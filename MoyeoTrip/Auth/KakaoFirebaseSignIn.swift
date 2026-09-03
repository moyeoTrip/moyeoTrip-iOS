import FirebaseAuth
import Foundation
import KakaoSDKAuth
import KakaoSDKCommon
import KakaoSDKUser

struct KakaoFirebaseSignIn {
    let authAPIClient: AuthAPIClientProtocol

    func idToken() async throws -> String {
        guard let nativeAppKey = Bundle.main.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String,
              !nativeAppKey.isEmpty else {
            throw AuthIdentityError.missingConfiguration("Kakao Native App Key")
        }
        let kakaoAccessToken = try await kakaoAccessToken()
        let customToken = try await authAPIClient.kakaoFirebaseCustomToken(accessToken: kakaoAccessToken)
        let result = try await Auth.auth().signIn(withCustomToken: customToken)
        return try await result.user.getIDToken()
    }

    private func kakaoAccessToken() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let completion: (OAuthToken?, Error?) -> Void = { token, error in
                if let error {
                    // 카카오 화면에서 뒤로 가기·취소한 것은 실패가 아니다 (AUTH-SILENT-CASES-CANON R1).
                    continuation.resume(throwing: Self.mapped(error))
                } else if let accessToken = token?.accessToken {
                    continuation.resume(returning: accessToken)
                } else {
                    continuation.resume(throwing: AuthIdentityError.missingIDToken)
                }
            }
            if UserApi.isKakaoTalkLoginAvailable() {
                UserApi.shared.loginWithKakaoTalk(completion: completion)
            } else {
                UserApi.shared.loginWithKakaoAccount(completion: completion)
            }
        }
    }

    /// 카카오 SDK 취소만 별도 값으로 갈라낸다 — 나머지 오류는 그대로 둔다.
    nonisolated private static func mapped(_ error: Error) -> Error {
        if case SdkError.ClientFailed(let reason, _) = error, reason == .Cancelled {
            return AuthIdentityError.canceledByUser
        }
        return error
    }
}
