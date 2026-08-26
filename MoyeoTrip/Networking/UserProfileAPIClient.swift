//
//  UserProfileAPIClient.swift
//  MoyeoTrip
//
//  내 프로필 실서버 연동 (연동 대상 6) — 조회·수정·취향 후보(options).
//

import Foundation

struct ServerProfileOption: Decodable, Identifiable, Hashable {
    let id: Int64
    let label: String
}

struct ServerRegionOption: Decodable, Identifiable, Hashable {
    let id: Int64
    let signguName: String
}

struct ServerMyProfile: Decodable, Hashable {
    let nickname: String
    let profileImageUrl: String?
    let introduction: String?
    let travelStyles: [ServerProfileOption]
    let interestedRegions: [ServerRegionOption]
    let birthDate: String?
    let gender: String
    let chatNotificationMode: String
    let recruitmentDeadlineEnabled: Bool
    let socialActivityEnabled: Bool
    let marketingEnabled: Bool

    var genderText: String {
        switch gender {
        case "F":
            return "여성"
        case "M":
            return "남성"
        default:
            return "선택 안 함"
        }
    }

    /// "1998-04-12" → "1998.04.12"
    var birthDateText: String? {
        birthDate?.replacingOccurrences(of: "-", with: ".")
    }
}

/// `GET /api/v1/users/{userId}/profile` — 다른 사용자의 공개 프로필 (2026-08-25 배포).
/// 25 프로필 카드의 닉네임 · 색상 · 소개 · 여행 스타일 · 평균 매너 점수가 여기서 온다.
///
/// 라이브 응답 실측:
/// `{"userId":62,"nickname":"따스한 기린 2334","nicknameColor":"ORANGE","profileImageUrl":null,`
/// ` "introduction":null,"travelStyles":[],"interestedRegions":[],"mannerRating":5.0}`
///
/// 서버는 값이 없으면 `null` 을 준다(소개 · 매너 점수). **null 은 화면에서 칸을 만들지 않는다** —
/// 카드가 값을 지어내지 않게 여기서도 기본값을 채우지 않고 `Optional` 로 그대로 들고 있는다.
/// 배열도 키 자체가 빠져 올 수 있어 `Optional` 로 받고 읽는 쪽에서 빈 배열로 본다.
struct ServerPublicProfile: Decodable, Hashable {
    let userId: Int64?
    let nickname: String?
    /// `NicknameCandidate.color` 10종 중 하나. 카드 팔레트의 지정색이다.
    let nicknameColor: String?
    let profileImageUrl: String?
    let introduction: String?
    let mannerRating: Double?
    let travelStyles: [ServerProfileOption]?
    let interestedRegions: [ServerRegionOption]?

    var profileImageURL: URL? {
        profileImageUrl.flatMap(URL.init(string:))
    }

    var travelStyleLabels: [String] {
        (travelStyles ?? []).map(\.label)
    }

    var interestedRegionNames: [String] {
        (interestedRegions ?? []).map(\.signguName)
    }
}

/// `GET /api/v1/users/{userId}/travel-reviews` — 다른 여행자들이 이 사람에게 남긴 평가 (2026-08-25 배포).
///
/// **여행 제목과 작성 시각은 응답에 없다** — 어느 여행에서 받은 평가인지, 최신순인지 알 수 없어
/// 화면에도 그 줄을 만들지 않는다 (BE 요청 대상).
/// 남긴 사람의 닉네임 색이 함께 오므로 평가마다 그 사람 색으로 강조선을 긋는다.
struct ServerReceivedTravelReview: Decodable, Hashable, Identifiable {
    let reviewerId: Int64
    let reviewerNickname: String
    let reviewerNicknameColor: String?
    let reviewerProfileImageUrl: String?
    let content: String

    var id: Int64 { reviewerId }
}

struct ServerProfileOptions: Decodable, Hashable {
    let travelStyles: [ServerProfileOption]
    let interestedRegions: [ServerRegionOption]
}

struct ServerProfileUpdate: Encodable {
    let introduction: String?
    let travelStyleIds: [Int64]
    let interestedRegionIds: [Int64]
    let birthDate: String
    let gender: String
}

final class UserProfileAPIClient: @unchecked Sendable {
    static let shared = UserProfileAPIClient()

    private let api: MoyeoAPIClient

    init(api: MoyeoAPIClient = .shared) {
        self.api = api
    }

    func myProfile() async throws -> ServerMyProfile {
        try await api.get("/api/v1/users/me/profile")
    }

    /// 25 프로필 카드가 쓰는 공개 프로필. `me` 가 아닌 다른 사용자의 색상·소개·여행 스타일이다.
    func publicProfile(userID: Int64) async throws -> ServerPublicProfile {
        try await api.get("/api/v1/users/\(userID)/profile")
    }

    /// 25-1 카드 뒷면의 "다른 여행자들이 남긴 평가".
    func travelReviews(userID: Int64) async throws -> [ServerReceivedTravelReview] {
        try await api.get("/api/v1/users/\(userID)/travel-reviews")
    }

    func profileOptions() async throws -> ServerProfileOptions {
        try await api.get("/api/v1/users/me/profile/options")
    }

    func updateProfile(_ update: ServerProfileUpdate) async throws -> ServerMyProfile {
        try await api.send("/api/v1/users/me/profile", method: "PUT", body: update)
    }
}
