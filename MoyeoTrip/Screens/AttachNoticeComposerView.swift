//
//  AttachNoticeComposerView.swift
//  MoyeoTrip
//
//  20-2f 공지 작성 (호스트). 정본 `ATTACH-COMPOSER-CANON.md` §2 · R5-1.
//
//  **제목 칸이 없다.** 기획 결정(2026-08-30)으로 공지는 본문만 둔다 —
//  서버 모델도 `notice` 문자열 하나뿐이라 제목을 두면 클라가 지어내야 했다.
//
//  **상단 고정은 최대 1개다.** 서버는 개수를 제한하지 않으므로(실서버 방 101 에 2건이 고정돼 있다)
//  클라가 지킨다 — 새로 고정할 때 기존 고정 공지를 `PUT .../notices/{id}` 로 `pinned:false` 로 푼다.
//

import SwiftUI

struct AttachNoticeComposerView: View {
    let roomID: Int64
    let onSent: () -> Void

    @StateObject private var sendState = AttachComposerSendState()
    @State private var noticeText = ""
    @State private var isPinned = true
    /// 지금 고정돼 있는 공지들 — 새로 고정하면 이것들을 푼다 (R5-1).
    @State private var pinnedNotices: [ServerChatRoomNotice] = []

    /// 서버 `CreateChatRoomNoticeRequest` 와 같은 한도.
    private static let noticeLimit = 1000

    private var trimmedNotice: String {
        noticeText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 고정 토글 설명 — 세 플랫폼이 글자 그대로 같은 문구를 쓴다 (정본 R5-1 표).
    private var pinDescription: String {
        pinnedNotices.isEmpty
            ? "채팅방 맨 위에 계속 보여요."
            : "지금 고정된 공지가 있어요. 이걸 고정하면 그 공지는 풀려요."
    }

    var body: some View {
        AttachComposerFrame(
            title: "공지 작성",
            hint: "공지는 호스트만 올릴 수 있어요.",
            cta: "공지 올리기",
            isCTAEnabled: !trimmedNotice.isEmpty && !sendState.isSending,
            identifier: "attachNotice",
            onSend: send
        ) {
            AttachFieldLabel(text: "공지 내용", isRequired: true)
            noticeEditor

            AttachToggleRow(
                label: "상단에 고정하기",
                desc: pinDescription,
                isOn: $isPinned,
                identifier: "attachNotice.pinned"
            )
            .padding(.top, 10)
            .overlay(alignment: .top) { Rectangle().fill(MoyeoTheme.softLine).frame(height: 1) }

            if isPinned && !trimmedNotice.isEmpty {
                AttachFieldLabel(text: "채팅방 맨 위에 이렇게 보여요").padding(.top, 6)
                pinnedPreview
            }

            AttachNoteBox(lines: [
                "상단 고정은 하나만 할 수 있어요. 가장 중요한 공지 하나만 올려두세요.",
                "고정을 해제해도 공지 이력에는 그대로 남아요.",
                "공지를 올리면 방 사람들에게 알림이 가요."
            ])
        }
        .task {
            guard MoyeoServerSync.isEnabled else { return }
            let history = try? await ChatRoomContentAPIClient.shared.notices(roomID: roomID)
            pinnedNotices = history?.pinnedNotices ?? []
        }
        .attachComposerFailureAlert(sendState)
    }

    private var noticeEditor: some View {
        VStack(alignment: .trailing, spacing: 0) {
            TextEditor(text: $noticeText)
                .font(.subheadline)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 132)
                // TextEditor 에는 placeholder 가 없다 — 웹 · 안드로이드와 **같은 문구**를 얹는다.
                .overlay(alignment: .topLeading) {
                    if noticeText.isEmpty {
                        Text("멤버에게 알릴 내용을 적어주세요")
                            .font(.subheadline)
                            .foregroundStyle(MoyeoTheme.muted)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .onChange(of: noticeText) { _, value in
                    if value.count > Self.noticeLimit {
                        noticeText = String(value.prefix(Self.noticeLimit))
                    }
                }
                .accessibilityLabel("공지 내용")
                .accessibilityIdentifier("attachNotice.body")
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

    /// R2 — 채팅방 맨 위에 얹히는 고정 공지 배너와 같은 생김새.
    private var pinnedPreview: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "note.text")
                .font(.caption)
                .foregroundStyle(MoyeoTheme.forest)
            Text(trimmedNotice)
                .font(.caption)
                .foregroundStyle(MoyeoTheme.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Text("📌").font(.caption2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoyeoTheme.leaf)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.primary100))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier("attachNotice.preview")
    }

    private func send() {
        let notice = trimmedNotice
        let pinned = isPinned
        let previouslyPinned = pinnedNotices
        sendState.send(fallbackMessage: "공지를 올리지 못했어요.") {
            // 고정은 하나만 남긴다 — 서버가 막지 않으므로 클라가 먼저 기존 고정을 푼다 (R5-1)
            if pinned {
                for old in previouslyPinned {
                    try? await ChatRoomWriteAPIClient.shared.setNoticePinned(
                        roomID: roomID, noticeID: old.noticeId, pinned: false
                    )
                }
            }
            _ = try await ChatRoomWriteAPIClient.shared.createNotice(
                roomID: roomID, notice: notice, pinned: pinned
            )
        } onSuccess: { onSent() }
    }
}
