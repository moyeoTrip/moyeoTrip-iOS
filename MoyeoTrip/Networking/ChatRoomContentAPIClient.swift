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
        MoyeoImageURL.resolve(profileImageUrl)
    }
}

struct ServerChatRoomMemberList: Decodable, Hashable {
    let participantCount: Int
    let maxParticipants: Int
    let waitlistCount: Int
    let members: [ServerChatRoomMember]

    /// 이 응답만 보고 판정한 내 userId. 말풍선 정렬에는 쓰지 않는다 —
    /// 그건 `ServerChatRoomContent.currentUserID` 가 토큰에서 먼저 읽는다 (TAB-STATE-CANON R6).
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
    /// 마지막 수정 시각 (BE-30). 한 번도 고치지 않은 공지는 `createdAt` 과 같다.
    ///
    /// **옵셔널이다** — 서버 배포 전에는 이 키가 아예 오지 않는다. 필수로 두면 공지 이력이
    /// 통째로 `invalidResponse` 가 된다(IOS-F74·F112 와 같은 결). 값이 없으면 수정 저장 때
    /// `expectedUpdatedAt` 을 보내지 않고, 서버는 검사를 건너뛴다(옛 클라이언트 호환 경로).
    let updatedAt: String?

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
        MoyeoImageURL.resolve(imageUrl)
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
    /// 이 페이지보다 **더 오래된 메시지가 남아 있는지** (서버 `hasNext`).
    /// 거짓이면 더 부르지 않는다 — 방 맨 위에서 헛된 조회를 되풀이하지 않게 한다.
    var hasOlderMessages = false
    /// 더 오래된 페이지를 부를 커서 (서버 `nextId`). 이 값보다 **작은** 메시지가 다음 페이지다.
    var olderMessagesCursor: Int64?
    /// 메시지 조회가 실제로 성공했는지.
    ///
    /// 예전에는 `(try? …)?.messages ?? []` 하나로 **「빈 방」과 「조회 실패」가 같은 값**이 됐다.
    /// 폴링이 한 번 실패하면 대화가 통째로 사라졌다가 다음 폴링에 되돌아온다.
    var didLoadMessages = false

    /// 말풍선을 왼쪽·오른쪽 어디에 그릴지 정하는 내 userId (TAB-STATE-CANON R6).
    ///
    /// **액세스 토큰 페이로드에서 동기로 읽는다.** 동행자 목록의 `me` 플래그를 기다리면
    /// 그 응답이 오기 전까지 내가 보낸 메시지가 남의 것처럼 왼쪽에 그려졌다가 뒤늦게 튄다.
    /// 세션을 읽지 못할 때만 목록으로 떨어진다.
    var currentUserID: Int64? {
        MoyeoCurrentUser.id ?? memberList.currentUserID
    }

    /// 최근 한 페이지 조회 결과를 얹는다. **실패(`nil`)면 아무것도 건드리지 않는다** —
    /// 빈 배열로 덮으면 통신이 한 번 끊길 때마다 대화가 사라진다.
    mutating func applyLatestPage(_ page: ServerChatMessagePage?) {
        guard let page else { return }
        messages = page.messages
        hasOlderMessages = page.hasNext
        olderMessagesCursor = page.nextId
        didLoadMessages = true
    }
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

    /// 방을 못 읽은 이유. `nil` 하나로 뭉뚱그리면 「통신이 잠깐 끊겼다」와
    /// 「이 방에서 나갔다·방이 사라졌다」를 화면이 구분할 수 없어, 입력창이 살아 있는 채로
    /// 옛 메시지가 남는다 (IOS-F92).
    enum ChatRoomAccess {
        case granted(ServerChatRoomContent)
        /// 403 미참가 · 404 방 없음 — 더는 이 방을 쓸 수 없다.
        case revoked(String)
        /// 통신 실패. 옛 내용을 그대로 두고 다시 시도하면 된다.
        case unavailable
    }

    /// 참여 중인 방이면 화면 하나가 필요한 읽기 응답을 한 번에 모아 온다.
    func access(roomID: Int64) async -> ChatRoomAccess {
        let memberList: ServerChatRoomMemberList
        do {
            memberList = try await members(roomID: roomID)
        } catch let error as MoyeoAPIError {
            guard case .server(let statusCode, let code, let message) = error else { return .unavailable }
            switch (statusCode, code) {
            case (403, _), (404, _):
                // 서버가 까닭을 줬으면 그것을 쓰고, **앱이 붙인 일반 문구뿐이면** 이 화면이 아는
                // 더 정확한 말을 쓴다 — 403 일반 문구보다 「이 채팅방을 …」이 낫다.
                let reason = message.trimmingCharacters(in: .whitespacesAndNewlines)
                return .revoked(
                    reason.isEmpty || MoyeoAPIStatusMessage.isGenerated(reason)
                        ? "이 채팅방을 더 이상 볼 수 없어요."
                        : reason
                )
            default:
                return .unavailable
            }
        } catch {
            return .unavailable
        }

        var content = ServerChatRoomContent(roomID: roomID, memberList: memberList)
        content.detail = try? await roomAPI.detail(roomID: roomID)
        content.course = try? await courseAPI.roomCourse(roomID: roomID).course
        content.noticeHistory = try? await notices(roomID: roomID)
        content.roadmap = try? await currentRoadmap(roomID: roomID)
        content.applyLatestPage(try? await messages(roomID: roomID))
        return .granted(content)
    }

    /// 이유를 가리지 않는 예전 판. 읽기 전용 판정이 필요 없는 화면만 쓴다.
    func content(roomID: Int64) async -> ServerChatRoomContent? {
        guard let memberList = try? await members(roomID: roomID) else { return nil }

        var content = ServerChatRoomContent(roomID: roomID, memberList: memberList)
        content.detail = try? await roomAPI.detail(roomID: roomID)
        content.course = try? await courseAPI.roomCourse(roomID: roomID).course
        content.noticeHistory = try? await notices(roomID: roomID)
        content.roadmap = try? await currentRoadmap(roomID: roomID)
        content.applyLatestPage(try? await messages(roomID: roomID))
        return content
    }
}
