import Foundation

/// 单次轮询结果
struct PollResult {
    let totalBalance: Decimal?   // 成功账号的 CNY 余额之和；全部失败时为 nil
    let failedCount: Int
    let allFailed: Bool
}

/// 余额轮询调度器
/// 用 Task 循环 + Task.sleep 实现定时轮询，避免 Timer 强引用坑
/// API Key 从内存缓存读取，避免每次轮询都触发 Keychain XPC 通信
@MainActor
final class BalancePoller {
    private var task: Task<Void, Never>?
    private let client = DeepSeekClient()
    private var accounts: [Account] = []
    private var apiKeys: [UUID: String] = [:]   // 内存缓存：apiKeyId -> apiKey 明文
    private var intervalSeconds: Int

    /// 轮询回调，在主线程执行
    var onPoll: ((PollResult) -> Void)?

    init(accounts: [Account], apiKeys: [UUID: String], intervalMinutes: Int) {
        self.accounts = accounts
        self.apiKeys = apiKeys
        self.intervalSeconds = intervalMinutes * 60
    }

    /// 更新账号列表、API Key 缓存与轮询频率，并重启轮询
    func update(accounts: [Account], apiKeys: [UUID: String], intervalMinutes: Int) {
        self.accounts = accounts
        self.apiKeys = apiKeys
        self.intervalSeconds = intervalMinutes * 60
        restart()
    }

    /// 启动轮询
    func start() {
        guard task == nil else { return }
        startTask()
    }

    /// 停止轮询
    func stop() {
        task?.cancel()
        task = nil
    }

    /// 重启轮询（配置变更后调用）
    func restart() {
        stop()
        start()
    }

    private func startTask() {
        task = Task { [weak self] in
            guard let self else { return }
            // 启动后立即执行一次
            let result = await self.refreshOnce()
            self.onPoll?(result)
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(self.intervalSeconds))
                } catch {
                    // 被取消
                    break
                }
                if Task.isCancelled { break }
                let result = await self.refreshOnce()
                self.onPoll?(result)
            }
        }
    }

    /// 手动触发一次刷新（不依赖定时器）
    func refreshOnce() async -> PollResult {
        guard !accounts.isEmpty else {
            return PollResult(totalBalance: nil, failedCount: 0, allFailed: true)
        }

        // 并发查询各账号余额，API Key 从内存缓存读取（避免每次轮询触发 Keychain XPC）
        let results = await withTaskGroup(of: (Account, Result<Decimal, DeepSeekError>).self) { group in
            for account in accounts {
                group.addTask { [client, apiKeys] in
                    guard let apiKey = apiKeys[account.apiKeyId], !apiKey.isEmpty else {
                        return (account, .failure(.unauthorized))
                    }
                    do {
                        let balance = try await client.fetchCNYBalance(apiKey: apiKey)
                        return (account, .success(balance))
                    } catch let error as DeepSeekError {
                        return (account, .failure(error))
                    } catch {
                        return (account, .failure(.unknown))
                    }
                }
            }
            var collected: [(Account, Result<Decimal, DeepSeekError>)] = []
            for await item in group {
                collected.append(item)
            }
            return collected
        }

        var total: Decimal = 0
        var failedCount = 0
        var hasAnySuccess = false
        for (_, result) in results {
            switch result {
            case .success(let balance):
                total += balance
                hasAnySuccess = true
            case .failure:
                failedCount += 1
            }
        }

        return PollResult(
            totalBalance: hasAnySuccess ? total : nil,
            failedCount: failedCount,
            allFailed: !hasAnySuccess
        )
    }
}
