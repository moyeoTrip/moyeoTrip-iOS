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
    /// 이 화면을 열 때 서버에 있던 내용. 저장 직전에 다시 읽어 이 값과 견준다 —
    /// 그 사이 누가 먼저 고쳤으면 **말없이 덮어쓰지 않는다** (TC NOTICE-021).
    @State private var baselineContent: String
    /// 이 화면이 읽은 공지의 `updatedAt` (BE-30). 저장할 때 `expectedUpdatedAt` 으로 같이 보내면
    /// 그 사이 남이 고친 경우 서버가 409 `40923` 으로 막는다 — 재조회 가드가 못 잡는 **마지막
    /// 한 순간**(재조회와 PUT 사이)까지 닫힌다. 서버 배포 전에는 nil 이라 보내지 않는다.
    @State private var baselineUpdatedAt: String?
    @StateObject private var sendState = AttachComposerSendState()

    /// 서버 `UpdateChatRoomNoticeRequest` 와 같은 한도.
    private static let noticeLimit = 1000

    init(roomID: Int64, notice: ServerChatRoomNotice, onChanged: @escaping () -> Void = {}) {
        self.roomID = roomID
        self.notice = notice
        self.onChanged = onChanged
        _noticeText = State(initialValue: notice.content ?? "")
        _isPinned = State(initialValue: notice.pinned)
        _baselineContent = State(initialValue: notice.content ?? "")
        _baselineUpdatedAt = State(initialValue: notice.updatedAt)
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
            AttachFieldLabel(text: "공지 내용", isRequired: true, isFirst: true)
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
            // ① 저장 직전에 다시 읽어 내용이 바뀌었는지 견준다. 이것만으로는 **경합 창이 좁아질 뿐**이다 —
            //    재조회와 PUT 사이에 남이 고치면 여전히 덮어쓴다 (TC NOTICE-021).
            try await checkNotEditedByOthers()
            // 고정은 하나만 남긴다 — 서버가 막지 않으므로 클라가 먼저 기존 고정을 푼다 (R5-1)
            if pinned {
                for old in previouslyPinned {
                    try? await ChatRoomWriteAPIClient.shared.setNoticePinned(
                        roomID: roomID, noticeID: old.noticeId, pinned: false
                    )
                }
            }
            // ② 창을 닫는 것은 서버다 — 내가 읽은 `updatedAt` 을 실어 보내고, 그 사이 남이 고쳤으면
            //    서버가 409 `40923` 으로 거절한다 (BE-30). 서버 배포 전에는 nil 이라 예전과 같다.
            do {
                try await ChatRoomWriteAPIClient.shared.updateNotice(
                    roomID: roomID, noticeID: notice.noticeId, notice: content, pinned: pinned,
                    expectedUpdatedAt: baselineUpdatedAt
                )
            } catch let error as MoyeoAPIError
                where error.serverCode == MoyeoServerErrorCode.noticeUpdateConflict {
                // 서버 `errorMessage` 를 그대로 쓰지 않는다 — 문구는 클라가 소유한다(결정 ⑩).
                // 재조회 가드가 쓰던 것과 **같은 문장**을 쓴다: 사용자에게는 같은 상황이다.
                await adoptLatestAfterServerConflict()
                throw NoticeConflictError.edited
            }
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

// MARK: - 저장 직전 충돌 확인

private extension NoticeEditView {
    /// 저장 직전에 서버 공지를 다시 읽어, 그 사이 남이 고쳤거나 지웠으면 **저장을 멈춘다**.
    /// 다시 읽기 자체가 실패하면(통신 불가) 막지 않는다 — 읽지 못한 것을 충돌로 단정하지 않는다.
    func checkNotEditedByOthers() async throws {
        guard MoyeoServerSync.isEnabled else { return }
        guard let history = try? await ChatRoomContentAPIClient.shared.notices(roomID: roomID) else { return }
        guard let latest = history.allNotices.first(where: { $0.noticeId == notice.noticeId }) else {
            throw NoticeConflictError.removed
        }
        guard (latest.content ?? "") != baselineContent else { return }
        // 최신 내용을 화면에 올려 두고 멈춘다 — 무엇이 달라졌는지 보고 다시 저장하게 한다.
        adopt(latest)
        throw NoticeConflictError.edited
    }

    /// 서버가 409 `40923` 으로 거절했을 때 — 최신 공지를 읽어 입력칸에 올린다.
    /// **덮어쓰기를 다시 시도하지 않는다.** 다시 읽지 못하면 입력을 건드리지 않고 안내만 한다
    /// (읽지 못한 것을 근거로 사용자가 쓴 글을 지우지 않는다).
    func adoptLatestAfterServerConflict() async {
        guard MoyeoServerSync.isEnabled,
              let history = try? await ChatRoomContentAPIClient.shared.notices(roomID: roomID),
              let latest = history.allNotices.first(where: { $0.noticeId == notice.noticeId })
        else { return }
        adopt(latest)
    }

    /// 서버 최신값을 화면과 기준값에 함께 올린다 — 다음 저장은 이 버전 위에서 시작한다.
    func adopt(_ latest: ServerChatRoomNotice) {
        noticeText = latest.content ?? ""
        baselineContent = latest.content ?? ""
        baselineUpdatedAt = latest.updatedAt
        isPinned = latest.pinned
    }
}

/// 저장하려는 순간 공지가 이미 바뀌어 있던 경우. 오류가 아니라 **다시 보라는 안내**다.
private enum NoticeConflictError: LocalizedError {
    case edited
    case removed

    var errorDescription: String? {
        switch self {
        case .edited:
            return "다른 사람이 먼저 이 공지를 고쳤어요. 최신 내용을 불러왔으니 확인하고 다시 저장해주세요."
        case .removed:
            return "이 공지는 이미 삭제됐어요."
        }
    }
}
