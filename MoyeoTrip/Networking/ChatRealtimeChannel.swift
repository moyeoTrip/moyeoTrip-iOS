//
//  ChatRealtimeChannel.swift
//  MoyeoTrip
//
//  채팅방 한 곳의 실시간 채널 — STOMP 구독·전송·재연결 (2026-09-14 결정 ⑤).
//
//  사용자: 「당연히 실시간해야지, 나는 당연히 실시간인 줄 알았어.」
//  예전에는 5초 폴링이라 상대가 보낸 메시지가 최대 5초 늦게 떴다 (QA BE-27).
//
//  **폴링을 지우지 않는다.** 연결이 끊기거나 실패하면 화면이 폴링으로 떨어지고,
//  복구되면 다시 STOMP 를 쓴다. 화면 복귀 때는 놓친 메시지를 기존 조회 API 로 한 번 따라잡는다.
//

import Combine
import Foundation
import SwiftUI

/// 실시간 연결 상태. 화면은 이 값으로 **폴링을 켤지 끌지**를 정한다.
enum ChatRealtimeState: Equatable {
    case idle
    case connecting
    case connected
    /// 끊겼고 다시 붙는 중이다. 값은 몇 번째 재시도인지 — 안내 문구를 가르는 데 쓴다.
    case reconnecting(attempt: Int)
}

@MainActor
final class ChatRealtimeChannel: ObservableObject {
    @Published private(set) var state: ChatRealtimeState = .idle

    /// 새 메시지가 왔을 때. 화면이 목록에 얹는다.
    var onMessage: ((ServerChatMessage) -> Void)?
    /// 투표가 갱신됐을 때. 투표 카드는 메시지 목록 안에 있어 **다시 읽어야** 반영된다.
    var onPollUpdated: (() -> Void)?
    /// 연결이 (재)수립됐을 때. 끊겨 있던 동안 놓친 메시지를 따라잡는 자리다.
    var onConnected: (() -> Void)?

    /// 구독은 붙었는데 **오는 것을 읽을 수 없는** 상태인가.
    ///
    /// 2026-09-14 실서버는 `/topic/chat-rooms/{id}/messages` 로 채팅 메시지가 아니라
    /// `JsonNode` 의 빈(bean) 속성(`{"array":false,"nodeType":"OBJECT",…}`)을 브로드캐스트한다.
    /// 프레임은 오는데 안에 `messageId` 도 `content` 도 없다 — 서버
    /// `RealtimeMessagingService` 가 `JsonNode` 를 그대로 `convertAndSend` 하면서 생긴 일이다.
    ///
    /// 그런 프레임을 한 번이라도 받으면 **이 연결로는 실시간을 쓰지 않는다.** 그냥 두면
    /// 「연결됐다」는 이유로 폴링이 쉬어, 5초 폴링만 있던 예전보다 **더 나빠진다.**
    @Published private(set) var isDegraded = false

    /// 폴링을 늦춰도 되는가. 연결됐고 **읽을 수 있는 것이 올 때만** 참이다.
    var isLive: Bool { state == .connected && !isDegraded }

    private let client = StompClient()
    private var roomID: Int64?
    private var lifecycle: Task<Void, Never>?
    private let decoder = JSONDecoder()

    /// 재연결 지수 백오프. 1초에서 시작해 30초에서 멈춘다 —
    /// 더 벌리면 화면을 보고 있는 사람에게 「죽은 것」과 구분되지 않는다.
    private static let baseBackoff: UInt64 = 1_000_000_000
    private static let maxBackoff: UInt64 = 30_000_000_000

    /// 방을 구독한다. 같은 방으로 다시 부르면 아무 일도 하지 않는다.
    func start(roomID: Int64) {
        guard self.roomID != roomID || lifecycle == nil else { return }
        stop()
        self.roomID = roomID
        lifecycle = Task { [weak self] in
            await self?.run(roomID: roomID)
        }
    }

    func stop() {
        lifecycle?.cancel()
        lifecycle = nil
        roomID = nil
        state = .idle
        isDegraded = false
        Task { [client] in await client.disconnect() }
    }

    /// STOMP 로 메시지를 보낸다. 연결이 없으면 던져서 **호출부가 REST 로 떨어지게** 한다.
    func send(content: String) async throws {
        guard let roomID, isLive else { throw StompClient.StompError.notConnected }
        let body = ServerSendChatMessageOverStomp(content: content)
        let data = try JSONEncoder().encode(body)
        guard let json = String(data: data, encoding: .utf8) else {
            throw StompClient.StompError.notConnected
        }
        try await client.send(destination: "/app/chat-rooms/\(roomID)/messages", jsonBody: json)
    }

    // MARK: - 연결 수명

    private func run(roomID: Int64) async {
        var attempt = 0
        while !Task.isCancelled {
            state = attempt == 0 ? .connecting : .reconnecting(attempt: attempt)
            if await connectOnce(roomID: roomID) {
                attempt = 0
                state = .connected
                onConnected?()
                // 끊길 때까지 기다린다 — `onClose` 가 상태를 되돌리면 여기서 깨어난다.
                while !Task.isCancelled, state == .connected {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
                guard !Task.isCancelled else { return }
                attempt = 1
                continue
            }
            attempt += 1
            let delay = min(Self.baseBackoff << UInt64(min(attempt - 1, 5)), Self.maxBackoff)
            state = .reconnecting(attempt: attempt)
            try? await Task.sleep(nanoseconds: delay)
        }
    }

    /// 한 번 붙어 본다. 성공하면 `true`.
    private func connectOnce(roomID: Int64) async -> Bool {
        guard MoyeoServerSync.isEnabled,
              let url = Self.webSocketURL(),
              let tokens = (try? KeychainAuthSessionStore().load()) ?? nil else { return false }
        do {
            try await client.connect(
                url: url,
                accessToken: tokens.accessToken,
                // `self` 를 먼저 꺼내 상수로 잡는다 — 캡처한 `var` 를 다른 실행 문맥에서
                // 읽으면 Swift 6 에서 오류가 된다.
                onFrame: { [weak self] frame in
                    guard let self else { return }
                    Task { @MainActor in self.handle(frame) }
                },
                onClose: { [weak self] _ in
                    guard let self else { return }
                    Task { @MainActor in self.markDisconnected() }
                }
            )
            // 서버가 `SUBSCRIBE` 도 검사한다 — 참가자가 아니면 여기서 `ERROR` 가 돌아온다.
            try await client.subscribe(destination: "/topic/chat-rooms/\(roomID)/messages")
            try await client.subscribe(destination: "/topic/chat-rooms/\(roomID)/polls")
            return true
        } catch {
            await client.disconnect()
            return false
        }
    }

    private func markDisconnected() {
        guard state == .connected else { return }
        state = .reconnecting(attempt: 1)
    }

    private func handle(_ frame: StompFrame) {
        guard frame.command == "MESSAGE",
              let destination = frame.headers["destination"],
              let data = frame.body.data(using: .utf8) else { return }
        if destination.hasSuffix("/messages") {
            guard let message = try? decoder.decode(ServerChatMessage.self, from: data) else {
                // 읽을 수 없는 것이 왔다 — 이 연결로는 실시간을 믿지 않고 폴링에 맡긴다.
                isDegraded = true
                return
            }
            onMessage?(message)
        } else if destination.hasSuffix("/polls") {
            // 투표 갱신 payload 는 방 전체 카드를 다시 그릴 근거가 못 된다(카드 하나만 온다) —
            // 화면이 기존 조회 API 로 다시 읽게 한다.
            onPollUpdated?()
        }
    }

    /// REST 주소에서 `wss://…/ws` 를 만든다. 주소를 두 군데 적어 두면 한쪽만 바뀐다.
    private static func webSocketURL() -> URL? {
        var components = URLComponents(
            url: AuthAPIConfiguration.current.baseURL.appending(path: "/ws"),
            resolvingAgainstBaseURL: false
        )
        switch components?.scheme?.lowercased() {
        case "https": components?.scheme = "wss"
        case "http": components?.scheme = "ws"
        default: break
        }
        return components?.url
    }
}

/// `/app/chat-rooms/{roomId}/messages` 본문 — 서버 `SendChatMessageRequest` 와 같은 모양이다.
/// 답글·멘션은 이 경로로 보내지 않는다(화면이 아직 쓰지 않는다) — 보내지 않으면 서버 기본값이다.
private struct ServerSendChatMessageOverStomp: Encodable {
    let content: String
}
