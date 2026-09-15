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
    /// 모집이 불발된 방. **잠금은 `tripConfirmed` 와 똑같고 이유만 다르다** —
    /// 케이스가 없던 시절에는 불발된 방도 `tripConfirmed` 로 접혀서 「여행이 확정되어 경로가
    /// 잠겼어요」라고 말했다. 떠나지도 않을 여행을 확정됐다고 알리는 셈이었다 (안드 AND-119 교차).
    case tripCancelled

    /// 경로를 못 고치는 상태인지. 잠금 판단은 **여기 한 곳**에서만 한다 —
    /// 케이스를 늘릴 때 `!= .editable` 같은 조건이 흩어져 있으면 잠금이 새기 쉽다.
    var isRouteLocked: Bool { self != .editable }
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
    /// 작성자 userId. **nil 이면 공개하지 않은 것** — 25 공개 프로필로 보내지 않고
    /// 누를 수 있는 모양도 주지 않는다 (BE-29).
    var travelerUserID: Int64?
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
    /// 나이 제한은 **호스트가 정했을 때만** 걸린다 — 정하지 않았으면 `nil` 이다.
    /// 서버도 둘 다 nullable 이고, 예전 기본값 `25~35` 는 호스트가 고른 적 없는 제한이었다.
    var minimumAge: Int?
    var maximumAge: Int?
    var genderRestriction: String = "성별 무관"
    /// 17-5 신청 승인 방식 — 서버 `joinApprovalMode` 의 `AUTO` · `MANUAL` 을 그대로 담는다.
    ///
    /// 신청하는 사람에게 이 값은 **「누르면 바로 들어가는가, 호스트가 볼 때까지 기다리는가」**를
    /// 가른다. 예전에는 상세가 이 값을 아예 읽지 않아, 신청 버튼을 누르고 나서야 알 수 있었다
    /// (IOS-F103). 못 받았으면 nil 이고 그때는 **줄을 그리지 않는다**(기본값을 지어내지 않는다).
    var joinApprovalMode: String?
    var routeEditState: RouteEditState = .linkedLocked
    var notices: [TripNotice] = []
    var applicationState: RecruitmentApplicationState = .none
    /// 실서버 모임 연동 필드 — 서버 모임일 때만 채워진다.
    ///
    /// **호스트 닉네임은 모집 상세 응답에 없지만 「없는 값」이 아니다.**
    /// `GET /chat-rooms/{id}` 는 `hostId` 와 `hostProfileImageUrl` 만 주고 `participants` 에도
    /// 닉네임이 없지만, **공개 프로필 API(`GET /users/{userId}/profile`)가 닉네임·매너 점수·여행 횟수를
    /// 모두 준다.** 예전에는 세 플랫폼이 다 「서버가 안 준다」고 적어 두고 「호스트」 라벨만 덩그러니
    /// 그렸다 — 이름 없는 빈 줄이 됐다(사용자 지적 2026-09-12).
    /// 그래서 `hostUserID` 를 들고 있다가 상세 화면에서 공개 프로필로 이름을 채운다.
    var serverRoomID: Int64?
    var hostUserID: Int64?
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
        guard let minimumAge, let maximumAge else { return "나이 제한 없음" }
        return "\(minimumAge)~\(maximumAge)세"
    }
}

struct Participant: Identifiable, Hashable {
    let id: String
    let name: String
    let avatar: String
}

struct ChatThread: Identifiable, Hashable {
    let id: String
    /// 방 id 로만 들어오는 진입에서는 처음에 비어 있고, 상세 응답이 오면 채워진다 —
    /// 그래서 `let` 이 아니라 `var` 다 (`isReadOnly` 와 같은 이유, 20-1 2026-09-09).
    var tripTitle: String
    let region: String
    let mascot: String
    let lastMessage: String
    let updatedAt: String
    let unreadCount: Int
    var statusSummary: String
    let statusDetail: String
    var members: [Participant]
    var messages: [ChatMessage]
    /// 서버 응답을 얹을 때 다시 정해진다 — `let` 이면 라우트 진입용 자리끼우개의
    /// `true` 가 그대로 남아 모집 중인 방까지 「종료」로 그려진다 (2026-09-08 결함).
    var isReadOnly: Bool
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
    /// 이동 거리·소요 시간·방문지 수. **서버가 준 값이 있을 때만** 채운다 —
    /// 예전 기본값 `12.4km`·`4시간 30분`·`3곳` 은 아무 근거 없는 수치라,
    /// 이 값을 덮어쓰지 않는 생성 경로(`ServerFeedMapper.stubPost` = 알림 딥링크)에서
    /// 그대로 새 나갈 수 있었다 (NO-MOCK-CANON R1). 비면 24 피드가 그 칸을 그리지 않는다.
    var distanceText: String = ""
    var durationText: String = ""
    var visitCountText: String = ""
    /// 「사진 N장」. 비면 그 줄을 그리지 않는다 — 지어낸 기본값을 두지 않는다 (NO-MOCK R1).
    var photoCountText: String = ""
    /// 실서버 피드 연동 필드 — 서버 피드일 때만 채워진다
    var authorAvatarURL: URL?
    var photoURL: URL?
    /// 서버 피드가 준 사진 전체(sequence 순). 22 타임라인은 웹 · 안드로이드처럼 앞의 2장을 나란히 그린다.
    var photoURLs: [URL] = []
    var serverFeedID: Int64?
    /// 다녀온 코스의 서버 id (`FeedTripResponse.courseId`). 「방문지 N곳」을 눌러
    /// 14 코스 상세로 가는 데 쓴다 — **없으면 누를 수 있는 모양을 주지 않는다**
    /// (식별자 없이 눌리는 자리를 만들지 않는다, `FEED-COMMENT-PREVIEW-CANON` 보충).
    var serverCourseID: Int64?
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

extension FeedPost {
  /// 신고할 수 있는 피드인가. 서버 피드가 아니면(목 id·미로그인) 보낼 대상이 없고,
  /// 내가 쓴 피드는 서버가 받지 않는다 — 자기 피드를 신고하면 400 `40039`
  /// (`본인이 작성한 피드는 신고할 수 없습니다`)다 (2026-09-03 실서버 확인).
  ///
  /// **목록 카드와 상세가 같은 규칙을 써야 한다.** 예전에는 상세에만 이 판정이 있고
  /// 목록의 `...` 는 `Button` 조차 아니어서 눌러도 아무 일도 없었다.
  var canReport: Bool {
    guard serverFeedID != nil else { return false }
    guard let authorID = serverAuthorID, let myID = MoyeoCurrentUser.id else { return true }
    return authorID != myID
  }

  /// 내가 쓴 서버 피드인가 — 24-6 수정·삭제 시트를 열 수 있는 조건이다.
  ///
  /// `canReport` 의 반대가 아니다. 서버 피드가 아니거나 작성자를 모르면 **둘 다 아니다** —
  /// 모르는 글에 수정·삭제를 열어 주면 남의 글을 지우자고 권하는 꼴이 된다.
  ///
  /// 예전에는 이 판정이 없어 **내 피드에는 `...` 자체가 그려지지 않았고**, 수정·삭제 시트
  /// (`FeedActionsSheetView`)로 가는 제품 경로가 캡처 하네스뿐이었다 (TC FEED-027).
  var canEditOrDelete: Bool {
    guard serverFeedID != nil,
          let authorID = serverAuthorID,
          let myID = MoyeoCurrentUser.id
    else { return false }
    return authorID == myID
  }
}
