//
//  ChatRoomFooter.swift
//  MoyeoTrip
//
//  20 채팅방 하단 — 입력창이거나, 입력할 수 없는 이유다.
//  `ChatRoomBody` 타입 본문이 300줄을 넘어 갈라냈다.
//

import SwiftUI

struct ChatRoomFooter: View {
  /// 403 미참가 · 404 방 없음일 때 서버가 준 안내. 있으면 입력창을 그리지 않는다 (IOS-F92).
  let accessRevokedMessage: String?
  let isReadOnly: Bool
  let archiveStatus: String?
  @Binding var draft: String
  let isOffline: Bool
  /// 직전 전송이 실패한 이유. 있으면 입력칸 **위에** 한 줄로 보여준다 (TC CHAT-011).
  var sendFailureMessage: String?
  let send: () -> Void
  let attachment: () -> Void

  var body: some View {
    if let accessRevokedMessage {
      // 나갔거나 사라진 방이다 — 입력창을 남겨 두면 보낼 수 없는 글을 쓰게 된다.
      notice(title: "이 채팅방에 참여하고 있지 않아요", body: accessRevokedMessage)
        .accessibilityIdentifier("chat.accessRevoked")
    } else if isReadOnly {
      notice(
        title: archiveStatus ?? "읽기 전용 보관",
        body: "종료된 모임이라 새 메시지를 보낼 수 없어요."
      )
    } else {
      VStack(spacing: 0) {
        if let sendFailureMessage {
          HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
              .font(.caption2.weight(.bold))
            Text(sendFailureMessage)
              .font(.caption2.weight(.semibold))
              .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
          }
          .foregroundStyle(MoyeoTheme.warningText)
          .padding(.horizontal, 18)
          .padding(.vertical, 7)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(MoyeoTheme.warningBackground)
          .accessibilityIdentifier("chat.message.sendFailed")
        }
        ChatComposer(draft: $draft, isOffline: isOffline, send: send, attachment: attachment)
      }
    }
  }

  private func notice(title: String, body: String) -> some View {
    VStack(spacing: 4) {
      Text(title)
        .font(.caption.weight(.heavy))
        .foregroundStyle(MoyeoTheme.forest)
      Text(body)
        .font(.caption.weight(.semibold))
        .foregroundStyle(MoyeoTheme.muted)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .padding(.horizontal, 20)
    .background(MoyeoTheme.card)
  }
}

/// 채팅 날짜 구분선 — "오늘" · "어제" · "2026년 9월 14일 (일)".
///
/// 하루가 바뀌어도 표시가 없어 어제 온 약속과 오늘 온 약속이 한 덩어리로 읽혔다
/// (IOS-F107. 웹이 먼저 넣었고 규칙을 그대로 맞췄다).
struct ChatDaySeparator: View {
  let label: String

  var body: some View {
    HStack(spacing: 10) {
      Rectangle().fill(MoyeoTheme.softLine).frame(height: 1)
      Text(label)
        .font(MoyeoTypography.tinyMeta)
        .foregroundStyle(MoyeoTheme.muted)
        .fixedSize()
      Rectangle().fill(MoyeoTheme.softLine).frame(height: 1)
    }
    .padding(.vertical, 2)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(label) 대화")
    .accessibilityIdentifier("chat.daySeparator")
  }
}

/// 채팅방에 들어왔는데 읽기 응답을 **한 번도** 못 받았을 때의 안내 + 다시 시도.
///
/// 권한 없음(403·404)은 `ChatRoomFooter` 의 `accessRevokedMessage` 가 맡는다. 이쪽은 통신
/// 실패·5xx 라 **통신이 돌아오면 회복된다** — 예전에는 이 갈래가 `return` 뿐이라 방이 통째로
/// 비어 있는데 한 마디도 없었고, 빈 방인지 못 불러온 것인지 알 길이 없었다.
struct ChatEntryFailureNotice: View {
  let message: String
  let onRetry: () -> Void

  var body: some View {
    VStack(spacing: 6) {
      Text(message)
        .font(.caption.weight(.semibold))
        .foregroundStyle(MoyeoTheme.dangerRed)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
      Button("다시 시도", action: onRetry)
        .font(.caption.weight(.semibold))
        .foregroundStyle(MoyeoTheme.forest)
    }
    .frame(maxWidth: .infinity)
    .accessibilityIdentifier("chat.entryFailure.retry")
  }
}
