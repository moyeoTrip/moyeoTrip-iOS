//
//  FeedEditViews.swift
//  MoyeoTrip
//
//  23-2 내 피드 액션 시트 · 23-3 피드 삭제 확인 · 24-6 피드 수정.
//
//  기획 정본: `모여트립 in 경북/screens-edit-delete.jsx`
//  서버 계약: `docs/api/BACKEND_REQUEST_CHANGES_2026-09-04.md` §2 (2026-09-04 BE 회신)
//  2026-09-07 실서버로 존재·권한을 확인했다.
//
//  근거: `PUT /api/v1/feeds/{feedId}` `{ content }` · `DELETE /api/v1/feeds/{feedId}` → 204
//
//  **본문만 고친다.** 사진은 이 API 로 교체하지 않고 기존 첨부가 유지되며, 공개 범위도 못 바꾼다
//  (댓글 쓴 사람이 갑자기 피드를 못 보게 되는 것을 막으려는 정책이다).
//  그래서 사진·공개범위 편집 UI 를 두지 않는다 — 두면 **죽은 버튼**이 된다.
//

import SwiftUI

/// 피드 id 만 알고 들어오는 진입(캡처 라우트)을 위해 피드를 먼저 받아온다.
///
/// **남의 피드면 빈 상태로 끝낸다.** 서버도 403 으로 막지만, 화면에 수정·삭제를 띄워 놓고
/// 눌렀을 때 실패하게 두는 것은 죽은 버튼과 같다.
struct FeedEditLoaderView: View {
    let feedID: Int64
    /// 어느 화면으로 들어왔는지 — 액션 시트 · 삭제 확인 · 수정 중 하나.
    let mode: Mode

    enum Mode { case actions, delete, edit }

    @State private var feed: ServerFeed?
    @State private var loadState: TripCompanionsState = .loading

    var body: some View {
        Group {
            switch loadState {
            case .loading:
                MoyeoEmptyStateView(
                    message: MoyeoEmptyText.loading,
                    accessibilityIdentifier: "feedEdit.state"
                )
            case .failed:
                MoyeoEmptyStateView(
                    message: MoyeoEmptyText.loadFailed,
                    onRetry: { Task { await load() } },
                    accessibilityIdentifier: "feedEdit.state"
                )
            case .empty:
                MoyeoEmptyStateView(
                    message: "내가 쓴 기록만 수정하거나 지울 수 있어요.",
                    accessibilityIdentifier: "feedEdit.state"
                )
            case .ready:
                if let feed {
                    switch mode {
                    case .actions: FeedActionsSheetView(feed: feed)
                    case .delete: FeedDeleteView(feed: feed)
                    case .edit: FeedEditView(feed: feed)
                    }
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
        guard let detail = try? await FeedAPIClient.shared.feed(id: feedID),
              let me = try? await UserProfileAPIClient.shared.myProfile() else {
            loadState = .failed
            return
        }
        // 내 피드가 아니면 수정·삭제를 낼 수 없다.
        guard let myUserID = me.userId, detail.author.userId == myUserID else {
            loadState = .empty
            return
        }
        feed = detail
        loadState = .ready
    }
}

// MARK: - 23-2 내 피드 액션 시트

/// 남의 피드에서는 이 자리에 32 신고 시트가 열린다(정본 `REPORT-CANON.md`).
/// 내 피드에는 신고가 없다 — 자기 글은 신고할 수 없다(서버가 400 `40039` 로 막는다).
struct FeedActionsSheetView: View {
    let feed: ServerFeed

    @Environment(\.dismiss) private var dismiss
    @State private var route: FeedEditLoaderView.Mode?

    private var photoCount: Int { feed.images.count }

    var body: some View {
        ZStack(alignment: .bottom) {
            MoyeoTheme.overlayScrim
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(alignment: .leading, spacing: 0) {
                Capsule()
                    .fill(MoyeoTheme.line)
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 16)

                Text("내가 쓴 여행 기록")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(MoyeoTheme.ink)

                Text("“\(feed.content)” · 사진 \(photoCount)장")
                    .font(MoyeoTypography.tinyMeta)
                    .foregroundStyle(MoyeoTheme.text400)
                    .lineLimit(1)
                    .padding(.top, 5)

                VStack(spacing: 0) {
                    actionRow(Action(
                        icon: "square.and.pencil",
                        label: "수정하기",
                        desc: "글을 다시 쓸 수 있어요. 사진은 바꿀 수 없어요.",
                        identifier: "feedActions.edit"
                    )) { route = .edit }

                    // 삭제는 한 단계 더 물어본다 — 시트에서 바로 지우면 되돌릴 방법이 없다.
                    actionRow(Action(
                        icon: "trash",
                        label: "삭제하기",
                        desc: "되돌릴 수 없어요. 한 번 더 확인해요.",
                        isDanger: true,
                        identifier: "feedActions.delete"
                    )) { route = .delete }
                }
                .padding(.top, 14)

                // 취소 버튼 모양은 `MoyeoConfirmSheet` 과 같게 맞춘다 —
                // 시트끼리 버튼이 달라 보이면 같은 종류의 화면으로 읽히지 않는다.
                Button { dismiss() } label: {
                    Text("닫기")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MoyeoTheme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
                .accessibilityIdentifier("feedActions.close")
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 32)
            .moyeoBottomSheetSurface()
            .accessibilityIdentifier("feedActions.sheet")
        }
        .background(FeedOverlayBackdrop(feed: feed))
        // 시트처럼 보이지만 실제로는 밀어 올린 화면이다 — 모달 의미를 직접 붙인다 (TC ENV-007).
        .accessibilityAddTraits(.isModal)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(item: $route) { mode in
            FeedEditLoaderView(feedID: feed.feedId, mode: mode)
        }
    }

    /// 시트 안의 한 줄. 인자가 늘어 구조체로 묶었다(SwiftLint 인자 5개 제한).
    struct Action {
        let icon: String
        let label: String
        let desc: String
        var isDanger = false
        let identifier: String
    }

    @ViewBuilder
    private func actionRow(_ item: Action, action: @escaping () -> Void) -> some View {
        let icon = item.icon
        let label = item.label
        let desc = item.desc
        let isDanger = item.isDanger
        let identifier = item.identifier
        Button(action: action) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(isDanger ? MoyeoTheme.dangerRed : MoyeoTheme.text700)
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(isDanger ? MoyeoTheme.dangerRed : MoyeoTheme.ink)
                    Text(desc)
                        .font(MoyeoTypography.tinyMeta)
                        .foregroundStyle(MoyeoTheme.text400)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { Rectangle().fill(MoyeoTheme.softLine).frame(height: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - 23-3 피드 삭제 확인

struct FeedDeleteView: View {
    let feed: ServerFeed

    @Environment(\.dismiss) private var dismiss
    @StateObject private var sendState = AttachComposerSendState()

    private var photoCount: Int { feed.images.count }

    var body: some View {
        MoyeoConfirmSheet(
            title: "이 여행 기록을 삭제할까요?",
            subject: "“\(feed.content)” · 사진 \(photoCount)장",
            // 서버가 함께 정리하는 것을 그대로 적는다 (BE 회신 §2).
            lines: [
                "사진 \(photoCount)장과 글이 함께 사라져요.",
                "달린 댓글 \(feed.commentCount)개와 좋아요도 같이 없어져요.",
                "되돌릴 수 없어요.",
                "내가 쓴 기록만 지울 수 있어요."
            ],
            cancelTitle: "그대로 둘게요",
            confirmTitle: "삭제하기",
            isDanger: true,
            isBusy: sendState.isSending,
            identifier: "feedDelete",
            onCancel: { dismiss() },
            onConfirm: delete
        )
        .background(FeedOverlayBackdrop(feed: feed))
        .navigationBarBackButtonHidden(true)
        .attachComposerFailureAlert(sendState)
    }

    private func delete() {
        sendState.send(fallbackMessage: "기록을 지우지 못했어요.") {
            try await FeedAPIClient.shared.deleteFeed(feedID: feed.feedId)
        } onSuccess: {
            dismiss()
        }
    }
}

// MARK: - 24-6 피드 수정

struct FeedEditView: View {
    let feed: ServerFeed

    @Environment(\.dismiss) private var dismiss
    @State private var draftBody: String
    @StateObject private var sendState = AttachComposerSendState()

    /// 서버 `UpdateFeedRequest.content` 와 같은 한도 — `@Size(max = 500)` 이다.
    /// 예전에는 1,000 이라 500자를 넘겨 쓰면 저장 순간에 서버가 400 을 냈다.
    /// 작성 화면(`FeedWriteView`)은 처음부터 500 이었고 수정 화면만 어긋나 있었다.
    private static let contentLimit = 500

    init(feed: ServerFeed) {
        self.feed = feed
        _draftBody = State(initialValue: feed.content)
    }

    private var trimmed: String {
        draftBody.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isChanged: Bool {
        trimmed != feed.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var photoCount: Int { feed.images.count }

    private var visibilityText: String {
        ServerFeedMapper.visibility(from: feed.visibility) == .privateOnly ? "나만 보기" : "전체 공개"
    }

    var body: some View {
        AttachComposerFrame(
            title: "여행 기록 수정",
            cta: "수정 저장",
            isCTAEnabled: !trimmed.isEmpty && isChanged && !sendState.isSending,
            identifier: "feedEdit",
            onSend: save
        ) {
            AttachFieldLabel(text: "글", isRequired: true, isFirst: true)
            editor

            // 못 고치는 것은 감추지 않고 이유를 적는다 — 감추면 "왜 없지?" 로 남는다.
            VStack(alignment: .leading, spacing: 0) {
                Text("여기서 못 바꾸는 것")
                    .font(.system(size: 11.5, weight: .heavy))
                    .foregroundStyle(MoyeoTheme.text700)
                    .padding(.horizontal, 13)
                    .padding(.top, 11)
                    .padding(.bottom, 2)

                lockedRow(
                    icon: "photo",
                    title: "사진 \(photoCount)장",
                    reason: "사진은 바꿀 수 없어요. 다시 올리려면 기록을 지우고 새로 써요."
                )
                lockedRow(
                    icon: "lock",
                    title: "공개 범위 · \(visibilityText)",
                    reason: "댓글 쓴 분이 갑자기 못 보게 되지 않도록 처음 정한 값을 그대로 둬요."
                )
                lockedRow(
                    icon: "map",
                    title: feed.trip.courseTitle,
                    reason: "어느 여행의 기록인지는 바꿀 수 없어요."
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MoyeoTheme.subtleBackground)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.softLine))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.top, 14)

            // 삭제는 저장 CTA 와 멀리 떼어 놓는다 (20-3a 와 같은 규칙).
            NavigationLink {
                FeedDeleteView(feed: feed)
            } label: {
                Text("이 기록 삭제하기")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.dangerRed)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
            }
            .buttonStyle(.plain)
            .padding(.top, 24)
            .accessibilityIdentifier("feedEdit.delete")
        }
        .attachComposerFailureAlert(sendState)
    }

    private var editor: some View {
        VStack(alignment: .trailing, spacing: 0) {
            TextEditor(text: $draftBody)
                .font(.subheadline)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 148)
                .onChange(of: draftBody) { _, value in
                    if value.count > Self.contentLimit {
                        draftBody = String(value.prefix(Self.contentLimit))
                    }
                }
                .accessibilityLabel("여행 기록 글")
                .accessibilityIdentifier("feedEdit.body")
            Text("\(draftBody.count)/\(Self.contentLimit)")
                .font(MoyeoTypography.tinyMeta)
                .monospacedDigit()
                .foregroundStyle(MoyeoTheme.text400)
        }
        .padding(12)
        .background(MoyeoTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func lockedRow(icon: String, title: String, reason: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(MoyeoTheme.text400)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MoyeoTheme.text700)
                Text(reason)
                    .font(MoyeoTypography.tinyMeta)
                    .foregroundStyle(MoyeoTheme.text400)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "lock")
                .font(.system(size: 13))
                .foregroundStyle(MoyeoTheme.text400)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .overlay(alignment: .top) { Rectangle().fill(MoyeoTheme.softLine).frame(height: 1) }
    }

    private func save() {
        let content = trimmed
        sendState.send(fallbackMessage: "기록을 수정하지 못했어요.") {
            try await FeedAPIClient.shared.updateFeed(feedID: feed.feedId, content: content)
        } onSuccess: {
            dismiss()
        }
    }
}

/// 23-2 · 23-3 시트 뒤에 깔리는 화면 — **피드 상세**다.
///
/// 기획·웹은 시트 뒤에 피드가 보인다. 빈 배경으로 두면 딤만 남아 4열 비교에서
/// iOS 만 회색 판이 된다 (2026-09-08 대조에서 잡았다).
/// 30-2 신고 시트의 `ReportBackdrop` 과 같은 방식이다 — 피드를 못 받았으면 배경색만 둔다.
struct FeedOverlayBackdrop: View {
    let feed: ServerFeed?

    var body: some View {
        // 이 뒤 화면은 **장식용 다시 그리기**다 — 누를 수는 없지만 스크린리더는 그대로 읽어,
        // 시트 안을 다 읽고 나면 똑같은 피드 상세가 한 번 더 읽혔다 (TC ENV-007).
        if let feed {
            FeedDetailView(post: ServerFeedMapper.post(from: feed))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            MoyeoTheme.background
        }
    }
}
