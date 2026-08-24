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
        thumbnail.flatMap(URL.init(string:))
    }
}

/// 공개 코스 상세 (travel-courses/{courseId}) — 14 코스 상세.
/// 목록 응답에 없는 작성자·연결된 모임 수가 더 온다.
struct ServerTravelCourseDetail: Decodable, Hashable, Identifiable {
    let courseId: Int64
    let title: String
    let description: String?
    let creatorNickname: String?
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
        thumbnail.flatMap(URL.init(string:))
    }
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
}

// MARK: - 화면 모델 매핑

enum ServerCourseMapper {
    static let serverCourseIDPrefix = "server-course-"

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
                travelerAvatar: "",
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
