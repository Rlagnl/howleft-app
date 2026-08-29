import Foundation

/// DeepSeek /user/balance 接口响应模型
struct BalanceResponse: Codable {
    let is_available: Bool
    let balance_infos: [BalanceInfo]
}

/// 单条余额信息
struct BalanceInfo: Codable {
    let currency: String            // "CNY" | "USD"
    let total_balance: String       // 总可用余额
    let granted_balance: String     // 赠金余额
    let topped_up_balance: String   // 充值余额
}
