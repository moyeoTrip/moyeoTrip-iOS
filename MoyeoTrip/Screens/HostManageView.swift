import SwiftUI

struct HostManageView: View {
    let trip: TripRecruitment
    let thread: ChatThread?
    let onSendChatMessage: (ChatThread, ChatMessage) -> Void
    let onApproveApplicant: (TripRecruitment, Participant) -> Void
    let onRejectApplicant: (TripRecruitment, Participant) -> Void
    let onSetRecruitmentClosed: (TripRecruitment, Bool) -> Void
    @State private var pendingApplicants = HostApplicant.noPending
    @State private var approvedApplicants = HostApplicant.noApproved
    @State private var rejectedApplicants: [HostApplicant] = []
    /// 거절 기록을 서버에서 받았는지. 받았으면(빈 배열이어도) 빈 상태 문구를 그린다.
    @State private var usesServerRejected = false
    /// 거절 기록 줄 아래에 적을 설명(「N일 전 거절」). 서버 `rejectedAt` 에서 만든다.
    @State private var rejectedDetailByID: [String: String] = [:]
    @State private var isRecruitmentClosed: Bool
    @State private var selectedThread: ChatThread?
    @State private var routeDestination: SupportRoute?
    /// 18-4 여행 확정 / 불발 · 18-5 집합 정보 수정 — 서버 모임에서만 연다.
    @State private var tripStatusRoute: RoomIDRoute?
    @State private var meetingEditRoute: RoomIDRoute?
    /// 18-6 모집 내용 수정 — `RecruitEditView` 는 만들어져 있는데 `SupportRoute.recruitEdit` 를
    /// 넣는 곳이 `UITestInitialState` 하나뿐이라 **앱에서 갈 길이 없었다**(웹·안드도 같은 구멍이었다).
    @State private var recruitEditRoute: RoomIDRoute?
    /// 서버 승인 대기 목록을 받았는지. 받았으면(빈 배열이어도) 목데이터 대기자를 쓰지 않는다 (18)
    @State private var usesServerApplications = false
    /// 승인된 동행자 줄에 **실제 프로필 사진**을 그리기 위한 서버 멤버 목록.
    /// 예전에는 받지 않아 아바타가 빈 원으로만 나왔다.
    @State private var serverMembers: [ServerChatRoomMember] = []
    /// 승인·거절 처리 중인 신청 — 중복 탭을 막는다
    @State private var processingApplicationIDs = Set<Int64>()
    /// 승인·거절이 실패한 이유. 승인 대기 구역 위에 한 줄로 적는다.
    ///
    /// 예전에는 `try?` 와 `catch { rejected = false }` 로 삼켜 **카드가 그대로 남고 안내도 없었다** —
    /// 호스트는 버튼이 안 눌린 줄 안다 (TC SOCIAL-010 계열).
    @State private var applicationActionFailure: String?
    /// 이 화면에서 실제로 합류(JOINED)한 인원. 대기열(WAITLISTED)로 간 승인은 세지 않는다.
    @State private var serverJoinedDelta = 0
    /// 대기열(`GET /chat-rooms/{roomId}/applications/waitlist`). 호스트만 200 이다.
    /// 서버가 준 `position` 순서를 그대로 쓴다 — 클라가 다시 매기지 않는다.
    @State private var waitlist: [HostApplicant] = []
    /// 서버가 말하는 지금 방 상태(`RECRUITING` · `CONFIRMED` · `CANCELLED`).
    ///
    /// 예전에는 화면에 넘어온 `trip` 값만 보고 그려서, 18-4 에서 불발·확정을 하고 돌아와도
    /// 계속 「모집중」이었고 앱을 다시 켜야 반영됐다 (IOS-F127). 18-4 에서 돌아올 때 다시 읽는다.
    @State private var serverRoomStatus: String?

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
                        status: summaryStatusText
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
                    .padding(.bottom, 12)
                    .accessibilityIdentifier("hostManage.route")

                    // 두 동작은 **나란한 버튼**이다 — 기획·웹이 그렇다.
                    // 예전에는 셰브런이 달린 목록 줄 두 개였고, 그래서 같은 화면인데
                    // 앱만 「메뉴 화면」처럼 보였다 (18, 사용자 지적 2026-09-09).
                    //
                    // 18-4 여행 확정 / 불발 — 참가자가 보는 20-4 확정 모먼트는 있는데
                    // 호스트가 그 버튼을 누르는 화면이 없었다 (정본 §6-1).
                    // 18-5 집합 정보 수정 — `PUT /chat-rooms/{id}/meeting-info`.
                    HostManageHostActions(
                        isRecruitmentClosed: isRecruitmentClosed,
                        // 세 화면 모두 모집 중일 때만 서버가 받는다 — 전이가 끝난 방에서는 잠근다.
                        isRecruiting: isRecruiting,
                        hasServerRoom: trip.serverRoomID != nil,
                        onTripStatus: {
                            if let roomID = trip.serverRoomID {
                                tripStatusRoute = RoomIDRoute(roomID: roomID, kind: "tripStatus")
                            }
                        },
                        onMeetingEdit: {
                            if let roomID = trip.serverRoomID {
                                meetingEditRoute = RoomIDRoute(roomID: roomID, kind: "meetingEdit")
                            }
                        },
                        onRecruitEdit: {
                            if let roomID = trip.serverRoomID {
                                recruitEditRoute = RoomIDRoute(roomID: roomID, kind: "recruitEdit")
                            }
                        }
                    )

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

                    // 대기열 — 정원이 찼을 때 승인한 신청이 여기로 간다(`ApprovalResult.WAITLISTED`).
                    // 호스트만 볼 수 있어(참가자는 403) 서버 신청 목록을 받은 방에서만 그린다.
                    if usesServerApplications {
                        HostWaitlistSection(waitlist: waitlist) { route in
                            routeDestination = route
                        }
                    }

                    // 거절 기록 — 자리는 **웹을 기준**으로 대기열과 승인된 동행자 사이다.
                    // 신청 계열 세 구역(승인 대기 → 대기열 → 거절 기록)이 붙어 있어야
                    // 「신청 → 대기 → 거절」이 한눈에 읽힌다. iOS 만 맨 아래에 두고 있었다.
                    if usesServerRejected || !rejectedApplicants.isEmpty {
                        HostRejectedSection(
                            rejected: rejectedApplicants,
                            detailByID: rejectedDetailByID,
                            onOpenProfile: { routeDestination = $0 }
                        )
                    }

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
                    .frame(height: MoyeoTheme.ctaHeight)
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
        // 바를 감추면 UIKit 이 엣지 스와이프를 스스로 끈다. 탭 루트에서 한 번 살려 둔 것이
        // **push 될 때마다 다시 꺼지므로** 이 화면들에서도 각각 되살린다 (TC NAV-017).
        .moyeoBackSwipeEnabled()
        .navigationDestination(item: $selectedThread) { thread in
            ChatRoomView(thread: thread) { message in
                onSendChatMessage(thread, message)
            }
        }
        .navigationDestination(item: $routeDestination) { route in
            SupportDestinationView(route: route)
        }
        .navigationDestination(item: $tripStatusRoute) { route in
            TripStatusView(roomID: route.roomID)
        }
        // 18-4 에서 돌아오면 방 상세를 다시 읽는다. 확정·불발은 이 화면이 그리는 값을 전부 바꾼다.
        .onChange(of: tripStatusRoute) { _, route in
            guard route == nil else { return }
            Task { await refreshRoomStatus() }
        }
        .navigationDestination(item: $meetingEditRoute) { route in
            MeetingInfoEditView(roomID: route.roomID)
        }
        .navigationDestination(item: $recruitEditRoute) { route in
            RecruitEditView(roomID: route.roomID)
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
            // 승인된 동행자 아바타는 멤버 목록에만 있다(신청 목록에는 없다).
            // 실패하면 사진 없이 그린다 — 이 줄 때문에 화면 전체를 막지 않는다.
            if let memberList = try? await ChatRoomContentAPIClient.shared.members(roomID: roomID) {
                serverMembers = memberList.members
            }
            await loadWaitlist(roomID: roomID)
            await loadRejected(roomID: roomID)
        }
        .task { await refreshRoomStatus() }
        .accessibilityIdentifier("screen.hostManage")
    }

    @ViewBuilder
    private var pendingContent: some View {
        HostPendingApplicantsSection(
            applicants: pendingApplicants,
            failureMessage: applicationActionFailure,
            onApprove: approve,
            onReject: reject,
            onOpenProfile: { routeDestination = $0 }
        )
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
        case .tripCancelled:
            // 확정과 똑같이 잠기지만 **확정됐다고 말하지 않는다.** 예전에는 케이스가 없어
            // 불발된 방도 「여행이 확정되어…」로 읽혔다.
            return "모집이 불발되어 경로가 잠겼어요. 같은 코스로 다시 모집을 열 수 있어요."
        }
    }

    /// 승인·거절 공통. **성공한 뒤에만** 카드를 옮기고, 실패하면 카드를 그대로 두고
    /// 승인 대기 구역에 까닭을 적는다 — 예전에는 `try?`·`catch { rejected = false }` 로
    /// 삼켜 아무 일도 일어나지 않은 것처럼 보였다 (TC SOCIAL-010 계열).
    private func runApplicationAction(
        _ applicationID: Int64,
        failureText: String,
        action: @escaping () async throws -> Void
    ) {
        guard !processingApplicationIDs.contains(applicationID) else { return }
        processingApplicationIDs.insert(applicationID)
        applicationActionFailure = nil
        Task {
            do {
                try await action()
            } catch {
                applicationActionFailure = error.moyeoUserMessage(fallback: failureText)
                // 실패한 까닭이 「그 신청이 이제 없다」일 수 있다 — 다른 기기·다른 사람이 먼저
                // 처리했거나 신청자가 취소한 경우다(서버 `CHAT_JOIN_APPLICATION_NOT_FOUND`).
                // 까닭만 적고 카드를 그대로 두면 없는 신청에 계속 승인·거절을 누르게 된다(TC HOST-008).
                // 통신 자체가 실패한 것이면 이 다시 읽기도 실패해 **목록은 그대로** 남는다.
                await reloadApplications()
            }
            processingApplicationIDs.remove(applicationID)
        }
    }

    /// 화면기획 18 승인. 서버 모임이면 실제로 승인한 뒤에만 목록에서 뺀다.
    private func approve(_ applicant: HostApplicant) {
        guard let roomID = trip.serverRoomID, let applicationID = applicant.serverApplicationID else {
            applyApproved(applicant)
            return
        }
        runApplicationAction(
            applicationID,
            failureText: "신청을 승인하지 못했어요. 잠시 후 다시 시도해주세요."
        ) {
            let result = try await ChatRoomWriteAPIClient.shared.approveApplication(
                roomID: roomID, applicationID: applicationID
            )
            // 정원이 차 있으면 서버가 WAITLISTED 를 준다 — 그때는 참여 인원이 늘지 않는다
            if !result.isWaitlisted { serverJoinedDelta += 1 }
            applyApproved(applicant)
        }
    }

    private func reject(_ applicant: HostApplicant) {
        guard let roomID = trip.serverRoomID, let applicationID = applicant.serverApplicationID else {
            applyRejected(applicant)
            return
        }
        runApplicationAction(
            applicationID,
            failureText: "신청을 거절하지 못했어요. 잠시 후 다시 시도해주세요."
        ) {
            try await ChatRoomWriteAPIClient.shared.rejectApplication(
                roomID: roomID, applicationID: applicationID
            )
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
        // 서버가 거절 기록을 주므로 **서버 값을 다시 받아** 그린다 — 화면에만 쌓아 두면
        // 다시 들어왔을 때 사라진다(예전 문제). 못 받으면 방금 건만이라도 보여 준다.
        if let roomID = trip.serverRoomID, MoyeoServerSync.isEnabled {
            Task { await loadRejected(roomID: roomID) }
        } else {
            rejectedApplicants.append(applicant)
        }
        onRejectApplicant(trip, applicant.participant)
    }
}

// MARK: - 승인된 동행자 집계

extension HostManageView {
    /// 승인된 동행자 수(호스트 포함). 서버 모임은 서버가 준 참여 인원이 정답이다.
    private var approvedCount: Int {
        usesServerApplications
            ? max(trip.joined, 1) + serverJoinedDelta
            : approvedApplicants.count + 1
    }

    private var approvedAvatars: [HostCompanionAvatar] {
        HostCompanionAvatar.approved(
            usesServer: usesServerApplications,
            serverMembers: serverMembers,
            fallbackCount: approvedCount,
            mockEmojis: [trip.hostAvatar] + approvedApplicants.map(\.avatar)
        )
    }
}

struct HostManageContext: Identifiable, Hashable {
    let trip: TripRecruitment
    let thread: ChatThread

    var id: String {
        trip.id
    }
}

struct HostManageSectionTitle: View {
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

/// 서버가 말하는 방 상태를 읽고 화면 글자로 옮기는 조각.
/// 타입 본문 길이 제한(300줄)에 걸려 확장으로 나눴다 — 화면 구조는 그대로다.
private extension HostManageView {
    /// 서버 상태를 못 읽었으면 넘어온 값 그대로 그린다 — 상태를 지어내지 않는다.
    var isRecruiting: Bool {
        guard let serverRoomStatus else { return !isRecruitmentClosed }
        return serverRoomStatus == "RECRUITING"
    }

    /// 요약 줄의 상태 글자. 서버가 말한 상태가 있으면 그것이 우선이다.
    var summaryStatusText: String {
        switch serverRoomStatus {
        case "CANCELLED":
            return "모집 취소됨"
        case "CONFIRMED":
            return "여행 확정됨"
        default:
            if isRecruitmentClosed { return "모집 취소됨" }
            return trip.recruitmentDeadline.isEmpty ? trip.status.rawValue : trip.recruitmentDeadline
        }
    }

    /// 승인 대기 목록을 서버에서 다시 받아 그린다. 승인·거절이 실패한 뒤에 부른다 —
    /// 그 사이에 신청이 사라졌을 수 있어서다(TC HOST-008). 못 받으면 **아무것도 바꾸지 않는다**.
    func reloadApplications() async {
        guard MoyeoServerSync.isEnabled, let roomID = trip.serverRoomID else { return }
        guard let applications = try? await ChatRoomWriteAPIClient.shared.applications(roomID: roomID) else {
            return
        }
        pendingApplicants = applications.map { ServerTripMapper.hostApplicant(from: $0) }
        usesServerApplications = true
        await loadWaitlist(roomID: roomID)
        await loadRejected(roomID: roomID)
    }

    /// 대기열을 받아 화면에 반영한다. 호스트 전용(참가자는 403)이라 실패하면 빈 채로 둔다 —
    /// 섹션 자체가 신청 목록을 받은(=호스트인) 방에서만 그려지므로 「비어 있음」을 지어내지 않는다.
    func loadWaitlist(roomID: Int64) async {
        guard let entries = try? await ChatRoomWriteAPIClient.shared.waitlist(roomID: roomID) else {
            return
        }
        waitlist = entries
            .sorted { $0.position < $1.position }
            .map { ServerTripMapper.waitlistApplicant(from: $0) }
    }

    /// 거절 기록을 **서버에서** 받아 온다 — `GET /chat-rooms/{roomId}/applications/rejected` (BE-17).
    ///
    /// 예전에는 이 API 가 없는 줄 알고 **이 화면에서 방금 거절한 건**만 모아 두었다.
    /// 화면을 다시 열면 비어서 섹션째 사라졌고, 지난 거절은 어디에서도 볼 수 없었다 (TC HOST-010).
    /// 호스트 전용이라 참가자는 403 이다 — 실패하면 섹션을 그리지 않는다(없다고 지어내지 않는다).
    func loadRejected(roomID: Int64) async {
        guard let entries = try? await ChatRoomWriteAPIClient.shared.rejectedApplications(roomID: roomID) else {
            return
        }
        usesServerRejected = true
        rejectedApplicants = entries.map(ServerTripMapper.rejectedHostApplicant(from:))
        rejectedDetailByID = Dictionary(
            uniqueKeysWithValues: entries.map {
                ("server-application-\($0.applicationId)", ServerTripMapper.rejectedDetailText(from: $0))
            }
        )
    }

    /// 서버가 말하는 방 상태를 읽어 화면에 반영한다. 못 읽으면 **아무것도 바꾸지 않는다**.
    func refreshRoomStatus() async {
        guard MoyeoServerSync.isEnabled, let roomID = trip.serverRoomID else { return }
        guard let detail = try? await ChatRoomAPIClient.shared.detail(roomID: roomID) else { return }
        serverRoomStatus = detail.status
        isRecruitmentClosed = detail.status == "CANCELLED"
    }
}
