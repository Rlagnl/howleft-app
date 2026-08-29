import Foundation
import AppKit
import ServiceManagement
import Combine

/// 全局状态管理
@MainActor
final class AppState: ObservableObject {
    /// 单例：AppDelegate 中的 NSStatusItem/NSPopover 无法直接持有 ObservableObject，
    /// 通过 shared 访问状态，并在状态变化时发通知刷新菜单栏标题
    static let shared = AppState()

    // MARK: - 发布给 UI 的状态
    @Published var totalBalance: Decimal?       // 当前 CNY 余额总和，nil 表示未加载
    @Published var lastUpdatedAt: Date?         // 最后成功更新时间
    @Published var failedAccountCount: Int = 0  // 失败账号数
    @Published var isLowBalance: Bool = false   // 余额不足状态（用于图标 + 阈值去重）
    @Published var isRefreshing: Bool = false   // 正在刷新中

    // MARK: - 依赖
    let settings = AppSettings.shared
    /// 内存缓存 API Key（启动时从 Keychain 加载一次，之后轮询不再读 Keychain，避免 XPC 噪音）
    private var apiKeys: [UUID: String] = [:]
    private lazy var poller: BalancePoller = BalancePoller(
        accounts: settings.accounts,
        apiKeys: apiKeys,
        intervalMinutes: settings.pollingIntervalMinutes
    )
    private let notifier = NotificationManager.shared

    /// 状态变化时发通知，AppDelegate 监听后刷新 NSStatusItem 标题
    private var cancellables: Set<AnyCancellable> = []

    private init() {
        // 恢复缓存状态
        self.totalBalance = settings.lastTotalBalance
        self.lastUpdatedAt = settings.lastUpdatedAt
        self.isLowBalance = settings.isLowBalance

        // 启动时从 Keychain 一次性加载所有 API Key 到内存，之后轮询只读内存
        // 这样避免每个轮询周期都触发 securityd XPC 通信产生 NSSecureCoding 警告
        for account in settings.accounts {
            if let key = try? KeychainStore.load(for: account.apiKeyId) ?? nil {
                self.apiKeys[account.apiKeyId] = key
            }
        }

        // 用 Combine 监听自身 @Published 变化，转发给 NotificationCenter
        // AppDelegate 通过监听通知刷新菜单栏标题，实现状态驱动的 UI 更新
        $totalBalance
            .combineLatest($isLowBalance)
            .sink { _ in
                NotificationCenter.default.post(name: NSNotification.Name("AppStateChanged"), object: nil)
            }
            .store(in: &cancellables)

        // 配置 poller 回调
        poller.onPoll = { [weak self] result in
            self?.applyPollResult(result)
        }

        // 启动轮询（即使无账号也启动，添加账号后会更新）
        poller.start()

        // 注意：SMAppService 注册状态由系统跨启动持久化，启动时无需重新 register()。
        // 启动时主动 register() 会触发系统 XPC 通信，产生大量 NSSecureCoding 警告日志，
        // 故仅在用户主动切换时才调用 register/unregister。
    }

    // MARK: - 账号管理
    /// 添加账号
    func addAccount(name: String, apiKey: String) throws {
        let accountId = UUID()
        let apiKeyId = UUID()
        try KeychainStore.save(apiKey: apiKey, for: apiKeyId)
        let account = Account(
            id: accountId,
            name: name,
            apiKeyId: apiKeyId,
            apiKeyMasked: Account.mask(apiKey: apiKey)
        )
        settings.accounts.append(account)
        apiKeys[apiKeyId] = apiKey   // 同步内存缓存
        poller.update(accounts: settings.accounts, apiKeys: apiKeys, intervalMinutes: settings.pollingIntervalMinutes)
        // 添加后立即刷新一次
        Task { await self.refreshNow() }
    }

    /// 删除账号
    func deleteAccount(_ account: Account) {
        try? KeychainStore.delete(for: account.apiKeyId)
        settings.accounts.removeAll { $0.id == account.id }
        apiKeys.removeValue(forKey: account.apiKeyId)   // 同步内存缓存
        poller.update(accounts: settings.accounts, apiKeys: apiKeys, intervalMinutes: settings.pollingIntervalMinutes)
        Task { await self.refreshNow() }
    }

    // MARK: - 刷新
    /// 手动触发一次刷新
    func refreshNow() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let result = await poller.refreshOnce()
        applyPollResult(result)
    }

    /// 应用轮询结果，更新状态并检测阈值跨越
    private func applyPollResult(_ result: PollResult) {
        if let balance = result.totalBalance {
            // 至少有一个账号成功
            self.totalBalance = balance
            self.lastUpdatedAt = Date()
            self.failedAccountCount = result.failedCount

            // 持久化缓存
            settings.lastTotalBalance = balance
            settings.lastUpdatedAt = self.lastUpdatedAt

            // 检测阈值跨越
            let threshold = settings.lowBalanceThreshold
            let newIsLow = balance < threshold
            let oldIsLow = self.isLowBalance
            self.isLowBalance = newIsLow
            settings.isLowBalance = newIsLow

            // 触发通知 + 提示音（仅充足->不足）
            Task {
                await notifier.handleBalanceTransition(
                    oldIsLow: oldIsLow,
                    newIsLow: newIsLow,
                    currentBalance: balance,
                    threshold: threshold
                )
            }
        } else {
            // 全部失败：保留上次余额，仅更新失败计数
            self.failedAccountCount = result.failedCount
        }
    }

    // MARK: - 配置变更
    /// 轮询频率变更后重启 poller
    func pollingIntervalDidChange() {
        poller.update(accounts: settings.accounts, apiKeys: apiKeys, intervalMinutes: settings.pollingIntervalMinutes)
    }

    // MARK: - 外部操作
    /// 打开充值页面
    func openRechargeURL() {
        if let url = URL(string: "https://platform.deepseek.com/usage") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - 开机自启
    /// 切换开机自启
    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            // 注册/注销成功后，以系统真实状态为准同步给 UI
            settings.launchAtLogin = (SMAppService.mainApp.status == .enabled)
        } catch {
            // 注册/注销失败：不改 launchAtLogin，保持系统真实状态
            settings.launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }
}
