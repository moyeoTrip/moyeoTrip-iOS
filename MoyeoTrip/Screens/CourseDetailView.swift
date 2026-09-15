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
    /// 찜 상태는 **서버가 아는 값**이다. 아직 못 읽었으면 `nil` 이라 하트를 채우지 않는다.
    /// 예전에는 로컬 `@State` 토글만 바꾸고 「찜한 코스에 담았어요」를 띄워,
    /// 서버에는 아무것도 저장되지 않은 채 성공처럼 보였다 (IOS-F14·F93).
    @State private var isFavorite: Bool?
    @State private var isTogglingFavorite = false
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
                isFavorite: isFavorite ?? false,
                isFavoriteEnabled: displayCourse.serverCourseID != nil && !isTogglingFavorite,
                onBack: { dismiss() },
                onToggleFavorite: toggleFavorite
            )

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 18) {
                        CourseDetailHero(course: displayCourse) { userID, info in
                            supportRoute = .publicProfile(
                                .serverUser(
                                    ProfileCardUserReference(
                                        userID: userID,
                                        nickname: info.travelerName,
                                        profileImageUrl: info.travelerAvatarURL?.absoluteString
                                    )
                                )
                            )
                        }

                        if let feedbackMessage {
                            CourseDetailFeedbackBanner(message: feedbackMessage)
                                .padding(.horizontal, 20)
                        }

                        // 방문지 좌표가 있을 때만 실지도를 그린다 — 좌표가 없으면 섹션째 숨긴다
                        if !displayCourse.itinerary.isEmpty {
                            DetailPanel(title: "코스 미리보기") {
                                CourseRouteMap(stops: displayCourse.itinerary)
                            }

                            // **방문지 목록**. 기획·웹·안드로이드에는 있는데 iOS 에만 없어서
                            // 지도만 보고 어디를 도는지 알 수 없었다 (사용자 지적, 2026-09-09).
                            DetailPanel(title: "방문지 \(displayCourse.itinerary.count)곳") {
                                VStack(spacing: 10) {
                                    ForEach(displayCourse.itinerary) { stop in
                                        CourseStopRow(stop: stop) { placeID in
                                            supportRoute = .placeDetail(placeID)
                                        }
                                    }
                                }
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
            guard MoyeoServerSync.isEnabled, let courseID = course.serverCourseID else { return }
            if serverDetail == nil,
               let detail = try? await TravelCourseAPIClient.shared.courseDetail(courseID: courseID) {
                serverDetail = ServerCourseMapper.course(from: detail)
            }
            // 코스 상세 응답에는 내 찜 여부가 없다 — 찜 목록으로 판단한다 (BE-26).
            if isFavorite == nil,
               let liked = try? await TravelCourseAPIClient.shared.likedCourses() {
                isFavorite = liked.contains { $0.courseId == courseID }
            }
        }
        .accessibilityIdentifier("course.detail.\(course.id)")
    }

    private func toggleFavorite() {
        guard let courseID = displayCourse.serverCourseID, !isTogglingFavorite else { return }
        isTogglingFavorite = true
        feedbackMessage = nil
        Task {
            defer { isTogglingFavorite = false }
            do {
                let result = try await TravelCourseAPIClient.shared.toggleFavorite(courseID: courseID)
                isFavorite = result.favorite
                feedbackMessage = result.favorite ? "찜한 코스에 담았어요." : "찜한 코스에서 제외했어요."
            } catch {
                feedbackMessage = error.moyeoUserMessage(
                    fallback: "찜을 저장하지 못했어요. 잠시 후 다시 시도해주세요."
                )
            }
        }
    }
}

private struct CourseDetailHeader: View {
    let isFavorite: Bool
    /// 서버 코스가 아니면 찜할 곳이 없다 — 누를 수 있게 두고 아무 일도 안 하는 대신 잠근다.
    let isFavoriteEnabled: Bool
    let onBack: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        ZStack {
            Text("코스 상세")
                .font(MoyeoTypography.font(size: 16, weight: .bold, relativeTo: .headline))
                .foregroundStyle(MoyeoTheme.ink)

            HStack {
                Button(action: onBack) {
                    // ENV-009 / NAV-017 — 그림에만 반응하던 것을 틀 전체로 넓힌다
                    Image(systemName: "chevron.left")
                        .font(.system(size: 19, weight: .bold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(MoyeoTheme.ink)
                .accessibilityLabel("뒤로")

                Spacer()

                // 결정 ⑬ — 공유 진입점을 뺐다. 공개 URL 규격이 없어 공유 본문에 링크가
                // 한 줄도 없었다(EXTRA-003). 「준비 중」 안내로 바꾸지 않고 버튼 자체를 없앤다.
                // 찜 버튼이 제자리(오른쪽 끝)를 그대로 지킨다.
                HStack(spacing: 4) {
                    Button(action: onToggleFavorite) {
                        // ENV-009 — 찜도 같다 (재던 값 15x14pt)
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!isFavoriteEnabled)
                    .foregroundStyle(isFavorite ? MoyeoTheme.coral : MoyeoTheme.ink)
                    .accessibilityLabel(isFavorite ? "찜 해제" : "찜")
                    .accessibilityIdentifier("course.detail.favorite")
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
    /// 작성자 프로필로 보내는 길. 작성자 userId 가 공개됐을 때만 불린다 (BE-29).
    let onOpenCreatorProfile: (Int64, CoursePublishingInfo) -> Void

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
                    // 작성자 userId 를 공개한 코스에서만 25 공개 프로필로 보낸다 (BE-29).
                    // 공개하지 않았으면 누를 수 있는 모양조차 주지 않는다.
                    if let creatorUserID = publishingInfo.travelerUserID {
                        Button {
                            onOpenCreatorProfile(creatorUserID, publishingInfo)
                        } label: {
                            CoursePublishingSource(info: publishingInfo)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("course.detail.creatorProfile")
                        .accessibilityHint("\(publishingInfo.travelerName) 님의 프로필 보기")
                    } else {
                        CoursePublishingSource(info: publishingInfo)
                    }
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
