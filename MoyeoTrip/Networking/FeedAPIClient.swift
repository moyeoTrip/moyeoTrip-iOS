//
//  FeedAPIClient.swift
//  MoyeoTrip
//
//  피드 실서버 연동 (연동 대상 8) — 목록·상세·좋아요·댓글.
//

import Foundation

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

/// 23-1 댓글. 서버는 대댓글을 `replies` 로 중첩해 내려준다 (`GET /feeds/{id}/comments` → 배열).
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

    /// 23-1 댓글 목록. 스펙(`/api-docs`)에는 단일 객체로 적혀 있지만 서버는 **배열**을 준다.
    func comments(feedID: Int64) async throws -> [ServerFeedComment] {
        try await api.get("/api/v1/feeds/\(feedID)/comments")
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
    static let serverFeedIDPrefix = "server-feed-"

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
            title: nil,
            subtitle: feed.trip.courseTitle,
            detailBody: feed.content,
            distanceText: "",
            durationText: "",
            visitCountText: "\(feed.trip.places.count)곳",
            photoCountText: feed.images.isEmpty ? "" : "1/\(feed.images.count)",
            authorAvatarURL: feed.author.profileImageUrl.flatMap(URL.init(string:)),
            photoURL: feed.images.min { $0.sequence < $1.sequence }
                .flatMap { URL(string: $0.imageUrl) },
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
