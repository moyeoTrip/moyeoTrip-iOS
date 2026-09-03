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
    /// 프로필 이미지가 없을 때만 쓰는 대체 표시(닉네임에서 유도한 마스코트).
    let travelerAvatar: String
    /// 작성자 프로필 이미지. 있으면 **반드시** 이걸 그린다 (`creatorProfileImageUrl`).
    var travelerAvatarURL: URL?
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
    /// 공지는 **본문만** 있다. 제목 필드를 두지 않는다 —
    /// 서버 모델도 `notice` 문자열 하나뿐이라 제목을 두면 클라가 지어내야 했다
    /// (정본 `ATTACH-COMPOSER-CANON.md` §2, 기획 결정 2026-08-30).
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

    /// 아직 코스를 고르지 않은 자리. 값을 지어내지 않으려고 전부 비워 둔다.
    static let empty = TravelCourse(
        id: "",
        title: "",
        region: "",
        subtitle: "",
        duration: "",
        distance: "",
        mascot: "",
        mood: .forest,
        tags: [],
        stops: []
    )

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
    /// 서버 메시지의 원본. 장소 · 만날 위치 · 투표 · 정산 메모 · 사진은 **카드**로 그려야 하는데,
    /// `body` 하나로 납작하게 눌러 담으면 좌표도 선택지도 사진도 사라진다.
    /// 목데이터 스레드에서는 nil 이고 그때는 예전처럼 말풍선만 그린다.
    var server: ServerChatMessage?
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
    /// 서버 피드가 준 사진 전체(sequence 순). 22 타임라인은 웹 · 안드로이드처럼 앞의 2장을 나란히 그린다.
    var photoURLs: [URL] = []
    var serverFeedID: Int64?
    var serverLiked: Bool = false
    /// changeLog18 — 작성자를 눌러 25 프로필 카드로 갈 때 쓰는 유저 id (서버 피드만 안다)
    var serverAuthorID: Int64?

    var isServerBacked: Bool {
        serverFeedID != nil
    }
}

struct ProfileSummary: Hashable {
    let name: String
    let handle: String
    let profileImageURL: URL?
    let region: String
    let badges: [String]
    let joinedTrips: Int
    let hostedTrips: Int
    let feedCount: Int
    let points: Int
    let favoriteRegions: [String]

    /// 아바타는 저장하지 않고 **닉네임에서 계산한다** (NO-MOCK-CANON R5).
    /// 고정 이모지를 들고 있으면 서버 닉네임이 바뀌어도 동물이 따라오지 않는다.
    var avatar: String {
        ProfileCardCompanion.mascotEmoji(forNickname: name) ?? ProfileCardCompanion.unknownAnimalMascot
    }

    /// 로그인 전 · 서버 프로필이 오기 전의 자리. 지어낸 값을 두지 않는다.
    static let empty = ProfileSummary(
        name: "",
        handle: "",
        profileImageURL: nil,
        region: "",
        badges: [],
        joinedTrips: 0,
        hostedTrips: 0,
        feedCount: 0,
        points: 0,
        favoriteRegions: []
    )
}
