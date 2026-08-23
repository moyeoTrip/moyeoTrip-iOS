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
