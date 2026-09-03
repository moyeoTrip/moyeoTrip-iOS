//
//  NoticeEditView.swift
//  MoyeoTrip
//
//  20-3a 공지 수정 · 삭제. 정본 `ATTACH-COMPOSER-CANON.md` §6-1.
//
//  20-3 공지 이력의 카드마다 `수정` 링크가 있는데 **갈 곳이 없었다.**
//  `Text` 로 그려져 있어 버튼 감사에도 안 잡혔다.
//
//  근거: `PUT /api/v1/chat-rooms/{roomId}/notices/{noticeId}` · `DELETE` 같은 경로
//
//  **제목 칸을 두지 않는다** — 공지는 본문만이다 (정본 §2, 기획 결정 2026-08-30).
//  **상단 고정은 최대 1개다** — 서버가 개수를 막지 않으므로 클라가 지킨다 (R5-1).
//

import SwiftUI

/// 방 id 만 알고 들어오는 진입(캡처 라우트 `notice-edit`)을 위해 공지를 먼저 받아온다.
/// 20-3 에서 `수정` 을 눌러 들어올 때는 이미 공지 원본이 있으므로 이 화면을 거치지 않는다.
struct NoticeEditLoaderView: View {
    let roomID: Int64

    @State private var notice: ServerChatRoomNotice?
    @State private var loadState: TripCompanionsState = .loading

    var body: some View {
        Group {
            switch loadState {
            case .loading:
                MoyeoEmptyStateView(
                    message: MoyeoEmptyText.loading,
                    accessibilityIdentifier: "noticeEdit.state"
                )
            case .failed:
                MoyeoEmptyStateView(
                    message: MoyeoEmptyText.loadFailed,
                    onRetry: { Task { await load() } },
                    accessibilityIdentifier: "noticeEdit.state"
                )
            case .empty:
                MoyeoEmptyStateView(
                    message: MoyeoEmptyText.noNotices,
                    accessibilityIdentifier: "noticeEdit.state"
                )
            case .ready:
                if let notice {
                    NoticeEditView(roomID: roomID, notice: notice)
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        loadState = .loading
        guard MoyeoServerSync.isEnabled else {
            loadState = .empty
            return
        }
        guard let history = try? await ChatRoomContentAPIClient.shared.notices(roomID: roomID) else {
            loadState = .failed
            return
        }
        notice = history.allNotices.first
        loadState = notice == nil ? .empty : .ready
    }
}

struct NoticeEditView: View {
    let roomID: Int64
    let notice: ServerChatRoomNotice
    /// 수정·삭제가 끝나면 20-3 이 이력을 다시 읽는다.
    var onChanged: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var noticeText: String
    @State private var isPinned: Bool
    /// 지금 고정돼 있는 다른 공지들 — 이 공지를 고정하면 그것들을 푼다 (R5-1).
    @State private var otherPinnedNotices: [ServerChatRoomNotice] = []
    /// 삭제는 되돌릴 수 없다 — 확인 시트를 거친 뒤에만 서버를 부른다.
    @State private var showsDeleteConfirmation = false
    @StateObject private var sendState = AttachComposerSendState()

    /// 서버 `UpdateChatRoomNoticeRequest` 와 같은 한도.
    private static let noticeLimit = 1000

    init(roomID: Int64, notice: ServerChatRoomNotice, onChanged: @escaping () -> Void = {}) {
        self.roomID = roomID
        self.notice = notice
        self.onChanged = onChanged
        _noticeText = State(initialValue: notice.content ?? "")
        _isPinned = State(initialValue: notice.pinned)
    }

    private var trimmedNotice: String {
        noticeText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 고정 토글 설명 — 세 플랫폼이 글자 그대로 같은 문구를 쓴다 (정본 R5-1 표).
    private var pinDescription: String {
        otherPinnedNotices.isEmpty
            ? "채팅방 맨 위에 계속 보여요."
            : "지금 고정된 공지가 있어요. 이걸 고정하면 그 공지는 풀려요."
    }

    var body: some View {
        AttachComposerFrame(
            title: "공지 수정",
            cta: "수정 저장",
            isCTAEnabled: !trimmedNotice.isEmpty && !sendState.isSending,
            identifier: "noticeEdit",
            onSend: save
        ) {
            AttachFieldLabel(text: "공지 내용", isRequired: true)
            editor

            AttachToggleRow(
                label: "상단에 고정하기",
                desc: pinDescription,
                isOn: $isPinned,
                identifier: "noticeEdit.pinned"
            )
            .padding(.top, 10)
            .overlay(alignment: .top) { Rectangle().fill(MoyeoTheme.softLine).frame(height: 1) }

            if !authorLine.isEmpty {
                Text(authorLine)
                    .font(MoyeoTypography.tinyMeta)
                    .monospacedDigit()
                    .foregroundStyle(MoyeoTheme.text400)
                    .padding(.top, 10)
            }

            // 삭제는 되돌릴 수 없다 — 저장 CTA 와 멀리 떼어 놓는다 (기획 주석).
            Button {
                showsDeleteConfirmation = true
            } label: {
                Text("이 공지 삭제하기")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.dangerRed)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
            }
            .buttonStyle(.plain)
            .padding(.top, 24)
            .accessibilityIdentifier("noticeEdit.delete")

            Text("삭제하면 공지 이력에서도 사라져요. 되돌릴 수 없어요.")
                .font(MoyeoTypography.tinyMeta)
                .foregroundStyle(MoyeoTheme.text400)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        }
        .overlay {
            if showsDeleteConfirmation {
                MoyeoConfirmSheet(
                    title: "이 공지를 삭제할까요?",
                    subject: trimmedNotice,
                    lines: [
                        "삭제하면 공지 이력에서도 사라져요. 되돌릴 수 없어요.",
                        "이미 받은 알림은 지워지지 않아요."
                    ],
                    cancelTitle: "그대로 둘게요",
                    confirmTitle: "공지 삭제",
                    isDanger: true,
                    isBusy: sendState.isSending,
                    identifier: "noticeDelete",
                    onCancel: { showsDeleteConfirmation = false },
                    onConfirm: { showsDeleteConfirmation = false; delete() }
                )
            }
        }
        .task {
            guard MoyeoServerSync.isEnabled else { return }
            let history = try? await ChatRoomContentAPIClient.shared.notices(roomID: roomID)
            otherPinnedNotices = (history?.pinnedNotices ?? []).filter { $0.noticeId != notice.noticeId }
        }
        .attachComposerFailureAlert(sendState)
    }

    private var editor: some View {
        VStack(alignment: .trailing, spacing: 0) {
            TextEditor(text: $noticeText)
                .font(.subheadline)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 132)
                .onChange(of: noticeText) { _, value in
                    if value.count > Self.noticeLimit {
                        noticeText = String(value.prefix(Self.noticeLimit))
                    }
                }
                .accessibilityLabel("공지 내용")
                .accessibilityIdentifier("noticeEdit.body")
            Text("\(noticeText.count)/\(Self.noticeLimit)")
                .font(MoyeoTypography.tinyMeta)
                .monospacedDigit()
                .foregroundStyle(MoyeoTheme.text400)
        }
        .padding(12)
        .background(MoyeoTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// 작성자·작성일. 서버가 준 값만 적는다 — 모르면 줄째로 뺀다.
    private var authorLine: String {
        let date = notice.createdAt.split(separator: "T").first.map {
            $0.replacingOccurrences(of: "-", with: ".")
        } ?? ""
        return [notice.authorNickname, date.isEmpty ? "" : "\(date) 작성"]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func save() {
        let content = trimmedNotice
        let pinned = isPinned
        let previouslyPinned = otherPinnedNotices
        sendState.send(fallbackMessage: "공지를 수정하지 못했어요.") {
            // 고정은 하나만 남긴다 — 서버가 막지 않으므로 클라가 먼저 기존 고정을 푼다 (R5-1)
            if pinned {
                for old in previouslyPinned {
                    try? await ChatRoomWriteAPIClient.shared.setNoticePinned(
                        roomID: roomID, noticeID: old.noticeId, pinned: false
                    )
                }
            }
            try await ChatRoomWriteAPIClient.shared.updateNotice(
                roomID: roomID, noticeID: notice.noticeId, notice: content, pinned: pinned
            )
        } onSuccess: {
            onChanged()
            dismiss()
        }
    }

    private func delete() {
        sendState.send(fallbackMessage: "공지를 삭제하지 못했어요.") {
            try await ChatRoomWriteAPIClient.shared.deleteNotice(
                roomID: roomID, noticeID: notice.noticeId
            )
        } onSuccess: {
            onChanged()
            dismiss()
        }
    }
}
