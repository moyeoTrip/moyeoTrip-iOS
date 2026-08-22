import Foundation

struct OfflinePendingChatMessage: Codable, Identifiable, Equatable {
    let id: String
    let threadID: String
    let body: String
    let createdAt: Date

    var message: ChatMessage {
        ChatMessage(
            id: id,
            senderName: MockData.profile.name,
            avatar: MockData.profile.avatar,
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

enum UITestCaptureSeed {
    static func prepare(arguments: [String], defaults: UserDefaults = .standard) {
        guard arguments.contains("UITEST_MODE"), arguments.contains("UITEST_OFFLINE_CHAT") else { return }
        let pending = OfflinePendingChatMessage(
            id: "uitest-offline-pending",
            threadID: "chat-cheongsong-juwangsan",
            body: "연결되면 보내주세요",
            createdAt: Date(timeIntervalSince1970: 1_786_937_600)
        )
        OfflineChatQueue.enqueue(pending, defaults: defaults)
    }
}
