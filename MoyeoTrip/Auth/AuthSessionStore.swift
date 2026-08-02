import Foundation
import Security

protocol AuthSessionStoring {
    func load() throws -> AuthTokens?
    func save(_ tokens: AuthTokens) throws
    func clear() throws
}

final class KeychainAuthSessionStore: AuthSessionStoring {
    private let service: String
    private let account: String

    init(
        service: String = Bundle.main.bundleIdentifier ?? "kr.hanchae.MoyeoTrip",
        account: String = "service-session"
    ) {
        self.service = service
        self.account = account
    }

    func load() throws -> AuthTokens? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw AuthSessionStoreError.keychain(status)
        }
        return try JSONDecoder().decode(AuthTokens.self, from: data)
    }

    func save(_ tokens: AuthTokens) throws {
        let data = try JSONEncoder().encode(tokens)
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var query = baseQuery
            query[kSecValueData as String] = data
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw AuthSessionStoreError.keychain(addStatus)
            }
        } else if status != errSecSuccess {
            throw AuthSessionStoreError.keychain(status)
        }
    }

    func clear() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthSessionStoreError.keychain(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
    }
}

enum AuthSessionStoreError: Error {
    case keychain(OSStatus)
}

final class InMemoryAuthSessionStore: AuthSessionStoring {
    private(set) var tokens: AuthTokens?

    func load() throws -> AuthTokens? { tokens }

    func save(_ tokens: AuthTokens) throws {
        self.tokens = tokens
    }

    func clear() throws {
        tokens = nil
    }
}
