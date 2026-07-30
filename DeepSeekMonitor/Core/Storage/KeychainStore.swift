import Foundation
import Security

/// Keychain 封装，存储 DeepSeek API Key
/// 以 apiKeyId.uuidString 为 Account，service 隔离本应用
/// 注意：非沙箱环境使用传统 file-based Keychain（不启用 kSecUseDataProtectionKeychain），
/// 该属性在 ad-hoc 签名下会报 errSecMissingEntitlement / errSecNotAvailable。
enum KeychainStore {
    private static let service = "com.deepseek.monitor"

    enum KeychainError: LocalizedError {
        case unhandledStatus(OSStatus)
        case dataConversionError

        var errorDescription: String? {
            switch self {
            case .unhandledStatus(let status):
                // 同时给出错误码与 SecCopyErrorMessageString 的可读描述，便于诊断
                let message = (SecCopyErrorMessageString(status, nil) as String?) ?? "未知 Keychain 错误"
                return "Keychain 操作失败（码 \(status)）：\(message)"
            case .dataConversionError:
                return "API Key 数据转换失败"
            }
        }
    }

    /// 保存 API Key（若已存在则更新）
    static func save(apiKey: String, for keyId: UUID) throws {
        guard let data = apiKey.data(using: .utf8) else {
            throw KeychainError.dataConversionError
        }
        let account = keyId.uuidString

        // 先尝试删除已存在的项（避免重复添加冲突）
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    /// 读取 API Key，不存在返回 nil
    static func load(for keyId: UUID) throws -> String? {
        let account = keyId.uuidString
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
        guard let data = item as? Data, let apiKey = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversionError
        }
        return apiKey
    }

    /// 删除 API Key
    static func delete(for keyId: UUID) throws {
        let account = keyId.uuidString
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        // 不存在视为删除成功
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }
}
