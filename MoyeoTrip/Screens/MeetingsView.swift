//
//  MeetingsView.swift
//  MoyeoTrip
//

import SwiftUI

enum MeetingSegment: String, CaseIterable, Hashable {
  case ongoing = "진행중"
  case applied = "신청중"
  case confirmed = "확정"
  case ended = "종료"
}

struct MeetingsView: View {
  /// 목록·고른 세그먼트는 화면 밖 보관소에 있다 — 재진입 시 다시 부르지 않는다
  /// (TAB-STATE-CANON R1·R3).
  @ObservedObject var tabData: MoyeoTabDataStore
  @Binding var chatThreads: [ChatThread]
  /// 19-2 시트가 열리는 동안 하단 탭바를 숨긴다 — 안 숨기면 탭바가 시트 버튼을 가린다.
  @Binding var isBottomNavigationSuppressed: Bool
  var tripContext = TripInteractionContext()
  /// 19-2 참가 신청 취소 확인. 취소는 대기 순번을 잃는 행동이라 되돌릴 수 없다 —
  /// 지금까지 확인 없이 바로 눌리는 자리였다.
  @State private var cancelCandidate: ServerWaitingRoom?
  @State private var isCancellingApplication = false
  /// 신청 취소가 실패한 이유. 있으면 확인 시트를 닫지 않고 그 자리에 적는다.
  @State private var cancelFailure: String?

  /// 진입 세그먼트(`UITEST_SCREEN`)는 보관소 초기값으로 들어온다 —
  /// 화면을 만드는 동안 보관소를 건드리지 않는다.
  init(
    tabData: MoyeoTabDataStore,
    chatThreads: Binding<[ChatThread]>,
    isBottomNavigationSuppressed: Binding<Bool> = .constant(false),
    tripContext: TripInteractionContext = TripInteractionContext()
  ) {
    self.tabData = tabData
    _chatThreads = chatThreads
    _isBottomNavigationSuppressed = isBottomNavigationSuppressed
    self.tripContext = tripContext
  }

  private var segment: MeetingSegment {
    tabData.meetingSegment
  }

  private var serverWaiting: [ServerWaitingRoom]? {
    tabData.meetingWaitingRooms
  }

  private var serverRooms: [ServerMyChatRoom]? {
    tabData.meetingRooms
  }

  /// 21 견본을 뽑아 올 방 — 내 채팅방 중 첫 방이다. 참여 중인 방이 없으면 nil 이고,
  /// 화면은 카드를 지어내지 않고 빈 상태를 그린다 (NO-MOCK-CANON R1).
  private var specialMessagesRoomID: Int64? {
    serverRooms?.first?.roomId ?? chatThreads.first?.serverRoomID
  }

  /// 19-2 안내 문구는 19-1 시트와 직접 진입(`ApplyCancelView`)이 같은 것을 쓴다.
  private func applyCancelLines(_ room: ServerWaitingRoom) -> [String] {
    ApplyCancelView.lines(for: room)
  }

  private func confirmApplyCancel(_ room: ServerWaitingRoom) {
    guard !isCancellingApplication else { return }
    isCancellingApplication = true
    cancelFailure = nil
    Task {
      let failure = await cancelServerApplication(roomID: room.roomId)
      isCancellingApplication = false
      // 실패하면 **시트를 닫지 않는다** — 닫아 버리면 취소된 것처럼 보인다.
      if let failure {
        cancelFailure = failure
      } else {
        cancelCandidate = nil
      }
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      MoyeoHeader(
        title: "모임",
        showsBottomBorder: false
      )

      // 21 은 카드 렌더링 견본이다 — 그릴 실제 메시지가 있어야 하므로 내 방 하나를 실어 보낸다.
      NavigationLink(value: MeetingsRoute.specialMessages(specialMessagesRoomID)) {
        SpecialMessagesEntry()
          .padding(.horizontal, 18)
          .padding(.bottom, 6)
      }
      .buttonStyle(.plain)

      MeetingSegmentTabs(
        selectedSegment: $tabData.meetingSegment,
        threads: chatThreads,
        appliedCountOverride: serverWaiting?.count,
        serverCounts: serverSegmentCounts
      )
      .padding(.horizontal, 18)
      .padding(.bottom, 8)

      ScrollView {
        segmentContent
          .padding(.horizontal, 18)
          .padding(.bottom, 132)
      }
      .scrollBounceBehavior(.basedOnSize)
      // 당겨서 새로고침이 **실제로 다시 받아온다.** 예전에는 이 목록이 첫 로드 이후
      // 다시 불리지 않아, 불발 처리한 방이 「모집중」으로 남았다 (IOS-F143).
      .refreshable { await tabData.refreshMeetings() }
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .navigationDestination(for: TripRecruitment.self) { trip in
      TripDetailView(
        trip: trip,
        isApplied: tripContext.isApplied(trip),
        threadProvider: tripContext.chatThreadProvider,
        onApplied: tripContext.onApplyTrip,
        onSendChatMessage: tripContext.onSendChatMessage
      )
    }
    .navigationDestination(for: ChatThread.self) { thread in
      ChatRoomView(thread: thread) { message in
        updateThreadPreview(threadID: thread.id, message: message)
      }
    }
    .navigationDestination(for: MeetingsRoute.self) { route in
      switch route {
      case .specialMessages(let roomID):
        SpecialMessageCardsView(roomID: roomID)
      case .applyCancel(let roomID):
        ApplyCancelView(roomID: roomID)
      }
    }
    // 19-2 — 되돌릴 수 없는 행동이라 확인 시트를 먼저 띄운다 (기획 `ConfirmSheet`).
    // 화면 뿌리에 얹어야 시트가 목록 영역이 아니라 화면 바닥에 붙는다.
    .overlay {
      if let room = cancelCandidate {
        MoyeoConfirmSheet(
          title: "참가 신청을 취소할까요?",
          subject: room.title,
          lines: applyCancelLines(room),
          cancelTitle: "그대로 둘게요",
          confirmTitle: "신청 취소",
          isDanger: true,
          isBusy: isCancellingApplication,
          failureMessage: cancelFailure,
          identifier: "applyCancel",
          onCancel: {
            cancelCandidate = nil
            cancelFailure = nil
          },
          onConfirm: { confirmApplyCancel(room) }
        )
      }
    }
    .onChange(of: cancelCandidate?.roomId) { _, roomID in
      isBottomNavigationSuppressed = roomID != nil
    }
    // 처음 들어오면 받아오고, 이미 받아 둔 값이 있으면 **화면을 지우지 않고 뒤에서 다시 받는다** —
    // 탭을 다녀오면 방 상태 변화가 반영돼야 한다 (IOS-F143).
    .task {
      if tabData.meetingRooms == nil {
        await tabData.loadMeetingsIfNeeded()
      } else {
        await tabData.refreshMeetings()
      }
    }
    .accessibilityIdentifier("screen.meetings")
  }

  /// 세그먼트 본문. 서버가 준 방만 그리고, 못 받으면 §2 빈 상태를 그린다.
  @ViewBuilder
  private var segmentContent: some View {
    if segment == .applied {
      appliedSegmentContent
    } else {
      roomSegmentContent
    }
  }

  /// 캐시가 없고 처음 받아오는 중일 때만 로딩 문구를 띄운다 (R2).
  /// 이미 받은 목록은 갱신 중에도 그대로 보여준다.
  private var isLoadingWithoutCache: Bool {
    tabData.isLoadingMeetings && serverRooms == nil
  }

  @ViewBuilder
  private var appliedSegmentContent: some View {
    if let serverWaiting, !serverWaiting.isEmpty {
      ServerWaitingTripList(rooms: serverWaiting) { room in
        cancelCandidate = room
      }
    } else if isLoadingWithoutCache {
      MoyeoEmptyStateView(
        message: MoyeoEmptyText.loading,
        accessibilityIdentifier: "meetings.applied.loading"
      )
    } else {
      MoyeoEmptyStateView(
        message: MoyeoEmptyText.noChatRooms,
        systemImage: "person.3",
        accessibilityIdentifier: "meetings.applied.empty"
      )
    }
  }

  @ViewBuilder
  private var roomSegmentContent: some View {
    if serverRooms != nil {
      // 세그먼트별 문구는 `ServerMeetingList` 가 갖고 있다. 예전에는 여기서 `threads.isEmpty`
      // 를 먼저 잡아 네 세그먼트 모두 「참여 중인 채팅방이 없어요」 하나로 끝났고,
      // 세그먼트별 문구는 **도달할 수 없는 죽은 코드**였다 (IOS-F12).
      ServerMeetingList(threads: serverThreads(for: segment), segment: segment)
    } else if !sessionThreads.isEmpty {
      // 이 세션에서 만들어진 방(모집 만들기 직후)만 남는다
      ChatListView(threads: sessionThreads)
    } else if isLoadingWithoutCache {
      MoyeoEmptyStateView(
        message: MoyeoEmptyText.loading,
        accessibilityIdentifier: "meetings.loading"
      )
    } else {
      MoyeoEmptyStateView(
        message: MoyeoEmptyText.noChatRooms,
        systemImage: "person.3",
        accessibilityIdentifier: "meetings.empty"
      )
    }
  }

  /// 세그먼트별 서버 방 목록 — 서버 상태(status·ended)로만 나눈다
  private func serverThreads(for segment: MeetingSegment) -> [ChatThread] {
    guard let serverRooms else { return [] }
    let rooms: [ServerMyChatRoom]
    switch segment {
    case .ongoing:
      rooms = serverRooms.filter { !$0.ended }
    case .applied:
      rooms = []
    case .confirmed:
      rooms = serverRooms.filter { !$0.ended && $0.status == "CONFIRMED" }
    case .ended:
      rooms = serverRooms.filter(\.ended)
    }
    // 함수 참조 대신 클로저로 호출해 main-actor 격리를 유지한다(Swift 6).
    return rooms.map { ServerTripMapper.chatThread(from: $0) }
  }

  private var serverSegmentCounts: [MeetingSegment: Int]? {
    guard serverRooms != nil else { return nil }
    return [
      .ongoing: serverThreads(for: .ongoing).count,
      .confirmed: serverThreads(for: .confirmed).count,
      .ended: serverThreads(for: .ended).count
    ]
  }

  /// 신청 취소. 실패하면 화면에 적을 문구를 돌려준다 — 예전에는 빈 `catch` 로 삼켜
  /// **시트가 그냥 닫히고 줄도 그대로**라 눌렀는지조차 알 수 없었다 (TC SOCIAL-010 계열).
  private func cancelServerApplication(roomID: Int64) async -> String? {
    do {
      try await ChatRoomAPIClient.shared.cancelApplication(roomID: roomID)
      tabData.removeMeetingWaitingRoom(roomID: roomID)
      return nil
    } catch {
      // 실패한 까닭이 「그 신청이 이제 없다」일 수 있다 — 그 사이 호스트가 승인했거나
      // 다른 기기에서 이미 취소한 경우다. 까닭만 적고 목록을 그대로 두면 승인돼 참여 중인 방이
      // 계속 「호스트 승인을 기다리는 중」으로 남는다 (TC MEET-011).
      // 통신이 안 되는 상황이면 이 다시 읽기도 실패해 **목록은 그대로** 남는다.
      await tabData.refreshMeetings()
      return error.moyeoUserMessage(
        fallback: "신청을 취소하지 못했어요. 잠시 후 다시 시도해주세요.")
    }
  }

  private var sessionThreads: [ChatThread] {
    switch segment {
    case .ongoing:
      return chatThreads.filter { !$0.isReadOnly }
    case .applied:
      return []
    case .confirmed:
      return chatThreads.filter { !$0.isReadOnly && $0.statusSummary.contains("확정") }
    case .ended:
      return chatThreads.filter(\.isReadOnly)
    }
  }

  private func updateThreadPreview(threadID: String, message: ChatMessage) {
    guard let index = chatThreads.firstIndex(where: { $0.id == threadID }) else { return }
    chatThreads[index] = chatThreads[index].withAppendedMessage(message)
  }
}

private struct SpecialMessagesEntry: View {
  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "sparkles")
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(MoyeoTheme.forest)
        .frame(width: 34, height: 34)
        .background(MoyeoTheme.leaf)
        .clipShape(Circle())
      VStack(alignment: .leading, spacing: 3) {
        Text("친구 도감 메시지")
          .font(MoyeoTypography.cardTitle)
          .foregroundStyle(MoyeoTheme.ink)
        Text("여행 뒤 남는 특별 메시지를 모아봐요.")
          .font(MoyeoTypography.cardMeta)
          .foregroundStyle(MoyeoTheme.muted)
      }
      Spacer()
      Image(systemName: "chevron.right")
        .font(.caption.weight(.heavy))
        .foregroundStyle(MoyeoTheme.text400)
    }
    .padding(.vertical, 9)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(MoyeoTheme.softLine)
        .frame(height: 1)
    }
  }
}

private struct MeetingSegmentTabs: View {
  @Binding var selectedSegment: MeetingSegment
  let threads: [ChatThread]
  /// 실서버 신청중 개수 — 서버 데이터가 있으면 그 개수를 쓴다
  var appliedCountOverride: Int?
  /// 실서버 내 모임 개수 — chat-rooms/my 가 성공했을 때만 채워진다
  var serverCounts: [MeetingSegment: Int]?

  var body: some View {
    HStack(spacing: 0) {
      ForEach(MeetingSegment.allCases, id: \.self) { item in
        let count = item == .applied
          ? (appliedCountOverride ?? threads.count(for: item))
          : (serverCounts?[item] ?? threads.count(for: item))

        Button {
          selectedSegment = item
        } label: {
          VStack(spacing: 7) {
            HStack(spacing: 5) {
              Text(item.rawValue)
              Text("\(count)")
            }
            .font(MoyeoTypography.tab)
            .foregroundStyle(selectedSegment == item ? MoyeoTheme.forest : MoyeoTheme.muted)

            Rectangle()
              .fill(selectedSegment == item ? MoyeoTheme.forest : .clear)
              .frame(height: 2)
          }
          .frame(maxWidth: .infinity)
          .frame(height: 48)
          .contentShape(Rectangle())
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("\(item.rawValue), \(count)")
          .accessibilityIdentifier("meetings.segment.\(item.rawValue)")
        }
        .buttonStyle(.plain)
      }
    }
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(MoyeoTheme.softLine)
        .frame(height: 1)
    }
  }
}

extension [ChatThread] {
  fileprivate func count(for segment: MeetingSegment) -> Int {
    switch segment {
    case .ongoing:
      return filter { !$0.isReadOnly }.count
    case .applied:
      return 0
    case .confirmed:
      return filter { !$0.isReadOnly && $0.statusSummary.contains("확정") }.count
    case .ended:
      return filter(\.isReadOnly).count
    }
  }
}

private struct ServerMeetingList: View {
  let threads: [ChatThread]
  let segment: MeetingSegment

  var body: some View {
    if threads.isEmpty {
      VStack(spacing: 6) {
        Text(emptyTitle)
          .font(.subheadline.weight(.heavy))
          .foregroundStyle(MoyeoTheme.ink)
        Text(emptyHint)
          .font(.caption.weight(.semibold))
          .foregroundStyle(MoyeoTheme.muted)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 44)
      .accessibilityIdentifier("meeting.server.empty.\(segment.rawValue)")
    } else {
      ChatListView(threads: threads)
    }
  }

  private var emptyTitle: String {
    switch segment {
    case .applied:
      return "신청한 모임이 없어요"
    case .confirmed:
      return "확정된 여행이 없어요"
    case .ended:
      return "종료된 여행이 없어요"
    case .ongoing:
      return "진행 중인 모임이 없어요"
    }
  }

  /// 세그먼트마다 **다음에 할 일**이 다르다 — 같은 한 줄을 넷에 돌려쓰지 않는다.
  private var emptyHint: String {
    switch segment {
    case .applied:
      return "신청하면 호스트 승인을 기다리는 동안 여기에 보여요."
    case .confirmed:
      return "호스트가 여행을 확정하면 여기로 옮겨져요."
    case .ended:
      return "여행이 끝나면 채팅방이 14일 동안 여기에 남아요."
    case .ongoing:
      return "탐색에서 마음에 드는 모임을 찾아보세요."
    }
  }
}
