//
//  TravelCourseAPIClient.swift
//  MoyeoTrip
//
//  여행 코스 실서버 연동 (연동 대상 3) — 공개·인기 코스, 태그, 채팅방 코스.
//

import Foundation

// MARK: - 응답 모델

struct ServerTravelCourse: Decodable, Hashable, Identifiable {
    struct Place: Decodable, Hashable {
        let contentId: Int64
        let dayNumber: Int
        let sequence: Int
        let visitTime: String?
        let title: String
        let thumbnail: String?
        let latitude: Double
        let longitude: Double
    }

    let courseId: Int64
    let title: String
    let description: String?
    let type: String
    let travelTime: String
    let distanceKm: Double
    let averageRating: Double?
    let ratingCount: Int64
    let tags: [ServerCourseTag]
    let thumbnail: String?
    let places: [Place]

    var id: Int64 { courseId }

    var thumbnailURL: URL? {
        MoyeoImageURL.resolve(thumbnail)
    }
}

/// 공개 코스 상세 (travel-courses/{courseId}) — 14 코스 상세.
/// 목록 응답에 없는 작성자·연결된 모임 수가 더 온다.
struct ServerTravelCourseDetail: Decodable, Hashable, Identifiable {
    let courseId: Int64
    let title: String
    let description: String?
    let creatorNickname: String?
    /// 작성자 프로필 이미지 (2026-09-02 서버 추가, 실서버 확인 — 코스 81·61·21 모두 URL 이 온다).
    /// 작성자 비공개·탈퇴·이미지 없음이면 `null` 이다 — 그때만 닉네임 아바타로 떨어진다.
    let creatorProfileImageUrl: String?
    let creatorTravelStartDate: String?
    let creatorTravelEndDate: String?
    let chatRoomCount: Int64
    let travelTime: String
    let distanceKm: Double
    let averageRating: Double?
    let ratingCount: Int64
    let tags: [ServerCourseTag]
    let thumbnail: String?
    let places: [ServerTravelCourse.Place]

    var id: Int64 { courseId }

    var thumbnailURL: URL? {
        MoyeoImageURL.resolve(thumbnail)
    }
}

/// 찜한 코스 (`travel-courses/me/favorites`) — 26 마이 `찜한 코스` 탭.
/// 목록 응답보다 좁다: 소요 시간·거리·평점이 없다. 없는 값을 카드에 두지 않는다.
struct ServerLikedCourse: Decodable, Hashable, Identifiable {
    let courseId: Int64
    let title: String
    let description: String?
    let thumbnail: String?
    let tags: [ServerCourseTag]

    var id: Int64 { courseId }

    var thumbnailURL: URL? {
        MoyeoImageURL.resolve(thumbnail)
    }
}

/// `POST /travel-courses/{courseId}/publication` 응답.
struct ServerCoursePublication: Decodable, Hashable {
    let courseId: Int64
    let publicationStatus: String
}

struct ServerRoomCourse: Decodable, Hashable {
    struct Room: Decodable, Hashable {
        let roomId: Int64
        let tripType: String
        let startDate: String
        let endDate: String?
        let dayTripStartTime: String?
        let dayTripEndTime: String?
    }

    let room: Room
    let course: ServerTravelCourse?
}

// MARK: - 클라이언트

final class TravelCourseAPIClient: @unchecked Sendable {
    static let shared = TravelCourseAPIClient()

    private let api: MoyeoAPIClient

    init(api: MoyeoAPIClient = .shared) {
        self.api = api
    }

    func publicCourses(tagID: Int64? = nil) async throws -> [ServerTravelCourse] {
        var query: [URLQueryItem] = []
        if let tagID {
            query.append(URLQueryItem(name: "tagId", value: "\(tagID)"))
        }
        return try await api.get("/api/v1/travel-courses/public", query: query)
    }

    func popularCourses() async throws -> [ServerTravelCourse] {
        try await api.get("/api/v1/travel-courses/public/popular")
    }

    /// 27-3 코스 공개 — `POST /travel-courses/{courseId}/publication`.
    /// **되돌릴 수 없다.** 호출부는 두 단계 확인을 거친 뒤에만 부른다.
    /// 이 호출부가 없어서 27-3 이 서버를 부르지 않고 화면에만 "공개했어요" 를 띄우고 있었다
    /// (`audit-api-coverage.mjs` 의 "아무 플랫폼도 쓰지 않음").
    func publishCourse(
        courseID: Int64,
        title: String,
        description: String,
        showsCreatorNickname: Bool
    ) async throws -> ServerCoursePublication {
        struct PublishRequest: Encodable {
            let title: String
            let description: String
            let showCreatorNickname: Bool
        }
        return try await api.send(
            "/api/v1/travel-courses/\(courseID)/publication",
            method: "POST",
            body: PublishRequest(
                title: title, description: description, showCreatorNickname: showsCreatorNickname
            )
        )
    }

    /// 26 마이 `찜한 코스` — 오래 "조회 API 가 없다"고 적혀 있었지만 실서버는 200 을 준다.
    /// 응답(`LikedTravelCourseResponse`)은 목록 카드보다 좁다 — 소요 시간·거리·평점이 없다.
    func likedCourses() async throws -> [ServerLikedCourse] {
        try await api.get("/api/v1/travel-courses/me/favorites")
    }

    func tags() async throws -> [ServerCourseTag] {
        try await api.get("/api/v1/travel-courses/tags")
    }

    /// 공개 코스 상세 — 14 코스 상세
    func courseDetail(courseID: Int64) async throws -> ServerTravelCourseDetail {
        try await api.get("/api/v1/travel-courses/\(courseID)")
    }

    func roomCourse(roomID: Int64) async throws -> ServerRoomCourse {
        try await api.get("/api/v1/travel-courses/chat-rooms/\(roomID)")
    }

    /// 12-1 검색 결과 — **제목에 포함되거나 태그명이 일치**하는 공개 코스를 준다.
    /// 소개글(`description`)은 검색 대상이 아니다 (정본 `ATTACH-COMPOSER-CANON.md` R6).
    func searchCourses(keyword: String) async throws -> [ServerTravelCourse] {
        try await api.get(
            "/api/v1/travel-courses/search",
            query: [URLQueryItem(name: "keyword", value: keyword)]
        )
    }

    /// 27-4 코스 평가 — `POST /travel-courses/chat-rooms/{roomId}/rating`.
    /// 서버는 `score` 를 1~5 정수로만 받는다(`RateTravelCourseRequest`). 204 를 준다.
    /// **확정된 여행이 끝난 채팅방 참가자만** 평가할 수 있다 — 그 밖에는 서버가 거절한다.
    func rateCourse(roomID: Int64, score: Int) async throws {
        struct RateRequest: Encodable {
            let score: Int
        }
        try await api.sendVoid(
            "/api/v1/travel-courses/chat-rooms/\(roomID)/rating",
            method: "POST",
            body: RateRequest(score: score)
        )
    }

    /// 14 코스 상세 `모집 중인 모임 보기` — 모집 마감 전이고 아직 참가하지 않은 방만 온다.
    /// 응답은 11 탐색 카드와 같은 `SearchChatRoomResponse` 다 (정본 §4).
    func recruitingRooms(courseID: Int64) async throws -> [ServerChatRoomSummary] {
        try await api.get("/api/v1/travel-courses/\(courseID)/chat-rooms")
    }
}

// MARK: - 화면 모델 매핑

enum ServerCourseMapper {
    static let serverCourseIDPrefix = "server-course-"

    /// courseId 만 아는 진입점용 빈 껍데기 — 14 코스 상세가 서버 상세로 다시 채운다.
    static func stubCourse(serverCourseID: Int64) -> TravelCourse {
        TravelCourse(
            id: "\(serverCourseIDPrefix)\(serverCourseID)",
            title: "",
            region: "",
            subtitle: "",
            duration: "",
            distance: "",
            mascot: "",
            mood: .forest,
            tags: [],
            stops: [],
            serverCourseID: serverCourseID
        )
    }

    /// 서버 코스 → 코스 상세 화면 모델.
    /// 서버가 주지 않는 값(지역·마스코트 등)은 비워 두고 화면에서 숨긴다.
    static func course(from server: ServerTravelCourse) -> TravelCourse {
        course(
            courseID: server.courseId,
            title: server.title,
            description: server.description,
            travelTime: server.travelTime,
            distanceKm: server.distanceKm,
            tags: server.tags,
            places: server.places,
            source: server.type == "CUSTOM" ? .custom : .linked,
            thumbnailURL: server.thumbnailURL,
            averageRating: server.averageRating,
            ratingCount: server.ratingCount,
            publishingInfo: nil
        )
    }

    /// 공개 코스 상세 → 14 코스 상세.
    /// 상세는 작성자와 이 코스로 만들어진 모임 수를 더 준다 — 있을 때만 여행자 코스 카드를 그린다.
    static func course(from detail: ServerTravelCourseDetail) -> TravelCourse {
        var publishingInfo: CoursePublishingInfo?
        if let nickname = detail.creatorNickname, !nickname.isEmpty {
            publishingInfo = CoursePublishingInfo(
                travelerName: nickname,
                // 이미지가 없을 때만 쓰는 대체 표시. 표는 `MoyeoNicknameAnimal` 하나뿐이다 (NO-MOCK R5).
                travelerAvatar: MoyeoNicknameAnimal.emoji(forNickname: nickname)
                    ?? MoyeoNicknameAnimal.unknown,
                travelerAvatarURL: MoyeoImageURL.resolve(detail.creatorProfileImageUrl),
                publishedAt: travelPeriodText(
                    startDate: detail.creatorTravelStartDate,
                    endDate: detail.creatorTravelEndDate
                ),
                tripCount: Int(detail.chatRoomCount)
            )
        }

        return course(
            courseID: detail.courseId,
            title: detail.title,
            description: detail.description,
            travelTime: detail.travelTime,
            distanceKm: detail.distanceKm,
            tags: detail.tags,
            places: detail.places,
            // 상세는 공개 코스만 조회되므로 커스텀 여부를 따로 주지 않는다
            source: .linked,
            thumbnailURL: detail.thumbnailURL,
            averageRating: detail.averageRating,
            ratingCount: detail.ratingCount,
            publishingInfo: publishingInfo
        )
    }

    // swiftlint:disable:next function_parameter_count
    private static func course(
        courseID: Int64,
        title: String,
        description: String?,
        travelTime: String,
        distanceKm: Double,
        tags: [ServerCourseTag],
        places: [ServerTravelCourse.Place],
        source: CourseSource,
        thumbnailURL: URL?,
        averageRating: Double?,
        ratingCount: Int64,
        publishingInfo: CoursePublishingInfo?
    ) -> TravelCourse {
        let orderedPlaces = places.sorted { ($0.dayNumber, $0.sequence) < ($1.dayNumber, $1.sequence) }
        return TravelCourse(
            id: "\(serverCourseIDPrefix)\(courseID)",
            title: title,
            region: "",
            subtitle: description ?? "",
            duration: travelTime,
            distance: distanceText(distanceKm),
            mascot: "",
            mood: .forest,
            tags: tags.map(\.name),
            stops: orderedPlaces.map(\.title),
            source: source,
            itinerary: orderedPlaces.map { place in
                ItineraryStop(
                    id: "server-stop-\(place.contentId)-\(place.dayNumber)-\(place.sequence)",
                    day: place.dayNumber,
                    order: place.sequence,
                    time: ServerTripMapper.shortTime(place.visitTime) ?? "",
                    name: place.title,
                    memo: "",
                    placeID: "\(place.contentId)",
                    latitude: place.latitude,
                    longitude: place.longitude
                )
            },
            publishingInfo: publishingInfo,
            thumbnailURL: thumbnailURL,
            serverCourseID: courseID,
            serverAverageRating: averageRating,
            serverRatingCount: ratingCount
        )
    }

    /// 작성자가 다녀온 기간 — 서버가 날짜를 주지 않으면 빈 문자열로 남긴다
    static func travelPeriodText(startDate: String?, endDate: String?) -> String {
        guard let startDate, !startDate.isEmpty else { return "" }
        return ServerTripMapper.scheduleText(startDate: startDate, endDate: endDate)
    }

    static func distanceText(_ kilometers: Double) -> String {
        if kilometers.rounded() == kilometers {
            return "\(Int(kilometers))km"
        }
        return String(format: "%.1fkm", kilometers)
    }
}
