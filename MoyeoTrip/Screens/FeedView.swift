//
//  FeedView.swift
//  MoyeoTrip
//

// 실서버 피드 연동 상태가 더해져 길어졌다 — 기존 화면 파일들과 같은 예외를 둔다.
// swiftlint:disable file_length
import SwiftUI

private enum FeedSegment: String, CaseIterable, Hashable {
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
}

private let feedTimelineMediaHeight: CGFloat = 166

struct FeedView: View {
  @Binding var feedPosts: [FeedPost]
  @Binding var isBottomNavigationSuppressed: Bool
  var onPublish: (FeedPost) -> Void = { _ in }
  /// 24-1~24-5 단계별 캡처를 위한 글쓰기 시작 단계
  private let feedWriteInitialStep: Int
  @State private var segment: FeedSegment = .discover
  @State private var isWritingPost = false
  @State private var selectedPost: FeedPost?
  /// 실서버 피드 — 로그인 세션이 있고 피드 API가 성공했을 때만 채워진다 (nil = 목데이터)
  @State private var serverPosts: [FeedPost]?
  /// changeLog18 — 작성자를 눌러 여는 25 프로필 카드
  @State private var authorProfileRoute: SupportRoute?

  init(
    feedPosts: Binding<[FeedPost]>,
    isBottomNavigationSuppressed: Binding<Bool>,
    onPublish: @escaping (FeedPost) -> Void = { _ in },
    initialPostID: String? = nil,
    startsWritingPost: Bool = false,
    feedWriteInitialStep: Int = 1
  ) {
    _feedPosts = feedPosts
    _isBottomNavigationSuppressed = isBottomNavigationSuppressed
    self.onPublish = onPublish
    _selectedPost = State(
      initialValue: MockData.feedPost(for: initialPostID, in: feedPosts.wrappedValue))
    _isWritingPost = State(initialValue: startsWritingPost)
    self.feedWriteInitialStep = feedWriteInitialStep
  }

  private var filteredPosts: [FeedPost] {
    if let serverPosts {
      return serverPosts
    }
    switch segment {
    case .following:
      return feedPosts.filter { $0.visibility == .friendsOnly }
    case .discover:
      return feedPosts.filter { $0.visibility != .privateOnly }
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 42) {
        ForEach(FeedSegment.allCases, id: \.self) { item in
          Button {
            segment = item
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
            if let serverPosts, serverPosts.isEmpty {
              // 실서버 피드가 비어 있을 때의 상태 UI
              VStack(spacing: 8) {
                Image(systemName: "doc.text.image")
                  .font(.title3.weight(.bold))
                  .foregroundStyle(MoyeoTheme.forest)
                Text(segment == .following ? "친구의 피드가 아직 없어요" : "아직 올라온 피드가 없어요")
                  .font(.subheadline.weight(.heavy))
                  .foregroundStyle(MoyeoTheme.ink)
                Text("여행을 마치면 피드로 기록을 남길 수 있어요.")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(MoyeoTheme.muted)
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 64)
              .accessibilityIdentifier("feed.server.empty")
            }
            ForEach(Array(filteredPosts.enumerated()), id: \.element.id) { index, post in
              FeedPostCard(
                post: post,
                onOpenPost: {
                  selectedPost = post
                },
                onOpenAuthor: {
                  authorProfileRoute = .publicProfile(post.authorProfileSubject)
                },
                onWritePost: {
                  isWritingPost = true
                }
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
        .background(MoyeoTheme.background)
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
    .background(MoyeoTheme.background.ignoresSafeArea())
    .navigationDestination(item: $selectedPost) { post in
      FeedDetailView(post: post) {
        incrementCommentCount(for: post.id)
      }
    }
    .navigationDestination(item: $authorProfileRoute) { route in
      SupportDestinationView(route: route)
    }
    .navigationDestination(isPresented: $isWritingPost) {
      FeedWriteView(initialStep: feedWriteInitialStep) { post in
        publish(post)
      }
    }
    .onAppear {
      isBottomNavigationSuppressed = selectedPost != nil || isWritingPost
    }
    .onChange(of: selectedPost) { _, post in
      isBottomNavigationSuppressed = post != nil || isWritingPost
    }
    .onChange(of: isWritingPost) { _, isPresented in
      isBottomNavigationSuppressed = selectedPost != nil || isPresented
    }
    .onDisappear {
      if selectedPost == nil && !isWritingPost {
        isBottomNavigationSuppressed = false
      }
    }
    .task(id: segment) {
      guard MoyeoServerSync.isEnabled else { return }
      let tab = segment == .following ? "FRIENDS" : "DISCOVER"
      guard let page = try? await FeedAPIClient.shared.feeds(tab: tab) else { return }
      serverPosts = page.feeds.map(ServerFeedMapper.post(from:))
    }
    .accessibilityIdentifier("screen.feed")
  }

  private func publish(_ post: FeedPost) {
    feedPosts.removeAll { $0.id == post.id }
    feedPosts.insert(post, at: 0)
    onPublish(post)
    segment = .discover
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
  @State private var supportRoute: SupportRoute?
  /// 실서버 피드의 좋아요 토글 상태 (nil이면 서버 값 그대로)
  @State private var likeOverride: (liked: Bool, count: Int)?
  @State private var isSendingComment = false

  private var totalCommentCount: Int {
    post.commentCount + submittedComments.count
  }

  private var displayLikeCount: Int {
    likeOverride?.count ?? post.likeCount
  }

  private var displayLiked: Bool {
    likeOverride?.liked ?? post.serverLiked
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
            Button {
              supportRoute = .report
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

          Text(post.feedTitle)
            .font(.system(size: 20, weight: .heavy))
            .foregroundStyle(MoyeoTheme.ink)
            .lineSpacing(4)

          Text(post.feedSubtitle)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(MoyeoTheme.muted)
            .lineSpacing(3)

          ZStack(alignment: .topTrailing) {
            HStack(spacing: 2) {
              FeedPhotoPreview(post: post, height: 168)
              FeedRouteMap(route: post.route, mood: post.mood)
            }
            .frame(height: 168)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(post.photoCountText)
              .font(.caption2.weight(.heavy))
              .foregroundStyle(.white)
              .padding(.horizontal, 7)
              .padding(.vertical, 4)
              .background(.black.opacity(0.55))
              .clipShape(Capsule())
              .padding(8)
          }

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
              FeedMetricBox(title: "방문지", value: post.visitCountText)
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
            if post.isServerBacked {
              // 서버 댓글 목록 화면은 아직 연동 전 — 목데이터 댓글 화면으로 잘못 이동하지 않게 개수만 보여준다
              Text("댓글 \(totalCommentCount)개")
            } else {
              Button("댓글 \(totalCommentCount)개 모두 보기 →") {
                supportRoute = .feedComments(post.id)
              }
              .buttonStyle(.plain)
              .foregroundStyle(MoyeoTheme.forest)
              .accessibilityIdentifier("feed.comments.openAll")
            }
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
                submittedComments.append(trimmed)
                onCommentSubmitted()
                comment = ""
              } catch {
                optionMessage = (error as? LocalizedError)?.errorDescription
                  ?? "댓글을 등록하지 못했어요. 잠시 후 다시 시도해주세요."
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
    .alert(
      "피드 옵션",
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

  /// 실서버 피드 좋아요 토글 (POST /feeds/{id}/like)
  private func toggleServerLike() {
    guard let feedID = post.serverFeedID, MoyeoServerSync.isEnabled else { return }
    Task {
      do {
        try await FeedAPIClient.shared.toggleLike(feedID: feedID)
        let liked = !displayLiked
        likeOverride = (liked, max(displayLikeCount + (liked ? 1 : -1), 0))
      } catch {
        optionMessage = (error as? LocalizedError)?.errorDescription
          ?? "좋아요를 처리하지 못했어요. 잠시 후 다시 시도해주세요."
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
  let onOpenAuthor: () -> Void
  let onWritePost: () -> Void

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
            Image(systemName: "ellipsis")
              .foregroundStyle(MoyeoTheme.muted)
          }

          Text(post.feedTitle)
            .font(MoyeoTypography.font(size: 15, weight: .bold, relativeTo: .headline))
            .foregroundStyle(MoyeoTheme.ink)
            .lineLimit(1)
            .padding(.top, 12)
            .accessibilityIdentifier("feed.post.\(post.id).title")

          Text(post.feedSubtitle)
            .font(MoyeoTypography.font(size: 12, relativeTo: .caption))
            .foregroundStyle(MoyeoTheme.muted)
            .lineLimit(1)
            .padding(.top, 5)
            .accessibilityIdentifier("feed.post.\(post.id).subtitle")

          HStack(spacing: 2) {
            FeedPhotoPreview(post: post, height: feedTimelineMediaHeight)
            FeedRouteMap(route: post.route, mood: post.mood)
          }
          .frame(height: feedTimelineMediaHeight)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          .padding(.top, 12)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(post.feedTitle)
      .accessibilityIdentifier("feed.post.\(post.id)")

      HStack(spacing: 16) {
        Label("\(post.likeCount)", systemImage: "heart")
        Label("\(post.commentCount)", systemImage: "bubble.right")
          .accessibilityIdentifier("feed.post.\(post.id).comments")
        Spacer()
        Button {
          onWritePost()
        } label: {
          Image(systemName: "plus")
            .font(.caption.bold())
            .frame(width: 34, height: 34)
            .overlay {
              Circle()
                .stroke(MoyeoTheme.softLine, lineWidth: 1)
            }
        }
        .frame(width: 34, height: 34)
        .contentShape(Circle())
        .buttonStyle(.plain)
        .accessibilityLabel("피드 작성")
        .accessibilityIdentifier("feed.write.open")
      }
      .font(MoyeoTypography.font(size: 12, relativeTo: .caption))
      .foregroundStyle(MoyeoTheme.text700)
      .padding(.top, 12)
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
