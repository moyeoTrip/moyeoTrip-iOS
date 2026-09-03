//
//  AuthSignupGate.swift
//  MoyeoTrip
//
//  가입 게이트 정본 (docs/alignment/SIGNUP-GATE-CANON.md R1~R3, 2026-08-29).
//

import Foundation

extension Notification.Name {
    /// 일반 API 가 409 `40902`·`40918` 로 막혔다 — 루트(ContentView)가 가입 흐름으로 되돌린다.
    static let moyeoSignupGateRequired = Notification.Name("moyeo.signupGateRequired")
}

/// 서버가 "이 사용자는 아직 가입이 끝나지 않았다"고 알려주는 409 업무 코드.
///
/// **401 과 절대 섞지 않는다(R1).** 두 코드는 토큰 문제가 아니라 가입 단계 문제다.
/// 재발급 경로로 새면 서버는 계속 409 를 주고 클라는 계속 재발급을 시도해 무한 재시도가 된다.
enum MoyeoSignupGate {
    /// 닉네임·성별·생년월일 입력 전 (409).
    nonisolated static let userInfoRequiredCode = 40902
    /// 프로필 이미지 선택 전 또는 선택 이미지 누락 (409).
    nonisolated static let profileImageRequiredCode = 40918
    /// 이미 프로필 이미지 설정 완료 (409). 프로필 이미지 API 3종에서만 온다.
    nonisolated static let alreadyCompletedCode = 40919

    /// 되돌아가야 할 가입 단계.
    enum Step: String, Equatable {
        case userInfo
        case profileImage
    }

    /// 이 응답이 가입 게이트인지, 게이트라면 어느 단계로 보내야 하는지.
    nonisolated static func step(statusCode: Int, code: Int?) -> Step? {
        guard statusCode == 409, let code else { return nil }
        switch code {
        case userInfoRequiredCode:
            return .userInfo
        case profileImageRequiredCode:
            return .profileImage
        default:
            return nil
        }
    }

    /// 프로필 이미지 API 3종이 "이미 끝났다"고 답한 경우(R2).
    /// 오류로 그리면 가입이 끝난 사용자가 마지막 화면에 갇힌다 — 조용히 다음 화면으로 넘긴다.
    nonisolated static func isAlreadyCompleted(statusCode: Int, code: Int?) -> Bool {
        statusCode == 409 && code == alreadyCompletedCode
    }

    /// 가입 단계로 되돌리라고 루트에 알린다.
    ///
    /// 화면마다 따로 처리하면 어떤 화면은 오류 토스트를, 어떤 화면은 재시도를 하게 된다.
    /// 한 곳(네트워킹 계층)에서 알리고 한 곳(루트)에서 받는다.
    static func announce(_ step: Step) {
        NotificationCenter.default.post(name: .moyeoSignupGateRequired, object: step.rawValue)
    }
}

/// FCM 등록 토큰 정규화 (정본 R6).
///
/// 공백만 있는 문자열을 보내면 서버가 400 `40016 FCM_TOKEN_BLANK` 로 가입·로그인을 막는다.
/// 토큰이 없으면 필드를 **생략**한다 — `Optional` 이 `nil` 이면 `JSONEncoder` 가 키를 넣지 않는다.
enum AuthFCMToken {
    nonisolated static func normalized(_ token: String?) -> String? {
        guard let trimmed = token?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
