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
      MoyeoPhotoTile(
        mascot: thread.mascot,
        mood: thread.mood,
        height: 56,
        cornerRadius: 16
      )
      .frame(width: 56)

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

  init(thread: ChatThread, onSendMessage: @escaping (ChatMessage) -> Void = { _ in }) {
    self.thread = thread
    self.onSendMessage = onSendMessage
  }

  var body: some View {
    ChatRoomBody(
      thread: thread,
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
      SupportDestinationView(route: route)
    }
  }
}

/// changeLog14 — 채팅방 본문. 오버레이(20-2 첨부 메뉴 · 32 신고 시트)의 배경이
/// 실루엣이 아니라 실제 채팅방과 같은 코드를 쓰도록 화면 껍데기와 분리했다.
struct ChatRoomBody: View {
  @Environment(\.moyeoIsOffline) private var isOffline
  let thread: ChatThread
  var onSendMessage: (ChatMessage) -> Void = { _ in }
  var onOpenRoute: (SupportRoute) -> Void = { _ in }
  @State private var messages: [ChatMessage]
  @State private var draft = ""
  @State private var pendingMessageIDs: Set<String>

  init(
    thread: ChatThread,
    onSendMessage: @escaping (ChatMessage) -> Void = { _ in },
    onOpenRoute: @escaping (SupportRoute) -> Void = { _ in }
  ) {
    self.thread = thread
    self.onSendMessage = onSendMessage
    self.onOpenRoute = onOpenRoute
    let pending = OfflineChatQueue.messages(for: thread.id)
    let existingIDs = Set(thread.messages.map(\.id))
    _messages = State(
      initialValue: thread.messages + pending.filter { !existingIDs.contains($0.id) }.map(\.message)
    )
    _pendingMessageIDs = State(initialValue: Set(pending.map(\.id)))
  }

  var body: some View {
    VStack(spacing: 0) {
      ChatRoomStatusHeader(thread: thread)

      if isOffline {
        OfflineChatBanner()
      }

      // 화면기획 20 고정 공지 바 — 공지 제목 + "공지 4개 · 고정 2 · 이력 보기"
      Button {
        onOpenRoute(.noticeHistory(thread.id))
      } label: {
        HStack(spacing: 9) {
          Image(systemName: "pin.fill")
          VStack(alignment: .leading, spacing: 2) {
            Text(thread.pinnedNotices.first?.title ?? "07:50 청송 시외버스터미널 정문 앞 집합")
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

      // 화면기획 20 코스 바 — 코스 이름 + "방문지 4곳 · 호스트 직접 코스" + 경로 수정 버튼
      Button {
        let tripID =
          thread.tripID ?? MockData.trips.first { $0.title == thread.tripTitle }?.id
          ?? MockData.trips[0].id
        let state: RouteEditState =
          thread.statusSummary.contains("확정")
          ? .tripConfirmed : (thread.courseSource == .custom ? .editable : .linkedLocked)
        onOpenRoute(.courseEdit(tripID, state))
      } label: {
        HStack(spacing: 9) {
          Image(systemName: "map.fill")
          VStack(alignment: .leading, spacing: 2) {
            Text(thread.courseDisplayName)
            Text("방문지 \(thread.routeSummary.count)곳 · \(thread.courseSource.title)")
              .font(.caption2).foregroundStyle(MoyeoTheme.muted).lineLimit(1)
          }
          Spacer()
          Text("경로 수정")
            .font(.caption2.weight(.heavy))
            .foregroundStyle(MoyeoTheme.brandText)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .overlay(Capsule().stroke(MoyeoTheme.forest.opacity(0.6)))
        }
        .font(.caption.weight(.heavy))
        .foregroundStyle(MoyeoTheme.ink)
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(MoyeoTheme.card)
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("chat.routeSummary")

      ScrollView {
        VStack(spacing: 14) {
          if thread.isReadOnly {
            ChatArchiveNotice(thread: thread)
          }

          ForEach(messages) { message in
            MessageBubble(message: message, isPending: pendingMessageIDs.contains(message.id))
          }
        }
        .padding(20)
      }

      if thread.isReadOnly {
        VStack(spacing: 4) {
          Text(thread.archiveStatus ?? "읽기 전용 보관")
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
  }

  /// 고정 공지 바 두 번째 줄 — 공지·고정 수는 스레드에 공지가 있으면 그 수를,
  /// 없으면 화면기획 20의 기준 값(공지 4 · 고정 2)을 쓴다.
  private var noticeSummaryText: String {
    let total = thread.pinnedNotices.count
    guard total > 0 else { return "공지 4개 · 고정 2 · 이력 보기" }
    let pinned = thread.pinnedNotices.filter(\.isPinned).count
    return "공지 \(total)개 · 고정 \(pinned) · 이력 보기"
  }

  private func sendMessage() {
    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    let message = ChatMessage(
      id: UUID().uuidString,
      senderName: MockData.profile.name,
      avatar: MockData.profile.avatar,
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

  private func conditionPill(_ icon: String, _ title: String) -> some View {
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

extension ChatThread {
  var courseDisplayName: String {
    if !courseName.isEmpty { return courseName }
    if let tripID, let trip = MockData.trip(for: tripID), let course = MockData.course(for: trip.courseID) {
      return course.title
    }
    return "코스 정보"
  }

  var priceDisplayText: String { price.isEmpty ? "비용 협의" : price }
  var ageRangeDisplayText: String { ageRange.isEmpty ? "20~100세" : ageRange }
  var genderDisplayText: String { genderRestriction.isEmpty ? "성별 무관" : genderRestriction }

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

  var body: some View {
    if message.kind == .routeChanged {
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
      Text(message.body)
        .font(.caption.weight(.heavy))
        .foregroundStyle(MoyeoTheme.forest)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(MoyeoTheme.leaf)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      HStack(alignment: .bottom, spacing: 8) {
        if message.isMine {
          Spacer(minLength: 42)
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

struct SpecialMessageCardsView: View {
  var body: some View {
    VStack(spacing: 0) {
      SpecialMessageHeader()

      ScrollViewReader { proxy in
        ScrollView {
          VStack(spacing: 10) {
            SpecialPlaceCard()
            SpecialMeetupCard()
              .id("specialMessages.middle")
            SpecialPaymentCard()
            SpecialNoticeCard()
            SpecialSimpleCard(
              title: "여행이 확정됐어요!",
              subtitle: "좋은 여행 되세요",
              tint: MoyeoTheme.leaf
            )
            SpecialSimpleCard(
              title: "아쉬운 모임이에요. 다음에 또 봐요!",
              subtitle: "14일 후 자동으로 사라져요",
              tint: adaptiveColor(light: "#FFF6D8", dark: "#3A321E")
            )
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
    .background(MoyeoTheme.background.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
    .accessibilityIdentifier("screen.specialMessages")
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

private struct SpecialPlaceCard: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("장소", systemImage: "mappin.circle")
        .font(.caption2.weight(.heavy))
        .foregroundStyle(MoyeoTheme.forest)
      Text("동궁과 월지")
        .font(.caption.weight(.heavy))
        .foregroundStyle(MoyeoTheme.ink)
      Text("경북 경주시 원화로 102")
        .font(.caption2)
        .foregroundStyle(MoyeoTheme.muted)
      MoyeoPhotoTile(mascot: "🌙", mood: .forest, height: 64, cornerRadius: 8)
      HStack {
        Text("09:00-22:00")
        Spacer()
        Text("지도 보기 →")
      }
      .font(.caption2.weight(.semibold))
      .foregroundStyle(MoyeoTheme.muted)
    }
    .specialCard()
  }
}

private struct SpecialMeetupCard: View {
  /// 화면기획 21 "만날 위치 공유" — 경주 모집의 첫 방문지 좌표를 그대로 쓴다.
  private var coordinate: MoyeoMapCoordinate? {
    let stop = MockData.trips.first { $0.id == "trip-gyeongju-night" }?.itinerary.first
    return MoyeoMapCoordinate(latitude: stop?.latitude, longitude: stop?.longitude)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("11/8 14:00 만남", systemImage: "calendar")
        .font(.caption2.weight(.heavy))
        .foregroundStyle(MoyeoTheme.coral)
      MapMessagePreview(coordinate: coordinate)
        .frame(height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      Text("경주역 2번 출구")
        .font(.caption.weight(.heavy))
        .foregroundStyle(MoyeoTheme.ink)
      Text("길 찾기 →")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(MoyeoTheme.muted)
    }
    .specialCard()
  }
}

private struct SpecialPaymentCard: View {
  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "creditcard")
        .font(.caption.bold())
        .foregroundStyle(MoyeoTheme.muted)
      VStack(alignment: .leading, spacing: 5) {
        Text("우직한 곰 7821님이 결제했어요")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(MoyeoTheme.muted)
        Text("한옥스테이 1박")
          .font(.caption.weight(.heavy))
          .foregroundStyle(MoyeoTheme.ink)
        Text("120,000원 · 4명")
          .font(.caption2)
          .foregroundStyle(MoyeoTheme.muted)
      }
      Spacer()
      Text("1인 30,000원")
        .font(.caption.weight(.heavy))
        .foregroundStyle(MoyeoTheme.forest)
    }
    .specialCard()
  }
}

private struct SpecialNoticeCard: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("공지 · 호스트", systemImage: "note.text")
        .font(.caption2.weight(.heavy))
        .foregroundStyle(MoyeoTheme.forest)
      Text("집합: 경주역 2번 출구\n시간: 11/8 (토) 14:00\n함께 출발하면 좋아요 🙌")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(MoyeoTheme.text700)
        .lineSpacing(3)
    }
    .specialCard(fill: adaptiveColor(light: "#F4FBF6", dark: "#1D2E24"))
  }
}

private struct SpecialSimpleCard: View {
  let title: String
  let subtitle: String
  let tint: Color

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "sparkles")
        .font(.caption.bold())
        .foregroundStyle(MoyeoTheme.forest)
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.caption.weight(.heavy))
          .foregroundStyle(MoyeoTheme.ink)
        Text(subtitle)
          .font(.caption2)
          .foregroundStyle(MoyeoTheme.muted)
      }
      Spacer()
    }
    .specialCard(fill: tint)
  }
}

private struct MapMessagePreview: View {
  var coordinate: MoyeoMapCoordinate?

  var body: some View {
    if let coordinate {
      MoyeoMapView(
        content: MoyeoMapContent(
          center: coordinate,
          level: 16,
          markers: [MoyeoMapMarker(id: "special-meetup", coordinate: coordinate)],
          fitsContent: false
        ),
        isInteractive: false,
        fallback: { mockup }
      )
    } else {
      mockup
    }
  }

  private var mockup: some View {
    GeometryReader { proxy in
      let size = proxy.size

      ZStack {
        adaptiveColor(light: "#EAF3E6", dark: "#1B2D23")
        Path { path in
          path.move(to: CGPoint(x: 0, y: size.height * 0.66))
          path.addCurve(
            to: CGPoint(x: size.width, y: size.height * 0.22),
            control1: CGPoint(x: size.width * 0.28, y: size.height * 0.52),
            control2: CGPoint(x: size.width * 0.62, y: size.height * 0.42)
          )
        }
        .stroke(MoyeoTheme.forest, style: StrokeStyle(lineWidth: 4, lineCap: .round))

        ForEach([CGFloat(0.18), CGFloat(0.58), CGFloat(0.82)], id: \.self) { x in
          Circle()
            .fill(MoyeoTheme.forest)
            .frame(width: 16, height: 16)
            .overlay {
              Circle().stroke(MoyeoTheme.elevatedCard.opacity(0.8), lineWidth: 2)
            }
            .position(x: size.width * x, y: size.height * (0.70 - x * 0.42))
        }
      }
    }
  }
}

extension View {
  fileprivate func specialCard(fill: Color = MoyeoTheme.card) -> some View {
    padding(12)
      .background(fill)
      .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
          .stroke(MoyeoTheme.softLine, lineWidth: 1)
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
