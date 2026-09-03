//
//  AuthFlowStage.swift
//  MoyeoTrip
//
//  가입·로그인 흐름의 단계와 의존성 묶음. `AuthFlowModel.swift` 가 500줄을 넘어 갈라냈다.
//

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
    case taste
    /// 약관 동의. 서버 `GET /api/v1/terms` 목록을 그대로 그리고, 동의한 ID 를 회원가입에 함께 보낸다.
    /// 이 단계 없이 가입을 시도하면 서버가 400 `40012` 로 막는다.
    case terms
    case profileImage

    var progress: Double {
        switch self {
        case .splash: 0
        case .onboarding: 0.12
        case .login: 0.28
        case .emailLogin, .emailRegistration, .passwordReset: 0.34
        case .nickname: 0.44
        case .basics: 0.68
        case .taste: 0.82
        case .terms: 0.88
        case .profileImage: 0.94
        }
    }
}

struct AuthFlowDependencies {
    let apiClient: AuthAPIClientProtocol
    let identityProvider: AuthIdentityProviding
    let sessionStore: AuthSessionStoring
    let fcmTokenProvider: AuthFCMTokenProviding

    /// 캡처도 실제 앱과 같은 인증 경로를 탄다 (NO-MOCK-CANON R2) — 목 응답을 끼워 넣지 않는다.
    static var current: AuthFlowDependencies {
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
