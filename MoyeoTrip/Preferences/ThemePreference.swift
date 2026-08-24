import Combine
import SwiftUI

/// 29 설정 › 화면 › 테마. 저장 상태는 3상태다 — `system` 이면 OS 설정을 그대로 따라간다.
enum MoyeoThemeMode: String, CaseIterable {
    case system
    case light
    case dark

    /// 화면기획 문구. 순환 표시에 쓰는 값이라 새 문구를 만들지 않는다.
    var rowValue: String {
        switch self {
        case .system:
            return "시스템 기본"
        case .light:
            return "라이트"
        case .dark:
            return "다크"
        }
    }

    /// `nil` 이면 SwiftUI 가 OS 설정을 따라간다 — 런타임에 OS 설정이 바뀌어도 즉시 반응한다.
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    /// 행을 탭했을 때의 다음 상태: 시스템 기본 → 라이트 → 다크 → 시스템 기본
    var next: MoyeoThemeMode {
        switch self {
        case .system:
            return .light
        case .light:
            return .dark
        case .dark:
            return .system
        }
    }

    /// 저장값 해석. 모르는 값·빈 값은 기본값(`system`)으로 되돌린다.
    static func resolved(from rawValue: String?) -> MoyeoThemeMode {
        guard let rawValue, let mode = MoyeoThemeMode(rawValue: rawValue) else { return .system }
        return mode
    }
}

@MainActor
final class MoyeoThemeStore: ObservableObject {
    // init 의 기본 인자는 호출자 컨텍스트에서 평가되므로 @MainActor 격리를 벗겨 둔다
    // (Swift 6 언어 모드에서는 격리된 정적 프로퍼티 참조가 에러다).
    nonisolated static let defaultsKey = "app-theme-mode"
    static let shared = MoyeoThemeStore()

    @Published private(set) var mode: MoyeoThemeMode

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = MoyeoThemeStore.defaultsKey) {
        self.defaults = defaults
        self.key = key
        mode = MoyeoThemeMode.resolved(from: defaults.string(forKey: key))
    }

    func update(_ mode: MoyeoThemeMode) {
        guard mode != self.mode else { return }
        self.mode = mode
        defaults.set(mode.rawValue, forKey: key)
    }

    func advance() {
        update(mode.next)
    }
}
