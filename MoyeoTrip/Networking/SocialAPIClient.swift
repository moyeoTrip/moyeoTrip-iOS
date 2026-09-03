//
//  SocialAPIClient.swift
//  MoyeoTrip
//
//  친구·차단·여행 도감 실서버 연동 (연동 대상 7).
//

import Foundation

struct ServerFriendUser: Decodable, Hashable {
    let userId: Int64
    let nickname: String
    let profileImageUrl: String?
    let introduction: String?

    var profileImageURL: URL? {
        MoyeoImageURL.resolve(profileImageUrl)
    }
}

struct ServerFriendList: Decodable, Hashable {
    let totalCount: Int
    let friends: [ServerFriend]
}

struct ServerFriend: Decodable, Identifiable, Hashable {
    let friendshipId: Int64
    let user: ServerFriendUser
    let lastActive: String?

    var id: Int64 { friendshipId }
}

struct ServerFriendRequestList: Decodable, Hashable {
    let totalCount: Int
    let requests: [ServerFriendRequest]
}

struct ServerFriendRequest: Decodable, Identifiable, Hashable {
    let requestId: Int64
    let user: ServerFriendUser
    let requestedAt: String

    var id: Int64 { requestId }
}

struct ServerBlockedUser: Decodable, Identifiable, Hashable {
    let userId: Int64
    let nickname: String
    let profileImageUrl: String?
    let blockedAt: String

    var id: Int64 { userId }

    var profileImageURL: URL? {
        MoyeoImageURL.resolve(profileImageUrl)
    }
}

struct ServerTravelDex: Decodable, Hashable {
    let totalCount: Int
    let companions: [ServerTravelDexCompanion]
}

struct ServerTravelDexCompanion: Decodable, Identifiable, Hashable {
    struct Memory: Decodable, Hashable {
        let chatRoomId: Int64
        let tripTitle: String
        let tripDate: String
        let oneLineReview: String?
    }

    let userId: Int64
    let nickname: String
    let profileImageUrl: String?
    let mannerRating: Double?
    let tripCount: Int
    let latestTripDate: String
    let latestTripTitle: String
    let memories: [Memory]

    var id: Int64 { userId }

    var profileImageURL: URL? {
        MoyeoImageURL.resolve(profileImageUrl)
    }
}

final class SocialAPIClient: @unchecked Sendable {
    static let shared = SocialAPIClient()

    private let api: MoyeoAPIClient

    init(api: MoyeoAPIClient = .shared) {
        self.api = api
    }

    // MARK: 친구

    func friends() async throws -> ServerFriendList {
        try await api.get("/api/v1/users/me/friends")
    }

    func receivedFriendRequests() async throws -> ServerFriendRequestList {
        try await api.get("/api/v1/users/me/friend-requests/received")
    }

    func sentFriendRequests() async throws -> ServerFriendRequestList {
        try await api.get("/api/v1/users/me/friend-requests/sent")
    }

    func sendFriendRequest(userID: Int64) async throws {
        try await api.sendVoid("/api/v1/users/me/friend-requests/\(userID)", method: "POST")
    }

    func acceptFriendRequest(requestID: Int64) async throws {
        try await api.sendVoid("/api/v1/users/me/friend-requests/\(requestID)/accept", method: "POST")
    }

    func rejectFriendRequest(requestID: Int64) async throws {
        try await api.sendVoid("/api/v1/users/me/friend-requests/\(requestID)/reject", method: "POST")
    }

    func cancelFriendRequest(requestID: Int64) async throws {
        try await api.sendVoid("/api/v1/users/me/friend-requests/\(requestID)", method: "DELETE")
    }

    /// 27-2a 친구 끊기 — **되돌릴 수 없다.** 호출부는 확인 단계를 거친 뒤에만 부른다.
    ///
    /// 경로 변수는 **상대 사용자 ID** 다(`DELETE /users/me/friends/{friendUserId}`).
    /// 예전에는 `friendshipId` 를 넣고 있었다 — 호출부가 없어 드러나지 않았던 결함이다.
    func removeFriend(friendUserID: Int64) async throws {
        try await api.sendVoid("/api/v1/users/me/friends/\(friendUserID)", method: "DELETE")
    }

    // MARK: 차단

    func blockedUsers() async throws -> [ServerBlockedUser] {
        try await api.get("/api/v1/users/me/blocks")
    }

    /// 차단. 30-2 신고 시트가 실제로 반영하는 유일한 동작이다 —
    /// 신고 접수 API 는 서버에 없어서, 시트가 할 수 있는 건 차단뿐이다(웹 30-2 와 같은 사정).
    func block(userID: Int64) async throws {
        try await api.sendVoid("/api/v1/users/me/blocks/\(userID)", method: "POST")
    }

    func unblock(userID: Int64) async throws {
        try await api.sendVoid("/api/v1/users/me/blocks/\(userID)", method: "DELETE")
    }

    // MARK: 여행 도감

    func travelDex() async throws -> ServerTravelDex {
        try await api.get("/api/v1/users/me/travel-dex")
    }
}
