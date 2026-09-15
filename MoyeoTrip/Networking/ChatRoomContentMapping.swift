//
//  ChatRoomContentMapping.swift
//  MoyeoTrip
//
//  채팅방 읽기 응답 → 화면 모델 매핑. `ChatRoomContentAPIClient.swift` 가 500줄을 넘어 갈라냈다.
//

import Foundation

// MARK: - 화면 모델 매핑

extension ServerTripMapper {
    /// 순수 상수라 액터 격리가 필요 없다 — 뷰 밖(매퍼)에서도 부른다.
    nonisolated static let serverThreadIDPrefix = "server-chat-"

    static let serverNoticeIDPrefix = "server-notice-"

    static func roomID(fromThreadID threadID: String) -> Int64? {
        guard threadID.hasPrefix(serverThreadIDPrefix) else { return nil }
        return Int64(threadID.dropFirst(serverThreadIDPrefix.count))
    }

    /// 20-3 공지 카드의 화면 id → 서버 noticeId. 목데이터 공지면 nil 이다.
    static func noticeID(fromNoticeID noticeID: String) -> Int64? {
        guard noticeID.hasPrefix(serverNoticeIDPrefix) else { return nil }
        return Int64(noticeID.dropFirst(serverNoticeIDPrefix.count))
    }

    /// 내 채팅방 목록 항목 → 19 모임 목록 행.
    /// 서버가 주지 않는 값(지역·마스코트·멤버 목록)은 비워 두고 화면에서 숨긴다.
    static func chatThread(from room: ServerMyChatRoom) -> ChatThread {
        ChatThread(
            id: "\(serverThreadIDPrefix)\(room.roomId)",
            tripTitle: room.title,
            region: "",
            mascot: "",
            lastMessage: room.latestMessage?.content.replacingOccurrences(of: "\n", with: " ") ?? "",
            updatedAt: room.latestMessage.map { ServerDateTime.listTimeText(from: $0.sentAt) } ?? "",
            unreadCount: Int(room.unreadMessageCount ?? 0),
            statusSummary: statusSummary(for: room),
            statusDetail: "",
            members: [],
            messages: [],
            isReadOnly: !room.chatAvailable || room.ended,
            tripID: nil,
            recruitmentDeadline: room.ended ? "" : dDayText(room.recruitmentDDay),
            scheduleSummary: scheduleText(startDate: room.startDate, endDate: room.endDate),
            serverRoomID: room.roomId,
            thumbnailURL: MoyeoImageURL.resolve(room.thumbnail)
        )
    }

    /// "2/4명 · 여행 확정" — 서버가 인원을 주지 않는 지난 여행 요약이면 상태만 남긴다
    static func statusSummary(for room: ServerMyChatRoom) -> String {
        let state = statusText(for: room)
        guard let participantCount = room.participantCount, let maxParticipants = room.maxParticipants else {
            return state
        }
        return "\(participantCount)/\(maxParticipants)명 · \(state)"
    }

    static func statusText(for room: ServerMyChatRoom) -> String {
        // 불발된 방은 **끝났더라도 불발이라고 말한다.** 예전에는 `ended` 를 먼저 봐서
        // 불발된 방과 실제로 다녀온 방이 종료 탭에 똑같이 「여행 종료」로 섞였고,
        // 마지막 메시지를 읽어야만 구분됐다 (IOS-F130).
        if room.status == "CANCELLED" { return "모집 취소" }
        if room.ended { return "여행 종료" }
        switch room.status {
        case "CONFIRMED":
            return "여행 확정"
        default:
            return "모집중"
        }
    }

    static func dDayText(_ dDay: Int64?) -> String {
        guard let dDay else { return "" }
        return dDay <= 0 ? "D-Day" : "D-\(dDay)"
    }

    /// 서버 공지 → 20-3 공지 카드. 본문이 카드의 주인공이다 —
    /// 첫 줄을 떼어 제목으로 쓰던 것을 없앴다 (정본 `ATTACH-COMPOSER-CANON.md` §2).
    static func notice(from notice: ServerChatRoomNotice) -> TripNotice {
        return TripNotice(
            id: "\(serverNoticeIDPrefix)\(notice.noticeId)",
            body: notice.content ?? "",
            createdAt: ServerDateTime.noticeTimeText(from: notice.createdAt),
            isPinned: notice.pinned,
            authorName: notice.authorNickname
        )
    }

    /// 서버 메시지 → 20 말풍선. 프로필 이미지는 동행자 목록에서 따로 붙인다.
    static func chatMessage(from message: ServerChatMessage, currentUserID: Int64?) -> ChatMessage {
        ChatMessage(
            id: "server-message-\(message.messageId)",
            senderName: message.senderNickname,
            avatar: "",
            body: messageBody(message),
            time: ServerDateTime.bubbleTimeText(from: message.createdAt),
            isMine: message.senderId != nil && message.senderId == currentUserID,
            kind: message.isSystem ? .system : .text,
            // 카드로 그려야 하는 종류(장소·만날 위치·투표·정산 메모·사진)를 위해 원본을 실어 둔다
            server: message
        )
    }

    /// 카드 메시지는 서버가 준 값만 이어 붙인다 — 없는 값을 채우지 않는다
    static func messageBody(_ message: ServerChatMessage) -> String {
        switch message.type {
        case "POLL":
            guard let poll = message.poll else { return message.content }
            let options = poll.options.map { "· \($0.text) \($0.voteCount)" }.joined(separator: "\n")
            return options.isEmpty ? poll.question : "\(poll.question)\n\(options)"
        case "LOCATION":
            guard let name = message.location?.name, !name.isEmpty else { return message.content }
            return message.content.isEmpty ? name : "\(message.content)\n\(name)"
        case "TOURISM_CONTENT":
            guard let content = message.tourismContent else { return message.content }
            let address = content.address ?? ""
            let lines = [content.title, address].filter { !$0.isEmpty }
            return lines.joined(separator: "\n")
        default:
            return message.content
        }
    }

    static func member(from member: ServerChatRoomMember) -> Participant {
        Participant(
            id: "server-member-\(member.userId)",
            name: member.nickname,
            avatar: ""
        )
    }

    /// 목록에서 만든 스레드에 방 내부 읽기 응답을 얹는다.
    /// 서버가 주지 않는 값은 채우지 않고 빈 문자열로 남겨 화면에서 감춘다.
    static func chatThread(_ thread: ChatThread, applying content: ServerChatRoomContent) -> ChatThread {
        var updated = thread
        let memberList = content.memberList
        // 함수 참조 대신 클로저로 호출해 main-actor 격리를 유지한다(Swift 6).
        updated.members = memberList.members.map { member(from: $0) }
        updated.statusSummary = memberStatusSummary(thread: thread, memberList: memberList)
        // 내 메시지 판정은 토큰에서 온다 — 멤버 목록을 기다리지 않는다 (TAB-STATE-CANON R6).
        let currentUserID = content.currentUserID
        updated.messages = content.messages.map {
            chatMessage(from: $0, currentUserID: currentUserID)
        }
        updated.pinnedNotices = content.noticeHistory?.allNotices.map { notice(from: $0) } ?? []
        updated.isCurrentUserHost = memberList.members.contains { $0.me && $0.host }

        if let course = content.course {
            updated.courseName = course.title
            updated.courseSource = course.type == "CUSTOM" ? .custom : .linked
            updated.routeSummary = ServerCourseMapper.course(from: course).itinerary
        }

        if let detail = content.detail {
            // **모임 이름을 여기서 채운다.** 예전에는 채우지 않아서, 방 id 로 바로 들어오는
            // 진입(캡처·딥링크·알림)에서는 `stubThread` 의 빈 제목이 그대로 남아
            // 20-1 머리글에 **모임명이 아예 안 보였다** (사용자 지적 2026-09-09).
            if !detail.title.isEmpty { updated.tripTitle = detail.title }
            updated.price = detail.participationFee.map { "1인 \(decimalText($0))원" } ?? ""
            updated.genderRestriction = genderText(detail.genderRestriction)
            updated.ageRange = ageRangeText(minimumAge: detail.minimumAge, maximumAge: detail.maximumAge)
            updated.meetupSummary = meetupSummary(detail)
            // **읽기 전용 여부를 여기서 다시 정한다.**
            //
            // 예전에는 갱신하지 않아서, 라우트로 채팅방에 바로 들어올 때 쓰는
            // `stubThread` 의 `isReadOnly: true` 가 서버 응답이 온 뒤에도 그대로 남았다.
            // 그래서 **모집 중이고 시작일이 미래인 방까지** 「여행이 종료됐어요 ·
            // 읽기 전용 보관」으로 그려지고 입력창이 사라졌다 (사용자 지적, 2026-09-08).
            // 방을 가리지 않았고, 20 일반 채팅방·37 오프라인 채팅에도 그대로 실려 있었다.
            // 웹·안드로이드는 목록의 `ended` 를 쓰는데 **상세 응답에는 그 필드가 없다** —
            // 그래서 `status` 와 날짜로 같은 뜻을 계산한다(2026-09-08 실서버로 필드 확인).
            updated.isReadOnly = isReadOnlyRoom(status: detail.status, startDate: detail.startDate, endDate: detail.endDate)
            updated.recruitmentDeadline = updated.isReadOnly ? "" : dDayText(detail.recruitmentDDay)
            updated.scheduleSummary = scheduleSummaryText(detail)
        }

        return updated
    }

    /// 채팅이 읽기 전용인지 — 서버 목록의 `ended` 와 같은 뜻을 상세 응답으로 계산한다.
    ///
    /// `CANCELLED`(불발)·`COMPLETED`(완료)는 그 자체로 끝난 방이고,
    /// 그 밖에는 **여행 마지막 날이 지났으면** 끝난 것으로 본다
    /// (방 101 = `CONFIRMED` · 2026-08-28 출발인데 목록이 `ended: true` 로 준다).
    static func isReadOnlyRoom(status: String, startDate: String, endDate: String?, today: Date = Date()) -> Bool {
        if status == "CANCELLED" || status == "COMPLETED" { return true }
        guard let lastDay = ServerDateTime.date(fromDateOnly: endDate ?? startDate) else { return false }
        // 마지막 날 당일은 아직 여행 중이다 — 그 다음 날부터 끝난 것으로 센다.
        return Calendar.current.startOfDay(for: today) > Calendar.current.startOfDay(for: lastDay)
    }

    /// 동행자 목록이 주는 실제 인원으로 "2/4명 · 여행 확정"의 앞부분을 갈아 끼운다
    static func memberStatusSummary(thread: ChatThread, memberList: ServerChatRoomMemberList) -> String {
        let state = thread.statusSummary.components(separatedBy: " · ").last ?? ""
        let counts = "\(memberList.participantCount)/\(memberList.maxParticipants)명"
        return state.isEmpty || state.hasSuffix("명") ? counts : "\(counts) · \(state)"
    }

    /// 서버가 나이 제한을 주지 않으면(null) 그 줄을 비운다 — 기본값을 지어내지 않는다
    static func ageRangeText(minimumAge: Int?, maximumAge: Int?) -> String {
        switch (minimumAge, maximumAge) {
        case (let minimum?, let maximum?):
            return "\(minimum)~\(maximum)세"
        case (let minimum?, nil):
            return "\(minimum)세 이상"
        case (nil, let maximum?):
            return "\(maximum)세 이하"
        default:
            return ""
        }
    }

    /// "08:40 안동역 1번 출구 앞 광장"
    static func meetupSummary(_ detail: ServerChatRoomDetail) -> String {
        let time = timeText(fromDateTime: detail.meetingDateTime)
        let place = detail.meetingDetails ?? ""
        return [time, place].filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// "2026.09.20 (일) 당일치기 · 09:00 – 18:00"
    static func scheduleSummaryText(_ detail: ServerChatRoomDetail) -> String {
        let kind: TripScheduleKind = detail.tripType == "OVERNIGHT" ? .overnight : .dayTrip
        var parts = [
            scheduleText(startDate: detail.startDate, endDate: detail.endDate),
            kind.rawValue
        ]
        if let start = shortTime(detail.dayTripStartTime), let end = shortTime(detail.dayTripEndTime) {
            parts.append("\(start) – \(end)")
        }
        return parts.joined(separator: " · ")
    }
}
