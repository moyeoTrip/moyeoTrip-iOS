//
//  ChatRoomAPIClient.swift
//  MoyeoTrip
//
//  모임(채팅방) 검색·상세·참가 신청·찜 실서버 연동 (연동 대상 1·2·9).
//

import Foundation

// MARK: - 응답 모델

/// 검색 결과 항목 (`GET /chat-rooms/search`).
///
/// 2026-08-24 서버 패치로 `dayTripStartTime`·`dayTripEndTime`·`recruitmentDDay`·`status`·`favorite`·
/// `meetingLatitude`·`meetingLongitude`·`meetingDetails`·`meetingDateTime` 9필드가 추가됐다.
/// 그래서 카드 배지·찜 하트를 그리려고 항목마다 상세를 부를 필요가 없다.
struct ServerChatRoomSummary: Decodable, Identifiable, Hashable {
    let roomId: Int64
    let title: String
    let description: String?
    let thumbnail: String?
    let tripType: String
    let startDate: String
    let endDate: String?
    /// 당일 여행 시간. 숙박이면 둘 다 null이라 표기를 숨긴다.
    /// 문서엔 `HH:mm` 인데 실제 응답은 `HH:mm:ss` 다 — 양쪽 모두 파싱한다.
    let dayTripStartTime: String?
    let dayTripEndTime: String?
    let recruitmentDeadlineDate: String
    let recruitmentDDay: Int64?
    /// `RECRUITING` · `CONFIRMED` · `CANCELLED`
    let status: String
    /// 로그인 사용자의 찜 여부
    let favorite: Bool
    /// 집합 장소 좌표. 미정이면 null이고, **둘 다 있을 때만** 지도 마커를 찍는다.
    let meetingLatitude: Double?
    let meetingLongitude: Double?
    /// 집합 장소 안내. 미정이면 null — "미정" 같은 문구를 지어내지 않고 표기를 숨긴다.
    let meetingDetails: String?
    let meetingDateTime: String

    let hostId: Int64
    let participantCount: Int
    let maxParticipants: Int
    let courseTitle: String
    let tags: [ServerCourseTag]

    var id: Int64 { roomId }

    var thumbnailURL: URL? {
        thumbnail.flatMap(URL.init(string:))
    }

    var tagNames: [String] {
        tags.map(\.name)
    }
}

struct ServerCourseTag: Decodable, Hashable {
    let tagId: Int64
    let name: String
}

struct ServerChatRoomDetail: Decodable, Hashable {
    struct ServerParticipant: Decodable, Hashable {
        let userId: Int64
        let profileImageUrl: String?
    }

    let roomId: Int64
    let title: String
    let description: String?
    let thumbnail: String?
    let tripType: String
    let startDate: String
    let endDate: String?
    let recruitmentDeadlineDate: String
    let tripNights: Int
    let tripDays: Int
    let dayTripStartTime: String?
    let dayTripEndTime: String?
    let meetingLatitude: Double?
    let meetingLongitude: Double?
    let meetingDetails: String?
    let meetingDateTime: String
    let participationFee: Int64?
    let genderRestriction: String
    let minimumAge: Int?
    let maximumAge: Int?
    let joinApprovalMode: String
    let recruitmentDDay: Int64?
    let hostId: Int64
    let hostProfileImageUrl: String?
    let participantCount: Int
    let maxParticipants: Int
    let status: String
    let favorite: Bool
    let latestPinnedNotice: ServerChatRoomNotice?
    let participants: [ServerParticipant]
}

struct ServerJoinEligibility: Decodable, Hashable {
    let canApply: Bool
}

enum ServerJoinResult: String, Decodable {
    case joined = "JOINED"
    case waitlisted = "WAITLISTED"
    case pendingApproval = "PENDING_APPROVAL"
}

struct ServerJoinResponse: Decodable {
    let roomId: Int64
    let result: ServerJoinResult
}

struct ServerFavoriteResponse: Decodable {
    let favorite: Bool
}

struct ServerWaitingRoom: Decodable, Identifiable, Hashable {
    let roomId: Int64
    let title: String
    let thumbnail: String?
    let applicationStatus: String
    let waitlistPosition: Int?
    let tripType: String
    let startDate: String
    let endDate: String?
    let meetingDateTime: String
    let meetingDetails: String?
    let participantCount: Int
    let maxParticipants: Int

    var id: Int64 { roomId }
}

/// 내 채팅방 목록 항목 (chat-rooms/my) — 19 모임 목록·26 내 여행이 쓴다.
/// 지난 여행 요약이면 서버가 status·인원·D-day를 null로 준다.
struct ServerMyChatRoom: Decodable, Identifiable, Hashable {
    let roomId: Int64
    let courseId: Int64
    let title: String
    let description: String?
    let startDate: String
    let endDate: String?
    let chatAvailable: Bool
    let thumbnail: String?
    let status: String?
    let recruitmentDDay: Int64?
    let ended: Bool
    let coursePublicationAvailable: Bool
    let participantCount: Int?
    let maxParticipants: Int?
    let unreadMessageCount: Int64?
    let latestMessage: ServerLatestChatMessage?

    var id: Int64 { roomId }

    var thumbnailURL: URL? {
        thumbnail.flatMap(URL.init(string:))
    }
}

struct ServerLatestChatMessage: Decodable, Hashable {
    let type: String
    let senderNickname: String
    let content: String
    let sentAt: String
}

/// chat-rooms/my 의 상태 필터
enum ServerMyChatRoomFilter: String {
    case all = "ALL"
    case recruiting = "RECRUITING"
    case confirmed = "CONFIRMED"
    case ended = "ENDED"
}

struct ServerKickHistory: Decodable, Identifiable, Hashable {
    let kickHistoryId: Int64
    let roomId: Int64
    let roomTitle: String
    let reason: String
    let kickedAt: String

    var id: Int64 { kickHistoryId }
}

// MARK: - 클라이언트

final class ChatRoomAPIClient: @unchecked Sendable {
    static let shared = ChatRoomAPIClient()

    /// 17 모집 만들기 요청은 파일 길이 때문에 `ServerChatRoomCreateRequest.swift` 의 확장에 있다.
    /// 그 확장이 같은 요청기를 쓰도록 모듈 내부까지 공개한다.
    let api: MoyeoAPIClient

    init(api: MoyeoAPIClient = .shared) {
        self.api = api
    }

    func search(keyword: String? = nil, limit: Int = 20) async throws -> [ServerChatRoomSummary] {
        var query = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let keyword, !keyword.isEmpty {
            query.append(URLQueryItem(name: "keyword", value: keyword))
        }
        return try await api.get("/api/v1/chat-rooms/search", query: query)
    }

    func detail(roomID: Int64) async throws -> ServerChatRoomDetail {
        try await api.get("/api/v1/chat-rooms/\(roomID)")
    }

    func joinEligibility(roomID: Int64) async throws -> ServerJoinEligibility {
        try await api.get("/api/v1/chat-rooms/\(roomID)/join-eligibility")
    }

    func apply(roomID: Int64, message: String?) async throws -> ServerJoinResponse {
        struct JoinRequest: Encodable {
            let applicationMessage: String?
        }
        return try await api.send(
            "/api/v1/chat-rooms/\(roomID)/applications",
            method: "POST",
            body: JoinRequest(applicationMessage: message)
        )
    }

    func cancelApplication(roomID: Int64) async throws {
        try await api.sendVoid("/api/v1/chat-rooms/\(roomID)/applications/me", method: "DELETE")
    }

    func toggleFavorite(roomID: Int64) async throws -> Bool {
        let response: ServerFavoriteResponse = try await api.send(
            "/api/v1/chat-rooms/\(roomID)/favorite",
            method: "POST"
        )
        return response.favorite
    }

    /// 내가 속한 채팅방 목록 — 19 모임 목록·26 내 여행
    func myRooms(filter: ServerMyChatRoomFilter = .all) async throws -> [ServerMyChatRoom] {
        try await api.get(
            "/api/v1/chat-rooms/my",
            query: [URLQueryItem(name: "filter", value: filter.rawValue)]
        )
    }

    func myWaitingRooms() async throws -> [ServerWaitingRoom] {
        try await api.get("/api/v1/chat-rooms/my-waiting")
    }

    func myKickHistories() async throws -> [ServerKickHistory] {
        try await api.get("/api/v1/chat-rooms/my-kick-histories")
    }
}

// MARK: - 화면 모델 매핑

enum ServerTripMapper {
    static let serverTripIDPrefix = "server-room-"

    static func roomID(fromTripID tripID: String) -> Int64? {
        guard tripID.hasPrefix(serverTripIDPrefix) else { return nil }
        return Int64(tripID.dropFirst(serverTripIDPrefix.count))
    }

    /// roomId만 아는 진입점(알림 등)용 빈 껍데기 — 상세 화면이 서버 상세로 다시 채운다
    static func placeholderTrip(roomID: Int64, title: String = "") -> TripRecruitment {
        TripRecruitment(
            id: "\(serverTripIDPrefix)\(roomID)",
            courseID: "",
            title: title,
            region: "",
            coverMascot: "",
            hostName: "",
            hostAvatar: "",
            schedule: "",
            meetupPoint: "",
            price: "",
            capacity: 0,
            joined: 0,
            minimumParticipants: 0,
            status: .open,
            summary: "",
            vibe: "",
            tags: [],
            route: [],
            participants: [],
            recruitmentDeadline: "",
            minimumAge: 0,
            maximumAge: 0,
            genderRestriction: "",
            serverRoomID: roomID
        )
    }

    /// 검색 결과 요약 → 모집 상세 진입용 최소 TripRecruitment.
    /// 서버가 주지 않는 값은 비워 두고, 화면은 서버 상세 응답으로 다시 채운다.
    static func trip(from summary: ServerChatRoomSummary) -> TripRecruitment {
        var meeting: MeetingPointDetails?
        if let coordinate = summary.meetingCoordinate {
            meeting = MeetingPointDetails(
                name: summary.meetingDetails ?? "",
                address: "",
                detail: "",
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                meetingTime: timeText(fromDateTime: summary.meetingDateTime)
            )
        }
        // `map(displayDate)` 처럼 함수 참조로 넘기면 main-actor 격리가 벗겨져 Swift 6 경고가 난다.
        // 호출을 이 컨텍스트 안에 둔다.
        var endDateText: String?
        if let endDate = summary.endDate {
            endDateText = displayDate(endDate)
        }

        return TripRecruitment(
            id: "\(serverTripIDPrefix)\(summary.roomId)",
            courseID: "",
            title: summary.title,
            region: "",
            coverMascot: "",
            hostName: "",
            hostAvatar: "",
            schedule: scheduleText(startDate: summary.startDate, endDate: summary.endDate),
            meetupPoint: summary.meetingDetails ?? "",
            price: "",
            capacity: summary.maxParticipants,
            joined: summary.participantCount,
            minimumParticipants: 0,
            status: status(from: summary.status),
            summary: summary.description ?? "",
            vibe: "",
            tags: summary.tagNames,
            route: [],
            participants: [],
            scheduleDetails: TripScheduleDetails(
                kind: summary.tripType == "OVERNIGHT" ? .overnight : .dayTrip,
                startDate: displayDate(summary.startDate),
                endDate: endDateText,
                startTime: shortTime(summary.dayTripStartTime),
                endTime: shortTime(summary.dayTripEndTime)
            ),
            meetingDetails: meeting,
            recruitmentDeadline: deadlineText(
                deadlineDate: summary.recruitmentDeadlineDate,
                dDay: summary.recruitmentDDay
            ),
            minimumAge: 0,
            maximumAge: 0,
            genderRestriction: "",
            serverRoomID: summary.roomId,
            heroImageURL: summary.thumbnailURL,
            serverCourseTitle: summary.courseTitle
        )
    }

    /// 채팅방 상세 응답 → 모집 상세 화면 모델
    static func trip(from detail: ServerChatRoomDetail, course: ServerTravelCourse?) -> TripRecruitment {
        let kind: TripScheduleKind = detail.tripType == "OVERNIGHT" ? .overnight : .dayTrip
        let meetingTime = timeText(fromDateTime: detail.meetingDateTime)

        var meeting: MeetingPointDetails?
        if let latitude = detail.meetingLatitude, let longitude = detail.meetingLongitude {
            meeting = MeetingPointDetails(
                name: detail.meetingDetails ?? "",
                address: "",
                detail: "",
                latitude: latitude,
                longitude: longitude,
                meetingTime: meetingTime
            )
        }

        return TripRecruitment(
            id: "\(serverTripIDPrefix)\(detail.roomId)",
            courseID: "",
            title: detail.title,
            region: "",
            coverMascot: "",
            hostName: "",
            hostAvatar: "",
            schedule: scheduleText(startDate: detail.startDate, endDate: detail.endDate),
            meetupPoint: detail.meetingDetails ?? "",
            price: detail.participationFee.map { "1인 \(decimalText($0))원" } ?? "무료 · 미정",
            capacity: detail.maxParticipants,
            joined: detail.participantCount,
            minimumParticipants: 0,
            status: status(from: detail.status),
            summary: detail.description ?? "",
            vibe: "",
            tags: course?.tags.map(\.name) ?? [],
            route: course?.places
                .sorted { ($0.dayNumber, $0.sequence) < ($1.dayNumber, $1.sequence) }
                .map(\.title) ?? [],
            participants: [],
            courseSource: course?.type == "CUSTOM" ? .custom : .linked,
            scheduleDetails: TripScheduleDetails(
                kind: kind,
                startDate: displayDate(detail.startDate),
                // 함수 참조로 넘기면 main-actor 격리가 벗겨져 Swift 6 에서 경고가 난다.
                endDate: detail.endDate.map { displayDate($0) },
                startTime: shortTime(detail.dayTripStartTime),
                endTime: shortTime(detail.dayTripEndTime)
            ),
            meetingDetails: meeting,
            recruitmentDeadline: deadlineText(
                deadlineDate: detail.recruitmentDeadlineDate,
                dDay: detail.recruitmentDDay
            ),
            minimumAge: detail.minimumAge ?? 0,
            maximumAge: detail.maximumAge ?? 0,
            genderRestriction: genderText(detail.genderRestriction),
            serverRoomID: detail.roomId,
            heroImageURL: detail.thumbnail.flatMap(URL.init(string:)),
            hostProfileImageURL: detail.hostProfileImageUrl.flatMap(URL.init(string:)),
            serverCourseTitle: course?.title
        )
    }

    static func status(from serverStatus: String) -> RecruitmentStatus {
        switch serverStatus {
        case "CONFIRMED":
            return .confirmed
        case "CANCELLED":
            return .cancelled
        default:
            return .open
        }
    }

    static func genderText(_ restriction: String) -> String {
        switch restriction {
        case "FEMALE_ONLY":
            return "여성만"
        case "MALE_ONLY":
            return "남성만"
        default:
            return "성별 무관"
        }
    }

    /// "2026-09-12" → "2026.09.12 (토)"
    static func displayDate(_ isoDate: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: isoDate) else { return isoDate }
        formatter.dateFormat = "yyyy.MM.dd (E)"
        return formatter.string(from: date)
    }

    /// "2026-09-12" + 종료일 → "2026.09.12 (토)" 또는 "2026.09.12 (토) ~ 2026.09.13 (일)"
    static func scheduleText(startDate: String, endDate: String?) -> String {
        guard let endDate, !endDate.isEmpty else { return displayDate(startDate) }
        return "\(displayDate(startDate)) ~ \(displayDate(endDate))"
    }

    /// 서버 시각 → 화면 표기 `HH:mm`.
    /// 문서는 `HH:mm`, 실제 응답은 `HH:mm:ss` 라 **양쪽 모두** 받는다.
    static func shortTime(_ time: String?) -> String? {
        guard let time, !time.isEmpty else { return nil }
        let parts = time.split(separator: ":")
        guard parts.count >= 2 else { return nil }
        return "\(parts[0]):\(parts[1])"
    }

    /// "2026-09-12T08:30:00" → "08:30"
    static func timeText(fromDateTime dateTime: String) -> String {
        guard let timePart = dateTime.split(separator: "T").last else { return "" }
        return String(timePart.prefix(5))
    }

    /// 마감일 → "D-17 · 9/9" (기존 목데이터 표기와 같은 형태)
    static func deadlineText(deadlineDate: String, dDay: Int64?) -> String {
        let parts = deadlineDate.split(separator: "-")
        let shortDate: String
        if parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]) {
            shortDate = "\(month)/\(day)"
        } else {
            shortDate = deadlineDate
        }
        guard let dDay else { return shortDate }
        return dDay <= 0 ? "D-Day · \(shortDate)" : "D-\(dDay) · \(shortDate)"
    }

    static func decimalText(_ value: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
