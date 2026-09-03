import Foundation

struct OfflinePendingChatMessage: Codable, Identifiable, Equatable {
    let id: String
    let threadID: String
    let body: String
    let createdAt: Date

    /// 내 말풍선이라 보낸 사람 표기는 쓰지 않는다 — 이름을 지어내지 않으려고 비워 둔다.
    var message: ChatMessage {
        ChatMessage(
            id: id,
            senderName: "",
            avatar: "",
            body: body,
            time: "전송 대기",
            isMine: true
        )
    }
}

enum OfflineChatQueue {
    private static let storageKey = "moyeo.pendingChatMessages.v1"

    static func messages(for threadID: String, defaults: UserDefaults = .standard) -> [OfflinePendingChatMessage] {
        allMessages(defaults: defaults)
            .filter { $0.threadID == threadID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    static func enqueue(_ pending: OfflinePendingChatMessage, defaults: UserDefaults = .standard) {
        var messages = allMessages(defaults: defaults)
        guard !messages.contains(where: { $0.id == pending.id }) else { return }
        messages.append(pending)
        save(messages, defaults: defaults)
    }

    static func remove(ids: Set<String>, defaults: UserDefaults = .standard) {
        save(allMessages(defaults: defaults).filter { !ids.contains($0.id) }, defaults: defaults)
    }

    private static func allMessages(defaults: UserDefaults) -> [OfflinePendingChatMessage] {
        guard let data = defaults.data(forKey: storageKey),
              let messages = try? JSONDecoder().decode([OfflinePendingChatMessage].self, from: data)
        else {
            return []
        }
        return messages
    }

    private static func save(_ messages: [OfflinePendingChatMessage], defaults: UserDefaults) {
        if messages.isEmpty {
            defaults.removeObject(forKey: storageKey)
            return
        }
        if let data = try? JSONEncoder().encode(messages) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
