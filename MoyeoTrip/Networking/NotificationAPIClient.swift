//
//  NotificationAPIClient.swift
//  MoyeoTrip
//
//  알림 실서버 연동 (연동 대상 5) — 목록·읽음 처리·설정·강퇴 이력.
//

import Foundation

struct ServerNotificationPage: Decodable, Hashable {
    let notifications: [ServerNotification]
    let nextLastId: Int64?
    let hasNext: Bool
    let unreadCount: Int64
}

struct ServerNotification: Decodable, Identifiable, Hashable {
    let notificationId: Int64
    let type: String
    let content: String
    let chatRoomId: Int64?
    let referenceId: Int64
    let read: Bool
    let createdAt: String

    var id: Int64 { notificationId }
}

struct ServerNotificationSettings: Decodable, Hashable {
    let doNotDisturbEnabled: Bool
    let doNotDisturbStartTime: String?
    let doNotDisturbEndTime: String?
    let doNotDisturbDays: [String]
}

struct ServerNotificationSettingsUpdate: Encodable {
    let chatNotificationMode: String
    let recruitmentDeadlineEnabled: Bool
    let socialActivityEnabled: Bool
    let marketingEnabled: Bool
    let doNotDisturbEnabled: Bool
    let doNotDisturbStartTime: String?
    let doNotDisturbEndTime: String?
    let doNotDisturbDays: [String]
}

final class NotificationAPIClient: @unchecked Sendable {
    static let shared = NotificationAPIClient()

    private let api: MoyeoAPIClient

    init(api: MoyeoAPIClient = .shared) {
        self.api = api
    }

    func notifications(lastID: Int64? = nil, size: Int = 20, unreadOnly: Bool = false) async throws -> ServerNotificationPage {
        var query = [
            URLQueryItem(name: "size", value: "\(size)"),
            URLQueryItem(name: "unreadOnly", value: unreadOnly ? "true" : "false")
        ]
        if let lastID {
            query.append(URLQueryItem(name: "lastId", value: "\(lastID)"))
        }
        return try await api.get("/api/v1/notifications", query: query)
    }

    func markRead(notificationID: Int64) async throws {
        try await api.sendVoid("/api/v1/notifications/\(notificationID)/read", method: "PUT")
    }

    func markAllRead() async throws {
        try await api.sendVoid("/api/v1/notifications/read-all", method: "PUT")
    }

    func settings() async throws -> ServerNotificationSettings {
        try await api.get("/api/v1/notifications/settings")
    }

    func updateSettings(_ update: ServerNotificationSettingsUpdate) async throws -> ServerNotificationSettings {
        try await api.send("/api/v1/notifications/settings", method: "PUT", body: update)
    }

    func kickHistory(notificationID: Int64) async throws -> ServerKickHistory {
        try await api.get("/api/v1/notifications/\(notificationID)/kick-history")
    }
}
