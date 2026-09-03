import Foundation

protocol AuthIdentityProviding {
    func socialIDToken(for provider: AuthServiceProvider) async throws -> String
    func signInWithEmail(_ email: String, password: String) async throws -> String
    func createEmailAccount(_ email: String, password: String) async throws -> String
    func sendPasswordReset(to email: String) async throws
    /// 기기에 남아 있는 로그인 상태에서 새 idToken 을 받는다. 로그인 상태가 없으면 `nil`.
    ///
    /// 세션 복원 중 `40902`(회원 정보 미입력)로 되돌아갈 때 쓴다 (SIGNUP-GATE-CANON R2-1).
    /// 가입 API 는 Firebase idToken 을 요구하는데, 그 값은 세션에 저장되지 않는다.
    /// Firebase SDK 가 로그인 상태를 유지하므로 재로그인을 요구하지 않고 여기서 다시 받는다.
    func currentUserIDToken() async throws -> String?
}

extension AuthIdentityProviding {
    /// 기본값은 "유지된 로그인 상태 없음" — Firebase 를 쓰는 구현만 실제 토큰을 준다.
    func currentUserIDToken() async throws -> String? { nil }
}

struct MockAuthIdentityProvider: AuthIdentityProviding {
    var delayNanoseconds: UInt64 = 350_000_000

    func socialIDToken(for provider: AuthServiceProvider) async throws -> String {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return "demo-firebase-id-token-\(provider.pathComponent)"
    }

    func signInWithEmail(_ email: String, password: String) async throws -> String {
        try await mockEmailToken(email: email, password: password, operation: "signin")
    }

    func createEmailAccount(_ email: String, password: String) async throws -> String {
        try await mockEmailToken(email: email, password: password, operation: "signup")
    }

    func sendPasswordReset(to email: String) async throws {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        guard email.contains("@") else { throw AuthIdentityError.invalidEmail }
    }

    private func mockEmailToken(email: String, password: String, operation: String) async throws -> String {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        guard email.contains("@") else { throw AuthIdentityError.invalidEmail }
        guard password.count >= 6 else { throw AuthIdentityError.weakPassword }
        return "demo-firebase-id-token-email-\(operation)"
    }
}

enum AuthIdentityError: LocalizedError {
    case unsupportedProvider
    case invalidEmail
    case weakPassword
    case missingIDToken
    case missingConfiguration(String)
    /// 사용자가 소셜 로그인 화면에서 스스로 빠져나왔다 (AUTH-SILENT-CASES-CANON R1).
    /// 실패와 **다른 값**이라야 호출부가 조용히 아무것도 하지 않기를 고를 수 있다.
    case canceledByUser

    var errorDescription: String? {
        switch self {
        case .canceledByUser:
            // 취소는 화면에 띄우지 않는다 (정본 R2). 문구를 두면 언젠가 새어 나온다.
            return nil
        case .unsupportedProvider:
            return "현재 빌드에서 이 로그인 방식을 사용할 수 없어요."
        case .invalidEmail:
            return "이메일 주소를 다시 확인해주세요."
        case .weakPassword:
            return "비밀번호는 6자 이상 입력해주세요."
        case .missingIDToken:
            return "로그인 정보를 확인하지 못했어요. 다시 시도해주세요."
        case .missingConfiguration(let name):
            return "\(name) 설정이 필요해요."
        }
    }
}

#if canImport(FirebaseAuth)
import FirebaseAuth

struct FirebaseAuthIdentityProvider: AuthIdentityProviding {
    let authAPIClient: AuthAPIClientProtocol

    init(authAPIClient: AuthAPIClientProtocol = AuthAPIClient()) {
        self.authAPIClient = authAPIClient
    }

    func socialIDToken(for provider: AuthServiceProvider) async throws -> String {
        switch provider {
        case .google:
            return try await googleIDToken()
        case .apple:
            return try await AppleFirebaseSignIn().idToken()
        case .kakao:
            return try await KakaoFirebaseSignIn(authAPIClient: authAPIClient).idToken()
        case .email:
            throw AuthIdentityError.unsupportedProvider
        }
    }

    func signInWithEmail(_ email: String, password: String) async throws -> String {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return try await result.user.getIDToken()
    }

    func createEmailAccount(_ email: String, password: String) async throws -> String {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        return try await result.user.getIDToken()
    }

    func sendPasswordReset(to email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    /// Firebase 는 로그인 상태를 기기에 유지한다 — 재로그인 없이 새 idToken 을 받을 수 있다.
    func currentUserIDToken() async throws -> String? {
        guard let user = Auth.auth().currentUser else { return nil }
        return try await user.getIDToken()
    }

    private func googleIDToken() async throws -> String {
        #if canImport(GoogleSignIn) && canImport(UIKit)
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthIdentityError.missingConfiguration("GoogleService-Info.plist")
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        guard let presentingViewController = UIApplication.shared.authPresentingViewController else {
            throw AuthIdentityError.unsupportedProvider
        }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
        guard let googleIDToken = result.user.idToken?.tokenString else {
            throw AuthIdentityError.missingIDToken
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: googleIDToken,
            accessToken: result.user.accessToken.tokenString
        )
        let authResult = try await Auth.auth().signIn(with: credential)
        return try await authResult.user.getIDToken()
        #else
        throw AuthIdentityError.unsupportedProvider
        #endif
    }
}

#if canImport(GoogleSignIn) && canImport(UIKit)
import FirebaseCore
import GoogleSignIn
import UIKit

private extension UIApplication {
    @MainActor
    var authPresentingViewController: UIViewController? {
        let root = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        var presented = root
        while let next = presented?.presentedViewController {
            presented = next
        }
        return presented
    }
}
#endif
#endif

protocol AuthFCMTokenProviding {
    func currentToken() async -> String?
    func markRegisteredWithBackend(_ token: String?)
}

extension AuthFCMTokenProviding {
    func markRegisteredWithBackend(_ token: String?) {}
}

struct UnsupportedAuthFCMTokenProvider: AuthFCMTokenProviding {
    func currentToken() async -> String? { nil }
}

struct FirebaseMessagingAuthFCMTokenProvider: AuthFCMTokenProviding {
    func currentToken() async -> String? {
        await MoyeoPushNotificationManager.shared.currentToken()
    }

    func markRegisteredWithBackend(_ token: String?) {
        MoyeoPushNotificationManager.shared.markTokenRegisteredWithBackend(token)
    }
}
