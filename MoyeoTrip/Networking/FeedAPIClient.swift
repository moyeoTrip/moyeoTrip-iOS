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
    /// 24 피드 글쓰기 — `POST /api/v1/feeds` (multipart: `request` JSON + `images` 1~10장).
    ///
    /// **예전에는 이 호출이 없었다.** iOS 의 「게시하기」는 화면 안 목록에만 글을 끼워 넣고
    /// 서버에는 아무것도 올리지 않았다 — 앱을 다시 켜면 사라지고, 웹·안드로이드에서도 안 보였다
    /// (웹 `createFeed` · 안드 `FeedRepository.createFeed` 는 둘 다 이 엔드포인트를 부른다,
    /// 2026-09-09 발견). 제목 칸은 서버가 받지 않는다 — `content` 하나뿐이다(BE 요청 §8-7).
    func createFeed(
        chatRoomID: Int64,
        content: String,
        visibility: String,
        images: [MoyeoMultipartFile]
    ) async throws -> ServerFeed {
        struct CreateRequest: Encodable {
            let chatRoomId: Int64
            let content: String
            let visibility: String
        }
        return try await api.sendMultipart(
            "/api/v1/feeds",
            method: "POST",
            jsonPartName: "request",
            jsonPart: CreateRequest(chatRoomId: chatRoomID, content: content, visibility: visibility),
            files: images
        )
    }

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

    // MARK: - 수정 · 삭제 (2026-09-04 BE 회신으로 열렸다)
    //
    // 정본 `docs/api/BACKEND_REQUEST_CHANGES_2026-09-04.md` · 2026-09-07 실서버로 확인.

    /// 피드 수정 — **본문만** 받는다.
    ///
    /// 사진은 이 API 로 교체하지 않고 기존 첨부가 그대로 유지된다. 공개 범위도 못 바꾼다 —
    /// 댓글 쓴 사람이 갑자기 피드를 못 보게 되는 것을 막으려는 정책이다.
    /// 그래서 24-6 화면에는 사진·공개범위 편집 UI 를 두지 않는다(두면 죽은 버튼이 된다).
    /// 작성자 본인만 된다. 없는 피드는 404 `40417`.
    func updateFeed(feedID: Int64, content: String) async throws {
        struct UpdateRequest: Encodable { let content: String }
        try await api.sendVoid(
            "/api/v1/feeds/\(feedID)",
            method: "PUT",
            body: UpdateRequest(content: content)
        )
    }

    /// 피드 삭제 — 204 No Content.
    ///
    /// 사진·댓글·좋아요·신고 관계가 함께 정리되고, 커밋 뒤 이미지 파일도 지워진다.
    /// **되돌릴 수 없다** — 23-3 확인 단계를 거친 뒤에만 부른다.
    func deleteFeed(feedID: Int64) async throws {
        try await api.sendVoid("/api/v1/feeds/\(feedID)", method: "DELETE")
    }

    /// 댓글 수정 — 공백 불가 · **최대 500자**다.
    ///
    /// 신고 `details` 의 300자와 다르다 — 헷갈리기 쉬우니 화면에서도 500 으로 자른다.
    /// 작성자 본인만 된다. 남의 댓글은 403, 없는 댓글은 404 `40422`.
    func updateComment(feedID: Int64, commentID: Int64, content: String) async throws {
        struct UpdateRequest: Encodable { let content: String }
        try await api.sendVoid(
            "/api/v1/feeds/\(feedID)/comments/\(commentID)",
            method: "PUT",
            body: UpdateRequest(content: content)
        )
    }

    /// 댓글 삭제 — 최상위 댓글을 지우면 **달린 답글도 함께** 사라진다.
    ///
    /// 화면이 그 사실을 먼저 알려야 한다.
    func deleteComment(feedID: Int64, commentID: Int64) async throws {
        try await api.sendVoid(
            "/api/v1/feeds/\(feedID)/comments/\(commentID)",
            method: "DELETE"
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

    /// 피드·댓글의 작성 시각 표기.
    ///
    /// **상대 시각이다** — 기획(`screens-additions3.jsx` 의 `2시간 전`)과 웹
    /// (`moyeo-api.js` 의 `formatRelative`)이 그렇게 쓴다. 예전에는 iOS·안드로이드만
    /// `2026.09.07` 처럼 절대 날짜를 써서 4열 비교에서 두 앱만 달라 보였다
    /// (2026-09-08 사용자 지적). 규칙과 경계값은 웹 `formatRelative` 를 그대로 옮겼다:
    /// 1분 미만 `방금 전` · 60분 미만 `N분 전` · 24시간 미만 `N시간 전` ·
    /// 1일 `어제` · 7일 미만 `N일 전` · 그 이상은 `YYYY.MM.DD`.
    static func createdAtText(_ dateTime: String) -> String {
        guard let then = Self.serverDate(dateTime) else {
            // 파싱 실패는 지어내지 않고 날짜 부분만 보여준다.
            guard let datePart = dateTime.split(separator: "T").first else { return dateTime }
            return datePart.replacingOccurrences(of: "-", with: ".")
        }
        let minutes = Int(Date().timeIntervalSince(then) / 60)
        if minutes < 1 { return "방금 전" }
        if minutes < 60 { return "\(minutes)분 전" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)시간 전" }
        let days = hours / 24
        if days == 1 { return "어제" }
        if days < 7 { return "\(days)일 전" }
        return Self.absoluteFormatter.string(from: then)
    }

    /// 서버는 타임존 없는 `yyyy-MM-dd'T'HH:mm:ss[.SSSSSS]` 를 준다 — 기기 시간대로 읽는다.
    private static func serverDate(_ dateTime: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateTime) { return date }
        }
        return nil
    }

    private static let absoluteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()
}
