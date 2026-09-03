import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif

/// Firebase 기본 앱 구성 — **앱에서 가장 먼저 불러야 한다.**
///
/// SwiftUI 는 `App.init()` 이 앱 델리게이트의 `didFinishLaunchingWithOptions` 보다 먼저 돈다.
/// 델리게이트에서만 `FirebaseApp.configure()` 를 부르면, 그 사이에 Firebase 를 건드리는 코드가
/// `[FirebaseCore][I-COR000003] The default Firebase app has not yet been configured` 를 남긴다.
///
/// `GoogleService-Info.plist` 가 없으면 아무것도 하지 않는다 — 설정 파일 없이 configure 하면 크래시한다.
/// (실기기·시뮬레이터 모두 번들에 들어 있는지 확인하고 쓴다.)
enum MoyeoFirebaseBootstrap {
    static func configureIfPossible(bundle: Bundle = .main) {
        #if canImport(FirebaseCore)
        guard bundle.path(forResource: "GoogleService-Info", ofType: "plist") != nil,
              FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
        #endif
    }
}
