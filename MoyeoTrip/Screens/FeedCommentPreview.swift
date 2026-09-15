//
//  FeedCommentPreview.swift
//  MoyeoTrip
//
//  23 피드 상세의 댓글 미리보기 (`FEED-COMMENT-PREVIEW-CANON.md`).
//
//  예전 모양은 **진입 링크가 댓글 위**에 「좋아요 N개」와 나란히 있고, 그 아래 최상위 댓글
//  3개를 그린 뒤 아무것도 없었다 — 다 읽은 사람에게는 「댓글이 3개가 끝」으로 보였다
//  (2026-09-14 사용자 지적). 이제 진입 줄은 **댓글 아래 하나**뿐이고, 위의
//  「좋아요 N개 · 댓글 N개」는 개수 표시로만 남는다.
//
//  대댓글은 서버가 `FeedCommentResponse.replies` 로 **이미 함께 준다** — 추가 호출이 없다.
//

import SwiftUI

/// 23 상세의 댓글 미리보기 묶음 — 최상위 댓글 + 대댓글 + 전체 보기 진입 줄.
struct FeedCommentPreviewSection: View {
    /// 서버가 준 최상위 댓글. 호출부가 `limit=3` 으로 받아 넘긴다 — 여기서 자르지 않는다.
    let comments: [ServerFeedComment]
    /// 전체 댓글 수. 서버 `commentCount` 는 **대댓글까지 센 값**이라 화면에 보이는 최상위
    /// 댓글 수와 다른 게 정상이다 (인스타그램·유튜브와 같은 셈법, 정본에 사용자 확인 있음).
    let commentCount: Int
    /// 23-1 전체 보기로 간다. 「답글 N개 더 보기」도 **그 자리에서 펼치지 않고** 여기로 간다.
    let onOpenAll: () -> Void

    /// 댓글 하나당 미리 보여줄 대댓글 수. 넘으면 접어서 23-1 로 보낸다.
    private static let replyPreviewLimit = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(comments) { comment in
                FeedPreviewCommentRow(comment: comment)
                repliesBlock(for: comment)
            }
            entryRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("feed.detail.commentPreview")
    }

    /// 대댓글 — 들여쓰기로 부모와의 관계를 보여준다. 2개를 넘으면 나머지는 접는다.
    @ViewBuilder
    private func repliesBlock(for comment: ServerFeedComment) -> some View {
        let replies = comment.replyList
        ForEach(replies.prefix(Self.replyPreviewLimit)) { reply in
            FeedPreviewCommentRow(comment: reply, isReply: true)
                .padding(.leading, 30)
        }
        if replies.count > Self.replyPreviewLimit {
            Button(action: onOpenAll) {
                Text("답글 \(replies.count - Self.replyPreviewLimit)개 더 보기")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MoyeoTheme.muted)
                    .frame(minHeight: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 30)
            .accessibilityIdentifier("feed.detail.commentPreview.moreReplies.\(comment.commentId)")
        }
    }

    /// 진입 줄은 **댓글 아래 하나뿐이다.** 댓글이 몇 개든 항상 그리고,
    /// `commentCount == 0` 일 때만 빼고 그 자리에 첫 댓글을 권한다.
    ///
    /// 「최상위 3개 이하면 감추자」는 폐기된 안이다 — 최상위가 적어도 **대댓글이 숨어 있을 수
    /// 있어** 들어갈 길이 사라진다.
    @ViewBuilder
    private var entryRow: some View {
        if commentCount == 0 {
            Text("첫 댓글을 남겨보세요.")
                .font(.caption)
                .foregroundStyle(MoyeoTheme.muted)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
                .accessibilityIdentifier("feed.detail.commentPreview.empty")
        } else {
            Button(action: onOpenAll) {
                HStack(spacing: 4) {
                    Text("댓글 \(commentCount)개 전체 보기")
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(MoyeoTheme.forest)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("댓글 \(commentCount)개 전체 보기")
            .accessibilityIdentifier("feed.comments.openAll")
        }
    }
}

/// 23 상세에 펼치는 댓글 한 줄 — 아바타 · 닉네임 · **작성 시각** · 본문.
/// 좋아요·답글 같은 행동은 23-1 에서만 한다.
struct FeedPreviewCommentRow: View {
    let comment: ServerFeedComment
    /// 대댓글이면 한 치수 작게 그린다.
    var isReply = false

    private var authorImageURL: URL? {
        MoyeoImageURL.resolve(comment.author?.profileImageUrl)
    }

    private var avatarSize: CGFloat { isReply ? 24 : 30 }

    /// 작성 시각 — 상대 시각 정본(`RELATIVE-TIME-CANON.md`)을 쓴다. 미리보기 댓글에는
    /// 시각이 아예 없었다 (2026-09-14 사용자 요청). 못 읽는 값이면 빈 문자열이라 줄을 뺀다.
    private var timeText: String {
        guard let createdAt = comment.createdAt else { return "" }
        return ServerFeedMapper.createdAtText(createdAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                avatar
                Text(comment.author?.nickname ?? "")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                if !timeText.isEmpty {
                    Text(timeText)
                        .font(.caption2)
                        .foregroundStyle(MoyeoTheme.text400)
                }
                Spacer(minLength: 0)
            }
            Text(comment.content ?? "")
                .font(.caption)
                .foregroundStyle(MoyeoTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, avatarSize + 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 서버가 프로필 이미지를 주면 반드시 이미지다 — 없을 때만 마스코트로 떨어진다.
    @ViewBuilder
    private var avatar: some View {
        if let authorImageURL {
            CachedRemoteImage(url: authorImageURL) { image in
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
                mascot: comment.author.flatMap {
                    MoyeoNicknameAnimal.emoji(forNickname: $0.nickname)
                } ?? MoyeoNicknameAnimal.unknown,
                size: avatarSize,
                background: MoyeoTheme.leaf
            )
        }
    }
}
