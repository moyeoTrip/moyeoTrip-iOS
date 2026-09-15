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

    /// FCM 등록 토큰을 서버에 올린다 — `PUT /notifications/fcm-token`, 204.
    ///
    /// 예전에는 **이 호출부가 앱에 0곳**이었다. 토큰이 도는(Firebase 가 새 토큰을 주는) 순간
    /// 서버는 옛 토큰을 계속 들고 있어 그 뒤로 푸시가 한 통도 오지 않았다 (IOS-F108).
    func updateFCMToken(_ token: String) async throws {
        try await api.sendVoid(
            "/api/v1/notifications/fcm-token",
            method: "PUT",
            body: ServerFCMTokenUpdate(fcmToken: token)
        )
    }

    /// 로그아웃할 때 서버에서 토큰을 지운다 — `DELETE /notifications/fcm-token`, 204.
    ///
    /// 지우지 않으면 **로그아웃한 기기로 그 사람의 알림이 계속 간다.** 기기를 넘겨주거나
    /// 계정을 바꿔 로그인하면 남의 대화 내용이 잠금화면에 뜬다 (IOS-F66).
    func deleteFCMToken() async throws {
        try await api.sendVoid("/api/v1/notifications/fcm-token", method: "DELETE")
    }
}

/// 서버 `UpdateFcmTokenRequest` — `@NotBlank` · `@Size(max = 255)`.
struct ServerFCMTokenUpdate: Encodable {
    let fcmToken: String
}
