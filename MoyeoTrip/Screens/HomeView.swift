//
//  HomeView.swift
//  MoyeoTrip
//

// 실서버 공개 코스 레일이 더해져 길어졌다 — 기존 화면 파일들과 같은 예외를 둔다.
import SwiftUI

struct HomeView: View {
    @Environment(\.moyeoIsOffline) private var isOffline
    @Binding var isBottomNavigationSuppressed: Bool
    @Binding var feedPosts: [FeedPost]
    var tripContext = TripInteractionContext()
    var onAuthCompleted: () -> Void = {}
    var onOpenCourseList: () -> Void = {}
    @State private var supportRoute: SupportRoute?
    /// 실서버 공개 코스 — 로그인 세션이 있고 코스 API가 성공했을 때만 채워진다 (nil = 목데이터)
    @State private var serverCourses: [TravelCourse]?
    private let bottomScrollClearance: CGFloat = 86
    /// 09 히어로의 날씨. 로그인 상태면 서버가 정하고(GET /weather/gyeongbuk),
    /// 아니면 목데이터로 떨어진다. 사용자가 고르는 값이 아니다.
    @State private var serverWeather: ServerGyeongbukWeather?

    private var weatherCondition: WeatherCondition {
        serverWeather?.heroCondition ?? MockData.currentWeatherCondition
    }

    private var recommendedCourses: [TravelCourse] {
        if let serverCourses {
            return Array(serverCourses.prefix(6))
        }
        return Array(
            WeatherCoursePolicy
                .recommendedCourses(for: weatherCondition, courses: MockData.courses)
                .prefix(6)
        )
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                MoyeoHeader(
                    title: "모여트립 in 경북",
                    rightSystemImage: "bell",
                    rightAccessibilityLabel: "알림",
                    isRightActionEnabled: !isOffline,
                    rightDisabledHint: "인터넷에 연결되면 알림을 확인할 수 있어요"
                ) {
                    supportRoute = .notifications
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 18) {
                            if isOffline {
                                OfflineHomeHeroCard()
                            } else {
                                HomeHeroCard(
                                    content: WeatherHeroPolicy.content(for: weatherCondition),
                                    // 시안에 박힌 랜드마크 대신 실제 예보 지점을 보여준다.
                                    place: serverWeather?.locationName
                                )
                            }

                            // 실시간 추천과 인기 순위는 네트워크 없이 만들 수 없다.
                            // 오프라인에서는 저장해둔 코스만 보여준다 (화면기획).
                            if isOffline {
                                OfflineSavedCourseSection()
                                    .id("home.middle")
                            } else {
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("지금 떠나기 좋은 코스")
                                            .font(MoyeoTypography.sectionTitle)
                                            .foregroundStyle(MoyeoTheme.ink)
                                        Spacer()
                                        Button {
                                            onOpenCourseList()
                                        } label: {
                                            Text("더보기 ›")
                                                .font(MoyeoTypography.cardMeta)
                                                .foregroundStyle(MoyeoTheme.muted)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("home.moreCourses")
                                    }
                                    .padding(.horizontal, 18)

                                    if let serverCourses, serverCourses.isEmpty {
                                        // 실서버에 공개된 코스가 아직 없다 — 서버 상태 그대로 보여준다
                                        Text("아직 공개된 코스가 없어요.")
                                            .font(MoyeoTypography.cardMeta)
                                            .foregroundStyle(MoyeoTheme.muted)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 18)
                                            .padding(.vertical, 12)
                                            .accessibilityIdentifier("home.serverCourses.empty")
                                    } else {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 14) {
                                                ForEach(Array(recommendedCourses.enumerated()), id: \.element.id) { index, course in
                                                    NavigationLink(value: course) {
                                                        CourseCard(
                                                            course: course,
                                                            showsStatus: index == 0 && !course.isServerBacked
                                                        )
                                                        .frame(width: 136)
                                                    }
                                                    .buttonStyle(.plain)
                                                    .accessibilityIdentifier("course.card.\(course.id)")
                                                }
                                            }
                                            .padding(.horizontal, 18)
                                            .padding(.bottom, 3)
                                        }
                                    }
                                }
                                .id("home.middle")

                                PopularCourseRanking()
                                    .padding(.horizontal, 18)
                            }

                            Color.clear
                                .frame(height: bottomScrollClearance)
                                .id("home.bottom")

                            if let state = QAScrollState.requested {
                                Color.clear
                                    .frame(height: homeQASpacerHeight(for: state))
                                    .id("home.qa.bottom")
                            }
                        }
                        .padding(.top, 0)
                        .padding(.bottom, 10)
                    }
                    .onAppear {
                        guard let state = QAScrollState.requested else { return }
                        let target = state.targetID(middle: "home.middle", bottom: "home.qa.bottom")
                        Task {
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            proxy.scrollTo(target, anchor: state.anchor)
                        }
                    }
                }
            }

            VStack(alignment: .trailing, spacing: 7) {
                if isOffline {
                    Text("연결 후 모집 만들기")
                        .font(MoyeoTypography.tinyMeta)
                        .foregroundStyle(MoyeoTheme.warningText)
                        .padding(.horizontal, 9)
                        .frame(height: 26)
                        .background(MoyeoTheme.warningBackground)
                        .clipShape(Capsule())
                        .accessibilityHidden(true)
                }

                Button {
                    supportRoute = .createRecruitment(recommendedCourses.first?.id ?? MockData.courses[0].id)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(isOffline ? MoyeoTheme.text400 : MoyeoTheme.forest)
                        .clipShape(Circle())
                        .shadow(
                            color: isOffline ? .clear : MoyeoTheme.forest.opacity(0.28),
                            radius: 18,
                            x: 0,
                            y: 10
                        )
                }
                .buttonStyle(.plain)
                .disabled(isOffline)
                .accessibilityLabel("모집 만들기")
                .accessibilityHint(isOffline ? "인터넷에 연결되면 사용할 수 있어요" : "")
                .accessibilityIdentifier("home.floatingPlus")
            }
            .padding(.trailing, 20)
            .padding(.bottom, 86)
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
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
        .navigationDestination(item: $supportRoute) { route in
            SupportDestinationView(
                route: route,
                tripContext: tripContext,
                feedPosts: $feedPosts,
                onAuthCompleted: onAuthCompleted
            )
        }
        .navigationDestination(for: SupportRoute.self) { route in
            SupportDestinationView(
                route: route,
                tripContext: tripContext,
                feedPosts: $feedPosts,
                onAuthCompleted: onAuthCompleted
            )
        }
        .task {
            guard MoyeoServerSync.isEnabled, serverWeather == nil else { return }
            // 날씨는 실패해도 목데이터 히어로가 그대로 뜬다 — 화면을 비우지 않는다.
            serverWeather = try? await WeatherAPIClient.shared.gyeongbuk()
        }
        .task {
            guard MoyeoServerSync.isEnabled, serverCourses == nil else { return }
            // 인기 코스를 먼저, 비어 있으면 공개 코스 전체를 쓴다
            if let popular = try? await TravelCourseAPIClient.shared.popularCourses(), !popular.isEmpty {
                serverCourses = popular.map(ServerCourseMapper.course(from:))
            } else if let publicCourses = try? await TravelCourseAPIClient.shared.publicCourses() {
                serverCourses = publicCourses.map(ServerCourseMapper.course(from:))
            }
        }
        .onAppear {
            isBottomNavigationSuppressed = supportRoute != nil
        }
        .onChange(of: supportRoute) { _, route in
            isBottomNavigationSuppressed = route != nil
        }
        .onDisappear {
            if supportRoute == nil {
                isBottomNavigationSuppressed = false
            }
        }
        .accessibilityIdentifier("screen.home")
    }

    private func homeQASpacerHeight(for state: QAScrollState) -> CGFloat {
        switch state {
        case .bottom:
            return 36
        case .middle:
            return 180
        }
    }
}

private struct CourseCard: View {
    let course: TravelCourse
    let showsStatus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let thumbnailURL = course.thumbnailURL {
                    CachedRemoteImage(url: thumbnailURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        MoyeoTheme.leaf
                    }
                    .frame(height: 86)
                    .clipped()
                } else if course.isServerBacked {
                    MoyeoTheme.leaf
                        .frame(height: 86)
                } else {
                    MoyeoPhotoTile(
                        mascot: course.mascot,
                        mood: course.mood,
                        height: 86,
                        cornerRadius: 0
                    )
                }
            }
            .overlay(alignment: .topLeading) {
                if showsStatus {
                    Pill(text: "진행중", tint: .white)
                        .background(Capsule().fill(MoyeoTheme.forest))
                        .padding(7)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(course.title)
                    .font(MoyeoTypography.chip)
                    .foregroundStyle(MoyeoTheme.ink)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                    Text(course.peopleText)
                        .font(MoyeoTypography.cardMeta)
                        .lineLimit(1)
                }
                .foregroundStyle(MoyeoTheme.muted)
            }
            .frame(height: 64, alignment: .topLeading)
            .padding(10)
        }
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                .stroke(MoyeoTheme.softLine, lineWidth: 1)
        }
    }
}

extension TravelCourse {
    var peopleText: String {
        switch id {
        case "course-cheongsong-juwangsan":
            return "2/5명"
        case "course-andong-hahoe":
            return "3/6명"
        case "course-gyeongju-history":
            return "4/6명"
        case "course-ulleung-island":
            return "1/5명"
        default:
            // 서버 코스는 지역명을 내려주지 않는다 — 이동 거리를 대신 보여준다
            return region.isEmpty ? distance : region
        }
    }
}

struct TripRecruitmentCard: View {
    let trip: TripRecruitment

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                MascotAvatar(
                    mascot: trip.coverMascot,
                    size: 56,
                    background: trip.status.tint.opacity(0.14)
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Pill(text: trip.status.rawValue, tint: trip.status.tint)
                        Pill(text: trip.region, tint: MoyeoTheme.forest)
                    }
                    Text(trip.title)
                        .font(.headline)
                        .foregroundStyle(MoyeoTheme.ink)
                        .lineLimit(2)
                    if let course = MockData.course(for: trip.courseID) {
                        Label(course.title, systemImage: "map.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MoyeoTheme.text400)
                            .lineLimit(1)
                    }
                    Text(trip.summary)
                        .font(.subheadline)
                        .foregroundStyle(MoyeoTheme.muted)
                        .lineLimit(2)
                }

                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(MoyeoTheme.muted.opacity(0.7))
                    .padding(.top, 6)
            }

            HStack(spacing: 8) {
                MetricChip(icon: "calendar", text: trip.schedule)
                MetricChip(icon: "mappin.and.ellipse", text: trip.meetupPoint)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ParticipantStack(participants: trip.participants)
                    Spacer()
                    Text("\(trip.joined)/\(trip.capacity)명 · 최소 \(trip.minimumParticipants)명")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MoyeoTheme.muted)
                }
                ProgressBar(value: trip.progress, tint: trip.status.tint, marker: trip.minimumProgress)
                if !trip.hasMetMinimumParticipants {
                    Text("출발 확정까지 \(trip.needsMoreParticipants)명 남았어요")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MoyeoTheme.coral)
                }
            }
        }
        .moyeoCard()
    }
}

private struct LocalTipCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "sparkles")
                .font(.title3.bold())
                .foregroundStyle(MoyeoTheme.coral)
                .frame(width: 40, height: 40)
                .background(MoyeoTheme.coral.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 7) {
                Text("오늘의 경북 힌트")
                    .font(.headline)
                    .foregroundStyle(MoyeoTheme.ink)
                Text("낯선 지역 모임은 집결지와 쉬는 시간을 먼저 확인하면 더 편하게 참여할 수 있어요.")
                    .font(.subheadline)
                    .foregroundStyle(MoyeoTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .moyeoCard()
    }
}
