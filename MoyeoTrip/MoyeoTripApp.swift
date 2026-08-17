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
    init() {
        SentryBootstrap.startIfConfigured()
        #if canImport(FirebaseCore)
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil,
           FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #endif
        #if canImport(KakaoSDKCommon)
        if let nativeAppKey = Bundle.main.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String,
           !nativeAppKey.isEmpty {
            KakaoSDK.initSDK(appKey: nativeAppKey)
        }
        #endif
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
