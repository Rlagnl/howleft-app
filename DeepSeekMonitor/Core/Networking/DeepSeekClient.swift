import Foundation

/// DeepSeek API 客户端，封装余额查询
/// 注意：DeepSeek 官方 /user/balance 实际只返回 CNY 余额，无 USD 数据
struct DeepSeekClient {
    private static let balanceURL = URL(string: "https://api.deepseek.com/user/balance")!

    /// 查询指定 API Key 的 CNY 余额
    /// - Parameter apiKey: DeepSeek API Key
    /// - Returns: CNY 余额（Decimal），仅取 currency == "CNY" 的 total_balance
    func fetchCNYBalance(apiKey: String) async throws -> Decimal {
        var request = URLRequest(url: Self.balanceURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            throw DeepSeekError.network(error)
        } catch {
            throw DeepSeekError.unknown
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepSeekError.unknown
        }

        if httpResponse.statusCode == 401 {
            throw DeepSeekError.unauthorized
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw DeepSeekError.unexpectedStatus(httpResponse.statusCode)
        }

        let balanceResponse: BalanceResponse
        do {
            balanceResponse = try JSONDecoder().decode(BalanceResponse.self, from: data)
        } catch {
            throw DeepSeekError.decoding(error)
        }

        // 仅取 CNY 余额（官方 API 只返回 CNY 条目）
        guard let cnyInfo = balanceResponse.balance_infos.first(where: { $0.currency == "CNY" }),
              let balance = Decimal(string: cnyInfo.total_balance) else {
            throw DeepSeekError.noCNYBalance
        }
        return balance
    }
}
