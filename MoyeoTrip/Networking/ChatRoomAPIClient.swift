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
/// 목록·지도 응답의 공통 요약.
///
/// **필수 필드는 두 응답 모두가 주는 것만이다.** 2026-08-26 검색 응답 축소로 `tripType`·`startDate`·
/// `recruitmentDeadlineDate`·`meetingDateTime`·`hostId`·`courseTitle` 등이 빠졌고, 지도 응답
/// (`GET /chat-rooms/map`)도 좌표 관련 필드만 더 줄 뿐 나머지는 주지 않는다.
/// 필수로 두면 **디코딩이 통째로 실패해 화면이 조용히 목데이터로 떨어진다** — 실제로 그렇게 됐었다.
/// 없는 값은 옵셔널로 받고, 화면은 값이 있을 때만 그 줄을 그린다.
struct ServerChatRoomSummary: Decodable, Identifiable, Hashable {
    let roomId: Int64
    let title: String
    let description: String?
    let thumbnail: String?
    let tripType: String?
    let startDate: String?
    let endDate: String?
    /// 당일 여행 시간. 숙박이면 둘 다 null이라 표기를 숨긴다.
    /// 문서엔 `HH:mm` 인데 실제 응답은 `HH:mm:ss` 다 — 양쪽 모두 파싱한다.
    let dayTripStartTime: String?
    let dayTripEndTime: String?
    let recruitmentDeadlineDate: String?
    let recruitmentDDay: Int64?
    /// `RECRUITING` · `CONFIRMED` · `CANCELLED`
    let status: String
    /// 로그인 사용자의 찜 여부
    let favorite: Bool
    /// 집합 장소 좌표. 미정이면 null이고, **둘 다 있을 때만** 지도 마커를 찍는다.
    /// 검색 응답에는 아예 없다 — 좌표가 오는 것은 지도 응답뿐이다.
    let meetingLatitude: Double?
    let meetingLongitude: Double?
    /// 집합 장소 안내. 미정이면 null — "미정" 같은 문구를 지어내지 않고 표기를 숨긴다.
    let meetingDetails: String?
    let meetingDateTime: String?

    let hostId: Int64?
    let participantCount: Int
    let maxParticipants: Int
    let courseTitle: String?
    let tags: [ServerCourseTag]

    var id: Int64 { roomId }

    var thumbnailURL: URL? {
        MoyeoImageURL.resolve(thumbnail)
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
    /// 여행 확정에 필요한 호스트 포함 최소 출발 인원. 18-4 확정 CTA 의 잠금 근거다.
    /// 서버는 늘 주지만(실서버 확인), 예전 응답을 캐시로 읽는 경우가 있어 옵셔널로 둔다.
    let minimumParticipants: Int?
    let maxParticipants: Int
    let status: String
    let favorite: Bool
    let latestPinnedNotice: ServerChatRoomNotice?
    let participants: [ServerParticipant]
    // 2026-08-26 BE 변경: 검색 응답이 카드용으로 축소되면서 코스 제목·태그가 상세로 옮겨졌다.
    // canApply 는 삭제된 join-eligibility 를 대체한다.
    let courseTitle: String?
    let tags: [ServerCourseTag]?
    let canApply: Bool?
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
        MoyeoImageURL.resolve(thumbnail)
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

    /// 26-1 찜한 모집 — 응답은 11 탐색 카드와 같은 `SearchChatRoomResponse` 다.
    /// 찜한 모집이 마감되거나 여행이 끝나도 목록에는 그대로 남는다(서버가 거르지 않는다).
    func favoriteRooms() async throws -> [ServerChatRoomSummary] {
        try await api.get("/api/v1/chat-rooms/my/favorites")
    }
}
