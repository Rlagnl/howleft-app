import Foundation

/// DeepSeek 账号模型
/// 每个"账号"绑定 1 个 API Key 用于查询余额（同账号下多 Key 共享余额，避免重复计算）
struct Account: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String          // 用户起名，如"工作账号"
    var apiKeyId: UUID        // Keychain 中存储 API Key 的键标识
    var apiKeyMasked: String  // UI 显示用掩码（如 sk-***...***1234）

    /// 生成掩码：保留首 4 + 末 4，中间用 *** 代替
    static func mask(apiKey: String) -> String {
        guard apiKey.count > 8 else { return String(repeating: "*", count: max(apiKey.count, 4)) }
        let start = apiKey.prefix(4)
        let end = apiKey.suffix(4)
        return "\(start)***\(end)"
    }
}
