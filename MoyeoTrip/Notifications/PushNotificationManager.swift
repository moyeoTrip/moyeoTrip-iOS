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

final class MoyeoPushNotificationManager: NSObject {
    static let shared = MoyeoPushNotificationManager()

    private let tokenDefaultsKey = "moyeo.fcmToken"
    private var isConfigured = false

    var cachedToken: String? {
        UserDefaults.standard.string(forKey: tokenDefaultsKey)
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

    func currentToken() async -> String? {
        #if canImport(FirebaseMessaging)
        do {
            let token = try await Messaging.messaging().token()
            store(token: token)
            return token
        } catch {
            return cachedToken
        }
        #else
        return cachedToken
        #endif
    }

    func setAPNSToken(_ deviceToken: Data) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken = deviceToken
        #endif
    }

    private func store(token: String) {
        UserDefaults.standard.set(token, forKey: tokenDefaultsKey)
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
        #if canImport(FirebaseCore)
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil,
           FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #endif
        MoyeoPushNotificationManager.shared.configure()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        MoyeoPushNotificationManager.shared.setAPNSToken(deviceToken)
    }
}
