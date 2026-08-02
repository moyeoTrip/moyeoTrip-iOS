import Foundation
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
#if canImport(KakaoSDKUser)
import KakaoSDKUser
#endif

final class AuthAccountService {
    private let apiClient: AuthAPIClientProtocol
    private let sessionStore: AuthSessionStoring

    init(
        apiClient: AuthAPIClientProtocol = AuthAPIClient(),
        sessionStore: AuthSessionStoring = KeychainAuthSessionStore()
    ) {
        self.apiClient = apiClient
        self.sessionStore = sessionStore
    }

    func logout() async throws {
        try sessionStore.clear()
        await clearProviderSessions()
    }

    func withdraw() async throws {
        guard var tokens = try sessionStore.load() else {
            throw AuthClientError.missingTokens
        }

        do {
            try await apiClient.withdraw(accessToken: tokens.accessToken)
        } catch AuthClientError.server(let statusCode, _) where statusCode == 401 {
            let refreshed = try await apiClient.refreshSession(refreshToken: tokens.refreshToken)
            tokens = refreshed.tokens
            try sessionStore.save(tokens)
            try await apiClient.withdraw(accessToken: tokens.accessToken)
        } catch AuthClientError.server(let statusCode, _) where statusCode == 404 {
            try sessionStore.clear()
            await clearProviderSessions()
            return
        }

        try sessionStore.clear()
        await clearProviderSessions()
    }

    @MainActor
    private func clearProviderSessions() async {
        #if canImport(FirebaseAuth)
        try? Auth.auth().signOut()
        #endif
        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
        #endif
        #if canImport(KakaoSDKUser)
        await withCheckedContinuation { continuation in
            UserApi.shared.logout { _ in
                continuation.resume()
            }
        }
        #endif
    }
}
