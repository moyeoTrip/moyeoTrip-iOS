//
//  ChatRoomContentAPIClient.swift
//  MoyeoTrip
//
//  참여 중인 채팅방 내부 읽기 연동 — 동행자·공지 이력·현재 로드맵·메시지.
//  화면기획 20 채팅방 · 20-1 사이드 메뉴 · 20-3 공지 이력이 이 응답을 쓴다.
//
//  서버는 방 참여자에게만 200을 주고 비참여자에게는 403을 준다.
//  403이면 아무것도 반환하지 않고 화면은 기존 목데이터를 그대로 유지한다.
//  쓰기(메시지 전송·공지 등록)는 서버가 500을 반환해 연동하지 않는다 — 읽기 전용이다.
//

import Foundation

// MARK: - 응답 모델

struct ServerChatRoomMember: Decodable, Identifiable, Hashable {
    let userId: Int64
    let nickname: String
    let profileImageUrl: String?
    let completedTripCount: Int
    let host: Bool
    let me: Bool

    var id: Int64 { userId }

    var profileImageURL: URL? {
        profileImageUrl.flatMap(URL.init(string:))
    }
}

struct ServerChatRoomMemberList: Decodable, Hashable {
    let participantCount: Int
    let maxParticipants: Int
    let waitlistCount: Int
    let members: [ServerChatRoomMember]

    var currentUserID: Int64? {
        members.first { $0.me }?.userId
    }

    /// senderId → 프로필 이미지. 메시지 응답에는 프로필 이미지가 없어 동행자 목록으로 채운다.
    var profileImageURLsByUserID: [Int64: URL] {
        var result: [Int64: URL] = [:]
        for member in members {
            if let url = member.profileImageURL {
                result[member.userId] = url
            }
        }
        return result
    }
}

struct ServerChatRoomNotice: Decodable, Identifiable, Hashable {
    let noticeId: Int64
    let content: String?
    let pinned: Bool
    let authorNickname: String
    let createdAt: String

    var id: Int64 { noticeId }
}

struct ServerChatRoomNoticeHistory: Decodable, Hashable {
    let pinnedNotices: [ServerChatRoomNotice]
    let unpinnedNotices: [ServerChatRoomNotice]

    /// 고정 공지가 먼저, 그 뒤에 지난 공지 — 20-3 섹션 순서와 같다
    var allNotices: [ServerChatRoomNotice] {
        pinnedNotices + unpinnedNotices
    }
}

struct ServerRoadmapPlace: Decodable, Identifiable, Hashable {
    let contentId: Int64
    let sequence: Int
    let title: String
    let thumbnail: String?
    let latitude: Double?
    let longitude: Double?
    let scheduledAt: String?
    let progress: String

    var id: String { "\(contentId)-\(sequence)" }

    var isCompleted: Bool { progress == "COMPLETED" }
    var isCurrent: Bool { progress == "CURRENT" }
}

struct ServerCurrentRoadmap: Decodable, Hashable {
    let active: Bool
    let dayNumber: Int?
    let totalDays: Int
    let currentPlace: ServerRoadmapPlace?
    let nextPlace: ServerRoadmapPlace?
    let places: [ServerRoadmapPlace]
}

struct ServerSharedTourismContent: Decodable, Hashable {
    let contentId: Int64
    let title: String
    let address: String?
    let thumbnail: String?
    let latitude: Double?
    let longitude: Double?
}

struct ServerSharedLocation: Decodable, Hashable {
    let latitude: Double
    let longitude: Double
    let name: String?
}

struct ServerChatPollOption: Decodable, Identifiable, Hashable {
    let optionId: Int64
    let text: String
    let voteCount: Int
    let votedByMe: Bool
    let voterNicknames: [String]?

    var id: Int64 { optionId }
}

struct ServerChatPoll: Decodable, Hashable {
    let question: String
    let anonymous: Bool
    let totalVoteCount: Int
    let options: [ServerChatPollOption]
}

struct ServerRepliedChatMessage: Decodable, Hashable {
    let messageId: Int64
    let senderNickname: String
    let content: String
}

struct ServerMentionedChatUser: Decodable, Hashable {
    let userId: Int64
    let nickname: String
}

struct ServerChatMessage: Decodable, Identifiable, Hashable {
    let messageId: Int64
    let type: String
    let senderId: Int64?
    let senderNickname: String
    let content: String
    let createdAt: String
    let imageUrl: String?
    let tourismContent: ServerSharedTourismContent?
    let location: ServerSharedLocation?
    let poll: ServerChatPoll?
    let replyTo: ServerRepliedChatMessage?
    let mentions: [ServerMentionedChatUser]?

    var id: Int64 { messageId }

    var isSystem: Bool { type == "SYSTEM" }

    var imageURL: URL? {
        imageUrl.flatMap(URL.init(string:))
    }
}

struct ServerChatMessagePage: Decodable, Hashable {
    let messages: [ServerChatMessage]
    let nextId: Int64?
    let hasNext: Bool
}

/// 채팅방 한 곳의 읽기 응답 묶음. 동행자 목록이 없으면(403) 참여 중인 방이 아니다.
struct ServerChatRoomContent: Hashable {
    let roomID: Int64
    let memberList: ServerChatRoomMemberList
    var detail: ServerChatRoomDetail?
    var course: ServerTravelCourse?
    var noticeHistory: ServerChatRoomNoticeHistory?
    var roadmap: ServerCurrentRoadmap?
    var messages: [ServerChatMessage] = []
}

// MARK: - 클라이언트

final class ChatRoomContentAPIClient: @unchecked Sendable {
    static let shared = ChatRoomContentAPIClient()

    private let api: MoyeoAPIClient
    private let roomAPI: ChatRoomAPIClient
    private let courseAPI: TravelCourseAPIClient

    init(
        api: MoyeoAPIClient = .shared,
        roomAPI: ChatRoomAPIClient = .shared,
        courseAPI: TravelCourseAPIClient = .shared
    ) {
        self.api = api
        self.roomAPI = roomAPI
        self.courseAPI = courseAPI
    }

    func members(roomID: Int64) async throws -> ServerChatRoomMemberList {
        try await api.get("/api/v1/chat-rooms/\(roomID)/members")
    }

    func notices(roomID: Int64) async throws -> ServerChatRoomNoticeHistory {
        try await api.get("/api/v1/chat-rooms/\(roomID)/notices")
    }

    func currentRoadmap(roomID: Int64) async throws -> ServerCurrentRoadmap {
        try await api.get("/api/v1/chat-rooms/\(roomID)/roadmap/current")
    }

    func messages(
        roomID: Int64,
        beforeMessageID: Int64? = nil,
        limit: Int = 50
    ) async throws -> ServerChatMessagePage {
        var query = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let beforeMessageID {
            query.append(URLQueryItem(name: "beforeMessageId", value: "\(beforeMessageID)"))
        }
        return try await api.get("/api/v1/chat-rooms/\(roomID)/messages", query: query)
    }

    /// 참여 중인 방이면 화면 하나가 필요한 읽기 응답을 한 번에 모아 온다.
    /// 동행자 목록이 403이면 nil을 돌려주고 화면은 목데이터를 유지한다.
    func content(roomID: Int64) async -> ServerChatRoomContent? {
        guard let memberList = try? await members(roomID: roomID) else { return nil }

        var content = ServerChatRoomContent(roomID: roomID, memberList: memberList)
        content.detail = try? await roomAPI.detail(roomID: roomID)
        content.course = try? await courseAPI.roomCourse(roomID: roomID).course
        content.noticeHistory = try? await notices(roomID: roomID)
        content.roadmap = try? await currentRoadmap(roomID: roomID)
        content.messages = (try? await messages(roomID: roomID))?.messages ?? []
        return content
    }
}

// MARK: - 날짜 파싱

/// 서버는 나노초까지 붙은 로컬 date-time을 준다 ("2026-08-24T08:06:50.072025").
enum ServerDateTime {
    static func date(from value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = formatter.date(from: value) { return date }
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return formatter.date(from: value)
    }

    /// 채팅 목록의 갱신 시각 — 오늘은 시각만, 어제는 "어제", 그 밖은 날짜
    static func listTimeText(from value: String) -> String {
        guard let date = date(from: value) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "a h:mm"
        } else if Calendar.current.isDateInYesterday(date) {
            return "어제"
        } else {
            formatter.dateFormat = "M월 d일"
        }
        return formatter.string(from: date)
    }

    /// 말풍선 시각 — "오후 1:30"
    static func bubbleTimeText(from value: String) -> String {
        guard let date = date(from: value) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter.string(from: date)
    }

    /// 공지 작성 시각 — "8월 24일 오전 1:12"
    static func noticeTimeText(from value: String) -> String {
        guard let date = date(from: value) else { return value }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 a h:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 화면 모델 매핑

extension ServerTripMapper {
    static let serverThreadIDPrefix = "server-chat-"

    static func roomID(fromThreadID threadID: String) -> Int64? {
        guard threadID.hasPrefix(serverThreadIDPrefix) else { return nil }
        return Int64(threadID.dropFirst(serverThreadIDPrefix.count))
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
            thumbnailURL: room.thumbnail.flatMap(URL.init(string:))
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
        if room.ended { return "여행 종료" }
        switch room.status {
        case "CONFIRMED":
            return "여행 확정"
        case "CANCELLED":
            return "모집 취소"
        default:
            return "모집중"
        }
    }

    static func dDayText(_ dDay: Int64?) -> String {
        guard let dDay else { return "" }
        return dDay <= 0 ? "D-Day" : "D-\(dDay)"
    }

    /// 서버 공지 → 20-3 공지 카드. 서버는 제목을 따로 주지 않아 첫 줄을 제목으로 쓴다.
    static func notice(from notice: ServerChatRoomNotice) -> TripNotice {
        let content = notice.content ?? ""
        var lines = content.components(separatedBy: "\n")
        let title = lines.first ?? ""
        lines.removeFirst()
        return TripNotice(
            id: "server-notice-\(notice.noticeId)",
            title: title,
            body: lines.joined(separator: "\n"),
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
            kind: message.isSystem ? .system : .text
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
        updated.members = memberList.members.map(member(from:))
        updated.statusSummary = memberStatusSummary(thread: thread, memberList: memberList)
        updated.messages = content.messages.map {
            chatMessage(from: $0, currentUserID: memberList.currentUserID)
        }
        updated.pinnedNotices = content.noticeHistory?.allNotices.map(notice(from:)) ?? []
        updated.isCurrentUserHost = memberList.members.contains { $0.me && $0.host }

        if let course = content.course {
            updated.courseName = course.title
            updated.courseSource = course.type == "CUSTOM" ? .custom : .linked
            updated.routeSummary = ServerCourseMapper.course(from: course).itinerary
        }

        if let detail = content.detail {
            updated.price = detail.participationFee.map { "1인 \(decimalText($0))원" } ?? ""
            updated.genderRestriction = genderText(detail.genderRestriction)
            updated.ageRange = ageRangeText(minimumAge: detail.minimumAge, maximumAge: detail.maximumAge)
            updated.meetupSummary = meetupSummary(detail)
            updated.recruitmentDeadline = thread.isReadOnly ? "" : dDayText(detail.recruitmentDDay)
            updated.scheduleSummary = scheduleSummaryText(detail)
        }

        return updated
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
