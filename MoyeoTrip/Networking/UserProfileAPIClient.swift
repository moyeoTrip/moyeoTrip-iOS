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

    func profileOptions() async throws -> ServerProfileOptions {
        try await api.get("/api/v1/users/me/profile/options")
    }

    func updateProfile(_ update: ServerProfileUpdate) async throws -> ServerMyProfile {
        try await api.send("/api/v1/users/me/profile", method: "PUT", body: update)
    }
}
