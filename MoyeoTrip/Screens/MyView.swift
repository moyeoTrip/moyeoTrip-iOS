//
//  MyView.swift
//  MoyeoTrip
//

// swiftlint:disable file_length

import SwiftUI

struct MyView: View {
  /// 프로필·내 모임은 화면 밖 보관소에 있다 — 탭을 다녀와도 이미 받은 값을 즉시 그리고,
  /// 갱신은 뒤에서 조용히 한다 (TAB-STATE-CANON R1·R3).
  @ObservedObject var tabData: MoyeoTabDataStore
  @Binding var path: NavigationPath

  var tripContext = TripInteractionContext()
  var profile = ProfileSummary.empty
  var feedPosts: [FeedPost] = []
  var onAuthenticationRequired: () -> Void = {}
  // 26-1 — 찜은 **코스와 모집 두 가지**인데 탭이 코스뿐이었다 (정본 §6-2).
  private let segments = ["진행중", "지난여행", "찜한 코스", "찜한 모집"]
  private var activeTrips: [TripRecruitment] {
    tripContext.trips
  }

  /// 26 상단 3칸 지표의 근거 — `GET /users/{myId}/profile` 이 매너 점수 · 완료한 여행 수 ·
  /// 공개 피드 수를 준다. `GET /users/me/profile` 에는 그 셋이 없다.
  @State private var myMetrics: ServerPublicProfile?

  private var serverProfile: ServerMyProfile? {
    tabData.myProfile
  }

  private var serverRooms: [ServerMyChatRoom]? {
    tabData.myRooms
  }

  var body: some View {
    VStack(spacing: 0) {
      MyHeader {
        path.append(MyRoute.settings)
      }

      ScrollView {
        VStack(spacing: 10) {
          NavigationLink(value: MyRoute.profile(myProfileSubject, startsFlipped: false)) {
            MyProfileSummaryCard(profile: profile, serverProfile: serverProfile)
          }
          .buttonStyle(.plain)
          .accessibilityElement(children: .combine)
          .accessibilityLabel("프로필 메뉴")
          .accessibilityIdentifier("my.profileSummary")

          // 화면기획 26 의 3칸 지표 — `여행` `매너` `피드`.
          // 서버가 준 값만 칸을 만든다. 셋 다 없으면 줄 자체를 그리지 않는다 (R1).
          if let myMetrics, !MyProfileMetricStrip.metrics(from: myMetrics).isEmpty {
            MyProfileMetricStrip(profile: myMetrics)
          }

          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Text("내 여행")
                .font(MoyeoTypography.sectionTitle)
                .foregroundStyle(MoyeoTheme.ink)
              Spacer()
              Text("\(myTravelCount)개")
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.forest)
            }

            MySegmentBar(
              segments: segments,
              selectedSegment: $tabData.mySegment
            )

            MyTravelTabContent(
              selectedSegment: tabData.mySegment,
              activeTrips: activeTrips,
              serverRooms: serverRooms
            )
          }
          .padding(.top, 8)

          MyHubMenuPanel { route in
            path.append(route)
          }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 128)
      }
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .navigationDestination(for: TripRecruitment.self) { trip in
      TripDetailView(
        trip: trip,
        isApplied: tripContext.isApplied(trip),
        threadProvider: tripContext.chatThreadProvider,
        onApplied: tripContext.onApplyTrip,
        onSendChatMessage: tripContext.onSendChatMessage
      )
    }
    .navigationDestination(for: TravelCourse.self) { course in
      CourseDetailView(
        course: course,
        tripContext: tripContext
      )
    }
    .navigationDestination(for: MyRoute.self) { route in
      switch route {
      case .profile(let subject, let startsFlipped):
        ProfileCardView(subject: subject, startsFlipped: startsFlipped)
      case .profileEdit:
        ProfileEditView(profile: profile)
      case .profileTasteEdit:
        ProfileEditView(profile: profile, opensTasteEditor: true)
      case .myFeed:
        MyFeedListView(posts: feedPosts)
      case .friendDex:
        FriendDexView()
      case .settings:
        SettingsView(onAuthenticationRequired: onAuthenticationRequired)
      case .customerCenter:
        CustomerCenterView()
      case .friends:
        FriendsManagementView()
      }
    }
    .navigationDestination(for: SupportRoute.self) { route in
      SupportDestinationView(route: route, onAuthCompleted: onAuthenticationRequired)
    }
    // 마이도 재진입할 때마다 뒤에서 갱신한다 — 가진 값은 그대로 그린 채다 (R3).
    .task { await tabData.refreshMy() }
    .task { await loadMyMetrics() }
    .accessibilityIdentifier("screen.my")
  }

  /// 25 프로필 카드에 그릴 내 정보. `GET /users/me` 는 userID 를 주지 않아
  /// 받은 값(닉네임 · 이미지 · 소개 · 여행 스타일)만 넘긴다.
  private var myProfileSubject: ProfileCardSubject {
    guard let serverProfile else { return .unavailable }
    return .me(
      nickname: serverProfile.nickname,
      profileImageURL: MoyeoImageURL.resolve(serverProfile.profileImageUrl),
      introduction: serverProfile.introduction,
      travelStyles: serverProfile.travelStyles.map(\.label)
    )
  }

  /// 내 신원은 액세스 토큰에서 동기로 읽는다 (TAB-STATE-CANON R6).
  /// 못 받으면 지표 줄을 그리지 않는다 — 숫자를 지어내지 않는다.
  private func loadMyMetrics() async {
    guard myMetrics == nil, MoyeoServerSync.isEnabled, let userID = MoyeoCurrentUser.id else { return }
    myMetrics = try? await UserProfileAPIClient.shared.publicProfile(userID: userID)
  }

  /// 내 여행 개수 — 서버 목록을 받았으면 진행 중인 서버 방 개수를 쓴다
  private var myTravelCount: Int {
    guard let serverRooms else { return activeTrips.count }
    return serverRooms.filter { !$0.ended }.count
  }
}

private struct MyHeader: View {
  let openSettings: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Text("마이")
        .font(MoyeoTypography.screenTitle)
        .foregroundStyle(MoyeoTheme.ink)
      Spacer()
      Button(action: openSettings) {
        Label("설정", systemImage: "gearshape")
          .labelStyle(.iconOnly)
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(MoyeoTheme.ink)
          .frame(width: 38, height: 38)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("my.settings")
    }
    .frame(height: 56)
    .padding(.horizontal, 18)
    .background(MoyeoTheme.background)
  }
}

private struct MyProfileSummaryCard: View {
  let profile: ProfileSummary
  var serverProfile: ServerMyProfile?

  var body: some View {
    HStack(spacing: 12) {
      // `GET /users/me/profile` 이 준 이미지가 우선이다.
      // 세션 프로필에는 이미지가 없을 수 있어, 그것만 보고 이모지로 떨어지곤 했다 (R5 는 폴백일 때만).
      AuthenticatedProfileAvatar(
        profile: profile,
        size: 58,
        overrideImageURL: MoyeoImageURL.resolve(serverProfile?.profileImageUrl)
      )
      VStack(alignment: .leading, spacing: 4) {
        Text(serverProfile?.nickname ?? profile.name)
          .font(MoyeoTypography.cardTitle)
          .foregroundStyle(MoyeoTheme.ink)
          .lineLimit(1)
        // 자기소개는 서버 값이다. 없으면 그 줄을 만들지 않는다 — 문구를 지어내지 않는다.
        if let introduction = serverProfile?.introduction, !introduction.isEmpty {
          Text(introduction)
            .font(MoyeoTypography.cardBody)
            .foregroundStyle(MoyeoTheme.muted)
            .lineLimit(1)
        }
      }
      Spacer()
      Image(systemName: "chevron.right")
        .font(.caption.bold())
        .foregroundStyle(MoyeoTheme.text400)
    }
    .padding(12)
    .frame(minHeight: 94)
    .background(MoyeoTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
        .stroke(MoyeoTheme.softLine, lineWidth: 1)
    }
  }
}

private struct MyTravelTabContent: View {
  let selectedSegment: String
  let activeTrips: [TripRecruitment]
  /// 실서버 내 모임 목록 — 있으면 진행중·지난여행 탭을 서버 방으로 그린다
  var serverRooms: [ServerMyChatRoom]?

  var body: some View {
    if let serverRooms {
      serverContent(rooms: serverRooms)
    } else {
      sessionContent
    }
  }

  @ViewBuilder
  private func serverContent(rooms: [ServerMyChatRoom]) -> some View {
    let filtered = selectedSegment == "지난여행" ? rooms.filter(\.ended) : rooms.filter { !$0.ended }

    VStack(spacing: 10) {
      if selectedSegment == "찜한 모집" {
        // 26-1 찜한 모집 — `GET /chat-rooms/my/favorites`. 목록 화면을 그대로 끼워 넣는다.
        FavoriteRoomsSection()
      } else if selectedSegment == "찜한 코스" {
        // `GET /travel-courses/me/favorites` 는 실서버에 있다. 오래 "API 가 없다"고 적어 두어
        // 탭이 늘 비어 있었다 (NO-MOCK-CANON §4-1 — 내 오판이었다).
        FavoriteCoursesSection()
      } else if filtered.isEmpty {
        MoyeoEmptyStateView(
          message: MoyeoEmptyText.noChatRooms,
          accessibilityIdentifier: "my.serverTrip.empty"
        )
      } else {
        ForEach(filtered) { room in
          if room.ended {
            // 지난 여행은 서버가 코스 공개 가능 여부만 준다 — 이동할 상세가 없어 카드만 보여준다
            MyServerTripCard(room: room)
              .accessibilityIdentifier("my.serverTrip.\(room.roomId)")
          } else {
            NavigationLink(value: ServerTripMapper.placeholderTrip(roomID: room.roomId, title: room.title)) {
              MyServerTripCard(room: room)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("my.serverTrip.\(room.roomId)")
          }
        }
      }
    }
  }

  /// 서버 목록을 못 받았을 때. 이 세션에서 만들어진 모집만 남는다.
  @ViewBuilder
  private var sessionContent: some View {
    VStack(spacing: 10) {
      if selectedSegment == "진행중", !activeTrips.isEmpty {
        ForEach(activeTrips) { trip in
          NavigationLink(value: trip) {
            MyActiveTripCard(trip: trip)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("my.activeTrip.\(trip.id)")
        }
      } else {
        MoyeoEmptyStateView(
          message: MoyeoEmptyText.noChatRooms,
          accessibilityIdentifier: "my.trip.empty"
        )
      }
    }
  }
}

/// 화면기획 26 — 실서버 내 여행 카드. 서버가 주지 않는 값(지역·마스코트·참가자 얼굴)은 그리지 않는다.
private struct MyServerTripCard: View {
  let room: ServerMyChatRoom

  var body: some View {
    HStack(spacing: MyTravelCardMetrics.gap) {
      Group {
        if let thumbnailURL = room.thumbnailURL {
          CachedRemoteImage(url: thumbnailURL, fallbackShape: .square) { image in
            image
              .resizable()
              .scaledToFill()
          } placeholder: {
            MoyeoTheme.leaf
          }
        } else {
          // 서버가 썸네일을 주지 않은 여행 — 빈 판 대신 마스코트를 채운다
          MoyeoPlaceholderImageView(shape: .square)
        }
      }
      .frame(width: MyTravelCardMetrics.thumbWidth, height: MyTravelCardMetrics.thumbHeight)
      .clipShape(RoundedRectangle(cornerRadius: MyTravelCardMetrics.thumbRadius, style: .continuous))

      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .top, spacing: 8) {
          Text(room.title)
            .font(MyTravelCardMetrics.titleFont)
            .foregroundStyle(MoyeoTheme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .accessibilityIdentifier("my.serverTrip.\(room.roomId).title")
          Spacer(minLength: 4)
          if !room.ended, let dDay = room.recruitmentDDay {
            Pill(text: dDay <= 0 ? "D-Day" : "D-\(dDay)", tint: MoyeoTheme.coral)
          }
        }

        Text(ServerTripMapper.scheduleText(startDate: room.startDate, endDate: room.endDate))
          .font(MyTravelCardMetrics.metaFont)
          .foregroundStyle(MoyeoTheme.muted)
          .lineLimit(1)
          .accessibilityIdentifier("my.serverTrip.\(room.roomId).date")

        Text(ServerTripMapper.statusText(for: room))
          .font(MyTravelCardMetrics.subtitleFont)
          .foregroundStyle(MoyeoTheme.muted)
          .lineLimit(1)
          .accessibilityIdentifier("my.serverTrip.\(room.roomId).status")

        if let participantCount = room.participantCount, let maxParticipants = room.maxParticipants,
           maxParticipants > 0 {
          HStack(spacing: 8) {
            ProgressBar(
              value: min(Double(participantCount) / Double(maxParticipants), 1),
              tint: MoyeoTheme.forest
            )
            Text("\(participantCount)/\(maxParticipants)명")
              .font(.caption2.weight(.bold))
              .foregroundStyle(MoyeoTheme.text700)
              .accessibilityIdentifier("my.serverTrip.\(room.roomId).people")
          }
          .padding(.top, 1)
        }
      }
    }
    .padding(12)
    .frame(height: MyTravelCardMetrics.activeHeight)
    .moyeoListCard()
  }
}

private struct MyHubMenuPanel: View {
  let openRoute: (MyRoute) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("메뉴")
        .font(.system(size: 18, weight: .heavy))
        .foregroundStyle(MoyeoTheme.ink)
      VStack(spacing: 0) {
        Button {
          openRoute(.myFeed)
        } label: {
          MyHubMenuRow(title: "내 피드", subtitle: "내가 기록한 경북 여행")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("my.feedShortcut")
        Divider().padding(.leading, 16)
        Button {
          openRoute(.friendDex)
        } label: {
          // 도감 마릿수는 도감 화면이 서버에서 받는다 — 메뉴 줄에서 숫자를 지어내지 않는다
          MyHubMenuRow(title: "친구 도감", subtitle: "최근 동행 순")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("my.friendDexShortcut")
        Divider().padding(.leading, 16)
        // changeLog18 — 25 가 프로필 카드로 바뀌면서 관리 진입점이 여기로 왔다.
        // 옮기지 않으면 28 프로필 수정이 어디서도 열리지 않는다.
        Button {
          openRoute(.profileEdit)
        } label: {
          MyHubMenuRow(title: "내 정보 수정", subtitle: "프로필과 여행 취향을 관리해요")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("my.profileEditShortcut")
        Divider().padding(.leading, 16)
        Button {
          openRoute(.friends)
        } label: {
          MyHubMenuRow(title: "친구 관리", subtitle: "친구 신청과 수락을 관리해요")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("my.friendsShortcut")
        Divider().padding(.leading, 16)
        Button {
          openRoute(.customerCenter)
        } label: {
          // 신고 내역 화면은 없다 — 갈 수 있는 두 창구를 그대로 적는다 (정본 REPORT-CANON §1).
          MyHubMenuRow(title: "고객센터", subtitle: "GitHub 이슈 · 이메일로 문의해요")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("my.customerCenterShortcut")
      }
      .background(MoyeoTheme.card)
      .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
          .stroke(MoyeoTheme.softLine, lineWidth: 1)
      }
    }
  }
}

private struct MyFeedListView: View {
  let posts: [FeedPost]
  @State private var selectedPost: FeedPost?

  var body: some View {
    VStack(spacing: 0) {
      CompactDetailHeader(title: "내 피드") {
        Text("\(posts.count)")
          .font(.caption.weight(.heavy))
          .foregroundStyle(MoyeoTheme.forest)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(MoyeoTheme.leaf)
          .clipShape(Capsule())
      }

      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          VStack(alignment: .leading, spacing: 5) {
            Text("내가 남긴 경북 여행 기록")
              .font(.system(size: 19, weight: .heavy))
              .foregroundStyle(MoyeoTheme.ink)
            Text("사진, 경로, 함께 간 친구가 남아 있는 피드를 모아봐요.")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(MoyeoTheme.muted)
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          // 0건이면 소개 문구 아래가 그냥 비어 있었다 — 무엇을 하면 채워지는지 알려준다.
          if posts.isEmpty {
            MoyeoEmptyStateView(
              message: MoyeoEmptyText.noMyFeeds,
              systemImage: "square.and.pencil",
              accessibilityIdentifier: "myFeed.empty"
            )
            .padding(.top, 24)
          } else {
            ForEach(posts) { post in
              MyFeedPostCard(post: post) {
                selectedPost = post
              }
            }
          }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 34)
      }
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
    .navigationDestination(item: $selectedPost) { post in
      FeedDetailView(post: post)
    }
    .accessibilityIdentifier("screen.myFeed")
  }
}

private struct MyFeedPostCard: View {
  let post: FeedPost
  let onOpen: () -> Void

  var body: some View {
    Button(action: onOpen) {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 10) {
          // 피드 카드와 같은 컴포넌트다 — 프로필 이미지가 있으면 이미지를 그리고,
          // 없을 때만 마스코트로 떨어진다. 여기만 마스코트를 고정하면 같은 사람이 화면마다 달라진다.
          FeedAuthorAvatar(post: post, size: 38)
          VStack(alignment: .leading, spacing: 3) {
            Text(post.displayAuthorName)
              .font(.system(size: 16, weight: .heavy))
              .foregroundStyle(MoyeoTheme.ink)
            Text("\(post.region) · \(post.createdAt) · \(post.visibility.rawValue)")
              .font(.caption.weight(.semibold))
              .foregroundStyle(MoyeoTheme.muted)
          }
          Spacer()
          Image(systemName: "chevron.right")
            .font(.caption.bold())
            .foregroundStyle(MoyeoTheme.text400)
        }

        // 피드 경로에는 좌표가 없다 — 손으로 그린 경로 지도를 옆에 두지 않는다 (R4)
        FeedPhotoPreview(post: post, height: 118)
        .frame(height: 118)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

        VStack(alignment: .leading, spacing: 7) {
          Text(post.feedTitle)
            .font(.system(size: 16, weight: .heavy))
            .foregroundStyle(MoyeoTheme.ink)
            .lineLimit(2)
          Text(post.detailBodyText)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(MoyeoTheme.text700)
            .lineLimit(2)
        }

        MyFeedTagRow(tags: post.tags)

        HStack(spacing: 16) {
          Label("\(post.likeCount)", systemImage: "heart")
          Label("\(post.commentCount)", systemImage: "bubble.right")
          Spacer()
          Text(post.photoCountText)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(MoyeoTheme.muted)
      }
      .padding(13)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(MoyeoTheme.card)
      .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
          .stroke(MoyeoTheme.softLine, lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(post.feedTitle)
    .accessibilityIdentifier("my.feedPost.\(post.id)")
  }
}

private struct MyFeedTagRow: View {
  let tags: [String]

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6) {
        ForEach(tags, id: \.self) { tag in
          Text("#\(tag)")
            .font(.caption.weight(.heavy))
            .foregroundStyle(MoyeoTheme.forest)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(MoyeoTheme.leaf)
            .clipShape(Capsule())
        }
      }
    }
  }
}

private struct ProfileEditView: View {
  let profile: ProfileSummary
  @State private var displayName: String
  @State private var bio: String
  @State private var selectedTravelStyles: Set<Int64>
  @State private var selectedInterestRegions: Set<Int64>
  @State private var isTasteEditorPresented: Bool
  @State private var saveMessage: String?
  /// 28-1 의 세 줄(자기소개·생년월일·성별)을 실제로 고치는 시트. 예전에는 화살표만 있었다.
  @State private var editingField: ProfileEditField?
  /// 서버 값에서 시작해 시트에서 바뀌는 값 — 저장은 PUT users/me/profile 한 번이다.
  @State private var birthDate = ""
  @State private var gender = ""
  @State private var bioDraft = ""
  /// 실서버 프로필·취향 후보 — 로그인 세션이 있을 때만 채워진다
  @State private var serverProfile: ServerMyProfile?
  @State private var serverOptions: ServerProfileOptions?
  /// 후보는 `GET users/me/profile/options` 가 정본이다 (정본 R5).
  /// 06-1 가입 단계도 2026-08-30 부터 같은 API 를 쓴다 — 클라에 거울 표를 두지 않는다.
  @State private var styleOptions: [TravelTasteOption] = []
  @State private var regionOptions: [TravelTasteOption] = []

  init(profile: ProfileSummary, opensTasteEditor: Bool = false) {
    self.profile = profile
    // 닉네임·자기소개는 서버 프로필이 채운다. 별도 "비공개 닉네임" 같은 값은 없다.
    _displayName = State(initialValue: profile.name)
    _bio = State(initialValue: "")
    // 서버 프로필이 채운다. 기본값을 넣어두면 서버 값이 오기 전까지 사용자가 고르지 않은
    // 취향이 본인 것처럼 보인다.
    _selectedTravelStyles = State(initialValue: [])
    _selectedInterestRegions = State(initialValue: [])
    _isTasteEditorPresented = State(initialValue: opensTasteEditor)
  }

  var body: some View {
    VStack(spacing: 0) {
      CompactDetailHeader(title: "프로필 수정") {
        Button {
          if serverProfile != nil {
            saveProfileToServer()
          } else {
            saveMessage = "프로필 변경사항이 저장됐어요."
          }
        } label: {
          Text("저장")
            .font(.caption.weight(.heavy))
            .foregroundStyle(MoyeoTheme.forest)
            .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("저장")
        .accessibilityIdentifier("profile.edit.save")
      }

      // 화면기획 구조: 중앙 아바타(고정 배지) → 공개 프로필 그룹 → 비공개 정보 그룹.
      // 항목마다 카드를 두면 무엇이 공개/비공개인지 묶음이 읽히지 않는다.
      ScrollView {
        VStack(spacing: 0) {
          VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
              // 아바타는 닉네임에서 계산한다 (R5). `emojiOverride` 를 주면 서버 프로필
              // 이미지까지 무시되므로 여기서는 주지 않는다.
              AuthenticatedProfileAvatar(profile: profile, size: 96)
              Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(MoyeoTheme.muted)
                .frame(width: 26, height: 26)
                .background(MoyeoTheme.subtleBackground)
                .clipShape(Circle())
                .overlay(Circle().stroke(MoyeoTheme.line))
            }
            Text(displayName)
              .font(.title3.weight(.heavy))
              .foregroundStyle(MoyeoTheme.ink)
            Text("한 번 정한 친구는 바꿀 수 없어요")
              .font(.caption)
              .foregroundStyle(MoyeoTheme.muted)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 24)

          ProfileEditGroupHeader("공개 프로필")
          ProfileEditListRow(
            label: "자기소개",
            value: bio.isEmpty ? "아직 없어요" : bio,
            action: { bioDraft = bio; editingField = .introduction }
          )
          ProfileTravelTasteBlock(
            travelStyleIDs: selectedTravelStyles,
            interestRegionIDs: selectedInterestRegions,
            styleOptions: styleOptions,
            regionOptions: regionOptions
          ) {
            isTasteEditorPresented = true
          }

          ProfileEditGroupHeader("비공개 정보")
          // 닉네임과 캐릭터는 선택 후 바꿀 수 없다 — 잠금 표시로 알린다
          ProfileEditListRow(label: "닉네임", value: displayName, locked: true)
          ProfileEditListRow(label: "캐릭터", value: "고정됨", locked: true)
          // 서버 프로필이 없으면(미로그인·응답 실패) 고칠 값도 없다 — 목 생년월일·성별을
          // 채우지 않고 줄 자체를 그리지 않는다 (NO-MOCK-CANON R1).
          if serverProfile != nil {
            ProfileEditListRow(
              label: "생년월일",
              value: birthDate.isEmpty ? "등록 안 됨" : birthDate.replacingOccurrences(of: "-", with: "."),
              action: { editingField = .birthDate }
            )
            ProfileEditListRow(
              label: "성별",
              value: ServerMyProfile.genderText(for: gender),
              action: { editingField = .gender }
            )
          }

          Text("비공개 정보는 다른 여행자에게 보이지 않아요.")
            .font(.caption2)
            .foregroundStyle(MoyeoTheme.text400)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .padding(.bottom, 40)
      }
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
    .accessibilityIdentifier("screen.profileEdit")
    .task {
      await loadServerProfile()
    }
    .sheet(isPresented: $isTasteEditorPresented) {
      ProfileTravelTasteEditSheet(
        travelStyles: $selectedTravelStyles,
        interestRegions: $selectedInterestRegions,
        styleOptions: styleOptions,
        regionOptions: regionOptions,
        onSave: serverProfile != nil ? { saveProfileToServer() } : nil
      )
      .presentationDetents([.height(720)])
      .presentationDragIndicator(.hidden)
      .presentationCornerRadius(24)
      .presentationBackground(MoyeoTheme.card)
    }
    .sheet(item: $editingField) { field in
      ProfileEditFieldSheet(
        field: field,
        introduction: $bioDraft,
        birthDate: $birthDate,
        gender: $gender,
        onSave: {
          if field == .introduction { bio = bioDraft }
          editingField = nil
          saveProfileToServer()
        },
        onCancel: { editingField = nil }
      )
      .presentationDetents([.height(field == .birthDate ? 480 : 360)])
      .presentationCornerRadius(24)
      .presentationBackground(MoyeoTheme.card)
    }
    .alert(
      "저장 완료",
      isPresented: Binding<Bool>(
        get: { saveMessage != nil },
        set: { isPresented in
          if !isPresented {
            saveMessage = nil
          }
        }
      )
    ) {
      Button("확인") {
        saveMessage = nil
      }
    } message: {
      Text(saveMessage ?? "")
    }
  }

  /// 서버 프로필과 취향 후보(options)를 불러와 화면 상태를 서버 값으로 바꾼다.
  /// 서버 후보가 기획 옵션과 다르면 서버 값을 쓴다.
  private func loadServerProfile() async {
    guard MoyeoServerSync.isEnabled, serverProfile == nil else { return }
    guard let loaded = try? await UserProfileAPIClient.shared.myProfile() else { return }
    serverProfile = loaded
    displayName = loaded.nickname
    bio = loaded.introduction ?? ""
    birthDate = loaded.birthDate ?? ""
    gender = loaded.gender
    selectedTravelStyles = Set(loaded.travelStyles.map(\.id))
    selectedInterestRegions = Set(loaded.interestedRegions.map(\.id))

    if let options = try? await UserProfileAPIClient.shared.profileOptions() {
      serverOptions = options
      styleOptions = options.travelStyles.map { TravelTasteOption(id: $0.id, label: $0.label) }
      regionOptions = options.interestedRegions.map { TravelTasteOption(id: $0.id, label: $0.signguName) }
    }
  }

  /// 현재 선택을 PUT users/me/profile 로 저장한다 (여행 취향 시트 저장 포함)
  private func saveProfileToServer() {
    guard let serverProfile, let serverOptions else {
      saveMessage = "서버 프로필을 불러오지 못해 저장할 수 없어요."
      return
    }
    // 서버는 생년월일을 반드시 요구한다 — 아직 등록되지 않았으면 그 줄부터 채우게 안내한다.
    guard !birthDate.isEmpty else {
      saveMessage = "생년월일이 등록되지 않아 저장할 수 없어요."
      return
    }
    // 서버 후보에 실제로 있는 id 만 보낸다 — 없는 id 는 `40015`·`40014` 로 저장이 막힌다.
    let styleIDs = serverOptions.travelStyles
      .map(\.id)
      .filter(selectedTravelStyles.contains)
    let regionIDs = serverOptions.interestedRegions
      .map(\.id)
      .filter(selectedInterestRegions.contains)
    let update = ServerProfileUpdate(
      introduction: bio.isEmpty ? nil : bio,
      travelStyleIds: styleIDs,
      interestedRegionIds: regionIDs,
      birthDate: birthDate,
      gender: gender.isEmpty ? serverProfile.gender : gender
    )
    Task {
      do {
        let updated = try await UserProfileAPIClient.shared.updateProfile(update)
        self.serverProfile = updated
        selectedTravelStyles = Set(updated.travelStyles.map(\.id))
        selectedInterestRegions = Set(updated.interestedRegions.map(\.id))
        // 저장 뒤 화면은 **서버가 돌려준 값**으로 다시 맞춘다 — 시트에서 고른 값을 그대로 두면
        // 서버가 거른 값이 저장된 것처럼 남는다.
        bio = updated.introduction ?? ""
        birthDate = updated.birthDate ?? ""
        gender = updated.gender
        saveMessage = "프로필 변경사항이 저장됐어요."
      } catch {
        saveMessage = (error as? LocalizedError)?.errorDescription
          ?? "저장하지 못했어요. 잠시 후 다시 시도해주세요."
      }
    }
  }
}

private struct ProfileTravelTasteBlock: View {
  let travelStyleIDs: Set<Int64>
  let interestRegionIDs: Set<Int64>
  /// 서버 후보 그대로. 아직 도착하지 않았으면 비어 있고, 그때는 칩을 그리지 않는다 (정본 R5).
  let styleOptions: [TravelTasteOption]
  let regionOptions: [TravelTasteOption]
  let action: () -> Void

  private var orderedTravelStyles: [String] {
    styleOptions.filter { travelStyleIDs.contains($0.id) }.map(\.label)
  }

  private var orderedInterestRegions: [String] {
    regionOptions.filter { interestRegionIDs.contains($0.id) }.map(\.label)
  }

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 8) {
          Text("여행 취향")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(MoyeoTheme.ink)
          Spacer(minLength: 8)
          Text("탭해서 바로 수정")
            .font(.caption.weight(.semibold))
            .foregroundStyle(MoyeoTheme.brandText)
          Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(MoyeoTheme.text400)
        }

        ProfileTravelTastePreviewLine(title: "여행 스타일", items: orderedTravelStyles)
        ProfileTravelTastePreviewLine(title: "관심 지역", items: orderedInterestRegions)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(MoyeoTheme.background)
      .contentShape(Rectangle())
      .overlay(alignment: .bottom) {
        Rectangle()
          .fill(MoyeoTheme.softLine)
          .frame(maxWidth: .infinity)
          .frame(height: 1)
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("여행 취향 편집")
    .accessibilityIdentifier("profile.edit.travelTaste")
  }
}

private struct ProfileTravelTastePreviewLine: View {
  let title: String
  let items: [String]

  var body: some View {
    HStack(spacing: 6) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(MoyeoTheme.muted)
        .frame(width: 58, alignment: .leading)
      ForEach(items, id: \.self) { item in
        Text(item)
          .font(.caption.weight(.heavy))
          .foregroundStyle(MoyeoTheme.brandText)
          .padding(.horizontal, 9)
          .frame(height: 27)
          .background(MoyeoTheme.selectionSurface)
          .clipShape(Capsule())
          .overlay {
            Capsule().stroke(MoyeoTheme.forest.opacity(0.7), lineWidth: 1)
          }
      }
      Text("+ 추가")
        .font(.caption.weight(.heavy))
        .foregroundStyle(MoyeoTheme.muted)
        .padding(.horizontal, 9)
        .frame(height: 27)
        .background(MoyeoTheme.subtleBackground)
        .clipShape(Capsule())
        .overlay {
          Capsule().stroke(MoyeoTheme.line, lineWidth: 1)
        }
      Spacer(minLength: 0)
    }
  }
}

private struct ProfileTravelTasteEditSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Binding private var travelStyles: Set<Int64>
  @Binding private var interestRegions: Set<Int64>
  @State private var draftTravelStyles: Set<Int64>
  @State private var draftInterestRegions: Set<Int64>
  /// 후보 목록 — `GET users/me/profile/options` 응답만 쓴다 (정본 R5).
  private let styleOptions: [TravelTasteOption]
  private let regionOptions: [TravelTasteOption]
  /// 서버 연동 시 저장 직후 PUT users/me/profile 호출
  private let onSave: (() -> Void)?

  init(
    travelStyles: Binding<Set<Int64>>,
    interestRegions: Binding<Set<Int64>>,
    styleOptions: [TravelTasteOption],
    regionOptions: [TravelTasteOption],
    onSave: (() -> Void)? = nil
  ) {
    _travelStyles = travelStyles
    _interestRegions = interestRegions
    _draftTravelStyles = State(initialValue: travelStyles.wrappedValue)
    _draftInterestRegions = State(initialValue: interestRegions.wrappedValue)
    self.styleOptions = styleOptions
    self.regionOptions = regionOptions
    self.onSave = onSave
  }

  private var canSave: Bool {
    TravelTasteSelection.isComplete(
      styles: draftTravelStyles,
      interestRegions: draftInterestRegions
    )
  }

  /// 서버 프로필이 시트를 띄운 **뒤에** 도착할 수 있다. 그때 초안이 옛 값에 머물면
  /// 칩은 꺼져 있는데 하단 개수만 옛 숫자를 세는 상태가 된다(실제로 그렇게 찍혔다).
  private func syncDraftFromBindings() {
    draftTravelStyles = travelStyles
    draftInterestRegions = interestRegions
  }

  var body: some View {
    VStack(spacing: 0) {
      Capsule()
        .fill(MoyeoTheme.line)
        .frame(width: 36, height: 4)
        .padding(.top, 10)
        .padding(.bottom, 18)

      VStack(alignment: .leading, spacing: 5) {
        Text("여행 취향 편집")
          .font(MoyeoTypography.screenTitle)
          .foregroundStyle(MoyeoTheme.ink)
        Text("여행 스타일과 관심 지역은 함께 저장돼요.")
          .font(MoyeoTypography.cardMeta)
          .foregroundStyle(MoyeoTheme.muted)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 20)
      .padding(.bottom, 18)

      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          TravelTasteOptionSection(
            title: "여행 스타일",
            requirementHint: "1개 이상",
            options: styleOptions,
            selectedItems: $draftTravelStyles,
            accessibilityPrefix: "profile.taste.style"
          )
          TravelTasteOptionSection(
            title: "관심 지역",
            requirementHint: "경북 안에서 1곳 이상",
            options: regionOptions,
            selectedItems: $draftInterestRegions,
            accessibilityPrefix: "profile.taste.region"
          )
          TravelTasteSelectionSummary(
            styleCount: draftTravelStyles.count,
            regionCount: draftInterestRegions.count,
            accessibilityIdentifier: "profile.taste.summary"
          )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
      }
      .safeAreaInset(edge: .bottom) {
        HStack(spacing: 10) {
          Button("취소") { dismiss() }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(MoyeoTheme.ink)
            .frame(width: 72, height: 52)
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.taste.cancel")

          AuthPrimaryButton(title: "저장", accessibilityIdentifier: "profile.taste.save") {
            travelStyles = draftTravelStyles
            interestRegions = draftInterestRegions
            onSave?()
            dismiss()
          }
          .disabled(!canSave)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(MoyeoTheme.card)
      }
    }
    .accessibilityIdentifier("screen.profileTasteEdit")
    .onAppear(perform: syncDraftFromBindings)
    .onChange(of: travelStyles) { _, _ in syncDraftFromBindings() }
    .onChange(of: interestRegions) { _, _ in syncDraftFromBindings() }
  }
}

private struct ProfileEditFieldCard<Content: View>: View {
  let title: String
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(.subheadline.weight(.heavy))
        .foregroundStyle(MoyeoTheme.ink)
      content()
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(MoyeoTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
        .stroke(MoyeoTheme.softLine, lineWidth: 1)
    }
  }
}

private struct ProfileEditChipGrid: View {
  let items: [String]
  @Binding var selectedItems: Set<String>

  var body: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
      ForEach(items, id: \.self) { item in
        Button {
          if selectedItems.contains(item) {
            selectedItems.remove(item)
          } else {
            selectedItems.insert(item)
          }
        } label: {
          Text(item)
            .font(.caption.weight(.heavy))
            .foregroundStyle(selectedItems.contains(item) ? .white : MoyeoTheme.forest)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(selectedItems.contains(item) ? MoyeoTheme.forest : MoyeoTheme.leaf)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profile.edit.region.\(item)")
      }
    }
  }
}

private struct CustomerCenterView: View {
  var body: some View {
    VStack(spacing: 0) {
      CompactDetailHeader(title: "고객센터") {
        Image(systemName: "questionmark.bubble.fill")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(MoyeoTheme.forest)
      }

      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          // 예전에는 동작 없는 행 셋(`문의 접수`·`신고 내역`·`자주 묻는 질문`)에
          // 근거 없는 배지(`평균 2시간`·`0건`·`FAQ`)를 달아 뒀다. 눌러도 아무 일이 없었고,
          // 상담함·평균 응답시간은 존재하지 않는 개념이다(정본 `changeLog14`).
          // 실제로 갈 수 있는 두 창구만 남긴다 — 웹·안드로이드와 같은 값이다.
          CustomerCenterStatusCard()
          CustomerCenterLinkRow(
            title: MoyeoContact.issuesLabel,
            subtitle: "버그 제보와 기능 제안을 올려요",
            url: MoyeoContact.issuesURL,
            identifier: "customerCenter.issues"
          )
          CustomerCenterLinkRow(
            title: MoyeoContact.emailLabel,
            subtitle: MoyeoContact.email,
            url: MoyeoContact.mailtoURL,
            identifier: "customerCenter.email"
          )
        }
        .padding(18)
        .padding(.bottom, 44)
      }
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
    .accessibilityIdentifier("screen.customerCenter")
  }
}

private struct CustomerCenterStatusCard: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("오늘도 도와드릴게요")
        .font(.headline.weight(.heavy))
        .foregroundStyle(MoyeoTheme.ink)
      // 상담함·접수 개념은 없다 — 실제로 열리는 두 창구를 그대로 설명한다.
      Text(MoyeoContact.dialogBody)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(MoyeoTheme.muted)
        .lineSpacing(5)
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(MoyeoTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
        .stroke(MoyeoTheme.softLine, lineWidth: 1)
    }
  }
}

/// 실제로 여는 링크 행. 눌러도 아무 일이 없는 행을 두지 않는다.
private struct CustomerCenterLinkRow: View {
  let title: String
  let subtitle: String
  let url: URL
  let identifier: String

  @Environment(\.openURL) private var openURL

  var body: some View {
    Button {
      openURL(url)
    } label: {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 5) {
          Text(title)
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(MoyeoTheme.ink)
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(MoyeoTheme.muted)
        }
        Spacer(minLength: 8)
        Image(systemName: "arrow.up.right")
          .font(.caption.weight(.bold))
          .foregroundStyle(MoyeoTheme.muted)
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(MoyeoTheme.card)
      .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
          .stroke(MoyeoTheme.softLine, lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(identifier)
  }
}

private struct CustomerCenterActionRow: View {
  let title: String
  let subtitle: String
  let badge: String

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 5) {
        Text(title)
          .font(.subheadline.weight(.heavy))
          .foregroundStyle(MoyeoTheme.ink)
        Text(subtitle)
          .font(.caption.weight(.semibold))
          .foregroundStyle(MoyeoTheme.muted)
          .lineLimit(2)
      }
      Spacer()
      Text(badge)
        .font(.caption.weight(.heavy))
        .foregroundStyle(MoyeoTheme.forest)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(MoyeoTheme.leaf)
        .clipShape(Capsule())
    }
    .padding(16)
    .background(MoyeoTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(MoyeoTheme.softLine, lineWidth: 1)
    }
  }
}

private struct MyHubMenuRow: View {
  let title: String
  let subtitle: String

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.subheadline.weight(.heavy))
          .foregroundStyle(MoyeoTheme.ink)
        Text(subtitle)
          .font(.caption.weight(.semibold))
          .foregroundStyle(MoyeoTheme.muted)
          .lineLimit(1)
      }
      Spacer()
      Image(systemName: "chevron.right")
        .font(.caption.bold())
        .foregroundStyle(MoyeoTheme.text400)
    }
    .frame(height: 58)
    .padding(.horizontal, 16)
    .contentShape(Rectangle())
  }
}

private struct MySegmentBar: View {
  let segments: [String]
  @Binding var selectedSegment: String

  var body: some View {
    HStack(spacing: 4) {
      ForEach(segments, id: \.self) { segment in
        Button {
          selectedSegment = segment
        } label: {
          Text(segment)
            .font(MoyeoTypography.tab)
            .foregroundStyle(selectedSegment == segment ? MoyeoTheme.forest : MoyeoTheme.muted)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(selectedSegment == segment ? MoyeoTheme.card : .clear)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
      }
    }
    .padding(4)
    .background(MoyeoTheme.subtleBackground)
    .clipShape(Capsule())
  }
}

private struct CompactDetailHeader<Trailing: View>: View {
  @Environment(\.dismiss) private var dismiss
  let title: String
  @ViewBuilder var trailing: () -> Trailing

  var body: some View {
    HStack {
      Button {
        dismiss()
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(MoyeoTheme.ink)
          .frame(width: 34, height: 34)
      }
      .buttonStyle(.plain)

      Spacer()

      Text(title)
        .font(.subheadline.weight(.heavy))
        .foregroundStyle(MoyeoTheme.ink)

      Spacer()

      trailing()
        .frame(width: 34, height: 34)
    }
    .frame(height: 50)
    .padding(.horizontal, 10)
    .background(MoyeoTheme.background)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(MoyeoTheme.softLine)
        .frame(height: 1)
    }
  }
}

private struct FriendDexView: View {
  private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
  @State private var isSearching = false
  @State private var query = ""
  @State private var selectedFilter: DogamFriendFilter = .all
  /// 실서버 여행 도감 — 도감 API가 성공했을 때만 채워진다 (nil = 아직 못 받음)
  @State private var serverDex: ServerTravelDex?

  /// 한 줄 메시지를 아직 안 남긴 친구 수와, 그중 가장 최근 여행 이름.
  /// 대상이 없으면 `nil` — 안내 카드를 아예 그리지 않는다.
  private var emptyBackNotice: (count: Int, tripTitle: String)? {
    guard let serverDex else { return nil }
    let pending = serverDex.companions.filter { companion in
      companion.memories.contains { ($0.oneLineReview ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    guard !pending.isEmpty else { return nil }
    let latest = pending
      .flatMap(\.memories)
      .filter { ($0.oneLineReview ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      .max { $0.tripDate < $1.tripDate }
    guard let tripTitle = latest?.tripTitle else { return nil }
    return (pending.count, tripTitle)
  }

  private var filteredServerCompanions: [ServerTravelDexCompanion]? {
    guard let serverDex else { return nil }
    return serverDex.companions
      .filter { selectedFilter.includesServer($0) }
      .filter { companion in
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedQuery.isEmpty
          || companion.nickname.localizedCaseInsensitiveContains(trimmedQuery)
      }
  }

  private var visibleFriendCount: Int {
    filteredServerCompanions?.count ?? 0
  }

  var body: some View {
    VStack(spacing: 0) {
      CompactDetailHeader(title: "친구 도감") {
        Button {
          withAnimation(.easeInOut(duration: 0.16)) {
            isSearching.toggle()
          }
        } label: {
          Label(
            isSearching ? "검색 닫기" : "검색", systemImage: isSearching ? "xmark" : "magnifyingglass"
          )
          .labelStyle(.iconOnly)
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(MoyeoTheme.ink)
          .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isSearching ? "검색 닫기" : "검색")
        .accessibilityIdentifier("friendDex.searchToggle")
      }

      ScrollViewReader { proxy in
        ScrollView {
          VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
              VStack(alignment: .leading, spacing: 4) {
                Text("지금까지 만난 친구")
                  .font(.caption2)
                  .foregroundStyle(MoyeoTheme.muted)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                  Text("\(visibleFriendCount)")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(MoyeoTheme.forest)
                  Text("마리")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MoyeoTheme.muted)
                }
              }
              Spacer()
              Text(query.isEmpty ? selectedFilter.summary : "검색 결과")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(MoyeoTheme.muted)
            }

            if isSearching {
              DogamSearchField(query: $query)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 6) {
              ForEach(DogamFriendFilter.allCases) { filter in
                DogamFilterChip(
                  title: serverDex == nil
                    ? filter.title
                    : filter.serverTitle(companions: serverDex?.companions ?? []),
                  selected: selectedFilter == filter
                ) {
                  selectedFilter = filter
                }
              }
            }

            // 여행이 끝났는데 한 줄 메시지를 안 남긴 친구가 있으면 도감 상단에서 유도한다 (화면기획 27)
            // **서버 도감에서 계산한다** — 예전에는 `serverDex == nil` 일 때만 그리면서
            // 「카드 뒷면이 비어 있는 친구 2명」과 여행 이름을 **하드코딩**했다(NO-MOCK R1).
            // 실제 사용자에게도 늘 "2명" 이라고 보였다.
            if let notice = emptyBackNotice {
              NavigationLink(value: SupportRoute.tripMessage) {
                DogamEmptyBackNoticeCard(count: notice.count, tripTitle: notice.tripTitle)
              }
              .buttonStyle(.plain)
              .accessibilityIdentifier("friendDex.emptyBackNotice")
            }

            if let serverCompanions = filteredServerCompanions {
              // 실서버 도감 — 서버가 준 동행자만 그린다
              if serverCompanions.isEmpty {
                ServerDogamEmptyView(hasAnyCompanion: (serverDex?.totalCount ?? 0) > 0)
              } else {
                LazyVGrid(columns: columns, spacing: 8) {
                  ForEach(serverCompanions) { companion in
                    // 카드를 탭하면 25 프로필 카드로 넘어간다 (changeLog18)
                    NavigationLink(
                      value: MyRoute.profile(.serverCompanion(companion), startsFlipped: false)
                    ) {
                      ServerDogamCard(companion: companion)
                    }
                    .buttonStyle(.plain)
                  }
                }
              }
            } else {
              // 도감은 서버 응답이 전부다 — 목 친구를 채우지 않는다 (NO-MOCK-CANON R1)
              DogamEmptyResultView()
            }

            Text("다음 모임에서 새 친구를 만나보세요 ✨")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(MoyeoTheme.muted)
              .frame(maxWidth: .infinity)
              .padding(.top, 4)
            if let state = QAScrollState.requested {
              Color.clear
                .frame(height: state.qaSpacerHeight)
                .id("friendDex.bottom")
            }
          }
          .padding(.horizontal, 18)
          .padding(.top, 12)
          .padding(.bottom, 28)
        }
        .onAppear {
          guard let state = QAScrollState.requested else { return }
          let target = state.targetID(middle: "friendDex.middle", bottom: "friendDex.bottom")
          Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            proxy.scrollTo(target, anchor: state.anchor)
          }
        }
      }
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
    .task {
      guard MoyeoServerSync.isEnabled, serverDex == nil else { return }
      serverDex = try? await SocialAPIClient.shared.travelDex()
    }
    .accessibilityIdentifier("screen.friendDex")
  }
}

/// 실서버 도감 카드 — 서버가 준 값(닉네임·동행 횟수·최근 여행일·프로필 이미지)만 그린다
private struct ServerDogamCard: View {
  let companion: ServerTravelDexCompanion

  var body: some View {
    VStack(spacing: 6) {
      ZStack(alignment: .topTrailing) {
        CachedRemoteImage(url: companion.profileImageURL) { image in
          image
            .resizable()
            .scaledToFill()
        } placeholder: {
          MoyeoTheme.leaf
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        if companion.tripCount > 1 {
          Text("\(companion.tripCount)x")
            .font(.system(size: 8, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .frame(height: 16)
            .background(MoyeoTheme.forest)
            .clipShape(Capsule())
            .offset(x: 8, y: -5)
        }
      }

      Text(companion.nickname.split(separator: " ").prefix(2).joined(separator: " "))
        .font(.caption2.weight(.heavy))
        .foregroundStyle(MoyeoTheme.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
      Text(ServerTripMapper.displayDate(companion.latestTripDate))
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(MoyeoTheme.muted)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 92)
    .background(MoyeoTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
        .stroke(MoyeoTheme.softLine, lineWidth: 1)
    }
    .accessibilityIdentifier("friendDex.server.\(companion.userId)")
  }
}

/// 실서버 도감이 비어 있을 때의 상태 — 아직 함께 여행한 친구가 없다
private struct ServerDogamEmptyView: View {
  let hasAnyCompanion: Bool

  var body: some View {
    VStack(spacing: 6) {
      Text(hasAnyCompanion ? "검색 결과가 없어요" : "아직 함께 여행한 친구가 없어요.")
        .font(.subheadline.weight(.heavy))
        .foregroundStyle(MoyeoTheme.ink)
      Text(hasAnyCompanion ? "이름이나 필터를 바꿔 다시 찾아보세요." : "여행을 마치면 동행자가 도감에 기록돼요.")
        .font(.caption.weight(.semibold))
        .foregroundStyle(MoyeoTheme.muted)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 112)
    .background(MoyeoTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
        .stroke(MoyeoTheme.softLine, lineWidth: 1)
    }
    .accessibilityIdentifier("friendDex.server.empty")
  }
}

private enum DogamFriendFilter: String, CaseIterable, Identifiable {
  case all
  case repeated
  case recent

  var id: String { rawValue }

  var title: String {
    switch self {
    case .all:
      return "전체 12"
    case .repeated:
      return "2회 이상 4"
    case .recent:
      return "최근 1개월 3"
    }
  }

  var summary: String {
    switch self {
    case .all:
      return "최근 동행 순"
    case .repeated:
      return "2회 이상 만난 친구"
    case .recent:
      return "최근 1개월 동행"
    }
  }

  // MARK: 실서버 도감

  func includesServer(_ companion: ServerTravelDexCompanion) -> Bool {
    switch self {
    case .all:
      return true
    case .repeated:
      return companion.tripCount >= 2
    case .recent:
      return Self.isWithinRecentMonth(companion.latestTripDate)
    }
  }

  /// 서버 도감의 필터 칩은 서버 데이터 기준으로 개수를 센다
  func serverTitle(companions: [ServerTravelDexCompanion]) -> String {
    let count = companions.filter { includesServer($0) }.count
    switch self {
    case .all:
      return "전체 \(count)"
    case .repeated:
      return "2회 이상 \(count)"
    case .recent:
      return "최근 1개월 \(count)"
    }
  }

  private static func isWithinRecentMonth(_ isoDate: String) -> Bool {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    guard let date = formatter.date(from: isoDate) else { return false }
    guard let threshold = Calendar.current.date(byAdding: .month, value: -1, to: Date()) else {
      return false
    }
    return date >= threshold
  }
}

private struct DogamSearchField: View {
  @Binding var query: String

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(.caption.weight(.bold))
        .foregroundStyle(MoyeoTheme.muted)
      TextField("친구 이름 검색", text: $query)
        .font(.subheadline.weight(.semibold))
        .textInputAutocapitalization(.never)
        .disableAutocorrection(true)
      if !query.isEmpty {
        Button("지우기") {
          query = ""
        }
        .font(.caption.weight(.heavy))
        .foregroundStyle(MoyeoTheme.forest)
      }
    }
    .padding(.horizontal, 12)
    .frame(height: 40)
    .background(MoyeoTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(MoyeoTheme.softLine, lineWidth: 1)
    }
    .accessibilityIdentifier("friendDex.searchField")
  }
}

private struct DogamFilterChip: View {
  let title: String
  let selected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.caption2.weight(.heavy))
        .foregroundStyle(selected ? .white : MoyeoTheme.text700)
        .padding(.horizontal, 8)
        .frame(height: 23)
        .background(selected ? MoyeoTheme.forest : MoyeoTheme.card)
        .clipShape(Capsule())
        .overlay {
          Capsule()
            .stroke(selected ? MoyeoTheme.forest : MoyeoTheme.softLine, lineWidth: 1)
        }
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("friendDex.filter.\(title)")
  }
}

/// 화면기획 27 상단 안내 — 카드 뒷면(한 줄 메시지)이 비어 있는 친구를 27-1로 유도한다.
/// 수치와 여행 이름은 **서버 도감에서 온다** — 지어내지 않는다.
private struct DogamEmptyBackNoticeCard: View {
  let count: Int
  let tripTitle: String

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "square.and.pencil")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(MoyeoTheme.onLeaf)
      VStack(alignment: .leading, spacing: 3) {
        Text("카드 뒷면이 비어 있는 친구 \(count)명")
          .font(.caption.weight(.heavy))
          .foregroundStyle(MoyeoTheme.onLeaf)
        Text("\(tripTitle)에서 만난 친구들에게 한 줄 남겨볼까요?")
          .font(.caption2)
          .foregroundStyle(MoyeoTheme.brandText)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 6)
      Image(systemName: "chevron.right")
        .font(.caption.weight(.bold))
        .foregroundStyle(MoyeoTheme.brandText)
    }
    .padding(13)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(MoyeoTheme.leaf)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(MoyeoTheme.primary100, lineWidth: 1)
    }
  }
}

private struct DogamEmptyResultView: View {
  var body: some View {
    VStack(spacing: 6) {
      Text("검색 결과가 없어요")
        .font(.subheadline.weight(.heavy))
        .foregroundStyle(MoyeoTheme.ink)
      Text("이름이나 필터를 바꿔 다시 찾아보세요.")
        .font(.caption.weight(.semibold))
        .foregroundStyle(MoyeoTheme.muted)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 112)
    .background(MoyeoTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
        .stroke(MoyeoTheme.softLine, lineWidth: 1)
    }
  }
}

private struct SettingsView: View {
  @State private var chatEnabled = true
  @State private var deadlineEnabled = true
  @State private var friendEnabled = true
  @State private var marketingEnabled = false
  /// 실서버 알림 설정 — 로그인 세션이 있고 설정 API가 성공했을 때만 켜진다
  @State private var isServerSettingsLoaded = false
  @State private var serverChatMode = "ALL"
  @State private var serverDNDSettings: ServerNotificationSettings?
  @State private var selectedAction: SettingsRow?
  /// 29 설정 › 화면 › 테마. 행을 탭하면 시스템 기본 → 라이트 → 다크 순으로 순환한다.
  @ObservedObject private var themeStore = MoyeoThemeStore.shared
  @State private var isPerformingAccountAction = false
  @State private var accountErrorMessage: String?
  @State private var isShowingProviderManagement = false
  @State private var supportRoute: SupportRoute?
  @StateObject private var providerService: AuthProviderLinkService
  private let accountService: AuthAccountService
  private let onAuthenticationRequired: () -> Void

  init(
    accountService: AuthAccountService = AuthAccountService(),
    providerService: AuthProviderLinkService? = nil,
    onAuthenticationRequired: @escaping () -> Void = {}
  ) {
    self.accountService = accountService
    _providerService = StateObject(wrappedValue: providerService ?? .current)
    self.onAuthenticationRequired = onAuthenticationRequired
  }

  var body: some View {
    VStack(spacing: 0) {
      CompactDetailHeader(title: "설정") {
        Color.clear
      }

      ScrollViewReader { proxy in
        ScrollView {
          VStack(spacing: 16) {
            SettingsSectionGroup("알림") {
              // 세부 설정은 토글 다음에 온다 (화면기획·웹·안드로이드와 같은 순서)
              SettingsToggleRow(title: "채팅 메시지", subtitle: nil, isOn: $chatEnabled)
              SettingsToggleRow(title: "모집 마감 임박", subtitle: "D-3부터 알려드려요", isOn: $deadlineEnabled)
              SettingsToggleRow(title: "친구 신청·피드 반응", subtitle: nil, isOn: $friendEnabled)
              SettingsToggleRow(title: "마케팅 알림", subtitle: "이벤트·새 코스 소개", isOn: $marketingEnabled)
              SettingsValueRow(action: .notificationDetail) { _ in
                supportRoute = .notificationDetail
              }
            }

            SettingsSectionGroup("화면") {
              // 기획에 테마 선택 UI가 없어 시트·새 화면을 만들지 않고 행에서 순환한다
              SettingsValueRow(action: .theme, valueOverride: themeRowValue) { _ in
                advanceTheme()
              }
              SettingsValueRow(action: .language) { selectedAction = $0 }
            }
            .id("settings.middle")

            SettingsSectionGroup("계정") {
              SettingsValueRow(action: .loginMethod) { _ in
                isShowingProviderManagement = true
              }
              // 13-2 — 알림이 사라져도 내보내진 사유를 다시 볼 수 있는 유일한 길이다.
              SettingsValueRow(action: .kickHistory) { _ in
                supportRoute = .kickHistory
              }
              SettingsValueRow(action: .blockedUsers) { _ in
                supportRoute = .blockedUsers
              }
              SettingsValueRow(action: .privacyPolicy) { _ in
                supportRoute = .legalDocument(.privacy)
              }
              SettingsValueRow(action: .terms) { _ in
                supportRoute = .legalDocument(.service)
              }
            }

            SettingsSectionGroup("정보") {
              SettingsValueRow(action: .version) { selectedAction = $0 }
              SettingsValueRow(action: .contact) { selectedAction = $0 }
              SettingsValueRow(action: .rate) { selectedAction = $0 }
              // changeLog17 — `앱 평가하기` 다음, `로그아웃` 위
              SettingsValueRow(action: .ossLicenses) { _ in
                supportRoute = .ossLicenses
              }
              SettingsDangerRow(action: .logout) { selectedAction = $0 }
              SettingsDangerRow(action: .deleteAccount) { _ in
                supportRoute = .accountDelete
              }
            }
            if let state = QAScrollState.requested {
              Color.clear
                .frame(height: state.qaSpacerHeight)
                .id("settings.bottom")
            }

            if isPerformingAccountAction {
              ProgressView("계정 정보를 처리하고 있어요")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MoyeoTheme.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .accessibilityIdentifier("settings.account.progress")
            }
          }
          .padding(.horizontal, 18)
          .padding(.top, 14)
          .padding(.bottom, 34)
        }
        .onAppear {
          guard let state = QAScrollState.requested else { return }
          let target = state.targetID(middle: "settings.middle", bottom: "settings.bottom")
          Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            proxy.scrollTo(target, anchor: state.anchor)
          }
        }
      }
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
    .alert(item: $selectedAction) { action in
      accountAlert(for: action)
    }
    .alert("계정 작업을 완료하지 못했어요", isPresented: accountErrorBinding) {
      Button("확인", role: .cancel) {}
    } message: {
      Text(accountErrorMessage ?? "잠시 후 다시 시도해주세요.")
    }
    .sheet(isPresented: $isShowingProviderManagement) {
      ProviderManagementView(service: providerService)
    }
    .navigationDestination(item: $supportRoute) { route in
      SupportDestinationView(route: route, onAuthCompleted: onAuthenticationRequired)
    }
    .task {
      await loadServerNotificationSettings()
    }
    .onChange(of: chatEnabled) { _, _ in pushServerNotificationSettings() }
    .onChange(of: deadlineEnabled) { _, _ in pushServerNotificationSettings() }
    .onChange(of: friendEnabled) { _, _ in pushServerNotificationSettings() }
    .onChange(of: marketingEnabled) { _, _ in pushServerNotificationSettings() }
    .accessibilityIdentifier("screen.settings")
  }

  /// 저장된 사용자 설정을 그대로 보여준다 — 캡처도 같은 값을 쓴다 (NO-MOCK-CANON R2)
  private var themeRowValue: String {
    themeStore.mode.rowValue
  }

  private func advanceTheme() {
    themeStore.advance()
  }

  /// 29-2 알림 설정 — 채팅 모드·3개 토글은 프로필 응답에, 방해 금지는 알림 설정 응답에 있다
  private func loadServerNotificationSettings() async {
    guard MoyeoServerSync.isEnabled, !isServerSettingsLoaded else { return }
    guard let profile = try? await UserProfileAPIClient.shared.myProfile() else { return }
    serverChatMode = profile.chatNotificationMode
    chatEnabled = profile.chatNotificationMode != "NONE"
    deadlineEnabled = profile.recruitmentDeadlineEnabled
    friendEnabled = profile.socialActivityEnabled
    marketingEnabled = profile.marketingEnabled
    serverDNDSettings = try? await NotificationAPIClient.shared.settings()
    isServerSettingsLoaded = true
  }

  private func pushServerNotificationSettings() {
    guard isServerSettingsLoaded else { return }
    let chatMode = chatEnabled ? (serverChatMode == "NONE" ? "ALL" : serverChatMode) : "NONE"
    let update = ServerNotificationSettingsUpdate(
      chatNotificationMode: chatMode,
      recruitmentDeadlineEnabled: deadlineEnabled,
      socialActivityEnabled: friendEnabled,
      marketingEnabled: marketingEnabled,
      doNotDisturbEnabled: serverDNDSettings?.doNotDisturbEnabled ?? false,
      doNotDisturbStartTime: serverDNDSettings?.doNotDisturbStartTime,
      doNotDisturbEndTime: serverDNDSettings?.doNotDisturbEndTime,
      doNotDisturbDays: serverDNDSettings?.doNotDisturbDays ?? []
    )
    Task {
      if let updated = try? await NotificationAPIClient.shared.updateSettings(update) {
        serverDNDSettings = updated
      }
    }
  }

  private var accountErrorBinding: Binding<Bool> {
    Binding(
      get: { accountErrorMessage != nil },
      set: { isPresented in
        if !isPresented { accountErrorMessage = nil }
      }
    )
  }

  private func accountAlert(for action: SettingsRow) -> Alert {
    switch action {
    case .logout:
      return Alert(
        title: Text(action.dialogTitle),
        message: Text(action.dialogBody),
        primaryButton: .destructive(Text("로그아웃")) {
          performAccountAction(action)
        },
        secondaryButton: .cancel(Text("취소"))
      )
    case .deleteAccount:
      return Alert(
        title: Text(action.dialogTitle),
        message: Text(action.dialogBody),
        primaryButton: .destructive(Text("영구 탈퇴")) {
          performAccountAction(action)
        },
        secondaryButton: .cancel(Text("취소"))
      )
    default:
      return Alert(
        title: Text(action.dialogTitle),
        message: Text(action.dialogBody),
        dismissButton: .default(Text(action.confirmLabel))
      )
    }
  }

  private func performAccountAction(_ action: SettingsRow) {
    guard !isPerformingAccountAction else { return }
    isPerformingAccountAction = true
    Task {
      do {
        if action == .deleteAccount {
          try await accountService.withdraw()
        } else {
          try await accountService.logout()
        }
        onAuthenticationRequired()
      } catch {
        accountErrorMessage =
          (error as? LocalizedError)?.errorDescription
          ?? "잠시 후 다시 시도해주세요."
      }
      isPerformingAccountAction = false
    }
  }
}

/// 29-5 계정 연결 (로그인 방식). 설정의 `로그인 방식 › 관리` 와 캡처 라우트가 같은 화면을 연다.
struct ProviderManagementView: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject var service: AuthProviderLinkService
  /// 설정에서는 시트로 뜨고, 캡처 라우트(`account-providers`)에서는 밀어 넣는다.
  /// 밀어 넣을 때 자체 `NavigationStack` 과 `presentationDetents` 를 그대로 두면 아무것도 그려지지 않는다.
  var isPresentedAsSheet = true
  @State private var email = ""
  @State private var password = ""
  @State private var isEmailFormExpanded = false

  var body: some View {
    if isPresentedAsSheet {
      NavigationStack { content }
        .presentationDetents([.large])
        .accessibilityIdentifier("screen.providerManagement")
    } else {
      content
        .accessibilityIdentifier("screen.providerManagement")
    }
  }

  private var content: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          // 29-5 안내 문구는 세 플랫폼이 글자 그대로 같다 (기획 `ScreenAccountProviders`).
          Text("어느 방법으로든 같은 계정으로 들어와요. 하나를 더 연결해두면 한쪽을 못 쓰게 돼도 들어올 수 있어요.")
            .font(MoyeoTypography.cardBody)
            .foregroundStyle(MoyeoTheme.muted)
            .fixedSize(horizontal: false, vertical: true)

          ForEach(AuthServiceProvider.connectionOrder) { provider in
            providerCard(provider)
          }

          // 마지막 하나는 끊을 수 없다 — 끊으면 아무 방법으로도 못 들어온다.
          // 서버에도 연결 해제 API 가 없다(POST /auth/providers 는 연결만 한다).
          AttachNoteBox(lines: ["마지막 하나 남은 로그인 방식은 끊을 수 없어요. 계정을 아예 지우려면 설정에서 탈퇴해 주세요."])
            .accessibilityIdentifier("providers.note")

          if let errorMessage = service.errorMessage {
            Text(errorMessage)
              .font(.caption.weight(.semibold))
              .foregroundStyle(MoyeoTheme.coral)
              .accessibilityIdentifier("providers.error")
          }
        }
        .padding(18)
      }
      .background(MoyeoTheme.background.ignoresSafeArea())
      .navigationTitle("로그인 방식")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        if isPresentedAsSheet {
          ToolbarItem(placement: .confirmationAction) {
            Button("완료") { dismiss() }
          }
        }
      }
      .task { await service.load() }
  }

  @ViewBuilder
  private func providerCard(_ provider: AuthServiceProvider) -> some View {
    let isConnected = service.providers.contains(provider)
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        ProviderManagementMark(provider: provider)
        VStack(alignment: .leading, spacing: 2) {
          Text(provider.providerName)
            .font(MoyeoTypography.cardTitle)
            .foregroundStyle(MoyeoTheme.ink)
          Text(isConnected ? "연결됨" : provider.providerConnectionHint)
            .font(MoyeoTypography.cardMeta)
            .foregroundStyle(isConnected ? MoyeoTheme.forest : MoyeoTheme.muted)
        }
        Spacer()
        if isConnected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(MoyeoTheme.forest)
        }
      }

      providerAction(provider, isConnected: isConnected)
    }
    .padding(16)
    .background(MoyeoTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
        .stroke(MoyeoTheme.softLine, lineWidth: 1)
    }
    .disabled(service.isLoading || service.linkingProvider != nil)
  }

  @ViewBuilder
  private func providerAction(_ provider: AuthServiceProvider, isConnected: Bool) -> some View {
    if provider == .email, !isConnected {
      if isEmailFormExpanded {
        emailConnectionForm
      } else {
        AuthProviderButton(
          provider: .email,
          isDisabled: service.isLoading || service.linkingProvider != nil,
          showsMark: false,
          titleOverride: "이메일 연결",
          accessibilityIdentifierOverride: "providers.email.link"
        ) {
          withAnimation(.easeInOut(duration: 0.18)) {
            isEmailFormExpanded = true
          }
        }
      }
    } else if !isConnected {
      AuthProviderButton(
        provider: provider,
        isLoading: service.linkingProvider == provider,
        isDisabled: service.isLoading || service.linkingProvider != nil,
        showsMark: false,
        titleOverride: "\(provider.providerName) 연결",
        accessibilityIdentifierOverride: "providers.\(provider.pathComponent).link"
      ) {
        Task { await service.link(provider) }
      }
    }
  }

  private var emailConnectionForm: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("아직 가입되지 않은 이메일을 새 로그인 수단으로 추가해요.")
        .font(MoyeoTypography.cardMeta)
        .foregroundStyle(MoyeoTheme.muted)
      TextField("새 이메일", text: $email)
        .textInputAutocapitalization(.never)
        .keyboardType(.emailAddress)
        .autocorrectionDisabled()
        .moyeoInput()
        .accessibilityIdentifier("providers.email.email")
      SecureField("비밀번호", text: $password)
        .textContentType(.newPassword)
        .moyeoInput()
        .accessibilityIdentifier("providers.email.password")
      emailSubmitButton
      Button("입력 닫기") {
        withAnimation(.easeInOut(duration: 0.18)) {
          isEmailFormExpanded = false
        }
      }
      .font(.caption.weight(.semibold))
      .foregroundStyle(MoyeoTheme.muted)
      .frame(maxWidth: .infinity)
      .buttonStyle(.plain)
    }
  }

  private var emailSubmitButton: some View {
    Button {
      Task { await service.linkEmail(email: email, password: password) }
    } label: {
      HStack(spacing: 8) {
        if service.linkingProvider == .email {
          ProgressView().tint(.white)
        }
        Text(service.linkingProvider == .email ? "연결하고 있어요" : "새 이메일 연결")
      }
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(MoyeoPrimaryButtonStyle())
    .disabled(
      email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || password.isEmpty
        || service.linkingProvider != nil
    )
    .accessibilityIdentifier("providers.email.submit")
  }
}

extension AuthServiceProvider {
  fileprivate static let connectionOrder: [AuthServiceProvider] = [.kakao, .google, .email, .apple]

  fileprivate var providerName: String {
    switch self {
    case .kakao: "카카오"
    case .google: "Google"
    case .email: "이메일"
    case .apple: "Apple"
    }
  }

  fileprivate var providerConnectionHint: String {
    self == .email ? "이메일과 비밀번호가 필요해요" : "추가로 연결할 수 있어요"
  }
}

private struct ProviderManagementMark: View {
  @Environment(\.colorScheme) private var colorScheme

  let provider: AuthServiceProvider

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .fill(backgroundColor)
      mark
    }
    .frame(width: 38, height: 38)
    .accessibilityHidden(true)
  }

  @ViewBuilder
  private var mark: some View {
    switch provider {
    case .kakao:
      Image("KakaoSymbolOfficial")
        .resizable()
        .scaledToFit()
        .frame(width: 30, height: 30)
    case .google:
      Image("GoogleG")
        .resizable()
        .scaledToFit()
        .frame(width: 20, height: 20)
    case .email:
      Text("@")
        .font(.system(size: 18, weight: .heavy))
        .foregroundStyle(MoyeoTheme.forest)
    case .apple:
      Image("AppleSymbolOfficial")
        .resizable()
        .scaledToFit()
        .frame(width: 20, height: 20)
    }
  }

  private var backgroundColor: Color {
    switch provider {
    case .kakao:
      Color(hex: "#FEE500")
    case .google:
      colorScheme == .dark ? Color(hex: "#131314") : .white
    case .email:
      MoyeoTheme.leaf
    case .apple:
      colorScheme == .dark ? .white : .black
    }
  }
}

private struct MoyeoPrimaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 14, weight: .heavy))
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity, minHeight: 46)
      .background(MoyeoTheme.forest.opacity(configuration.isPressed ? 0.78 : 1))
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  }
}

extension View {
  fileprivate func moyeoInput() -> some View {
    padding(.horizontal, 12)
      .frame(minHeight: 48)
      .background(MoyeoTheme.background)
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .stroke(MoyeoTheme.softLine, lineWidth: 1)
      }
  }
}

private struct SettingsSectionGroup<Content: View>: View {
  let title: String
  let content: Content

  init(_ title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(MoyeoTheme.muted)
        .padding(.horizontal, 2)

      VStack(spacing: 0) {
        content
      }
      .background(MoyeoTheme.card)
      .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
          .stroke(MoyeoTheme.softLine, lineWidth: 1)
      }
    }
  }
}

private struct SettingsToggleRow: View {
  let title: String
  let subtitle: String?
  @Binding var isOn: Bool

  var body: some View {
    HStack(spacing: 10) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 14, weight: .heavy))
          .foregroundStyle(MoyeoTheme.ink)
        if let subtitle {
          Text(subtitle)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(MoyeoTheme.muted)
        }
      }
      Spacer()
      Toggle("", isOn: $isOn)
        .labelsHidden()
        .scaleEffect(0.82)
        .tint(MoyeoTheme.forest)
    }
    .frame(maxWidth: .infinity, minHeight: subtitle == nil ? 58 : 64, alignment: .leading)
    .padding(.horizontal, 16)
    .contentShape(Rectangle())
    .overlay(alignment: .bottom) {
      SettingsRowDivider()
    }
  }
}

private struct SettingsValueRow: View {
  let action: SettingsRow
  /// 사용자 설정에 따라 바뀌는 값(테마)은 화면에서 넣어준다
  var valueOverride: String?
  let onTap: (SettingsRow) -> Void

  var body: some View {
    Button {
      onTap(action)
    } label: {
      HStack(spacing: 8) {
        Text(action.rowTitle)
          .font(.system(size: 14, weight: .heavy))
          .foregroundStyle(MoyeoTheme.ink)
        Spacer()
        if let value = valueOverride ?? action.rowValue {
          Text(value)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(MoyeoTheme.muted)
        }
        Image(systemName: "chevron.right")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(MoyeoTheme.text400)
      }
      .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
      .padding(.horizontal, 16)
      .contentShape(Rectangle())
      .overlay(alignment: .bottom) {
        SettingsRowDivider()
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(action.rowTitle)
    .accessibilityIdentifier("settings.action.\(action.key)")
  }
}

private struct SettingsDangerRow: View {
  let action: SettingsRow
  let onTap: (SettingsRow) -> Void

  var body: some View {
    Button {
      onTap(action)
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(action.rowTitle)
            .font(.system(size: 14, weight: .heavy))
            .foregroundStyle(MoyeoTheme.coral)
          if let value = action.rowValue {
            Text(value)
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(MoyeoTheme.coral.opacity(0.72))
          }
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(MoyeoTheme.text400)
      }
      .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
      .padding(.horizontal, 16)
      .contentShape(Rectangle())
      .overlay(alignment: .bottom) {
        SettingsRowDivider()
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(action.rowTitle)
    .accessibilityIdentifier("settings.action.\(action.key)")
  }
}

private struct SettingsRowDivider: View {
  var body: some View {
    Rectangle()
      .fill(MoyeoTheme.softLine)
      .frame(height: 1)
      .padding(.leading, 16)
  }
}

/// 29 설정의 행 식별자. 목데이터가 아니라 "어느 행을 눌렀는지"를 가리키는 값이다.
private enum SettingsRow: Identifiable {
  case notificationDetail
  case theme
  case language
  case loginMethod
  /// 13-2 내 강퇴 이력. 13-1 은 알림 한 건을 여는 화면이라 알림이 사라지면 사유를 다시 볼 길이 없었다.
  case kickHistory
  case blockedUsers
  case privacyPolicy
  case terms
  case version
  case contact
  case rate
  /// changeLog17 — 29-4 오픈소스 라이선스로 이동하는 행
  case ossLicenses
  case logout
  case deleteAccount

  var id: String { rowTitle }

  var key: String {
    switch self {
    case .notificationDetail:
      return "notificationDetail"
    case .theme:
      return "theme"
    case .language:
      return "language"
    case .loginMethod:
      return "loginMethod"
    case .kickHistory:
      return "kickHistory"
    case .blockedUsers:
      return "blockedUsers"
    case .privacyPolicy:
      return "privacyPolicy"
    case .terms:
      return "terms"
    case .version:
      return "version"
    case .contact:
      return "contact"
    case .rate:
      return "rate"
    case .ossLicenses:
      return "ossLicenses"
    case .logout:
      return "logout"
    case .deleteAccount:
      return "deleteAccount"
    }
  }

  var rowTitle: String {
    switch self {
    case .notificationDetail:
      return "알림 세부 설정"
    case .theme:
      return "테마"
    case .language:
      return "언어"
    case .loginMethod:
      return "로그인 방식"
    case .kickHistory:
      return "내보내진 기록"
    case .blockedUsers:
      return "차단한 사용자"
    case .privacyPolicy:
      return "개인정보 처리방침"
    case .terms:
      return "이용약관"
    case .version:
      return "버전"
    case .contact:
      return "문의하기"
    case .rate:
      return "앱 평가하기"
    case .ossLicenses:
      return "오픈소스 라이선스"
    case .logout:
      return "로그아웃"
    case .deleteAccount:
      return "계정 탈퇴"
    }
  }

  var rowValue: String? {
    switch self {
    case .notificationDetail:
      return "방해금지 22:30~07:00"
    case .theme:
      // 캡처 기본값. 실제 값은 SettingsView 가 사용자 설정으로 덮어쓴다.
      return MoyeoThemeMode.system.rowValue
    case .language:
      return "한국어"
    case .loginMethod:
      return "관리"
    case .blockedUsers:
      return "2명"
    case .version:
      // 최신 버전 조회 API가 없어 `(최신)` 판정은 붙이지 않는다. 캡처 모드만 기획값을 유지한다.
      return AppVersionInfo.rowValue
    case .deleteAccount:
      return nil
    default:
      return nil
    }
  }

  var dialogTitle: String {
    switch self {
    case .notificationDetail:
      return "알림 세부 설정"
    case .theme:
      return "테마 설정"
    case .language:
      return "언어 설정"
    case .loginMethod:
      return "로그인 방식"
    case .kickHistory:
      return "내보내진 기록"
    case .blockedUsers:
      return "차단한 사용자"
    case .privacyPolicy:
      return "개인정보 처리방침"
    case .terms:
      return "이용약관"
    case .version:
      return "앱 버전"
    case .contact:
      return "문의하기"
    case .rate:
      return "앱 평가하기"
    case .ossLicenses:
      return "오픈소스 라이선스"
    case .logout:
      return "로그아웃 안내"
    case .deleteAccount:
      return "계정 탈퇴 안내"
    }
  }

  var dialogBody: String {
    switch self {
    case .notificationDetail:
      return "알림 범위, 방해금지 시간대와 모임별 음소거를 관리해요."
    case .theme:
      return "시스템 설정에 맞춰 밝은 화면과 어두운 화면을 자동으로 전환해요."
    case .language:
      return "한국어 기준으로 표시되고, 지역 안내 문구도 같은 언어 설정을 따라가요."
    case .loginMethod:
      return "카카오 계정으로 연결된 상태예요. 계정 연결 관리는 여기에서 이어져요."
    case .kickHistory:
      // 화면으로 이동하는 행이라 다이얼로그 본문이 필요 없다
      return ""
    case .blockedUsers:
      return "차단 목록 2명을 확인하고 필요하면 차단을 해제할 수 있어요."
    case .privacyPolicy:
      return "모여트립의 개인정보 수집, 보관, 삭제 기준을 확인하는 문서 화면이에요."
    case .terms:
      return "여행 모집, 채팅, 후기 이용 규칙을 확인하는 약관 화면이에요."
    case .version:
      return AppVersionInfo.dialogBody
    case .contact:
      return "채팅, 모집, 결제 문의를 남기는 고객센터로 이어져요."
    case .rate:
      return "스토어 평가로 이동하기 전, 모여트립 사용 경험을 한 번 더 확인해요."
    case .ossLicenses:
      // 다이얼로그를 쓰지 않고 29-4로 이동하는 행이라 본문이 필요 없다
      return ""
    case .logout:
      return "이 기기에서 로그아웃하고 로그인 화면으로 돌아갈까요?"
    case .deleteAccount:
      return "탈퇴 요청 후 30일 동안 대기 상태가 되며, 그 안에 다시 로그인하면 계정을 되살릴 수 있어요."
    }
  }

  var confirmLabel: String {
    switch self {
    case .logout, .deleteAccount:
      return "확인"
    default:
      return "닫기"
    }
  }
}

private struct MyActiveTripCard: View {
  let trip: TripRecruitment

  var body: some View {
    HStack(spacing: MyTravelCardMetrics.gap) {
      MoyeoPhotoTile(
        mascot: trip.coverMascot,
        mood: trip.mood,
        height: MyTravelCardMetrics.thumbHeight,
        cornerRadius: MyTravelCardMetrics.thumbRadius
      )
      .frame(width: MyTravelCardMetrics.thumbWidth)

      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .top, spacing: 8) {
          Text(trip.myListTitle)
            .font(MyTravelCardMetrics.titleFont)
            .foregroundStyle(MoyeoTheme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .accessibilityIdentifier("my.activeTrip.\(trip.id).title")
          Spacer(minLength: 4)
          Pill(text: trip.ddayText, tint: MoyeoTheme.coral)
        }

        Text(trip.myDateText)
          .font(MyTravelCardMetrics.metaFont)
          .foregroundStyle(MoyeoTheme.muted)
          .lineLimit(1)
          .accessibilityIdentifier("my.activeTrip.\(trip.id).date")

        Text(trip.meetupPoint)
          .font(MyTravelCardMetrics.subtitleFont)
          .foregroundStyle(MoyeoTheme.muted)
          .lineLimit(1)
          .accessibilityIdentifier("my.activeTrip.\(trip.id).meetup")

        HStack(spacing: 8) {
          ProgressBar(value: trip.myProgress, tint: MoyeoTheme.forest)
          Text(trip.myPeopleText)
            .font(.caption2.weight(.bold))
            .foregroundStyle(MoyeoTheme.text700)
            .accessibilityIdentifier("my.activeTrip.\(trip.id).people")
          ParticipantStack(participants: trip.myDisplayParticipants, limit: 3, size: 22)
        }
        .padding(.top, 1)
      }
    }
    .padding(12)
    .frame(height: MyTravelCardMetrics.activeHeight)
    .moyeoListCard()
  }
}

private enum MyTravelCardMetrics {
  static let activeHeight: CGFloat = 144
  static let summaryHeight: CGFloat = 136
  static let thumbWidth: CGFloat = 96
  static let thumbHeight: CGFloat = 86
  static let thumbRadius: CGFloat = 9
  static let gap: CGFloat = 14
  static let titleFont = MoyeoTypography.font(size: 15, weight: .bold, relativeTo: .headline)
  static let subtitleFont = MoyeoTypography.font(size: 12.5, relativeTo: .subheadline)
  static let metaFont = MoyeoTypography.font(size: 11.5, weight: .bold, relativeTo: .caption)
}

private struct MyTravelSummaryCard: View {
  let identifierPrefix: String
  let title: String
  let subtitle: String
  let meta: String
  let mascot: String
  let mood: CourseMood
  let badge: String

  var body: some View {
    HStack(spacing: MyTravelCardMetrics.gap) {
      MoyeoPhotoTile(
        mascot: mascot,
        mood: mood,
        height: MyTravelCardMetrics.thumbHeight,
        cornerRadius: MyTravelCardMetrics.thumbRadius
      )
      .frame(width: MyTravelCardMetrics.thumbWidth)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(MyTravelCardMetrics.titleFont)
          .foregroundStyle(MoyeoTheme.ink)
          .lineLimit(1)
          .minimumScaleFactor(0.88)
          .accessibilityIdentifier("\(identifierPrefix).title")
        Text(subtitle)
          .font(MyTravelCardMetrics.subtitleFont)
          .foregroundStyle(MoyeoTheme.muted)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("\(identifierPrefix).subtitle")
        Text(meta)
          .font(MyTravelCardMetrics.metaFont)
          .foregroundStyle(MoyeoTheme.text700)
          .lineLimit(1)
          .accessibilityIdentifier("\(identifierPrefix).meta")
      }

      Spacer(minLength: 6)

      Pill(text: badge, tint: MoyeoTheme.forest)
        .accessibilityIdentifier("\(identifierPrefix).badge")
    }
    .padding(12)
    .frame(height: MyTravelCardMetrics.summaryHeight)
    .moyeoListCard()
  }
}

extension View {
  fileprivate func moyeoListCard() -> some View {
    self
      .background(MoyeoTheme.card)
      .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
          .stroke(MoyeoTheme.softLine, lineWidth: 1)
      }
  }
}

extension TripRecruitment {
  fileprivate var mood: CourseMood {
    switch id {
    case "trip-andong-hahoe":
      return .sunrise
    case "trip-gyeongju-night":
      return .coral
    default:
      return .forest
    }
  }

  fileprivate var ddayText: String {
    // 마감 D-day는 4개 플랫폼 공통 값이다 (docs/alignment/MOCKDATA-CANON.md)
    switch id {
    case "trip-cheongsong-juwangsan":
      return "D-3"
    case "trip-andong-hahoe":
      return "D-5"
    case "trip-gyeongju-night":
      return "D-3"
    default:
      return "D-1"
    }
  }

  /// 화면기획 26 마이 — 진행중 카드는 서버가 준 코스 이름이 있으면 그것을, 없으면 모집 이름을 쓴다
  fileprivate var myListTitle: String {
    serverCourseTitle.flatMap { $0.isEmpty ? nil : $0 } ?? title
  }

  fileprivate var myDateText: String {
    schedule.split(separator: " ").prefix(2).joined(separator: " ")
  }

  fileprivate var myPeopleText: String {
    "\(myParticipantCount.joined)/\(myParticipantCount.capacity)명"
  }

  fileprivate var myProgress: Double {
    guard myParticipantCount.capacity > 0 else { return 0 }
    return min(Double(myParticipantCount.joined) / Double(myParticipantCount.capacity), 1)
  }

  fileprivate var myDisplayParticipants: [Participant] {
    Array(participants.prefix(myParticipantCount.joined))
  }

  private var myParticipantCount: (joined: Int, capacity: Int) {
    (joined, capacity)
  }
}

private struct ProfileHeader: View {
  let profile: ProfileSummary

  var body: some View {
    VStack(spacing: 18) {
      HStack(spacing: 16) {
        AuthenticatedProfileAvatar(profile: profile, size: 82)
        VStack(alignment: .leading, spacing: 8) {
          Text(profile.name)
            .font(.title2.weight(.heavy))
            .foregroundStyle(MoyeoTheme.ink)
          Text(profile.handle)
            .font(.headline)
            .foregroundStyle(MoyeoTheme.forest)
          Label(profile.region, systemImage: "mappin.circle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(MoyeoTheme.muted)
        }
        Spacer()
        Image(systemName: "gearshape.fill")
          .font(.headline.bold())
          .foregroundStyle(MoyeoTheme.forest)
          .frame(width: 44, height: 44)
          .background(MoyeoTheme.leaf)
          .clipShape(Circle())
      }

      HStack(spacing: 8) {
        ForEach(dynamicBadges.prefix(3), id: \.self) { badge in
          Pill(text: badge, tint: MoyeoTheme.coral)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .moyeoCard()
  }

  private var dynamicBadges: [String] {
    ["여행 \(profile.joinedTrips)", "매너 4.7", "경북 친구"]
  }
}

/// 서버 프로필 이미지가 우선이고, 없으면 **닉네임에서 계산한 동물**을 그린다 (NO-MOCK-CANON R5).
/// 화면별 고정 이모지(`emojiOverride`)는 두지 않는다 — 서버 이미지까지 가려 버렸다.
private struct AuthenticatedProfileAvatar: View {
  let profile: ProfileSummary
  let size: CGFloat
  /// 세션 프로필보다 최신인 서버 이미지. 있으면 이쪽을 쓴다.
  var overrideImageURL: URL?

  var body: some View {
    Group {
      if let url = overrideImageURL ?? profile.profileImageURL {
        CachedRemoteImage(url: url) { image in
          image.resizable().scaledToFill()
        } placeholder: {
          fallback
        }
      } else {
        fallback
      }
    }
    .frame(width: size, height: size)
    .background(MoyeoTheme.leaf)
    .clipShape(Circle())
    .accessibilityLabel("\(profile.name) 프로필 이미지")
  }

  private var fallback: some View {
    Text(profile.avatar)
      .font(.system(size: size * 0.48))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// 화면기획 26 상단의 3칸 지표. 25 프로필 카드와 **같은 근거**(`GET /users/{userId}/profile`)다.
/// 매너 점수는 소수 한 자리로 적는다 — 평균값이라 `4.7` 처럼 나온다(안드로이드가 정본).
private struct MyProfileMetricStrip: View {
  let profile: ServerPublicProfile

  struct Metric: Identifiable {
    let id: String
    let value: String
    let label: String
  }

  static func metrics(from profile: ServerPublicProfile) -> [Metric] {
    var result: [Metric] = []
    if let trips = profile.completedTripCount {
      result.append(Metric(id: "여행", value: "\(trips)", label: "여행"))
    }
    if let manner = profile.mannerRating {
      result.append(Metric(id: "매너", value: String(format: "%.1f", manner), label: "매너"))
    }
    if let feeds = profile.feedCount {
      result.append(Metric(id: "피드", value: "\(feeds)", label: "피드"))
    }
    return result
  }

  var body: some View {
    HStack(spacing: 8) {
      ForEach(Self.metrics(from: profile)) { metric in
        VStack(spacing: 3) {
          Text(metric.value)
            .font(MoyeoTypography.font(size: 17, weight: .bold, relativeTo: .headline))
            .monospacedDigit()
            .foregroundStyle(MoyeoTheme.ink)
          Text(metric.label)
            .font(MoyeoTypography.tinyMeta)
            .foregroundStyle(MoyeoTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(MoyeoTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.softLine))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(metric.label) \(metric.value)")
      }
    }
    .accessibilityIdentifier("my.profileMetrics")
  }
}

private struct ProfileTagPanel: View {
  let profile: ProfileSummary

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("선호 지역")
        .font(.headline)
        .foregroundStyle(MoyeoTheme.ink)
      HStack(spacing: 8) {
        ForEach(profile.favoriteRegions, id: \.self) { region in
          Pill(text: region, tint: MoyeoTheme.forest)
        }
      }

      Divider()

      HStack(spacing: 12) {
        Image(systemName: "leaf.fill")
          .font(.headline)
          .foregroundStyle(MoyeoTheme.forest)
          .frame(width: 38, height: 38)
          .background(MoyeoTheme.leaf)
          .clipShape(Circle())
        VStack(alignment: .leading, spacing: 4) {
          Text("이번 달 추천")
            .font(.subheadline.bold())
            .foregroundStyle(MoyeoTheme.ink)
          Text("문경새재 숲길 힐링 워크가 프로필 취향과 잘 맞아요.")
            .font(.caption)
            .foregroundStyle(MoyeoTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .moyeoCard()
  }
}

/// 28-1 에서 고칠 수 있는 줄. 자기소개는 공개, 생년월일·성별은 비공개 정보다.
private enum ProfileEditField: String, Identifiable {
  case introduction
  case birthDate
  case gender

  var id: String { rawValue }

  var title: String {
    switch self {
    case .introduction: return "자기소개"
    case .birthDate: return "생년월일"
    case .gender: return "성별"
    }
  }
}

/// 28-1 의 한 줄을 고치는 시트. 저장은 `PUT users/me/profile` 한 번으로 끝난다 —
/// 항목별 API 는 없다.
private struct ProfileEditFieldSheet: View {
  let field: ProfileEditField
  @Binding var introduction: String
  @Binding var birthDate: String
  @Binding var gender: String
  let onSave: () -> Void
  let onCancel: () -> Void

  /// 서버 형식은 `yyyy-MM-dd` 다. 값이 없으면 오늘로 시작한다(저장 전까지 서버에 가지 않는다).
  @State private var pickedDate = Date()

  private static let serverFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Button("취소") { onCancel() }
          .font(.subheadline.weight(.bold))
          .foregroundStyle(MoyeoTheme.muted)
        Spacer()
        Text(field.title)
          .font(.subheadline.weight(.heavy))
          .foregroundStyle(MoyeoTheme.ink)
        Spacer()
        Button("저장") {
          if field == .birthDate {
            birthDate = Self.serverFormatter.string(from: pickedDate)
          }
          onSave()
        }
        .font(.subheadline.weight(.heavy))
        .foregroundStyle(MoyeoTheme.forest)
        .accessibilityIdentifier("profile.edit.field.save")
      }
      .padding(.horizontal, 20)
      .frame(height: 56)
      .overlay(alignment: .bottom) { Rectangle().fill(MoyeoTheme.softLine).frame(height: 1) }

      editor
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(20)
    }
    .background(MoyeoTheme.card)
    .onAppear {
      if let parsed = Self.serverFormatter.date(from: birthDate) { pickedDate = parsed }
    }
    .accessibilityIdentifier("profile.edit.field.\(field.rawValue)")
  }

  @ViewBuilder
  private var editor: some View {
    switch field {
    case .introduction:
      VStack(alignment: .leading, spacing: 8) {
        TextEditor(text: $introduction)
          .scrollContentBackground(.hidden)
          .padding(10)
          .frame(minHeight: 120)
          .background(MoyeoTheme.subtleBackground)
          .overlay(RoundedRectangle(cornerRadius: 10).stroke(MoyeoTheme.line))
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
          .accessibilityIdentifier("profile.edit.introductionInput")
        Text("\(introduction.count) / 200")
          .font(.caption2)
          .foregroundStyle(MoyeoTheme.text400)
          .monospacedDigit()
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
    case .birthDate:
      DatePicker("", selection: $pickedDate, displayedComponents: .date)
        .datePickerStyle(.wheel)
        .labelsHidden()
        // 17-2 날짜 시트와 같은 한국어 표기로 맞춘다 (기본값이면 월이 영어로 나온다).
        .environment(\.locale, Locale(identifier: "ko_KR"))
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("profile.edit.birthDatePicker")
    case .gender:
      VStack(spacing: 8) {
        ForEach(AuthGender.allCases) { option in
          Button {
            gender = option.apiValue
          } label: {
            HStack {
              Text(option.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MoyeoTheme.ink)
              Spacer()
              if gender == option.apiValue {
                Image(systemName: "checkmark")
                  .font(.system(size: 13, weight: .heavy))
                  .foregroundStyle(MoyeoTheme.forest)
              }
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .contentShape(Rectangle())
            .background(MoyeoTheme.subtleBackground)
            .overlay(
              RoundedRectangle(cornerRadius: 10)
                .stroke(gender == option.apiValue ? MoyeoTheme.forest : MoyeoTheme.line)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("profile.edit.gender.\(option.rawValue)")
        }
      }
    }
  }
}

/// 프로필 수정의 그룹 제목. 공개/비공개 묶음을 구분한다.
private struct ProfileEditGroupHeader: View {
  let title: String

  init(_ title: String) { self.title = title }

  var body: some View {
    Text(title)
      .font(.caption.weight(.bold))
      .foregroundStyle(MoyeoTheme.muted)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 20)
      .padding(.vertical, 10)
      .background(MoyeoTheme.subtleBackground)
  }
}

/// 라벨 좌측 · 값 우측의 한 줄 행. 카드로 감싸지 않는다 (화면기획).
///
/// 예전에는 `showsChevron` 이 화살표만 그렸고 **누르는 동작이 없었다** — 자기소개·생년월일·성별
/// 세 줄이 눌릴 것처럼 보이면서 아무 일도 하지 않았다. 이제 `action` 이 있는 줄만 화살표를 그린다.
private struct ProfileEditListRow: View {
  let label: String
  let value: String
  var locked = false
  var action: (() -> Void)?

  var body: some View {
    VStack(spacing: 0) {
      if let action {
        Button(action: action) { row }
          .buttonStyle(.plain)
          .accessibilityLabel("\(label) 수정")
      } else {
        row
      }
      Divider().overlay(MoyeoTheme.softLine)
    }
  }

  private var row: some View {
    HStack(spacing: 8) {
      Text(label).font(.subheadline.weight(.bold)).foregroundStyle(MoyeoTheme.ink)
      Spacer(minLength: 8)
      Text(value)
        .font(.subheadline.weight(locked ? .regular : .bold))
        .foregroundStyle(locked ? MoyeoTheme.muted : MoyeoTheme.ink)
        .lineLimit(1)
      // 잠긴 줄은 체크, 누를 수 있는 줄만 화살표. 둘 다 아니면 아이콘을 그리지 않는다.
      if locked {
        Image(systemName: "checkmark")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(MoyeoTheme.text400)
      } else if action != nil {
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(MoyeoTheme.text400)
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
    .contentShape(Rectangle())
  }
}
