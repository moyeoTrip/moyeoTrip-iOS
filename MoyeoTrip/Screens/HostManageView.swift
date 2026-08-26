import SwiftUI

struct HostManageView: View {
    let trip: TripRecruitment
    let thread: ChatThread?
    let onSendChatMessage: (ChatThread, ChatMessage) -> Void
    let onApproveApplicant: (TripRecruitment, Participant) -> Void
    let onRejectApplicant: (TripRecruitment, Participant) -> Void
    let onSetRecruitmentClosed: (TripRecruitment, Bool) -> Void
    @State private var pendingApplicants = HostApplicant.mockPending
    @State private var approvedApplicants = HostApplicant.mockApproved
    @State private var rejectedApplicants: [HostApplicant] = []
    @State private var isRecruitmentClosed: Bool
    @State private var selectedThread: ChatThread?
    @State private var routeDestination: SupportRoute?
    /// 서버 승인 대기 목록을 받았는지. 받았으면(빈 배열이어도) 목데이터 대기자를 쓰지 않는다 (18)
    @State private var usesServerApplications = false
    /// 승인·거절 처리 중인 신청 — 중복 탭을 막는다
    @State private var processingApplicationIDs = Set<Int64>()
    /// 이 화면에서 실제로 합류(JOINED)한 인원. 대기열(WAITLISTED)로 간 승인은 세지 않는다.
    @State private var serverJoinedDelta = 0

    init(
        trip: TripRecruitment,
        thread: ChatThread?,
        onSendChatMessage: @escaping (ChatThread, ChatMessage) -> Void,
        onApproveApplicant: @escaping (TripRecruitment, Participant) -> Void = { _, _ in },
        onRejectApplicant: @escaping (TripRecruitment, Participant) -> Void = { _, _ in },
        onSetRecruitmentClosed: @escaping (TripRecruitment, Bool) -> Void = { _, _ in }
    ) {
        self.trip = trip
        self.thread = thread
        self.onSendChatMessage = onSendChatMessage
        self.onApproveApplicant = onApproveApplicant
        self.onRejectApplicant = onRejectApplicant
        self.onSetRecruitmentClosed = onSetRecruitmentClosed
        _isRecruitmentClosed = State(initialValue: trip.status == .cancelled)
    }

    var body: some View {
        VStack(spacing: 0) {
            HostManageNavigationBar()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HostManageTripSummary(
                        title: trip.title,
                        participantText: "\(approvedCount) / \(trip.capacity)명",
                        status: isRecruitmentClosed
                            ? "모집 취소됨"
                            : (trip.recruitmentDeadline.isEmpty ? trip.status.rawValue : trip.recruitmentDeadline)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .accessibilityIdentifier("hostManage.summary")

                    Button {
                        routeDestination = .courseEdit(trip.id, trip.routeEditState)
                    } label: {
                        HostManageRouteRow(
                            count: trip.itinerary.isEmpty ? trip.route.count : trip.itinerary.count,
                            detail: routePolicyCopy
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
                    .accessibilityIdentifier("hostManage.route")

                    Divider()
                        .overlay(MoyeoTheme.line)

                    HostManageSectionTitle(
                        title: "승인 대기",
                        count: pendingApplicants.count,
                        trailingNote: "48시간 후 자동 거절"
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                    pendingContent
                        .padding(.horizontal, 20)

                    // 화면기획 18 — 승인된 동행자 수는 본인을 포함해 센다 (4)
                    HostManageSectionTitle(title: "승인된 동행자", count: approvedCount)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 12)

                    HostApprovedCompanionsRow(
                        avatars: approvedAvatars,
                        count: approvedCount
                    )
                    .padding(.horizontal, 20)
                    .accessibilityIdentifier("hostApproved.companions")

                    if !rejectedApplicants.isEmpty {
                        HostManageSectionTitle(title: "거절 기록", count: rejectedApplicants.count)
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                            .padding(.bottom, 12)
                        ForEach(rejectedApplicants) { applicant in
                            HostCompactApplicantRow(applicant: applicant, detail: "거절된 신청")
                                .padding(.horizontal, 20)
                                .accessibilityIdentifier("hostRejected.\(applicant.id)")
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                selectedThread = thread
            } label: {
                Label("채팅방 들어가기", systemImage: "bubble.left")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(thread == nil ? MoyeoTheme.text400 : MoyeoTheme.forest)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(thread == nil)
            .accessibilityIdentifier("hostManage.openChat")
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(MoyeoTheme.card)
            .overlay(alignment: .top) {
                Rectangle().fill(MoyeoTheme.line).frame(height: 1)
            }
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedThread) { thread in
            ChatRoomView(thread: thread) { message in
                onSendChatMessage(thread, message)
            }
        }
        .navigationDestination(item: $routeDestination) { route in
            SupportDestinationView(route: route)
        }
        .task {
            guard
                MoyeoServerSync.isEnabled,
                let roomID = trip.serverRoomID,
                !usesServerApplications
            else {
                return
            }
            // 호스트가 아니면 서버가 403 을 준다 — 그때는 목데이터 대기자를 그대로 남긴다
            guard
                let applications = try? await ChatRoomWriteAPIClient.shared.applications(roomID: roomID)
            else {
                return
            }
            // 함수 참조 대신 클로저로 호출해 main-actor 격리를 유지한다(Swift 6).
            pendingApplicants = applications.map { ServerTripMapper.hostApplicant(from: $0) }
            usesServerApplications = true
        }
        .accessibilityIdentifier("screen.hostManage")
    }

    /// 승인된 동행자 수(호스트 포함). 서버 모임은 서버가 준 참여 인원이 정답이다.
    private var approvedCount: Int {
        usesServerApplications
            ? max(trip.joined, 1) + serverJoinedDelta
            : approvedApplicants.count + 1
    }

    /// 서버 모임은 마스코트를 주지 않는다 — 빈 문자열로 두면 leaf 원만 그려진다(지어내지 않는다).
    private var approvedAvatars: [String] {
        usesServerApplications
            ? Array(repeating: "", count: approvedCount)
            : [trip.hostAvatar] + approvedApplicants.map(\.avatar)
    }

    @ViewBuilder
    private var pendingContent: some View {
        if pendingApplicants.isEmpty {
            HostManageEmptyState {
                Text("새 신청이 오면 이곳에서 승인하거나 거절할 수 있어요.")
                    .font(.subheadline)
                    .foregroundStyle(MoyeoTheme.muted)
            }
        } else {
            if let primaryApplicant = pendingApplicants.first {
                HostApplicantCard(
                    applicant: primaryApplicant,
                    primaryLabel: "승인",
                    secondaryLabel: "거절",
                    onPrimary: { approve(primaryApplicant) },
                    onSecondary: { reject(primaryApplicant) }
                )
            }
            ForEach(Array(pendingApplicants.dropFirst())) { applicant in
                // 화면기획 18 — 접힌 대기자는 요약(나이·성별·매너)과 chevron만 보인다
                HostCompactApplicantRow(applicant: applicant, detail: applicant.meta)
                    .padding(.top, 8)
            }
        }
    }

    private var statusCopy: String {
        if isRecruitmentClosed {
            return "모집이 취소되어 새 신청을 받지 않아요. 채팅방에서는 기존 안내를 확인할 수 있어요."
        }
        return "최소 \(trip.minimumParticipants)명 이상이면 출발 확정 상태로 전환돼요."
    }

    private var routePolicyCopy: String {
        switch trip.routeEditState {
        case .editable:
            // 화면기획 18 — "확정 전(D-3)까지 수정할 수 있어요 · 호스트 직접 코스"
            let deadline = trip.recruitmentDeadline.isEmpty ? "마감" : trip.recruitmentDeadline
            return "확정 전(\(deadline))까지 수정할 수 있어요 · \(trip.courseSource.title)"
        case .linkedLocked:
            return "등록 코스의 경로는 고정돼요. 집합 정보는 수정할 수 있어요."
        case .tripConfirmed:
            return "여행이 확정되어 경로가 잠겼어요. 변경은 공지로 알려주세요."
        }
    }

    /// 화면기획 18 승인. 서버 모임이면 실제로 승인한 뒤에만 목록에서 뺀다 —
    /// 실패하면 대기 카드를 그대로 남겨 호스트가 다시 시도할 수 있게 한다.
    private func approve(_ applicant: HostApplicant) {
        guard let roomID = trip.serverRoomID, let applicationID = applicant.serverApplicationID else {
            applyApproved(applicant)
            return
        }
        guard !processingApplicationIDs.contains(applicationID) else { return }
        processingApplicationIDs.insert(applicationID)
        Task {
            let result = try? await ChatRoomWriteAPIClient.shared.approveApplication(
                roomID: roomID, applicationID: applicationID
            )
            processingApplicationIDs.remove(applicationID)
            guard let result else { return }
            // 정원이 차 있으면 서버가 WAITLISTED 를 준다 — 그때는 참여 인원이 늘지 않는다
            if !result.isWaitlisted {
                serverJoinedDelta += 1
            }
            applyApproved(applicant)
        }
    }

    private func reject(_ applicant: HostApplicant) {
        guard let roomID = trip.serverRoomID, let applicationID = applicant.serverApplicationID else {
            applyRejected(applicant)
            return
        }
        guard !processingApplicationIDs.contains(applicationID) else { return }
        processingApplicationIDs.insert(applicationID)
        Task {
            let rejected: Bool
            do {
                try await ChatRoomWriteAPIClient.shared.rejectApplication(
                    roomID: roomID, applicationID: applicationID
                )
                rejected = true
            } catch {
                rejected = false
            }
            processingApplicationIDs.remove(applicationID)
            guard rejected else { return }
            applyRejected(applicant)
        }
    }

    private func applyApproved(_ applicant: HostApplicant) {
        pendingApplicants.removeAll { $0.id == applicant.id }
        approvedApplicants.append(applicant)
        onApproveApplicant(trip, applicant.participant)
    }

    private func applyRejected(_ applicant: HostApplicant) {
        pendingApplicants.removeAll { $0.id == applicant.id }
        rejectedApplicants.append(applicant)
        onRejectApplicant(trip, applicant.participant)
    }
}

struct HostManageContext: Identifiable, Hashable {
    let trip: TripRecruitment
    let thread: ChatThread

    var id: String {
        trip.id
    }
}

private struct HostManageActions: View {
    let isRecruitmentClosed: Bool
    let hasThread: Bool
    let onOpenChat: () -> Void
    let onToggleClose: () -> Void

    var body: some View {
        SupportCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(closeStateTitle, systemImage: closeStateIcon)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(isRecruitmentClosed ? MoyeoTheme.coral : MoyeoTheme.forest)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(closeStateTitle)
                    .accessibilityIdentifier("hostManage.closeState")

                Button {
                    onOpenChat()
                } label: {
                    Label("모임 채팅으로 이동", systemImage: "bubble.left.and.bubble.right.fill")
                        .font(.subheadline.weight(.heavy))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.borderedProminent)
                .tint(MoyeoTheme.forest)
                .disabled(!hasThread)
                .accessibilityLabel("모임 채팅으로 이동")
                .accessibilityIdentifier("hostManage.openChat")

                Button {
                    onToggleClose()
                } label: {
                    Text(closeActionTitle)
                        .font(.subheadline.weight(.heavy))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.borderedProminent)
                .tint(MoyeoTheme.coral)
                .accessibilityLabel(closeActionTitle)
                .accessibilityIdentifier("hostManage.toggleClose")
            }
        }
    }

    private var closeStateTitle: String {
        isRecruitmentClosed ? "모집 취소됨" : "모집 진행중"
    }

    private var closeStateIcon: String {
        isRecruitmentClosed ? "xmark.circle.fill" : "checkmark.seal.fill"
    }

    private var closeActionTitle: String {
        isRecruitmentClosed ? "모집 다시 열기" : "모집 취소"
    }
}

private struct HostManageSectionTitle: View {
    let title: String
    let count: Int
    /// 화면기획은 대기 목록 옆에 자동 거절 정책을 함께 알려준다
    var trailingNote: String?

    var body: some View {
        HStack {
            Text("\(title) (\(count))")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)
            Spacer()
            // 화면기획 18 — 승인 대기 옆에만 자동 거절 정책을 알린다
            if let trailingNote {
                Text(trailingNote)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.muted)
            }
        }
    }
}

private struct HostApplicantCard: View {
    let applicant: HostApplicant
    let primaryLabel: String
    let secondaryLabel: String
    let onPrimary: () -> Void
    let onSecondary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HostApplicantHeader(applicant: applicant)
            // 신청 한마디는 인용 블록으로 (화면기획). 신청자가 안 남겼으면 빈 인용을 그리지 않는다.
            if !applicant.note.isEmpty {
                Text("\u{201C}\(applicant.note)\u{201D}")
                    .font(.caption)
                    .foregroundStyle(MoyeoTheme.muted)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                    .background(MoyeoTheme.subtleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            HStack(spacing: 10) {
                Button(action: onSecondary) {
                    Text(secondaryLabel)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(MoyeoTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(MoyeoTheme.line))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(applicant.name) \(secondaryLabel)")
                .accessibilityIdentifier("hostApplicant.\(applicant.id).reject")

                Button(action: onPrimary) {
                    Text(primaryLabel)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(MoyeoTheme.forest)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(applicant.name) \(primaryLabel)")
                .accessibilityIdentifier("hostApplicant.\(applicant.id).approve")
            }
        }
        .padding(16)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MoyeoTheme.line, lineWidth: 1)
        }
    }
}

private struct HostApplicantHeader: View {
    let applicant: HostApplicant

    var body: some View {
        HStack(spacing: 12) {
            // 서버 신청자는 프로필 이미지를 준다. 없으면 leaf 원만 남기고 마스코트를 지어내지 않는다.
            if let profileImageURL = applicant.profileImageURL {
                CachedRemoteImage(url: profileImageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    MoyeoTheme.leaf
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                Text(applicant.avatar)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(MoyeoTheme.leaf)
                    .clipShape(Circle())
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(applicant.name)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                Text(applicant.meta)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.muted)
            }
            Spacer()
            // 화면기획 18 — 대기 카드 우상단 더보기
            Image(systemName: "ellipsis")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MoyeoTheme.text400)
        }
    }
}

struct HostManagePill: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    /// 마감 배지(D-3)는 화면기획처럼 코랄 톤으로 구분한다
    private var isDeadline: Bool { text.hasPrefix("D-") }

    var body: some View {
        Text(text)
            .font(.caption.weight(.heavy))
            .foregroundStyle(isDeadline ? MoyeoTheme.coral : MoyeoTheme.forest)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(isDeadline ? MoyeoTheme.coral.opacity(0.14) : MoyeoTheme.leaf)
            .clipShape(Capsule())
    }
}
