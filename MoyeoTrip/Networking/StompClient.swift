//
//  StompClient.swift
//  MoyeoTrip
//
//  STOMP 1.2 최소 구현 — `URLSessionWebSocketTask` 위에 프레임만 얹는다 (2026-09-14 결정 ⑤).
//
//  서버는 SockJS 를 쓰지 않는다(`WebSocketConfig.registerStompEndpoints` 에 `withSockJS()` 가
//  없다) — **맨 WebSocket 위의 STOMP** 다. 인증은 HTTP 핸드셰이크가 아니라
//  **`CONNECT` 프레임의 `Authorization` 네이티브 헤더**에서 한다.
//
//  외부 STOMP 라이브러리를 들이지 않는다. 우리가 쓰는 명령은 CONNECT·SUBSCRIBE·SEND·
//  DISCONNECT 넷뿐이고, 의존성을 하나 더 들이면 오픈소스 고지 화면까지 함께 움직여야 한다.
//

import Foundation

/// STOMP 프레임 한 장.
/// 프레임 만들기·읽기는 메인 액터와 상관이 없다 — 소켓 수신 루프에서 바로 쓴다.
nonisolated struct StompFrame: Equatable, Sendable {
    let command: String
    var headers: [String: String] = [:]
    var body: String = ""

    /// 헤더 값 이스케이프는 STOMP 1.2 규칙이다(`\` → `\\`, 개행 → `\n` 등).
    /// 우리가 보내는 값(토큰·목적지)에는 없지만, 규칙을 지키지 않는 프레임은 서버가 통째로 버린다.
    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: ":", with: "\\c")
    }

    private static func unescape(_ value: String) -> String {
        var result = ""
        var isEscaping = false
        for character in value {
            if isEscaping {
                switch character {
                case "r": result.append("\r")
                case "n": result.append("\n")
                case "c": result.append(":")
                case "\\": result.append("\\")
                default: result.append(character)
                }
                isEscaping = false
            } else if character == "\\" {
                isEscaping = true
            } else {
                result.append(character)
            }
        }
        return result
    }

    /// 전송할 문자열. 프레임 끝은 **NUL 바이트**다.
    var encoded: String {
        var text = command + "\n"
        for key in headers.keys.sorted() {
            text += "\(Self.escape(key)):\(Self.escape(headers[key] ?? ""))\n"
        }
        text += "\n" + body + "\u{0}"
        return text
    }

    /// 받은 문자열 한 장을 프레임으로 읽는다. 하트비트(개행만 있는 프레임)는 `nil` 이다.
    static func decode(_ text: String) -> StompFrame? {
        let trimmed = text.hasSuffix("\u{0}") ? String(text.dropLast()) : text
        guard let headerEnd = trimmed.range(of: "\n\n") else {
            // 본문 구분선이 없으면 하트비트이거나 우리가 모르는 프레임이다.
            return nil
        }
        let head = String(trimmed[trimmed.startIndex..<headerEnd.lowerBound])
        let body = String(trimmed[headerEnd.upperBound...])
        var lines = head.components(separatedBy: "\n")
        guard let command = lines.first, !command.isEmpty else { return nil }
        lines.removeFirst()

        var headers: [String: String] = [:]
        for line in lines {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = unescape(String(line[line.startIndex..<separator]))
            let value = unescape(String(line[line.index(after: separator)...]))
            // STOMP 1.2 — 같은 이름이 여러 번 오면 **먼저 온 값**이 이긴다.
            if headers[key] == nil { headers[key] = value }
        }
        return StompFrame(command: command, headers: headers, body: body)
    }
}

/// 한 WebSocket 연결 위의 STOMP 세션.
///
/// 상태(소켓·구독 번호)를 들고 있고 여러 곳에서 동시에 불릴 수 있어 `actor` 로 둔다.
actor StompClient {
    enum StompError: LocalizedError {
        /// 서버가 `CONNECTED` 대신 `ERROR` 를 줬거나, 소켓이 먼저 닫혔다.
        case handshakeRejected(String)
        case notConnected

        var errorDescription: String? {
            switch self {
            case .handshakeRejected(let reason): return reason
            case .notConnected: return "실시간 연결이 없어요."
            }
        }
    }

    private let session: URLSession
    private var socket: URLSessionWebSocketTask?
    private var receiveLoop: Task<Void, Never>?
    private var heartbeatLoop: Task<Void, Never>?
    private var subscriptionCounter = 0

    init(session: URLSession = .shared) {
        self.session = session
    }

    var isConnected: Bool { socket != nil }

    /// 소켓을 열고 `CONNECT` → `CONNECTED` 까지 마친다.
    ///
    /// - Parameters:
    ///   - onFrame: `CONNECTED` 이후 도착하는 모든 프레임.
    ///   - onClose: 연결이 끊겼을 때 한 번. 재연결은 호출부가 정한다.
    func connect(
        url: URL,
        accessToken: String,
        onFrame: @escaping @Sendable (StompFrame) -> Void,
        onClose: @escaping @Sendable (Error?) -> Void
    ) async throws {
        await disconnect()

        let task = session.webSocketTask(with: url)
        task.resume()
        socket = task

        let connect = StompFrame(
            command: "CONNECT",
            headers: [
                "accept-version": "1.2",
                "host": url.host() ?? "",
                // 우리는 하트비트를 **보낼 수** 있고, 받을 필요는 없다.
                // 서버(SimpleBroker)가 스케줄러 없이 뜨면 하트비트가 꺼진 채로 협상된다.
                "heart-beat": "10000,0",
                // **HTTP 핸드셰이크가 아니라 이 헤더**로 인증한다 (WebSocketConfig.authenticate).
                "Authorization": "Bearer \(accessToken)"
            ]
        )
        try await task.send(.string(connect.encoded))

        // `CONNECTED` 가 올 때까지는 이 자리에서 직접 읽는다 — 받기 루프를 먼저 띄우면
        // 핸드셰이크 결과를 기다릴 곳이 없어진다.
        while true {
            let message = try await task.receive()
            guard let frame = Self.frame(from: message) else { continue }
            switch frame.command {
            case "CONNECTED":
                startReceiveLoop(task: task, onFrame: onFrame, onClose: onClose)
                startHeartbeat(task: task, negotiated: frame.headers["heart-beat"])
                return
            case "ERROR":
                await disconnect()
                throw StompError.handshakeRejected(frame.headers["message"] ?? frame.body)
            default:
                continue
            }
        }
    }

    /// 목적지를 구독한다. **서버가 `SUBSCRIBE` 도 검사한다** — 참가자가 아닌 방을 구독하면
    /// `ERROR` 프레임이 오고 연결이 닫힌다.
    func subscribe(destination: String) async throws {
        guard let socket else { throw StompError.notConnected }
        subscriptionCounter += 1
        let frame = StompFrame(
            command: "SUBSCRIBE",
            headers: [
                "id": "sub-\(subscriptionCounter)",
                "destination": destination,
                "ack": "auto"
            ]
        )
        try await socket.send(.string(frame.encoded))
    }

    func send(destination: String, jsonBody: String) async throws {
        guard let socket else { throw StompError.notConnected }
        let frame = StompFrame(
            command: "SEND",
            headers: [
                "destination": destination,
                "content-type": "application/json;charset=utf-8",
                // 본문에 NUL 이 없어도 길이를 적어 준다 — 서버가 본문 끝을 정확히 자른다.
                "content-length": "\(jsonBody.utf8.count)"
            ],
            body: jsonBody
        )
        try await socket.send(.string(frame.encoded))
    }

    func disconnect() async {
        receiveLoop?.cancel()
        receiveLoop = nil
        heartbeatLoop?.cancel()
        heartbeatLoop = nil
        if let socket {
            // `DISCONNECT` 는 예의상 보낸다 — 실패해도 소켓은 어차피 닫는다.
            try? await socket.send(.string(StompFrame(command: "DISCONNECT").encoded))
            socket.cancel(with: .goingAway, reason: nil)
        }
        socket = nil
    }

    private func startReceiveLoop(
        task: URLSessionWebSocketTask,
        onFrame: @escaping @Sendable (StompFrame) -> Void,
        onClose: @escaping @Sendable (Error?) -> Void
    ) {
        receiveLoop = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    let message = try await task.receive()
                    guard let frame = Self.frame(from: message) else { continue }
                    if frame.command == "ERROR" {
                        await self?.disconnect()
                        onClose(StompError.handshakeRejected(frame.headers["message"] ?? frame.body))
                        return
                    }
                    onFrame(frame)
                } catch {
                    guard !Task.isCancelled else { return }
                    await self?.disconnect()
                    onClose(error)
                    return
                }
            }
        }
    }

    /// 협상된 값이 있으면 그 주기로 개행 한 글자를 보낸다. **조용히 멈추지 않기 위한 것**이다 —
    /// 중간의 프록시는 아무 말 없는 소켓을 먼저 끊는다.
    private func startHeartbeat(task: URLSessionWebSocketTask, negotiated: String?) {
        let parts = (negotiated ?? "0,0").split(separator: ",").compactMap { Int($0) }
        // `heart-beat:<서버가 보낼 주기>,<서버가 받고 싶은 주기>` — 우리가 지킬 것은 뒤엣값이다.
        let wanted = parts.count == 2 ? parts[1] : 0
        let interval = wanted > 0 ? max(wanted, 1000) : 20_000
        heartbeatLoop = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000)
                guard !Task.isCancelled else { return }
                try? await task.send(.string("\n"))
            }
        }
    }

    private static func frame(from message: URLSessionWebSocketTask.Message) -> StompFrame? {
        switch message {
        case .string(let text):
            return StompFrame.decode(text)
        case .data(let data):
            return String(data: data, encoding: .utf8).flatMap(StompFrame.decode)
        @unknown default:
            return nil
        }
    }
}
