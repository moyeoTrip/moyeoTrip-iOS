import Foundation

/// 통신이 안 될 때 화면에 적는 문구. 같은 문장을 두 번 보여주지 않으려고
/// 화면 쪽에서도 이 값과 견주는 곳이 있다.
enum MoyeoUserFacingError {
    static let network = "인터넷 연결을 확인하고 다시 시도해 주세요."

    /// 실패를 화면에 적을 때 쓰는 문구. **예외 원문을 그대로 쓰지 않는다.**
    ///
    /// `URLError` 의 `localizedDescription` 은 기기 언어를 따라가긴 하지만
    /// "The Internet connection appears to be offline." 처럼 영어가 그대로 뜨는 경우가 있고,
    /// `DecodingError` 는 `keyNotFound(CodingKeys(stringValue: "noticeId"…` 같은 개발자용 문장이다.
    /// 예전에는 화면 곳곳이 `error.localizedDescription` 을 그대로 띄웠다
    /// (안드로이드 `UserFacingError.kt` 와 같은 취지 — QA IOS-F87·F26, 2026-09-13).
    ///
    /// 서버가 준 문구(`MoyeoAPIError.server`)는 한국어라 그대로 쓴다.
    ///
    /// - Parameter fallback: 이 동작이 실패했을 때 쓸 화면별 문구. 「무엇을」 못 했는지 담는다.
    static func message(_ error: Error, fallback: String) -> String {
        switch error {
        // 통신 자체가 안 된 것(DNS 실패·연결 끊김·타임아웃)은 어느 갈래로 들어와도 **같은 한 문장**이다.
        // `URLError.localizedDescription` 은 영어가 그대로 뜨거나 실패한 호스트가 섞여 나올 수 있어
        // 절대 쓰지 않는다(웹 `shared.jsx` · 안드 `UserFacingError.kt` 와 같은 문장).
        case is URLError:
            return network
        case is DecodingError:
            return fallback
        case let apiError as MoyeoAPIError:
            return message(apiError, fallback: fallback)
        case let authError as AuthClientError:
            return message(authError, fallback: fallback)
        // 앱이 정의한 나머지 오류(`AuthIdentityError` · `StompClient.StompError`)는 이미 한국어
        // 사용자 문구다. 문구가 없는 값(취소)은 fallback 으로 떨어진다.
        case let localized as LocalizedError:
            return localized.errorDescription ?? fallback
        default:
            return fallback
        }
    }

    private static func message(_ error: MoyeoAPIError, fallback: String) -> String {
        switch error {
        case .transport:
            return network
        case .invalidResponse:
            return fallback
        case .missingSession:
            return error.errorDescription ?? fallback
        case .server(_, _, let message):
            return serverMessage(message, fallback: fallback)
        }
    }

    private static func message(_ error: AuthClientError, fallback: String) -> String {
        switch error {
        case .transport:
            return network
        case .server(_, _, let message):
            return serverMessage(message, fallback: fallback)
        case .invalidConfiguration, .invalidResponse, .missingTokens, .wrongEmailPassword:
            return error.errorDescription ?? fallback
        }
    }

    /// 서버가 준 한국어 문구는 그대로 쓰되, 빈 문자열이면 화면 문구로 되돌린다.
    private static func serverMessage(_ message: String, fallback: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

extension Error {
    /// `MoyeoUserFacingError.message(_:fallback:)` 의 짧은 이름.
    func moyeoUserMessage(fallback: String) -> String {
        MoyeoUserFacingError.message(self, fallback: fallback)
    }
}
