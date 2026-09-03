import Foundation

enum UITestRuntime {
    static let arguments = ProcessInfo.processInfo.arguments

    static var isEnabled: Bool {
        arguments.contains("UITEST_MODE")
    }

    /// 라이브 캡처. 캡처 라우팅은 그대로 두고 **데이터 차단만** 푼다.
    /// 캡처 도구가 `UITEST_LIVE_DATA` 와 `UITEST_ACCESS_TOKEN=<jwt>` 를 함께 넘긴다.
    static var usesLiveData: Bool {
        arguments.contains("UITEST_LIVE_DATA")
    }

    /// 관광 콘텐츠를 **목 샘플**로 그릴지.
    ///
    /// 목데이터 캡처에서는 결정적인 샘플을 쓰지만, **라이브 캡처는 예외다** —
    /// 실데이터를 보려고 찍는 캡처에서 관광 사진만 샘플이면 "이미지가 내려오는지"를 확인할 수 없다.
    static var usesMockTourism: Bool { isEnabled && !usesLiveData }

    /// 라이브 캡처용 액세스 토큰. 실행 인자로만 받고 어디에도 로그하지 않는다.
    static var liveAccessToken: String? {
        guard usesLiveData else { return nil }
        let token = arguments
            .first { $0.hasPrefix("UITEST_ACCESS_TOKEN=") }?
            .replacingOccurrences(of: "UITEST_ACCESS_TOKEN=", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let token, !token.isEmpty else { return nil }
        return token
    }

    /// 캡처 토큰을 **인증 모델이 쓰는 형태**로 돌려준다.
    ///
    /// `liveAccessToken` 이 `usesLiveData` 를 이미 요구하므로 실사용 경로에서는 항상 nil 이다 —
    /// 캡처 토큰이 새어 나갈 길이 없다.
    ///
    /// `refreshToken` 은 비어 있다. 이 세션을 받는 쪽은 **갱신하지 않고** 액세스 토큰만 써야 한다.
    static var liveCaptureTokens: AuthTokens? {
        guard let token = liveAccessToken else { return nil }
        return AuthTokens(accessToken: token, refreshToken: "")
    }

    /// 라이브 캡처 세션을 키체인에 심는다. 목 캡처(`UITEST_LIVE_DATA` 없음)에서는 아무것도 하지 않는다 —
    /// 번호별 비교 캡처가 서버 데이터로 오염되면 안 된다.
    ///
    /// `refreshToken` 은 일부러 비운다. 401 이면 조용히 실패하는 쪽이 안전하고,
    /// 갱신 응답이 키체인에 남는 경로를 아예 만들지 않는다.
    static func prepareLiveSessionIfNeeded(store: AuthSessionStoring = KeychainAuthSessionStore()) {
        guard let tokens = liveCaptureTokens else { return }
        try? store.save(tokens)
    }

    static var reducesVisualAnimations: Bool {
        arguments.contains("UITEST_FAST_ANIMATIONS")
    }

    static var mockNetworkDelayNanoseconds: UInt64 {
        // XCUIElement.tap() waits for app quiescence and commonly returns after
        // roughly 1.5 seconds. Keep this transient state alive just beyond that
        // boundary so the progress UI remains observable without the full delay.
        reducesVisualAnimations ? 1_800_000_000 : 2_500_000_000
    }

    static var mockRefreshDelayNanoseconds: UInt64 {
        reducesVisualAnimations ? 20_000_000 : 80_000_000
    }

    static var mockNicknameDelayNanoseconds: UInt64 {
        reducesVisualAnimations ? 30_000_000 : 1_500_000_000
    }
}
