import Foundation
import ServiceManagement

/// 用户配置，持久化到 UserDefaults
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // MARK: - 账号列表
    @Published var accounts: [Account] {
        didSet { persistAccounts() }
    }

    // MARK: - 轮询与提醒配置
    @Published var pollingIntervalMinutes: Int {
        didSet {
            let clamped = max(1, min(60, pollingIntervalMinutes))
            if clamped != pollingIntervalMinutes {
                pollingIntervalMinutes = clamped
                return
            }
            defaults.set(pollingIntervalMinutes, forKey: Keys.pollingIntervalMinutes)
        }
    }

    @Published var lowBalanceThreshold: Decimal {
        didSet {
            // Decimal 存为 String 以保证精度
            defaults.set(lowBalanceThreshold.description, forKey: Keys.lowBalanceThreshold)
        }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    // MARK: - 运行时缓存状态
    @Published var lastTotalBalance: Decimal? {
        didSet {
            if let value = lastTotalBalance {
                defaults.set(value.description, forKey: Keys.lastTotalBalance)
            } else {
                defaults.removeObject(forKey: Keys.lastTotalBalance)
            }
        }
    }

    @Published var lastUpdatedAt: Date? {
        didSet { defaults.set(lastUpdatedAt, forKey: Keys.lastUpdatedAt) }
    }

    @Published var isLowBalance: Bool {
        didSet { defaults.set(isLowBalance, forKey: Keys.isLowBalance) }
    }

    @Published var notificationAuthorizationRequested: Bool {
        didSet { defaults.set(notificationAuthorizationRequested, forKey: Keys.notificationAuthorizationRequested) }
    }

    private enum Keys {
        static let accounts = "accounts"
        static let pollingIntervalMinutes = "pollingIntervalMinutes"
        static let lowBalanceThreshold = "lowBalanceThreshold"
        static let launchAtLogin = "launchAtLogin"
        static let lastTotalBalance = "lastTotalBalance"
        static let lastUpdatedAt = "lastUpdatedAt"
        static let isLowBalance = "isLowBalance"
        static let notificationAuthorizationRequested = "notificationAuthorizationRequested"
    }

    private init() {
        // 账号
        if let data = defaults.data(forKey: Keys.accounts),
           let decoded = try? JSONDecoder().decode([Account].self, from: data) {
            self.accounts = decoded
        } else {
            self.accounts = []
        }

        // 轮询频率
        self.pollingIntervalMinutes = defaults.object(forKey: Keys.pollingIntervalMinutes) as? Int ?? 5

        // 阈值
        if let str = defaults.string(forKey: Keys.lowBalanceThreshold) {
            self.lowBalanceThreshold = Decimal(string: str) ?? 10
        } else {
            self.lowBalanceThreshold = 10
        }

        // 开机自启：以系统 SMAppService 的真实注册状态为准，避免 UserDefaults 与系统状态不一致
        // 不一致时 Toggle 会显示为混合态（灰色），而非激活态的蓝色
        self.launchAtLogin = (SMAppService.mainApp.status == .enabled)

        // 缓存状态
        if let str = defaults.string(forKey: Keys.lastTotalBalance) {
            self.lastTotalBalance = Decimal(string: str)
        } else {
            self.lastTotalBalance = nil
        }
        self.lastUpdatedAt = defaults.object(forKey: Keys.lastUpdatedAt) as? Date
        self.isLowBalance = defaults.bool(forKey: Keys.isLowBalance)
        self.notificationAuthorizationRequested = defaults.bool(forKey: Keys.notificationAuthorizationRequested)
    }

    private func persistAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            defaults.set(data, forKey: Keys.accounts)
        }
    }
}
