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

    /// 공백만 있는 FCM 토큰은 서버가 400 `40016 FCM_TOKEN_BLANK` 로 막는다 (정본 R6).
    /// 전송 직전 한 곳에서 걸러 두면 토큰 출처가 늘어도 같은 규칙이 지켜진다.
    init(idToken: String, fcmToken: String?) {
        self.idToken = idToken
        self.fcmToken = AuthFCMToken.normalized(fcmToken)
    }
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
    /// 07 취향 단계에서 고른 **여행 스타일 서버 id** (정본 R4).
    ///
    /// 예전에는 고른 값이 어디로도 전송되지 않아 조용히 유실됐다.
    /// 고르지 않았으면 `nil` — `JSONEncoder` 가 키 자체를 빼고, 서버는 "선택 안 함"으로 저장한다.
    /// 표에 없는 id 를 보내면 400 `40015` 로 가입이 막힌다.
    let travelStyleIds: [Int64]?
    /// 07 취향 단계에서 고른 **관심 지역 서버 id**. 경북 시·군만 허용되고, 틀리면 400 `40014` 다.
    let interestedRegionIds: [Int64]?
    let fcmToken: String?
    /// 사용자가 동의한 **서버 약관의 ID**. 서버 필수 항목이다.
    ///
    /// 빠지면 서버가 400 `40012` "필수 약관에 모두 동의해야 회원가입할 수 있습니다." 로 막는다.
    /// 목록은 `GET /api/v1/terms` 가 주는 것을 그대로 쓴다 — 클라가 약관을 따로 갖지 않는다.
    let agreedTermIds: [Int64]

    /// 취향은 선택 항목이라 기본값을 둔다. FCM 토큰은 공백을 걸러 보낸다 (정본 R6).
    init(
        idToken: String,
        nicknameSelectionToken: String,
        nickname: String,
        gender: String,
        birthDate: String,
        travelStyleIds: [Int64]? = nil,
        interestedRegionIds: [Int64]? = nil,
        fcmToken: String?,
        agreedTermIds: [Int64]
    ) {
        self.idToken = idToken
        self.nicknameSelectionToken = nicknameSelectionToken
        self.nickname = nickname
        self.gender = gender
        self.birthDate = birthDate
        self.travelStyleIds = travelStyleIds
        self.interestedRegionIds = interestedRegionIds
        self.fcmToken = AuthFCMToken.normalized(fcmToken)
        self.agreedTermIds = agreedTermIds
    }
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

/// 액세스 토큰(JWT) 페이로드. 서버가 넣는 클레임은 `userId` · `nickName` · `exp` 셋뿐이다.
///
/// 여기 있는 값은 **네트워크 없이 즉시** 알 수 있다 — 같은 값을 서버 응답으로 다시 받아
/// 기다리면 첫 프레임이 틀리게 그려진다 (TAB-STATE-CANON R6).
struct AuthAccessTokenPayload: Equatable {
    let userId: Int64?
    let nickName: String?

    nonisolated init?(accessToken: String) {
        let parts = accessToken.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload.append(String(repeating: "=", count: (4 - payload.count % 4) % 4))
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        // 서버가 숫자로 넣지만 JSON 인코더에 따라 문자열로 올 수 있어 둘 다 받는다.
        if let number = json["userId"] as? NSNumber {
            userId = number.int64Value
        } else if let text = json["userId"] as? String {
            userId = Int64(text)
        } else {
            userId = nil
        }
        let nickname = (json["nickName"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        nickName = nickname.isEmpty ? nil : nickname
    }
}

struct AuthDisplayProfile: Codable, Equatable {
    let nickname: String
    let profileImageURL: URL?

    static func nickname(fromAccessToken accessToken: String) -> String? {
        AuthAccessTokenPayload(accessToken: accessToken)?.nickName
    }
}

/// 지금 로그인한 사용자의 신원. 저장된 액세스 토큰에서 **동기로** 읽는다 (TAB-STATE-CANON R6).
///
/// 멤버 목록 응답의 `me` 플래그를 기다리면 내가 보낸 메시지가 잠깐 남의 것으로 그려진다.
/// 이미 가진 값을 기다릴 이유가 없다.
enum MoyeoCurrentUser {
    static var id: Int64? {
        guard let tokens = (try? KeychainAuthSessionStore().load()) ?? nil else { return nil }
        return AuthAccessTokenPayload(accessToken: tokens.accessToken)?.userId
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
    /// `code` 는 서버 오류 본문의 업무 코드다. 상태 코드만으로는 같은 409 안에서
    /// 가입 게이트(`40902`·`40918`)와 "이미 완료"(`40919`)를 가려낼 수 없다 (정본 R1·R2).
    case server(statusCode: Int, code: Int?, message: String)
    case transport(String)
    /// 로그인 실패 뒤 계정 만들기가 `emailAlreadyInUse` 로 막힌 경우 —
    /// 계정은 있고 비밀번호가 틀린 것이다. (Email Enumeration Protection 때문에
    /// 로그인 응답만으로는 구분되지 않는다.)
    case wrongEmailPassword

    /// 프로필 이미지 API 3종이 "이미 프로필 이미지 설정을 완료했습니다"(409 `40919`)로 답한 경우 (정본 R2).
    var isSignupAlreadyCompleted: Bool {
        guard case .server(let statusCode, let code, _) = self else { return false }
        return MoyeoSignupGate.isAlreadyCompleted(statusCode: statusCode, code: code)
    }

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "서버 주소를 확인해주세요."
        case .invalidResponse:
            return "서버 응답을 이해하지 못했어요. 잠시 후 다시 시도해주세요."
        case .missingTokens:
            return "로그인 정보가 완전하지 않아요. 다시 로그인해주세요."
        case .server(_, _, let message):
            return message
        case .transport:
            return "서버에 연결하지 못했어요. 네트워크 상태를 확인해주세요."
        case .wrongEmailPassword:
            return "비밀번호가 올바르지 않아요. 비밀번호 재설정을 이용해주세요."
        }
    }
}

/// Firebase 이메일 로그인 실패가 "계정이 없거나 비밀번호가 틀림"인지 판별한다.
///
/// 이 프로젝트는 **Email Enumeration Protection** 이 켜져 있어 두 경우가 같은 코드로 온다.
/// 계정 만들기를 한 번 더 시도해 `emailAlreadyInUse` 가 나오는지로 가른다.
enum AuthEmailSignInMiss {
    private static let missCodes: Set<Int> = [
        17009, // wrongPassword
        17011, // userNotFound
        17004  // invalidCredential (열거 방지가 켜지면 위 둘이 모두 이 코드로 온다)
    ]

    static func matches(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == "FIRAuthErrorDomain" && missCodes.contains(nsError.code)
    }

    /// 17007 = emailAlreadyInUse
    static func isEmailAlreadyInUse(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == "FIRAuthErrorDomain" && nsError.code == 17007
    }
}
