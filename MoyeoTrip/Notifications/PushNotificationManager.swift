import Foundation
import UIKit
import UserNotifications
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

extension Notification.Name {
    static let moyeoPushNotificationOpened = Notification.Name("moyeo.pushNotificationOpened")
    static let moyeoPushNotificationReceived = Notification.Name("moyeo.pushNotificationReceived")
    static let moyeoPushTokenDidRefresh = Notification.Name("moyeo.pushTokenDidRefresh")
    static let moyeoPushRegistrationFailed = Notification.Name("moyeo.pushRegistrationFailed")
}

enum MoyeoPushDestination: String, Equatable {
    case home
    case notifications
    case explore
    case meetings
    case feed
    case my

    init(userInfo: [AnyHashable: Any]) {
        let rawValue = (userInfo["screen"] ?? userInfo["route"] ?? userInfo["destination"])
            .map { String(describing: $0).lowercased() }
        switch rawValue {
        case "notification", "notifications", "notification-center":
            self = .notifications
        case "explore", "search", "course":
            self = .explore
        case "meeting", "meetings", "chat", "chatroom":
            self = .meetings
        case "feed", "post":
            self = .feed
        case "my", "profile", "settings":
            self = .my
        default:
            self = .home
        }
    }
}

enum MoyeoPushTokenRegistrationState {
    static func pendingToken(cachedToken: String?, registeredToken: String?) -> String? {
        guard let cachedToken, !cachedToken.isEmpty, cachedToken != registeredToken else { return nil }
        return cachedToken
    }
}

final class MoyeoPushNotificationManager: NSObject {
    static let shared = MoyeoPushNotificationManager()

    private let tokenDefaultsKey = "moyeo.fcmToken"
    private let registeredTokenDefaultsKey = "moyeo.registeredFCMToken"
    private var isConfigured = false

    var cachedToken: String? {
        UserDefaults.standard.string(forKey: tokenDefaultsKey)
    }

    var tokenAwaitingBackendRegistration: String? {
        MoyeoPushTokenRegistrationState.pendingToken(
            cachedToken: cachedToken,
            registeredToken: UserDefaults.standard.string(forKey: registeredTokenDefaultsKey)
        )
    }

    func configure() {
        guard !isConfigured else { return }
        isConfigured = true
        UNUserNotificationCenter.current().delegate = self
        #if canImport(FirebaseMessaging)
        Messaging.messaging().delegate = self
        #endif
        Task { @MainActor in
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    @MainActor
    func requestAuthorizationIfNeeded() async {
        guard !ProcessInfo.processInfo.arguments.contains("UITEST_MODE") else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        case .authorized, .provisional, .ephemeral:
            UIApplication.shared.registerForRemoteNotifications()
        case .denied:
            break
        @unknown default:
            break
        }
    }

    /// 서버로 보낼 최신 등록 토큰. 공백뿐이면 `nil` 이다 —
    /// 그대로 보내면 서버가 400 `40016 FCM_TOKEN_BLANK` 로 가입·로그인을 막는다 (SIGNUP-GATE-CANON R6).
    func currentToken() async -> String? {
        #if canImport(FirebaseMessaging)
        do {
            let token = try await Messaging.messaging().token()
            store(token: token)
            return AuthFCMToken.normalized(token)
        } catch {
            return AuthFCMToken.normalized(cachedToken)
        }
        #else
        return AuthFCMToken.normalized(cachedToken)
        #endif
    }

    func setAPNSToken(_ deviceToken: Data) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken = deviceToken
        #endif
    }

    func markTokenRegisteredWithBackend(_ token: String?) {
        guard let token = AuthFCMToken.normalized(token) else { return }
        UserDefaults.standard.set(token, forKey: registeredTokenDefaultsKey)
    }

    func handleBackgroundNotification(_ userInfo: [AnyHashable: Any]) {
        NotificationCenter.default.post(
            name: .moyeoPushNotificationReceived,
            object: MoyeoPushDestination(userInfo: userInfo),
            userInfo: userInfo
        )
    }

    private func store(token rawToken: String) {
        guard let token = AuthFCMToken.normalized(rawToken) else { return }
        let didChange = cachedToken != token
        UserDefaults.standard.set(token, forKey: tokenDefaultsKey)
        if didChange {
            NotificationCenter.default.post(name: .moyeoPushTokenDidRefresh, object: token)
        }
    }

    private func publishOpen(userInfo: [AnyHashable: Any]) {
        NotificationCenter.default.post(
            name: .moyeoPushNotificationOpened,
            object: MoyeoPushDestination(userInfo: userInfo)
        )
    }
}

extension MoyeoPushNotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        publishOpen(userInfo: response.notification.request.content.userInfo)
    }
}

#if canImport(FirebaseMessaging)
extension MoyeoPushNotificationManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, !fcmToken.isEmpty else { return }
        store(token: fcmToken)
    }
}
#endif

final class MoyeoAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // MoyeoTripApp.init() 에서 이미 구성했다면 건너뛴다.
        // 델리게이트만으로 시작하는 경로(테스트·확장)를 위해 호출은 남겨 둔다.
        MoyeoFirebaseBootstrap.configureIfPossible()
        MoyeoPushNotificationManager.shared.configure()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        MoyeoPushNotificationManager.shared.setAPNSToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NotificationCenter.default.post(name: .moyeoPushRegistrationFailed, object: error)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        MoyeoPushNotificationManager.shared.handleBackgroundNotification(userInfo)
        completionHandler(.newData)
    }
}
