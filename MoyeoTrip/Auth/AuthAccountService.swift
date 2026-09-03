import Combine
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
    private let profileStore: AuthDisplayProfileStoring

    init(
        apiClient: AuthAPIClientProtocol = AuthAPIClient(),
        sessionStore: AuthSessionStoring = KeychainAuthSessionStore(),
        profileStore: AuthDisplayProfileStoring = UserDefaultsAuthDisplayProfileStore()
    ) {
        self.apiClient = apiClient
        self.sessionStore = sessionStore
        self.profileStore = profileStore
    }

    func logout() async throws {
        try sessionStore.clear()
        profileStore.clear()
        await clearProviderSessions()
    }

    func withdraw() async throws {
        guard var tokens = try sessionStore.load() else {
            throw AuthClientError.missingTokens
        }

        do {
            try await apiClient.withdraw(accessToken: tokens.accessToken)
        } catch AuthClientError.server(let statusCode, _, _) where statusCode == 401 {
            let refreshed = try await apiClient.refreshSession(refreshToken: tokens.refreshToken)
            tokens = refreshed.tokens
            try sessionStore.save(tokens)
            try await apiClient.withdraw(accessToken: tokens.accessToken)
        } catch AuthClientError.server(let statusCode, _, _) where statusCode == 404 {
            try sessionStore.clear()
            profileStore.clear()
            await clearProviderSessions()
            return
        }

        try sessionStore.clear()
        profileStore.clear()
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

final class AuthCurrentUserService {
    private let apiClient: AuthAPIClientProtocol
    private let sessionStore: AuthSessionStoring
    private let profileStore: AuthDisplayProfileStoring

    init(
        apiClient: AuthAPIClientProtocol = AuthAPIClient(),
        sessionStore: AuthSessionStoring = KeychainAuthSessionStore(),
        profileStore: AuthDisplayProfileStoring = UserDefaultsAuthDisplayProfileStore()
    ) {
        self.apiClient = apiClient
        self.sessionStore = sessionStore
        self.profileStore = profileStore
    }

    func cachedProfile() -> AuthDisplayProfile? {
        if let profile = profileStore.load() { return profile }
        guard let tokens = (try? sessionStore.load()) ?? nil,
              let nickname = AuthDisplayProfile.nickname(fromAccessToken: tokens.accessToken) else {
            return nil
        }
        return AuthDisplayProfile(nickname: nickname, profileImageURL: nil)
    }

    func refreshProfile() async throws -> AuthDisplayProfile {
        var tokens = try requireTokens()
        let response: AuthProfileImagesResponse
        do {
            response = try await apiClient.profileImages(accessToken: tokens.accessToken)
        } catch AuthClientError.server(let statusCode, _, _) where statusCode == 401 {
            let refreshed = try await apiClient.refreshSession(refreshToken: tokens.refreshToken)
            tokens = refreshed.tokens
            try sessionStore.save(tokens)
            response = try await apiClient.profileImages(accessToken: tokens.accessToken)
        }

        let cached = profileStore.load()
        let nickname = AuthDisplayProfile.nickname(fromAccessToken: tokens.accessToken) ?? cached?.nickname
        guard let nickname else { throw AuthClientError.invalidResponse }
        let profile = AuthDisplayProfile(
            nickname: nickname,
            profileImageURL: response.candidates.first(where: \.selected)?.profileImageUrl
        )
        profileStore.save(profile)
        return profile
    }

    private func requireTokens() throws -> AuthTokens {
        guard let tokens = try sessionStore.load() else { throw AuthClientError.missingTokens }
        return tokens
    }
}

@MainActor
final class AuthProviderLinkService: ObservableObject {
    @Published private(set) var providers: Set<AuthServiceProvider> = []
    @Published private(set) var isLoading = false
    @Published private(set) var linkingProvider: AuthServiceProvider?
    @Published private(set) var errorMessage: String?

    private let apiClient: AuthAPIClientProtocol
    private let identityProvider: AuthIdentityProviding
    private let sessionStore: AuthSessionStoring
    private let fcmTokenProvider: AuthFCMTokenProviding

    static var current: AuthProviderLinkService {
        AuthProviderLinkService()
    }

    init(
        apiClient: AuthAPIClientProtocol? = nil,
        identityProvider: AuthIdentityProviding? = nil,
        sessionStore: AuthSessionStoring? = nil,
        fcmTokenProvider: AuthFCMTokenProviding? = nil
    ) {
        self.apiClient = apiClient ?? AuthAPIClient()
        self.identityProvider = identityProvider ?? AuthFlowDependencies.current.identityProvider
        self.sessionStore = sessionStore ?? KeychainAuthSessionStore()
        self.fcmTokenProvider = fcmTokenProvider ?? FirebaseMessagingAuthFCMTokenProvider()
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            providers = try await withValidAccessToken { accessToken in
                try await apiClient.linkedProviders(accessToken: accessToken).providers
            }
        } catch {
            errorMessage = message(for: error)
        }
    }

    func link(_ provider: AuthServiceProvider) async {
        guard provider != .email, !providers.contains(provider), linkingProvider == nil else { return }
        linkingProvider = provider
        errorMessage = nil
        defer { linkingProvider = nil }
        do {
            let idToken = try await identityProvider.socialIDToken(for: provider)
            try await submitLink(idToken: idToken)
        } catch {
            errorMessage = message(for: error)
        }
    }

    func linkEmail(email: String, password: String) async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty, !providers.contains(.email), linkingProvider == nil else { return }
        linkingProvider = .email
        errorMessage = nil
        defer { linkingProvider = nil }
        do {
            let idToken = try await identityProvider.createEmailAccount(trimmedEmail, password: password)
            try await submitLink(idToken: idToken)
        } catch {
            errorMessage = message(for: error)
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func submitLink(idToken: String) async throws {
        // 공백만 있는 토큰은 서버가 400 `40016` 으로 막는다 — 없으면 필드를 생략한다 (정본 R6).
        let fcmToken = AuthFCMToken.normalized(await fcmTokenProvider.currentToken())
        providers = try await withValidAccessToken { accessToken in
            try await apiClient.linkProvider(
                idToken: idToken,
                fcmToken: fcmToken,
                accessToken: accessToken
            ).providers
        }
        fcmTokenProvider.markRegisteredWithBackend(fcmToken)
    }

    private func withValidAccessToken<Value>(
        operation: (String) async throws -> Value
    ) async throws -> Value {
        guard var tokens = try sessionStore.load() else { throw AuthClientError.missingTokens }
        do {
            return try await operation(tokens.accessToken)
        } catch AuthClientError.server(let statusCode, let code, let message) where statusCode == 401 {
            // 갱신 토큰이 없는 세션(캡처 세션)은 갱신할 수 없다 — 401 을 그대로 올린다.
            // 빈 refreshToken 으로 `/auth/refresh` 를 부르면 400 이 돌아와 원인이 가려진다.
            guard !tokens.refreshToken.isEmpty else {
                throw AuthClientError.server(statusCode: statusCode, code: code, message: message)
            }
            let refreshed = try await apiClient.refreshSession(refreshToken: tokens.refreshToken)
            tokens = refreshed.tokens
            try sessionStore.save(tokens)
            return try await operation(tokens.accessToken)
        }
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "요청을 완료하지 못했어요. 다시 시도해주세요."
    }
}
