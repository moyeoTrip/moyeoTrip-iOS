import Combine
import Foundation

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
    /// 서버가 주는 활성 약관. 클라가 약관 목록을 따로 갖지 않는다 —
    /// 서버에서 약관이 늘거나 줄면 화면도 따라 바뀐다.
    @Published private(set) var serverTerms: [ServerTermSummary] = []
    @Published private(set) var isLoadingTerms = false
    @Published private(set) var termsLoadFailed = false
    /// 프로필 이미지 API 가 409 `40919`("이미 설정 완료")로 답했다 (정본 R2).
    /// 오류를 띄우지 않고 화면이 이 값을 보고 조용히 다음으로 넘어간다.
    @Published private(set) var signupDidComplete = false

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

    /// 캡처(`UITEST_LIVE_DATA`)에서만 — 심어 둔 액세스 토큰을 **갱신 없이** 그대로 세션으로 채택한다.
    ///
    /// 직접 진입(캡처 라우트)은 `restoreSession()` 을 타지 않아 `tokens` 가 비어 있고,
    /// 그렇다고 `restoreSession()` 을 태우면 캡처 세션의 refreshToken 이 빈 문자열이라
    /// `/auth/refresh` 가 400 으로 답해 화면이 로그인으로 튄다.
    /// 실사용 경로에서는 `UITestRuntime.liveCaptureTokens` 가 항상 nil 이라 아무 일도 하지 않는다.
    @discardableResult
    func adoptLiveCaptureSessionIfNeeded() -> Bool {
        guard tokens == nil, let captureTokens = UITestRuntime.liveCaptureTokens else { return tokens != nil }
        tokens = captureTokens
        hasAttemptedSessionRestore = true
        return true
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
                await resumeUserInfoSignup()
            }
        } catch {
            if case AuthClientError.server(let statusCode, _, _) = error,
               statusCode == 400 || statusCode == 401 || statusCode == 404 {
                // 세션 만료다(400 `40001 "유효하지 않은 RefreshToken 입니다."`).
                // 로그인 화면으로 보내는 것 자체가 안내이므로 오류 배너를 남기지 않는다
                // (AUTH-SILENT-CASES-CANON R3). 서버 `errorMessage` 는 개발자용이다(R4).
                try? dependencies.sessionStore.clear()
                tokens = nil
                stage = .onboarding
            } else {
                // 네트워크 실패·서버 5xx 는 사용자가 조치할 수 있다 — 계속 오류로 보여준다.
                stage = .login
                errorMessage = message(for: error)
            }
        }
        return false
    }

    /// 세션은 살아 있는데 서버가 "회원 정보가 아직 없다"고 답한 경우 (SIGNUP-GATE-CANON R2-1).
    ///
    /// 가입 API 는 Firebase `idToken` 을 요구하는데 그 값은 세션에 저장되지 않는다.
    /// 그렇다고 세션을 지우고 로그인 화면으로 보내면 **다시 로그인하라고 요구하는 셈**이다.
    /// Firebase 가 로그인 상태를 기기에 유지하므로 새 idToken 을 받아 그대로 이어간다.
    private func resumeUserInfoSignup() async {
        guard let refreshedIDToken = try? await dependencies.identityProvider.currentUserIDToken() else {
            // 유지된 로그인 상태가 없을 때만 재로그인이 필요하다.
            clearSessionAndReturnToOnboarding()
            return
        }
        do {
            // 로그인 응답이 제공자·가입 단계를 함께 주므로 첫 로그인과 같은 경로를 그대로 탄다.
            _ = try await routeAfterBackendLogin(idToken: refreshedIDToken)
        } catch {
            // 새 토큰으로도 이어갈 수 없으면 그때 로그인 화면으로 보낸다. 오류 배너는 남기지 않는다(R3).
            clearSessionAndReturnToOnboarding()
        }
    }

    private func clearSessionAndReturnToOnboarding() {
        try? dependencies.sessionStore.clear()
        tokens = nil
        stage = .onboarding
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
            return try await routeAfterBackendLogin(idToken: idToken)
        } catch {
            // 사용자가 그만둔 것은 실패가 아니다 — 로딩만 걷고 로그인 화면을 그대로 둔다
            // (AUTH-SILENT-CASES-CANON R1·R2).
            guard !AuthSignInCancellation.matches(error) else { return false }
            errorMessage = message(for: error)
            return false
        }
    }

    /// 이메일로 시작하기 — 로그인해 보고, 계정이 없으면 그대로 만든다.
    ///
    /// 사용자가 "로그인 / 새 계정 만들기"를 먼저 고르지 않는다. 소셜 로그인과 같은 흐름이다.
    ///
    /// 이 Firebase 프로젝트는 **Email Enumeration Protection** 이 켜져 있어서 로그인 실패가
    /// "계정 없음"인지 "비밀번호 틀림"인지 구분되지 않는다(둘 다 `invalidCredential`).
    /// 그래서 두 번째 호출로 가린다 — 계정 만들기가 `emailAlreadyInUse` 로 막히면
    /// 계정은 있고 비밀번호가 틀린 것이다.
    /// (실측 2026-08-29: 없는 이메일 로그인 → INVALID_LOGIN_CREDENTIALS, 있는 이메일 가입 → EMAIL_EXISTS)
    func authenticateEmail(email: String, password: String) async -> Bool {
        guard !isBusy else { return false }
        isSubmittingEmail = true
        errorMessage = nil
        passwordResetMessage = nil
        defer { isSubmittingEmail = false }

        do {
            let idToken = try await signInOrCreateEmailAccount(email: email, password: password)
            return try await routeAfterBackendLogin(idToken: idToken)
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

    /// 07 취향 단계에서 고른 값은 여기서 처음이자 마지막으로 서버에 실린다 (정본 R4).
    /// 고르지 않았으면 `nil` 을 넘겨 필드를 생략한다 — 빈 배열을 만들어 보내지 않는다.
    func submitSignup(
        gender: AuthGender,
        birthdate: AuthBirthdate,
        travelStyleIds: [Int64],
        interestedRegionIds: [Int64],
        agreedTermIds: [Int64]
    ) async {
        guard !isBusy, provider != nil, let idToken else { return }
        isSubmittingSignup = true
        errorMessage = nil
        defer { isSubmittingSignup = false }

        do {
            // 공백만 있는 토큰은 서버가 400 `40016` 으로 막는다 — 없으면 필드를 생략한다 (정본 R6).
            let fcmToken = AuthFCMToken.normalized(await dependencies.fcmTokenProvider.currentToken())
            let response = try await dependencies.apiClient.signup(
                request: AuthSignupRequest(
                    idToken: idToken,
                    nicknameSelectionToken: nicknameSelectionToken,
                    nickname: selectedNickname,
                    gender: gender.apiValue,
                    birthDate: birthdate.apiValue,
                    travelStyleIds: travelStyleIds.isEmpty ? nil : travelStyleIds,
                    interestedRegionIds: interestedRegionIds.isEmpty ? nil : interestedRegionIds,
                    fcmToken: fcmToken,
                    agreedTermIds: agreedTermIds
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

    func clearError() {
        errorMessage = nil
        passwordResetMessage = nil
    }

    /// 로그인 응답이 제공자와 가입 단계를 함께 준다 — 어느 버튼으로 들어왔는지는 여기서 쓰지 않는다.
    private func routeAfterBackendLogin(idToken: String) async throws -> Bool {
        // 공백만 있는 토큰은 서버가 400 `40016` 으로 막는다 — 없으면 필드를 생략한다 (정본 R6).
        // 같은 기기에서 계정을 바꿔도 서버가 토큰을 이관하므로 삭제 후 재시도는 하지 않는다.
        let fcmToken = AuthFCMToken.normalized(await dependencies.fcmTokenProvider.currentToken())
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

    private func withValidAccessToken<Value>(
        operation: (String) async throws -> Value
    ) async throws -> Value {
        guard var currentTokens = tokens else { throw AuthClientError.missingTokens }
        do {
            return try await operation(currentTokens.accessToken)
        } catch AuthClientError.server(let statusCode, let code, let message) where statusCode == 401 {
            // 갱신 토큰이 없는 세션(캡처 세션)은 갱신할 수 없다 — 401 을 그대로 올린다.
            // 빈 refreshToken 으로 `/auth/refresh` 를 부르면 400 이 돌아와 원인이 가려진다.
            guard !currentTokens.refreshToken.isEmpty else {
                throw AuthClientError.server(statusCode: statusCode, code: code, message: message)
            }
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

// MARK: - 프로필 이미지 (가입 마지막 단계)

extension AuthFlowViewModel {
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
            handleProfileImageFailure(error)
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
            handleProfileImageFailure(error)
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
            // 이미 프로필 이미지가 있으면 선택도 `40919` 로 막힌다 — 그건 실패가 아니라 완료다 (정본 R2).
            guard !isSignupAlreadyCompleted(error) else { return true }
            errorMessage = message(for: error)
            return false
        }
    }

    /// 후보 생성·조회가 실패했을 때. `40919` 는 오류가 아니라 완료다 (정본 R2).
    private func handleProfileImageFailure(_ error: Error) {
        guard !isSignupAlreadyCompleted(error) else {
            // 40919 = 이미 프로필 이미지 설정을 마쳤다 → **더 만들 수 없다.**
            // 남은 횟수를 초기 기본값(3)으로 두면 만들 수 없는 화면에 "3회 남음" 이 뜬다.
            // 서버가 알려준 값이 아니라 우리가 지어낸 숫자다 (NO-MOCK R1).
            // 안드로이드도 이 경우 0 을 쓴다 — 세 플랫폼이 같아야 한다.
            remainingProfileGenerations = 0
            signupDidComplete = true
            return
        }
        errorMessage = message(for: error)
    }

    private func mergeProfileCandidate(_ candidate: AuthProfileImageCandidate) {
        if let index = profileImages.firstIndex(where: { $0.id == candidate.id }) {
            profileImages[index] = candidate
        } else {
            profileImages.append(candidate)
        }
    }

    /// 후보 생성·조회·선택이 409 `40919` 로 막힌 경우인지 (정본 R2).
    ///
    /// 이미 가입이 끝난 사용자가 이 화면에 들어오면 세 API 가 모두 이 코드를 준다.
    /// 오류로 그리면 되돌아갈 길이 없는 마지막 화면에 갇힌다.
    private func isSignupAlreadyCompleted(_ error: Error) -> Bool {
        (error as? AuthClientError)?.isSignupAlreadyCompleted ?? false
    }
}

// MARK: - 이메일

extension AuthFlowViewModel {
    /// 로그인해 보고, 계정이 없으면 그대로 만든다.
    func signInOrCreateEmailAccount(email: String, password: String) async throws -> String {
        do {
            return try await dependencies.identityProvider.signInWithEmail(email, password: password)
        } catch {
            guard AuthEmailSignInMiss.matches(error) else { throw error }
            do {
                return try await dependencies.identityProvider.createEmailAccount(email, password: password)
            } catch {
                // 계정은 있었다 → 처음 실패는 비밀번호가 틀린 것이다.
                if AuthEmailSignInMiss.isEmailAlreadyInUse(error) {
                    throw AuthClientError.wrongEmailPassword
                }
                throw error
            }
        }
    }
}

// MARK: - 약관

extension AuthFlowViewModel {
    /// 약관 단계에 들어갈 때 서버 목록을 받아온다.
    ///
    /// 실패하면 목록을 비운 채 재시도 버튼을 띄운다 — 임의의 약관을 지어내지 않는다.
    /// 약관을 모르는 채로 가입시키면 동의 기록이 사실과 달라진다.
    func loadTerms(client: TermsAPIClient = .shared) async {
        guard !isLoadingTerms else { return }
        isLoadingTerms = true
        termsLoadFailed = false
        defer { isLoadingTerms = false }
        do {
            serverTerms = try await client.terms()
        } catch {
            serverTerms = []
            termsLoadFailed = true
            errorMessage = message(for: error)
        }
    }
}
