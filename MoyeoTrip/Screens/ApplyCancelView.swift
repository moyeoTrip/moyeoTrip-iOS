//
//  ApplyCancelView.swift
//  MoyeoTrip
//
//  19-2 참가 신청 취소 확인. 19-1 신청중 목록의 `신청 취소` 에서 온다 —
//  대기열 순번을 잃는 행동이라 되돌릴 수 없다.
//  근거: `DELETE /api/v1/chat-rooms/{roomId}/applications/me`
//
//  취소할 신청이 없으면 **시트를 지어내지 않는다.** 웹(`screens-gaps.jsx` ScreenApplyCancel)과 같이
//  제목이 있는 빈 상태를 그린다 — 그래야 이 자리가 무슨 화면인지 남는다 (NO-MOCK-CANON R2).
//

import SwiftUI

struct ApplyCancelView: View {
  /// 캡처·딥링크가 지정한 방. 없으면 내 신청 목록의 첫 건을 쓴다.
  var roomID: Int64?

  @Environment(\.dismiss) private var dismiss
  @State private var rooms: [ServerWaitingRoom]?
  @State private var didLoad = false
  @State private var loadFailed = false
  @State private var isCancelling = false

  /// 대기 순번은 서버가 준 값(`waitlistPosition`)일 때만 적는다 — 없으면 그 문장을 짓지 않는다.
  static func lines(for room: ServerWaitingRoom) -> [String] {
    let first = room.waitlistPosition.map { "대기 순번 \($0)번이 사라져요. 다시 신청하면 맨 뒤부터예요." }
      ?? "다시 신청하면 맨 뒤부터예요."
    return [first, "호스트에게는 따로 알리지 않아요."]
  }

  private var target: ServerWaitingRoom? {
    guard let rooms else { return nil }
    if let roomID { return rooms.first { $0.roomId == roomID } }
    return rooms.first
  }

  var body: some View {
    ZStack {
      // 취소할 신청이 있으면 19-1 목록을 깔고 그 위에 확인 시트를 얹는다 (20-1a·20-1b 와 같은 방식).
      if let target {
        backdrop(target)
        MoyeoConfirmSheet(
          title: "참가 신청을 취소할까요?",
          subject: target.title,
          lines: Self.lines(for: target),
          cancelTitle: "그대로 둘게요",
          confirmTitle: "신청 취소",
          isDanger: true,
          isBusy: isCancelling,
          identifier: "applyCancel",
          onCancel: { dismiss() },
          onConfirm: { cancel(target) }
        )
      } else {
        unavailable
      }
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
    .task { await load() }
    .accessibilityIdentifier("screen.applyCancel")
  }

  private func backdrop(_ room: ServerWaitingRoom) -> some View {
    VStack(spacing: 0) {
      MoyeoHeader(title: "참가 신청 취소")
      ScrollView {
        ServerWaitingTripList(rooms: rooms ?? [room]) { _ in }
          .padding(.horizontal, 18)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
  }

  /// 취소할 신청이 없을 때. 제목을 남겨 이 화면이 무엇인지 알 수 있게 한다.
  private var unavailable: some View {
    VStack(spacing: 0) {
      MoyeoHeader(title: "참가 신청 취소")
      Spacer(minLength: 0)
      MoyeoEmptyStateView(
        message: emptyMessage,
        systemImage: "person.3",
        accessibilityIdentifier: "applyCancel.empty"
      )
      Spacer(minLength: 0)
    }
  }

  private var emptyMessage: String {
    if loadFailed { return MoyeoEmptyText.loadFailed }
    return didLoad ? MoyeoEmptyText.noApplications : MoyeoEmptyText.loading
  }

  private func load() async {
    guard MoyeoServerSync.isEnabled else {
      didLoad = true
      return
    }
    do {
      rooms = try await ChatRoomAPIClient.shared.myWaitingRooms()
    } catch {
      loadFailed = true
    }
    didLoad = true
  }

  private func cancel(_ room: ServerWaitingRoom) {
    guard !isCancelling else { return }
    isCancelling = true
    Task {
      try? await ChatRoomAPIClient.shared.cancelApplication(roomID: room.roomId)
      isCancelling = false
      dismiss()
    }
  }
}
