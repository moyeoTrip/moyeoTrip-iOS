@testable import MoyeoTrip
import Testing

struct PushNotificationTests {
    @Test func destinationsUseSharedRouteAliases() {
        #expect(MoyeoPushDestination(userInfo: ["screen": "notification-center"]) == .notifications)
        #expect(MoyeoPushDestination(userInfo: ["route": "chatroom"]) == .meetings)
        #expect(MoyeoPushDestination(userInfo: ["destination": "post"]) == .feed)
        #expect(MoyeoPushDestination(userInfo: ["screen": "settings"]) == .my)
        #expect(MoyeoPushDestination(userInfo: [:]) == .home)
    }
}
