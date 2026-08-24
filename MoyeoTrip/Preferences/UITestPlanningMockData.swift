import Foundation

/// 번호별 비교 캡처는 화면기획의 목데이터를 그대로 보여줘야 한다. 사용자 설정(최근 검색어 · 테마)과
/// 실제 빌드 버전은 기기마다 달라 캡처를 흔들기 때문에, 캡처·UI 테스트 실행에서는 이 값으로 고정한다.
///
/// 판정은 앱이 이미 쓰던 캡처 플래그(`UITEST_MODE`)를 그대로 재사용한다. 캡처 스크립트는
/// `UITEST_MODE` + `UITEST_SCREEN=...` + `UITEST_FORCE_LIGHT|DARK` 를 함께 넘긴다.
enum UITestPlanningMockData {
    /// 캡처 모드인지. `UITestRuntime.isEnabled` 와 같은 플래그를 쓴다.
    ///
    /// `UITEST_USER_PREFERENCES` 를 함께 넘기면 목데이터 고정을 끄고 실제 사용자 설정 경로로 동작한다.
    /// 로그인 없이 실기기·시뮬레이터에서 최근 검색어 영구 저장과 테마 순환을 확인할 때 쓴다
    /// (`UITEST_MODE` 없이는 로그인 화면에 막혀 설정 화면까지 가지 못한다). 캡처 스크립트는 이 인자를 넘기지 않는다.
    static var isActive: Bool {
        UITestRuntime.isEnabled && !UITestRuntime.arguments.contains("UITEST_USER_PREFERENCES")
    }

    /// 화면기획 12 검색의 최근 검색어
    static let recentSearches = ["경주", "단풍", "황리단길", "안동 한옥", "주왕산"]

    /// 화면기획 29 설정 › 정보 › 버전 값
    static let versionRowValue = "1.0.4 (최신)"

    /// 화면기획 29 설정의 버전 다이얼로그 본문
    static let versionDialogBody = "현재 설치된 버전은 1.0.4이며 최신 상태로 표시돼요."
}
