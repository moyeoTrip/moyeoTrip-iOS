//
//  MoyeoModels.swift
//  MoyeoTrip
//

import Foundation

enum CourseMood: String, CaseIterable, Hashable {
    case forest
    case coral
    case river
    case blossom
    case sunrise
}

enum RecruitmentStatus: String, Hashable {
    case open = "모집중"
    case almostFull = "마감임박"
    case confirmed = "출발확정"
    case cancelled = "모집취소"
}

enum CourseStatus: String, Hashable {
    case relaxed = "느긋한 코스"
    case balanced = "알찬 코스"
    case active = "활동적인 코스"
}

enum SeatAvailability: Hashable {
    case open(remainingSeats: Int)
    case almostFull(remainingSeats: Int)
    case full
}

enum FeedVisibility: String, CaseIterable, Hashable {
    case publicAll = "전체공개"
    case friendsOnly = "친구만"
    case privateOnly = "나만 보기"
}

enum DogamVisibility: String, CaseIterable, Hashable {
    case publicAll = "전체공개"
    case friendsOnly = "친구에게만"
    case privateOnly = "나만 보기"
}

enum CourseSource: String, CaseIterable, Hashable {
    case linked
    case custom

    var title: String {
        switch self {
        case .linked: "등록된 코스"
        case .custom: "호스트 직접 코스"
        }
    }
}

enum RouteEditState: String, Hashable {
    case editable
    case linkedLocked
    case tripConfirmed
}

enum TripScheduleKind: String, CaseIterable, Hashable {
    case dayTrip = "당일치기"
    case overnight = "1박 이상"
}

struct TripScheduleDetails: Hashable {
    var kind: TripScheduleKind
    var startDate: String
    var endDate: String?
    var startTime: String?
    var endTime: String?
}

struct MeetingPointDetails: Hashable {
    var name: String
    var address: String
    var detail: String
    var latitude: Double
    var longitude: Double
    var meetingTime: String
}

struct ItineraryStop: Identifiable, Hashable {
    var id: String
    var day: Int
    var order: Int
    var time: String
    var name: String
    var memo: String
    var placeID: String?
    var latitude: Double?
    var longitude: Double?
}

struct CoursePublishingInfo: Hashable {
    let travelerName: String
    let travelerAvatar: String
    let publishedAt: String
    let tripCount: Int
}

enum RecruitmentApplicationState: Hashable {
    case none
    case approvalPending
    case waitlisted(position: Int)
    case approved
}

struct TripNotice: Identifiable, Hashable {
    var id: String
    var title: String
    var body: String
    var createdAt: String
    var isPinned: Bool
    /// 서버 공지의 작성자 닉네임 — 서버 공지일 때만 채워진다
    var authorName: String = ""
}

enum ChatMessageKind: String, Hashable {
    case text
    case system
    case routeChanged
}

struct TravelCourse: Identifiable, Hashable {
    let id: String
    let title: String
    let region: String
    let subtitle: String
    let duration: String
    let distance: String
    let mascot: String
    let mood: CourseMood
    let tags: [String]
    let stops: [String]
    var source: CourseSource = .linked
    var itinerary: [ItineraryStop] = []
    var publishingInfo: CoursePublishingInfo?
    /// 실서버 코스 연동 필드 — 서버 코스일 때만 채워진다
    var thumbnailURL: URL?
    var serverCourseID: Int64?
    var serverAverageRating: Double?
    var serverRatingCount: Int64?

    var isServerBacked: Bool {
        serverCourseID != nil
    }

    var status: CourseStatus {
        switch parsedDistance {
        case ..<5.5:
            return .relaxed
        case ..<7.5:
            return .balanced
        default:
            return .active
        }
    }

    var isBeginnerFriendly: Bool {
        status != .active && stops.count <= 4
    }

    private var parsedDistance: Double {
        let numberText = distance.replacingOccurrences(of: "km", with: "")
        return Double(numberText) ?? 0
    }
}

struct TripRecruitment: Identifiable, Hashable {
    let id: String
    let courseID: String
    let title: String
    let region: String
    let coverMascot: String
    let hostName: String
    let hostAvatar: String
    let schedule: String
    let meetupPoint: String
    let price: String
    let capacity: Int
    let joined: Int
    let minimumParticipants: Int
    let status: RecruitmentStatus
    let summary: String
    let vibe: String
    let tags: [String]
    let route: [String]
    let participants: [Participant]
    var courseSource: CourseSource = .linked
    var itinerary: [ItineraryStop] = []
    var scheduleDetails: TripScheduleDetails?
    var meetingDetails: MeetingPointDetails?
    var recruitmentDeadline: String = ""
    var minimumAge: Int = 25
    var maximumAge: Int = 35
    var genderRestriction: String = "성별 무관"
    var routeEditState: RouteEditState = .linkedLocked
    var notices: [TripNotice] = []
    var applicationState: RecruitmentApplicationState = .none
    /// 실서버 모임 연동 필드 — 서버 모임일 때만 채워진다.
    /// 서버가 내려주지 않는 값(호스트 닉네임·매너 점수·최소 인원 등)은 화면에서 숨긴다.
    var serverRoomID: Int64?
    var heroImageURL: URL?
    var hostProfileImageURL: URL?
    var serverCourseTitle: String?

    var isServerBacked: Bool {
        serverRoomID != nil
    }

    var remainingSeats: Int {
        max(capacity - joined, 0)
    }

    var progress: Double {
        guard capacity > 0 else { return 0 }
        return min(Double(joined) / Double(capacity), 1)
    }

    var minimumProgress: Double {
        guard capacity > 0 else { return 0 }
        return min(Double(minimumParticipants) / Double(capacity), 1)
    }

    var hasMetMinimumParticipants: Bool {
        joined >= minimumParticipants
    }

    var needsMoreParticipants: Int {
        max(minimumParticipants - joined, 0)
    }

    var seatAvailability: SeatAvailability {
        if remainingSeats == 0 {
            return .full
        }

        if remainingSeats <= 2 {
            return .almostFull(remainingSeats: remainingSeats)
        }

        return .open(remainingSeats: remainingSeats)
    }

    var canJoin: Bool {
        status != .cancelled && remainingSeats > 0
    }

    var applicationActionTitle: String {
        status == .cancelled ? "모집 종료" : (canJoin ? "신청하기" : "대기 신청")
    }

    var ageRangeText: String {
        "\(minimumAge)~\(maximumAge)세"
    }
}

struct Participant: Identifiable, Hashable {
    let id: String
    let name: String
    let avatar: String
}

struct ExploreSpot: Identifiable, Hashable {
    let id: String
    let name: String
    let region: String
    let category: String
    let address: String
    let summary: String
    let mapHint: String
    let mascot: String
    let tags: [String]
    let linkedTripID: String?
    // 실지도(화면기획 11)에 마커를 찍기 위한 위경도. 없으면 목업 지도로 남는다.
    var latitude: Double?
    var longitude: Double?
}

struct ChatThread: Identifiable, Hashable {
    let id: String
    let tripTitle: String
    let region: String
    let mascot: String
    let lastMessage: String
    let updatedAt: String
    let unreadCount: Int
    var statusSummary: String
    let statusDetail: String
    var members: [Participant]
    var messages: [ChatMessage]
    let isReadOnly: Bool
    var closureReason: String?
    var archiveNotice: String?
    var archiveStatus: String?
    var tripID: String?
    var pinnedNotices: [TripNotice] = []
    var routeSummary: [ItineraryStop] = []
    var courseSource: CourseSource = .linked
    var isCurrentUserHost: Bool = false
    var courseName: String = ""
    var price: String = ""
    var recruitmentDeadline: String = ""
    var ageRange: String = ""
    var genderRestriction: String = ""
    var scheduleSummary: String = ""
    /// 실서버 채팅방 연동 필드 — 서버 모임일 때만 채워진다.
    /// 서버가 내려주지 않는 값(지역·마스코트·매너 점수)은 화면에서 숨긴다.
    var serverRoomID: Int64?
    var thumbnailURL: URL?
    var meetupSummary: String = ""

    var isServerBacked: Bool {
        serverRoomID != nil
    }
}

struct ChatMessage: Identifiable, Hashable {
    let id: String
    let senderName: String
    let avatar: String
    let body: String
    let time: String
    let isMine: Bool
    var kind: ChatMessageKind = .text
}

extension ChatMessage {
    var isSystemNotice: Bool {
        kind != .text || senderName == "시스템" || senderName == "모여트립"
    }
}

struct FeedPost: Identifiable, Hashable {
    let id: String
    let authorName: String
    let authorAvatar: String
    let region: String
    let createdAt: String
    let photoMascot: String
    let caption: String
    let tags: [String]
    let route: [String]
    let visibility: FeedVisibility
    let likeCount: Int
    var commentCount: Int
    let mood: CourseMood
    var title: String?
    var subtitle: String?
    var detailBody: String?
    var distanceText: String = "12.4km"
    var durationText: String = "4시간 30분"
    // 대표 피드의 경로는 주왕산 · 용연폭포 · 주산지 3곳이다 (4개 플랫폼 공통)
    var visitCountText: String = "3곳"
    var photoCountText: String = "1/10"
    /// 실서버 피드 연동 필드 — 서버 피드일 때만 채워진다
    var authorAvatarURL: URL?
    var photoURL: URL?
    var serverFeedID: Int64?
    var serverLiked: Bool = false

    var isServerBacked: Bool {
        serverFeedID != nil
    }
}

struct DogamFriend: Identifiable, Hashable {
    let id: String
    let nickname: String
    let avatar: String
    let lastMetAt: String
    let metCount: Int
}

struct ProfileSummary: Hashable {
    let name: String
    let handle: String
    let avatar: String
    let profileImageURL: URL?
    let region: String
    let badges: [String]
    let joinedTrips: Int
    let hostedTrips: Int
    let feedCount: Int
    let points: Int
    let favoriteRegions: [String]
}
