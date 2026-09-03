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
    var threadProvider: (TripRecruitment) -> ChatThread? = { _ in nil }
    var onApplied: (TripRecruitment) -> Void = { _ in }
    var onSendChatMessage: (ChatThread, ChatMessage) -> Void = { _, _ in }
    /// 신청 시트를 열린 상태로 시작한다(캡처가 실제 상세 화면 위의 실제 시트를 찍게 한다).
    var startsWithApplicationSheet = false
    @Environment(\.dismiss) private var dismiss
    @State private var isApplicationPresented = false
    @State private var selectedThread: ChatThread?
    @State private var isFavorite = false
    @State private var didApplyInSession = false
    @State private var feedbackMessage: String?
    /// 15 상세 히어로의 깃발 버튼. 모집·채팅방 신고는 접수 API 가 없다 —
    /// 접수되는 것처럼 보이는 30-2 시트를 열지 않고 그 자리에서 안내한다 (정본 `REPORT-CANON.md` §3).
    @State private var showsReportUnsupported = false
    // 실서버 연동 상태 — 서버 모임(serverRoomID)일 때만 채워진다
    @State private var serverTrip: TripRecruitment?
    @State private var serverCourse: TravelCourse?
    @State private var serverCanApply: Bool?
    /// 15 참가자 아바타 줄의 근거. `GET /chat-rooms/{roomId}` 의 `participants` 다.
    @State private var serverParticipants: [ServerChatRoomDetail.ServerParticipant] = []
    /// userId → 닉네임. 상세 응답에는 닉네임이 없어 `GET /chat-rooms/{roomId}/members` 로 채운다.
    /// 그 목록이 열리지 않으면 비어 있고, 그때는 사람별 동물 대신 `🐾` 를 쓴다.
    @State private var participantNicknamesByUserID: [Int64: String] = [:]
    @State private var serverJoinResult: ServerJoinResult?

    private var appliedState: Bool {
        isApplied || didApplyInSession
    }

    /// 서버 상세를 받아오면 서버 데이터로, 아니면 진입 시 받은 데이터로 그린다
    private var displayTrip: TripRecruitment {
        serverTrip ?? trip
    }

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    ScrollView {
                        VStack(spacing: 0) {
                            TripDetailHero(
                                trip: displayTrip,
                                onBack: {
                                    dismiss()
                                },
                                onReport: {
                                    showsReportUnsupported = true
                                }
                            )
                            if let feedbackMessage {
                                TripDetailFeedbackBanner(message: feedbackMessage)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 12)
                            }
                            TripDetailPanel(
                                trip: displayTrip,
                                serverCourse: serverCourse,
                                participants: serverParticipants,
                                participantNicknamesByUserID: participantNicknamesByUserID
                            )
                                .padding(.top, feedbackMessage == nil ? -28 : 12)
                        }
                        .frame(width: proxy.size.width)
                        .padding(.bottom, 128)
                    }

                    TripDetailBottomBar(
                        canJoin: displayTrip.canJoin && (serverCanApply ?? true),
                        actionTitle: displayTrip.applicationActionTitle,
                        isApplied: appliedState,
                        isAppliedTitle: displayTrip.isServerBacked ? appliedServerTitle : "모임 채팅으로 이동",
                        isFavorite: isFavorite,
                        onToggleFavorite: toggleFavorite,
                        onApply: {
                            if appliedState {
                                if displayTrip.isServerBacked {
                                    feedbackMessage = appliedServerFeedback
                                } else {
                                    selectedThread = threadProvider(trip)
                                }
                            } else if displayTrip.status == .cancelled {
                                feedbackMessage = "모집이 취소되어 신청할 수 없어요."
                            } else if displayTrip.isServerBacked, serverCanApply == false {
                                feedbackMessage = "지금은 이 모임에 신청할 수 없어요."
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
                    trip: displayTrip,
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
                        if !displayTrip.isServerBacked {
                            selectedThread = threadProvider(trip)
                        }
                    },
                    serverSubmitHandler: serverSubmitHandler
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
        .overlay {
            if showsReportUnsupported {
                ReportUnsupportedDialog { showsReportUnsupported = false }
            }
        }
        .task {
            if startsWithApplicationSheet { isApplicationPresented = true }
            await loadServerDetail()
        }
    }

    private var appliedServerTitle: String {
        switch serverJoinResult {
        case .joined:
            return "참여가 확정됐어요"
        case .waitlisted:
            return "대기열 등록됨"
        default:
            return "신청 완료 · 승인 대기"
        }
    }

    private var appliedServerFeedback: String {
        switch serverJoinResult {
        case .joined:
            return "참여가 확정됐어요. 모임 탭에서 확인할 수 있어요."
        case .waitlisted:
            return "대기열에 등록됐어요. 자리가 나면 순서대로 합류돼요."
        default:
            return "호스트 승인을 기다리고 있어요. 결과는 알림으로 알려드려요."
        }
    }

    private var serverSubmitHandler: ((String) async throws -> ServerJoinResult)? {
        guard let roomID = trip.serverRoomID, MoyeoServerSync.isEnabled else { return nil }
        return { message in
            let response = try await ChatRoomAPIClient.shared.apply(roomID: roomID, message: message)
            await MainActor.run {
                serverJoinResult = response.result
                didApplyInSession = true
                onApplied(trip)
            }
            return response.result
        }
    }

    private func toggleFavorite() {
        guard let roomID = trip.serverRoomID, MoyeoServerSync.isEnabled else {
            isFavorite.toggle()
            feedbackMessage = isFavorite ? "찜한 코스에 담았어요." : "찜한 코스에서 제외했어요."
            return
        }
        Task {
            do {
                let favorite = try await ChatRoomAPIClient.shared.toggleFavorite(roomID: roomID)
                isFavorite = favorite
                feedbackMessage = favorite ? "찜한 코스에 담았어요." : "찜한 코스에서 제외했어요."
            } catch {
                feedbackMessage = (error as? LocalizedError)?.errorDescription
                    ?? "찜 처리에 실패했어요. 잠시 후 다시 시도해주세요."
            }
        }
    }

    private func loadServerDetail() async {
        guard let roomID = trip.serverRoomID, MoyeoServerSync.isEnabled else { return }
        let course = (try? await TravelCourseAPIClient.shared.roomCourse(roomID: roomID))?.course
        if let detail = try? await ChatRoomAPIClient.shared.detail(roomID: roomID) {
            serverTrip = ServerTripMapper.trip(from: detail, course: course)
            isFavorite = detail.favorite
            // 참가 가능 여부는 상세 응답의 canApply 다. 예전 /join-eligibility 는 서버에서 삭제됐다.
            serverCanApply = detail.canApply
            // 아바타 줄은 서버가 준 참가자만 그린다 — 0건이면 줄 자체가 없다 (NO-MOCK R1).
            serverParticipants = detail.participants
        }
        serverCourse = course.map(ServerCourseMapper.course(from:))
        await loadParticipantNicknames(roomID: roomID)
    }

    /// 닉네임 동물 이모지 폴백(R5)에 쓸 닉네임만 받아 온다.
    /// 멤버 목록은 방에 속한 사람에게만 열리므로 실패해도 조용히 넘긴다 — 아바타 줄은 그대로 그린다.
    private func loadParticipantNicknames(roomID: Int64) async {
        guard !serverParticipants.isEmpty else { return }
        guard let list = try? await ChatRoomContentAPIClient.shared.members(roomID: roomID) else { return }
        participantNicknamesByUserID = Dictionary(
            list.members.map { ($0.userId, $0.nickname) },
            uniquingKeysWith: { first, _ in first }
        )
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
    let onReport: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                TripDetailHeroImage(trip: trip)
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

                // 화면기획 15 — 우상단은 신고(깃발)다. 상태 배지는 히어로에 두지 않는다
                HStack {
                    HeroIconButton(systemImage: "chevron.left", label: "뒤로", action: onBack)
                    Spacer()
                    HeroIconButton(systemImage: "flag", label: "신고", action: onReport)
                }
                .padding(.horizontal, 18)
                .padding(.top, 56)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(width: proxy.size.width, height: 284)
        }
        .frame(height: 284)
    }
}

/// 서버 모임은 썸네일 URL을, 목데이터 모임은 번들 이미지 에셋을 그린다
struct TripDetailHeroImage: View {
    let trip: TripRecruitment

    var body: some View {
        if let heroImageURL = trip.heroImageURL {
            CachedRemoteImage(url: heroImageURL, fallbackShape: .landscape) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                MoyeoTheme.leaf
            }
        } else {
            // 서버가 썸네일을 내려주지 않은 모임 — 히어로는 이미지가 필수인 자리다
            MoyeoPlaceholderImageView(shape: .landscape)
        }
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

/// 15 모집 상세 · 20-4 확정 모먼트의 참가자 아바타 줄. 겹친 원을 늘어놓고 넘치는 인원은 `+N` 배지로 접는다.
///
/// 치수는 세 플랫폼·기획이 같다 — 바깥 지름 32(사진 28 + 링 2), 겹침 -8.
/// (웹 `screens-refined.jsx` `ScreenGroupDetail`, 안드로이드 `TripDetailScreen.kt` 아바타 Row,
///  기획 `모여트립 in 경북/screens-refined.jsx` `MemberStack`.)
///
/// 근거 API 는 `GET /api/v1/chat-rooms/{roomId}` 의 `participants[].profileImageUrl` 다.
/// 사진이 없으면 닉네임 동물 이모지(R5)를 쓰고, 닉네임까지 없으면 `🐾` 다.
/// **아바타를 지어내지 않는다** — 참가자 목록이 비면 부르는 쪽에서 줄을 그리지 않는다 (R1).
struct TripDetailParticipantStack: View {
    let participants: [ServerChatRoomDetail.ServerParticipant]
    var nicknamesByUserID: [Int64: String] = [:]

    /// 바깥 지름. 링 2 를 뺀 30 - 2 = 28 이 사진 지름이다.
    private let diameter: CGFloat = 32
    private let ringWidth: CGFloat = 2
    private let overlap: CGFloat = -8
    /// 기획 15 가 얼굴 3개 + `+2` 이므로 넘치는 인원은 배지로 접는다.
    /// 웹 · 안드로이드가 접지 않고 5명까지 그리므로, 그 범위에서는 세 쪽이 같게 보인다.
    private let visibleLimit = 4

    var body: some View {
        let shown = Array(participants.prefix(visibleLimit))
        let hidden = participants.count - shown.count
        HStack(spacing: overlap) {
            ForEach(shown, id: \.userId) { participant in
                avatar(participant)
            }
            if hidden > 0 {
                Text("+\(hidden)")
                    .font(.system(size: 11, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(MoyeoTheme.muted)
                    .frame(width: diameter, height: diameter)
                    .background(MoyeoTheme.subtleBackground)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(MoyeoTheme.card, lineWidth: ringWidth))
                    .accessibilityIdentifier("trip.detail.participants.more")
            }
            Spacer(minLength: 0)
        }
        .accessibilityIdentifier("trip.detail.participants")
    }

    private func avatar(_ participant: ServerChatRoomDetail.ServerParticipant) -> some View {
        let url = MoyeoImageURL.resolve(participant.profileImageUrl)
        let nickname = nicknamesByUserID[participant.userId]
        let mascot = MoyeoNicknameAnimal.emoji(forNickname: nickname ?? "") ?? MoyeoNicknameAnimal.unknown
        return ZStack {
            if url != nil {
                CachedRemoteImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    MascotAvatar(mascot: mascot, size: diameter - ringWidth * 2)
                }
            } else {
                MascotAvatar(mascot: mascot, size: diameter - ringWidth * 2)
            }
        }
        .frame(width: diameter - ringWidth * 2, height: diameter - ringWidth * 2)
        .clipShape(Circle())
        .padding(ringWidth)
        .background(Circle().fill(MoyeoTheme.card))
        .accessibilityIdentifier("trip.detail.participant.\(participant.userId)")
    }
}

private struct TripDetailPanel: View {
    let trip: TripRecruitment
    var serverCourse: TravelCourse?
    var participants: [ServerChatRoomDetail.ServerParticipant] = []
    var participantNicknamesByUserID: [Int64: String] = [:]

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

                if let course = serverCourse {
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

            // 화면기획 15 · 웹 · 안드로이드와 같은 자리 — 코스 카드·태그 줄 아래, `n / m명` 위다.
            if !participants.isEmpty {
                TripDetailParticipantStack(
                    participants: participants,
                    nicknamesByUserID: participantNicknamesByUserID
                )
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
                ProgressBar(
                    value: trip.progress,
                    tint: trip.status.tint,
                    marker: trip.minimumParticipants > 0 ? trip.minimumProgress : nil
                )
            }

            // 화면기획 15 일정 카드 — 일정 · 여행 시간 · 집합 세 줄 뒤에
            // 구분선을 두고 좌표 한 줄과 길 찾기를 붙인다 (웹 · Android 동일)
            VStack(spacing: 10) {
                TripScheduleRow(icon: "calendar", label: "일정", value: trip.detailScheduleText)
                TripScheduleRow(icon: "clock", label: "여행 시간", value: trip.detailTravelTimeText)
                TripScheduleRow(
                    icon: "mappin.and.ellipse", label: "집합", value: trip.detailMeetupText)
                if let meeting = trip.meetingDetails {
                    Rectangle()
                        .fill(MoyeoTheme.softLine)
                        .frame(height: 1)
                    HStack(spacing: 10) {
                        Image(systemName: "map")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MoyeoTheme.muted)
                            .frame(width: 16)
                        // 좌표는 길 찾기 링크의 입력값이지 사용자에게 보일 값이 아니다 —
                        // 기획에도 없고, 웹은 이 자리에 집합 장소 이름을 둔다.
                        // 예전에는 `36.410800, 129.057500` 이 그대로 보였다.
                        Text(meetingPlaceLabel(for: meeting))
                            .font(.caption2)
                            .foregroundStyle(MoyeoTheme.muted)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Link(destination: directionsURL(for: meeting)) {
                            Text("길 찾기")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(MoyeoTheme.brandText)
                        }
                        .accessibilityIdentifier("trip.detail.directions")
                    }
                }
            }
            .padding(14)
            .background(MoyeoTheme.subtleBackground)
            .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            .accessibilityIdentifier("trip.detail.schedule")

            // 조건 4종은 한 카드 안에서 2x2 — 4줄로 세우면 카드만 길어진다 (웹 기준)
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    DetailInfoRow(icon: "wonsign.circle", title: "예상 비용", value: trip.price)
                    DetailInfoRow(icon: "clock", title: "모집 마감", value: trip.recruitmentDeadline)
                }
                HStack(alignment: .top, spacing: 12) {
                    DetailInfoRow(icon: "person.2", title: "나이대", value: trip.displayAgeRangeText)
                    DetailInfoRow(icon: "person.crop.circle", title: "성별", value: trip.genderRestriction)
                }
            }
            .padding(14)
            .background(MoyeoTheme.subtleBackground)
            .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            .accessibilityIdentifier("trip.detail.conditions")

            if trip.courseSource == .custom {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text(trip.customCourseNoticeText)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(MoyeoTheme.brandText)
                .padding(12)
                .background(MoyeoTheme.leaf)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(MoyeoTheme.primary100, lineWidth: 1)
                }
                .accessibilityIdentifier("trip.detail.customCourseNotice")
            }

            HStack(spacing: 12) {
                if let hostImageURL = trip.hostProfileImageURL {
                    CachedRemoteImage(url: hostImageURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        MoyeoTheme.leaf
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else if !trip.hostAvatar.isEmpty {
                    MascotAvatar(mascot: trip.hostAvatar, size: 44, background: MoyeoTheme.leaf)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("호스트")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MoyeoTheme.muted)
                    // 서버는 호스트 닉네임·매너 점수를 내려주지 않는다 — 있는 값만 보여준다
                    if !trip.hostName.isEmpty {
                        Text(trip.hostName)
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(MoyeoTheme.ink)
                    }
                    // 매너 점수는 서버가 주지 않는다 — 지어내지 않고 줄을 만들지 않는다 (§4 BE 요청)
                }
                Spacer()
            }

            if !trip.summary.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("모임 소개")
                        .font(.headline)
                        .foregroundStyle(MoyeoTheme.ink)
                    Text(trip.summary)
                        .font(.subheadline)
                        .foregroundStyle(MoyeoTheme.text700)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // 코스 미리보기는 실지도다 — 방문지 좌표가 없으면 섹션째 그리지 않는다
            if !trip.itinerary.isEmpty {
                TripRoutePreview(stops: trip.itinerary)
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

    /// 집합 장소 표기. 웹 15 상세와 같은 순서·대체 문구를 쓴다.
    private func meetingPlaceLabel(for meeting: MeetingPointDetails) -> String {
        for candidate in [meeting.name, meeting.detail, meeting.address] {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return "집합 위치"
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

/// 화면기획 15 일정 카드 행 — 라벨은 왼쪽 고정 폭, 값은 굵게 한 줄이다
private struct TripScheduleRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MoyeoTheme.muted)
                .frame(width: 16)
            Text(label)
                .font(.caption)
                .foregroundStyle(MoyeoTheme.muted)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

/// 15 코스 미리보기 — 번호 원 나열이 아니라 실제 카카오 지도다 (NO-MOCK-CANON R4).
/// 좌표가 빠진 방문지가 하나라도 있으면 지도를 그리지 않는다.
private struct TripRoutePreview: View {
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
            VStack(alignment: .leading, spacing: 10) {
                Text("코스 미리보기")
                    .font(.headline)
                    .foregroundStyle(MoyeoTheme.ink)

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
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("코스 경로 지도, 방문지 \(stops.count)곳")
                .accessibilityIdentifier("trip.route.preview")
            }
        }
    }
}

private struct TripDetailBottomBar: View {
    let canJoin: Bool
    let actionTitle: String
    let isApplied: Bool
    var isAppliedTitle = "모임 채팅으로 이동"
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
                Text(isApplied ? isAppliedTitle : (canJoin ? "함께 가기 신청" : actionTitle))
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
    var detailMetaText: String {
        ([region] + tags.prefix(2))
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    /// 서버 모임은 나이 제한이 없으면 null을 내려준다 — "제한 없음"으로 표기한다
    var displayAgeRangeText: String {
        guard minimumAge > 0 || maximumAge > 0 else { return "제한 없음" }
        if minimumAge > 0 && maximumAge > 0 { return ageRangeText }
        if minimumAge > 0 { return "\(minimumAge)세 이상" }
        return "\(maximumAge)세 이하"
    }

    var detailDateText: String {
        parsedSchedule.dateText
    }

    /// 화면기획 15 — "2026.05.25 (토) · 당일치기"
    var detailScheduleText: String {
        guard let kind = scheduleDetails?.kind else { return parsedSchedule.dateText }
        return "\(parsedSchedule.dateText) · \(kind.rawValue)"
    }

    /// 화면기획 15 — "08:00 - 18:00" (종료 시간이 없으면 시작 시간만)
    var detailTravelTimeText: String {
        guard let details = scheduleDetails else { return parsedSchedule.timeText }
        let start = details.startTime ?? parsedSchedule.timeText
        guard let end = details.endTime, !end.isEmpty else { return start }
        return "\(start) - \(end)"
    }

    /// 화면기획 15 — "07:50 청송 시외버스터미널 정문 앞"
    var detailMeetupText: String {
        guard let meeting = meetingDetails else { return meetupPoint }
        let place = meeting.detail.isEmpty ? meeting.name : "\(meeting.name) \(meeting.detail)"
        return "\(meeting.meetingTime) \(place)"
    }

    /// 화면기획 15 안내 박스 — 확정 마감일을 문장 안에 그대로 노출한다
    var customCourseNoticeText: String {
        // "D-3 · 5/22(금)" → "5/22" (기획 문장은 요일 없이 날짜만 넣는다)
        let deadline = recruitmentDeadline
            .split(separator: "·")
            .last?
            .trimmingCharacters(in: .whitespaces)
            .split(separator: "(")
            .first?
            .trimmingCharacters(in: .whitespaces)
        guard let deadline, !deadline.isEmpty else {
            return "호스트가 직접 만든 코스예요. 여행이 확정되기 전까지 경로가 바뀔 수 있고, 바뀌면 알림으로 알려드려요."
        }
        return "호스트가 직접 만든 코스예요. 여행이 확정(\(deadline) 마감)되기 전까지 경로가 바뀔 수 있고, 바뀌면 알림으로 알려드려요."
    }

    var detailTimeText: String {
        parsedSchedule.timeText
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
