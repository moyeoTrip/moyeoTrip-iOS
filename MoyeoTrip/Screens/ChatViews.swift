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
                height: 54,
                cornerRadius: 8
            )
            .frame(width: 54)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    HStack(spacing: 7) {
                        Text(thread.tripTitle)
                            .font(MoyeoTypography.cardTitle)
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
                        .font(MoyeoTypography.cardMeta)
                        .foregroundStyle(MoyeoTheme.text400)
                        .monospacedDigit()
                }

                Text(thread.statusSummary)
                    .font(MoyeoTypography.cardBody)
                    .foregroundStyle(MoyeoTheme.muted)
                    .monospacedDigit()
                    .lineLimit(1)

                HStack(alignment: .top, spacing: 10) {
                    Text(thread.lastMessage)
                        .font(MoyeoTypography.cardBody)
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
        .padding(.vertical, 9)
        .frame(minHeight: 76)
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
    @State private var messages: [ChatMessage]
    @State private var draft = ""
    @State private var toolbarMessage: String?

    init(thread: ChatThread, onSendMessage: @escaping (ChatMessage) -> Void = { _ in }) {
        self.thread = thread
        self.onSendMessage = onSendMessage
        _messages = State(initialValue: thread.messages)
    }

    var body: some View {
        VStack(spacing: 0) {
            ChatRoomStatusHeader(thread: thread)

            ScrollView {
                VStack(spacing: 14) {
                    if !thread.isReadOnly {
                        ChatApplicationNotice()
                    } else {
                        ChatArchiveNotice(thread: thread)
                    }

                    ForEach(messages) { message in
                        MessageBubble(message: message)
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
                ChatComposer(draft: $draft, send: sendMessage)
            }
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .navigationTitle(thread.tripTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    toolbarMessage = "호스트 연락 방식과 통화 가능 시간을 확인할 수 있어요."
                } label: {
                    Image(systemName: "phone.fill")
                }
                .accessibilityLabel("전화")

                Button {
                    toolbarMessage = "신고, 알림 끄기, 멤버 보기 메뉴를 확인할 수 있어요."
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("더보기")
            }
        }
        .alert("채팅방 도구", isPresented: Binding<Bool>(
            get: { toolbarMessage != nil },
            set: { if !$0 { toolbarMessage = nil } }
        )) {
            Button("확인", role: .cancel) {
                toolbarMessage = nil
            }
        } message: {
            Text(toolbarMessage ?? "")
        }
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
        onSendMessage(message)
        draft = ""
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
        Text(thread.memberCountText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(MoyeoTheme.muted)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
            .padding(.bottom, 10)
            .background(MoyeoTheme.background)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(MoyeoTheme.softLine)
                    .frame(height: 1)
            }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        if message.isSystemMessage {
            Text(message.body)
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.forest)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(MoyeoTheme.leaf)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .center)
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
                        .background(message.isMine ? MoyeoTheme.leaf : MoyeoTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                                .stroke(message.isMine ? .clear : MoyeoTheme.softLine, lineWidth: 1)
                        }
                    Text(message.time)
                        .font(.caption2)
                        .foregroundStyle(MoyeoTheme.muted)
                }

                if !message.isMine {
                    Spacer(minLength: 42)
                }
            }
        }
    }
}

private struct ChatApplicationNotice: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(MoyeoTheme.forest)
            Text("모임 신청 후 대화가 이어져요")
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.forest)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(MoyeoTheme.leaf)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct ChatComposer: View {
    @Binding var draft: String
    let send: () -> Void

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
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
                    let target = state.targetID(middle: "specialMessages.middle", bottom: "specialMessages.bottom")
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
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("11/8 14:00 만남", systemImage: "calendar")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(MoyeoTheme.coral)
            MapMessagePreview()
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
    var body: some View {
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

private extension View {
    func specialCard(fill: Color = MoyeoTheme.card) -> some View {
        padding(12)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                    .stroke(MoyeoTheme.softLine, lineWidth: 1)
            }
    }
}

private extension ChatThread {
    var memberCountText: String {
        statusSummary.components(separatedBy: " · ").first ?? "\(members.count)명"
    }

    var mood: CourseMood {
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

private extension ChatMessage {
    var isSystemMessage: Bool {
        isSystemNotice
    }
}
