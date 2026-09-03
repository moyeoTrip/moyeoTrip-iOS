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

  init(thread: ChatThread, onSendMessage: @escaping (ChatMessage) -> Void = { _ in }) {
    self.thread = thread
    self.onSendMessage = onSendMessage
  }

  var body: some View {
    ChatRoomBody(
      thread: thread,
      reloadToken: reloadToken,
      onSendMessage: onSendMessage,
      onOpenRoute: { supportRoute = $0 }
    )
    .background(MoyeoTheme.background.ignoresSafeArea())
    .navigationTitle(thread.tripTitle)
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
  @State private var messages: [ChatMessage]
  @State private var draft = ""
  @State private var pendingMessageIDs: Set<String>
  /// 참여 중인 서버 방의 읽기 응답 — 403이거나 미로그인이면 nil로 남고 목데이터가 유지된다
  @State private var serverContent: ServerChatRoomContent?

  init(
    thread: ChatThread,
    reloadToken: Int = 0,
    onSendMessage: @escaping (ChatMessage) -> Void = { _ in },
    onOpenRoute: @escaping (SupportRoute) -> Void = { _ in }
  ) {
    self.thread = thread
    self.reloadToken = reloadToken
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

      if isOffline {
        OfflineChatBanner()
      }

      if let roadmap = serverContent?.roadmap, roadmap.active {
        // 여행 당일에만 서버가 로드맵을 활성으로 준다
        ServerRoadmapBar(roadmap: roadmap)
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
      // 서버 모임의 경로 수정(PUT)은 연동 대상이 아니라 서버 모임에서는 정보만 보여준다
      if thread.isServerBacked {
        if !displayThread.courseDisplayName.isEmpty {
          serverCourseBar
        }
      } else if let tripID = thread.tripID {
        Button {
          let state: RouteEditState =
            thread.statusSummary.contains("확정")
            ? .tripConfirmed : (thread.courseSource == .custom ? .editable : .linkedLocked)
          onOpenRoute(.courseEdit(tripID, state))
        } label: {
          courseBarLabel(showsEditButton: true)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chat.routeSummary")
      }

      ScrollView {
        VStack(spacing: 14) {
          if displayThread.isReadOnly {
            ChatArchiveNotice(thread: displayThread)
          }

          ForEach(messages) { message in
            MessageBubble(
              message: message,
              isPending: pendingMessageIDs.contains(message.id),
              avatarURL: avatarURLsByNickname[message.senderName]
            )
          }
        }
        .padding(20)
      }

      if displayThread.isReadOnly {
        VStack(spacing: 4) {
          Text(displayThread.archiveStatus ?? "읽기 전용 보관")
            .font(.caption.weight(.heavy))
            .foregroundStyle(MoyeoTheme.forest)
          Text("종료된 모임이라 새 메시지를 보낼 수 없어요.")
            .font(.caption.weight(.semibold))
            .foregroundStyle(MoyeoTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(MoyeoTheme.card)
      } else {
        ChatComposer(
          draft: $draft,
          isOffline: isOffline,
          send: sendMessage,
          attachment: {
            onOpenRoute(.chatAttach(thread.id))
          }
        )
      }
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
    .onChange(of: reloadToken) { _, _ in
      Task { await loadServerContent() }
    }
  }

  /// 참여 중인 서버 방의 읽기 응답을 받아 화면에 얹는다. 실패하면 기존 값을 그대로 둔다.
  private func loadServerContent() async {
    guard MoyeoServerSync.isEnabled, let roomID = thread.serverRoomID else { return }
    guard let content = await ChatRoomContentAPIClient.shared.content(roomID: roomID) else { return }
    serverContent = content
    applyServerMessages(content)
  }

  private var serverCourseBar: some View {
    courseBarLabel(showsEditButton: false)
      .accessibilityIdentifier("chat.routeSummary")
  }

  private func courseBarLabel(showsEditButton: Bool) -> some View {
    HStack(spacing: 9) {
      Image(systemName: "map.fill")
      VStack(alignment: .leading, spacing: 2) {
        Text(displayThread.courseDisplayName)
        Text("방문지 \(displayThread.routeSummary.count)곳 · \(displayThread.courseSource.title)")
          .font(.caption2).foregroundStyle(MoyeoTheme.muted).lineLimit(1)
      }
      Spacer()
      if showsEditButton {
        Text("경로 수정")
          .font(.caption2.weight(.heavy))
          .foregroundStyle(MoyeoTheme.brandText)
          .padding(.horizontal, 10)
          .frame(height: 28)
          .overlay(Capsule().stroke(MoyeoTheme.forest.opacity(0.6)))
      }
    }
    .font(.caption.weight(.heavy))
    .foregroundStyle(MoyeoTheme.ink)
    .padding(.horizontal, 16)
    .frame(height: 52)
    .background(MoyeoTheme.card)
  }

  /// 서버 모임은 공지가 없으면 바를 감춘다. 목데이터 스레드는 기존 기준 문구를 유지한다.
  private var pinnedNoticeTitle: String? {
    // 공지는 본문만 있다 (정본 ATTACH-COMPOSER-CANON.md §2) — 바에는 본문 첫 줄을 띄운다.
    if let body = displayThread.pinnedNotices.first?.body,
      let firstLine = body.components(separatedBy: "\n").first, !firstLine.isEmpty {
      return firstLine
    }
    return thread.isServerBacked ? nil : "07:50 청송 시외버스터미널 정문 앞 집합"
  }

  /// 고정 공지 바 두 번째 줄 — 공지·고정 수는 스레드에 공지가 있으면 그 수를,
  /// 없으면 화면기획 20의 기준 값(공지 4 · 고정 2)을 쓴다.
  private var noticeSummaryText: String {
    let notices = displayThread.pinnedNotices
    guard !notices.isEmpty else { return "공지 4개 · 고정 2 · 이력 보기" }
    let pinned = notices.filter(\.isPinned).count
    return "공지 \(notices.count)개 · 고정 \(pinned) · 이력 보기"
  }

  private func applyServerMessages(_ content: ServerChatRoomContent) {
    let serverMessages = content.messages.map {
      ServerTripMapper.chatMessage(from: $0, currentUserID: content.currentUserID)
    }
    let existingIDs = Set(serverMessages.map(\.id))
    let pending = OfflineChatQueue.messages(for: thread.id)
    messages = serverMessages + pending.filter { !existingIDs.contains($0.id) }.map(\.message)
  }

  private func sendMessage() {
    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    // 서버 모임은 실제로 전송한 뒤 서버 메시지를 다시 읽는다 — 목데이터 말풍선을 끼워 넣지 않는다.
    if !isOffline, MoyeoServerSync.isEnabled, let roomID = thread.serverRoomID {
      draft = ""
      Task {
        guard
          (try? await ChatRoomWriteAPIClient.shared.sendMessage(roomID: roomID, content: trimmed)) != nil
        else {
          // 전송 실패는 입력을 되돌려 다시 보낼 수 있게 한다
          draft = trimmed
          return
        }
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

  private func flushPendingMessages() {
    let pending = OfflineChatQueue.messages(for: thread.id)
    guard !pending.isEmpty else { return }
    for item in pending {
      onSendMessage(item.message)
    }
    let sentIDs = Set(pending.map(\.id))
    pendingMessageIDs.subtract(sentIDs)
    OfflineChatQueue.remove(ids: sentIDs)
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

private struct OfflineChatBanner: View {
  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Circle()
        .fill(MoyeoTheme.warningText)
        .frame(width: 6, height: 6)
        .padding(.top, 5)
      Text("연결이 끊겼어요. **보낸 메시지는 연결되면 자동으로 전송**돼요.")
        .font(MoyeoTypography.font(size: 11.5, relativeTo: .caption))
        .foregroundStyle(MoyeoTheme.warningText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 9)
    .background(MoyeoTheme.warningBackground)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("offline.chat.banner")
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
    ageRange.isEmpty ? (isServerBacked ? "" : "20~100세") : ageRange
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

struct MessageBubble: View {
  let message: ChatMessage
  var isPending = false
  /// 서버 메시지의 발신자 프로필 이미지 — 동행자 목록에서 붙인다
  var avatarURL: URL?
  /// 20 투표 참여·취소. 없으면 선택지는 눌러도 아무 일이 없다 (카드 모양은 같다).
  var isVoting = false
  var onVote: ((ServerChatMessage, ServerChatPollOption) -> Void)?

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
          onVote: onVote.map { handler in { option in handler(card, option) } }
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

private struct ChatComposer: View {
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

        TextField("메시지 입력", text: $draft, axis: .vertical)
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
        .accessibilityIdentifier("chat.message.send")
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
  @State private var votingMessageID: Int64?

  private enum LoadStatus {
    case loading
    case ready
    case failed
  }

  /// 종류별 가장 최근 한 건. 없는 종류는 nil 이고 카드를 그리지 않는다.
  private var samples: [(kind: ChatSpecialMessageKind, message: ServerChatMessage)] {
    ChatSpecialMessageKind.allCases.compactMap { kind in
      guard let last = messages.last(where: { $0.type == kind.rawValue }) else { return nil }
      return (kind, last)
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
      if samples.isEmpty {
        // 방은 찾았지만 아직 카드로 그릴 메시지가 없다 — 예시로 채우지 않는다.
        MoyeoEmptyStateView(message: MoyeoEmptyText.noChatMessages)
          .frame(maxHeight: .infinity)
      } else {
        sampleList
      }
    }
  }

  private var sampleList: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(spacing: 10) {
          ForEach(Array(samples.enumerated()), id: \.element.kind) { index, sample in
            sampleRow(sample.kind, sample.message)
              // `--p2` 스크롤 캡처의 기준점 — 두 번째 카드가 화면 가운데다.
              .id(index == 1 ? "specialMessages.middle" : "specialMessages.card.\(sample.kind.rawValue)")
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
    guard let roomID, MoyeoServerSync.isEnabled else {
      status = .failed
      return
    }
    status = .loading
    guard let page = try? await ChatRoomContentAPIClient.shared.messages(roomID: roomID) else {
      status = .failed
      return
    }
    messages = page.messages
    status = .ready
  }

  /// 투표는 견본에서도 실제로 참여된다 — 채팅방(20)과 같은 엔드포인트다.
  /// 응답이 갱신된 카드를 그대로 주므로 그 메시지만 바꿔 끼운다.
  private func vote(message: ServerChatMessage, option: ServerChatPollOption) async {
    guard let roomID, votingMessageID == nil else { return }
    votingMessageID = message.messageId
    let updated: ServerChatMessage?
    if option.votedByMe {
      updated = try? await ChatRoomWriteAPIClient.shared.cancelVote(
        roomID: roomID, messageID: message.messageId)
    } else {
      updated = try? await ChatRoomWriteAPIClient.shared.vote(
        roomID: roomID, messageID: message.messageId, optionID: option.optionId)
    }
    if let updated, let index = messages.firstIndex(where: { $0.messageId == updated.messageId }) {
      messages[index] = updated
    }
    votingMessageID = nil
  }
}

private struct SpecialMessageHeader: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    HStack {
      Button {
        dismiss()
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(MoyeoTheme.ink)
          .frame(width: 34, height: 34)
      }
      .buttonStyle(.plain)

      Spacer()
      Text("채팅방 · 특수 메시지 6종")
        .font(.caption.weight(.heavy))
        .foregroundStyle(MoyeoTheme.ink)
      Spacer()
      Color.clear.frame(width: 34, height: 34)
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
