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
  /// 값은 탭 바깥(`MoyeoTabDataStore`)에 둔다 — 화면 안에 두면 탭을 떠날 때 사라져서
  /// 돌아올 때마다 줄이 없어졌다가 다시 생긴다 (TC NAV-011).
  private var myMetrics: ServerPublicProfile? { tabData.myMetrics }

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
              serverRooms: serverRooms,
              didFailServerRooms: tabData.didFailMyRooms,
              onRetryServerRooms: { Task { await tabData.refreshMy() } }
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
      // 당겨서 새로고침 — 정본 TAB-STATE-CANON R4.
      .refreshable { await tabData.refreshMy() }
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
    // 「지난여행」 카드에서 끝난 방을 읽기 전용으로 연다 (IOS-F81).
    .navigationDestination(for: ChatThread.self) { thread in
      ChatRoomView(thread: thread)
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
  /// 내 카드도 **남의 카드와 똑같은 경로**로 만든다.
  ///
  /// 예전에는 `.me` 라는 별도 분기가 있었는데, 그 분기가 공개 프로필을 합치지 않아
  /// 내 카드에만 매너 점수·여행·피드가 없었다. 항목을 하나씩 맞추는 대신 **분기를 없앴다** —
  /// 두 경로가 있으면 언제든 다시 어긋난다. 이제 내 카드도 `serverUser` 로 들어가
  /// `GET users/{id}/profile` · `travel-reviews` 를 같은 코드로 받는다.
  private var myProfileSubject: ProfileCardSubject {
    guard let serverProfile else { return .unavailable }
    // 내 userId 는 액세스 토큰에서 동기로 읽는다 (TAB-STATE-CANON R6).
    // 없으면 공개 프로필을 못 받아 **항목이 빠진 카드**가 되므로 빈 상태로 둔다 —
    // 반쪽 카드를 그리는 것보다 정직하다.
    guard let userID = MoyeoCurrentUser.id else { return .unavailable }
    return .serverUser(
      ProfileCardUserReference(
        userID: userID,
        nickname: serverProfile.nickname,
        profileImageUrl: serverProfile.profileImageUrl,
        introduction: serverProfile.introduction,
        nicknameColor: serverProfile.nicknameColor
      )
    )
  }

  /// 내 신원은 액세스 토큰에서 동기로 읽는다 (TAB-STATE-CANON R6).
  /// 못 받으면 지표 줄을 그리지 않는다 — 숫자를 지어내지 않는다.
  private func loadMyMetrics() async {
    await tabData.loadMyMetricsIfNeeded()
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
  /// 내 모임 조회가 **실패**했는지. 빈 목록과 갈라야 한다.
  var didFailServerRooms = false
  /// 실패 줄의 「다시 시도」.
  var onRetryServerRooms: () -> Void = {}

  var body: some View {
    // 찜 두 탭은 **내 모임 목록과 무관한 API** 를 쓴다. 예전에는 `serverRooms` 가 있어야
    // 닿을 수 있어서, 내 모임 조회가 실패하면 찜해 둔 게 있어도 찜 탭까지
    // 「참여 중인 모임이 없어요.」로 덮였다.
    if selectedSegment == "찜한 모집" {
      VStack(spacing: 10) { FavoriteRoomsSection() }
    } else if selectedSegment == "찜한 코스" {
      VStack(spacing: 10) { FavoriteCoursesSection() }
    } else if let serverRooms {
      serverContent(rooms: serverRooms)
    } else if didFailServerRooms {
      // 실패를 빈 목록으로 그리지 않는다 — 참여 중인 모임이 있어도 없는 것처럼 보였다.
      VStack(spacing: 10) {
        MoyeoEmptyStateView(
          message: MoyeoEmptyText.loadFailed,
          onRetry: onRetryServerRooms,
          accessibilityIdentifier: "my.serverTrip.failed"
        )
      }
    } else {
      sessionContent
    }
  }

  @ViewBuilder
  private func serverContent(rooms: [ServerMyChatRoom]) -> some View {
    let filtered = selectedSegment == "지난여행" ? rooms.filter(\.ended) : rooms.filter { !$0.ended }

    VStack(spacing: 10) {
      if filtered.isEmpty {
        // 두 세그먼트가 **같은 문구**를 썼다 — 「지난여행」이 비었을 때 「참여 중인 채팅방이
        // 없어요」는 지난 여행이 없다는 뜻으로 읽히지 않는다 (IOS-F43).
        MoyeoEmptyStateView(
          message: selectedSegment == "지난여행"
            ? "아직 끝난 여행이 없어요. 여행이 끝나면 여기에 남아요."
            : MoyeoEmptyText.noChatRooms,
          accessibilityIdentifier: "my.serverTrip.empty"
        )
      } else {
        ForEach(filtered) { room in
          if room.ended {
            // 끝난 방도 **읽기 전용 채팅방으로 열린다**(`isReadOnly: !chatAvailable || ended`).
            // 예전에는 「이동할 상세가 없다」며 카드만 그려서, 지난 여행의 사진·정산·여행
            // 마무리에 마이 탭에서 닿을 길이 아예 없었다 (IOS-F81).
            NavigationLink(value: ServerTripMapper.stubThread(serverRoomID: room.roomId)) {
              MyServerTripCard(room: room)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("my.serverTrip.\(room.roomId)")
          } else if room.chatAvailable {
            // **채팅이 열린 방은 채팅방으로 간다.** 예전에는 `chatAvailable` 을 읽기 전용 판정에만
            // 쓰고 이동은 늘 모집 상세여서, 이미 확정된 내 여행을 눌러도 「함께 가기 신청」
            // 화면이 열렸다 (IOS-F44). 상세 응답에는 이 값이 없지만 **목록 응답에는 있다**
            // (`ServerMyChatRoom.chatAvailable` — 상세 쪽은 `BE-23` 으로 요청돼 있다).
            NavigationLink(value: ServerTripMapper.stubThread(serverRoomID: room.roomId)) {
              MyServerTripCard(room: room)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("my.serverTrip.\(room.roomId)")
          } else {
            // 아직 채팅이 열리지 않은 방(모집 중·승인 대기)은 모집 상세가 맞다.
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
    // 큰 글자에서 높이를 못박으면 카드 안에서 상태·인원 줄이 겹쳐 읽힌다 (TC ENV-005).
    // 기본 크기에서는 지금과 같은 높이이고, 글자가 커질 때만 카드가 따라 늘어난다.
    .frame(minHeight: MyTravelCardMetrics.activeHeight)
    .moyeoListCard()
  }
}

private struct MyHubMenuPanel: View {
  let openRoute: (MyRoute) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("메뉴")
        // 고정 크기(.system(size:))는 글자 크기 설정을 따르지 않는다 — 큰 글자에서
        // 이 라벨만 작게 남아 아래 항목과 겹쳐 보였다 (TC ENV-005).
        .font(MoyeoTypography.font(size: 18, weight: .heavy, relativeTo: .title3))
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
    // 결정 ⑪ — 사진 영역만 `Button` 밖으로 뺀다. `Button` 안에 `TabView(.page)` 를
    // 넣으면 탭이 삼켜져 카드를 눌러도 상세로 가지 않는다. 그래서 카드를 위(머리)·
    // 사진·아래(본문) 세 덩이로 나누고, 사진 말고는 예전처럼 `Button` 이 받는다.
    // 사진 탭도 `onTap` 으로 같은 `onOpen` 을 부른다 — 어디를 눌러도 상세로 간다.
    VStack(alignment: .leading, spacing: 12) {
      Button(action: onOpen) {
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
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(post.feedTitle)
      .accessibilityIdentifier("my.feedPost.\(post.id)")

      // 피드 경로에는 좌표가 없다 — 손으로 그린 경로 지도를 옆에 두지 않는다 (R4)
      photoArea

      Button(action: onOpen) {
        VStack(alignment: .leading, spacing: 12) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("my.feedPost.\(post.id).body")
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

  /// 사진 영역. 여러 장이면 상세와 같은 페이저로 좌우로 넘긴다 (결정 ⑪).
  /// 한 장이면 페이저도 배지도 만들지 않고 예전처럼 한 장만 그린다.
  @ViewBuilder
  private var photoArea: some View {
    Group {
      if post.photoURLs.count > 1 {
        FeedCardPhotoPager(
          photoURLs: post.photoURLs,
          height: 118,
          identifierPrefix: "my.feedPost.\(post.id)",
          onTap: onOpen
        )
      } else {
        FeedPhotoPreview(post: post, height: 118)
          .contentShape(Rectangle())
          .onTapGesture(perform: onOpen)
      }
    }
    .frame(height: 118)
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
  /// 저장 결과가 **성공인지 실패인지.** 예전에는 둘 다 같은 `saveMessage` 에 담겨
  /// 실패도 「저장 완료」라는 제목으로 떴다 (IOS-F47).
  @State private var didSaveSucceed = true
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
            didSaveSucceed = true
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
            // 자물쇠 배지를 달지 않는다. 닉네임 아래 "바꿀 수 없어요" 경고도 두지 않는다 —
            // 고칠 수 없다는 사실은 아래 **비공개 정보**의 `닉네임`·`캐릭터` 줄에 잠금 표시로
            // 이미 있다. 들어오자마자 큰 자물쇠와 경고로 맞이하면 압박으로 읽힌다.
            //
            // 아바타는 닉네임에서 계산한다 (R5). `emojiOverride` 를 주면 서버 프로필
            // 이미지까지 무시되므로 여기서는 주지 않는다.
            AuthenticatedProfileAvatar(profile: profile, size: 96)
            Text(displayName)
              .font(.title3.weight(.heavy))
              .foregroundStyle(MoyeoTheme.ink)
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
      didSaveSucceed ? "저장 완료" : "저장하지 못했어요",
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
      didSaveSucceed = false
      saveMessage = "서버 프로필을 불러오지 못해 저장할 수 없어요."
      return
    }
    // 서버는 생년월일을 반드시 요구한다 — 아직 등록되지 않았으면 그 줄부터 채우게 안내한다.
    guard !birthDate.isEmpty else {
      didSaveSucceed = false
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
        didSaveSucceed = true
        saveMessage = "프로필 변경사항이 저장됐어요."
      } catch {
        didSaveSucceed = false
        saveMessage = error.moyeoUserMessage(fallback: "저장하지 못했어요. 잠시 후 다시 시도해주세요.")
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
          // 화살표를 두지 않는다 — 기획·웹·안드로이드는 「탭해서 바로 수정」 문구만 둔다.
          // iOS 만 chevron 이 붙어 있어 4열 비교에서 이 줄만 달라 보였다 (28, 2026-09-09).
          Text("탭해서 바로 수정")
            .font(.caption.weight(.semibold))
            .foregroundStyle(MoyeoTheme.muted)
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
    // 제목은 칩 **위**에 둔다. 예전에는 왼쪽에 붙여 한 줄로 놓았는데,
    // 기획·웹·안드로이드는 셋 다 위에 두므로 iOS 만 줄바꿈이 달라 보였다 (28, 2026-09-09).
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(MoyeoTheme.muted)
      HStack(spacing: 6) {
        // 고른 칩은 **꽉 찬 초록**이다 (기획·웹 `variant="primary"` · 안드 `colors.primary`).
        // 예전에는 `selectionSurface` + 초록 글자라 iOS 만 옅은 칩으로 찍혔다.
        ForEach(items, id: \.self) { item in
          Text(item)
            .font(.caption.weight(.heavy))
            .foregroundStyle(MoyeoTheme.onLeaf)
            .padding(.horizontal, 11)
            .frame(height: 27)
            .background(MoyeoTheme.leaf)
            .clipShape(Capsule())
        }
        Text("+ 추가")
          .font(.caption.weight(.heavy))
          .foregroundStyle(MoyeoTheme.muted)
          .padding(.horizontal, 11)
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
  /// 열지 못했을 때의 안내. `mailto:` 는 메일 앱이 없으면 **아무 일도 일어나지 않는다** —
  /// 사용자는 버튼이 고장 난 줄 안다 (TC SOCIAL-037). 그때는 주소를 눌러 복사하게 둔다.
  @State private var openFailureMessage: String?

  var body: some View {
    Button {
      // `openURL` 의 완료 콜백으로 실제 결과를 받는다. 성공하면 아무 말도 하지 않는다.
      openURL(url) { accepted in
        guard !accepted else {
          openFailureMessage = nil
          return
        }
        UIPasteboard.general.string = subtitle
        openFailureMessage = "이 기기에서 바로 열 수 없어서 「\(subtitle)」를 복사해 뒀어요."
      }
    } label: {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 5) {
          Text(title)
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(MoyeoTheme.ink)
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(MoyeoTheme.muted)
          if let openFailureMessage {
            Text(openFailureMessage)
              .font(.caption2)
              .foregroundStyle(MoyeoTheme.warningText)
              .fixedSize(horizontal: false, vertical: true)
              .accessibilityIdentifier("\(identifier).openFailed")
          }
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
    // 큰 글자에서 높이를 못박으면 줄이 위 칸(섹션 라벨)까지 밀고 올라와 겹친다 (TC ENV-005).
    .frame(minHeight: 58)
    .padding(.vertical, 6)
    .padding(.horizontal, 16)
    .contentShape(Rectangle())
  }
}

private struct MySegmentBar: View {
  let segments: [String]
  @Binding var selectedSegment: String
  /// 큰 글자에서는 네 칸을 화면 폭에 균등 분할할 수 없다 — 「찜한 코스」·「찜한 모집」이
  /// 둘 다 「찜…」으로 잘려 **어느 탭인지 구분할 수 없었다** (TC ENV-005).
  /// 그 크기에서는 균등 분할을 포기하고 가로 스크롤로 바꿔 이름을 끝까지 보여준다.
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    if dynamicTypeSize.isAccessibilitySize {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 4) {
          ForEach(segments, id: \.self) { segment in
            chip(segment, fillsWidth: false)
          }
        }
        .padding(4)
      }
      .background(MoyeoTheme.subtleBackground)
      .clipShape(Capsule())
    } else {
      HStack(spacing: 4) {
        ForEach(segments, id: \.self) { segment in
          chip(segment, fillsWidth: true)
        }
      }
      .padding(4)
      .background(MoyeoTheme.subtleBackground)
      .clipShape(Capsule())
    }
  }

  /// 높이를 `height` 로 못박으면 큰 글자에서 글자가 캡슐 밖으로 넘친다 — 최소 높이로 둔다.
  private func chip(_ segment: String, fillsWidth: Bool) -> some View {
    Button {
      selectedSegment = segment
    } label: {
      Text(segment)
        .font(MoyeoTypography.tab)
        .lineLimit(1)
        .foregroundStyle(selectedSegment == segment ? MoyeoTheme.forest : MoyeoTheme.muted)
        .padding(.horizontal, fillsWidth ? 0 : 14)
        .frame(maxWidth: fillsWidth ? .infinity : nil)
        .frame(minHeight: 36)
        .background(selectedSegment == segment ? MoyeoTheme.card : .clear)
        .clipShape(Capsule())
    }
    .buttonStyle(.plain)
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
        // ENV-009 — 화살표 그림 크기는 그대로 두고 누를 넓이만 44x44 로 넓힌다
        Image(systemName: "chevron.left")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(MoyeoTheme.ink)
          .frame(width: 44, height: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      // ENV-006: 라벨이 없으면 VoiceOver 가 영어 시스템 문구(「Back」)로 읽는다.
      .accessibilityLabel("뒤로")

      Spacer()

      Text(title)
        .font(.subheadline.weight(.heavy))
        .foregroundStyle(MoyeoTheme.ink)

      Spacer()

      // ENV-009 — 뒤로 버튼이 44 로 넓어진 만큼 오른쪽 자리도 44 로 맞춘다(제목 가운데 정렬 유지).
      // 이 자리에 들어오는 버튼의 누를 넓이도 함께 44x44 가 된다.
      trailing()
        .frame(width: 44, height: 44)
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
  /// 도감 조회가 **실패**했는지. 「없다」와 「못 받았다」를 구분한다 —
  /// 예전에는 `try?` 로 삼켜 통신 실패가 「검색 결과가 없어요」로 읽혔다
  /// (TC SOCIAL-010 계열 · 안드 `AFTER-017` 교차).
  @State private var didFailDex = false

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

  /// 도감을 받아 온다. 실패는 **빈 도감이 아니라 실패로** 남긴다.
  private func loadServerDex() async {
    didFailDex = false
    do {
      serverDex = try await SocialAPIClient.shared.travelDex()
    } catch {
      didFailDex = true
    }
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
            } else if didFailDex {
              // **못 받은 것**이지 친구가 없는 게 아니다. 예전에는 이 자리에도
              // 「검색 결과가 없어요 / 이름이나 필터를 바꿔 다시 찾아보세요」가 떠서,
              // 통신이 끊긴 것을 사용자가 자기 검색어 탓으로 읽었다.
              MoyeoEmptyStateView(
                message: MoyeoEmptyText.loadFailed,
                onRetry: { Task { await loadServerDex() } },
                accessibilityIdentifier: "friendDex.failed"
              )
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
      await loadServerDex()
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
      // 27 도감의 동행 날짜는 **요일을 붙이지 않는다** — 웹·안드로이드가 `2026.09.12` 이고
      // iOS 만 `2026.09.12 (토)` 였다. 25 프로필 카드 뒷면도 이미 요일 없이 그린다
      // (`ProfileCardCompanion.dateText`). `displayDate` 는 일정 날짜용이라 그대로 둔다.
      Text(ProfileCardCompanion.dateText(companion.latestTripDate))
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

  /// 서버 도감을 아직 못 받았을 때 쓰는 이름. **수를 지어내지 않는다** (NO-MOCK-CANON R1).
  ///
  /// 예전에는 여기서 「전체 12」·「2회 이상 4」·「최근 1개월 3」을 **박아 돌려줬다** —
  /// 조회가 끝나기 전이나 실패했을 때 실제 사용자에게도 늘 그 숫자가 보였고,
  /// 「지금까지 만난 친구 0마리」 옆에 「전체 12」가 나란히 떴다.
  /// 같은 화면의 「카드 뒷면이 비어 있는 친구 2명」 하드코딩과 같은 부류다.
  var title: String {
    switch self {
    case .all:
      return "전체"
    case .repeated:
      return "2회 이상"
    case .recent:
      return "최근 1개월"
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
  /// 차단 인원. 서버에서 읽기 전에는 `nil` 이라 숫자를 그리지 않는다 (IOS-F22·F33).
  @State private var blockedUserCount: Int?
  /// 알림 설정 저장 실패를 알린다. 예전에는 `try?` 로 삼켜 꺼진 줄 알았던 알림이 살아 있었다 (IOS-F59).
  @State private var notificationSaveError: String?
  /// 알림 설정 **조회**가 실패했는지. 못 받았는데 화면 기본값(세 토글 모두 켜짐)을 그대로 그리면
  /// 서버가 확인해 준 내 설정으로 읽힌다 — 실패를 확정값으로 그리는 것은 목데이터와 같다
  /// (NO-MOCK-CANON R1). 실패는 실패라고 말하고 다시 시도를 준다.
  @State private var didFailServerNotificationSettings = false
  @State private var selectedAction: SettingsRow?
  /// 29 설정 › 화면 › 테마. 행을 탭하면 시스템 기본 → 라이트 → 다크 순으로 순환한다.
  @ObservedObject private var themeStore = MoyeoThemeStore.shared
  @State private var isPerformingAccountAction = false
  @State private var accountErrorMessage: String?
  @State private var isShowingProviderManagement = false
  /// 「문의하기」 행이 여는 두 창구 선택지 (GitHub 이슈 · 이메일).
  @State private var isShowingContactOptions = false
  /// 창구를 열지 못했을 때의 안내. 값이 있으면 알림으로 보여준다.
  @State private var contactOpenFailure: String?
  @Environment(\.openURL) private var openURL

  private var contactOpenFailureBinding: Binding<Bool> {
    Binding(get: { contactOpenFailure != nil }, set: { if !$0 { contactOpenFailure = nil } })
  }

  /// 창구를 연다. 열지 못하면 **주소를 클립보드에 넣고** 그 사실을 알린다 —
  /// `mailto:` 는 메일 앱이 없으면 아무 일도 일어나지 않아 버튼이 고장 난 것처럼 보였다.
  private func openContact(_ url: URL, copying fallbackText: String) {
    openURL(url) { accepted in
      guard !accepted else { return }
      UIPasteboard.general.string = fallbackText
      contactOpenFailure = "이 기기에서 바로 열 수 없어서 「\(fallbackText)」를 복사해 뒀어요."
    }
  }
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
              SettingsValueRow(action: .notificationDetail, valueOverride: quietHoursRowValue) { _ in
                supportRoute = .notificationDetail
              }
              if didFailServerNotificationSettings {
                MoyeoEmptyStateView(
                  message: MoyeoEmptyText.loadFailed,
                  onRetry: { Task { await loadServerNotificationSettings() } },
                  accessibilityIdentifier: "settings.notification.loadFailed"
                )
                .padding(.vertical, 10)
              }
              if let notificationSaveError {
                Text(notificationSaveError)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(MoyeoTheme.dangerRed)
                  .fixedSize(horizontal: false, vertical: true)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.horizontal, 16)
                  .padding(.vertical, 10)
                  .accessibilityIdentifier("settings.notification.saveError")
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
              SettingsValueRow(action: .blockedUsers, valueOverride: blockedUsersRowValue) { _ in
                supportRoute = .blockedUsers
              }
              SettingsValueRow(action: .privacyPolicy) { _ in
                supportRoute = .legalDocument(.privacyPolicy)
              }
              SettingsValueRow(action: .terms) { _ in
                supportRoute = .legalDocument(.service)
              }
            }

            SettingsSectionGroup("정보") {
              SettingsValueRow(action: .version) { selectedAction = $0 }
              // 「문의하기」는 안내만 하고 끝나면 안 된다 — 예전에는 「닫기」 하나뿐이라
              // 어디로 문의하는지 읽고도 갈 곳이 없었다 (TC SET-028).
              // 웹은 같은 다이얼로그 안에 GitHub·이메일 두 링크를 둔다. 그대로 맞춘다.
              SettingsValueRow(action: .contact) { _ in isShowingContactOptions = true }
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
    // 29 설정 「문의하기」 — 실제로 열리는 두 창구. 값은 `MoyeoContact` 한 곳에서 온다.
    .confirmationDialog("문의하기", isPresented: $isShowingContactOptions, titleVisibility: .visible) {
      Button(MoyeoContact.issuesLabel) { openContact(MoyeoContact.issuesURL, copying: MoyeoContact.issuesURL.absoluteString) }
      Button(MoyeoContact.emailLabel) { openContact(MoyeoContact.mailtoURL, copying: MoyeoContact.email) }
      Button("닫기", role: .cancel) {}
    } message: {
      Text(MoyeoContact.dialogBody)
    }
    // 열지 못했을 때(메일 앱 없음 등)만 뜬다 — 조용히 실패하지 않는다 (TC SOCIAL-037).
    .alert("바로 열 수 없어요", isPresented: contactOpenFailureBinding) {
      Button("확인", role: .cancel) { contactOpenFailure = nil }
    } message: {
      Text(contactOpenFailure ?? "")
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

  /// 방해금지 행의 값 — **서버 설정 그대로**. 아직 못 읽었으면 아무 값도 적지 않는다.
  private var quietHoursRowValue: String? {
    guard let settings = serverDNDSettings else { return nil }
    guard settings.doNotDisturbEnabled,
          let start = settings.doNotDisturbStartTime,
          let end = settings.doNotDisturbEndTime else { return "방해금지 꺼짐" }
    return "방해금지 \(Self.hourMinute(start))~\(Self.hourMinute(end))"
  }

  /// `"22:30:00"` · `"22:30"` 어느 쪽으로 와도 `22:30` 으로 줄인다.
  private static func hourMinute(_ value: String) -> String {
    value.split(separator: ":").prefix(2).joined(separator: ":")
  }

  /// 차단 인원 — 서버에서 읽은 수만 적는다.
  private var blockedUsersRowValue: String? {
    blockedUserCount.map { "\($0)명" }
  }

  private func advanceTheme() {
    themeStore.advance()
  }

  /// 29-2 알림 설정 — 채팅 모드·3개 토글은 프로필 응답에, 방해 금지는 알림 설정 응답에 있다
  private func loadServerNotificationSettings() async {
    guard MoyeoServerSync.isEnabled, !isServerSettingsLoaded else { return }
    didFailServerNotificationSettings = false
    guard let profile = try? await UserProfileAPIClient.shared.myProfile() else {
      didFailServerNotificationSettings = true
      return
    }
    serverChatMode = profile.chatNotificationMode
    chatEnabled = profile.chatNotificationMode != "NONE"
    deadlineEnabled = profile.recruitmentDeadlineEnabled
    friendEnabled = profile.socialActivityEnabled
    marketingEnabled = profile.marketingEnabled
    serverDNDSettings = try? await NotificationAPIClient.shared.settings()
    blockedUserCount = (try? await SocialAPIClient.shared.blockedUsers())?.count
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
      do {
        serverDNDSettings = try await NotificationAPIClient.shared.updateSettings(update)
        notificationSaveError = nil
      } catch {
        // 껐다고 생각한 알림이 살아 있으면 안 된다 — 실패를 말하고 화면을 서버 값으로 되돌린다.
        notificationSaveError = error.moyeoUserMessage(
          fallback: "알림 설정을 저장하지 못했어요. 잠시 후 다시 시도해주세요."
        )
        isServerSettingsLoaded = false
        await loadServerNotificationSettings()
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
          error.moyeoUserMessage(fallback: "잠시 후 다시 시도해주세요.")
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

          if service.hasLoadedProviders {
            ForEach(AuthServiceProvider.connectionOrder) { provider in
              providerCard(provider)
            }
          } else if service.isLoading {
            MoyeoEmptyStateView(
              message: MoyeoEmptyText.loading,
              accessibilityIdentifier: "providers.loading"
            )
          } else {
            // **못 받은 것을 「모두 연결되지 않음」으로 그리지 않는다.** 그렇게 그리면
            // 이미 연결된 방식에까지 「연결하기」가 붙어, 사용자는 연결이 풀린 줄 안다
            // (TC SET-023). 다시 받을 길만 준다.
            MoyeoSectionRetryNotice(
              message: "연결된 로그인 방식을 불러오지 못했어요.",
              identifier: "providers.list"
            ) {
              Task { await service.load() }
            }
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
    // 연결 버튼은 **줄 오른쪽에 작게** 둔다 (웹과 같은 배치, 사용자 지적 2026-09-09).
    // 예전에는 줄 아래에 폭을 꽉 채우는 큰 버튼이 붙어 카드 하나가 세 줄 높이였고,
    // 웹은 한 줄이라 같은 화면이 플랫폼마다 두 배 길이로 찍혔다.
    // 색은 그대로 둔다 — 카카오 노랑·Apple 흑백·Google 외곽선은 각 사업자의 브랜드 규정이다.
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 12) {
        ProviderManagementMark(provider: provider)
        VStack(alignment: .leading, spacing: 2) {
          Text(provider.providerName)
            .font(MoyeoTypography.cardTitle)
            .foregroundStyle(MoyeoTheme.ink)
          // 부제는 **연결 상태**만 말한다. 예전에는 사업자별 안내 문구였는데
          // 웹은 「연결되지 않음」이라 같은 줄이 플랫폼마다 다른 말을 했다 (29-5, 2026-09-09).
          Text(isConnected ? "연결됨" : "연결되지 않음")
            .font(MoyeoTypography.cardMeta)
            .foregroundStyle(isConnected ? MoyeoTheme.forest : MoyeoTheme.muted)
        }
        Spacer(minLength: 8)
        if isConnected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(MoyeoTheme.forest)
        } else {
          providerAction(provider, isConnected: isConnected)
        }
      }

      // 이메일만 입력이 필요해 줄 아래로 펼친다 — 나머지는 눌러서 바로 사업자 화면으로 간다.
      if provider == .email, !isConnected, isEmailFormExpanded {
        emailConnectionForm
      }
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

  /// 줄 오른쪽의 작은 연결 버튼. 문구는 네 표면 모두 「연결하기」다 (기획 `ScreenAccountProviders`).
  @ViewBuilder
  private func providerAction(_ provider: AuthServiceProvider, isConnected: Bool) -> some View {
    if provider == .email {
      AuthProviderButton(
        provider: .email,
        isDisabled: service.isLoading || service.linkingProvider != nil,
        showsMark: false,
        titleOverride: isEmailFormExpanded ? "입력 닫기" : "연결하기",
        accessibilityIdentifierOverride: "providers.email.link",
        isCompact: true
      ) {
        withAnimation(.easeInOut(duration: 0.18)) {
          isEmailFormExpanded.toggle()
        }
      }
    } else {
      AuthProviderButton(
        provider: provider,
        isLoading: service.linkingProvider == provider,
        isDisabled: service.isLoading || service.linkingProvider != nil,
        showsMark: false,
        titleOverride: "연결하기",
        accessibilityIdentifierOverride: "providers.\(provider.pathComponent).link",
        isCompact: true
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
      // 닫기는 줄 오른쪽 버튼이 겸한다 — 같은 동작을 두 곳에 두지 않는다.
      emailSubmitButton
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

  /// **서버에서 읽어야 하는 값은 여기에 적지 않는다.** 예전에는 방해금지 시간대와
  /// 차단 인원이 「방해금지 22:30~07:00」·「2명」으로 박혀 있어, 서버 값과 무관하게
  /// 늘 같은 숫자가 보였다 (IOS-F22·F33·F60, NO-MOCK-CANON R1).
  /// 그 두 행은 `SettingsView` 가 `valueOverride` 로 실제 값을 넘긴다.
  var rowValue: String? {
    switch self {
    case .theme:
      // 캡처 기본값. 실제 값은 SettingsView 가 사용자 설정으로 덮어쓴다.
      return MoyeoThemeMode.system.rowValue
    case .language:
      return "한국어"
    case .loginMethod:
      return "관리"
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
      // 「고객센터」는 존재하지 않는 개념이다(정본 changeLog14 · `MoyeoContact`).
      // 웹·안드로이드는 이미 이 문구로 바꿨는데 iOS 만 옛 문구가 남아 있었다.
      return MoyeoContact.dialogBody
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
          // 마감 근거가 없으면 배지를 그리지 않는다 (NO-MOCK-CANON R1).
          if !trip.ddayText.isEmpty {
            Pill(text: trip.ddayText, tint: MoyeoTheme.coral)
          }
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
    // 큰 글자에서 높이를 못박으면 카드 안에서 상태·인원 줄이 겹쳐 읽힌다 (TC ENV-005).
    // 기본 크기에서는 지금과 같은 높이이고, 글자가 커질 때만 카드가 따라 늘어난다.
    .frame(minHeight: MyTravelCardMetrics.activeHeight)
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

  /// 26 마이 진행중 카드의 마감 배지. **서버가 준 마감값에서만 뽑는다.**
  ///
  /// 예전에는 화면 id 로 갈라 `D-3`·`D-5` 를 돌려주고 나머지는 전부 `D-1` 이었다 —
  /// 서버가 알려준 적 없는 마감일이라 목데이터다 (NO-MOCK-CANON R1).
  /// `recruitmentDeadline` 은 `ServerChatRoomTripMapper.deadlineText` 가 만든
  /// `"D-17 · 9/9"` 꼴이라 앞머리만 떼어 쓰고, 근거가 없으면 **빈 문자열**이다
  /// (카드가 배지를 그리지 않는다).
  fileprivate var ddayText: String {
    guard let head = recruitmentDeadline.split(separator: "·").first else { return "" }
    let text = head.trimmingCharacters(in: .whitespaces)
    return text.hasPrefix("D-") ? text : ""
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

  /// 서버 `PUT /users/me/profile` 의 `introduction` 한도 (`size must be between 0 and 300`).
  private static let introductionLimit = 300

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
        // 카운터는 **서버 한도와 같아야 한다.** 예전에는 `/ 200` 이라 적어 두고 자르지도 않아,
        // 201~300자는 「넘었다」고 붉게 적히는데 저장은 되고, 301자부터는 서버가
        // `size must be between 0 and 300` 으로 막았다 (IOS-F48, 실서버 확인 2026-09-13).
        TextEditor(
          text: Binding(
            get: { introduction },
            set: { introduction = String($0.prefix(Self.introductionLimit)) }
          )
        )
          .scrollContentBackground(.hidden)
          .padding(10)
          .frame(minHeight: 120)
          .background(MoyeoTheme.subtleBackground)
          .overlay(RoundedRectangle(cornerRadius: 10).stroke(MoyeoTheme.line))
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
          .accessibilityIdentifier("profile.edit.introductionInput")
        Text("\(introduction.count) / \(Self.introductionLimit)")
          .font(.caption2)
          .foregroundStyle(
            introduction.count >= Self.introductionLimit ? MoyeoTheme.dangerRed : MoyeoTheme.text400
          )
          .monospacedDigit()
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
    case .birthDate:
      // 상한을 걸지 않으면 2439년까지 고를 수 있었고, 저장해야 서버가
      // 「과거 날짜여야 합니다」로 거절했다 (TC MY-015). 가입 플로우는 이미
      // `KoreanBirthdatePolicy` 로 최소 연령까지 막고 있는데 프로필 편집만 빠져 있었다.
      DatePicker(
        "",
        selection: $pickedDate,
        in: ...KoreanBirthdatePolicy.latestAllowedBirthdate(),
        displayedComponents: .date
      )
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
      // 라벨은 줄이지 않는다 — 값이 길면(자기소개 등) 라벨이 먼저 눌려 줄바꿈될 수 있다.
      // 웹에서 실제로 「자/기/소/개」로 세로로 쪼개진 것을 봤다. 값만 줄임표로 줄인다.
      Text(label)
        .font(.subheadline.weight(.bold))
        .foregroundStyle(MoyeoTheme.ink)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
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
