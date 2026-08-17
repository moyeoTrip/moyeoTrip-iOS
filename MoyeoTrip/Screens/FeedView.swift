//
//  FeedView.swift
//  MoyeoTrip
//

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

private let feedTimelineMediaHeight: CGFloat = 150

struct FeedView: View {
  @Binding var feedPosts: [FeedPost]
  @Binding var isBottomNavigationSuppressed: Bool
  var onPublish: (FeedPost) -> Void = { _ in }
  @State private var segment: FeedSegment = .discover
  @State private var isWritingPost = false
  @State private var selectedPost: FeedPost?

  init(
    feedPosts: Binding<[FeedPost]>,
    isBottomNavigationSuppressed: Binding<Bool>,
    onPublish: @escaping (FeedPost) -> Void = { _ in },
    initialPostID: String? = nil,
    startsWritingPost: Bool = false
  ) {
    _feedPosts = feedPosts
    _isBottomNavigationSuppressed = isBottomNavigationSuppressed
    self.onPublish = onPublish
    _selectedPost = State(
      initialValue: MockData.feedPost(for: initialPostID, in: feedPosts.wrappedValue))
    _isWritingPost = State(initialValue: startsWritingPost)
  }

  private var filteredPosts: [FeedPost] {
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
                .font(MoyeoTypography.tab)
                .foregroundStyle(segment == item ? MoyeoTheme.ink : MoyeoTheme.muted)
            }
            .frame(width: 76, height: 50)
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
      .frame(height: 50)
      .background(MoyeoTheme.background)
      .overlay(alignment: .bottom) {
        Rectangle()
          .fill(MoyeoTheme.softLine)
          .frame(height: 1)
      }

      ScrollViewReader { proxy in
        ScrollView {
          VStack(spacing: 0) {
            ForEach(Array(filteredPosts.enumerated()), id: \.element.id) { index, post in
              FeedPostCard(
                post: post,
                onOpenPost: {
                  selectedPost = post
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
          }
          .padding(.horizontal, 16)
          .padding(.top, 10)
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
    .navigationDestination(isPresented: $isWritingPost) {
      FeedWriteView { post in
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

  private var totalCommentCount: Int {
    post.commentCount + submittedComments.count
  }

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          HStack(spacing: 12) {
            MascotAvatar(mascot: post.authorAvatar, size: 44, background: MoyeoTheme.leaf)
            VStack(alignment: .leading, spacing: 5) {
              Text(post.displayAuthorName)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(MoyeoTheme.ink)
              Text(post.createdAt)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MoyeoTheme.muted)
            }
            Spacer()
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

          FeedTagRow(tags: post.tags, identifierPrefix: "feed.detail.\(post.id)")

          Text("공개 범위 · \(post.visibility.rawValue)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(MoyeoTheme.muted)

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

          HStack(spacing: 8) {
            FeedMetricBox(title: "이동 거리", value: post.distanceText)
            FeedMetricBox(title: "소요 시간", value: post.durationText)
            FeedMetricBox(title: "방문지", value: post.visitCountText)
          }

          HStack(spacing: 18) {
            Text("좋아요 \(post.likeCount)개")
            Button("댓글 \(totalCommentCount)개 모두 보기") {
              supportRoute = .feedComments(post.id)
            }
            .buttonStyle(.plain)
            .foregroundStyle(MoyeoTheme.forest)
            .accessibilityIdentifier("feed.comments.openAll")
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
          guard !trimmed.isEmpty else { return }
          submittedComments.append(trimmed)
          onCommentSubmitted()
          comment = ""
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
}

private struct FeedPostCard: View {
  let post: FeedPost
  let onOpenPost: () -> Void
  let onWritePost: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Button(action: onOpenPost) {
        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 10) {
            MascotAvatar(mascot: post.authorAvatar, size: 38, background: MoyeoTheme.leaf)
            VStack(alignment: .leading, spacing: 3) {
              Text(post.displayAuthorName)
                .font(MoyeoTypography.cardTitle)
                .foregroundStyle(MoyeoTheme.ink)
                .accessibilityIdentifier("feed.post.\(post.id).author")
              Text(post.createdAt)
                .font(MoyeoTypography.cardMeta)
                .foregroundStyle(MoyeoTheme.muted)
                .accessibilityIdentifier("feed.post.\(post.id).createdAt")
            }
            Spacer()
            Image(systemName: "ellipsis")
              .foregroundStyle(MoyeoTheme.muted)
          }

          VStack(alignment: .leading, spacing: 6) {
            Text(post.feedTitle)
              .font(.system(size: 17, weight: .heavy))
              .foregroundStyle(MoyeoTheme.ink)
              .lineLimit(2)
              .lineSpacing(2)
              .minimumScaleFactor(0.88)
              .accessibilityIdentifier("feed.post.\(post.id).title")
            Text(post.feedSubtitle)
              .font(MoyeoTypography.cardBody)
              .foregroundStyle(MoyeoTheme.muted)
              .lineLimit(2)
              .lineSpacing(2)
              .accessibilityIdentifier("feed.post.\(post.id).subtitle")
          }

          FeedTagRow(tags: post.tags, identifierPrefix: "feed.post.\(post.id)")

          HStack(spacing: 2) {
            FeedPhotoPreview(post: post, height: feedTimelineMediaHeight)
            FeedRouteMap(route: post.route, mood: post.mood)
          }
          .frame(height: feedTimelineMediaHeight)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(post.feedTitle)
      .accessibilityIdentifier("feed.post.\(post.id)")

      HStack(spacing: 18) {
        Label("\(post.likeCount)", systemImage: "heart")
        Label("\(post.commentCount)", systemImage: "bubble.right")
          .accessibilityIdentifier("feed.post.\(post.id).comments")
        Spacer()
        Button {
          onWritePost()
        } label: {
          Image(systemName: "plus")
            .font(.caption.bold())
            .frame(width: 28, height: 28)
            .overlay {
              Circle()
                .stroke(MoyeoTheme.softLine, lineWidth: 1)
            }
        }
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .buttonStyle(.plain)
        .accessibilityLabel("피드 작성")
        .accessibilityIdentifier("feed.write.open")
      }
      .font(MoyeoTypography.cardBody)
      .foregroundStyle(MoyeoTheme.text700)
      .padding(.top, 2)
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

private struct FeedTagRow: View {
  let tags: [String]
  var identifierPrefix: String?

  var body: some View {
    HStack(spacing: 6) {
      ForEach(Array(tags.prefix(3).enumerated()), id: \.offset) { index, tag in
        Text(tag)
          .font(MoyeoTypography.chip)
          .foregroundStyle(MoyeoTheme.forest)
          .lineLimit(1)
          .minimumScaleFactor(0.78)
          .padding(.horizontal, 9)
          .padding(.vertical, 5)
          .background(MoyeoTheme.leaf)
          .clipShape(Capsule())
          .accessibilityIdentifier(tagIdentifier(index: index))
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(tags.prefix(3).joined(separator: ", "))
    .accessibilityIdentifier(identifierPrefix.map { "\($0).tags" } ?? "feed.tags")
  }

  private func tagIdentifier(index: Int) -> String {
    guard let identifierPrefix else {
      return "feed.tag.\(index)"
    }

    return "\(identifierPrefix).tag.\(index)"
  }
}
