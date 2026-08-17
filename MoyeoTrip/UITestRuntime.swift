import Foundation

enum UITestRuntime {
    static let arguments = ProcessInfo.processInfo.arguments

    static var isEnabled: Bool {
        arguments.contains("UITEST_MODE")
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
