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
    /// 실서버 코스 상세 — 목록에 없는 작성자·연결된 모임 수가 여기서 온다 (14)
    @State private var serverDetail: TravelCourse?
    /// 14 `모집 중인 모임 보기` — `GET /travel-courses/{courseId}/chat-rooms` (정본 §4)
    @State private var showsRecruitments = false

    /// 서버 상세를 받았으면 그것으로 그린다. 실패하면 들어올 때 받은 코스를 그대로 유지한다.
    private var displayCourse: TravelCourse {
        serverDetail ?? course
    }

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
                        CourseDetailHero(course: displayCourse)

                        if let feedbackMessage {
                            CourseDetailFeedbackBanner(message: feedbackMessage)
                                .padding(.horizontal, 20)
                        }

                        // 방문지 좌표가 있을 때만 실지도를 그린다 — 좌표가 없으면 섹션째 숨긴다
                        if !displayCourse.itinerary.isEmpty {
                            DetailPanel(title: "코스 미리보기") {
                                CourseRouteMap(stops: displayCourse.itinerary)
                            }
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
                    // 이 코스로 열린 모집은 서버가 준다 — 세션이 아는 모집만 뒤지지 않는다 (정본 §4).
                    // 서버 코스가 아니면(목데이터 진입) 물어볼 곳이 없어 세션 목록으로 남는다.
                    if course.serverCourseID != nil {
                        showsRecruitments = true
                    } else {
                        selectedTrip = tripContext.trips.first { $0.courseID == course.id }
                    }
                }
            )
        }
        .navigationDestination(isPresented: $showsRecruitments) {
            if let courseID = course.serverCourseID {
                CourseRecruitmentsView(
                    courseID: courseID,
                    courseTitle: displayCourse.title,
                    tripContext: tripContext
                )
            }
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
        .task {
            guard MoyeoServerSync.isEnabled, let courseID = course.serverCourseID, serverDetail == nil else { return }
            if let detail = try? await TravelCourseAPIClient.shared.courseDetail(courseID: courseID) {
                serverDetail = ServerCourseMapper.course(from: detail)
            }
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
            Group {
                if let thumbnailURL = course.thumbnailURL {
                    // 실서버 코스 — 서버가 준 대표 썸네일을 그린다
                    CachedRemoteImage(url: thumbnailURL, fallbackShape: .landscape) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        MoyeoTheme.leaf
                    }
                } else {
                    // 코스 히어로는 이미지가 필수인 자리다 — 없으면 빈 썸네일만 둔다
                    MoyeoPlaceholderImageView(shape: .landscape)
                }
            }
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
                    if let firstTag = course.tags.first ?? (course.region.isEmpty ? nil : course.region) {
                        Pill(text: firstTag, tint: course.mood.accent)
                    }
                    Pill(text: course.status.rawValue, tint: course.mood.accent)
                }

                if let publishingInfo = course.publishingInfo {
                    CoursePublishingSource(info: publishingInfo)
                }

                if !course.subtitle.isEmpty {
                    Text(course.subtitle)
                        .font(MoyeoTypography.font(size: 13, relativeTo: .subheadline))
                        .foregroundStyle(MoyeoTheme.text700)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 0) {
                    CourseMetricColumn(icon: "clock", label: "소요시간", value: course.duration)
                    CourseMetricColumn(icon: "map", label: "이동거리", value: course.distance)
                    // 평점 — 평가가 없으면 서버가 null을 준다. 값을 지어내지 않는다.
                    if let rating = course.serverAverageRating {
                        CourseMetricColumn(
                            icon: "star.fill",
                            label: "평점",
                            value: String(format: "%.1f", rating)
                        )
                    } else {
                        CourseMetricColumn(icon: "star", label: "평점", value: "아직 없음")
                    }
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
            // 서버가 작성자 프로필 이미지를 주면 **반드시 이미지**다 (2026-09-02 추가).
            // `null` 일 때만 닉네임에서 유도한 마스코트로 떨어진다.
            if let avatarURL = info.travelerAvatarURL {
                CachedRemoteImage(url: avatarURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    MoyeoTheme.leaf
                }
                .frame(width: 30, height: 30)
                .clipShape(Circle())
                .accessibilityIdentifier("course.detail.creatorAvatarImage")
            } else {
                MascotAvatar(mascot: info.travelerAvatar, size: 30, background: MoyeoTheme.leaf)
            }

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

/// 14 코스 미리보기 — 방문지 좌표를 실제 카카오 지도에 순번 마커 + 경로선으로 그린다.
/// 좌표가 없는 방문지가 하나라도 있으면 그리지 않는다 (NO-MOCK-CANON R4).
private struct CourseRouteMap: View {
    let stops: [ItineraryStop]

    private var routeMarkers: [MoyeoMapMarker] {
        stops.compactMap { stop in
            guard let coordinate = MoyeoMapCoordinate(latitude: stop.latitude, longitude: stop.longitude) else {
                return nil
            }
            return MoyeoMapMarker(id: stop.id, coordinate: coordinate, order: stop.order)
        }
    }

    var body: some View {
        let markers = routeMarkers
        if markers.count == stops.count, let first = markers.first {
            MoyeoMapView(
                content: MoyeoMapContent(
                    center: first.coordinate,
                    level: 11,
                    markers: markers,
                    polyline: markers.map(\.coordinate)
                ),
                isInteractive: false,
                fallback: { MoyeoTheme.mapGreen }
            )
            .frame(height: 146)
            .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("코스 경로 지도, 방문지 \(stops.count)곳")
            .accessibilityIdentifier("course.route.preview")
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
