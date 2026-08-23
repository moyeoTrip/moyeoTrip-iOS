//
//  MyView.swift
//  MoyeoTrip
//

// swiftlint:disable file_length

import SwiftUI

struct MyView: View {
  @Binding var path: NavigationPath
  @State private var selectedSegment = "진행중"

  var tripContext = TripInteractionContext()
  var profile = MockData.profile
  var feedPosts = MockData.feedPosts
  var onAuthenticationRequired: () -> Void = {}
  private let segments = ["진행중", "지난여행", "찜한 코스"]
  // 화면기획 26 마이 — 진행중 카드는 4건(청송 · 안동 · 경주 · 포항)이다
  private var activeTrips: [TripRecruitment] {
    Array(tripContext.trips.prefix(4))
  }
  private let pastTrips = [
    PastTrip(
      courseID: "course-gyeongju-history",
      title: "경주 역사 감성 여행",
      date: "2024.04.12 (금)",
      region: "경주",
      summary: "월정교 야경과 첨성대 단풍길을 함께 걸었어요.",
      mascot: "🌙",
      mood: CourseMood.coral,
      isPublished: false
    ),
    PastTrip(
      courseID: "course-andong-hahoe",
      title: "안동 하회마을 하루 코스",
      date: "2024.03.22 (토)",
      region: "안동",
      summary: "하회마을 골목과 부용대 전망을 천천히 둘러봤어요.",
      mascot: "🏡",
      mood: CourseMood.sunrise,
      isPublished: true
    ),
    PastTrip(
      courseID: "course-ulleung-island",
      title: "울릉도 2박 3일 섬 여행",
      date: "2024.02.18 (일)",
      region: "울릉",
      summary: "해안 산책로와 섬마을 풍경을 여유롭게 남겼어요.",
      mascot: "🌊",
      mood: CourseMood.river,
      isPublished: true
    ),
    PastTrip(
      courseID: "course-mungyeong-saejae",
      title: "문경 새재 단풍 트레킹",
      date: "2023.11.04 (토)",
      region: "문경",
      summary: "완만한 고갯길과 단풍 숲길을 함께 걸었어요.",
      mascot: "🍁",
      mood: CourseMood.blossom,
      isPublished: true
    ),
    PastTrip(
      courseID: "course-pohang-drive",
      title: "포항·영덕 동해 드라이브",
      date: "2023.09.16 (토)",
      region: "포항",
      summary: "바다 전망 카페와 시장 먹거리를 가볍게 이었어요.",
      mascot: "🌉",
      mood: CourseMood.river,
      isPublished: true
    )
  ]

  var body: some View {
    VStack(spacing: 0) {
      MyHeader {
        path.append(MyRoute.settings)
      }

      ScrollView {
        VStack(spacing: 10) {
          NavigationLink(value: MyRoute.profile) {
            MyProfileSummaryCard(profile: profile)
          }
          .buttonStyle(.plain)
          .accessibilityElement(children: .combine)
          .accessibilityLabel("프로필 메뉴")
          .accessibilityIdentifier("my.profileSummary")

          MyProfileStatPills(profile: profile)

          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Text("내 여행")
                .font(MoyeoTypography.sectionTitle)
                .foregroundStyle(MoyeoTheme.ink)
              Spacer()
              Text("\(activeTrips.count)개")
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.forest)
            }

            MySegmentBar(
              segments: segments,
              selectedSegment: $selectedSegment
            )

            MyTravelTabContent(
              selectedSegment: selectedSegment,
              activeTrips: activeTrips,
              pastTrips: pastTrips,
              openCoursePublish: { path.append(SupportRoute.coursePublish) }
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
      case .profile:
        PublicProfileView(profile: profile, onAuthenticationRequired: onAuthenticationRequired)
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
    .accessibilityIdentifier("screen.my")
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

  var body: some View {
    HStack(spacing: 12) {
      AuthenticatedProfileAvatar(profile: profile, size: 58)
      VStack(alignment: .leading, spacing: 4) {
        Text(profile.name)
          .font(MoyeoTypography.cardTitle)
          .foregroundStyle(MoyeoTheme.ink)
          .lineLimit(1)
        Text(profile.oneLineBio)
          .font(MoyeoTypography.cardBody)
          .foregroundStyle(MoyeoTheme.muted)
          .lineLimit(1)
        HStack(spacing: 6) {
          Pill(text: "여행 \(profile.joinedTrips)", tint: MoyeoTheme.forest)
          Pill(text: "매너 \(profile.mannerScoreText)", tint: MoyeoTheme.coral)
        }
        .padding(.top, 4)
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

private struct MyProfileStatPills: View {
  let profile: ProfileSummary

  var body: some View {
    HStack(spacing: 8) {
      MyProfileStatPill(value: "\(profile.joinedTrips)", label: "여행", identifier: "my.stat.joined")
      MyProfileStatPill(value: profile.mannerScoreText, label: "매너", identifier: "my.stat.manner")
      MyProfileStatPill(value: "\(profile.feedCount)", label: "피드", identifier: "my.stat.feed")
    }
  }
}

private struct MyProfileStatPill: View {
  let value: String
  let label: String
  let identifier: String

  var body: some View {
    VStack(spacing: 4) {
      Text(value)
        .font(MoyeoTypography.sectionTitle)
        .foregroundStyle(MoyeoTheme.ink)
        .accessibilityIdentifier("\(identifier).value")
      Text(label)
        .font(.caption.weight(.semibold))
        .foregroundStyle(MoyeoTheme.muted)
        .accessibilityIdentifier("\(identifier).label")
    }
    .frame(maxWidth: .infinity)
    .frame(height: 54)
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
  let pastTrips: [PastTrip]
  let openCoursePublish: () -> Void

  var body: some View {
    VStack(spacing: 10) {
      switch selectedSegment {
      case "진행중":
        ForEach(activeTrips) { trip in
          NavigationLink(value: trip) {
            MyActiveTripCard(trip: trip)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("my.activeTrip.\(trip.id)")
        }
      case "지난여행":
        ForEach(pastTrips) { trip in
          VStack(spacing: 7) {
            NavigationLink(value: trip.course) {
              MyPastTripCard(trip: trip)
            }
            .buttonStyle(.plain)
            if !trip.isPublished {
              Button(action: openCoursePublish) {
                Label("코스 공개하기", systemImage: "map.fill")
                  .font(.caption.weight(.bold))
                  .frame(maxWidth: .infinity, minHeight: 44)
              }
              .buttonStyle(.bordered)
              .tint(MoyeoTheme.forest)
              .accessibilityIdentifier("my.pastTrip.\(trip.courseID).publish")
            }
          }
          .accessibilityIdentifier("my.pastTrip.\(trip.courseID)")
        }
      default:
        ForEach(MockData.courses.dropFirst(2)) { course in
          NavigationLink(value: course) {
            MySavedCourseCard(course: course)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("my.savedCourse.\(course.id)")
        }
      }
    }
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
          MyHubMenuRow(title: "친구 도감", subtitle: "\(MockData.dogamFriends.count)마리 · 최근 동행 순")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("my.friendDexShortcut")
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
          MyHubMenuRow(title: "고객센터", subtitle: "문의와 신고 내역")
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

          ForEach(posts) { post in
            MyFeedPostCard(post: post) {
              selectedPost = post
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
          MascotAvatar(mascot: post.authorAvatar, size: 38, background: MoyeoTheme.leaf)
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

        HStack(spacing: 2) {
          FeedPhotoPreview(post: post, height: 118)
          FeedRouteMap(route: post.route, mood: post.mood)
        }
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
  @State private var selectedTravelStyles: Set<String>
  @State private var selectedInterestRegions: Set<String>
  @State private var isTasteEditorPresented: Bool
  @State private var saveMessage: String?

  init(profile: ProfileSummary, opensTasteEditor: Bool = false) {
    self.profile = profile
    _displayName = State(initialValue: ProfileEditMockData.privateNickname)
    _bio = State(initialValue: ProfileEditMockData.bio)
    _selectedTravelStyles = State(initialValue: TravelTasteSelection.defaultStyles)
    _selectedInterestRegions = State(initialValue: TravelTasteSelection.defaultInterestRegions)
    _isTasteEditorPresented = State(initialValue: opensTasteEditor)
  }

  var body: some View {
    VStack(spacing: 0) {
      CompactDetailHeader(title: "프로필 수정") {
        Button {
          saveMessage = "프로필 변경사항이 저장됐어요."
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
              AuthenticatedProfileAvatar(
                profile: profile,
                size: 96,
                emojiOverride: ProfileEditMockData.privateAvatar
              )
              Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(MoyeoTheme.muted)
                .frame(width: 26, height: 26)
                .background(MoyeoTheme.subtleBackground)
                .clipShape(Circle())
                .overlay(Circle().stroke(MoyeoTheme.line))
            }
            Text(ProfileEditMockData.privateNickname)
              .font(.title3.weight(.heavy))
              .foregroundStyle(MoyeoTheme.ink)
            Text("한 번 정한 친구는 바꿀 수 없어요")
              .font(.caption)
              .foregroundStyle(MoyeoTheme.muted)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 24)

          ProfileEditGroupHeader("공개 프로필")
          ProfileEditListRow(label: "자기소개", value: bio, showsChevron: true)
          ProfileTravelTasteBlock(
            travelStyles: Array(selectedTravelStyles),
            interestRegions: Array(selectedInterestRegions)
          ) {
            isTasteEditorPresented = true
          }

          ProfileEditGroupHeader("비공개 정보")
          // 닉네임과 캐릭터는 선택 후 바꿀 수 없다 — 잠금 표시로 알린다
          ProfileEditListRow(label: "닉네임", value: displayName, locked: true)
          ProfileEditListRow(label: "캐릭터", value: "고정됨", locked: true)
          ProfileEditListRow(label: "생년월일", value: "1998.04.12", showsChevron: true)
          ProfileEditListRow(label: "성별", value: "여성", showsChevron: true)

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
    .sheet(isPresented: $isTasteEditorPresented) {
      ProfileTravelTasteEditSheet(
        travelStyles: $selectedTravelStyles,
        interestRegions: $selectedInterestRegions
      )
      .presentationDetents([.height(720)])
      .presentationDragIndicator(.hidden)
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
}

private struct ProfileTravelTasteBlock: View {
  let travelStyles: [String]
  let interestRegions: [String]
  let action: () -> Void

  private var orderedTravelStyles: [String] {
    TravelTasteSelection.styleOptions.filter(travelStyles.contains)
  }

  private var orderedInterestRegions: [String] {
    TravelTasteSelection.interestRegionOptions.filter(interestRegions.contains)
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
  @Binding private var travelStyles: Set<String>
  @Binding private var interestRegions: Set<String>
  @State private var draftTravelStyles: Set<String>
  @State private var draftInterestRegions: Set<String>

  init(
    travelStyles: Binding<Set<String>>,
    interestRegions: Binding<Set<String>>
  ) {
    _travelStyles = travelStyles
    _interestRegions = interestRegions
    _draftTravelStyles = State(initialValue: travelStyles.wrappedValue)
    _draftInterestRegions = State(initialValue: interestRegions.wrappedValue)
  }

  private var canSave: Bool {
    TravelTasteSelection.isComplete(
      styles: draftTravelStyles,
      interestRegions: draftInterestRegions
    )
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
            options: TravelTasteSelection.styleOptions,
            selectedItems: $draftTravelStyles,
            accessibilityPrefix: "profile.taste.style"
          )
          TravelTasteOptionSection(
            title: "관심 지역",
            requirementHint: "경북 안에서 1곳 이상",
            options: TravelTasteSelection.interestRegionOptions,
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
          CustomerCenterStatusCard()
          CustomerCenterActionRow(
            title: "문의 접수",
            subtitle: "모집, 채팅, 결제 문의를 남겨요",
            badge: "평균 2시간"
          )
          CustomerCenterActionRow(
            title: "신고 내역",
            subtitle: "접수한 신고와 처리 상태를 확인해요",
            badge: "0건"
          )
          CustomerCenterActionRow(
            title: "자주 묻는 질문",
            subtitle: "동행 확정, 환불, 안전 수칙을 빠르게 찾아요",
            badge: "FAQ"
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
      Text("여행 모집과 채팅 중 불편한 점을 남기면 상담함에 바로 접수돼요.")
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

extension ProfileSummary {
  /// 화면기획 26 마이 — 프로필 요약 카드의 한 줄 소개
  fileprivate var oneLineBio: String {
    "자연 속에서 힐링하는 걸 좋아해요!"
  }

  /// 화면기획 25 공개 프로필 — 소개 카드는 두 줄이다
  fileprivate var publicIntro: String {
    "자연과 여행을 사랑합니다 🌿\n새로운 사람들과 함께하는 여행이 좋아요!"
  }

  fileprivate var mannerScoreText: String {
    "4.7"
  }
}

/// 화면기획 28 프로필 수정 — 비공개 정보(닉네임·캐릭터)는 공개 이름과 별개다
private enum ProfileEditMockData {
  static let privateNickname = "따스한 사슴 3492"
  static let privateAvatar = "🦌"
  static let bio = "느긋한 여행 좋아해요"
}

private struct PublicProfileView: View {
  let profile: ProfileSummary
  let onAuthenticationRequired: () -> Void
  @State private var selectedDestination: ProfileDestination?

  var body: some View {
    VStack(spacing: 0) {
      CompactDetailHeader(title: "프로필") {
        Button {
          selectedDestination = .settings
        } label: {
          Label("설정", systemImage: "gearshape.fill")
            .labelStyle(.iconOnly)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(MoyeoTheme.forest)
            .frame(width: 34, height: 34)
            .background(MoyeoTheme.leaf)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profile.settings")
      }

      ScrollView {
        VStack(spacing: 14) {
          // 커버 위에 아바타가 걸치는 공개 프로필 헤더 (화면기획)
          VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
              MoyeoTheme.mapGreen.frame(height: 132)
              AuthenticatedProfileAvatar(profile: profile, size: 74)
                .padding(6)
                .background(MoyeoTheme.leaf)
                .clipShape(Circle())
                .offset(y: 38)
            }
            Spacer().frame(height: 46)
            Text(profile.name)
              .font(.title3.weight(.heavy))
              .foregroundStyle(MoyeoTheme.ink)
            HStack(spacing: 4) {
              Text("매너 점수 4.7점")
                .font(.caption.weight(.bold))
                .foregroundStyle(MoyeoTheme.muted)
              Image(systemName: "star")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MoyeoTheme.muted)
            }
            .padding(.top, 4)
          }

          StatGrid(profile: profile)
            .padding(.horizontal, 18)

          VStack(alignment: .leading, spacing: 6) {
            Text("소개").font(.subheadline.weight(.heavy)).foregroundStyle(MoyeoTheme.ink)
            Text(profile.publicIntro)
              .font(.subheadline)
              .foregroundStyle(MoyeoTheme.muted)
              .fixedSize(horizontal: false, vertical: true)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(14)
          .background(MoyeoTheme.card)
          .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
          .overlay {
            RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
              .stroke(MoyeoTheme.softLine, lineWidth: 1)
          }
          .padding(.horizontal, 18)

          ProfileMenuPanel { destination in
            selectedDestination = destination
          }
        }
        .padding(.bottom, 32)
      }
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
    .navigationDestination(item: $selectedDestination) { destination in
      switch destination {
      case .edit:
        ProfileEditView(profile: profile)
      case .settings:
        SettingsView(onAuthenticationRequired: onAuthenticationRequired)
      case .friends:
        FriendsManagementView()
      case .blocked:
        BlockedUsersView()
      }
    }
    .accessibilityIdentifier("screen.profile")
  }
}

private enum ProfileDestination: String, Identifiable {
  case edit
  case settings
  case friends
  case blocked

  var id: String { rawValue }
}

private struct ProfileMenuPanel: View {
  let onSelect: (ProfileDestination) -> Void

  var body: some View {
    VStack(spacing: 0) {
      ProfileMenuButton(
        title: "내 정보 수정",
        subtitle: "프로필과 여행 취향을 관리해요",
        destination: .edit,
        identifier: "profile.menu.edit",
        onSelect: onSelect
      )
      Divider().padding(.leading, 14)
      ProfileMenuButton(
        title: "친구 관리",
        subtitle: "함께 다녀온 친구와 신청을 관리해요",
        destination: .friends,
        identifier: "profile.menu.friends",
        onSelect: onSelect
      )
      Divider().padding(.leading, 14)
      ProfileMenuButton(
        title: "차단한 사용자",
        subtitle: "차단을 해제하면 다시 만날 수 있어요",
        destination: .blocked,
        identifier: "profile.menu.blocked",
        onSelect: onSelect
      )
    }
    .background(MoyeoTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
        .stroke(MoyeoTheme.softLine, lineWidth: 1)
    }
  }
}

private struct ProfileMenuButton: View {
  let title: String
  let subtitle: String
  let destination: ProfileDestination
  let identifier: String
  let onSelect: (ProfileDestination) -> Void

  var body: some View {
    Button {
      onSelect(destination)
    } label: {
      HStack(spacing: 10) {
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(MoyeoTheme.ink)
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(MoyeoTheme.muted)
            .lineLimit(1)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.caption.bold())
          .foregroundStyle(MoyeoTheme.text400)
      }
      .frame(height: 76)
      .contentShape(Rectangle())
      .padding(.horizontal, 14)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(identifier)
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

  private var filteredFriends: [DogamFriend] {
    MockData.dogamFriends
      .filter { selectedFilter.includes($0) }
      .filter { friend in
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedQuery.isEmpty
          || friend.nickname.localizedCaseInsensitiveContains(trimmedQuery)
      }
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
                  Text("\(filteredFriends.count)")
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
                  title: filter.title,
                  selected: selectedFilter == filter
                ) {
                  selectedFilter = filter
                }
              }
            }

            // 여행이 끝났는데 한 줄 메시지를 안 남긴 친구가 있으면 도감 상단에서 유도한다 (화면기획 27)
            NavigationLink(value: SupportRoute.tripMessage) {
              DogamEmptyBackNoticeCard()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("friendDex.emptyBackNotice")

            if filteredFriends.isEmpty {
              DogamEmptyResultView()
            } else {
              LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(filteredFriends.enumerated()), id: \.element.id) { index, friend in
                  DogamFriendCard(friend: friend)
                    .id(index == 6 ? "friendDex.middle" : friend.id)
                }
              }
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
    .accessibilityIdentifier("screen.friendDex")
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

  func includes(_ friend: DogamFriend) -> Bool {
    switch self {
    case .all:
      return true
    case .repeated:
      return friend.metCount >= 2
    case .recent:
      return friend.lastMetAt.contains("일 전")
    }
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

/// 화면기획 27 상단 안내 — 카드 뒷면(한 줄 메시지)이 비어 있는 친구를 27-1로 유도한다
private struct DogamEmptyBackNoticeCard: View {
  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "square.and.pencil")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(MoyeoTheme.onLeaf)
      VStack(alignment: .leading, spacing: 3) {
        Text("카드 뒷면이 비어 있는 친구 2명")
          .font(.caption.weight(.heavy))
          .foregroundStyle(MoyeoTheme.onLeaf)
        Text("경주 단풍·야경에서 만난 친구들에게 한 줄 남겨볼까요?")
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

extension DogamFriend {
  /// 화면기획 27 — 도감 카드는 "따스한 사슴"처럼 닉네임 앞 두 낱말만 보여준다
  fileprivate var cardLabel: String {
    nickname.split(separator: " ").prefix(2).joined(separator: " ")
  }
}

private struct DogamFriendCard: View {
  let friend: DogamFriend

  var body: some View {
    VStack(spacing: 6) {
      ZStack(alignment: .topTrailing) {
        MascotAvatar(mascot: friend.avatar, size: 44, background: MoyeoTheme.leaf)
        if friend.metCount > 1 {
          Text("\(friend.metCount)x")
            .font(.system(size: 8, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .frame(height: 16)
            .background(MoyeoTheme.forest)
            .clipShape(Capsule())
            .offset(x: 8, y: -5)
        }
      }

      // 카드 라벨은 닉네임 뒤 숫자를 뺀 앞 두 낱말이다 (화면기획 27)
      Text(friend.cardLabel)
        .font(.caption2.weight(.heavy))
        .foregroundStyle(MoyeoTheme.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
      Text(friend.lastMetAt)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(MoyeoTheme.muted)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 92)
    .background(MoyeoTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
        .stroke(friend.id == "dogam-01" ? MoyeoTheme.forest : MoyeoTheme.softLine, lineWidth: 1)
    }
  }
}

private struct SettingsView: View {
  @State private var chatEnabled = true
  @State private var deadlineEnabled = true
  @State private var friendEnabled = true
  @State private var marketingEnabled = false
  @State private var selectedAction: SettingsMockAction?
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
              SettingsValueRow(action: .theme) { selectedAction = $0 }
              SettingsValueRow(action: .language) { selectedAction = $0 }
            }
            .id("settings.middle")

            SettingsSectionGroup("계정") {
              SettingsValueRow(action: .loginMethod) { _ in
                isShowingProviderManagement = true
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
    .accessibilityIdentifier("screen.settings")
  }

  private var accountErrorBinding: Binding<Bool> {
    Binding(
      get: { accountErrorMessage != nil },
      set: { isPresented in
        if !isPresented { accountErrorMessage = nil }
      }
    )
  }

  private func accountAlert(for action: SettingsMockAction) -> Alert {
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

  private func performAccountAction(_ action: SettingsMockAction) {
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

private struct ProviderManagementView: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject var service: AuthProviderLinkService
  @State private var email = ""
  @State private var password = ""
  @State private var isEmailFormExpanded = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          Text("연결된 로그인 수단으로 같은 계정을 안전하게 이용할 수 있어요.")
            .font(MoyeoTypography.cardBody)
            .foregroundStyle(MoyeoTheme.muted)

          ForEach(AuthServiceProvider.connectionOrder) { provider in
            providerCard(provider)
          }

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
        ToolbarItem(placement: .confirmationAction) {
          Button("완료") { dismiss() }
        }
      }
      .task { await service.load() }
    }
    .presentationDetents([.large])
    .accessibilityIdentifier("screen.providerManagement")
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
  let action: SettingsMockAction
  let onTap: (SettingsMockAction) -> Void

  var body: some View {
    Button {
      onTap(action)
    } label: {
      HStack(spacing: 8) {
        Text(action.rowTitle)
          .font(.system(size: 14, weight: .heavy))
          .foregroundStyle(MoyeoTheme.ink)
        Spacer()
        if let value = action.rowValue {
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
  let action: SettingsMockAction
  let onTap: (SettingsMockAction) -> Void

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

private enum SettingsMockAction: Identifiable {
  case notificationDetail
  case theme
  case language
  case loginMethod
  case blockedUsers
  case privacyPolicy
  case terms
  case version
  case contact
  case rate
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
      return "시스템 기본"
    case .language:
      return "한국어"
    case .loginMethod:
      return "관리"
    case .blockedUsers:
      return "2명"
    case .version:
      return "1.0.4 (최신)"
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
    case .blockedUsers:
      return "차단 목록 2명을 확인하고 필요하면 차단을 해제할 수 있어요."
    case .privacyPolicy:
      return "모여트립의 개인정보 수집, 보관, 삭제 기준을 확인하는 문서 화면이에요."
    case .terms:
      return "여행 모집, 채팅, 후기 이용 규칙을 확인하는 약관 화면이에요."
    case .version:
      return "현재 설치된 버전은 1.0.4이며 최신 상태로 표시돼요."
    case .contact:
      return "채팅, 모집, 결제 문의를 남기는 고객센터 진입 화면이에요."
    case .rate:
      return "스토어 평가로 이동하기 전, 모여트립 사용 경험을 확인해요."
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

private struct PastTrip: Identifiable {
  let id = UUID()
  let courseID: String
  let title: String
  let date: String
  let region: String
  let summary: String
  let mascot: String
  let mood: CourseMood
  let isPublished: Bool

  var course: TravelCourse {
    MockData.course(for: courseID) ?? MockData.courses[0]
  }
}

private struct MyPastTripCard: View {
  let trip: PastTrip

  var body: some View {
    MyTravelSummaryCard(
      identifierPrefix: "my.pastTrip.\(trip.courseID)",
      title: trip.title,
      subtitle: trip.summary,
      meta: "\(trip.date) · 여행 기록",
      mascot: trip.mascot,
      mood: trip.mood,
      badge: trip.region
    )
  }
}

private struct MySavedCourseCard: View {
  let course: TravelCourse

  var body: some View {
    MyTravelSummaryCard(
      identifierPrefix: "my.savedCourse.\(course.id)",
      title: course.title,
      subtitle: course.subtitle,
      meta: "\(course.duration) · \(course.distance)",
      mascot: course.mascot,
      mood: course.mood,
      badge: course.region
    )
  }
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

  /// 화면기획 26 마이 — 진행중 카드는 대표 모집만 코스 이름으로 보여준다
  fileprivate var myListTitle: String {
    id == "trip-cheongsong-juwangsan" ? "주왕산 & 주산지 힐링 트레킹" : title
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

private struct DogamPanel: View {
  let onOpenFriendDex: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("지금까지 만난 친구")
            .font(.headline)
            .foregroundStyle(MoyeoTheme.ink)
          Text("\(MockData.dogamFriends.count)마리 · 최근 동행 순")
            .font(.caption)
            .foregroundStyle(MoyeoTheme.muted)
        }
        Spacer()
        Pill(text: "친구에게만", tint: MoyeoTheme.forest)
      }

      ForEach(MockData.dogamFriends.prefix(4)) { friend in
        Button(action: onOpenFriendDex) {
          HStack(spacing: 10) {
            MascotAvatar(mascot: friend.avatar, size: 44, background: MoyeoTheme.leaf)
            VStack(alignment: .leading, spacing: 5) {
              Text(friend.nickname)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)
              Text(friend.lastMetAt)
                .font(.caption)
                .foregroundStyle(MoyeoTheme.muted)
            }
            Spacer()
            if friend.metCount > 1 {
              Pill(text: "\(friend.metCount)x", tint: MoyeoTheme.coral)
            }
            Image(systemName: "chevron.right")
              .font(.caption.bold())
              .foregroundStyle(MoyeoTheme.text400)
          }
          .frame(height: 58)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profile.dogamPreview.\(friend.id)")
      }
    }
    .moyeoCard()
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

private struct AuthenticatedProfileAvatar: View {
  let profile: ProfileSummary
  let size: CGFloat
  /// 화면기획 28처럼 공개 이름과 다른 캐릭터를 보여줘야 하는 화면에서만 쓴다
  var emojiOverride: String?

  var body: some View {
    Group {
      if let url = profile.profileImageURL, emojiOverride == nil {
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
    Text(emojiOverride ?? profile.avatar)
      .font(.system(size: size * 0.48))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

private struct StatGrid: View {
  let profile: ProfileSummary

  var body: some View {
    HStack(spacing: 12) {
      StatCard(title: "여행", value: "\(profile.joinedTrips)", identifier: "profile.stat.joined")
      StatCard(title: "호스트", value: "\(profile.hostedTrips)", identifier: "profile.stat.hosted")
      StatCard(title: "피드", value: "\(profile.feedCount)", identifier: "profile.stat.feed")
    }
  }
}

private struct StatCard: View {
  let title: String
  let value: String
  let identifier: String

  var body: some View {
    VStack(spacing: 8) {
      Text(value)
        .font(.title3.weight(.heavy))
        .foregroundStyle(MoyeoTheme.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityIdentifier("\(identifier).value")
      Text(title)
        .font(.subheadline)
        .foregroundStyle(MoyeoTheme.muted)
        .accessibilityIdentifier("\(identifier).title")
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 18)
    .background(MoyeoTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
        .stroke(MoyeoTheme.line, lineWidth: 1)
    }
  }
}

private struct MyTripRow: View {
  let trip: TripRecruitment

  var body: some View {
    HStack(spacing: 12) {
      MascotAvatar(mascot: trip.coverMascot, size: 50, background: trip.status.tint.opacity(0.14))
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 6) {
          Pill(text: trip.status.rawValue, tint: trip.status.tint)
          Text(trip.schedule)
            .font(.caption.weight(.semibold))
            .foregroundStyle(MoyeoTheme.muted)
            .lineLimit(1)
        }
        Text(trip.title)
          .font(.headline)
          .foregroundStyle(MoyeoTheme.ink)
          .lineLimit(1)
        Text(trip.meetupPoint)
          .font(.caption)
          .foregroundStyle(MoyeoTheme.muted)
          .lineLimit(1)
      }
      Spacer()
      Image(systemName: "chevron.right")
        .font(.caption.bold())
        .foregroundStyle(MoyeoTheme.muted.opacity(0.7))
    }
    .moyeoCard()
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
private struct ProfileEditListRow: View {
  let label: String
  let value: String
  var showsChevron = false
  var locked = false

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        Text(label).font(.subheadline.weight(.bold)).foregroundStyle(MoyeoTheme.ink)
        Spacer(minLength: 8)
        Text(value)
          .font(.subheadline.weight(locked ? .regular : .bold))
          .foregroundStyle(locked ? MoyeoTheme.muted : MoyeoTheme.ink)
          .lineLimit(1)
        Image(systemName: locked ? "checkmark" : "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(MoyeoTheme.text400)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      Divider().overlay(MoyeoTheme.softLine)
    }
  }
}
