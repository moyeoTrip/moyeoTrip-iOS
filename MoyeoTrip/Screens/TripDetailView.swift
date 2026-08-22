//
//  TripDetailView.swift
//  MoyeoTrip
//

import SwiftUI

// The detail screen keeps its local presentation components beside the owning view.
// swiftlint:disable file_length

struct TripDetailView: View {
    let trip: TripRecruitment
    var isApplied = false
    var threadProvider: (TripRecruitment) -> ChatThread? = { MockData.chatThread(forTripID: $0.id) }
    var onApplied: (TripRecruitment) -> Void = { _ in }
    var onSendChatMessage: (ChatThread, ChatMessage) -> Void = { _, _ in }
    @Environment(\.dismiss) private var dismiss
    @State private var isApplicationPresented = false
    @State private var selectedThread: ChatThread?
    @State private var isFavorite = false
    @State private var didApplyInSession = false
    @State private var feedbackMessage: String?

    private var appliedState: Bool {
        isApplied || didApplyInSession
    }

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    ScrollView {
                        VStack(spacing: 0) {
                            TripDetailHero(
                                trip: trip,
                                onBack: {
                                    dismiss()
                                },
                                onRefresh: {
                                    feedbackMessage = "최신 모집 정보를 확인했어요."
                                }
                            )
                            if let feedbackMessage {
                                TripDetailFeedbackBanner(message: feedbackMessage)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 12)
                            }
                            TripDetailPanel(trip: trip)
                                .padding(.top, feedbackMessage == nil ? -28 : 12)
                        }
                        .frame(width: proxy.size.width)
                        .padding(.bottom, 128)
                    }

                    TripDetailBottomBar(
                        canJoin: trip.canJoin,
                        actionTitle: trip.applicationActionTitle,
                        isApplied: appliedState,
                        isFavorite: isFavorite,
                        onToggleFavorite: {
                            isFavorite.toggle()
                            feedbackMessage = isFavorite ? "찜한 코스에 담았어요." : "찜한 코스에서 제외했어요."
                        },
                        onApply: {
                            if appliedState {
                                selectedThread = threadProvider(trip)
                            } else if trip.status == .cancelled {
                                feedbackMessage = "모집이 취소되어 신청할 수 없어요."
                            } else {
                                isApplicationPresented = true
                            }
                        }
                    )
                    .frame(width: proxy.size.width)
                }
            }

            if isApplicationPresented {
                ApplicationSheet(
                    trip: trip,
                    onDismiss: {
                        isApplicationPresented = false
                    },
                    onSubmitted: {
                        didApplyInSession = true
                        onApplied(trip)
                        feedbackMessage = "신청이 완료됐어요."
                    },
                    onSubmit: {
                        isApplicationPresented = false
                        selectedThread = threadProvider(trip)
                    }
                )
                .transition(.opacity)
            }
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedThread) { thread in
            ChatRoomView(thread: thread) { message in
                onSendChatMessage(thread, message)
            }
        }
    }
}

private struct TripDetailFeedbackBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.caption.weight(.heavy))
            .foregroundStyle(MoyeoTheme.forest)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            .background(MoyeoTheme.leaf)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct TripDetailHero: View {
    let trip: TripRecruitment
    let onBack: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                Image(trip.heroImageAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: 284)
                    .clipped()
                    .overlay {
                        LinearGradient(
                            colors: [
                                .black.opacity(0.08),
                                .black.opacity(0.18),
                                .black.opacity(0.54)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .accessibilityLabel("\(trip.title) 대표 이미지")

                HStack {
                    HeroIconButton(systemImage: "chevron.left", label: "뒤로", action: onBack)
                    Spacer()
                    HeroIconButton(systemImage: "arrow.clockwise", label: "새로고침", action: onRefresh)
                }
                .padding(.horizontal, 18)
                .padding(.top, 56)
                .frame(maxHeight: .infinity, alignment: .top)

                Text(trip.status.rawValue)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.leading, 20)
                    .padding(.bottom, 48)
            }
            .frame(width: proxy.size.width, height: 284)
        }
        .frame(height: 284)
    }
}

private struct HeroIconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(MoyeoTheme.ink)
                .frame(width: 38, height: 38)
                .background(MoyeoTheme.card.opacity(0.92))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct TripDetailPanel: View {
    let trip: TripRecruitment

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Pill(text: trip.courseSource.title, tint: MoyeoTheme.primary300)
                    if let kind = trip.scheduleDetails?.kind {
                        Pill(text: kind.rawValue, tint: MoyeoTheme.river)
                    }
                }
                Text(trip.title)
                    .font(MoyeoTypography.font(size: 23, weight: .bold, relativeTo: .title2))
                    .foregroundStyle(MoyeoTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if let course = MockData.course(for: trip.courseID) {
                    NavigationLink {
                        CourseDetailView(course: course)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "map.fill")
                                .foregroundStyle(MoyeoTheme.muted)
                            Text(course.title)
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(MoyeoTheme.ink)
                                .lineLimit(1)
                            Spacer()
                            Pill(text: trip.courseSource.title, tint: MoyeoTheme.primary300)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(MoyeoTheme.text400)
                        }
                        .padding(.horizontal, 11)
                        .frame(minHeight: 42)
                        .background(MoyeoTheme.subtleBackground)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(MoyeoTheme.softLine))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("trip.detail.course")
                }

                Text(trip.detailMetaText)
                    .font(.subheadline)
                    .foregroundStyle(MoyeoTheme.muted)
            }

            HStack(alignment: .center) {
                ParticipantStack(participants: trip.participants, limit: 3, size: 32)
                Spacer()
                Text("최소 \(trip.minimumParticipants)명 이상")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.muted)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text("\(trip.joined) / \(trip.capacity)명")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.ink)
                    Text(trip.canJoin ? "신청 가능" : "대기 가능")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(trip.status.tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(trip.status.tint.opacity(0.14))
                        .clipShape(Capsule())
                    Spacer()
                }
                ProgressBar(value: trip.progress, tint: trip.status.tint, marker: trip.minimumProgress)
            }

            VStack(spacing: 12) {
                DetailInfoRow(icon: "calendar", title: "일정", value: trip.detailDateText)
                DetailInfoRow(icon: "clock", title: "시간", value: trip.detailTimeText)
                if let meeting = trip.meetingDetails {
                    DetailInfoRow(icon: "clock.badge", title: "집합 시간", value: meeting.meetingTime)
                }
                DetailInfoRow(icon: "mappin.and.ellipse", title: "모이는 곳", value: trip.meetupPoint)
                if let meeting = trip.meetingDetails {
                    DetailInfoRow(
                        icon: "map",
                        title: "좌표",
                        value: String(format: "%.6f, %.6f", meeting.latitude, meeting.longitude)
                    )
                    Link(destination: directionsURL(for: meeting)) {
                        Label("길찾기", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(MoyeoTheme.primary300)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .accessibilityIdentifier("trip.detail.directions")
                }
            }
            .padding(14)
            .background(MoyeoTheme.subtleBackground)
            .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))

            // 조건 4종은 한 카드 안에서 2x2 — 4줄로 세우면 카드만 길어진다 (웹 기준)
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    DetailInfoRow(icon: "wonsign.circle", title: "예상 비용", value: trip.price)
                    DetailInfoRow(icon: "clock", title: "모집 마감", value: trip.recruitmentDeadline)
                }
                HStack(alignment: .top, spacing: 12) {
                    DetailInfoRow(icon: "person.2", title: "나이대", value: trip.ageRangeText)
                    DetailInfoRow(icon: "person.crop.circle", title: "성별", value: trip.genderRestriction)
                }
            }
            .padding(14)
            .background(MoyeoTheme.subtleBackground)
            .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            .accessibilityIdentifier("trip.detail.conditions")

            HStack(spacing: 12) {
                MascotAvatar(mascot: trip.hostAvatar, size: 44, background: MoyeoTheme.leaf)
                VStack(alignment: .leading, spacing: 3) {
                    Text("호스트")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MoyeoTheme.muted)
                    Text(trip.hostName)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.ink)
                    Text("매너 점수 \(trip.hostScoreText)")
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.muted)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("모임 소개")
                    .font(.headline)
                    .foregroundStyle(MoyeoTheme.ink)
                Text(trip.summary)
                    .font(.subheadline)
                    .foregroundStyle(MoyeoTheme.text700)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TripRoutePreview(stops: trip.route)

            if trip.courseSource == .custom {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "sparkles")
                    Text("호스트가 직접 만든 코스예요. 여행 확정 전에는 경로가 바뀔 수 있고, 변경 시 모든 멤버에게 알려드려요.")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(MoyeoTheme.primary300)
                .padding(13)
                .background(MoyeoTheme.leaf)
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 24)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MoyeoTheme.softLine, lineWidth: 1)
        }
        .padding(.horizontal, 16)
    }

    private func directionsURL(for meeting: MeetingPointDetails) -> URL {
        var components = URLComponents(string: "https://maps.apple.com/")!
        components.queryItems = [
            URLQueryItem(name: "daddr", value: "\(meeting.latitude),\(meeting.longitude)"),
            URLQueryItem(name: "q", value: meeting.name)
        ]
        return components.url!
    }
}

private struct DetailInfoRow: View {
    let icon: String
    let title: String
    let value: String

    // 2x2 배치에서는 라벨 위 / 값 아래로 읽어야 좁은 폭에서 값이 잘리지 않는다
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MoyeoTheme.muted)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.muted)
                Text(value)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TripRoutePreview: View {
    let stops: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("코스 미리보기")
                .font(.headline)
                .foregroundStyle(MoyeoTheme.ink)

            HStack(spacing: 8) {
                ForEach(Array(stops.prefix(4).enumerated()), id: \.offset) { index, stop in
                    VStack(spacing: 6) {
                        Text("\(index + 1)")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(index == 0 ? MoyeoTheme.coral : MoyeoTheme.forest)
                            .clipShape(Circle())
                        Text(stop)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(MoyeoTheme.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(12)
            .background(MoyeoTheme.subtleBackground)
            .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
        }
    }
}

private struct TripDetailBottomBar: View {
    let canJoin: Bool
    let actionTitle: String
    let isApplied: Bool
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let onApply: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isFavorite ? MoyeoTheme.coral : MoyeoTheme.ink)
                    .frame(width: 52, height: 48)
                    .background(MoyeoTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                            .stroke(MoyeoTheme.softLine, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "찜 해제" : "찜")

            Button(action: onApply) {
                Text(isApplied ? "모임 채팅으로 이동" : (canJoin ? "함께 가기 신청" : actionTitle))
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(MoyeoTheme.forest)
                    .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("trip.detail.apply")
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

extension TripRecruitment {
    var heroImageAssetName: String {
        switch id {
        case "trip-cheongsong-juwangsan":
            return "weather_fog_seokguram"
        case "trip-andong-hahoe":
            return "weather_rain_hahoe"
        case "trip-gyeongju-history":
            return "weather_sunny_cheomseongdae"
        case "trip-pohang-drive",
             "trip-ulleung-island":
            return "weather_wind_homigot"
        case "trip-mungyeong-saejae":
            return "weather_cloudy_bulguksa"
        case "trip-yeongju-buseoksa":
            return "weather_snow_buseoksa"
        case "trip-andong-dosan":
            return "weather_heatwave_dosan"
        default:
            return "weather_sunny_cheomseongdae"
        }
    }

    var detailMetaText: String {
        let values = ([region] + tags.prefix(2)).joined(separator: " · ")
        return values
    }

    var detailDateText: String {
        parsedSchedule.dateText
    }

    var detailTimeText: String {
        parsedSchedule.timeText
    }

    var hostScoreText: String {
        switch id {
        case "trip-cheongsong-juwangsan":
            return "4.8점"
        case "trip-andong-hahoe",
             "trip-gyeongju-history":
            return "4.7점"
        default:
            return "4.6점"
        }
    }

    private var parsedSchedule: (dateText: String, timeText: String) {
        let parts = schedule.split(separator: " ").map(String.init)
        guard let time = parts.last, time.contains(":") else {
            return (schedule, "시간 미정")
        }

        let date = parts.dropLast().joined(separator: " ")
        return (date.isEmpty ? schedule : date, time)
    }
}
