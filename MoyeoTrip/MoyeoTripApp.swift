//
//  MoyeoTripApp.swift
//  MoyeoTrip
//
//  Created by 김한빈 on 5/29/26.
//

import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
#if canImport(KakaoSDKAuth) && canImport(KakaoSDKCommon)
import KakaoSDKAuth
import KakaoSDKCommon
#endif

@main
struct MoyeoTripApp: App {
    @UIApplicationDelegateAdaptor(MoyeoAppDelegate.self) private var appDelegate

    init() {
        // Firebase 를 가장 먼저 구성한다.
        //
        // SwiftUI 앱은 App.init() 이 앱 델리게이트의 didFinishLaunching 보다 먼저 돈다.
        // 델리게이트에서만 configure 하면, 그 사이에 Firebase 를 건드리는 코드(FirebaseMessaging 의
        // 알림 프록시 등)가 "The default Firebase app has not yet been configured" 경고를 남긴다.
        // 여기서 구성해 두면 그 창이 사라진다. 델리게이트 쪽 호출은 그대로 두되 이미 구성됐으면 건너뛴다.
        MoyeoFirebaseBootstrap.configureIfPossible()
        SentryBootstrap.startIfConfigured()
        #if canImport(KakaoSDKCommon)
        if let nativeAppKey = Bundle.main.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String,
           !nativeAppKey.isEmpty {
            KakaoSDK.initSDK(appKey: nativeAppKey)
        }
        #endif
        // 카카오 지도 SDK도 같은 네이티브 앱 키를 쓴다. 키가 없으면 목업 지도로 폴백한다.
        MoyeoMapRuntime.initializeIfPossible()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.font, MoyeoTypography.body)
                .transaction { transaction in
                    if UITestRuntime.reducesVisualAnimations {
                        transaction.animation = nil
                    }
                }
                .onOpenURL { url in
                    #if canImport(GoogleSignIn)
                    if GIDSignIn.sharedInstance.handle(url) {
                        return
                    }
                    #endif
                    #if canImport(KakaoSDKAuth)
                    if AuthApi.isKakaoTalkLoginUrl(url) {
                        _ = AuthController.handleOpenUrl(url: url)
                    }
                    #endif
                }
        }
    }
}
