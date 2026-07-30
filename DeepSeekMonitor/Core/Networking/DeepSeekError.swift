import Foundation

/// DeepSeek API 错误
enum DeepSeekError: LocalizedError {
    case unauthorized               // 401 鉴权失败
    case network(URLError)          // 网络错误
    case decoding(Error)            // 解析失败
    case unexpectedStatus(Int)      // 非 200 状态码
    case noCNYBalance               // 返回中无 CNY 余额条目
    case unknown                    // 未知错误

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "API Key 无效或已失效"
        case .network(let error):
            return "网络错误：\(error.localizedDescription)"
        case .decoding:
            return "响应解析失败"
        case .unexpectedStatus(let code):
            return "服务器返回状态码 \(code)"
        case .noCNYBalance:
            return "返回中无 CNY 余额条目"
        case .unknown:
            return "未知错误"
        }
    }
}
