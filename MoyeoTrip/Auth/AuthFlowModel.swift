import Combine
import Foundation

enum AuthFlowStage: Equatable {
    case splash
    case onboarding
    case login
    case emailLogin
    case emailRegistration
    case passwordReset
    case nickname
    case basics
    case profileImage

    var progress: Double {
        switch self {
        case .splash: 0
        case .onboarding: 0.12
        case .login: 0.28
        case .emailLogin, .emailRegistration, .passwordReset: 0.34
        case .nickname: 0.44
        case .basics: 0.68
        case .profileImage: 0.94
        }
    }
}

struct AuthFlowDependencies {
    let apiClient: AuthAPIClientProtocol
    let identityProvider: AuthIdentityProviding
    let sessionStore: AuthSessionStoring
    let fcmTokenProvider: AuthFCMTokenProviding

    static var current: AuthFlowDependencies {
        if ProcessInfo.processInfo.arguments.contains("UITEST_MODE") {
            return AuthFlowDependencies(
                apiClient: MockAuthAPIClient(arguments: ProcessInfo.processInfo.arguments),
                identityProvider: MockAuthIdentityProvider(delayNanoseconds: 50_000_000),
                sessionStore: InMemoryAuthSessionStore(),
                fcmTokenProvider: UnsupportedAuthFCMTokenProvider()
            )
        }
        let apiClient = AuthAPIClient()
        return AuthFlowDependencies(
            apiClient: apiClient,
            identityProvider: currentIdentityProvider(apiClient: apiClient),
            sessionStore: KeychainAuthSessionStore(),
            fcmTokenProvider: FirebaseMessagingAuthFCMTokenProvider()
        )
    }

    private static func currentIdentityProvider(
        apiClient: AuthAPIClientProtocol
    ) -> AuthIdentityProviding {
        #if canImport(FirebaseAuth)
        return FirebaseAuthIdentityProvider(authAPIClient: apiClient)
        #else
        return MockAuthIdentityProvider()
        #endif
    }
}

@MainActor
final class AuthFlowViewModel: ObservableObject {
    @Published var stage: AuthFlowStage = .onboarding
    @Published private(set) var loadingProvider: AuthServiceProvider?
    @Published private(set) var isSubmittingEmail = false
    @Published private(set) var passwordResetMessage: String?
    @Published private(set) var isSubmittingSignup = false
    @Published private(set) var isRestoringSession = false
    @Published private(set) var isLoadingProfileImages = false
    @Published private(set) var isGeneratingProfileImage = false
    @Published private(set) var selectingProfileImageID: Int64?
    @Published private(set) var errorMessage: String?
    @Published private(set) var nicknameResponse = AuthNicknameViewModel.initialResponse
    @Published private(set) var profileImages: [AuthProfileImageCandidate] = []
    @Published private(set) var remainingProfileGenerations = 3

    private let dependencies: AuthFlowDependencies
    private var provider: AuthServiceProvider?
    private var idToken: String?
    private var tokens: AuthTokens?
    private var selectedNickname = ""
    private var nicknameSelectionToken = ""
    private var hasAttemptedSessionRestore = false

    init(dependencies: AuthFlowDependencies? = nil) {
        self.dependencies = dependencies ?? .current
    }

    var nicknameProvider: AuthNicknameCandidateProviding {
        dependencies.apiClient
    }

    var selectedNicknameForProfile: String? {
        let nickname = selectedNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return nickname.isEmpty ? nil : nickname
    }

    var selectedNicknameCandidateForProfile: AuthNicknameCandidate? {
        nicknameResponse.candidates.first { $0.nickname == selectedNickname }
    }

    var isBusy: Bool {
        loadingProvider != nil || isSubmittingEmail || isSubmittingSignup || isRestoringSession || isLoadingProfileImages
            || isGeneratingProfileImage || selectingProfileImageID != nil
    }

    func restoreSession() async -> Bool {
        guard !hasAttemptedSessionRestore else { return false }
        hasAttemptedSessionRestore = true

        let storedTokens: AuthTokens
        do {
            guard let loadedTokens = try dependencies.sessionStore.load() else {
                stage = .onboarding
                return false
            }
            storedTokens = loadedTokens
        } catch {
            stage = .login
            errorMessage = message(for: error)
            return false
        }

        isRestoringSession = true
        defer { isRestoringSession = false }

        do {
            let response = try await dependencies.apiClient.refreshSession(
                refreshToken: storedTokens.refreshToken
            )
            let refreshedTokens = response.tokens
            try dependencies.sessionStore.save(refreshedTokens)
            tokens = refreshedTokens

            switch response.signupState {
            case .signupComplete:
                return true
            case .profileImageRequired:
                stage = .profileImage
                await loadProfileImages()
            case .userInfoRequired:
                try dependencies.sessionStore.clear()
                tokens = nil
                stage = .onboarding
            }
        } catch {
            if case AuthClientError.server(let statusCode, _) = error,
               statusCode == 400 || statusCode == 401 || statusCode == 404 {
                try? dependencies.sessionStore.clear()
                tokens = nil
                stage = .onboarding
            } else {
                stage = .login
            }
            errorMessage = message(for: error)
        }
        return false
    }

    func authenticate(with provider: AuthServiceProvider) async -> Bool {
        guard provider != .email else {
            stage = .emailLogin
            return false
        }
        guard !isBusy else { return false }
        loadingProvider = provider
        errorMessage = nil
        defer { loadingProvider = nil }

        do {
            let idToken = try await dependencies.identityProvider.socialIDToken(for: provider)
            return try await routeAfterBackendLogin(provider: provider, idToken: idToken)
        } catch {
            errorMessage = message(for: error)
            return false
        }
    }

    func authenticateEmail(email: String, password: String, mode: AuthEmailMode) async -> Bool {
        guard !isBusy else { return false }
        isSubmittingEmail = true
        errorMessage = nil
        passwordResetMessage = nil
        defer { isSubmittingEmail = false }

        do {
            let idToken: String
            switch mode {
            case .signIn:
                idToken = try await dependencies.identityProvider.signInWithEmail(email, password: password)
            case .createAccount:
                idToken = try await dependencies.identityProvider.createEmailAccount(email, password: password)
            }
            return try await routeAfterBackendLogin(provider: .email, idToken: idToken)
        } catch {
            errorMessage = message(for: error)
            return false
        }
    }

    func resetPassword(email: String) async {
        guard !isBusy else { return }
        isSubmittingEmail = true
        errorMessage = nil
        passwordResetMessage = nil
        defer { isSubmittingEmail = false }

        do {
            try await dependencies.identityProvider.sendPasswordReset(to: email)
            passwordResetMessage = "비밀번호 재설정 메일을 보냈어요."
        } catch {
            errorMessage = message(for: error)
        }
    }

    func prepareSignup(nickname: String, selectionToken: String) {
        selectedNickname = nickname
        nicknameSelectionToken = selectionToken
        errorMessage = nil
        stage = .basics
    }

    func submitSignup(gender: AuthGender, birthdate: AuthBirthdate) async {
        guard !isBusy, provider != nil, let idToken else { return }
        isSubmittingSignup = true
        errorMessage = nil
        defer { isSubmittingSignup = false }

        do {
            let fcmToken = await dependencies.fcmTokenProvider.currentToken()
            let response = try await dependencies.apiClient.signup(
                request: AuthSignupRequest(
                    idToken: idToken,
                    nicknameSelectionToken: nicknameSelectionToken,
                    nickname: selectedNickname,
                    gender: gender.apiValue,
                    birthDate: birthdate.apiValue,
                    fcmToken: fcmToken
                )
            )
            dependencies.fcmTokenProvider.markRegisteredWithBackend(fcmToken)
            try dependencies.sessionStore.save(response.tokens)
            tokens = response.tokens
            switch response.signupState {
            case .profileImageRequired:
                stage = .profileImage
                await loadProfileImages()
            case .signupComplete:
                throw AuthClientError.invalidResponse
            case .userInfoRequired:
                throw AuthClientError.invalidResponse
            }
        } catch {
            errorMessage = message(for: error)
        }
    }

    func loadProfileImages() async {
        guard !isLoadingProfileImages, tokens != nil else {
            if tokens == nil { errorMessage = AuthClientError.missingTokens.localizedDescription }
            return
        }
        isLoadingProfileImages = true
        errorMessage = nil
        defer { isLoadingProfileImages = false }

        do {
            let response = try await withValidAccessToken { accessToken in
                try await dependencies.apiClient.profileImages(accessToken: accessToken)
            }
            profileImages = response.candidates
            remainingProfileGenerations = response.remainingGenerationCount
        } catch {
            errorMessage = message(for: error)
        }
    }

    func generateProfileImage() async {
        guard !isBusy, remainingProfileGenerations > 0, tokens != nil else { return }
        isGeneratingProfileImage = true
        errorMessage = nil
        defer { isGeneratingProfileImage = false }

        do {
            let response = try await withValidAccessToken { accessToken in
                try await dependencies.apiClient.generateProfileImage(accessToken: accessToken)
            }
            mergeProfileCandidate(response.candidate)
            remainingProfileGenerations = response.remainingGenerationCount
        } catch {
            errorMessage = message(for: error)
        }
    }

    func selectProfileImage(_ candidate: AuthProfileImageCandidate) async -> Bool {
        guard !isBusy, tokens != nil else { return false }
        selectingProfileImageID = candidate.id
        errorMessage = nil
        defer { selectingProfileImageID = nil }

        do {
            let response = try await withValidAccessToken { accessToken in
                try await dependencies.apiClient.selectProfileImage(
                    id: candidate.id,
                    accessToken: accessToken
                )
            }
            guard response.signupState == .signupComplete else {
                throw AuthClientError.invalidResponse
            }
            profileImages = profileImages.map { image in
                AuthProfileImageCandidate(
                    profileImageId: image.profileImageId,
                    profileImageUrl: image.profileImageUrl,
                    selected: image.id == response.selectedImage.id
                )
            }
            return true
        } catch {
            errorMessage = message(for: error)
            return false
        }
    }

    func clearError() {
        errorMessage = nil
        passwordResetMessage = nil
    }

    private func routeAfterBackendLogin(provider: AuthServiceProvider, idToken: String) async throws -> Bool {
        let fcmToken = await dependencies.fcmTokenProvider.currentToken()
        let response = try await dependencies.apiClient.login(
            request: AuthLoginRequest(idToken: idToken, fcmToken: fcmToken)
        )
        dependencies.fcmTokenProvider.markRegisteredWithBackend(fcmToken)
        self.provider = response.providerType
        self.idToken = idToken

        switch response.signupState {
        case .signupComplete:
            guard let tokens = response.tokens else { throw AuthClientError.missingTokens }
            try dependencies.sessionStore.save(tokens)
            self.tokens = tokens
            return true
        case .profileImageRequired:
            guard let tokens = response.tokens else { throw AuthClientError.missingTokens }
            try dependencies.sessionStore.save(tokens)
            self.tokens = tokens
            stage = .profileImage
            await loadProfileImages()
        case .userInfoRequired:
            nicknameResponse = try await dependencies.apiClient.fetchCandidates()
            stage = .nickname
        }
        return false
    }

    private func mergeProfileCandidate(_ candidate: AuthProfileImageCandidate) {
        if let index = profileImages.firstIndex(where: { $0.id == candidate.id }) {
            profileImages[index] = candidate
        } else {
            profileImages.append(candidate)
        }
    }

    private func withValidAccessToken<Value>(
        operation: (String) async throws -> Value
    ) async throws -> Value {
        guard var currentTokens = tokens else { throw AuthClientError.missingTokens }
        do {
            return try await operation(currentTokens.accessToken)
        } catch AuthClientError.server(let statusCode, _) where statusCode == 401 {
            let refreshed = try await dependencies.apiClient.refreshSession(
                refreshToken: currentTokens.refreshToken
            )
            currentTokens = refreshed.tokens
            try dependencies.sessionStore.save(currentTokens)
            tokens = currentTokens
            return try await operation(currentTokens.accessToken)
        }
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "요청을 완료하지 못했어요. 다시 시도해주세요."
    }
}
