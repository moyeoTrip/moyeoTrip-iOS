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

    /// BE-32 (2026-09-15) — 서버가 새로 보내는 세 유형.
    ///
    /// 승격은 「내가 그 방의 참가자가 됐다」는 뜻이라 **채팅방**으로 간다.
    /// 확정·불발은 푸시에 모집 상세 목적지가 없어 `chatRoomId` 분기로 채팅방이 열린다
    /// (`RECRUITMENT_DEADLINE` 과 같은 사정) — 적어도 **홈으로 초기화되지는 않는다**.
    @Test func newChatRoomLifecycleTypesRouteToTheRoom() {
        let promoted = MoyeoPushDestination(userInfo: [
            "notificationType": "CHAT_ROOM_WAITLIST_PROMOTED",
            "chatRoomId": "101",
            // 승격의 `referenceId` 는 방 id 가 아니라 **참가자 행 id** 다 — 방은 이 값으로 찾지 않는다.
            "referenceId": "55501"
        ])
        #expect(promoted == .chatRoom(101))

        #expect(MoyeoPushDestination(userInfo: [
            "notificationType": "CHAT_ROOM_CONFIRMED", "chatRoomId": "102"
        ]) == .chatRoom(102))
        #expect(MoyeoPushDestination(userInfo: [
            "notificationType": "CHAT_ROOM_CANCELLED", "chatRoomId": "103"
        ]) == .chatRoom(103))

        // 방 id 가 없으면 지어내지 않는다 — 홈이 아니라 알림 목록까지만 데려간다.
        #expect(MoyeoPushDestination(userInfo: [
            "notificationType": "CHAT_ROOM_WAITLIST_PROMOTED"
        ]) == .meetings)
    }

    /// 세 유형이 종 아이콘(`default:`)으로 떨어지지 않는지. 떨어지면 목록에서 서로 구분되지 않는다.
    @Test func newChatRoomLifecycleTypesHaveTheirOwnIcons() {
        let fallback = ServerNotificationPresentation.style(for: "SOMETHING_UNKNOWN")
        #expect(fallback.icon == "bell.fill")

        let promoted = ServerNotificationPresentation.style(for: "CHAT_ROOM_WAITLIST_PROMOTED")
        let confirmed = ServerNotificationPresentation.style(for: "CHAT_ROOM_CONFIRMED")
        let cancelled = ServerNotificationPresentation.style(for: "CHAT_ROOM_CANCELLED")

        #expect(promoted.icon == "person.2.fill")
        #expect(confirmed.icon == "checkmark.circle.fill")
        // 불발은 강퇴와 같은 경고 계열이다.
        #expect(cancelled.icon == ServerNotificationPresentation.style(for: "CHAT_ROOM_KICKED").icon)
        #expect(cancelled.tint == MoyeoTheme.coral)
        #expect(confirmed.tint == MoyeoTheme.forest)
    }

    /// BE-33 (2026-09-15) — 화면이 약속하고도 서버가 만들지 않던 알림 세 종.
    ///
    /// 공지는 **채팅방**으로 간다(모집 상세로 보내면 정작 공지가 안 보인다).
    /// 승인·거절은 모집 상세가 맞지만 푸시에 그 목적지 case 가 없어 방으로 떨어진다 —
    /// 적어도 홈으로 초기화되지는 않는다(앱 안 목록은 모집 상세로 간다).
    @Test func applicationResultAndNoticeTypesKeepTheirContext() {
        #expect(MoyeoPushDestination(userInfo: [
            "notificationType": "CHAT_ROOM_NOTICE_POSTED",
            "chatRoomId": "201",
            // 공지의 `referenceId` 는 **공지 id** 다 — 방을 찾는 데 쓰지 않는다.
            "referenceId": "9001"
        ]) == .chatRoom(201))

        // 승인·거절의 `referenceId` 는 **신청 행 id** 다.
        #expect(MoyeoPushDestination(userInfo: [
            "notificationType": "CHAT_ROOM_APPLICATION_APPROVED",
            "chatRoomId": "202", "referenceId": "7001"
        ]) == .chatRoom(202))
        #expect(MoyeoPushDestination(userInfo: [
            "notificationType": "CHAT_ROOM_APPLICATION_REJECTED",
            "chatRoomId": "203", "referenceId": "7002"
        ]) == .chatRoom(203))

        let notice = ServerNotificationPresentation.style(for: "CHAT_ROOM_NOTICE_POSTED")
        let approved = ServerNotificationPresentation.style(for: "CHAT_ROOM_APPLICATION_APPROVED")
        let rejected = ServerNotificationPresentation.style(for: "CHAT_ROOM_APPLICATION_REJECTED")

        #expect(notice.icon == "pin.fill")
        #expect(approved.icon == "checkmark.circle.fill")
        #expect(rejected.icon == "xmark.circle.fill")
        #expect(notice.tint == MoyeoTheme.forest)
        #expect(approved.tint == MoyeoTheme.forest)
        // 거절만 위험색이다.
        #expect(rejected.tint == MoyeoTheme.coral)

        // 여섯 종 어느 것도 `default` 의 종 아이콘으로 떨어지지 않는다.
        let allNew = [
            "CHAT_ROOM_WAITLIST_PROMOTED", "CHAT_ROOM_CONFIRMED", "CHAT_ROOM_CANCELLED",
            "CHAT_ROOM_NOTICE_POSTED", "CHAT_ROOM_APPLICATION_APPROVED", "CHAT_ROOM_APPLICATION_REJECTED"
        ]
        #expect(allNew.allSatisfy { ServerNotificationPresentation.style(for: $0).icon != "bell.fill" })
    }
}
