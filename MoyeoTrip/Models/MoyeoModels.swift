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
}

struct ChatThread: Identifiable, Hashable {
    let id: String
    let tripTitle: String
    let region: String
    let mascot: String
    let lastMessage: String
    let updatedAt: String
    let unreadCount: Int
    let statusSummary: String
    let statusDetail: String
    let members: [Participant]
    let messages: [ChatMessage]
    let isReadOnly: Bool
    var closureReason: String?
    var archiveNotice: String?
    var archiveStatus: String?
}

struct ChatMessage: Identifiable, Hashable {
    let id: String
    let senderName: String
    let avatar: String
    let body: String
    let time: String
    let isMine: Bool
}

extension ChatMessage {
    var isSystemNotice: Bool {
        senderName == "시스템" || senderName == "모여트립"
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
    var visitCountText: String = "5곳"
    var photoCountText: String = "1/10"
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
    let region: String
    let badges: [String]
    let joinedTrips: Int
    let hostedTrips: Int
    let feedCount: Int
    let points: Int
    let favoriteRegions: [String]
}
