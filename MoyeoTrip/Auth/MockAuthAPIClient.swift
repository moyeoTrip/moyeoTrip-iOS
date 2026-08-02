import Foundation

final class MockAuthAPIClient: AuthAPIClientProtocol {
    private let arguments: [String]
    private var nicknameBatch = 0
    private var generatedImages: [AuthProfileImageCandidate] = []

    init(arguments: [String] = []) {
        self.arguments = arguments
    }

    func login(
        provider: AuthServiceProvider,
        request: AuthLoginRequest
    ) async throws -> AuthLoginResponse {
        try await pause()
        if arguments.contains("UITEST_AUTH_LOGIN_FAIL") {
            throw AuthClientError.server(statusCode: 401, message: "로그인에 실패했어요. 다시 시도해주세요.")
        }
        if arguments.contains("UITEST_AUTH_EXISTING_USER") {
            return AuthLoginResponse(
                accessToken: "mock-access",
                refreshToken: "mock-refresh",
                isNewUser: false,
                signupState: .signupComplete,
                providerType: provider
            )
        }
        if arguments.contains("UITEST_AUTH_PROFILE_REQUIRED") {
            return AuthLoginResponse(
                accessToken: "mock-access",
                refreshToken: "mock-refresh",
                isNewUser: false,
                signupState: .profileImageRequired,
                providerType: provider
            )
        }
        return AuthLoginResponse(
            accessToken: nil,
            refreshToken: nil,
            isNewUser: true,
            signupState: .userInfoRequired,
            providerType: provider
        )
    }

    func signup(
        provider: AuthServiceProvider,
        request: AuthSignupRequest
    ) async throws -> AuthSignupResponse {
        try await pause()
        if arguments.contains("UITEST_AUTH_SIGNUP_FAIL") {
            throw AuthClientError.server(statusCode: 409, message: "선택한 이름을 사용할 수 없어요. 새 이름을 받아주세요.")
        }
        return AuthSignupResponse(
            accessToken: "mock-access",
            refreshToken: "mock-refresh",
            signupState: .profileImageRequired
        )
    }

    func kakaoFirebaseCustomToken(accessToken: String) async throws -> String {
        "mock-kakao-custom-token"
    }

    func refreshSession(refreshToken: String) async throws -> AuthSignupResponse {
        let signupState: AuthSignupState = arguments.contains("UITEST_AUTH_PROFILE_REQUIRED")
            ? .profileImageRequired
            : .signupComplete
        return AuthSignupResponse(
            accessToken: "mock-access-refreshed",
            refreshToken: "mock-refresh-refreshed",
            signupState: signupState
        )
    }

    func withdraw(accessToken: String) async throws {
        try await pause()
    }

    func fetchCandidates() async throws -> AuthNicknameCandidatesResponse {
        try await pause()
        if arguments.contains("UITEST_NICKNAME_REFRESH_FAIL"), nicknameBatch > 0 {
            throw AuthNicknameCandidateError.unavailable
        }
        let response: AuthNicknameCandidatesResponse
        if nicknameBatch == 0 {
            response = AuthNicknameViewModel.initialResponse
        } else {
            let batchIndex = min(nicknameBatch - 1, MockAuthNicknameCandidateProvider.defaultBatches.count - 1)
            let nicknames = MockAuthNicknameCandidateProvider.defaultBatches[batchIndex]
            response = AuthNicknameCandidatesResponse(
                selectionToken: "mock-selection-\(nicknameBatch + 1)",
                candidates: nicknames.enumerated().map { index, nickname in
                    AuthNicknameCandidate(
                        id: "batch-\(nicknameBatch + 1)-\(index)",
                        nickname: nickname,
                        color: ["GREEN", "PURPLE", "SKY_BLUE"][index]
                    )
                }
            )
        }
        nicknameBatch += 1
        return response
    }

    func profileImages(accessToken: String) async throws -> AuthProfileImagesResponse {
        try await pause()
        return AuthProfileImagesResponse(
            candidates: generatedImages,
            generationCount: generatedImages.count,
            remainingGenerationCount: max(3 - generatedImages.count, 0),
            signupState: .profileImageRequired
        )
    }

    func generateProfileImage(accessToken: String) async throws -> AuthProfileImageGenerationResponse {
        try await Task.sleep(nanoseconds: 2_500_000_000)
        let index = generatedImages.count + 1
        let candidate = AuthProfileImageCandidate(
            profileImageId: Int64(index),
            profileImageUrl: URL(string: "https://example.com/moyeo-profile-\(index).png")!,
            selected: false
        )
        generatedImages.append(candidate)
        return AuthProfileImageGenerationResponse(
            candidate: candidate,
            generationCount: generatedImages.count,
            remainingGenerationCount: max(3 - generatedImages.count, 0),
            signupState: .profileImageRequired
        )
    }

    func selectProfileImage(
        id: Int64,
        accessToken: String
    ) async throws -> AuthProfileImageSelectionResponse {
        try await pause()
        guard let candidate = generatedImages.first(where: { $0.id == id }) else {
            throw AuthClientError.server(statusCode: 404, message: "선택할 이미지를 찾지 못했어요.")
        }
        return AuthProfileImageSelectionResponse(
            selectedImage: AuthProfileImageCandidate(
                profileImageId: candidate.id,
                profileImageUrl: candidate.profileImageUrl,
                selected: true
            ),
            signupState: .signupComplete
        )
    }

    private func pause() async throws {
        try await Task.sleep(nanoseconds: 80_000_000)
    }
}
