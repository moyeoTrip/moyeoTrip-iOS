import Foundation

/// 29 설정 › 정보 › 버전. 최신 버전을 알려주는 서버 API가 없어 `(최신)` 같은 판정 문구는 붙이지 않고
/// 설치된 빌드 버전만 보여준다.
enum AppVersionInfo {
    /// `CFBundleShortVersionString` (예: `1.0`)
    static var shortVersion: String {
        value(for: "CFBundleShortVersionString")
    }

    /// `CFBundleVersion` (예: `1`)
    static var buildNumber: String {
        value(for: "CFBundleVersion")
    }

    /// 설정 행에 쓰는 값. **캡처에서도 실제 설치된 빌드 버전을 그대로 보여준다** —
    /// 화면기획 값(1.0.4)을 덮어씌우면 스크린샷이 있지도 않은 버전을 말하게 된다.
    static var rowValue: String {
        displayText(shortVersion: shortVersion, buildNumber: buildNumber)
    }

    /// 버전 다이얼로그 본문.
    static var dialogBody: String {
        "현재 설치된 버전은 \(rowValue)이에요."
    }

    /// `1.0 (1)` 형식. 빌드 번호가 없으면 버전만 보여준다.
    static func displayText(shortVersion: String, buildNumber: String) -> String {
        switch (shortVersion.isEmpty, buildNumber.isEmpty) {
        case (true, true):
            return ""
        case (true, false):
            return "(\(buildNumber))"
        case (false, true):
            return shortVersion
        case (false, false):
            return "\(shortVersion) (\(buildNumber))"
        }
    }

    private static func value(for key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? ""
    }
}
