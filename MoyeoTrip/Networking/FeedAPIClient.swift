//
//  FeedAPIClient.swift
//  MoyeoTrip
//
//  피드 실서버 연동 (연동 대상 8) — 목록·상세·좋아요·댓글.
//

import Foundation

/// `GET /api/v1/feeds/report-reasons` 항목.
struct ServerFeedReportReason: Decodable, Hashable, Identifiable {
    let reason: String
    let displayName: String

    var id: String { reason }
}

struct ServerFeedPage: Decodable, Hashable {
    let feeds: [ServerFeed]
    let nextId: Int64?
}

struct ServerFeed: Decodable, Identifiable, Hashable {
    struct Author: Decodable, Hashable {
        let userId: Int64
        let nickname: String
        let profileImageUrl: String?
    }

    struct FeedImage: Decodable, Hashable {
        let imageId: Int64
        let imageUrl: String
        let sequence: Int
    }

    struct Trip: Decodable, Hashable {
        let chatRoomId: Int64
        let courseId: Int64
        let courseTitle: String
        let startDate: String
        let endDate: String?
        let places: [ServerFeedPlace]
    }

    let feedId: Int64
    let author: Author
    let content: String
    let visibility: String
    /// 신고 누적(서로 다른 이용자 3건)으로 비공개 처리된 피드.
    ///
    /// 작성자가 자기 피드를 볼 때만 `true` 로 온다. 작성자가 직접 고른 `PRIVATE` 는 `false` 라
    /// 둘을 구분할 수 있다 — 화면은 이 값으로만 "신고되어 비공개 처리되었습니다" 안내를 띄운다.
    /// 목록 응답에는 없을 수 있어 옵셔널로 둔다.
    let hiddenByReports: Bool?
    let images: [FeedImage]
    let trip: Trip
    let likeCount: Int64
    let commentCount: Int64
    let liked: Bool
    let createdAt: String

    var id: Int64 { feedId }
}

struct ServerFeedPlace: Decodable, Hashable {
    let tourismContentId: Int64
    let title: String
    let latitude: Double?
    let longitude: Double?
    let dayNumber: Int
    let sequence: Int
    let visitTime: String?
}

/// 23-1 댓글 한 묶음. `GET /feeds/{id}/comments` 는 **2026-09-02 부터 객체**를 준다
/// (그 전에는 댓글 배열 단독이었다 — 파괴적 변경이라 배열 디코딩은 그 날부터 실패했다).
///
/// `comments` 는 **최상위 댓글만** 최신 id 부터 오고, 대댓글은 각 항목의 `replies` 에 그대로 있다.
/// 다음 묶음이 있으면 마지막 최상위 댓글 id 가 `nextId`, 마지막 묶음이면 `nil` 이다 —
/// `GET /feeds` 의 `ServerFeedPage` 와 같은 커서 규칙이다.
struct ServerFeedCommentPage: Decodable, Hashable {
    let comments: [ServerFeedComment]
    let nextId: Int64?
}

/// 23-1 댓글. 서버는 대댓글을 `replies` 로 중첩해 내려준다.
struct ServerFeedComment: Decodable, Identifiable, Hashable {
    let commentId: Int64
    let author: ServerFeed.Author?
    let content: String?
    let createdAt: String?
    let replies: [ServerFeedComment]?

    var id: Int64 { commentId }

    var replyList: [ServerFeedComment] { replies ?? [] }
}

struct ServerFeedLikeResponse: Decodable {
    let liked: Bool
    let likeCount: Int64?
}

final class FeedAPIClient: @unchecked Sendable {
    static let shared = FeedAPIClient()

    private let api: MoyeoAPIClient

    init(api: MoyeoAPIClient = .shared) {
        self.api = api
    }

    /// tab: DISCOVER(전체 공개) / FRIENDS(친구)
    func feeds(tab: String = "DISCOVER", beforeFeedID: Int64? = nil, limit: Int = 20) async throws -> ServerFeedPage {
        var query = [
            URLQueryItem(name: "tab", value: tab),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let beforeFeedID {
            query.append(URLQueryItem(name: "beforeFeedId", value: "\(beforeFeedID)"))
        }
        return try await api.get("/api/v1/feeds", query: query)
    }

    func feed(id: Int64) async throws -> ServerFeed {
        try await api.get("/api/v1/feeds/\(id)")
    }

    func toggleLike(feedID: Int64) async throws {
        try await api.sendVoid("/api/v1/feeds/\(feedID)/like", method: "POST")
    }

    /// 신고 사유 목록. 코드와 표시 문구를 서버가 함께 준다 — 클라가 문구를 갖지 않는다.
    func reportReasons() async throws -> [ServerFeedReportReason] {
        try await api.get("/api/v1/feeds/report-reasons")
    }

    /// 피드 신고. 성공은 204 다.
    ///
    /// `details` 는 선택이고 서버 상한이 300자다. 서로 다른 이용자의 신고 3건이 모이면
    /// 서버가 `visibility=PRIVATE` · `hiddenByReports=true` 로 바꾼다.
    /// 오류: 본인 피드 400 · 권한 없음 403 · 없는 피드 404 · 중복 신고 409 `40917`(실서버 확인).
    func report(feedID: Int64, reason: String, details: String? = nil) async throws {
        struct ReportRequest: Encodable {
            let reason: String
            let details: String?
        }
        let trimmed = details?.trimmingCharacters(in: .whitespacesAndNewlines)
        try await api.sendVoid(
            "/api/v1/feeds/\(feedID)/reports",
            method: "POST",
            body: ReportRequest(
                reason: reason,
                details: (trimmed?.isEmpty ?? true) ? nil : String(trimmed!.prefix(300))
            )
        )
    }

    /// 23-1 댓글 목록 — id 커서 페이지네이션 (2026-09-02 서버 변경, 실서버 확인).
    ///
    /// `beforeCommentID` 는 **첫 요청에서 생략**한다. 응답의 `nextId` 를 그대로 다음 요청에 넣으면
    /// 그 id 보다 작은 최상위 댓글이 온다. `limit` 은 최상위 댓글 수이고 서버가 1~50 으로 보정한다
    /// — 대댓글은 페이지네이션 대상이 아니라 각 최상위 댓글의 `replies` 에 전부 들어 있다.
    func comments(
        feedID: Int64,
        beforeCommentID: Int64? = nil,
        limit: Int = 20
    ) async throws -> ServerFeedCommentPage {
        var query = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let beforeCommentID {
            query.append(URLQueryItem(name: "beforeCommentId", value: "\(beforeCommentID)"))
        }
        return try await api.get("/api/v1/feeds/\(feedID)/comments", query: query)
    }

    func postComment(feedID: Int64, content: String, parentCommentID: Int64? = nil) async throws {
        struct CommentRequest: Encodable {
            let content: String
            let parentCommentId: Int64?
        }
        try await api.sendVoid(
            "/api/v1/feeds/\(feedID)/comments",
            method: "POST",
            body: CommentRequest(content: content, parentCommentId: parentCommentID)
        )
    }
}

// MARK: - 화면 모델 매핑

enum ServerFeedMapper {
    nonisolated static let serverFeedIDPrefix = "server-feed-"

    /// 캡처·딥링크로 **댓글 화면에 바로 들어올 때** 쓰는 최소 게시물.
    ///
    /// 그 경로에는 피드 목록이 아직 없어서 `feedPosts` 에서 찾을 수 없다. 예전에는 그럴 때
    /// 빈 상태로 떨어져, 서버에 댓글이 있는데도 "아직 댓글이 없어요." 가 찍혔다.
    /// 화면이 `serverFeedID` 로 댓글을 직접 받으므로 여기서는 그 값만 실어 보낸다.
    nonisolated static func stubPost(serverFeedID feedID: Int64) -> FeedPost {
        var post = FeedPost(
            id: "\(serverFeedIDPrefix)\(feedID)",
            authorName: "",
            authorAvatar: "",
            region: "",
            createdAt: "",
            photoMascot: "",
            caption: "",
            tags: [],
            route: [],
            visibility: .publicAll,
            likeCount: 0,
            commentCount: 0,
            mood: .forest
        )
        post.serverFeedID = feedID
        return post
    }

    /// 화면 id → 서버 피드 id. 목 id 면 nil 이다.
    nonisolated static func feedID(fromPostID postID: String) -> Int64? {
        guard postID.hasPrefix(serverFeedIDPrefix) else { return nil }
        return Int64(postID.dropFirst(serverFeedIDPrefix.count))
    }

    static func post(from feed: ServerFeed) -> FeedPost {
        FeedPost(
            id: "\(serverFeedIDPrefix)\(feed.feedId)",
            authorName: feed.author.nickname,
            authorAvatar: "",
            region: "",
            createdAt: createdAtText(feed.createdAt),
            photoMascot: "",
            caption: feed.content,
            tags: [],
            route: feed.trip.places
                .sorted { ($0.dayNumber, $0.sequence) < ($1.dayNumber, $1.sequence) }
                .map(\.title),
            visibility: visibility(from: feed.visibility),
            likeCount: Int(feed.likeCount),
            commentCount: Int(feed.commentCount),
            mood: .forest,
            // 화면기획 23 은 **제목 = 코스 제목**, 부제 = 지역·해시태그, 본문 = 작성 내용이다.
            // 제목을 비워두면 화면이 작성 내용을 제목으로 올려 본문과 같은 글이 두 번 나온다.
            // 지역·해시태그는 서버가 주지 않으므로 부제는 비운다 — 없는 값을 지어내지 않는다.
            title: feed.trip.courseTitle,
            subtitle: nil,
            detailBody: feed.content,
            distanceText: "",
            durationText: "",
            visitCountText: "\(feed.trip.places.count)곳",
            photoCountText: feed.images.isEmpty ? "" : "1/\(feed.images.count)",
            authorAvatarURL: MoyeoImageURL.resolve(feed.author.profileImageUrl),
            photoURL: feed.images.min { $0.sequence < $1.sequence }
                .flatMap { MoyeoImageURL.resolve($0.imageUrl) },
            photoURLs: feed.images
                .sorted { $0.sequence < $1.sequence }
                .compactMap { MoyeoImageURL.resolve($0.imageUrl) },
            serverFeedID: feed.feedId,
            serverLiked: feed.liked,
            serverAuthorID: feed.author.userId
        )
    }

    static func visibility(from server: String) -> FeedVisibility {
        switch server {
        case "FRIENDS":
            return .friendsOnly
        case "PRIVATE":
            return .privateOnly
        default:
            return .publicAll
        }
    }

    /// "2026-09-15T19:30:00" → "2026.09.15"
    static func createdAtText(_ dateTime: String) -> String {
        guard let datePart = dateTime.split(separator: "T").first else { return dateTime }
        return datePart.replacingOccurrences(of: "-", with: ".")
    }
}
