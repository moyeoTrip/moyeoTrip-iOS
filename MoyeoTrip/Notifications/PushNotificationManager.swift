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

enum MoyeoPushDestination: Equatable {
    case home
    case notifications
    case explore
    case meetings
    case feed
    case my
    /// 그 방의 채팅으로 바로 연다 (`chatRoomId`).
    case chatRoom(Int64)
    /// 그 방의 **모집 상세**로 연다 (`chatRoomId`).
    ///
    /// 확정·불발·신청 결과·마감 임박은 일정이 걸린 일이라 채팅이 아니라 모집 상세가 맞다.
    /// 예전에는 이 목적지가 없어 넷 다 `default:` 의 `chatRoomId` 분기로 **채팅방**이 열렸고,
    /// 같은 알림을 앱 안 목록에서 누를 때(모집 상세)와 한 칸 어긋났다.
    case tripDetail(Int64)
    /// 친구 관리 화면.
    case friends

    /// **서버가 실제로 보내는 키로 판정한다.**
    ///
    /// 예전에는 `screen`·`route`·`destination` 만 읽었는데, 서버 FCM 데이터에는 그런 키가 없고
    /// `notificationId`·`notificationType`·`referenceId`·`chatRoomId` 만 담긴다
    /// (BE `PushNotificationSender`). 그래서 어떤 푸시를 눌러도 `default` 로 떨어져
    /// **늘 홈 탭**이 열렸다 (TC NOTIF-029·030·031).
    ///
    /// 유형별 목적지는 앱 안 알림 목록(`SupportScreens` 의 `openServerNotification`)과 **같은 규칙**이다 —
    /// 같은 알림을 목록에서 누를 때와 푸시로 누를 때 다른 곳이 열리면 안 된다.
    init(userInfo: [AnyHashable: Any]) {
        // 예전 키(`screen`·`route`·`destination`)도 계속 받아 준다 — 탭 단위 지정용이다.
        if let legacy = (userInfo["screen"] ?? userInfo["route"] ?? userInfo["destination"])
            .map({ String(describing: $0).lowercased() }),
           let tab = Self.tab(forLegacyValue: legacy) {
            self = tab
            return
        }

        let type = (userInfo["notificationType"] ?? userInfo["type"]).map { String(describing: $0) }
        let chatRoomID = Self.int64(userInfo["chatRoomId"])

        switch type {
        case "FRIEND_REQUEST", "FRIEND_ACCEPTED":
            self = .friends
        case "FEED_LIKE", "FEED_COMMENT":
            // 글 하나를 바로 여는 통로가 런타임에 없다(피드 탭은 시작 시점 id 만 받는다).
            // 알림 목록까지 데려가면 **그 줄을 누를 때** 그 글이 열린다
            // (`openServerNotification` 의 `openServerFeed`) — 홈으로 떨구는 것보다 한 걸음이다.
            self = .notifications
        case "MARKETING":
            // 갈 곳이 없는 유형이다 — 알림 목록을 열어 내용만 보여 준다.
            self = .notifications
        case .some(let value) where Self.chatRoomTypes.contains(value):
            if let chatRoomID { self = .chatRoom(chatRoomID) } else { self = .meetings }
        case .some(let value) where Self.tripDetailTypes.contains(value):
            if let chatRoomID { self = .tripDetail(chatRoomID) } else { self = .meetings }
        default:
            // 모르는 유형이라도 **알림 목록**까지는 데려간다. 홈으로 초기화하면
            // 무엇 때문에 열렸는지 알 길이 없다.
            if let chatRoomID { self = .chatRoom(chatRoomID) } else { self = .notifications }
        }
    }

    /// 앱 안 알림 목록의 `chatRoomNotificationTypes` 와 같은 집합이다.
    private static let chatRoomTypes: Set<String> = [
        "CHAT_MESSAGE_RECEIVED",
        "CHAT_ROOM_CREATED",
        "MEETING_INFO_UPDATED",
        "NOTICE_CREATED",
        "TRIP_CONFIRMED",
        "CHAT_ROOM_KICKED",
        // BE-32 — 대기자 자동 합류. 목록과 같이 **채팅방**으로 보낸다.
        "CHAT_ROOM_WAITLIST_PROMOTED",
        // BE-33 — 새 공지도 방으로. 모집 상세로 보내면 정작 그 공지가 보이지 않는다.
        "CHAT_ROOM_NOTICE_POSTED"
    ]

    /// 앱 안 알림 목록에서 **모집 상세**로 가는 유형들(`openServerNotification` 의 `default:`).
    ///
    /// 셋 다 `chatRoomId` 를 함께 받으므로 방을 찾는 데 `referenceId` 는 쓰지 않는다 —
    /// 승인·거절의 `referenceId` 는 **신청 행 id** 라 방 id 가 아니다.
    private static let tripDetailTypes: Set<String> = [
        "CHAT_ROOM_CONFIRMED",
        "CHAT_ROOM_CANCELLED",
        "CHAT_ROOM_APPLICATION_APPROVED",
        "CHAT_ROOM_APPLICATION_REJECTED",
        "RECRUITMENT_DEADLINE"
    ]

    private static func tab(forLegacyValue value: String) -> MoyeoPushDestination? {
        switch value {
        case "notification", "notifications", "notification-center": return .notifications
        case "explore", "search", "course": return .explore
        case "meeting", "meetings", "chat", "chatroom": return .meetings
        case "feed", "post": return .feed
        case "my", "profile", "settings": return .my
        case "home": return .home
        default: return nil
        }
    }

    /// FCM 데이터 값은 **문자열**로 온다 — 숫자로 올 수도 있어 둘 다 받는다.
    private static func int64(_ value: Any?) -> Int64? {
        guard let value else { return nil }
        if let number = value as? Int64 { return number }
        if let number = value as? Int { return Int64(number) }
        return Int64(String(describing: value))
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

    /// 캐시된 토큰이 서버에 올린 것과 다르면 `PUT /notifications/fcm-token` 으로 올린다.
    ///
    /// 예전에는 토큰이 도는 것을 `.moyeoPushTokenDidRefresh` 로 알리기만 하고
    /// **구독자가 0** 이었고, `tokenAwaitingBackendRegistration` 을 읽는 곳도 없었다.
    /// 토큰은 가입·로그인 때 한 번만 올라가서, 그 뒤 Firebase 가 토큰을 새로 주는 순간부터
    /// 서버는 죽은 토큰으로 보내고 사용자에게는 푸시가 한 통도 오지 않았다 (IOS-F108).
    ///
    /// 실패해도 화면에 아무 말도 하지 않는다 — 사용자가 할 수 있는 일이 없고,
    /// 다음 실행·다음 토큰 회전에 다시 시도한다. (성공했다고 말하지도 않는다.)
    @discardableResult
    func syncTokenWithBackend() async -> Bool {
        guard let token = await currentToken(), tokenAwaitingBackendRegistration != nil else { return false }
        do {
            try await NotificationAPIClient.shared.updateFCMToken(token)
            markTokenRegisteredWithBackend(token)
            return true
        } catch {
            return false
        }
    }

    /// 로그아웃 직전에 서버에서 토큰을 지운다 — `DELETE /notifications/fcm-token`.
    ///
    /// 지우지 않으면 로그아웃한 기기로 그 사람의 알림이 계속 가서,
    /// 다음에 그 기기를 쓰는 사람의 잠금화면에 남의 대화가 뜬다 (IOS-F66).
    func unregisterTokenFromBackend() async {
        try? await NotificationAPIClient.shared.deleteFCMToken()
        clearBackendRegistrationState()
    }

    /// 「이 토큰은 서버에 올려 두었다」는 기억만 지운다.
    /// 계정이 바뀌면 **같은 토큰이라도 다시 올려야 한다** — 지우지 않으면 다음 사람의
    /// 토큰이 영영 등록되지 않는다.
    func clearBackendRegistrationState() {
        UserDefaults.standard.removeObject(forKey: registeredTokenDefaultsKey)
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
