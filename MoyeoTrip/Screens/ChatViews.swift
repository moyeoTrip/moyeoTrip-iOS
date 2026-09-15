//
//  ChatViews.swift
//  MoyeoTrip
//

// swiftlint:disable file_length

import SwiftUI

struct ChatListView: View {
  let threads: [ChatThread]

  var body: some View {
    VStack(spacing: 0) {
      ForEach(threads) { thread in
        NavigationLink(value: thread) {
          ChatThreadRow(thread: thread)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("meeting.thread.\(thread.id)")
      }
    }
  }
}

private struct ChatThreadRow: View {
  let thread: ChatThread

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      if let thumbnailURL = thread.thumbnailURL {
        // 실서버 모임 — 서버가 준 대표 썸네일을 그린다
        CachedRemoteImage(url: thumbnailURL, fallbackShape: .square) { image in
          image
            .resizable()
            .scaledToFill()
        } placeholder: {
          MoyeoTheme.leaf
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      } else if thread.isServerBacked {
        // 서버가 썸네일을 주지 않은 모임 — 공용 플레이스홀더로 채운다(지어낸 목데이터가 아니다)
        MoyeoPlaceholderImageView(shape: .square)
          .frame(width: 56, height: 56)
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      } else {
        MoyeoPhotoTile(
          mascot: thread.mascot,
          mood: thread.mood,
          height: 56,
          cornerRadius: 16
        )
        .frame(width: 56)
      }

      VStack(alignment: .leading, spacing: 3) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          HStack(spacing: 7) {
            Text(thread.tripTitle)
            .font(MoyeoTypography.font(size: 14, weight: .bold, relativeTo: .headline))
              .foregroundStyle(MoyeoTheme.ink)
              .lineLimit(1)
              .truncationMode(.tail)
              .layoutPriority(1)
            if thread.unreadCount > 0 {
              Circle()
                .fill(MoyeoTheme.coral)
                .frame(width: 6, height: 6)
            }
          }

          Spacer(minLength: 4)

          Text(thread.updatedAt)
            .font(MoyeoTypography.font(size: 11, relativeTo: .caption))
            .foregroundStyle(MoyeoTheme.text400)
            .monospacedDigit()
        }

        if !thread.courseDisplayName.isEmpty {
          Label(thread.courseDisplayName, systemImage: "map.fill")
            .font(MoyeoTypography.font(size: 11, relativeTo: .caption2))
            .foregroundStyle(MoyeoTheme.text400)
            .lineLimit(1)
        }

        Text(thread.statusSummary)
          .font(MoyeoTypography.font(size: 12, relativeTo: .caption))
          .foregroundStyle(MoyeoTheme.muted)
          .monospacedDigit()
          .lineLimit(1)

        HStack(alignment: .top, spacing: 10) {
          Text(thread.lastMessage)
            .font(MoyeoTypography.font(size: 13, relativeTo: .subheadline))
            .foregroundStyle(MoyeoTheme.text700)
            .lineLimit(1)

          Spacer(minLength: 6)

          if thread.unreadCount > 0 {
            Text("\(thread.unreadCount)")
              .font(.caption2.bold())
              .foregroundStyle(.white)
              .frame(minWidth: 20, minHeight: 20)
              .padding(.horizontal, 3)
              .background(MoyeoTheme.coral)
              .clipShape(Capsule())
          }
        }
      }
    }
    .padding(.vertical, 14)
    .frame(minHeight: 96)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(MoyeoTheme.softLine)
        .frame(height: 1)
    }
  }
}

struct ChatRoomView: View {
  let thread: ChatThread
  let onSendMessage: (ChatMessage) -> Void
  @State private var toolbarMessage: String?
  @State private var supportRoute: SupportRoute?
  /// 20-2에서 카드를 보내면 올라간다 — 본문이 서버 메시지를 다시 읽는 신호다
  @State private var reloadToken = 0
  /// 본문이 서버 멤버 목록을 읽고 알려 주는 값. 20-2 공지 타일을 호스트에게만 여는 데 쓴다 (IOS-F73).
  @State private var isCurrentUserHost = false
  /// 본문이 서버에서 읽어 온 방 이름.
  ///
  /// 방 id 만 아는 진입(알림·딥링크)은 `stubThread` 로 들어와 `tripTitle` 이 **비어 있다.**
  /// 내비게이션 제목이 그 빈 값을 쓰면 **제목 없는 채팅방**이 열린다 — 알림에서 채팅방으로
  /// 곧장 보내기 시작하면서 실제로 그랬다 (2026-09-13 기기 확인, IOS-F147 과 같은 부류).
  @State private var resolvedTitle: String?

  init(thread: ChatThread, onSendMessage: @escaping (ChatMessage) -> Void = { _ in }) {
    self.thread = thread
    self.onSendMessage = onSendMessage
  }

  var body: some View {
    ChatRoomBody(
      thread: thread,
      reloadToken: reloadToken,
      onSendMessage: onSendMessage,
      onOpenRoute: { supportRoute = $0 },
      onHostResolved: { isCurrentUserHost = $0 },
      onTitleResolved: { resolvedTitle = $0 }
    )
    .background(MoyeoTheme.background.ignoresSafeArea())
    .navigationTitle(resolvedTitle ?? thread.tripTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItemGroup(placement: .navigationBarTrailing) {
        // 화면기획·웹의 채팅 헤더는 대화 검색이다. 연락처를 받지 않는 서비스라 통화 진입은 없다.
        Button {
          toolbarMessage = "이 채팅방의 대화를 검색할 수 있어요."
        } label: {
          Image(systemName: "magnifyingglass")
        }
        .accessibilityLabel("대화 검색")

        Button {
          supportRoute = .chatMenu(thread.id)
        } label: {
          Image(systemName: "line.3.horizontal")
        }
        .accessibilityLabel("모임 정보")
        .accessibilityIdentifier("chat.openMenu")
      }
    }
    .alert(
      "채팅방 도구",
      isPresented: Binding<Bool>(
        get: { toolbarMessage != nil },
        set: { if !$0 { toolbarMessage = nil } }
      )
    ) {
      Button("확인", role: .cancel) {
        toolbarMessage = nil
      }
    } message: {
      Text(toolbarMessage ?? "")
    }
    .navigationDestination(item: $supportRoute) { route in
      // 서버 모임은 목데이터 스레드로 되돌아가지 않도록 이 스레드를 그대로 넘긴다
      if thread.isServerBacked {
        switch route {
        case .chatMenu:
          ChatSideMenuView(thread: thread)
        case .noticeHistory:
          NoticeHistoryView(thread: thread)
        case .chatAttach:
          ChatAttachmentMenuView(
            serverRoomID: thread.serverRoomID,
            isCurrentUserHost: isCurrentUserHost,
            onShared: { reloadToken += 1 }
          )
        default:
          SupportDestinationView(route: route)
        }
      } else {
        SupportDestinationView(route: route)
      }
    }
  }
}

/// changeLog14 — 채팅방 본문. 오버레이(20-2 첨부 메뉴 · 32 신고 시트)의 배경이
/// 실루엣이 아니라 실제 채팅방과 같은 코드를 쓰도록 화면 껍데기와 분리했다.
struct ChatRoomBody: View {
  @Environment(\.moyeoIsOffline) private var isOffline
  let thread: ChatThread
  /// 20-2에서 카드를 보낸 뒤 서버 메시지를 다시 읽게 하는 신호
  var reloadToken = 0
  var onSendMessage: (ChatMessage) -> Void = { _ in }
  var onOpenRoute: (SupportRoute) -> Void = { _ in }
  /// 서버 멤버 목록을 읽고 「내가 호스트인가」를 바깥 화면에 알린다 (IOS-F73).
  var onHostResolved: (Bool) -> Void = { _ in }
  /// 서버에서 읽어 온 방 이름을 바깥 화면에 알린다 — 제목 없는 채팅방이 열리지 않게 한다.
  var onTitleResolved: (String) -> Void = { _ in }
  @Environment(\.scenePhase) private var scenePhase
  @State var messages: [ChatMessage]
  @State private var draft = ""
  /// 전송이 실패한 이유. 있으면 입력칸 위에 한 줄로 보여준다 (TC CHAT-011).
  @State private var sendFailureMessage: String?
  @State var pendingMessageIDs: Set<String>
  /// 참여 중인 서버 방의 읽기 응답 — 403이거나 미로그인이면 nil로 남고 목데이터가 유지된다
  @State private var serverContent: ServerChatRoomContent?
  /// 이 방을 더 이상 볼 수 없다는 서버 안내(403 미참가 · 404 방 없음). 나오면 입력창을 닫는다 (IOS-F92).
  @State private var accessRevokedMessage: String?
  /// 지금 투표를 보내는 중인 메시지. 채팅방에서도 투표가 **실제로** 되게 한다 (IOS-F76).
  @State var votingMessageID: Int64?
  /// 투표가 실패한 까닭. 있으면 입력칸 위에 한 줄로 보여준다 (TC SOCIAL-010 계열).
  @State private var voteFailureMessage: String?
  /// 길게 눌러 고른 **내 메시지**. 20-6 삭제 시트가 이 메시지를 지운다.
  ///
  /// 화면(`MessageDeleteView`)도 API(`deleteMessage`)도 오래 있었는데 **그 화면을 미는 곳이
  /// 캡처 하네스뿐**이라 제품에서는 닿을 수 없었다 (IOS-F16, 죽은 UI).
  @State private var messageToDelete: ServerChatMessage?
  /// 실시간 채널(STOMP). 연결돼 있는 동안 폴링은 쉰다 (2026-09-14 결정 ⑤).
  @StateObject private var realtime = ChatRealtimeChannel()

  // MARK: 과거 메시지 (TC CHAT-015)
  //
  // 서버는 최근 한 페이지(기본 50건)와 함께 커서를 준다 — `nextId`(그보다 **작은** 메시지가
  // 다음 페이지) · `hasNext`. 네트워킹 계층은 처음부터 둘 다 읽고 있었는데
  // **이 화면이 쓰지 않아** 최근 한 페이지 위로는 영영 올라갈 수 없었다.
  // 방에 메시지가 쌓이면 과거 대화가 사라진 것처럼 보인다.

  /// 지금까지 화면에 모은 서버 메시지. **messageId 오름차순**(위가 과거)으로 유지한다.
  /// 최근 페이지만 담던 예전과 달리, 위로 올려 받은 과거 페이지가 여기 쌓인다.
  @State private var loadedMessages: [ServerChatMessage] = []
  /// 더 오래된 메시지가 남아 있는가. 거짓이면 맨 위에서 더 부르지 않는다.
  @State private var hasOlderMessages = false
  /// 과거 페이지를 받는 중.
  @State private var isLoadingOlderMessages = false
  /// 맨 위까지 올라갔다. 폴링 응답의 `hasNext` 가 이 사실을 되돌리지 못하게 막는다 —
  /// 최근 페이지 기준으로는 늘 「더 있다」이기 때문이다.
  @State private var reachedOldestMessage = false
  /// 과거 페이지 조회가 실패한 이유. 있으면 목록 맨 위에 다시 시도 줄로 보여준다.
  @State private var olderMessagesFailure: String?
  /// 방에 들어왔는데 읽기 응답을 **한 번도** 못 받았을 때의 안내. 권한 문제(403·404)는
  /// `accessRevokedMessage` 가 맡고, 이쪽은 통신 실패·5xx 라 **다시 시도로 회복된다**.
  @State private var entryFailureMessage: String?

  init(
    thread: ChatThread,
    reloadToken: Int = 0,
    onSendMessage: @escaping (ChatMessage) -> Void = { _ in },
    onOpenRoute: @escaping (SupportRoute) -> Void = { _ in },
    onHostResolved: @escaping (Bool) -> Void = { _ in },
    onTitleResolved: @escaping (String) -> Void = { _ in }
  ) {
    self.thread = thread
    self.reloadToken = reloadToken
    self.onHostResolved = onHostResolved
    self.onTitleResolved = onTitleResolved
    self.onSendMessage = onSendMessage
    self.onOpenRoute = onOpenRoute
    let pending = OfflineChatQueue.messages(for: thread.id)
    let existingIDs = Set(thread.messages.map(\.id))
    _messages = State(
      initialValue: thread.messages + pending.filter { !existingIDs.contains($0.id) }.map(\.message)
    )
    _pendingMessageIDs = State(initialValue: Set(pending.map(\.id)))
  }

  /// 서버 읽기 응답을 받았으면 그것을 얹은 스레드로 그린다 (20)
  private var displayThread: ChatThread {
    guard let serverContent else { return thread }
    return ServerTripMapper.chatThread(thread, applying: serverContent)
  }

  /// 메시지 응답에는 프로필 이미지가 없다 — 동행자 목록의 닉네임으로 붙인다
  private var avatarURLsByNickname: [String: URL] {
    guard let serverContent else { return [:] }
    var result: [String: URL] = [:]
    for member in serverContent.memberList.members {
      if let url = member.profileImageURL {
        result[member.nickname] = url
      }
    }
    return result
  }

  var body: some View {
    VStack(spacing: 0) {
      ChatRoomStatusHeader(thread: displayThread)

      // 오프라인 안내는 **앱 전역 배너 하나로만** 낸다 (`MoyeoOfflineBanner`, ContentView).
      // 예전에는 여기서 채팅 전용 배너를 하나 더 그려 「연결이 끊겼어요」가 한 화면에
      // 두 번 나왔다 (사용자 지적, 2026-09-06 · 37 캡처).
      // 대기 중인 메시지라는 사실은 말풍선의 「전송 대기」 배지가 이미 말해 준다.

      if let roadmap = serverContent?.roadmap, roadmap.active, !roadmap.places.isEmpty {
        // 여행 당일에만 서버가 로드맵을 활성으로 준다. 방문지까지 있어야 띠를 그린다 —
        // 서버가 `active` 만 주고 오늘 방문지가 비어 있으면 20-5 도 빈 상태라, 눌러도
        // 아무것도 없는 화면으로 보내는 셈이 된다 (`TripDayView` 와 같은 조건).
        // **누를 수 있어야 한다.** 예전에는 그냥 `HStack` 이라, 20-5 여행 당일 화면으로 가는
        // 길이 앱 전체에 확정 직후 1회성 화면 하나뿐이었다 — 그 화면을 닫고 나면 다시 갈 수
        // 없었다(캡처 하네스만 `SupportRoute.tripDay` 를 밀어 넣었다).
        Button {
          onOpenRoute(.tripDay(thread.id))
        } label: {
          ServerRoadmapBar(roadmap: roadmap)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("오늘의 여행 일정 보기")
      }

      // 화면기획 20 고정 공지 바 — 공지 제목 + "공지 4개 · 고정 2 · 이력 보기"
      // 서버 모임에 공지가 없으면 지어내지 않고 바를 감춘다
      if let noticeTitle = pinnedNoticeTitle {
        Button {
          onOpenRoute(.noticeHistory(thread.id))
        } label: {
          HStack(spacing: 9) {
            Image(systemName: "pin.fill")
            VStack(alignment: .leading, spacing: 2) {
              Text(noticeTitle)
                .lineLimit(1)
              Text(noticeSummaryText)
                .font(.caption2)
                .foregroundStyle(MoyeoTheme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
          }
          .font(.caption.weight(.heavy))
          .foregroundStyle(MoyeoTheme.ink)
          .padding(.horizontal, 16)
          .frame(height: 52)
          .background(MoyeoTheme.leaf)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chat.pinnedNotice")
      }

      // 화면기획 20 코스 바 — 코스 이름 + "방문지 4곳 · 호스트 직접 코스" + 경로 수정 버튼
      // 서버 모임도 18-1 여행 경로로 들어간다. 예전에는 정보만 보여줘서(경로 수정 API 가
      // 연동 전이었다) 채팅방에서 경로를 볼 길이 아예 없었는데, 18-1 이 이제 실제로
      // 편집·저장하므로 같은 화면으로 보낸다.
      if thread.isServerBacked {
        if !displayThread.courseDisplayName.isEmpty, let roomID = thread.serverRoomID {
          Button {
            onOpenRoute(
              .courseEdit("\(ServerTripMapper.serverTripIDPrefix)\(roomID)", serverRouteEditState))
          } label: {
            // 고칠 수 없는 사람에게는 「경로 수정」 버튼을 주지 않는다 — 눌러도 잠긴 화면만
            // 나오는 죽은 버튼이 된다. 그 대신 화살표로 들어갈 수 있다는 것만 알린다.
            courseBarLabel(
              showsEditButton: serverRouteEditState == .editable,
              showsChevron: serverRouteEditState != .editable)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("chat.routeSummary")
        } else if !displayThread.courseDisplayName.isEmpty {
          // 방 id 를 모르면 18-1 을 열 수 없다 — 정보만 보여준다.
          serverCourseBar
        }
      } else if let tripID = thread.tripID {
        Button {
          let state: RouteEditState = thread.routeEditState
          onOpenRoute(.courseEdit(tripID, state))
        } label: {
          courseBarLabel(showsEditButton: true)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chat.routeSummary")
      }

      // 대화는 **아래가 최신**이다. 앵커가 없으면 목록을 다시 그릴 때마다 맨 위로 튀어
      // 방금 보낸 메시지가 안 보였다 (IOS-F109).
      ScrollView {
        VStack(spacing: 14) {
          // 위로 끝까지 올리면 이전 페이지를 이어 붙인다 (TC CHAT-015).
          olderMessagesHeader

          // 권한 없음(403·404)이 아닌 실패로 아직 아무것도 못 받았을 때의 안내 + 다시 시도.
          if accessRevokedMessage == nil, let entryFailureMessage {
            ChatEntryFailureNotice(message: entryFailureMessage) { Task { await loadServerContent() } }
          }

          if displayThread.isReadOnly {
            ChatArchiveNotice(thread: displayThread)
          }

          ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
            // 날짜 구분선. 예전에는 **하루가 바뀌어도 표시가 없어**, 어제 온 약속과 오늘 온
            // 약속이 한 덩어리로 읽혔다 (IOS-F107 · 웹 교차). 서버 시각을 못 읽으면
            // 구분선을 지어내지 않는다.
            if let created = message.server?.createdAt,
               ServerDateTime.startsNewDay(created, after: index == 0 ? nil : messages[index - 1].server?.createdAt),
               let label = ServerDateTime.daySeparatorText(from: created) {
              ChatDaySeparator(label: label)
            }
            // 예전에는 `onVote` 를 넘기지 않아 채팅방 안의 투표 선택지가 **항상 비활성**이었다 —
            // 「공유된 항목」 견본에서만 투표할 수 있었다 (IOS-F76).
            MessageBubble(
              message: message,
              isPending: pendingMessageIDs.contains(message.id),
              avatarURL: avatarURLsByNickname[message.senderName],
              isVoting: votingMessageID != nil
                && votingMessageID == message.server?.messageId,
              onVote: displayThread.isReadOnly || accessRevokedMessage != nil
                ? nil
                : { card, option in Task { await vote(card: card, option: option) } },
              roomID: thread.serverRoomID
            )
            // 20-6 — **내가 보낸 메시지만** 길게 눌러 지운다. 시스템 메시지는 제외한다.
            .onLongPressGesture {
              guard let server = message.server, message.isMine,
                    server.type != "SYSTEM", !displayThread.isReadOnly,
                    accessRevokedMessage == nil else { return }
              messageToDelete = server
            }
          }
        }
        .padding(20)
      }
      .defaultScrollAnchor(.bottom)

      ChatRoomFooter(
        accessRevokedMessage: accessRevokedMessage,
        isReadOnly: displayThread.isReadOnly,
        archiveStatus: displayThread.archiveStatus,
        draft: $draft,
        isOffline: isOffline,
        // 전송 실패와 투표 실패는 같은 자리(입력칸 위 한 줄)를 쓴다.
        // 둘이 동시에 뜰 일은 없고, 방금 누른 것이 무엇이든 그 결과가 눈에 든다.
        sendFailureMessage: sendFailureMessage ?? voteFailureMessage,
        send: sendMessage,
        attachment: { onOpenRoute(.chatAttach(thread.id)) }
      )
    }
    .onAppear {
      if !isOffline {
        flushPendingMessages()
      }
    }
    .onChange(of: isOffline) { wasOffline, isNowOffline in
      if wasOffline, !isNowOffline {
        flushPendingMessages()
      }
    }
    .task {
      guard serverContent == nil else { return }
      await loadServerContent()
    }
    // 실시간 채널(STOMP). 방에 머무는 동안만 붙어 있고, 화면을 벗어나면 끊는다.
    .task(id: "realtime-\(thread.id)-\(scenePhase == .active)") {
      guard scenePhase == .active, MoyeoServerSync.isEnabled,
            let roomID = thread.serverRoomID, accessRevokedMessage == nil else {
        realtime.stop()
        return
      }
      realtime.onMessage = { message in applyRealtimeMessage(message) }
      // 투표 갱신은 카드 하나만 오므로 목록을 다시 읽어 반영한다.
      realtime.onPollUpdated = { Task { await loadServerContent() } }
      // **놓친 메시지를 한 번 따라잡는다** — 끊겨 있던 동안 온 것은 구독으로 오지 않는다.
      realtime.onConnected = { Task { await loadServerContent() } }
      realtime.start(roomID: roomID)
    }
    // **폴링은 폴백으로 남긴다** (결정 ⑤ — 「폴링을 바로 지우지 마라」).
    //
    // 끊겨 있으면 예전처럼 5초마다, 실시간이 붙어 있으면 **15초에 한 번**만 읽는다.
    // 붙어 있다고 폴링을 아예 멈추지는 않는다 — 구독은 붙었는데 오는 것을 못 읽는 서버
    // 상태(2026-09-14 실서버)가 실제로 있고, 그때 멈춰 버리면 **5초 폴링만 있던 예전보다
    // 더 나빠진다.** 예전에는 이 값이 「새 메시지가 오는 속도」 그 자체였다 (IOS-F106 · QA BE-27).
    .task(id: "poll-\(thread.id)-\(scenePhase == .active)") {
      guard scenePhase == .active, MoyeoServerSync.isEnabled, thread.serverRoomID != nil else { return }
      var tick = 0
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: Self.pollInterval)
        guard !Task.isCancelled, accessRevokedMessage == nil else { return }
        tick += 1
        if realtime.isLive, tick % Self.livePollEveryNTicks != 0 { continue }
        await loadServerContent()
      }
    }
    .onChange(of: scenePhase) { _, phase in
      // 백그라운드에서 돌아오면 폴링 주기를 기다리지 않고 바로 한 번 읽는다.
      guard phase == .active else { return }
      Task { await loadServerContent() }
    }
    .onChange(of: reloadToken) { _, _ in
      Task { await loadServerContent() }
    }
    .navigationDestination(item: $messageToDelete) { target in
      MessageDeleteView(
        roomID: thread.serverRoomID ?? 0,
        pickedMessage: target,
        onDeleted: { Task { await loadServerContent() } }
      )
    }
  }

  /// **폴백** 폴링 간격. 실시간(STOMP)이 끊겼을 때만 도는 값이다 (결정 ⑤).
  /// 예전에는 실시간 채널이 없어 이 값이 「새 메시지가 오는 속도」 그 자체였다 (BE-27).
  private static let pollInterval: UInt64 = 5_000_000_000
  /// 실시간이 붙어 있을 때 폴링을 몇 번에 한 번만 돌릴지 — 5초 × 3 = 15초 안전망.
  private static let livePollEveryNTicks = 3

  /// 참여 중인 서버 방의 읽기 응답을 받아 화면에 얹는다.
  /// 통신 실패면 기존 값을 그대로 두고, **403·404 면 입력창을 닫는다** (IOS-F92).
  func loadServerContent() async {
    guard MoyeoServerSync.isEnabled, let roomID = thread.serverRoomID else { return }
    switch await ChatRoomContentAPIClient.shared.access(roomID: roomID) {
    case .granted(let content):
      accessRevokedMessage = nil
      entryFailureMessage = nil
      serverContent = content
      applyServerMessages(content)
      onHostResolved(content.memberList.members.contains { $0.me && $0.host })
      let title = ServerTripMapper.chatThread(thread, applying: content).tripTitle
      if !title.isEmpty { onTitleResolved(title) }
    case .revoked(let message):
      accessRevokedMessage = message
      entryFailureMessage = nil
      onHostResolved(false)
    case .unavailable:
      // 통신 실패·5xx 다. 권한 문제가 **아니므로** 입력창은 닫지 않는다.
      // 다만 아직 아무것도 못 받았으면 화면이 통째로 비어 있는데 예전에는 **한 마디도 없었다** —
      // 빈 방인지 못 불러온 것인지 알 길이 없었다. 가진 내용이 있으면 그대로 두고 조용히 넘어간다.
      if serverContent == nil { entryFailureMessage = "대화를 불러오지 못했어요." }
      return
    }
  }

  /// 목록 맨 위 줄. 과거 페이지가 남아 있으면 보이고, 화면에 들어오는 순간 다음 페이지를 부른다.
  /// 더 없으면 아예 그리지 않는다 — `hasNext` 가 거짓이면 다시 부르지 않는다.
  @ViewBuilder private var olderMessagesHeader: some View {
    if let olderMessagesFailure {
      VStack(spacing: 6) {
        Text(olderMessagesFailure)
          .font(.caption.weight(.semibold))
          .foregroundStyle(MoyeoTheme.dangerRed)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
        Button("다시 시도") {
          Task { await loadOlderMessages() }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(MoyeoTheme.forest)
      }
      .frame(maxWidth: .infinity)
      .accessibilityIdentifier("chat.olderMessages.retry")
    } else if isLoadingOlderMessages {
      ProgressView()
        .frame(maxWidth: .infinity)
        .accessibilityLabel("이전 대화를 불러오는 중")
        .accessibilityIdentifier("chat.olderMessages.loading")
    } else if hasOlderMessages {
      // 보이지 않는 감지 줄. 여기까지 올라오면 다음 페이지를 받는다.
      Color.clear
        .frame(height: 1)
        .accessibilityHidden(true)
        .onAppear { Task { await loadOlderMessages() } }
    }
  }

  private var serverCourseBar: some View {
    courseBarLabel(showsEditButton: false)
      .accessibilityIdentifier("chat.routeSummary")
  }

  /// 서버 모임의 18-1 진입 상태. 서버가 코스 수정을 받아 주는 조건
  /// (`ChatRoomService.updateRoomCourse` — 모집 중 · CUSTOM 코스 · 호스트)을 화면이 아는 값으로 따라간다.
  /// `ServerTripMapper.routeEditState` 와 같은 기준이고, 18-1 자체도 서버 상세를 다시 읽어 잠금을 판단한다.
  private var serverRouteEditState: RouteEditState { displayThread.routeEditState }

  private func courseBarLabel(showsEditButton: Bool, showsChevron: Bool = false) -> some View {
    ChatCourseBarLabel(
      thread: displayThread,
      showsEditButton: showsEditButton,
      showsChevron: showsChevron
    )
  }

  /// 상단 바에 띄울 **고정 공지**. 예전에는 `pinnedNotices.first` 를 그대로 썼는데
  /// 그 배열에는 고정을 푼 공지까지 들어 있어(`allNotices`), 고정을 해제해도 바가 그대로였다.
  /// 판정은 이미 있던 `RoutePolicy.pinnedNotices(from:)` 에 맡긴다 (IOS-F111).
  private var barPinnedNotices: [TripNotice] {
    RoutePolicy.pinnedNotices(from: displayThread.pinnedNotices)
  }

  /// 고정 공지가 없으면 바를 감춘다.
  ///
  /// 예전에는 서버 스레드가 아닐 때 `07:50 청송 시외버스터미널 정문 앞 집합` 을 띄웠다 —
  /// 아무도 올린 적 없는 공지다 (NO-MOCK-CANON R1). 이 세션에서 만들어진 모집도
  /// `ContentView.createdChatThread` 로 실제 사용자에게 열리므로 캡처 전용 경로가 아니었다.
  private var pinnedNoticeTitle: String? {
    // 공지는 본문만 있다 (정본 ATTACH-COMPOSER-CANON.md §2) — 바에는 본문 첫 줄을 띄운다.
    guard let body = barPinnedNotices.first?.body,
      let firstLine = body.components(separatedBy: "\n").first, !firstLine.isEmpty
    else {
      return nil
    }
    return firstLine
  }

  /// 고정 공지 바 두 번째 줄 — **서버가 준 수만** 적는다.
  /// 예전에는 공지가 없으면 「공지 4개 · 고정 2」라는 지어낸 값이 나왔다 (IOS-F111, NO-MOCK-CANON R1).
  private var noticeSummaryText: String {
    let notices = displayThread.pinnedNotices
    guard !notices.isEmpty else { return "이력 보기" }
    return "공지 \(notices.count)개 · 고정 \(barPinnedNotices.count) · 이력 보기"
  }
}

/// 화면기획 20 — 여행 당일 로드맵 진행 바. 서버가 active로 줄 때만 그린다.
private struct ServerRoadmapBar: View {
  let roadmap: ServerCurrentRoadmap

  var body: some View {
    HStack(spacing: 9) {
      Image(systemName: "mappin.and.ellipse")
      VStack(alignment: .leading, spacing: 2) {
        Text(headline)
          .lineLimit(1)
        if let next = roadmap.nextPlace {
          Text("다음 \(next.title)")
            .font(.caption2)
            .foregroundStyle(MoyeoTheme.muted)
            .lineLimit(1)
        }
      }
      Spacer()
      // 누를 수 있는 띠라는 것이 보여야 한다 — 공지 바와 같은 화살표를 둔다.
      Image(systemName: "chevron.right")
    }
    .font(.caption.weight(.heavy))
    .foregroundStyle(MoyeoTheme.forest)
    .padding(.horizontal, 16)
    .frame(height: 52)
    .background(MoyeoTheme.leaf)
    .accessibilityIdentifier("chat.roadmap")
  }

  private var headline: String {
    let completed = roadmap.places.filter(\.isCompleted).count
    var parts: [String] = []
    if let dayNumber = roadmap.dayNumber {
      parts.append("\(dayNumber)/\(roadmap.totalDays)일차")
    }
    if !roadmap.places.isEmpty {
      parts.append("방문지 \(completed)/\(roadmap.places.count)")
    }
    if let current = roadmap.currentPlace {
      parts.append(current.title)
    }
    return parts.joined(separator: " · ")
  }
}

private struct ChatArchiveNotice: View {
  let thread: ChatThread

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: 8) {
        Image(systemName: "archivebox.fill")
          .font(.caption.weight(.heavy))
          .foregroundStyle(MoyeoTheme.forest)
        Text(thread.closureReason ?? "여행이 종료됐어요")
          .font(.caption.weight(.heavy))
          .foregroundStyle(MoyeoTheme.ink)
        Spacer()
        if let archiveStatus = thread.archiveStatus {
          Text(archiveStatus)
            .font(.caption2.weight(.heavy))
            .foregroundStyle(MoyeoTheme.forest)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(MoyeoTheme.leaf)
            .clipShape(Capsule())
        }
      }
      Text(thread.archiveNotice ?? "채팅은 14일 동안 읽기 전용으로 보관돼요.")
        .font(.caption.weight(.semibold))
        .foregroundStyle(MoyeoTheme.muted)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(13)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(MoyeoTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(MoyeoTheme.softLine, lineWidth: 1)
    }
  }
}

private struct ChatRoomStatusHeader: View {
  let thread: ChatThread

  var body: some View {
    VStack(spacing: 8) {
      // 화면기획 20 — "마감 D-3"만 강조색으로 구분한다
      statusLine
        .font(.caption.weight(.semibold))
        .foregroundStyle(MoyeoTheme.muted)
        .frame(maxWidth: .infinity)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          // 서버가 주지 않은 조건은 빈 문자열로 와 칩을 그리지 않는다
          conditionPill("wonsign.circle", thread.priceDisplayText)
          conditionPill("person.2", thread.ageRangeDisplayText)
          conditionPill("person.crop.circle", thread.genderDisplayText)
        }
      }
      .padding(.horizontal, 16)
    }
    .padding(.top, 2)
    .padding(.bottom, 9)
    .background(MoyeoTheme.background)
    .overlay(alignment: .bottom) {
      Rectangle().fill(MoyeoTheme.softLine).frame(height: 1)
    }
  }

  private var statusLine: Text {
    if thread.chatStatusDeadline.isEmpty {
      return Text(thread.chatStatusLinePrefix)
    }
    return Text(
      "\(thread.chatStatusLinePrefix) · \(Text(thread.chatStatusDeadline).foregroundStyle(MoyeoTheme.coral))"
    )
  }

  @ViewBuilder
  private func conditionPill(_ icon: String, _ title: String) -> some View {
    if !title.isEmpty {
      Label(title, systemImage: icon)
        .font(.caption2.weight(.heavy))
        .foregroundStyle(MoyeoTheme.text700)
        .padding(.horizontal, 9)
        .frame(height: 26)
        .background(MoyeoTheme.subtleBackground)
        .overlay(Capsule().stroke(MoyeoTheme.softLine))
        .clipShape(Capsule())
    }
  }
}

extension ChatThread {
  /// 코스 이름을 못 받았으면 비워 둔다 — 자리 채우기 문구를 쓰지 않는다
  var courseDisplayName: String {
    courseName
  }

  /// 서버가 값을 주지 않은 조건은 빈 문자열로 남긴다 — 서버 모임에서는 그 칩을 숨긴다
  var priceDisplayText: String {
    price.isEmpty ? (isServerBacked ? "" : "비용 협의") : price
  }

  var ageRangeDisplayText: String {
    ageRange.isEmpty ? (isServerBacked ? "" : "\(RoomConditionAgePolicy.rangeText)세") : ageRange
  }

  var genderDisplayText: String {
    genderRestriction.isEmpty ? (isServerBacked ? "" : "성별 무관") : genderRestriction
  }

  var chatStatusLine: String {
    chatStatusDeadline.isEmpty ? chatStatusLinePrefix : "\(chatStatusLinePrefix) · \(chatStatusDeadline)"
  }

  /// 마감 강조 없이 남는 앞부분 — "2/5명 · 5/25(토) 08:00–18:00 · 당일치기"
  var chatStatusLinePrefix: String {
    let scheduleText = scheduleSummary.isEmpty ? "일정 확인" : scheduleSummary
    if recruitmentDeadline.isEmpty {
      return "\(memberCountText) · \(scheduleText) · \(statusSummary)"
    }
    return "\(memberCountText) · \(scheduleText)"
  }

  /// 강조색으로 그리는 마감 표기 — "마감 D-3"
  var chatStatusDeadline: String {
    recruitmentDeadline.isEmpty ? "" : "마감 \(recruitmentDeadline)"
  }
}

extension ChatRoomBody {
  private func sendMessage() {
    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    // 서버 모임은 실제로 전송한 뒤 서버 메시지를 다시 읽는다 — 목데이터 말풍선을 끼워 넣지 않는다.
    if !isOffline, MoyeoServerSync.isEnabled, let roomID = thread.serverRoomID {
      draft = ""
      sendFailureMessage = nil
      Task {
        do {
          // 실시간이 붙어 있으면 STOMP 로 보낸다 (결정 ⑤ — `/app/chat-rooms/{roomId}/messages`).
          // 붙어 있지 않으면 예전 그대로 REST 다. 어느 쪽이든 서버는 같은 서비스를 타고,
          // 같은 `/topic` 으로 모두에게 즉시 퍼진다.
          //
          // 길이(1,000자)는 화면이 이미 막고 있어, STOMP 경로에서 `@Valid` 로 조용히
          // 버려질 일이 없다. 그 밖의 실패는 아래 `catch` 가 REST 와 똑같이 말한다.
          if realtime.isLive {
            try await realtime.send(content: trimmed)
          } else {
            _ = try await ChatRoomWriteAPIClient.shared.sendMessage(roomID: roomID, content: trimmed)
          }
        } catch {
          // 전송 실패는 입력을 되돌려 다시 보낼 수 있게 한다.
          // **그리고 실패했다고 말한다** — 예전에는 되돌리기만 하고 아무 안내가 없어,
          // 보낸 줄 알았는데 말풍선이 안 생기는 상태로 남았다 (TC CHAT-011).
          //
          // 다만 **보내는 동안 사용자가 새로 쓴 글은 덮지 않는다.** 느린 전송이 실패하면
          // 그 사이에 친 글이 옛 원문으로 통째로 바뀌어 사라졌다 (TC CHAT-012).
          // 비어 있을 때만 되돌리고, 아니면 원문을 안내 문구에 실어 잃지 않게 한다.
          if draft.isEmpty {
            draft = trimmed
            sendFailureMessage = error.moyeoUserMessage(
              fallback: "메시지를 보내지 못했어요. 잠시 후 다시 시도해주세요."
            )
          } else {
            let reason = error.moyeoUserMessage(
              fallback: "메시지를 보내지 못했어요. 잠시 후 다시 시도해주세요."
            )
            sendFailureMessage = "\(reason) 못 보낸 글: \(trimmed)"
          }
          return
        }
        sendFailureMessage = nil
        await loadServerContent()
      }
      return
    }

    // 내 말풍선이라 보낸 사람 표기를 쓰지 않는다 — 이름·아바타를 지어내지 않는다.
    let message = ChatMessage(
      id: UUID().uuidString,
      senderName: "",
      avatar: "",
      body: trimmed,
      time: "지금",
      isMine: true
    )
    messages.append(message)
    if isOffline {
      pendingMessageIDs.insert(message.id)
      OfflineChatQueue.enqueue(
        OfflinePendingChatMessage(
          id: message.id,
          threadID: thread.id,
          body: message.body,
          createdAt: Date()
        )
      )
    } else {
      onSendMessage(message)
    }
    draft = ""
  }

  /// 최근 페이지 응답을 지금까지 모은 목록에 **얹는다**.
  ///
  /// 통째로 갈아치우면 위로 올려 받은 과거 페이지가 폴링 한 번에 날아간다.
  /// 최근 페이지의 가장 오래된 id 를 경계로 삼아, 그보다 **오래된 것은 그대로 두고**
  /// 그 이후 구간만 새 응답으로 바꾼다 — 지워진 메시지는 사라지고, 새 메시지가 들어와
  /// 창이 밀려도 밀려난 메시지를 잃지 않는다.
  private func applyServerMessages(_ content: ServerChatRoomContent) {
    // 조회가 실패했으면(`didLoadMessages == false`) 가진 것을 그대로 둔다.
    if content.didLoadMessages {
      if let boundary = content.messages.map(\.messageId).min() {
        loadedMessages = loadedMessages.filter { $0.messageId < boundary }
          + content.messages.sorted { $0.messageId < $1.messageId }
      } else {
        // 서버가 **성공적으로** 빈 방이라고 답했다. 과거 페이지도 의미가 없다.
        loadedMessages = []
        reachedOldestMessage = true
      }
      // 맨 위까지 올라간 뒤에는 최근 페이지의 `hasNext`(늘 참)가 이것을 되돌리면 안 된다.
      hasOlderMessages = reachedOldestMessage ? false : content.hasOlderMessages
    }
    renderMessages(currentUserID: content.currentUserID)
  }

  /// 모아 둔 서버 메시지와 전송 대기 큐를 합쳐 말풍선 목록을 다시 만든다.
  private func renderMessages(currentUserID: Int64?) {
    let serverMessages = loadedMessages.map {
      ServerTripMapper.chatMessage(from: $0, currentUserID: currentUserID)
    }
    let existingIDs = Set(serverMessages.map(\.id))
    let pending = OfflineChatQueue.messages(for: thread.id)
    messages = serverMessages + pending.filter { !existingIDs.contains($0.id) }.map(\.message)
  }

  /// 목록 맨 위에서 **이전 페이지를 이어 붙인다** (TC CHAT-015).
  ///
  /// 커서는 지금 가진 가장 오래된 messageId 다 — 서버는 그보다 작은 것만 주므로
  /// 이미 가진 메시지와 겹치지 않는다(실서버 확인: 50건 페이지 두 장, 교집합 0).
  /// 그래도 한 번 더 id 로 걸러 둔다 — 실시간 수신과 겹쳐 들어와도 같은 말풍선이 두 번
  /// 그려지지 않게 한다.
  private func loadOlderMessages() async {
    guard MoyeoServerSync.isEnabled, let roomID = thread.serverRoomID else { return }
    guard hasOlderMessages, !isLoadingOlderMessages, !reachedOldestMessage else { return }
    guard let cursor = loadedMessages.first?.messageId else { return }
    isLoadingOlderMessages = true
    olderMessagesFailure = nil
    defer { isLoadingOlderMessages = false }

    let page: ServerChatMessagePage
    do {
      page = try await ChatRoomContentAPIClient.shared.messages(
        roomID: roomID, beforeMessageID: cursor)
    } catch {
      // 조용히 삼키면 위로 올려도 아무 일이 없는 것처럼 보인다 — 말하고 다시 시도하게 한다.
      olderMessagesFailure = error.moyeoUserMessage(
        fallback: "이전 대화를 불러오지 못했어요.")
      return
    }

    let knownIDs = Set(loadedMessages.map(\.messageId))
    let older = page.messages
      .filter { !knownIDs.contains($0.messageId) }
      .sorted { $0.messageId < $1.messageId }
    if !older.isEmpty {
      loadedMessages = older + loadedMessages
      renderMessages(currentUserID: serverContent?.currentUserID)
    }
    if !page.hasNext || older.isEmpty {
      reachedOldestMessage = true
      hasOlderMessages = false
    }
  }

  /// 구독으로 받은 메시지 한 장을 목록에 얹는다.
  ///
  /// **이미 가진 메시지는 건너뛴다** — 폴백 폴링이나 따라잡기 조회와 겹쳐 같은 말풍선이
  /// 두 번 그려지지 않게 한다. 서버 응답 묶음(`serverContent.messages`)에도 같이 넣어야
  /// 다음 조회가 오기 전까지 상태가 어긋나지 않는다.
  private func applyRealtimeMessage(_ message: ServerChatMessage) {
    guard var content = serverContent else { return }
    guard !content.messages.contains(where: { $0.messageId == message.messageId }) else { return }
    content.messages.append(message)
    // 조회가 실패한 채로 구독 메시지만 온 경우에도 이 한 장은 실제로 받은 것이다.
    content.didLoadMessages = true
    serverContent = content
    applyServerMessages(content)
  }

  /// 20 투표 참여·취소. 서버가 갱신된 카드를 주므로 그 메시지만 바꿔 끼운다 (IOS-F76).
  ///
  /// 예전에는 `try?` 로 실패를 삼켜 **선택지를 눌러도 아무 일이 없었다** — 눈금도 그대로라
  /// 탭이 안 먹은 것처럼 보인다 (TC SOCIAL-010 계열).
  func vote(card: ServerChatMessage, option: ServerChatPollOption) async {
    guard let roomID = thread.serverRoomID, votingMessageID == nil else { return }
    votingMessageID = card.messageId
    defer { votingMessageID = nil }
    let updated: ServerChatMessage
    do {
      if option.votedByMe {
        updated = try await ChatRoomWriteAPIClient.shared.cancelVote(
          roomID: roomID, messageID: card.messageId)
      } else {
        updated = try await ChatRoomWriteAPIClient.shared.vote(
          roomID: roomID, messageID: card.messageId, optionID: option.optionId)
      }
    } catch {
      voteFailureMessage = error.moyeoUserMessage(
        fallback: "투표를 반영하지 못했어요. 잠시 후 다시 시도해주세요.")
      return
    }
    voteFailureMessage = nil
    if let index = messages.firstIndex(where: { $0.server?.messageId == updated.messageId }) {
      messages[index].server = updated
    }
  }
}

struct MessageBubble: View {
  let message: ChatMessage
  var isPending = false
  /// 서버 메시지의 발신자 프로필 이미지 — 동행자 목록에서 붙인다
  var avatarURL: URL?
  /// 20 투표 참여·취소. 없으면 선택지는 눌러도 아무 일이 없다 (카드 모양은 같다).
  var isVoting = false
  var onVote: ((ServerChatMessage, ServerChatPollOption) -> Void)?
  /// 정산 카드의 신고 진입점이 쓴다. 견본 화면은 넘기지 않아 신고 버튼이 그려지지 않는다.
  var roomID: Int64?

  /// 장소 · 만날 위치 · 투표 · 정산 메모 · 사진은 말풍선이 아니라 카드다.
  /// 예전에는 이 다섯 종류가 전부 `body` 로 눌려 평범한 텍스트 말풍선으로 그려졌다 —
  /// 좌표도, 선택지도, 사진도 화면에 없었다.
  private var specialCard: ServerChatMessage? {
    guard let server = message.server, server.isSpecialCard else { return nil }
    return server
  }

  var body: some View {
    if let card = specialCard {
      specialCardBubble(card)
    } else if message.kind == .routeChanged {
      // 화면기획 20 — 경로 수정 카드: 제목 + 본문 + "바뀐 경로 보기 →" 링크
      VStack(alignment: .leading, spacing: 7) {
        HStack(spacing: 7) {
          Image(systemName: "arrow.triangle.2.circlepath")
            .font(.caption.weight(.heavy))
          Text("호스트가 경로를 수정했어요")
            .font(.caption.weight(.heavy))
        }
        .foregroundStyle(MoyeoTheme.brandText)
        Text(.init(message.body))
          .font(.caption)
          .foregroundStyle(MoyeoTheme.onLeaf)
          .fixedSize(horizontal: false, vertical: true)
        Text("바뀐 경로 보기 →")
          .font(.caption.weight(.heavy))
          .foregroundStyle(MoyeoTheme.brandText)
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(MoyeoTheme.leaf)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .accessibilityIdentifier("chat.routeChangedCard")
    } else if message.isSystemMessage {
      // 시스템 메시지는 웹 · 안드로이드처럼 **중앙정렬**이다 (내 메시지 · 상대 메시지 정렬은 그대로).
      // 21 견본과 같은 줄을 쓴다 — 두 화면이 다르게 생기면 그게 결함이다.
      ChatSystemMessageNote(content: message.body)
    } else {
      HStack(alignment: .bottom, spacing: 8) {
        if message.isMine {
          Spacer(minLength: 42)
        } else if let avatarURL {
          CachedRemoteImage(url: avatarURL) { image in
            image
              .resizable()
              .scaledToFill()
          } placeholder: {
            MoyeoTheme.leaf
          }
          .frame(width: 32, height: 32)
          .clipShape(Circle())
        } else {
          MascotAvatar(mascot: message.avatar, size: 32, background: MoyeoTheme.leaf)
        }

        VStack(alignment: message.isMine ? .trailing : .leading, spacing: 4) {
          if !message.isMine {
            Text(message.senderName)
              .font(.caption.bold())
              .foregroundStyle(MoyeoTheme.muted)
          }
          Text(message.body)
            .font(.subheadline)
            .foregroundStyle(MoyeoTheme.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            // 디자인 시스템의 chat-mine 토큰 — leaf(선택 틴트)와 구분한다
            .background(message.isMine ? MoyeoTheme.chatMine : MoyeoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            .overlay {
              RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                .stroke(
                  isPending
                    ? MoyeoTheme.warningText : (message.isMine ? .clear : MoyeoTheme.softLine),
                  style: StrokeStyle(lineWidth: 1, dash: isPending ? [5, 4] : [])
                )
            }
            .opacity(isPending ? 0.62 : 1)
          if isPending {
            Label("전송 대기", systemImage: "clock")
              .font(MoyeoTypography.font(size: 10, weight: .bold, relativeTo: .caption2))
              .foregroundStyle(MoyeoTheme.warningText)
          } else {
            Text(message.time)
              .font(.caption2)
              .foregroundStyle(MoyeoTheme.muted)
          }
        }

        if !message.isMine {
          Spacer(minLength: 42)
        }
      }
    }
  }

  /// 카드형 메시지 한 줄. 보낸 사람 · 시각은 말풍선과 같은 자리에 두고,
  /// 표면만 카드로 바꾼다 (21 견본과 같은 카드).
  @ViewBuilder
  private func specialCardBubble(_ card: ServerChatMessage) -> some View {
    HStack(alignment: .bottom, spacing: 8) {
      if message.isMine {
        Spacer(minLength: 20)
      } else if let avatarURL {
        CachedRemoteImage(url: avatarURL) { image in
          image
            .resizable()
            .scaledToFill()
        } placeholder: {
          MoyeoTheme.leaf
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
      } else {
        MascotAvatar(mascot: message.avatar, size: 32, background: MoyeoTheme.leaf)
      }

      VStack(alignment: message.isMine ? .trailing : .leading, spacing: 4) {
        if !message.isMine {
          Text(message.senderName)
            .font(.caption.bold())
            .foregroundStyle(MoyeoTheme.muted)
        }
        ChatSpecialMessageCard(
          message: card,
          isVoting: isVoting,
          onVote: onVote.map { handler in { option in handler(card, option) } },
          roomID: roomID,
          isMine: message.isMine
        )
        .chatSpecialCardSurface()
        Text(message.time)
          .font(.caption2)
          .foregroundStyle(MoyeoTheme.muted)
      }

      if !message.isMine {
        Spacer(minLength: 20)
      }
    }
  }
}

struct ChatComposer: View {
  @Binding var draft: String
  let isOffline: Bool
  let send: () -> Void
  let attachment: () -> Void

  private var canSend: Bool {
    !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: 8) {
        Button(action: attachment) {
          Image(systemName: "plus")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(isOffline ? MoyeoTheme.text400 : MoyeoTheme.text700)
            .frame(width: 38, height: 38)
            .background(MoyeoTheme.subtleBackground)
            .clipShape(Circle())
            .overlay(Circle().stroke(MoyeoTheme.softLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isOffline)
        .accessibilityLabel(isOffline ? "첨부는 연결 후 가능" : "첨부")
        .accessibilityIdentifier("chat.attachment")

        // 서버 한도(1000자)를 화면이 먼저 지킨다. 예전에는 한도도 카운터도 없어
        // 1001자째에 서버가 400 으로 막을 때까지 아무 표시가 없었다 (IOS-F17).
        TextField(
          "메시지 입력",
          text: Binding(
            get: { draft },
            set: { draft = String($0.prefix(ServerChatShareLimits.maximumMessageLength)) }
          ),
          axis: .vertical
        )
          .lineLimit(1...4)
          .padding(.horizontal, 13)
          .padding(.vertical, 10)
          .background(MoyeoTheme.background)
          .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))

        Button(action: send) {
          Image(systemName: "paperplane.fill")
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(canSend ? MoyeoTheme.coral : MoyeoTheme.text400)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        // ENV-006: 라벨이 없으면 VoiceOver 가 영어 시스템 문구(「Send」)로 읽는다.
        .accessibilityLabel("메시지 보내기")
        .accessibilityIdentifier("chat.message.send")
      }
      // 한도 가까이 왔을 때만 센다 — 평소에 숫자가 떠 있으면 입력칸이 시끄럽다.
      if draft.count >= ServerChatShareLimits.maximumMessageLength - 100 {
        Text("\(draft.count) / \(ServerChatShareLimits.maximumMessageLength)자")
          .font(MoyeoTypography.font(size: 10.5, relativeTo: .caption2))
          .foregroundStyle(
            draft.count >= ServerChatShareLimits.maximumMessageLength
              ? MoyeoTheme.dangerRed : MoyeoTheme.text400
          )
          .frame(maxWidth: .infinity, alignment: .trailing)
          .accessibilityIdentifier("chat.message.counter")
      }
      if isOffline {
        Text("사진·장소 공유는 연결된 뒤에 보낼 수 있어요")
          .font(MoyeoTypography.font(size: 10.5, relativeTo: .caption2))
          .foregroundStyle(MoyeoTheme.text400)
          .padding(.leading, 4)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(MoyeoTheme.card)
    .overlay(alignment: .top) {
      Rectangle()
        .fill(MoyeoTheme.line)
        .frame(height: 1)
    }
  }
}

/// 21 특수 메시지 카드 6종 — **카드 렌더링 견본**이다.
///
/// ⚠️ 예전 이 화면은 손으로 그린 목데이터 카드 6장이었다("동궁과 월지" · "경북 경주시 원화로 102" ·
/// "우직한 곰 7821님이 결제했어요" · "11/8 14:00 만남"). 화면은 꽉 차 보였고 빈 상태 감사도
/// 통과했지만, 저 값은 서버에 존재하지 않는다 (`docs/alignment/NO-MOCK-CANON.md` R1).
///
/// 6종 전부 API 가 있다. 읽기는 `GET /chat-rooms/{roomId}/messages` 하나로 끝나고
/// 응답의 `type` 으로 종류를 가른다. 종류별로 **가장 최근 한 건**을 견본으로 뽑고,
/// 채팅방(20)과 **같은 카드**(`ChatSpecialMessageCard`)로 그린다 — 두 화면이 다르게
/// 생기면 그게 결함이다. 그 방에 없는 종류는 자리 자체가 없다.
struct SpecialMessageCardsView: View {
  /// 견본을 뽑아 올 방. 없으면 그릴 실제 메시지가 없다.
  let roomID: Int64?

  @State private var messages: [ServerChatMessage] = []
  @State private var status = LoadStatus.loading
  @State var votingMessageID: Int64?
  /// 투표가 실패한 까닭. 있으면 목록 위에 한 줄로 보여준다 (TC SOCIAL-010 계열).
  @State private var voteFailureMessage: String?
  /// 실제로 읽어 온 방. `roomID` 가 비어 들어왔을 때 여기서 찾은 값을 담는다.
  @State private var resolvedRoomID: Int64?

  private enum LoadStatus {
    case loading
    case ready
    case failed
  }

  /// 서버가 지운 메시지의 본문. 지워진 카드는 「공유된 항목」에 남기지 않는다.
  private static let deletedMessageContent = "삭제된 메시지입니다"

  /// 종류별 가장 최근 한 건 — **어떤 종류가 있는지**를 세는 데만 쓴다(아래 「아직 없는 카드」).
  private var samples: [(kind: ChatSpecialMessageKind, message: ServerChatMessage)] {
    ChatSpecialMessageKind.allCases.compactMap { kind in
      guard let last = liveMessages.last(where: { $0.type == kind.rawValue }) else { return nil }
      return (kind, last)
    }
  }

  /// 지워지지 않은 메시지만.
  private var liveMessages: [ServerChatMessage] {
    messages.filter { $0.content != Self.deletedMessageContent }
  }

  /// 이 방에 공유된 **모든** 항목. 종류별로 묶고 그 안에서는 최신이 위다.
  ///
  /// 예전에는 종류마다 `messages.last` **한 건만** 그려서, 사진을 열 장 올려도
  /// 「공유된 항목」에는 한 장만 보였다 — 화면 이름이 약속하는 것과 달랐다 (IOS-F19).
  private var sharedItems: [(kind: ChatSpecialMessageKind, message: ServerChatMessage)] {
    ChatSpecialMessageKind.allCases.flatMap { kind in
      liveMessages
        .filter { $0.type == kind.rawValue }
        .reversed()
        .map { (kind: kind, message: $0) }
    }
  }

  private var missingLabels: [String] {
    let drawn = Set(samples.map(\.kind))
    return ChatSpecialMessageKind.allCases.filter { !drawn.contains($0) }.map(\.label)
  }

  var body: some View {
    VStack(spacing: 0) {
      SpecialMessageHeader()
      content
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
    .accessibilityIdentifier("screen.specialMessages")
    .task(id: roomID) { await load() }
  }

  @ViewBuilder
  private var content: some View {
    switch status {
    case .loading:
      MoyeoEmptyStateView(message: MoyeoEmptyText.loading)
        .frame(maxHeight: .infinity)
    case .failed:
      MoyeoEmptyStateView(message: MoyeoEmptyText.loadFailed, onRetry: { Task { await load() } })
        .frame(maxHeight: .infinity)
    case .ready:
      if sharedItems.isEmpty {
        // 방은 찾았지만 아직 카드로 그릴 메시지가 없다 — 예시로 채우지 않는다.
        MoyeoEmptyStateView(message: MoyeoEmptyText.noChatMessages)
          .frame(maxHeight: .infinity)
      } else {
        sampleList
      }
    }
  }

  /// 캡처 하네스가 쓰는 식별자를 유지한다 — 종류별 첫 카드만 `card.<kind>` 를 갖는다.
  private func cardIdentifier(
    index: Int,
    item: (kind: ChatSpecialMessageKind, message: ServerChatMessage)
  ) -> String {
    if index == 1 { return "specialMessages.middle" }
    let isFirstOfKind = sharedItems.firstIndex { $0.kind == item.kind } == index
    return isFirstOfKind
      ? "specialMessages.card.\(item.kind.rawValue)"
      : "specialMessages.item.\(item.message.messageId)"
  }

  private var sampleList: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(spacing: 10) {
          if let voteFailureMessage {
            MoyeoInlineErrorText(
              message: voteFailureMessage, identifier: "specialMessages.vote.error")
          }
          ForEach(Array(sharedItems.enumerated()), id: \.element.message.messageId) { index, item in
            sampleRow(item.kind, item.message)
              // 캡처 식별자는 그대로 둔다 — 종류별 **첫 장**이 그 종류의 대표 카드다.
              // `--p2` 스크롤 캡처의 기준점도 예전처럼 두 번째 카드다.
              .id(cardIdentifier(index: index, item: item))
          }
          if !missingLabels.isEmpty {
            // 없는 종류를 예시로 채우지 않는다. 대신 **왜 비었는지**를 적는다 —
            // 카드가 빠진 것과 그 방에 그 메시지가 없는 것은 다르다.
            Text("이 모임에 아직 없는 카드: \(missingLabels.joined(separator: " · "))")
              .font(.caption2)
              .foregroundStyle(MoyeoTheme.muted)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.top, 2)
          }
          if let state = QAScrollState.requested {
            Color.clear
              .frame(height: state.qaSpacerHeight)
              .id("specialMessages.bottom")
          }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 28)
      }
      .onAppear {
        guard let state = QAScrollState.requested else { return }
        let target = state.targetID(
          middle: "specialMessages.middle", bottom: "specialMessages.bottom")
        Task {
          try? await Task.sleep(nanoseconds: 500_000_000)
          proxy.scrollTo(target, anchor: state.anchor)
        }
      }
    }
  }

  @ViewBuilder
  private func sampleRow(
    _ kind: ChatSpecialMessageKind, _ message: ServerChatMessage
  ) -> some View {
    if kind == .system {
      ChatSystemMessageNote(content: message.content)
    } else {
      VStack(alignment: .leading, spacing: 5) {
        Text(senderLine(message))
          .font(.caption2)
          .foregroundStyle(MoyeoTheme.muted)
        ChatSpecialMessageCard(
          message: message,
          isVoting: votingMessageID == message.messageId,
          onVote: { option in Task { await vote(message: message, option: option) } }
        )
        .chatSpecialCardSurface()
      }
    }
  }

  private func senderLine(_ message: ServerChatMessage) -> String {
    let time = ServerDateTime.bubbleTimeText(from: message.createdAt)
    return time.isEmpty ? message.senderNickname : "\(message.senderNickname) · \(time)"
  }

  private func load() async {
    guard MoyeoServerSync.isEnabled else {
      status = .failed
      return
    }
    status = .loading
    // 넘겨받은 방이 없을 수 있다 — 모임 탭에 들어가자마자 이 줄을 누르면 목록이 아직
    // 안 와서 `roomID` 가 nil 로 굳고, 그 뒤로는 「다시 시도」를 눌러도 살아나지 않았다
    // (nil 을 곧바로 실패로 단정했다). 없으면 **여기서 직접 내 방을 찾아본다.**
    let targetRoomID: Int64?
    if let roomID {
      targetRoomID = roomID
    } else {
      targetRoomID = (try? await ChatRoomAPIClient.shared.myRooms())?.first?.roomId
    }
    guard let targetRoomID else {
      status = .failed
      return
    }
    resolvedRoomID = targetRoomID
    guard let page = try? await ChatRoomContentAPIClient.shared.messages(roomID: targetRoomID) else {
      status = .failed
      return
    }
    messages = page.messages
    status = .ready
  }

  /// 투표는 견본에서도 실제로 참여된다 — 채팅방(20)과 같은 엔드포인트다.
  /// 응답이 갱신된 카드를 그대로 주므로 그 메시지만 바꿔 끼운다.
  /// 21 견본 카드의 투표. 채팅방(`ChatRoomBody.vote`)과 같은 규칙이다 —
  /// 실패를 삼키지 않고 말한다 (TC SOCIAL-010 계열).
  private func vote(message: ServerChatMessage, option: ServerChatPollOption) async {
    guard let roomID = resolvedRoomID ?? roomID, votingMessageID == nil else { return }
    votingMessageID = message.messageId
    defer { votingMessageID = nil }
    let updated: ServerChatMessage
    do {
      if option.votedByMe {
        updated = try await ChatRoomWriteAPIClient.shared.cancelVote(
          roomID: roomID, messageID: message.messageId)
      } else {
        updated = try await ChatRoomWriteAPIClient.shared.vote(
          roomID: roomID, messageID: message.messageId, optionID: option.optionId)
      }
    } catch {
      voteFailureMessage = error.moyeoUserMessage(
        fallback: "투표를 반영하지 못했어요. 잠시 후 다시 시도해주세요.")
      return
    }
    voteFailureMessage = nil
    if let index = messages.firstIndex(where: { $0.messageId == updated.messageId }) {
      messages[index] = updated
    }
  }
}

private struct SpecialMessageHeader: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    HStack {
      Button {
        dismiss()
      } label: {
          // ENV-009 — 화살표 그림 크기는 그대로 두고 누를 넓이만 44x44 로 넓힌다
        Image(systemName: "chevron.left")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(MoyeoTheme.ink)
          .frame(width: 44, height: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      // ENV-006: 라벨이 없으면 VoiceOver 가 영어 시스템 문구(「Back」)로 읽는다.
      .accessibilityLabel("뒤로")

      Spacer()
      Text("채팅방 · 특수 메시지 6종")
        .font(.caption.weight(.heavy))
        .foregroundStyle(MoyeoTheme.ink)
      Spacer()
      // ENV-009 — 뒤로 버튼과 같은 44 로 맞춰 제목 가운데 정렬을 유지한다
      Color.clear.frame(width: 44, height: 44)
    }
    .frame(height: 44)
    .padding(.horizontal, 10)
    .background(MoyeoTheme.background)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(MoyeoTheme.softLine)
        .frame(height: 1)
    }
  }
}

extension ChatThread {
  fileprivate var memberCountText: String {
    statusSummary.components(separatedBy: " · ").first ?? "\(members.count)명"
  }

  fileprivate var mood: CourseMood {
    switch region {
    case "경주":
      return .coral
    case "안동":
      return .sunrise
    case "울릉":
      return .river
    default:
      return .forest
    }
  }
}

extension ChatMessage {
  fileprivate var isSystemMessage: Bool {
    isSystemNotice
  }
}
