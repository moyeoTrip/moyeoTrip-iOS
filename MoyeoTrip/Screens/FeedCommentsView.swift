//
//  FeedCommentsView.swift
//  MoyeoTrip
//
//  23-1 피드 댓글 전체 보기. `Changelog02To05Screens.swift` 의 타입 본문이 300줄을 넘어 갈라냈다.
//
//  댓글 행의 동작은 **답글 달기 · 신고 · 차단** 셋이다 (23-1a 의 내 댓글 수정·삭제는 별 화면).
//  좋아요는 두지 않는다 — 서버에 댓글 좋아요 API 가 없다 (BE 요청 §4).
//

// 원글 요약·댓글 행·입력줄이 한 화면의 부품이라 다른 화면 파일들과 같은 예외를 둔다.
// 확장으로 갈라 놓은 부품들이 `private` 이라 파일을 더 쪼개면 접근 수준을 넓혀야 한다.
// swiftlint:disable file_length
import SwiftUI

private struct ChangelogComment: Identifiable {
  let mascot: String
  let name: String
  let badge: String
  let body: String
  let time: String
  var likes: Int = 0
  /// 대댓글. 댓글 구조가 검수되려면 답글까지 보여야 한다.
  var replies: [ChangelogComment] = []
  /// 실서버 댓글은 같은 사람이 같은 문장을 두 번 남길 수 있어 commentId를 식별자로 쓴다.
  var serverCommentID: Int64?
  /// 작성자 프로필 이미지. 서버가 주면 이걸 그리고, 없으면 `mascot` 으로 떨어진다.
  var authorImageURL: URL?
  /// 차단(`POST users/me/blocks/{userId}`) 대상. 서버 댓글만 안다.
  var authorUserID: Int64?

  var id: String {
    serverCommentID.map { "server-comment-\($0)" } ?? "\(name).\(body)"
  }
}

struct FeedCommentsView: View {
  let post: FeedPost
  @State private var comment = ""
  @State private var submitted: [String] = []
  /// 실서버 댓글 — 서버 피드이고 조회가 성공했을 때만 채워진다 (nil = 아직 못 받음).
  /// 무한 스크롤로 다음 묶음을 **뒤에 붙인다** (서버가 최신 id 부터 주므로 순서가 그대로 맞다).
  @State private var serverComments: [ServerFeedComment]?
  /// 다음 묶음 커서. 값이 없으면 마지막 묶음이다 (`nextId: null`).
  @State private var nextCommentID: Int64?
  @State private var isLoadingComments = false
  /// 첫 묶음을 한 번이라도 받아봤는지 — 받기 전에는 "댓글 없음" 을 띄우지 않는다.
  @State private var hasLoadedFirstPage = false
  /// 이 화면에서 등록해 서버에 반영된 댓글 수. 제목 개수를 서버 값 위에 더한다.
  @State private var postedCount = 0
  /// 진입 경로가 스텁 게시물(캡처·딥링크)일 때 제목·작성자·전체 개수를 채우려고 직접 받은 피드.
  @State private var loadedFeed: ServerFeed?

  /// 한 번에 받는 최상위 댓글 수. `GET /feeds` 와 같은 20 이다.
  private static let commentPageSize = 20

  /// 제목의 댓글 수.
  ///
  /// 커서 페이지네이션이라 받은 묶음만 세면 실제보다 작아진다 — `GET /feeds/{id}` 의
  /// `commentCount` 가 **대댓글까지 포함한 전체 수**라 그게 근거다
  /// (실서버 확인: 피드 1 = 최상위 3 + 답글 2 = 5).
  private var displayCommentCount: Int {
    let serverTotal = post.commentCount > 0 ? post.commentCount : Int(loadedFeed?.commentCount ?? 0)
    if serverTotal > 0 { return serverTotal + postedCount + submitted.count }
    guard let serverComments else { return submitted.count }
    return serverComments.reduce(0) { $0 + 1 + ($1.replies?.count ?? 0) } + submitted.count
  }

  /// 다음 묶음이 남아 있는지 — 서버가 준 `nextId` 로만 판단한다 (클라가 추측하지 않는다).
  private var hasMoreComments: Bool {
    nextCommentID != nil
  }

  /// 서버 피드면 서버 댓글만 그린다. 서버가 빈 배열을 주면 §2 빈 상태를 그린다.
  private var displayComments: [ChangelogComment] {
    guard let serverComments else { return comments }
    // 함수 참조(`map(Self.comment(from:))`)로 넘기면 main-actor 격리가 벗겨져 Swift 6 경고가 난다.
    return serverComments.map { changelogComment(from: $0) }
  }

  /// 서버 댓글 → 23-1 댓글 행. 서버가 주지 않는 값(마스코트·배지·좋아요 수)은 채우지 않는다.
  ///
  /// 시각은 **글 작성 시각**이라 상대 시각 정본(`ServerFeedMapper.createdAtText`)을 쓴다.
  /// 예전에는 **채팅용** `ServerDateTime.listTimeText` 를 써서 iOS 만 `오후 3:20` · `9월 7일` 이
  /// 떴다 — 안드로이드는 `3일 전` 이었다 (2026-09-14 사용자 지적, RELATIVE-TIME-CANON).
  private func changelogComment(from server: ServerFeedComment) -> ChangelogComment {
    var time = ""
    if let createdAt = server.createdAt {
      time = ServerFeedMapper.createdAtText(createdAt)
    }
    return ChangelogComment(
      mascot: "",
      name: server.author?.nickname ?? "",
      badge: "",
      body: server.content ?? "",
      time: time,
      replies: server.replyList.map { changelogComment(from: $0) },
      serverCommentID: server.commentId,
      authorImageURL: MoyeoImageURL.resolve(server.author?.profileImageUrl),
      authorUserID: server.author?.userId
    )
  }

  /// 서버 댓글을 못 받았을 때의 자리. 목 댓글을 채우지 않는다 (NO-MOCK-CANON R1).
  private let comments: [ChangelogComment] = []
  /// 「답글 달기」의 대상. 예전에는 `Button("답글 달기") {}` — **동작이 없는 버튼**이었다
  /// (23-1, 사용자 지적 2026-09-09). 서버는 `parentCommentId` 를 받는다.
  @State private var replyTarget: ChangelogComment?
  /// 신고 중인 댓글. 접수 API 가 없던 시절에는 `ReportUnsupportedDialog` 를 띄우는
  /// `Bool` 하나였다 — 서버에는 그때도 `POST /feeds/{feedId}/comments/{commentId}/reports`
  /// 가 있었다 (2026-09-14 실서버 확인). 이제 30-2 와 같은 결의 시트로 실제 접수한다.
  @State private var reportTargetComment: ChangelogComment?
  @State private var blockTarget: ChangelogComment?
  /// 23-1a 내 댓글 수정·삭제 화면으로 갈지.
  @State private var opensMyCommentEditor = false
  @State private var actionMessage: String?
  /// 댓글 등록 실패를 **입력칸 바로 위**에 적는다. 위쪽 `actionMessage` 는 스크롤을 올려야 보인다.
  @State private var submitError: String?
  @State private var isSubmitting = false

  /// 서버 `content` 한도와 같은 값. 예전에는 한도도 카운터도 없어, 넘긴 댓글이
  /// 오류 없이 사라졌다 (IOS-F26).
  private static let commentLimit = 500

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        LazyVStack(spacing: 0) {
          // 어떤 피드의 댓글인지 — 화면기획 23-1 상단 원글 요약
          originalPostSummary
          if let actionMessage {
            Text(actionMessage)
              .font(.caption.weight(.semibold))
              .foregroundStyle(MoyeoTheme.brandText)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 10)
              .accessibilityIdentifier("feedComments.actionResult")
          }
          if displayComments.isEmpty, submitted.isEmpty {
            if isLoadingComments && !hasLoadedFirstPage {
              // 첫 묶음을 받는 중이다 — 아직 없다고 단정하지 않는다.
              MoyeoEmptyStateView(
                message: MoyeoEmptyText.loading,
                accessibilityIdentifier: "feedComments.loading"
              )
            } else {
              MoyeoEmptyStateView(
                message: MoyeoEmptyText.noComments,
                accessibilityIdentifier: "feedComments.empty"
              )
            }
          }
          ForEach(displayComments) { item in
            commentRow(item)
              // 무한 스크롤 — **마지막 댓글**이 보이면 다음 묶음을 받는다.
              // 별도 표지에 `onAppear` 를 달면 그 표지가 한 번만 나타나 두 번째 묶음에서 멈춘다
              // (실제로 그렇게 멈추는 걸 시뮬레이터로 확인했다). 목록이 늘어나면
              // 새 마지막 항목이 다시 이 자리를 맡으므로 묶음마다 다시 걸린다.
              .onAppear {
                guard item.id == displayComments.last?.id else { return }
                Task { await loadMoreServerComments() }
              }
            // 대댓글은 들여쓰기로 부모와의 관계를 보여준다
            ForEach(item.replies) { reply in
              commentRow(reply, compact: true)
                .padding(.leading, 32)
            }
          }
          ForEach(submitted, id: \.self) { item in
            // 마스코트를 화면에서 고르지 않는다 — 표는 `MoyeoNicknameAnimal` 하나뿐이고
            // 이 자리는 닉네임을 모른다 (NO-MOCK-CANON R5). 이 파일의 다른 줄과 같이 비운다.
            commentRow(ChangelogComment(mascot: "", name: "나", badge: "", body: item, time: "방금"))
          }
          if hasMoreComments {
            // 다음 묶음이 남아 있다는 표시일 뿐이다 — 받아오는 건 마지막 댓글의 `onAppear` 가 한다.
            MoyeoEmptyStateView(
              message: MoyeoEmptyText.loading,
              accessibilityIdentifier: "feedComments.loadingMore"
            )
            .padding(.vertical, 12)
          }
          // 「함께 간 친구의 댓글이 먼저 보여요」를 두지 않는다 —
          // 서버는 댓글을 **id 내림차순**으로만 준다(친구 여부로 정렬하지 않는다).
          // 웹·안드로이드에도 없던 문구라, 지키지 못하는 약속을 iOS 만 하고 있었다 (23-1).
        }.padding(.horizontal, 18)
      }
      if let replyTarget {
        // 답글을 쓰는 중이면 누구에게 쓰는지 위에 띠로 알려 준다.
        HStack(spacing: 8) {
          Text("\(replyTarget.name)님에게 답글")
            .font(.caption.weight(.bold))
            .foregroundStyle(MoyeoTheme.muted)
          Spacer(minLength: 0)
          Button("취소") { self.replyTarget = nil }
            .font(.caption.weight(.bold))
            .foregroundStyle(MoyeoTheme.brandText)
            .buttonStyle(.plain)
            .accessibilityIdentifier("feedComments.reply.cancel")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(MoyeoTheme.subtleBackground)
      }
      composer
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    // 서버 댓글을 받았으면 그 개수가 근거다 — 목록에 5건이 떠 있는데 제목만 0 이면 안 된다.
    // 대댓글도 화면에 보이므로 함께 센다.
    .navigationTitle("댓글 \(displayCommentCount)")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await loadServerComments()
    }
    .overlay {
      // 댓글 신고는 **실제로 접수된다**. 사유는 `GET /feeds/report-reasons` 가 준다.
      if let target = reportTargetComment,
        let feedID = post.serverFeedID ?? loadedFeed?.feedId,
        let commentID = target.serverCommentID {
        MoyeoReportSheet(
          target: .comment(feedID: feedID, commentID: commentID),
          previewText: target.body
        ) {
          reportTargetComment = nil
        }
      }
    }
    .alert(
      "\(blockTarget?.name ?? "")님을 차단할까요?",
      isPresented: Binding(get: { blockTarget != nil }, set: { if !$0 { blockTarget = nil } })
    ) {
      Button("차단하기", role: .destructive) {
        if let target = blockTarget { blockCommentAuthor(target) }
        blockTarget = nil
      }
      Button("취소", role: .cancel) { blockTarget = nil }
    } message: {
      Text("차단하면 이 유저가 만들었거나 참여한 모집이 홈·탐색에서 모두 숨겨져요.")
    }
    .navigationDestination(isPresented: $opensMyCommentEditor) {
      if let feedID = post.serverFeedID {
        CommentEditView(feedID: feedID)
      } else {
        MoyeoEmptyStateView(message: MoyeoEmptyText.noFeeds)
      }
    }
    .accessibilityIdentifier("screen.feedComments")
  }

  /// 이 댓글이 내 것인가. 서버 댓글만 `authorUserID` 를 알고, 토큰의 userId 와 견준다.
  private func isMyComment(_ item: ChangelogComment) -> Bool {
    guard let authorID = item.authorUserID, let mine = MoyeoCurrentUser.id else { return false }
    return authorID == mine
  }

  /// 차단은 신고와 달리 **실제로 반영된다** (`POST users/me/blocks/{userId}`).
  private func blockCommentAuthor(_ target: ChangelogComment) {
    guard let userID = target.authorUserID else { return }
    Task {
      do {
        try await SocialAPIClient.shared.block(userID: userID)
        actionMessage = "\(target.name)님을 차단했어요."
      } catch {
        actionMessage = error.moyeoUserMessage(fallback: "차단하지 못했어요. 잠시 후 다시 시도해주세요.")
        return
      }
      // 차단하면 목록이 달라진다 — 첫 묶음부터 다시 읽는다.
      nextCommentID = nil
      serverComments = nil
      await loadServerComments()
    }
  }

  /// 첫 묶음. 댓글을 새로 달았을 때도 이걸 다시 부른다 —
  /// 최신 댓글이 최상위 첫 자리로 오므로 목록을 처음부터 다시 세우는 게 맞다.
  private func loadServerComments() async {
    guard MoyeoServerSync.isEnabled, let feedID = post.serverFeedID else { return }
    // 스텁 게시물(캡처·딥링크)로 들어오면 제목·작성자·전체 개수가 비어 있다 — 피드를 직접 받는다.
    if post.authorName.isEmpty, loadedFeed == nil {
      loadedFeed = try? await FeedAPIClient.shared.feed(id: feedID)
    }
    isLoadingComments = true
    defer {
      isLoadingComments = false
      hasLoadedFirstPage = true
    }
    guard let page = try? await FeedAPIClient.shared.comments(
      feedID: feedID,
      limit: Self.commentPageSize
    ) else { return }
    serverComments = page.comments
    nextCommentID = page.nextId
  }

  /// 다음 묶음. 서버가 준 `nextId` 를 `beforeCommentId` 로 그대로 넘긴다.
  private func loadMoreServerComments() async {
    guard MoyeoServerSync.isEnabled,
          let feedID = post.serverFeedID,
          let cursor = nextCommentID,
          !isLoadingComments else { return }
    isLoadingComments = true
    defer { isLoadingComments = false }
    guard let page = try? await FeedAPIClient.shared.comments(
      feedID: feedID,
      beforeCommentID: cursor,
      limit: Self.commentPageSize
    ) else {
      // 실패하면 같은 커서로 무한히 다시 부르지 않도록 멈춘다.
      nextCommentID = nil
      return
    }
    // 같은 커서 응답이 두 번 붙지 않게 이미 가진 id 는 건너뛴다.
    let known = Set((serverComments ?? []).map(\.commentId))
    serverComments = (serverComments ?? []) + page.comments.filter { !known.contains($0.commentId) }
    nextCommentID = page.nextId
  }
}

// 원글 요약 · 댓글 행 · 전송은 확장으로 뺀다 —
// 한 타입 본문이 300줄을 넘으면 SwiftLint(`type_body_length`)가 빌드를 세운다.
extension FeedCommentsView {
  /// 원글 요약 — 스텁 게시물로 들어왔으면 직접 받은 피드가 근거다 (없으면 빈 값 그대로 둔다).
  private var summaryTitle: String {
    post.feedTitle.isEmpty ? (loadedFeed?.trip.courseTitle ?? "") : post.feedTitle
  }

  private var summaryAuthorName: String {
    post.authorName.isEmpty ? (loadedFeed?.author.nickname ?? "") : post.authorName
  }

  private var summaryLikeCount: Int {
    post.authorName.isEmpty ? Int(loadedFeed?.likeCount ?? 0) : post.likeCount
  }

  /// 원글의 **첫 사진** — 피드가 준 사진 중 `sequence` 가 가장 앞선 것.
  /// (피드에 「대표 사진」이라는 개념은 없다 — 결정 ⑪.)
  ///
  /// 예전에는 사진이 있어도 무시하고 `MoyeoPhotoTile`(그라데이션 하늘 + 산 능선 도형)을
  /// 항상 그렸다. 그 도형은 40×40 으로 줄면 정체불명 무늬가 돼서 「이미지가 아니라 이상한 게
  /// 들어가 있다」는 지적을 받았다 (2026-09-14).
  private var summaryPhotoURL: URL? {
    if let photoURL = post.photoURL { return photoURL }
    return loadedFeed?.images.min { $0.sequence < $1.sequence }
      .flatMap { MoyeoImageURL.resolve($0.imageUrl) }
  }

  private var originalPostSummary: some View {
    HStack(spacing: 10) {
      // 사진이 **있으면 반드시 사진**이다. 없을 때만 기존 대체 그림으로 떨어진다.
      if let summaryPhotoURL {
        CachedRemoteImage(url: summaryPhotoURL) { image in
          image
            .resizable()
            .scaledToFill()
        } placeholder: {
          MoyeoTheme.leaf
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityHidden(true)
      } else {
        MoyeoPhotoTile(mascot: "", mood: post.mood, height: 40, cornerRadius: 10)
          .frame(width: 40)
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(summaryTitle)
          .font(.caption.weight(.heavy))
          .foregroundStyle(MoyeoTheme.ink)
          .lineLimit(1)
        Text("\(summaryAuthorName) · 좋아요 \(summaryLikeCount)")
          .font(.caption2)
          .foregroundStyle(MoyeoTheme.muted)
          .lineLimit(1)
      }
      Spacer(minLength: 0)
    }
    .padding(.top, 10)
    .padding(.bottom, 12)
    .overlay(alignment: .bottom) {
      Rectangle().fill(MoyeoTheme.softLine).frame(height: 1)
    }
    .accessibilityIdentifier("feedComments.originalPost")
  }

  private func commentRow(_ item: ChangelogComment, compact: Bool = false) -> some View {
    HStack(alignment: .top, spacing: 11) {
      // 서버가 프로필 이미지를 주면 반드시 이미지다 — 없을 때만 마스코트로 떨어진다.
      if let authorImageURL = item.authorImageURL {
        CachedRemoteImage(url: authorImageURL) { image in
          image
            .resizable()
            .scaledToFill()
        } placeholder: {
          MoyeoTheme.leaf
        }
        .frame(width: compact ? 30 : 38, height: compact ? 30 : 38)
        .clipShape(Circle())
      } else {
        MascotAvatar(mascot: item.mascot, size: compact ? 30 : 38, background: MoyeoTheme.leaf)
      }
      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 6) {
          Text(item.name).font(.subheadline.weight(.bold))
          if !item.badge.isEmpty {
            Text(item.badge).font(.system(size: 9.5, weight: .bold)).foregroundStyle(
              MoyeoTheme.forest
            )
            .padding(.horizontal, 7).frame(height: 21).background(MoyeoTheme.leaf).clipShape(
              Capsule())
          }
          Spacer()
          Text(item.time).font(.caption2).foregroundStyle(MoyeoTheme.text400)
        }
        Text(item.body).font(.subheadline).foregroundStyle(MoyeoTheme.ink)
        // 좋아요는 두지 않는다 — **댓글 좋아요 API 가 서버에 없다**(BE 요청 §4).
        // 예전에는 하트가 그려져 있었지만 누를 수도 없었고 수도 늘 0 이었다.
        // 「답글 달기」도 `{}` 라 아무 일도 하지 않았다 (23-1, 2026-09-09).
        HStack(spacing: 14) {
          // 대댓글에는 답글을 달지 않는다 — 서버가 2단만 받는다.
          if !compact {
            Button("답글 달기") { replyTarget = item }
              .foregroundStyle(MoyeoTheme.brandText)
              .accessibilityIdentifier("feedComments.reply")
          }
          // **내 댓글에는 신고·차단이 말이 안 된다.** 대신 23-1a 수정·삭제로 보낸다.
          // 그 화면(`CommentEditView`)도 API 도 오래 있었는데 **미는 곳이 캡처 하네스뿐**이라
          // 제품에서는 닿을 수 없었다 — 파일 머리 주석이 「수정·삭제는 별 화면」이라고
          // 적어 두고 그 별 화면으로 가는 길은 두지 않았다 (IOS-F27, 죽은 UI).
          if isMyComment(item) {
            Button("수정·삭제") { opensMyCommentEditor = true }
              .foregroundStyle(MoyeoTheme.brandText)
              .accessibilityIdentifier("feedComments.editMine")
          } else {
            Button("신고") { reportTargetComment = item }
              .accessibilityIdentifier("feedComments.report")
            Button("차단") { blockTarget = item }
              .accessibilityIdentifier("feedComments.block")
          }
        }
        .buttonStyle(.plain)
        .font(.caption.weight(.bold))
        .foregroundStyle(MoyeoTheme.muted)
        .frame(minHeight: 30)
      }
    }.padding(.vertical, 12).overlay(alignment: .bottom) {
      Rectangle().fill(MoyeoTheme.softLine).frame(height: 1)
    }
  }

  /// 입력줄 — 실패 문구와 글자수를 **입력칸 바로 옆에** 둔다.
  private var composer: some View {
    VStack(spacing: 6) {
      if let submitError {
        Text(submitError)
          .font(.caption.weight(.semibold))
          .foregroundStyle(MoyeoTheme.dangerRed)
          .frame(maxWidth: .infinity, alignment: .leading)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("feedComments.submitError")
      }
      HStack(spacing: 8) {
        TextField(
          replyTarget == nil ? "댓글을 입력하세요..." : "답글을 입력하세요...",
          text: Binding(
            get: { comment },
            set: { comment = String($0.prefix(Self.commentLimit)) }
          ),
          axis: .vertical
        ).lineLimit(1...4).padding(
          .horizontal, 13
        ).frame(minHeight: 44).background(MoyeoTheme.subtleBackground).clipShape(Capsule())
        Button {
          submit()
        } label: {
          Image(systemName: "paperplane.fill").foregroundStyle(.white).frame(width: 44, height: 44)
            .background(MoyeoTheme.forest).clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(replyTarget == nil ? "댓글 올리기" : "답글 올리기")
        .disabled(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
      }
      if !comment.isEmpty {
        Text("\(comment.count) / \(Self.commentLimit)자")
          .font(MoyeoTypography.tinyMeta)
          .foregroundStyle(comment.count >= Self.commentLimit ? MoyeoTheme.dangerRed : MoyeoTheme.muted)
          .frame(maxWidth: .infinity, alignment: .trailing)
          .accessibilityIdentifier("feedComments.counter")
      }
    }
    .padding(12)
    .background(MoyeoTheme.card)
  }

  /// 등록에 **성공한 뒤에만** 입력칸을 비운다. 예전에는 요청을 보내기도 전에 비우고
  /// `catch { return }` 으로 실패를 삼켜, 쓴 글이 말없이 사라졌다 (IOS-F26).
  private func submit() {
    let value = comment.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty, !isSubmitting else { return }
    submitError = nil
    guard MoyeoServerSync.isEnabled, let feedID = post.serverFeedID else {
      submitted.append(value)
      comment = ""
      return
    }
    // 서버 피드는 등록 후 **첫 묶음부터** 다시 읽는다 — 새 댓글이 최신 id 라 첫 묶음 맨 앞에 온다.
    // 화면에서 만든 댓글을 서버 값처럼 섞지 않는다.
    isSubmitting = true
    Task {
      defer { isSubmitting = false }
      do {
        try await FeedAPIClient.shared.postComment(
          feedID: feedID,
          content: value,
          parentCommentID: replyTarget?.serverCommentID
        )
        replyTarget = nil
        postedCount += 1
        comment = ""
      } catch {
        // 쓴 글은 입력칸에 그대로 둔다 — 다시 누르면 그대로 보낼 수 있어야 한다.
        submitError = error.moyeoUserMessage(fallback: "댓글을 올리지 못했어요. 잠시 후 다시 시도해주세요.")
        return
      }
      nextCommentID = nil
      serverComments = nil
      await loadServerComments()
    }
  }
}
