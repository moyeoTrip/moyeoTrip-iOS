//
//  ChatRoomOfflineQueue.swift
//  MoyeoTrip
//
//  연결이 돌아왔을 때 대기 중인 메시지를 실제로 보내는 부분.
//  `ChatRoomBody` 타입 본문이 300줄을 넘어 갈라냈다.
//

import SwiftUI

extension ChatRoomBody {
  func flushPendingMessages() {
    let pending = OfflineChatQueue.messages(for: thread.id)
    guard !pending.isEmpty else { return }

    // 서버 모임은 **실제로 보내고, 성공한 것만** 큐에서 지운다.
    // 예전에는 `onSendMessage`(대화 미리보기를 갱신하는 콜백)만 부르고 큐를 통째로 비웠다 —
    // 그 경로에는 서버 전송이 없어서 연결이 돌아오면 **상대에게 닿지 않은 메시지가
    // 대기 목록에서 조용히 사라졌다** (2026-09-10).
    if MoyeoServerSync.isEnabled, let roomID = thread.serverRoomID {
      Task {
        var deliveredIDs: Set<String> = []
        for item in pending {
          guard
            (try? await ChatRoomWriteAPIClient.shared.sendMessage(
              roomID: roomID,
              content: item.message.body
            )) != nil
          else {
            // 하나가 실패하면 **거기서 멈춘다** — 뒤엣것을 먼저 보내면 대화 순서가 뒤집힌다.
            break
          }
          deliveredIDs.insert(item.id)
        }
        guard !deliveredIDs.isEmpty else { return }
        pendingMessageIDs.subtract(deliveredIDs)
        OfflineChatQueue.remove(ids: deliveredIDs)
        await loadServerContent()
      }
      return
    }

    for item in pending {
      onSendMessage(item.message)
    }
    let sentIDs = Set(pending.map(\.id))
    pendingMessageIDs.subtract(sentIDs)
    OfflineChatQueue.remove(ids: sentIDs)
  }
}
