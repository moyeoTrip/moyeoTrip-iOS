//
//  CommentEditView.swift
//  MoyeoTrip
//
//  23-1a 내 댓글 수정 · 삭제.
//
//  기획 정본: `모여트립 in 경북/screens-edit-delete.jsx`
//  서버 계약: `docs/api/BACKEND_REQUEST_CHANGES_2026-09-04.md` §3 (2026-09-04 BE 회신)
//
//  근거: `PUT` · `DELETE /api/v1/feeds/{feedId}/comments/{commentId}`
//
//  · 댓글은 **그 자리에서** 고친다 — 별 화면으로 보내면 어느 댓글을 고치는지 잃는다.
//  · 서버 한도는 **500자**다. 신고 `details` 의 300자와 다르다 — 헷갈리기 쉬운 자리다.
//  · 최상위 댓글을 지우면 **달린 답글도 함께** 사라진다. 화면이 먼저 알려야 한다.
//  · 내 댓글에만 진입점을 낸다 — 남의 댓글은 서버가 403 으로 막는다(죽은 버튼을 두지 않는다).
//

import SwiftUI

struct CommentEditView: View {
    let feedID: Int64

    @State private var threads: [ServerFeedComment] = []
    @State private var myUserID: Int64?
    @State private var loadState: TripCompanionsState = .loading
    @State private var editingID: Int64?
    @State private var draft = ""
    @StateObject private var sendState = AttachComposerSendState()

    /// 서버 `UpdateFeedCommentRequest` 와 같은 한도.
    static let commentLimit = 500

    var body: some View {
        Group {
            switch loadState {
            case .loading:
                MoyeoEmptyStateView(
                    message: MoyeoEmptyText.loading,
                    accessibilityIdentifier: "commentEdit.state"
                )
            case .failed:
                MoyeoEmptyStateView(
                    message: MoyeoEmptyText.loadFailed,
                    onRetry: { Task { await load() } },
                    accessibilityIdentifier: "commentEdit.state"
                )
            case .empty:
                MoyeoEmptyStateView(
                    message: MoyeoEmptyText.noComments,
                    accessibilityIdentifier: "commentEdit.state"
                )
            case .ready:
                list
            }
        }
        .navigationTitle("댓글")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .attachComposerFailureAlert(sendState)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(threads) { comment in
                    CommentEditRow(
                        comment: comment,
                        depth: 0,
                        myUserID: myUserID,
                        editingID: $editingID,
                        draft: $draft,
                        isBusy: sendState.isSending,
                        onSave: save,
                        onDelete: delete
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
        .background(MoyeoTheme.background)
    }

    private func load() async {
        loadState = .loading
        guard MoyeoServerSync.isEnabled else {
            loadState = .empty
            return
        }
        guard let page = try? await FeedAPIClient.shared.comments(feedID: feedID, limit: 50),
              let me = try? await UserProfileAPIClient.shared.myProfile() else {
            loadState = .failed
            return
        }
        threads = page.comments
        myUserID = me.userId
        loadState = page.comments.isEmpty ? .empty : .ready
        // 이 화면(`comment-edit`)은 이름 그대로 **댓글을 고치러 오는 자리**다.
        // 인앱에서는 목록에서 「수정·삭제」를 눌러 대상을 들고 오지만, 라우트로 바로 열면
        // 대상이 없다 — 그때는 **내 가장 최근 댓글**을 편집 상태로 연다(기획 23-1a 와 같은 상태).
        // 이미 고치는 중이면 건드리지 않는다.
        if editingID == nil, let userID = me.userId,
           let mine = newestOwnComment(in: page.comments, myUserID: userID) {
            editingID = mine.commentId
            draft = mine.content ?? ""
        }
    }

    /// 내가 쓴 댓글 중 가장 최근 것. 답글도 후보다(서버가 최상위를 최신순으로 준다).
    private func newestOwnComment(in comments: [ServerFeedComment], myUserID: Int64) -> ServerFeedComment? {
        for comment in comments {
            if comment.author?.userId == myUserID { return comment }
            if let reply = newestOwnComment(in: comment.replyList, myUserID: myUserID) { return reply }
        }
        return nil
    }

    private func save(_ commentID: Int64) {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        sendState.send(fallbackMessage: "댓글을 수정하지 못했어요.") {
            try await FeedAPIClient.shared.updateComment(
                feedID: feedID, commentID: commentID, content: content
            )
        } onSuccess: {
            editingID = nil
            Task { await load() }
        }
    }

    private func delete(_ commentID: Int64) {
        sendState.send(fallbackMessage: "댓글을 지우지 못했어요.") {
            try await FeedAPIClient.shared.deleteComment(feedID: feedID, commentID: commentID)
        } onSuccess: {
            editingID = nil
            Task { await load() }
        }
    }
}

/// 댓글 한 줄. 답글은 자기 자신을 한 단 들여써 그린다.
private struct CommentEditRow: View {
    let comment: ServerFeedComment
    let depth: Int
    let myUserID: Int64?
    @Binding var editingID: Int64?
    @Binding var draft: String
    let isBusy: Bool
    let onSave: (Int64) -> Void
    let onDelete: (Int64) -> Void

    private var isMine: Bool {
        guard let myUserID, let authorID = comment.author?.userId else { return false }
        return authorID == myUserID
    }

    private var isEditing: Bool { editingID == comment.commentId }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 9) {
                // 기존 23-1 댓글 줄과 같은 표현 — 서버가 이미지를 주면 이미지,
                // 없을 때만 닉네임 동물로 떨어진다 (정본 NO-MOCK R5: 표는 한 곳뿐이다).
                commentAvatar

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(comment.author?.nickname ?? "")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(MoyeoTheme.ink)
                        Text(ServerFeedMapper.createdAtText(comment.createdAt ?? ""))
                            .font(MoyeoTypography.tinyMeta)
                            .foregroundStyle(MoyeoTheme.text400)
                        if isEditing {
                            Text("수정 중")
                                .font(MoyeoTypography.tinyMeta.weight(.bold))
                                .foregroundStyle(MoyeoTheme.forest)
                        }
                    }

                    if isEditing {
                        editor
                    } else {
                        Text(comment.content ?? "")
                            .font(.subheadline)
                            .foregroundStyle(MoyeoTheme.text700)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 3)

                        // 내 댓글에만 진입점을 낸다 — 남의 댓글은 서버가 403 으로 막는다.
                        //
                        // 「수정 · 삭제」를 회색 한 덩어리로 두면 **버튼으로 안 보인다** —
                        // 사용자가 「댓글 수정 버튼이 안 보인다」고 했다 (23-1a, 2026-09-09).
                        // 두 낱말로 갈라 각자의 색(수정=브랜드 초록 · 삭제=위험 빨강)을 준다.
                        if isMine {
                            HStack(spacing: 12) {
                                Button {
                                    editingID = comment.commentId
                                    draft = comment.content ?? ""
                                } label: {
                                    Text("수정")
                                        .font(MoyeoTypography.tinyMeta.weight(.heavy))
                                        .foregroundStyle(MoyeoTheme.brandText)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("commentEdit.open")
                                Button {
                                    editingID = comment.commentId
                                    draft = comment.content ?? ""
                                } label: {
                                    Text("삭제")
                                        .font(MoyeoTypography.tinyMeta.weight(.heavy))
                                        .foregroundStyle(MoyeoTheme.coral)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("commentEdit.openDelete")
                            }
                            .padding(.top, 5)
                        }
                    }
                }
            }
            .padding(.vertical, 13)
            .overlay(alignment: .bottom) {
                if !isEditing {
                    Rectangle().fill(MoyeoTheme.softLine).frame(height: 1)
                }
            }

            ForEach(comment.replyList) { reply in
                CommentEditRow(
                    comment: reply,
                    depth: depth + 1,
                    myUserID: myUserID,
                    editingID: $editingID,
                    draft: $draft,
                    isBusy: isBusy,
                    onSave: onSave,
                    onDelete: onDelete
                )
                .padding(.leading, 24)
            }
        }
    }

    private var avatarSize: CGFloat { depth > 0 ? 30 : 38 }

    @ViewBuilder
    private var commentAvatar: some View {
        if let imageURL = comment.author?.profileImageUrl, let url = URL(string: imageURL) {
            CachedRemoteImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                MoyeoTheme.leaf
            }
            .frame(width: avatarSize, height: avatarSize)
            .clipShape(Circle())
        } else {
            MascotAvatar(
                mascot: MoyeoNicknameAnimal.emoji(forNickname: comment.author?.nickname ?? "")
                    ?? MoyeoNicknameAnimal.unknown,
                size: avatarSize,
                background: MoyeoTheme.leaf
            )
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .trailing, spacing: 0) {
                TextEditor(text: $draft)
                    .font(.subheadline)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 62)
                    .onChange(of: draft) { _, value in
                        if value.count > CommentEditView.commentLimit {
                            draft = String(value.prefix(CommentEditView.commentLimit))
                        }
                    }
                    .accessibilityLabel("댓글 수정")
                    .accessibilityIdentifier("commentEdit.input")
                Text("\(draft.count)/\(CommentEditView.commentLimit)")
                    .font(MoyeoTypography.tinyMeta)
                    .monospacedDigit()
                    .foregroundStyle(MoyeoTheme.text400)
            }
            .padding(11)
            .background(MoyeoTheme.card)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.forest))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.top, 7)

            HStack(spacing: 8) {
                Button { onSave(comment.commentId) } label: {
                    Text("수정 저장")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(MoyeoTheme.forest)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isBusy || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("commentEdit.save")

                Button { editingID = nil } label: {
                    Text("취소")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(MoyeoTheme.text700)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(MoyeoTheme.line))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Button { onDelete(comment.commentId) } label: {
                    Text("삭제")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(MoyeoTheme.dangerRed)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .accessibilityIdentifier("commentEdit.delete")
            }
            .padding(.top, 9)

            Text(deleteWarning)
                .font(MoyeoTypography.tinyMeta)
                .foregroundStyle(MoyeoTheme.text400)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 7)
        }
    }

    /// 답글이 딸린 최상위 댓글은 **그 답글도 함께 사라진다**는 것을 먼저 알린다 (BE 회신 §3).
    private var deleteWarning: String {
        let replies = comment.replyList.count
        if depth == 0, replies > 0 {
            return "삭제하면 바로 사라져요. 이 댓글에 달린 답글 \(replies)개도 함께 없어져요. "
                + "되돌릴 수 없어요."
        }
        return "삭제하면 바로 사라져요. 되돌릴 수 없어요."
    }
}
