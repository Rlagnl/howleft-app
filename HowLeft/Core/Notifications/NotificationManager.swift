import Foundation
import UserNotifications
import AppKit

/// 通知 + 提示音 + 阈值去重管理
/// 授权状态缓存到内存，避免每次余额跨越都查询 usernoted 守护进程触发 XPC 通信
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    /// 内存缓存通知授权状态，避免重复 XPC 查询
    private var cachedAuthorization: Bool?

    private init() {}

    /// 请求通知授权（仅请求一次），结果缓存到内存
    /// - Returns: 是否授权
    func requestAuthorizationIfNeeded() async -> Bool {
        // 有缓存直接返回，避免每次都触发 XPC
        if let cached = cachedAuthorization {
            return cached
        }

        let settings = AppSettings.shared
        if settings.notificationAuthorizationRequested {
            // 之前请求过但本进程尚未缓存，查一次后缓存
            let current = await currentAuthorizationStatus()
            cachedAuthorization = current
            return current
        }
        settings.notificationAuthorizationRequested = true
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            cachedAuthorization = granted
            return granted
        } catch {
            cachedAuthorization = false
            return false
        }
    }

    /// 查询当前通知授权状态
    func currentAuthorizationStatus() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    /// 处理余额状态跨越阈值
    /// 仅在 充足 -> 不足 转换时推送通知 + 播放提示音
    func handleBalanceTransition(oldIsLow: Bool, newIsLow: Bool, currentBalance: Decimal, threshold: Decimal) async {
        guard !oldIsLow && newIsLow else { return }

        // 尝试请求授权（首次会触发 XPC，之后走内存缓存）
        let authorized = await requestAuthorizationIfNeeded()
        if authorized {
            pushNotification(balance: currentBalance, threshold: threshold)
        }
        // 提示音不依赖通知授权，始终播放
        playWarningSound()
    }

    private func pushNotification(balance: Decimal, threshold: Decimal) {
        let content = UNMutableNotificationContent()
        content.title = "DeepSeek 余额不足"
        content.body = "当前余额 \(formatBalance(balance))，低于阈值 \(formatBalance(threshold))"
        content.sound = nil  // 自行播放 NSSound，避免与系统通知音重复

        let request = UNNotificationRequest(
            identifier: "howleft.low-balance",
            content: content,
            trigger: nil
        )
        Task {
            do {
                try await center.add(request)
            } catch {
                // 通知发送失败不影响提示音
            }
        }
    }

    private func playWarningSound() {
        if let sound = NSSound(named: "warning") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    private func formatBalance(_ value: Decimal) -> String {
        "¥" + String(format: "%.2f", NSDecimalNumber(decimal: value).doubleValue)
    }
}
