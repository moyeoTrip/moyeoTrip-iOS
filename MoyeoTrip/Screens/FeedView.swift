//
//  FeedView.swift
//  MoyeoTrip
//

// 실서버 피드 연동 상태가 더해져 길어졌다 — 기존 화면 파일들과 같은 예외를 둔다.
// swiftlint:disable file_length
import SwiftUI

/// 24 피드 상단 탭. 고른 값이 탭 전환 뒤에도 남아야 해서 보관소가 함께 쓴다 (TAB-STATE-CANON R3).
enum FeedSegment: String, CaseIterable, Hashable {
  case following = "팔로잉"
  case discover = "발견"

  var accessibilityKey: String {
    switch self {
    case .following:
      return "following"
    case .discover:
      return "discover"
    }
  }

  /// 서버 피드 목록의 `tab` 파라미터.
  var serverTab: String {
    switch self {
    case .following:
      return "FRIENDS"
    case .discover:
      return "DISCOVER"
    }
  }
}

private let feedTimelineMediaHeight: CGFloat = 166

/// 좋아요 한 건의 현재 상태(내가 눌렀는지 · 개수). 목록 카드가 서버 값 대신 이 값을 그린다.
struct FeedLikeState: Equatable {
  let liked: Bool
  let count: Int
}

struct FeedView: View {
  /// 목록·고른 탭은 화면 밖 보관소에 있다 — 탭을 다녀와도 다시 부르지 않는다 (TAB-STATE-CANON R1·R3).
  @ObservedObject var tabData: MoyeoTabDataStore
  @Binding var feedPosts: [FeedPost]
  @Binding var isBottomNavigationSuppressed: Bool
  var onPublish: (FeedPost) -> Void = { _ in }
  /// 24-1~24-5 단계별 캡처를 위한 글쓰기 시작 단계
  private let feedWriteInitialStep: Int
  /// 24-1~24-5 캡처가 지정한 기록 대상 방
  private let feedWriteRoomID: Int64?
  /// 진입 시 열어야 할 게시물. 서버 목록이 늦게 오므로 도착한 뒤 한 번 더 해석한다.
  private let initialPostID: String?
  @State private var isWritingPost = false
  @State private var selectedPost: FeedPost?
  /// changeLog18 — 작성자를 눌러 여는 25 프로필 카드
  @State private var authorProfileRoute: SupportRoute?
  /// 목록 카드의 `...` 로 여는 30-2 신고 시트. 상세(23)와 같은 경로를 쓴다.
  @State private var reportRoute: SupportRoute?
  /// 목록에서 누른 좋아요의 **성공한** 결과. 상세(23)와 같은 규칙이다 —
  /// 낙관적 갱신을 하지 않고 서버가 받아준 뒤에만 하트·숫자를 바꾼다(되돌릴 일이 없다).
  @State private var likeOverrides: [String: FeedLikeState] = [:]
  /// 좋아요 실패 까닭. **그 카드 자리에** 적는다 — 목록 전체를 오류로 덮지 않는다.
  @State private var likeErrors: [String: String] = [:]
  /// 요청이 도는 동안 같은 카드를 다시 누르지 않게 한다(연타로 토글이 엇갈리지 않게).
  @State private var likingPostIDs: Set<String> = []

  init(
    tabData: MoyeoTabDataStore,
    feedPosts: Binding<[FeedPost]>,
    isBottomNavigationSuppressed: Binding<Bool>,
    onPublish: @escaping (FeedPost) -> Void = { _ in },
    initialPostID: String? = nil,
    startsWritingPost: Bool = false,
    feedWriteInitialStep: Int = 1,
    feedWriteRoomID: Int64? = nil
  ) {
    self.tabData = tabData
    _feedPosts = feedPosts
    _isBottomNavigationSuppressed = isBottomNavigationSuppressed
    self.onPublish = onPublish
    self.initialPostID = initialPostID
    _selectedPost = State(
      initialValue: feedPosts.wrappedValue.first { $0.id == initialPostID })
    _isWritingPost = State(initialValue: startsWritingPost)
    self.feedWriteInitialStep = feedWriteInitialStep
    self.feedWriteRoomID = feedWriteRoomID
  }

  /// 지금 보고 있는 피드 탭의 스크롤 위치 (NAV-009).
  private var scrollOffsetBinding: Binding<CGFloat> {
    Binding(
      get: { tabData.feedScrollOffsets[segment.accessibilityKey] ?? 0 },
      set: { tabData.feedScrollOffsets[segment.accessibilityKey] = $0 }
    )
  }

  private var segment: FeedSegment {
    tabData.feedSegment
  }

  private var filteredPosts: [FeedPost] {
    if let serverPosts = tabData.feedPosts(for: segment) {
      return serverPosts
    }
    switch segment {
    case .following:
      return feedPosts.filter { $0.visibility == .friendsOnly }
    case .discover:
      return feedPosts.filter { $0.visibility != .privateOnly }
    }
  }

  /// 화면을 덮는 것이 하나라도 열려 있으면 탭바를 내린다.
  /// 조건을 여러 곳에 나눠 적었다가 프로필 카드를 빠뜨려, 그 화면의 하단 버튼이
  /// 탭바에 깔려 눌리지 않았다 — 한 군데서만 판단한다.
  private var isCoveringScreenOpen: Bool {
    selectedPost != nil || isWritingPost || authorProfileRoute != nil || reportRoute != nil
  }

  /// 22 목록에서 누른 좋아요 (`POST /feeds/{id}/like`). 상세(23) `toggleServerLike` 와 같은 규칙이다 —
  /// **성공한 뒤에만** 하트·숫자를 바꾸고, 실패하면 그 카드 자리에 까닭을 적는다.
  private func toggleLike(_ post: FeedPost) {
    guard MoyeoServerSync.isEnabled, let feedID = post.serverFeedID else { return }
    guard !likingPostIDs.contains(post.id) else { return }
    likingPostIDs.insert(post.id)
    likeErrors[post.id] = nil
    Task {
      do {
        try await FeedAPIClient.shared.toggleLike(feedID: feedID)
        let liked = !(likeOverrides[post.id]?.liked ?? post.serverLiked)
        let base = likeOverrides[post.id]?.count ?? post.likeCount
        likeOverrides[post.id] = FeedLikeState(liked: liked, count: max(base + (liked ? 1 : -1), 0))
      } catch {
        // 서버 문구를 그대로 흘리지 않는다 — `moyeoUserMessage` 가 통신·해석 실패를 먼저 가른다 (결정 ⑩).
        likeErrors[post.id] = error.moyeoUserMessage(
          fallback: "좋아요를 처리하지 못했어요. 잠시 후 다시 시도해주세요."
        )
      }
      likingPostIDs.remove(post.id)
    }
  }

  /// 캐시가 없고 조회 중일 때만 로딩 문구를 띄운다 (R2). 이미 받은 목록은 로딩으로 덮지 않는다.
  private var isLoadingWithoutCache: Bool {
    tabData.feedPosts(for: segment) == nil && tabData.isLoadingFeed(segment)
  }

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
    VStack(spacing: 0) {
      HStack(spacing: 42) {
        ForEach(FeedSegment.allCases, id: \.self) { item in
          Button {
            tabData.feedSegment = item
          } label: {
            HStack {
              Text(item.rawValue)
                .font(MoyeoTypography.font(size: 14, weight: .bold, relativeTo: .headline))
                .foregroundStyle(segment == item ? MoyeoTheme.ink : MoyeoTheme.muted)
            }
            .frame(width: 76, height: 52)
            .overlay(alignment: .bottom) {
              Rectangle()
                .fill(segment == item ? MoyeoTheme.forest : .clear)
                .frame(height: 2)
            }
          }
          .buttonStyle(.plain)
          .frame(width: 76, height: 50)
          .contentShape(Rectangle())
          .accessibilityLabel(item.rawValue)
          .accessibilityIdentifier("feed.segment.\(item.accessibilityKey)")
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: 52)
      .background(MoyeoTheme.background)
      .overlay(alignment: .bottom) {
        Rectangle()
          .fill(MoyeoTheme.softLine)
          .frame(height: 1)
      }

      ScrollViewReader { proxy in
        ScrollView {
          VStack(spacing: 0) {
            if filteredPosts.isEmpty {
              if isLoadingWithoutCache {
                // 처음 받아오는 중이다. 이미 목록이 있으면 여기 오지 않는다 (R2).
                MoyeoEmptyStateView(
                  message: MoyeoEmptyText.loading,
                  accessibilityIdentifier: "feed.loading"
                )
                .padding(.vertical, 30)
              } else if tabData.didFailFeed(segment) {
                // **실패와 빈 상태를 가른다** (NO-MOCK-CANON R1 · TC FEED-038).
                // 예전에는 서버가 500 을 줘도 「아직 올라온 피드가 없어요.」로 보였다.
                MoyeoSectionRetryNotice(
                  message: "피드를 불러오지 못했어요.",
                  identifier: "feed.list"
                ) {
                  Task { await tabData.refreshFeed(segment) }
                }
                .padding(.vertical, 30)
              } else {
                // 서버가 준 피드만 그린다 — 없으면 §2 빈 상태다
                MoyeoEmptyStateView(
                  message: MoyeoEmptyText.noFeeds,
                  systemImage: "doc.text.image",
                  accessibilityIdentifier: "feed.empty"
                )
                .padding(.vertical, 30)
              }
            }
            ForEach(Array(filteredPosts.enumerated()), id: \.element.id) { index, post in
              FeedPostCard(
                post: post,
                onOpenPost: {
                  selectedPost = post
                },
                onReport: {
                  reportRoute = .report(post.id)
                },
                onOpenMyActions: {
                  reportRoute = .feedActions(post.id)
                },
                onOpenAuthor: {
                  authorProfileRoute = .publicProfile(post.authorProfileSubject)
                },
                likeState: likeOverrides[post.id],
                isLiking: likingPostIDs.contains(post.id),
                likeErrorMessage: likeErrors[post.id],
                onToggleLike: { toggleLike(post) }
              )
              .id("feed.post.\(post.id)")

              if index == 1 {
                Color.clear
                  .frame(height: 1)
                  .id("feed.middle")
              }
            }
            Color.clear
              .frame(height: QAScrollState.requested?.qaSpacerHeight ?? 1)
              .id("feed.bottom")
              .accessibilityElement(children: .ignore)
              .accessibilityLabel("피드 끝")
              .accessibilityIdentifier("feed.timeline.end")
          }
          .padding(.horizontal, 16)
          .padding(.top, 14)
          .padding(.bottom, 132)
        }
        .transaction { transaction in
          transaction.disablesAnimations = true
        }
        .scrollBounceBehavior(.basedOnSize)
        // 당겨서 새로고침 — 정본 TAB-STATE-CANON R4. 한 번 받은 탭은 재진입해도 다시 부르지
        // 않으므로(R3), 새 글을 보려면 사용자가 명시적으로 당기는 길이 있어야 한다.
        .refreshable { await tabData.refreshFeed(tabData.feedSegment) }
        .background(MoyeoTheme.background)
        // 탭을 오간 뒤에도 보던 자리로 돌아온다 (TC NAV-009, TAB-STATE-CANON R3).
        // 팔로잉·발견은 보던 자리가 다르므로 탭별로 따로 기억하고,
        // 탭을 바꾸면 그 탭의 자리에서 다시 시작하도록 `id` 로 상태를 새로 잡는다.
        .moyeoRestoresScrollOffset(scrollOffsetBinding)
        .id(segment.accessibilityKey)
        .onAppear {
          guard let state = QAScrollState.requested else { return }
          let target = state.targetID(middle: "feed.middle", bottom: "feed.bottom")
          Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            proxy.scrollTo(target, anchor: state.anchor)
          }
        }
      }
    }
      // 피드 쓰기는 **화면에 하나**다. 카드마다 + 를 달면 "이 피드에 무언가 더한다"로
      // 읽히는데 실제 동작은 새 피드 작성이라 뜻이 어긋난다. 접근성 식별자도 카드 수만큼
      // 중복돼 UI 테스트가 무엇을 잡았는지 알 수 없었다 — 이제 화면에 하나뿐이다.
      // 홈 화면 모집 만들기 FAB 과 같은 치수·그림자를 쓴다 (home.floatingPlus).
      Button {
        isWritingPost = true
      } label: {
        Image(systemName: "plus")
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(.white)
          .frame(width: 50, height: 50)
          .background(MoyeoTheme.forest)
          .clipShape(Circle())
          .shadow(color: MoyeoTheme.forest.opacity(0.28), radius: 18, x: 0, y: 10)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("피드 쓰기")
      .accessibilityIdentifier("feed.write.open")
      .padding(.trailing, 20)
      .padding(.bottom, 86)
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .navigationDestination(item: $selectedPost) { post in
      FeedDetailView(post: post) {
        incrementCommentCount(for: post.id)
      }
    }
    .navigationDestination(item: $authorProfileRoute) { route in
      SupportDestinationView(route: route)
    }
    .navigationDestination(item: $reportRoute) { route in
      SupportDestinationView(route: route)
    }
    .navigationDestination(isPresented: $isWritingPost) {
      FeedWriteView(initialStep: feedWriteInitialStep, requestedRoomID: feedWriteRoomID) { post in
        publish(post)
      }
    }
    .onAppear {
      isBottomNavigationSuppressed = isCoveringScreenOpen
    }
    .onChange(of: selectedPost) { _, _ in
      isBottomNavigationSuppressed = isCoveringScreenOpen
    }
    .onChange(of: isWritingPost) { _, _ in
      isBottomNavigationSuppressed = isCoveringScreenOpen
    }
    // 프로필 카드의 하단 액션바(카드 뒤집기·친구 신청)가 탭바에 깔려 눌리지 않았다.
    .onChange(of: authorProfileRoute) { _, _ in
      isBottomNavigationSuppressed = isCoveringScreenOpen
    }
    .onChange(of: reportRoute) { _, _ in
      isBottomNavigationSuppressed = isCoveringScreenOpen
    }
    .onDisappear {
      if !isCoveringScreenOpen {
        isBottomNavigationSuppressed = false
      }
    }
    .task(id: segment) {
      await tabData.loadFeedIfNeeded(segment)
      // 상세는 생성 시점에 목 목록에서 골라진다. 서버 목록이 온 뒤 같은 ID 의 실제 게시물로 바꾼다 —
      // 그러지 않으면 캡처·딥링크가 항상 목 게시물을 연다.
      guard let posts = tabData.feedPosts(for: segment),
            let requested = initialPostID,
            let matched = Self.post(matching: requested, in: posts) else { return }
      selectedPost = matched
    }
    .accessibilityIdentifier("screen.feed")
  }

  /// 요청 ID 를 서버 게시물과 맞춘다. 캡처는 서버 `feedId` 숫자를 그대로 넘긴다.
  private static func post(matching requested: String, in posts: [FeedPost]) -> FeedPost? {
    if let feedID = Int64(requested) {
      return posts.first { $0.serverFeedID == feedID }
    }
    return posts.first { $0.id == requested }
  }

  private func publish(_ post: FeedPost) {
    feedPosts.removeAll { $0.id == post.id }
    feedPosts.insert(post, at: 0)
    onPublish(post)
    tabData.feedSegment = .discover
    isWritingPost = false
    DispatchQueue.main.async {
      selectedPost = post
    }
  }

  private func incrementCommentCount(for postID: String) {
    guard let index = feedPosts.firstIndex(where: { $0.id == postID }) else { return }
    feedPosts[index].commentCount += 1
  }
}

struct FeedDetailView: View {
  let post: FeedPost
  var onCommentSubmitted: () -> Void = {}
  @State private var comment = ""
  @State private var submittedComments: [String] = []
  @State private var optionMessage: String?
  /// 위 안내창의 제목. 이 창은 옵션·댓글·좋아요가 **같이 쓴다** — 좋아요가 실패했는데
  /// 「피드 옵션」이라고만 떠서 무엇이 실패했는지 읽히지 않았다.
  @State private var optionTitle = "피드 옵션"
  @State private var supportRoute: SupportRoute?
  /// 실서버 피드의 좋아요 토글 상태 (nil이면 서버 값 그대로)
  @State private var likeOverride: (liked: Bool, count: Int)?
  @State private var isSendingComment = false
  /// 23 상세에 미리 보여줄 댓글 **일부**. 전체는 23-1 로 간다 (사용자 결정 2026-08-31 · 안드로이드 정본).
  @State private var previewComments: [ServerFeedComment] = []
  /// 23-1 로 넘길 게시물. 이 화면이 가진 실제 게시물을 그대로 넘겨야
  /// 23-1 상단 원글 요약(제목·작성자·좋아요)과 제목 개수가 채워진다.
  @State private var commentsPost: FeedPost?

  /// 첫 화면에 보여줄 최상위 댓글 수. 세 플랫폼이 3건으로 같다 (PDF-REVIEW-2026-08-31 F3).
  /// 커서 페이지네이션이라 요청도 3건만 한다 — 전체를 받아 잘라내지 않는다.
  private static let previewCommentLimit = 3

  /// 이 화면에서 서버에 등록해 목록에 반영된 댓글 수. `post` 는 값 복사라 갱신되지 않는다.
  @State private var postedCommentCount = 0

  private var totalCommentCount: Int {
    post.commentCount + submittedComments.count + postedCommentCount
  }

  private var displayLikeCount: Int {
    likeOverride?.count ?? post.likeCount
  }

  private var displayLiked: Bool {
    likeOverride?.liked ?? post.serverLiked
  }

  /// 목록 카드와 **같은 규칙**을 쓴다 (`FeedPost.canReport`).
  private var canReportPost: Bool { post.canReport }

  /// 「방문지 N곳」으로 여는 14 코스 상세. `FeedTripResponse.courseId` 가 근거다 —
  /// 추가 API 가 없고 `GET /travel-courses/{courseId}` 를 그대로 연다.
  @State private var courseRoute: Int64?

  /// 「방문지 N곳」 칸.
  ///
  /// 예전에는 **누를 수 없는 장식**이라, 어떤 코스를 다녀온 글인지 보고도 그 코스를 열 수
  /// 없었다 (2026-09-14 사용자 지적). `courseId` 를 아는 서버 피드에서만 누를 수 있게 하고,
  /// 모르면 **누를 수 있는 모양을 주지 않는다** — 식별자 없이 눌리는 자리를 만들지 않는다.
  @ViewBuilder
  private var visitCountTile: some View {
    if let courseID = post.serverCourseID {
      Button {
        courseRoute = courseID
      } label: {
        FeedMetricBox(title: "방문지", value: post.visitCountText, showsChevron: true)
      }
      .buttonStyle(.plain)
      .accessibilityAddTraits(.isButton)
      .accessibilityLabel("방문지 \(post.visitCountText), 코스 상세 보기")
      .accessibilityIdentifier("feed.detail.openCourse")
    } else {
      FeedMetricBox(title: "방문지", value: post.visitCountText)
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          HStack(spacing: 12) {
            // changeLog18 — 작성자를 누르면 25 프로필 카드로 간다
            HStack(spacing: 12) {
              FeedAuthorAvatar(post: post, size: 44)
              VStack(alignment: .leading, spacing: 5) {
                Text(post.displayAuthorName)
                  .font(.system(size: 15, weight: .heavy))
                  .foregroundStyle(MoyeoTheme.ink)
                Text(post.createdAt)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(MoyeoTheme.muted)
              }
            }
            .contentShape(Rectangle())
            .onTapGesture {
              supportRoute = .publicProfile(post.authorProfileSubject)
            }
            Spacer()
            // 공개 범위는 작성자 정보와 같은 줄에 둬서, 본문을 밀어내는 큰 단독 칩이 되지 않게 한다.
            FeedVisibilityBadge(title: post.visibility.rawValue)
            // 30-2 는 **남의 피드**에만 둔다 — 자기 피드를 신고하면 서버가 400 `40039`
            // (`본인이 작성한 피드는 신고할 수 없습니다`)로 거절한다. 정본 §2 는 403 이라 적었지만
            // 실서버는 400 이다(2026-09-03 확인). 어느 쪽이든 버튼을 두지 않는다.
            // 24-6 — **내 피드**에는 수정·삭제 시트를 연다. 예전에는 내 글에 `...` 자체가
            // 없어서 앱 안에서 내 여행기록을 고치거나 지울 길이 아예 없었다 (TC FEED-027).
            if post.canEditOrDelete {
              Button {
                supportRoute = .feedActions(post.id)
              } label: {
                Image(systemName: "ellipsis")
                  .foregroundStyle(MoyeoTheme.muted)
                  .frame(width: 44, height: 44)
                  .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .accessibilityLabel("내 피드 더보기")
              .accessibilityIdentifier("feed.detail.myMore")
            }
            if canReportPost {
              Button {
                supportRoute = .report(post.id)
              } label: {
                Image(systemName: "ellipsis")
                  .foregroundStyle(MoyeoTheme.muted)
                  .frame(width: 44, height: 44)
                  .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .accessibilityLabel("더보기")
              .accessibilityIdentifier("feed.detail.more")
            }
          }

          Text(post.feedTitle)
            .font(.system(size: 20, weight: .heavy))
            .foregroundStyle(MoyeoTheme.ink)
            .lineSpacing(4)

          Text(post.feedSubtitle)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(MoyeoTheme.muted)
            .lineSpacing(3)

          // 피드 경로에는 좌표가 없다 — 손으로 그린 경로 지도를 옆에 두지 않는다 (R4)
          //
          // 목록용 미리보기(`FeedPhotoPreview`, 앞 2장)를 쓰지 않는다 — 상세에서는
          // **전체를 좌우로 넘겨 볼 수 있어야** 하고 배지도 지금 위치를 가리켜야 한다.
          // 예전에는 4장 중 2장만 보이는데 배지는 고정 `"1/4"` 였다.
          FeedPhotoPager(photoURLs: post.photoURLs, height: 168)

          Text(post.detailBodyText)
            .font(.subheadline)
            .foregroundStyle(MoyeoTheme.ink)
            .fixedSize(horizontal: false, vertical: true)

          // 서버 피드는 이동 거리·소요 시간을 내려주지 않는다 — 값이 있는 칸만 그린다
          HStack(spacing: 8) {
            if !post.distanceText.isEmpty {
              FeedMetricBox(title: "이동 거리", value: post.distanceText)
            }
            if !post.durationText.isEmpty {
              FeedMetricBox(title: "소요 시간", value: post.durationText)
            }
            if !post.visitCountText.isEmpty {
              visitCountTile
            }
          }

          HStack(spacing: 18) {
            if post.isServerBacked {
              Button {
                toggleServerLike()
              } label: {
                Label("좋아요 \(displayLikeCount)개", systemImage: displayLiked ? "heart.fill" : "heart")
                  .foregroundStyle(displayLiked ? MoyeoTheme.coral : MoyeoTheme.text700)
              }
              .buttonStyle(.plain)
              .accessibilityIdentifier("feed.detail.like")
            } else {
              Text("좋아요 \(post.likeCount)개")
            }
            // **개수 표시만이다 — 누르는 기능이 없다.** 23-1 진입은 댓글 아래 한 군데뿐이다
            // (`FEED-COMMENT-PREVIEW-CANON`: 같은 기능을 두 군데 두지 않는다).
            Text("댓글 \(totalCommentCount)개")
              .accessibilityIdentifier("feed.detail.commentCount")
          }
          .font(.caption.weight(.semibold))
          .foregroundStyle(MoyeoTheme.text700)
          .padding(.bottom, 14)
          .frame(maxWidth: .infinity, alignment: .leading)
          .overlay(alignment: .bottom) {
            Rectangle()
              .fill(MoyeoTheme.softLine)
              .frame(height: 1)
          }

          // 댓글 일부(최상위 3건 + 각 대댓글 2건)를 상세에 펼치고, **그 아래** 23-1 진입 줄을 둔다.
          // 대댓글은 `replies` 로 이미 응답에 들어 있다 — 추가 호출을 만들지 않는다.
          FeedCommentPreviewSection(
            comments: previewComments,
            commentCount: totalCommentCount,
            onOpenAll: { commentsPost = post }
          )

          if !submittedComments.isEmpty {
            VStack(spacing: 8) {
              ForEach(Array(submittedComments.enumerated()), id: \.offset) { _, submittedComment in
                Text("나: \(submittedComment)")
                  .font(.subheadline)
                  .foregroundStyle(MoyeoTheme.ink)
                  .padding(12)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .background(MoyeoTheme.subtleBackground)
                  .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
              }
            }
          }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 88)
      }

      HStack(spacing: 8) {
        TextField("댓글을 입력하세요...", text: $comment, axis: .vertical)
          .lineLimit(1...4)
          .padding(.horizontal, 14)
          .frame(minHeight: 44)
          .background(MoyeoTheme.background)
          .clipShape(Capsule())
          .overlay {
            Capsule()
              .stroke(MoyeoTheme.softLine, lineWidth: 1)
          }
        Button {
          let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
          guard !trimmed.isEmpty, !isSendingComment else { return }
          if let feedID = post.serverFeedID, MoyeoServerSync.isEnabled {
            // 실서버 피드 — 댓글을 서버에 등록한다
            isSendingComment = true
            Task {
              do {
                try await FeedAPIClient.shared.postComment(feedID: feedID, content: trimmed)
                postedCommentCount += 1
                onCommentSubmitted()
                comment = ""
                // 새 댓글이 최신 id 라 첫 묶음 맨 앞에 온다 — 미리보기를 서버 값으로 다시 세운다.
                // 화면에서 만든 문장을 서버 목록에 섞지 않는다.
                await loadPreviewComments()
              } catch {
                optionTitle = "댓글을 등록하지 못했어요"
                optionMessage = error.moyeoUserMessage(fallback: "댓글을 등록하지 못했어요. 잠시 후 다시 시도해주세요.")
              }
              isSendingComment = false
            }
          } else {
            submittedComments.append(trimmed)
            onCommentSubmitted()
            comment = ""
          }
        } label: {
          Image(systemName: "paperplane.fill")
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(
              comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? MoyeoTheme.text400 : MoyeoTheme.river
            )
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        // ENV-006: 라벨이 없으면 VoiceOver 가 영어 시스템 문구(「Send」)로 읽는다.
        .accessibilityLabel("댓글 올리기")
        .accessibilityIdentifier("feed.comment.send")
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(MoyeoTheme.card)
      .overlay(alignment: .top) {
        Rectangle()
          .fill(MoyeoTheme.softLine)
          .frame(height: 1)
      }
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .navigationBarTitleDisplayMode(.inline)
    .navigationDestination(item: $supportRoute) { route in
      SupportDestinationView(route: route)
    }
    // 23-1 로는 `SupportRoute` 를 거치지 않고 이 게시물을 그대로 넘긴다 —
    // 라우트를 거치면 목록이 없는 경로에서 스텁 게시물로 떨어져 제목·작성자가 빈다.
    .navigationDestination(item: $commentsPost) { target in
      FeedCommentsView(post: target)
    }
    // 14 코스 상세. `courseId` 만 아는 진입이라 빈 껍데기를 넘기고
    // 그 화면이 `GET /travel-courses/{courseId}` 로 다시 채운다 (다른 진입점과 같은 방식).
    .navigationDestination(item: $courseRoute) { courseID in
      CourseDetailView(course: ServerCourseMapper.stubCourse(serverCourseID: courseID))
    }
    .task(id: post.serverFeedID) {
      await loadPreviewComments()
    }
    .alert(
      optionTitle,
      isPresented: Binding<Bool>(
        get: { optionMessage != nil },
        set: { isPresented in
          if !isPresented {
            optionMessage = nil
          }
        }
      ),
      actions: {
        Button("확인") {
          optionMessage = nil
        }
      },
      message: {
        Text(optionMessage ?? "")
      }
    )
  }

  /// 23 상세의 댓글 미리보기. 커서 페이지네이션의 첫 묶음을 `limit=3` 으로만 받는다 —
  /// 전체를 받아 화면에서 자르지 않는다.
  private func loadPreviewComments() async {
    guard MoyeoServerSync.isEnabled, let feedID = post.serverFeedID else { return }
    guard let page = try? await FeedAPIClient.shared.comments(
      feedID: feedID,
      limit: Self.previewCommentLimit
    ) else { return }
    previewComments = page.comments
  }

  /// 실서버 피드 좋아요 토글 (POST /feeds/{id}/like)
  private func toggleServerLike() {
    guard let feedID = post.serverFeedID, MoyeoServerSync.isEnabled else { return }
    Task {
      do {
        try await FeedAPIClient.shared.toggleLike(feedID: feedID)
        let liked = !displayLiked
        likeOverride = (liked, max(displayLikeCount + (liked ? 1 : -1), 0))
      } catch {
        optionTitle = "좋아요를 처리하지 못했어요"
        optionMessage = error.moyeoUserMessage(fallback: "좋아요를 처리하지 못했어요. 잠시 후 다시 시도해주세요.")
      }
    }
  }
}

private struct FeedVisibilityBadge: View {
  let title: String

  var body: some View {
    Label(title, systemImage: "person.2")
      .font(.caption2.weight(.heavy))
      .foregroundStyle(MoyeoTheme.muted)
      .padding(.horizontal, 8)
      .frame(height: 28)
      .background(MoyeoTheme.card)
      .clipShape(Capsule())
      .overlay(Capsule().stroke(MoyeoTheme.softLine, lineWidth: 1))
      .accessibilityIdentifier("feed.detail.visibility")
  }
}

private struct FeedPostCard: View {
  let post: FeedPost
  let onOpenPost: () -> Void
  /// 30-2 신고 시트를 연다. 상세(23)의 `...` 와 같은 동작이다.
  let onReport: () -> Void
  /// 24-6 내 피드 수정·삭제 시트를 연다 (내 글일 때만 그려진다).
  let onOpenMyActions: () -> Void
  let onOpenAuthor: () -> Void
  /// 이 화면에서 눌러 **성공한** 좋아요 결과. 없으면 서버가 준 값 그대로 그린다.
  var likeState: FeedLikeState?
  var isLiking = false
  var likeErrorMessage: String?
  var onToggleLike: () -> Void = {}

  private var displayLiked: Bool { likeState?.liked ?? post.serverLiked }
  private var displayLikeCount: Int { likeState?.count ?? post.likeCount }

  /// 상세(23)와 **같은 규칙**을 쓴다 (`FeedPost.canReport`) — 두 곳에 따로 적으면 갈린다.
  private var canReport: Bool { post.canReport }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button(action: onOpenPost) {
        VStack(alignment: .leading, spacing: 0) {
          HStack(spacing: 9) {
            // changeLog18 — 작성자 영역만 25 프로필 카드로 간다.
            // 카드 전체는 피드 상세로 가므로, 자식 탭 제스처가 먼저 먹도록 여기서 가로챈다.
            HStack(spacing: 9) {
              FeedAuthorAvatar(post: post, size: 34)
              VStack(alignment: .leading, spacing: 2) {
                Text(post.displayAuthorName)
                  .font(MoyeoTypography.font(size: 12, weight: .bold, relativeTo: .subheadline))
                  .foregroundStyle(MoyeoTheme.ink)
                  .accessibilityIdentifier("feed.post.\(post.id).author")
                Text(post.createdAt)
                  .font(MoyeoTypography.font(size: 10, relativeTo: .caption2))
                  .foregroundStyle(MoyeoTheme.muted)
                  .accessibilityIdentifier("feed.post.\(post.id).createdAt")
              }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpenAuthor)
            Spacer()
            // 예전에는 `Button` 이 아니라 그냥 `Image` 였다 — **눌러도 아무 일도 없었다.**
            // 피드 상세(23)의 `...` 와 같은 동작·같은 조건을 쓴다: 신고 시트를 열고,
            // 자기 피드에는 두지 않는다(서버가 400 `40039` 로 거절한다).
            if post.canEditOrDelete {
              Button(action: onOpenMyActions) {
                Image(systemName: "ellipsis")
                  .foregroundStyle(MoyeoTheme.muted)
                  .frame(width: 44, height: 44)
                  .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .accessibilityLabel("내 피드 더보기")
              .accessibilityIdentifier("feed.post.\(post.id).myMore")
            }
            if canReport {
              Button(action: onReport) {
                Image(systemName: "ellipsis")
                  .foregroundStyle(MoyeoTheme.muted)
                  .frame(width: 44, height: 44)
                  .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .accessibilityLabel("더보기")
              .accessibilityIdentifier("feed.post.\(post.id).more")
            }
          }

          Text(post.feedTitle)
            .font(MoyeoTypography.font(size: 15, weight: .bold, relativeTo: .headline))
            .foregroundStyle(MoyeoTheme.ink)
            .lineLimit(1)
            .padding(.top, 12)
            .accessibilityIdentifier("feed.post.\(post.id).title")

          // 22 타임라인의 본문 — 웹(`feed.content`) · 안드로이드(`feed.content`)와 같은 줄이다.
          // 예전에는 코스 제목과 지역·해시태그만 그려 **작성 내용이 아예 보이지 않았다.**
          if !post.caption.isEmpty {
            Text(post.caption)
              .font(MoyeoTypography.font(size: 12, relativeTo: .caption))
              .foregroundStyle(MoyeoTheme.text700)
              .lineLimit(4)
              .multilineTextAlignment(.leading)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.top, 5)
              .accessibilityIdentifier("feed.post.\(post.id).body")
          }

          // 지역 · 해시태그는 서버 피드에 없다 — 빈 줄을 만들지 않는다 (R1).
          if !post.feedSubtitle.isEmpty {
            Text(post.feedSubtitle)
              .font(MoyeoTypography.font(size: 12, relativeTo: .caption))
              .foregroundStyle(MoyeoTheme.muted)
              .lineLimit(1)
              .padding(.top, 5)
              .accessibilityIdentifier("feed.post.\(post.id).subtitle")
          }
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(post.feedTitle)
      .accessibilityIdentifier("feed.post.\(post.id)")

      // 피드 경로에는 좌표가 없다 — 손으로 그린 경로 지도를 옆에 두지 않는다 (R4)
      //
      // 결정 ⑪ — 사진은 **위 `Button` 바깥**에 둔다. 여러 장이면 상세와 같은 페이저로
      // 좌우로 넘긴다. `Button` 안에 `TabView(.page)` 를 넣으면 탭이 삼켜져
      // 카드를 눌러도 상세로 가지 않는다. 대신 사진 탭은 `onTap` 으로 직접 받아
      // **누르면 상세로 가는 동작은 그대로** 둔다.
      if post.hasFeedPhoto {
        Group {
          if post.photoURLs.count > 1 {
            FeedCardPhotoPager(
              photoURLs: post.photoURLs,
              height: feedTimelineMediaHeight,
              identifierPrefix: "feed.post.\(post.id)",
              onTap: onOpenPost
            )
          } else {
            // 사진이 1장(또는 목데이터 타일)이면 페이저도 배지도 만들지 않는다.
            FeedPhotoPreview(post: post, height: feedTimelineMediaHeight)
              .contentShape(Rectangle())
              .onTapGesture(perform: onOpenPost)
          }
        }
        .frame(height: feedTimelineMediaHeight)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.top, 12)
      }

      HStack(spacing: 16) {
        // 목록에서도 좋아요를 **누를 수 있다** — 웹·안드와 같다(결정 ⑥, 파리티 2026-09-15).
        // 예전에는 표시 전용이라 상세에 들어가야만 누를 수 있었다.
        // 상세와 같은 규칙으로 **성공한 뒤에만** 하트·숫자를 바꾼다(낙관적 갱신 없음).
        if post.isServerBacked {
          Button(action: onToggleLike) {
            Label("\(displayLikeCount)", systemImage: displayLiked ? "heart.fill" : "heart")
              .foregroundStyle(displayLiked ? MoyeoTheme.coral : MoyeoTheme.text700)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .disabled(isLiking)
          .accessibilityLabel("좋아요 \(displayLikeCount)개")
          .accessibilityIdentifier("feed.post.\(post.id).likes")
        } else {
          // 목데이터 카드는 서버에 보낼 대상이 없다 — 표시 전용 그대로 둔다.
          Label("\(post.likeCount)", systemImage: post.serverLiked ? "heart.fill" : "heart")
            .accessibilityIdentifier("feed.post.\(post.id).likes")
        }
        Label("\(post.commentCount)", systemImage: "bubble.right")
          .accessibilityIdentifier("feed.post.\(post.id).comments")
      }
      .font(MoyeoTypography.font(size: 12, relativeTo: .caption))
      .foregroundStyle(MoyeoTheme.text700)
      .padding(.top, 12)

      // 실패는 **그 카드 자리에** 적는다 — 목록 전체를 오류로 덮지 않는다.
      if let likeErrorMessage {
        Text(likeErrorMessage)
          .font(MoyeoTypography.font(size: 11, relativeTo: .caption2))
          .foregroundStyle(MoyeoTheme.coral)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 6)
          .accessibilityIdentifier("feed.post.\(post.id).likeError")
      }
    }
    .padding(.bottom, 18)
    .padding(.top, 14)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(MoyeoTheme.softLine)
        .frame(height: 1)
    }
  }
}
