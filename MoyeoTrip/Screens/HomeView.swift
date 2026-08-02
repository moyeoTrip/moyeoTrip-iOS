//
//  HomeView.swift
//  MoyeoTrip
//

import SwiftUI

struct HomeView: View {
    @Binding var isBottomNavigationSuppressed: Bool
    @Binding var feedPosts: [FeedPost]
    var tripContext = TripInteractionContext()
    var showsAuthFlowEntry = false
    var onAuthCompleted: () -> Void = {}
    var onOpenCourseList: () -> Void = {}
    @State private var supportRoute: SupportRoute?
    private let bottomScrollClearance: CGFloat = 86
    private let weatherCondition = MockData.currentWeatherCondition

    private var recommendedCourses: [TravelCourse] {
        Array(
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
                    rightAccessibilityLabel: "알림"
                ) {
                    supportRoute = .notifications
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 18) {
                            if showsAuthFlowEntry {
                                AuthFlowEntryButton {
                                    supportRoute = .authFlow
                                }
                                .padding(.horizontal, 18)
                            }

                            HomeHeroCard(content: WeatherHeroPolicy.content(for: weatherCondition))

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

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 14) {
                                        ForEach(Array(recommendedCourses.enumerated()), id: \.element.id) { index, course in
                                            NavigationLink(value: course) {
                                                CourseCard(course: course, showsStatus: index == 0)
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
                            .id("home.middle")

                            PopularCourseRanking()
                                .padding(.horizontal, 18)

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

            Button {
                supportRoute = .createRecruitment(recommendedCourses.first?.id ?? MockData.courses[0].id)
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
            .padding(.trailing, 20)
            .padding(.bottom, 86)
            .accessibilityLabel("모집 만들기")
            .accessibilityIdentifier("home.floatingPlus")
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

private struct AuthFlowEntryButton: View {
    let action: () -> Void

    var body: some View {
        let label = "회원가입 · 로그인 체험"

        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MoyeoTheme.forest)
                    .frame(width: 24, height: 24)
                    .background(MoyeoTheme.leaf)
                    .clipShape(Circle())

                Text(label)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(MoyeoTheme.text400)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(MoyeoTheme.card)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(MoyeoTheme.softLine, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier("home.authFlowEntry")
    }
}

private struct HomeHeroCard: View {
    let content: WeatherHeroContent
    private let weatherTags = ["맑음", "구름", "비", "눈", "안개", "강풍", "폭우", "폭염", "미세먼지"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("이번 주말, 어디로 떠나볼까요?")
                        .font(MoyeoTypography.sectionTitle)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(content.copy)
                        .font(MoyeoTypography.cardBody)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("home.weatherHero.copy")
                }
                Spacer(minLength: 10)
                Text(content.badge)
                    .font(MoyeoTypography.chip)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(.white.opacity(0.18))
                    .clipShape(Capsule())
            }

            WeatherHeroImage(content: content)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(weatherTags, id: \.self) { tag in
                        WeatherTagPill(
                            text: tag,
                            selected: tag == content.label,
                            selectedForeground: content.state.cardColor
                        )
                    }
                }
            }
        }
        .padding(14)
        .background(content.state.cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 18)
        .accessibilityIdentifier("home.weatherHero")
    }
}

private struct WeatherTagPill: View {
    let text: String
    let selected: Bool
    let selectedForeground: Color

    var body: some View {
        Text(text)
            .font(MoyeoTypography.tab)
            .foregroundStyle(selected ? selectedForeground : .white)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(selected ? .white.opacity(0.94) : .white.opacity(0.10))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(selected ? 1 : 0.34), lineWidth: 1)
            }
    }
}

private struct WeatherHeroImage: View {
    let content: WeatherHeroContent

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(content.imageAssetName)
                .resizable()
                .scaledToFill()
                .frame(height: 130)
                .clipped()
                .accessibilityIdentifier("home.weatherHero.image.\(content.imageAssetName)")
                .accessibilityLabel("\(content.label) 날씨 \(content.place) 이미지")
            Text("\(content.label) · \(content.place)")
                .font(MoyeoTypography.cardMeta)
                .foregroundStyle(content.state.selectedPillForeground)
                .lineLimit(1)
                .padding(.horizontal, 11)
                .frame(height: 30)
                .background(content.state.selectedPillBackground)
                .clipShape(Capsule())
                .padding(8)
        }
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct CourseCard: View {
    let course: TravelCourse
    let showsStatus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MoyeoPhotoTile(
                mascot: course.mascot,
                mood: course.mood,
                height: 86,
                cornerRadius: 0
            )
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
            return region
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
