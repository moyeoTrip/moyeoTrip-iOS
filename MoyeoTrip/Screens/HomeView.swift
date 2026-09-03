//
//  HomeView.swift
//  MoyeoTrip
//

// 실서버 공개 코스 레일이 더해져 길어졌다 — 기존 화면 파일들과 같은 예외를 둔다.
import SwiftUI

struct HomeView: View {
    @Environment(\.moyeoIsOffline) private var isOffline
    /// 날씨·코스는 화면 밖 보관소에 있다 — 탭을 다녀와도 이미 받은 값을 즉시 그린다
    /// (TAB-STATE-CANON R1). 홈은 그 값을 보여주면서 뒤에서 갱신한다 (R3).
    @ObservedObject var tabData: MoyeoTabDataStore
    @Binding var isBottomNavigationSuppressed: Bool
    @Binding var feedPosts: [FeedPost]
    var tripContext = TripInteractionContext()
    var onAuthCompleted: () -> Void = {}
    var onOpenCourseList: () -> Void = {}
    @State private var supportRoute: SupportRoute?
    private let bottomScrollClearance: CGFloat = 86

    /// 히어로 날씨. 서버 응답이 오기 전에는 날씨를 지어내지 않는다 — 히어로 카드는 값이 온 뒤에 그린다.
    private var weatherCondition: WeatherCondition? {
        tabData.homeWeather?.heroCondition
    }

    /// 추천 코스는 서버 공개 코스뿐이다. 못 받으면 빈 목록이고 §2 빈 상태를 그린다.
    private var recommendedCourses: [TravelCourse] {
        Array((tabData.homeCourses ?? []).prefix(6))
    }

    /// 캐시가 없고 처음 받아오는 중일 때만 로딩 문구를 띄운다 (R2).
    /// 이미 코스를 받아 뒀으면 갱신 중이라도 그 목록을 계속 보여준다 (R3).
    private var isLoadingCoursesWithoutCache: Bool {
        tabData.homeCourses == nil && tabData.isLoadingHomeCourses
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
                            } else if let weatherCondition {
                                HomeHeroCard(
                                    content: WeatherHeroPolicy.content(for: weatherCondition),
                                    // 시안에 박힌 랜드마크 대신 실제 예보 지점을 보여준다.
                                    place: tabData.homeWeather?.locationName
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

                                    if isLoadingCoursesWithoutCache {
                                        Text(MoyeoEmptyText.loading)
                                            .font(MoyeoTypography.cardMeta)
                                            .foregroundStyle(MoyeoTheme.muted)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 18)
                                            .padding(.vertical, 12)
                                            .accessibilityIdentifier("home.serverCourses.loading")
                                    } else if recommendedCourses.isEmpty {
                                        // 서버가 준 코스만 그린다 — 없으면 그 상태를 그대로 보여준다
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
                                                ForEach(recommendedCourses) { course in
                                                    NavigationLink(value: course) {
                                                        CourseCard(course: course)
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

                                PopularCourseRanking(
                                    courses: tabData.homePopularCourses,
                                    isLoading: tabData.isLoadingHomePopularCourses
                                )
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
                    supportRoute = .createRecruitment(recommendedCourses.first?.id ?? "")
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
        // 홈은 재진입할 때마다 뒤에서 갱신한다 — 가진 값은 그대로 그린 채다 (R3).
        .task { await tabData.refreshHomeWeather() }
        .task { await tabData.refreshHomeCourses() }
        .task { await tabData.refreshHomePopularCourses() }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let thumbnailURL = course.thumbnailURL {
                    CachedRemoteImage(url: thumbnailURL, fallbackShape: .landscape) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        MoyeoTheme.leaf
                    }
                    .frame(height: 86)
                    .clipped()
                } else {
                    // 서버가 썸네일을 주지 않은 코스 — 빈 판 대신 공용 플레이스홀더를 쓴다
                    MoyeoPlaceholderImageView(shape: .landscape)
                        .frame(height: 86)
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
    /// 서버 코스는 지역명을 내려주지 않는다 — 이동 거리를 대신 보여준다.
    /// 코스별 모집 인원은 서버가 주지 않아 지어내지 않는다.
    var peopleText: String {
        region.isEmpty ? distance : region
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
