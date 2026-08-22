//
//  CourseDetailView.swift
//  MoyeoTrip
//

import SwiftUI

struct CourseDetailView: View {
    let course: TravelCourse
    var tripContext = TripInteractionContext()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTrip: TripRecruitment?
    @State private var supportRoute: SupportRoute?
    @State private var isFavorite = false
    @State private var feedbackMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            CourseDetailHeader(
                isFavorite: isFavorite,
                onBack: { dismiss() },
                onShare: {
                    feedbackMessage = "코스 공유 링크를 복사했어요."
                },
                onToggleFavorite: {
                    isFavorite.toggle()
                    feedbackMessage = isFavorite ? "찜한 코스에 담았어요." : "찜한 코스에서 제외했어요."
                }
            )

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 18) {
                        CourseDetailHero(course: course)

                        if let feedbackMessage {
                            CourseDetailFeedbackBanner(message: feedbackMessage)
                                .padding(.horizontal, 20)
                        }

                        DetailPanel(title: "코스 미리보기") {
                            CourseRouteMap(route: course.stops, mood: course.mood)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("course.detail.bottom")
                    }
                    .padding(.bottom, 132)
                }
                .onAppear {
                    guard UITestScrollDriver.requestedPage > 1 else { return }
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 700_000_000)
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            proxy.scrollTo("course.detail.bottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            CourseDetailBottomBar(
                onCreateRecruitment: {
                    supportRoute = .createRecruitment(course.id)
                },
                onOpenRecruitments: {
                    selectedTrip = tripContext.trips.first { $0.courseID == course.id }
                        ?? MockData.trip(forCourseID: course.id)
                }
            )
        }
        .navigationDestination(item: $selectedTrip) { trip in
            TripDetailView(
                trip: trip,
                isApplied: tripContext.isApplied(trip),
                threadProvider: tripContext.chatThreadProvider,
                onApplied: tripContext.onApplyTrip,
                onSendChatMessage: tripContext.onSendChatMessage
            )
        }
        .navigationDestination(item: $supportRoute) { route in
            SupportDestinationView(
                route: route,
                tripContext: tripContext
            )
        }
        .accessibilityIdentifier("course.detail.\(course.id)")
    }
}

private struct CourseDetailHeader: View {
    let isFavorite: Bool
    let onBack: () -> Void
    let onShare: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        ZStack {
            Text("코스 상세")
                .font(MoyeoTypography.font(size: 16, weight: .bold, relativeTo: .headline))
                .foregroundStyle(MoyeoTheme.ink)

            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 19, weight: .bold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(MoyeoTheme.ink)
                .accessibilityLabel("뒤로")

                Spacer()

                HStack(spacing: 4) {
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .frame(width: 40, height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(MoyeoTheme.ink)
                    .accessibilityLabel("공유")

                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .frame(width: 40, height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isFavorite ? MoyeoTheme.coral : MoyeoTheme.ink)
                    .accessibilityLabel(isFavorite ? "찜 해제" : "찜")
                }
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 12)
        .background(MoyeoTheme.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MoyeoTheme.softLine)
                .frame(height: 1)
        }
    }
}

private struct CourseDetailFeedbackBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption.weight(.heavy))
            .foregroundStyle(MoyeoTheme.forest)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(MoyeoTheme.leaf)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct CourseDetailHero: View {
    let course: TravelCourse

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(course.heroImageAssetName)
                .resizable()
                .scaledToFill()
                .frame(height: 174)
                .frame(maxWidth: .infinity)
                .clipped()
                .accessibilityLabel("\(course.title) 대표 이미지")

            VStack(alignment: .leading, spacing: 13) {
                Text(course.title)
                    .font(MoyeoTypography.font(size: 22, weight: .bold, relativeTo: .title2))
                    .foregroundStyle(MoyeoTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 7) {
                    Pill(text: course.tags.first ?? course.region, tint: course.mood.accent)
                    Pill(text: course.status.rawValue, tint: course.mood.accent)
                    Pill(text: "추천", tint: course.mood.accent)
                }

                if let publishingInfo = course.publishingInfo {
                    CoursePublishingSource(info: publishingInfo)
                }

                Text(course.subtitle)
                    .font(MoyeoTypography.font(size: 13, relativeTo: .subheadline))
                    .foregroundStyle(MoyeoTheme.text700)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 0) {
                    CourseMetricColumn(icon: "clock", label: "소요시간", value: course.duration)
                    CourseMetricColumn(icon: "map", label: "이동거리", value: course.distance)
                    CourseMetricColumn(icon: "star.fill", label: "평점", value: "4.8")
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct CoursePublishingSource: View {
    let info: CoursePublishingInfo

    var body: some View {
        HStack(spacing: 9) {
            MascotAvatar(mascot: info.travelerAvatar, size: 30, background: MoyeoTheme.leaf)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(info.travelerName) 님이 다녀온 코스")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                    .lineLimit(1)
                Text("\(info.publishedAt) · 이 코스로 떠난 모임 \(info.tripCount)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.muted)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Label("여행자 코스", systemImage: "person.fill")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(MoyeoTheme.forest)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(MoyeoTheme.leaf)
                .clipShape(Capsule())
                .fixedSize()
        }
        .padding(11)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MoyeoTheme.softLine, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("course.publishingSource")
    }
}

private struct CourseMetricColumn: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(MoyeoTheme.muted)
            Text(label)
                .font(MoyeoTypography.font(size: 10, weight: .bold, relativeTo: .caption2))
                .foregroundStyle(MoyeoTheme.muted)
            Text(value)
                .font(MoyeoTypography.font(size: 12, weight: .bold, relativeTo: .caption))
                .foregroundStyle(MoyeoTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CourseRouteMap: View {
    let route: [String]
    let mood: CourseMood
    private let mapBackground = adaptiveColor(light: "#DCECE4", dark: "#16251F")
    private let ridgeColor = adaptiveColor(light: "#FFFFFF", dark: "#31423A")
    private let lowlandColor = adaptiveColor(light: "#BED8C4", dark: "#23362E")
    private let pointBackground = adaptiveColor(light: "#FFFFFF", dark: "#1D2C26")
    private let pointTextColor = adaptiveColor(light: "#0F1714", dark: "#E8F5ED")

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                    .fill(mapBackground)

                Canvas { context, size in
                    let routePoints = [0, 1, 2, 3].map { position(for: $0, size: size) }
                    var ridge = Path()
                    ridge.move(to: CGPoint(x: 0, y: size.height * 0.36))
                    ridge.addLine(to: CGPoint(x: size.width, y: size.height * 0.22))
                    context.stroke(
                        ridge,
                        with: .color(ridgeColor.opacity(0.60)),
                        style: StrokeStyle(lineWidth: 30, lineCap: .round)
                    )

                    var lowland = Path()
                    lowland.move(to: CGPoint(x: 0, y: size.height * 0.62))
                    lowland.addLine(to: CGPoint(x: size.width, y: size.height * 0.50))
                    context.stroke(
                        lowland,
                        with: .color(lowlandColor),
                        style: StrokeStyle(lineWidth: 26, lineCap: .round)
                    )

                    var routeLine = Path()
                    routeLine.move(to: routePoints[0])
                    routePoints.dropFirst().forEach { routeLine.addLine(to: $0) }
                    context.stroke(
                        routeLine,
                        with: .color(MoyeoTheme.forest),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
                }

                ForEach(Array(route.prefix(4).enumerated()), id: \.offset) { index, stop in
                    HStack(spacing: 6) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(index == 0 ? MoyeoTheme.coral : mood.accent)
                            .clipShape(Circle())
                        Text(stop)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(pointTextColor)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(pointBackground.opacity(0.88))
                    .clipShape(Capsule())
                    .position(position(for: index, size: proxy.size))
                }
            }
        }
        .frame(height: 146)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("course.route.preview")
    }

    private func position(for index: Int, size: CGSize) -> CGPoint {
        switch index {
        case 0:
            return CGPoint(x: size.width * 0.16, y: size.height * 0.75)
        case 1:
            return CGPoint(x: size.width * 0.40, y: size.height * 0.52)
        case 2:
            return CGPoint(x: size.width * 0.66, y: size.height * 0.32)
        default:
            return CGPoint(x: size.width * 0.74, y: size.height * 0.16)
        }
    }
}

private struct CourseDetailBottomBar: View {
    let onCreateRecruitment: () -> Void
    let onOpenRecruitments: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onCreateRecruitment) {
                Text("이 코스로 모집 만들기")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.forest)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(MoyeoTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                            .stroke(MoyeoTheme.forest, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            Button(action: onOpenRecruitments) {
                Text("모집 중인 모임 보기")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(MoyeoTheme.forest)
                    .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("course.detail.recruitments")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(MoyeoTheme.card)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MoyeoTheme.softLine)
                .frame(height: 1)
        }
    }
}

private struct DetailPanel<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    // 섹션을 카드로 감싸지 않는다 — 화면기획은 제목과 내용만 배경 위에 둔다
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(MoyeoTypography.font(size: 15, weight: .bold, relativeTo: .headline))
                .foregroundStyle(MoyeoTheme.ink)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }
}

private extension TravelCourse {
    var heroImageAssetName: String {
        switch id {
        case "course-cheongsong-juwangsan":
            return "weather_fog_seokguram"
        case "course-andong-hahoe":
            return "weather_rain_hahoe"
        case "course-gyeongju-history":
            return "weather_sunny_cheomseongdae"
        case "course-pohang-drive":
            return "weather_wind_homigot"
        case "course-ulleung-island":
            return "weather_wind_homigot"
        case "course-mungyeong-saejae":
            return "weather_cloudy_bulguksa"
        case "course-yeongju-buseoksa":
            return "weather_snow_buseoksa"
        case "course-andong-dosan":
            return "weather_heatwave_dosan"
        default:
            return "weather_sunny_cheomseongdae"
        }
    }
}
