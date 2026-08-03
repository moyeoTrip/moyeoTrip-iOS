import Foundation

protocol AuthAPIClientProtocol: AuthNicknameCandidateProviding {
    func login(request: AuthLoginRequest) async throws -> AuthLoginResponse

    func signup(request: AuthSignupRequest) async throws -> AuthSignupResponse

    func kakaoFirebaseCustomToken(accessToken: String) async throws -> String

    func refreshSession(refreshToken: String) async throws -> AuthSignupResponse
    func linkedProviders(accessToken: String) async throws -> AuthLinkedProvidersResponse
    func linkProvider(idToken: String, fcmToken: String?, accessToken: String) async throws -> AuthLinkedProvidersResponse

    func withdraw(accessToken: String) async throws

    func profileImages(accessToken: String) async throws -> AuthProfileImagesResponse
    func generateProfileImage(accessToken: String) async throws -> AuthProfileImageGenerationResponse
    func selectProfileImage(
        id: Int64,
        accessToken: String
    ) async throws -> AuthProfileImageSelectionResponse
}

struct AuthAPIConfiguration: Equatable {
    let baseURL: URL

    static var current: AuthAPIConfiguration {
        let environment = ProcessInfo.processInfo.environment
        let bundleURL = Bundle.main.object(forInfoDictionaryKey: "MOYEO_API_BASE_URL") as? String
        let configuredURL = environment["MOYEO_API_BASE_URL"] ?? bundleURL
        let fallbackURL = URL(string: "https://moyeo-trip-api.jayden-bin.cc")!
        guard let configuredURL,
              let url = URL(string: configuredURL),
              ["http", "https"].contains(url.scheme?.lowercased()) else {
            return AuthAPIConfiguration(baseURL: fallbackURL)
        }
        return AuthAPIConfiguration(baseURL: url)
    }
}

final class AuthAPIClient: AuthAPIClientProtocol {
    private let configuration: AuthAPIConfiguration
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        configuration: AuthAPIConfiguration = .current,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    func login(request: AuthLoginRequest) async throws -> AuthLoginResponse {
        try await send(
            path: "/api/v1/auth/login",
            method: "POST",
            body: request
        )
    }

    func signup(request: AuthSignupRequest) async throws -> AuthSignupResponse {
        try await send(
            path: "/api/v1/auth/signup",
            method: "POST",
            body: request
        )
    }

    func kakaoFirebaseCustomToken(accessToken: String) async throws -> String {
        let response: KakaoFirebaseCustomTokenResponse = try await send(
            path: "/api/v1/auth/firebase/kakao/custom-token",
            method: "POST",
            body: KakaoFirebaseCustomTokenRequest(accessToken: accessToken)
        )
        return response.customToken
    }

    func refreshSession(refreshToken: String) async throws -> AuthSignupResponse {
        try await send(
            path: "/api/v1/auth/refresh",
            method: "POST",
            body: AuthSessionRefreshRequest(refreshToken: refreshToken)
        )
    }

    func linkedProviders(accessToken: String) async throws -> AuthLinkedProvidersResponse {
        try await send(
            path: "/api/v1/auth/providers",
            method: "GET",
            accessToken: accessToken
        )
    }

    func linkProvider(
        idToken: String,
        fcmToken: String?,
        accessToken: String
    ) async throws -> AuthLinkedProvidersResponse {
        try await send(
            path: "/api/v1/auth/providers",
            method: "POST",
            body: AuthLoginRequest(idToken: idToken, fcmToken: fcmToken),
            accessToken: accessToken
        )
    }

    func withdraw(accessToken: String) async throws {
        try await sendWithoutResponse(
            path: "/api/v1/users/me",
            method: "DELETE",
            accessToken: accessToken
        )
    }

    func fetchCandidates() async throws -> AuthNicknameCandidatesResponse {
        let response: NicknameCandidatesPayload = try await send(
            path: "/api/v1/auth/nickname-candidates",
            method: "POST"
        )
        return AuthNicknameCandidatesResponse(
            selectionToken: response.selectionToken,
            candidates: response.candidates.map { candidate in
                AuthNicknameCandidate(
                    id: candidate.nickname,
                    nickname: candidate.nickname,
                    adjective: candidate.adjective,
                    animal: candidate.animal,
                    color: candidate.color,
                    description: candidate.description
                )
            }
        )
    }

    func profileImages(accessToken: String) async throws -> AuthProfileImagesResponse {
        try await send(
            path: "/api/v1/users/me/profile-images",
            method: "GET",
            accessToken: accessToken
        )
    }

    func generateProfileImage(accessToken: String) async throws -> AuthProfileImageGenerationResponse {
        try await send(
            path: "/api/v1/users/me/profile-images",
            method: "POST",
            accessToken: accessToken,
            timeoutInterval: 180
        )
    }

    func selectProfileImage(
        id: Int64,
        accessToken: String
    ) async throws -> AuthProfileImageSelectionResponse {
        try await send(
            path: "/api/v1/users/me/profile-image",
            method: "PUT",
            body: AuthProfileImageSelectionRequest(profileImageId: id),
            accessToken: accessToken
        )
    }

    private func send<Response: Decodable>(
        path: String,
        method: String,
        accessToken: String? = nil,
        timeoutInterval: TimeInterval = 20
    ) async throws -> Response {
        try await send(
            path: path,
            method: method,
            bodyData: nil,
            accessToken: accessToken,
            timeoutInterval: timeoutInterval
        )
    }

    private func sendWithoutResponse(
        path: String,
        method: String,
        accessToken: String? = nil
    ) async throws {
        let url = configuration.baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthClientError.transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let backendError = try? decoder.decode(AuthBackendErrorResponse.self, from: data)
            throw AuthClientError.server(
                statusCode: httpResponse.statusCode,
                message: backendError?.errorMessage ?? "요청을 완료하지 못했어요. 잠시 후 다시 시도해주세요."
            )
        }
    }

    private func send<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        body: Body,
        accessToken: String? = nil,
        timeoutInterval: TimeInterval = 20
    ) async throws -> Response {
        let bodyData = try encoder.encode(body)
        return try await send(
            path: path,
            method: method,
            bodyData: bodyData,
            accessToken: accessToken,
            timeoutInterval: timeoutInterval
        )
    }

    private func send<Response: Decodable>(
        path: String,
        method: String,
        bodyData: Data?,
        accessToken: String?,
        timeoutInterval: TimeInterval
    ) async throws -> Response {
        let url = configuration.baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = bodyData
        request.timeoutInterval = timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if bodyData != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthClientError.transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let backendError = try? decoder.decode(AuthBackendErrorResponse.self, from: data)
            throw AuthClientError.server(
                statusCode: httpResponse.statusCode,
                message: backendError?.errorMessage ?? "요청을 완료하지 못했어요. 잠시 후 다시 시도해주세요."
            )
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw AuthClientError.invalidResponse
        }
    }
}

private struct NicknameCandidatesPayload: Decodable {
    let selectionToken: String
    let candidates: [NicknameCandidatePayload]
}

private struct NicknameCandidatePayload: Decodable {
    let nickname: String
    let adjective: String
    let animal: String
    let color: String
    let description: String
}

private struct KakaoFirebaseCustomTokenRequest: Encodable {
    let accessToken: String
}

private struct KakaoFirebaseCustomTokenResponse: Decodable {
    let customToken: String
}
