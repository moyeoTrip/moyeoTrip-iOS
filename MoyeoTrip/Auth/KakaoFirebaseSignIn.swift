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
                    continuation.resume(throwing: error)
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
}
