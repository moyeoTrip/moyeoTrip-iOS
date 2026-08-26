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
    /// 캡처 시드가 넣는 대기 메시지 id. 플래그가 없는 실행에서는 이 id 를 지워 상태 누수를 막는다.
    static let seededMessageID = "uitest-offline-pending"

    static func prepare(arguments: [String], defaults: UserDefaults = .standard) {
        guard arguments.contains("UITEST_MODE") else { return }
        // 캡처는 실행 순서에 의존해서는 안 된다.
        // 이 시드는 UserDefaults 에 영구 저장되므로, 플래그 없이 들어온 캡처 실행에서 지우지 않으면
        // 앞서 찍은 `offline-chat` 의 전송 대기 메시지가 뒤이어 찍는 20 채팅방 캡처에 그대로 남는다
        // (실제로 커밋된 `ios/light/20--chat.png` 가 그렇게 오염됐다 — 재현·수정 확인).
        guard arguments.contains("UITEST_OFFLINE_CHAT") else {
            OfflineChatQueue.remove(ids: [seededMessageID], defaults: defaults)
            return
        }
        let pending = OfflinePendingChatMessage(
            id: seededMessageID,
            threadID: "chat-cheongsong-juwangsan",
            body: "연결되면 보내주세요",
            createdAt: Date(timeIntervalSince1970: 1_786_937_600)
        )
        OfflineChatQueue.enqueue(pending, defaults: defaults)
    }
}
