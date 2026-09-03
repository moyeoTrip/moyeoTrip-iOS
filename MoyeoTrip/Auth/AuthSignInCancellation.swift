//
//  AuthSignInCancellation.swift
//  MoyeoTrip
//
//  사용자가 스스로 그만둔 소셜 로그인은 실패가 아니다 (AUTH-SILENT-CASES-CANON R1·R2).
//
//  SDK 오류 모양을 아는 곳을 여기 한 곳으로 모은다. 뷰모델·화면이 카카오·애플·구글
//  각각의 오류 표현을 알게 되면 SDK 가 바뀔 때마다 "user canceled" 가 다시 새어 나온다.
//

import AuthenticationServices
import Foundation

enum AuthSignInCancellation {
    /// 이 오류가 "사용자가 취소한 것"인가.
    ///
    /// 각 SDK 진입점이 이미 `AuthIdentityError.canceledByUser` 로 바꿔 던지지만,
    /// 변환을 놓친 경로가 생겨도 화면에 SDK 원문이 뜨지 않도록 원본 오류도 함께 본다.
    nonisolated static func matches(_ error: Error) -> Bool {
        if case AuthIdentityError.canceledByUser = error { return true }

        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.canceled.rawValue {
            return true
        }
        // 구글 로그인 취소(`GIDSignInError.canceled`). GoogleSignIn 을 링크하지 않은 빌드에서도
        // 컴파일되도록 타입 대신 도메인·코드로 본다.
        if nsError.domain == googleSignInErrorDomain, nsError.code == googleSignInCanceledCode {
            return true
        }
        return false
    }

    nonisolated private static let googleSignInErrorDomain = "com.google.GIDSignIn"
    nonisolated private static let googleSignInCanceledCode = -5
}
