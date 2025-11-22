import Foundation
import Security
import CryptoKit

/// Keychain service for secure storage of encryption keys and tokens
class KeychainService {
    private let serviceName = "app.cardoncue.CardOnCue"

    enum KeychainError: LocalizedError {
        case unexpectedData
        case unhandledError(status: OSStatus)
        case itemNotFound

        var errorDescription: String? {
            switch self {
            case .unexpectedData:
                return "Unexpected data format in Keychain"
            case .unhandledError(let status):
                return "Keychain error: \(status)"
            case .itemNotFound:
                return "Item not found in Keychain"
            }
        }
    }

    enum KeychainKey {
        case masterKey
        case accessToken
        case refreshToken

        var rawValue: String {
            switch self {
            case .masterKey: return "master_key"
            case .accessToken: return "access_token"
            case .refreshToken: return "refresh_token"
            }
        }
    }

    // MARK: - Master Key Management

    /// Get or generate master encryption key
    func getMasterKey() throws -> SymmetricKey? {
        // Try to retrieve existing key
        if let keyData = try? getData(for: .masterKey) {
            return SymmetricKey(data: keyData)
        }

        // Generate new key if none exists
        return nil
    }

    /// Generate and store a new master key
    @discardableResult
    func generateAndStoreMasterKey() throws -> SymmetricKey {
        // Generate 256-bit key
        let key = SymmetricKey(size: .bits256)

        // Store in Keychain
        try storeData(key.dataRepresentation, for: .masterKey)

        print("✅ Generated and stored new master key")
        return key
    }

    /// Delete master key (WARNING: All encrypted data will be unrecoverable)
    func deleteMasterKey() throws {
        try deleteData(for: .masterKey)
    }

    // MARK: - Token Management

    /// Store access token
    func storeAccessToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.unexpectedData
        }
        try storeData(data, for: .accessToken)
    }

    /// Get access token
    func getAccessToken() throws -> String? {
        guard let data = try getData(for: .accessToken) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Delete access token
    func deleteAccessToken() throws {
        try deleteData(for: .accessToken)
    }

    /// Store refresh token
    func storeRefreshToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.unexpectedData
        }
        try storeData(data, for: .refreshToken)
    }

    /// Get refresh token
    func getRefreshToken() throws -> String? {
        guard let data = try getData(for: .refreshToken) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Delete refresh token
    func deleteRefreshToken() throws {
        try deleteData(for: .refreshToken)
    }

    /// Delete all tokens
    func deleteAllTokens() throws {
        try? deleteAccessToken()
        try? deleteRefreshToken()
    }

    // MARK: - Generic Keychain Operations

    private func storeData(_ data: Data, for key: KeychainKey) throws {
        // First try to delete existing item
        try? deleteData(for: key)

        // Create query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: serviceName,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecUseDataProtectionKeychain as String: true
        ]

        // Store in Keychain
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    private func getData(for key: KeychainKey) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: serviceName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseDataProtectionKeychain as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.unexpectedData
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandledError(status: status)
        }
    }

    private func deleteData(for key: KeychainKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: serviceName,
            kSecUseDataProtectionKeychain as String: true
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
}

// MARK: - SymmetricKey Extension

extension SymmetricKey {
    /// Convert to Data for storage
    var dataRepresentation: Data {
        return withUnsafeBytes { Data($0) }
    }
}
