import Foundation

enum AuthSignupState: String, Codable, Equatable {
    case userInfoRequired = "USER_INFO_REQUIRED"
    case profileImageRequired = "PROFILE_IMAGE_REQUIRED"
    case signupComplete = "SIGNUP_COMPLETE"
}

enum AuthServiceProvider: String, Codable, CaseIterable, Identifiable {
    case kakao = "KAKAO"
    case google = "GOOGLE"
    case email = "EMAIL"
    case apple = "APPLE"

    var id: String { rawValue }

    var pathComponent: String {
        rawValue.lowercased()
    }
}

enum AuthEmailMode: Equatable {
    case signIn
    case createAccount
}

struct AuthTokens: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
}

struct AuthSessionRefreshRequest: Encodable, Equatable {
    let refreshToken: String
}

struct AuthLoginRequest: Encodable, Equatable {
    let idToken: String
    let fcmToken: String?
}

struct AuthLoginResponse: Decodable, Equatable {
    let accessToken: String?
    let refreshToken: String?
    let isNewUser: Bool
    let signupState: AuthSignupState
    let providerType: AuthServiceProvider

    var tokens: AuthTokens? {
        guard let accessToken, let refreshToken else { return nil }
        return AuthTokens(accessToken: accessToken, refreshToken: refreshToken)
    }
}

struct AuthSignupRequest: Encodable, Equatable {
    let idToken: String
    let nicknameSelectionToken: String
    let nickname: String
    let gender: String
    let birthDate: String
    let fcmToken: String?
}

struct AuthSignupResponse: Decodable, Equatable {
    let accessToken: String
    let refreshToken: String
    let signupState: AuthSignupState

    var tokens: AuthTokens {
        AuthTokens(accessToken: accessToken, refreshToken: refreshToken)
    }
}

struct AuthLinkedProvidersResponse: Decodable, Equatable {
    let providers: Set<AuthServiceProvider>
}

struct AuthDisplayProfile: Codable, Equatable {
    let nickname: String
    let profileImageURL: URL?

    static func nickname(fromAccessToken accessToken: String) -> String? {
        let parts = accessToken.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload.append(String(repeating: "=", count: (4 - payload.count % 4) % 4))
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let nickname = json["nickName"] as? String else {
            return nil
        }
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct AuthProfileImageCandidate: Codable, Equatable, Identifiable {
    let profileImageId: Int64
    let profileImageUrl: URL
    let selected: Bool

    var id: Int64 { profileImageId }
}

struct AuthProfileImagesResponse: Decodable, Equatable {
    let candidates: [AuthProfileImageCandidate]
    let generationCount: Int
    let remainingGenerationCount: Int
    let signupState: AuthSignupState
}

struct AuthProfileImageGenerationResponse: Decodable, Equatable {
    let candidate: AuthProfileImageCandidate
    let generationCount: Int
    let remainingGenerationCount: Int
    let signupState: AuthSignupState
}

struct AuthProfileImageSelectionResponse: Decodable, Equatable {
    let selectedImage: AuthProfileImageCandidate
    let signupState: AuthSignupState
}

struct AuthProfileImageSelectionRequest: Encodable, Equatable {
    let profileImageId: Int64
}

struct AuthBackendErrorResponse: Decodable, Equatable {
    let code: Int?
    let errorMessage: String
}

enum AuthClientError: LocalizedError, Equatable {
    case invalidConfiguration
    case invalidResponse
    case missingTokens
    case server(statusCode: Int, message: String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "서버 주소를 확인해주세요."
        case .invalidResponse:
            return "서버 응답을 이해하지 못했어요. 잠시 후 다시 시도해주세요."
        case .missingTokens:
            return "로그인 정보가 완전하지 않아요. 다시 로그인해주세요."
        case .server(_, let message):
            return message
        case .transport:
            return "서버에 연결하지 못했어요. 네트워크 상태를 확인해주세요."
        }
    }
}
