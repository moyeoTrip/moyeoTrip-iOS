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
    /// 15 상세 히어로의 깃발 버튼. **모집 신고는 실제로 접수된다** —
    /// `POST /api/v1/chat-rooms/{roomId}/reports` (2026-09-14 실서버 확인).
    /// 예전에는 접수 API 가 없어 `ReportUnsupportedDialog` 로 안내만 했다.
    @State private var showsReportSheet = false
    // 실서버 연동 상태 — 서버 모임(serverRoomID)일 때만 채워진다
    @State private var serverTrip: TripRecruitment?
    @State private var serverCourse: TravelCourse?
    @State private var serverCanApply: Bool?
    /// 15 참가자 아바타 줄의 근거. `GET /chat-rooms/{roomId}` 의 `participants` 다.
    @State private var serverParticipants: [ServerChatRoomDetail.ServerParticipant] = []
    /// userId → 닉네임. 상세 응답에는 닉네임이 없어 `GET /chat-rooms/{roomId}/members` 로 채운다.
    /// 그 목록이 열리지 않으면 비어 있고, 그때는 사람별 동물 대신 `🐾` 를 쓴다.
    @State private var participantNicknamesByUserID: [Int64: String] = [:]
    /// 호스트 닉네임. **상세 응답에는 없지만 공개 프로필 API 가 준다**(`GET /users/{userId}/profile`).
    /// 멤버 목록(`/members`)은 참여자만 열려 비참여자가 보는 모집 상세에서는 403 이라 쓸 수 없다 —
    /// 그래서 예전에는 「호스트」 라벨만 뜨고 이름이 비어 있었다(사용자 지적 2026-09-12).
    @State private var hostNickname: String?
    @State private var serverJoinResult: ServerJoinResult?
    /// 호스트가 자기 모집을 열었을 때 18 모집 관리로 가는 길. 예전에는 **길이 없어서**
    /// 자기 방을 만들고도 신청 승인·여행 확정을 할 수 없었다 (안드로이드 교차 발견 2026-09-13).
    @State private var supportRoute: SupportRoute?
    /// 참가자 얼굴을 눌러 여는 프로필 카드 (IOS-F103 확인 중 발견).
    @State private var participantProfile: TripParticipantProfileRoute?
    /// ENV-009 · EXTRA-005 — 바닥 CTA 가 실제로 차지하는 높이. 예전에는 128pt 로 못박아
    /// 두었는데, 신청 불가 사유 한 줄이 붙거나 홈 인디케이터가 있는 기기에서는 CTA 가 더
    /// 높아져 마지막 카드(길 찾기 줄)를 덮었다 — 보이기만 하고 누를 수가 없었다.
    @State private var bottomBarHeight: CGFloat = 128

    /// 서버가 말하는 내 참여·신청 상태(`APPLIED` · `WAITING` …). 앱을 다시 켜도 남는다.
    @State private var serverParticipationStatus: String?
    /// 서버가 **그런 방이 없다(404)** 고 답했는지. 목록 카드가 준 값으로 상세를 계속 그리면
    /// 없는 모집을 **있는 것처럼** 보여주고, 카드에 없는 값(나이대·성별·집합)은 기본값으로 채워
    /// 「나이대 제한 없음」 같은 **없는 사실**까지 적는다 (2026-09-15 기기 확인 · NO-MOCK-CANON R2).
    @State private var serverDetailMissing = false

    private var appliedState: Bool {
        isApplied || didApplyInSession
            || serverParticipationStatus == "APPLIED" || serverParticipationStatus == "WAITING"
    }

    /// 서버 상세를 받아오면 서버 데이터로, 아니면 진입 시 받은 데이터로 그린다
    private var displayTrip: TripRecruitment {
        serverTrip ?? trip
    }

    /// 아직 서버 상세를 못 받은 **빈 껍데기**인가.
    ///
    /// 모집을 만든 직후·알림에서 들어오면 `ServerTripMapper.placeholderTrip` 으로 넘어오는데,
    /// 그 껍데기는 `capacity: 0 · joined: 0 · status: .open` 이다. 골격 그대로 그리면
    /// 「0/0명 · 모집중」이라는 **없는 사실**이 잠깐 보인다 (IOS-F146, NO-MOCK-CANON R2).
    private var isAwaitingServerDetail: Bool {
        serverTrip == nil && trip.isServerBacked && trip.capacity == 0 && trip.summary.isEmpty
    }

    /// 내가 이 모집의 호스트인가. 토큰의 userId 와 상세 응답의 `hostId` 를 견준다.
    private var isCurrentUserHost: Bool {
        guard let hostID = displayTrip.hostUserID, let myID = MoyeoCurrentUser.id else { return false }
        return hostID == myID
    }

    /// **내가 이미 이 방에 들어가 있는가.** 상세 응답의 `participants` 에 내 userId 가 있으면 참가자다.
    ///
    /// 서버 `canApply()` 는 참가자·호스트에게도 `false` 를 준다. 그 값을 「신청할 수 없음」으로만
    /// 읽으면 **내가 들어가 있는 방이 거절당한 것처럼** 보였다 — 배지는 「신청 불가」, CTA 는
    /// 회색 「함께 가기 신청」이었다 (웹 교차 발견 2026-09-14).
    private var isCurrentUserParticipant: Bool {
        guard let myID = MoyeoCurrentUser.id else { return false }
        return serverParticipants.contains { $0.userId == myID }
    }

    var body: some View {
        ZStack {
            if serverDetailMissing {
                missingDetailState
            } else if isAwaitingServerDetail {
                // 값을 아직 모른다 — 지어낸 골격 대신 「받는 중」이라고 말한다.
                MoyeoEmptyStateView(
                    message: MoyeoEmptyText.loading,
                    accessibilityIdentifier: "tripDetail.loading"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(MoyeoTheme.background.ignoresSafeArea())
            } else {
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
                                    showsReportSheet = true
                                },
                                canReport: displayTrip.serverRoomID != nil && !isCurrentUserHost
                            )
                            if let feedbackMessage {
                                TripDetailFeedbackBanner(message: feedbackMessage)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 12)
                            }
                            TripDetailPanel(
                                trip: displayTrip,
                                // **서버 판정(`canApply`)을 배지에도 넘긴다.** 정원만 보면 이미 참가한 방에서도
                                // 「신청 가능」이 뜨는데 아래 CTA 는 못 누르는 상태였다 (2026-09-10 · 방 22).
                                // 웹은 처음부터 `canApply` 로 그리고 있었다.
                                serverCanApply: serverCanApply,
                                // 내 자리를 배지에 넘긴다 — 참여 중인 방에 「신청 불가」가 뜨면 안 된다.
                                isCurrentUserHost: isCurrentUserHost,
                                isCurrentUserParticipant: isCurrentUserParticipant,
                                isCurrentUserApplicant: appliedState && !isCurrentUserParticipant,
                                serverCourse: serverCourse,
                                participants: serverParticipants,
                                onSelectParticipant: openParticipantProfile,
                                participantNicknamesByUserID: participantNicknamesByUserID,
                                hostNickname: hostNickname
                            )
                                .padding(.top, feedbackMessage == nil ? -28 : 12)
                        }
                        .frame(width: proxy.size.width)
                        // ENV-009 · EXTRA-005 — 바닥 CTA 가 실제로 차지한 높이만큼 비운다
                        .padding(.bottom, bottomBarHeight + 24)
                    }

                    if isCurrentUserHost, let roomID = displayTrip.serverRoomID {
                        TripDetailHostManageBar {
                            supportRoute = .hostManage(
                                "\(ServerTripMapper.serverTripIDPrefix)\(roomID)"
                            )
                        }
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                            if height > 0 { bottomBarHeight = height }
                        }
                    } else {
                    TripDetailBottomBar(
                        canJoin: displayTrip.canJoin && (serverCanApply ?? true),
                        // 못 누르는 상태를 **활성 초록으로 칠하지 않는다** — 웹은 같은 자리를 회색으로 둔다.
                        // 「신청 상태 보기」는 실제로 누를 수 있으므로 활성이다.
                        // 이미 들어가 있는 방이면 **누를 수 있다** — 할 일이 「신청」이 아니라 「열기」다.
                        isEnabled: isCurrentUserParticipant || appliedState
                            || (serverCanApply != false && displayTrip.status != .cancelled),
                        // 버튼 이름은 상태와 무관하게 **하는 일**을 적는다 — 못 누르는 이유는 위 배지가 말한다.
                        // 기획·웹이 「함께 가기 신청」을 회색으로 두는 것과 같다 (2026-09-10).
                        actionTitle: serverCanApply == false ? "함께 가기 신청" : displayTrip.applicationActionTitle,
                        isApplied: isCurrentUserParticipant || appliedState,
                        isAppliedTitle: isCurrentUserParticipant
                            ? "채팅방 열기"
                            : (displayTrip.isServerBacked ? appliedServerTitle : "모임 채팅으로 이동"),
                        isFavorite: isFavorite,
                        // 서버 `canApply` 가 이미 성별·연령 조건을 반영한다 — 조건 값도 같은 응답으로
                        // 오므로 **누르기 전에** 왜 안 되는지 적는다.
                        blockedReason: applyBlockedReason(for: displayTrip),
                        onToggleFavorite: toggleFavorite,
                        onApply: {
                            // 참가자는 곧장 방으로 간다 — 세션 신청 기록이 없어도 이미 멤버다.
                            if isCurrentUserParticipant, displayTrip.isServerBacked,
                               let roomID = displayTrip.serverRoomID {
                                selectedThread = threadProvider(trip)
                                    ?? ServerTripMapper.stubThread(serverRoomID: roomID)
                            } else if appliedState {
                                openRoomOrTellStatus()
                            } else if displayTrip.status == .cancelled {
                                feedbackMessage = "모집이 취소되어 신청할 수 없어요."
                            } else if displayTrip.isServerBacked, serverCanApply == false {
                                feedbackMessage = applyBlockedReason(for: displayTrip)
                                    ?? "지금은 이 모임에 신청할 수 없어요."
                            } else {
                                isApplicationPresented = true
                            }
                        }
                    )
                    .frame(width: proxy.size.width)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                        if height > 0 { bottomBarHeight = height }
                    }
                    }
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
                        // 「모임 채팅으로 이동」은 **서버 모임에서도** 실제로 이동해야 한다.
                        // 예전에는 목데이터 방일 때만 스레드를 세워, 실서버 방에서는
                        // 시트만 닫히고 아무 데도 가지 않았다 (IOS-F15).
                        //
                        // 다만 **바로 참여된 경우에만** 방으로 보낸다 — 승인 대기·대기열은
                        // 아직 방에 못 들어가고, 들여보내면 서버가 403 으로 막는다.
                        // 여기서도 `threadProvider` 를 먼저 물으면 **다른 방 스레드**가 열린다(위 `onApply` 와 같다).
                        if displayTrip.isServerBacked, serverJoinResult != .joined {
                            // 승인 대기·대기열 — 방으로 보내지 않는다. 결과 문구는 시트가 이미 띄웠다.
                        } else if let thread = threadProvider(trip) {
                            selectedThread = thread
                        } else if displayTrip.isServerBacked,
                                  serverJoinResult == .joined,
                                  let roomID = displayTrip.serverRoomID {
                            selectedThread = ServerTripMapper.stubThread(serverRoomID: roomID)
                        }
                    },
                    serverSubmitHandler: serverSubmitHandler
                )
                .transition(.opacity)
            }

            // 신고 시트는 **신청 시트와 같은 자리**에 얹는다. `.overlay` 로 두면 화면 아래쪽
            // 버튼(취소·신고하기)이 하단 CTA 띠에 가려 탭이 닿지 않았다 — 시트는 보이는데
            // 아무 버튼도 눌리지 않는 죽은 시트가 됐다 (2026-09-14 기기에서 확인).
            // 서버 모집일 때만 신고할 수 있다 — 목데이터 방은 서버에 보낼 id 가 없다.
            if showsReportSheet, let roomID = displayTrip.serverRoomID {
                MoyeoReportSheet(
                    target: .chatRoom(roomID: roomID),
                    previewText: displayTrip.title
                ) {
                    showsReportSheet = false
                }
                .transition(.opacity)
            }
            }
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $participantProfile) { route in
            ProfileCardView(subject: route.subject)
        }
        .navigationDestination(item: $supportRoute) { route in
            SupportDestinationView(route: route)
        }
        .navigationDestination(item: $selectedThread) { thread in
            ChatRoomView(thread: thread) { message in
                onSendChatMessage(thread, message)
            }
        }
        .task {
            if startsWithApplicationSheet { isApplicationPresented = true }
            await loadServerDetail()
        }
    }

    /// 신청 버튼을 막는 이유. 막을 이유가 없으면 nil 이다.
    ///
    /// 서버 `canApply == false` 인 경우는 (1) 취소·마감, (2) 이미 참여·신청 중,
    /// (3) 성별/연령 조건 미달 셋뿐이다(`ChatRoomService.canApply`). (2)는 아래에서 먼저 갈라내고,
    /// 남는 (1)·(3)을 구분해 **누르기 전에** 이유를 적는다.
    private func applyBlockedReason(for trip: TripRecruitment) -> String? {
        guard !isCurrentUserHost, !isCurrentUserParticipant, !appliedState else { return nil }
        guard serverCanApply == false else { return nil }
        if trip.status == .cancelled { return "모집이 끝나서 더는 신청할 수 없어요." }
        return trip.conditionSentence
            ?? "지금은 이 모임에 신청할 수 없어요. 모집이 마감됐거나 이미 신청한 모임이에요."
    }

    /// 신청한 뒤 하단 CTA 에 적는 말.
    ///
    /// 예전에는 결과를 모르면 무조건 **「신청 완료 · 승인 대기」**였다. 그런데 자동 승인 방에서는
    /// 기다릴 일이 없고, 이미 참여 중인 방에서도 같은 문구가 떠서 **상태와 어긋났다** (IOS-F05).
    /// 이제 모르는 경우에는 **단정하지 않고** 「신청 상태 보기」로 둔다 — 눌러서 하는 일 그대로다.
    private var appliedServerTitle: String {
        switch serverJoinResult {
        case .joined:
            return "참여가 확정됐어요"
        case .waitlisted:
            return "대기열 등록됨"
        case .pendingApproval:
            return "신청 완료 · 승인 대기"
        default:
            // 승인 방식을 알면 그만큼만 말한다. 그래도 모르면 상태를 지어내지 않는다.
            return displayTrip.joinApprovalMode == "MANUAL" ? "신청 완료 · 승인 대기" : "신청 상태 보기"
        }
    }

    private var appliedServerFeedback: String {
        switch serverJoinResult {
        case .joined:
            return "참여가 확정됐어요. 모임 탭에서 확인할 수 있어요."
        case .waitlisted:
            return "대기열에 등록됐어요. 자리가 나면 순서대로 합류돼요."
        case .pendingApproval:
            return "호스트 승인을 기다리고 있어요. 결과는 알림으로 알려드려요."
        default:
            return displayTrip.joinApprovalMode == "MANUAL"
                ? "호스트 승인을 기다리고 있어요. 결과는 알림으로 알려드려요."
                : "신청은 접수됐어요. 진행 상황은 모임 탭에서 확인할 수 있어요."
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
            // 신청하면 인원·상태가 바뀐다 — 상세를 다시 읽지 않으면 배지가 옛 값 그대로다 (IOS-F06).
            await loadServerDetail()
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
                feedbackMessage = error.moyeoUserMessage(
                    fallback: "찜 처리에 실패했어요. 잠시 후 다시 시도해주세요."
                )
            }
        }
    }

    private func loadServerDetail() async {
        guard let roomID = trip.serverRoomID, MoyeoServerSync.isEnabled else { return }
        let course = (try? await TravelCourseAPIClient.shared.roomCourse(roomID: roomID))?.course
        do {
            let detail = try await ChatRoomAPIClient.shared.detail(roomID: roomID)
            serverTrip = ServerTripMapper.trip(from: detail, course: course)
            isFavorite = detail.favorite
            // 참가 가능 여부는 상세 응답의 canApply 다. 예전 /join-eligibility 는 서버에서 삭제됐다.
            serverCanApply = detail.canApply
            serverParticipationStatus = detail.myParticipationStatus
            // 아바타 줄은 서버가 준 참가자만 그린다 — 0건이면 줄 자체가 없다 (NO-MOCK R1).
            serverParticipants = detail.participants
        } catch {
            // 「없는 방」만 빈 화면으로 바꾼다. 통신 실패·서버 오류는 예전처럼 카드 값으로 그린다 —
            // 잠깐 못 읽은 것을 「삭제됐다」고 단정하지 않는다.
            if case .server(let statusCode, let code, _) = (error as? MoyeoAPIError) ?? .invalidResponse,
               statusCode == 404 || code == 40404 {
                serverDetailMissing = true
            }
        }
        serverCourse = course.map(ServerCourseMapper.course(from:))
        await loadParticipantNicknames(roomID: roomID)
        await loadHostNickname()
    }

    /// 호스트 공개 프로필. 실패해도 화면을 막지 않는다 — 이름 줄만 비운다.
    private func loadHostNickname() async {
        guard let hostID = displayTrip.hostUserID else { return }
        guard let profile = try? await UserProfileAPIClient.shared.publicProfile(userID: hostID) else { return }
        hostNickname = profile.nickname
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

// MARK: - 신청한 뒤 CTA 를 눌렀을 때

private extension TripDetailView {
    /// 참가자 얼굴을 눌렀을 때. 닉네임은 아는 만큼만 넘기고 나머지는 공개 프로필이 채운다.
    func openParticipantProfile(_ participant: ServerChatRoomDetail.ServerParticipant) {
        participantProfile = TripParticipantProfileRoute(
            id: participant.userId,
            subject: .serverUser(
                ProfileCardUserReference(
                    userID: participant.userId,
                    nickname: participantNicknamesByUserID[participant.userId] ?? "",
                    profileImageUrl: participant.profileImageUrl,
                    introduction: nil,
                    nicknameColor: nil
                )
            )
        )
    }

    /// 서버가 「그런 방이 없다」고 한 경우. 목록 카드 값으로 상세를 지어내지 않는다.
    var missingDetailState: some View {
        MoyeoEmptyStateView(
            message: "이 모집을 찾을 수 없어요. 이미 사라졌거나 주소가 잘못됐어요.",
            systemImage: "questionmark.circle",
            accessibilityIdentifier: "tripDetail.missing"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MoyeoTheme.background.ignoresSafeArea())
    }

    /// 「신청 완료 · 승인 대기」·「신청 상태 보기」를 눌렀을 때 하는 일.
    ///
    /// 승인돼 참여 중이면 채팅방을 열고, **승인 대기·대기열이면 방을 열지 않고 상태만 알린다** (IOS-F15).
    /// `threadProvider` 를 먼저 물으면 안 된다 — 아직 들어가지도 않은 방에 목록이 들고 있던
    /// **다른 방 스레드**를 내주어, 승인 대기 상태에서 이 버튼을 누르면 남의 집합 정보가 적힌
    /// 채팅방이 열렸다(2026-09-15 기기에서 확인 — 방 425 에 신청한 직후 청송 집합 정보가 떴다).
    func openRoomOrTellStatus() {
        if displayTrip.isServerBacked, !isCurrentUserParticipant, serverJoinResult != .joined {
            feedbackMessage = appliedServerFeedback
            return
        }
        if let thread = threadProvider(trip) {
            selectedThread = thread
        } else if displayTrip.isServerBacked, serverJoinResult == .joined,
                  let roomID = displayTrip.serverRoomID {
            selectedThread = ServerTripMapper.stubThread(serverRoomID: roomID)
        } else {
            feedbackMessage = appliedServerFeedback
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
    let onReport: () -> Void
    /// 깃발을 그릴지. 서버 모집이 아니거나 **내가 연 모집**이면 두지 않는다 —
    /// 보낼 id 가 없거나 서버가 `40044`(본인이 개설한 모집)로 거절할 버튼이다 (죽은 UI).
    var canReport = true

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
                    if canReport {
                        HeroIconButton(systemImage: "flag", label: "신고", action: onReport)
                    }
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
    /// 얼굴을 눌렀을 때. 넘기지 않으면 **누를 수 없는 장식**이다(예전 동작).
    var onSelect: ((ServerChatRoomDetail.ServerParticipant) -> Void)?
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
                // 상세 응답이 `userId` 를 주는데도 **얼굴이 눌리지 않았다** —
                // 프로필 카드로 가는 길이 여기서 끊겨 있었다 (IOS-F103 확인 중 발견).
                if let onSelect {
                    Button { onSelect(participant) } label: { avatar(participant) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("참가자 프로필 보기")
                        .accessibilityIdentifier("trip.detail.participant.\(participant.userId)")
                } else {
                    avatar(participant)
                }
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
    /// `GET /chat-rooms/{id}` 의 `canApply`. 서버가 모집 상태·마감·기존 신청·성별/나이 제한을
    /// 모두 반영해 준 값이라 **정원 계산보다 이쪽이 우선**이다. 목 데이터에는 없어 nil 이다.
    var serverCanApply: Bool?
    /// 내가 이 방의 호스트인지 / 이미 참여 중인지. `canApply == false` 의 **이유**를 가르는 값이다.
    var isCurrentUserHost = false
    var isCurrentUserParticipant = false
    /// 내가 이미 신청해 **승인을 기다리는** 방인지. `canApply == false` 의 이유를 한 겹 더 가른다.
    var isCurrentUserApplicant = false
    var serverCourse: TravelCourse?
    var participants: [ServerChatRoomDetail.ServerParticipant] = []
    var onSelectParticipant: ((ServerChatRoomDetail.ServerParticipant) -> Void)?
    var participantNicknamesByUserID: [Int64: String] = [:]
    /// 공개 프로필에서 받은 호스트 닉네임. 못 받았으면 nil 이고, 그때는 이름 줄을 그리지 않는다.
    var hostNickname: String?

    /// 공개 프로필 > 멤버 목록 > 목데이터 순으로 읽는다. 셋 다 없으면 nil 이라 이름 줄을 그리지 않는다.
    private var hostDisplayName: String? {
        if let hostNickname, !hostNickname.isEmpty { return hostNickname }
        if let hostID = trip.hostUserID, let fromMembers = participantNicknamesByUserID[hostID],
           !fromMembers.isEmpty {
            return fromMembers
        }
        return trip.hostName.isEmpty ? nil : trip.hostName
    }

    /// 웹과 같은 순서로 읽는다 — **내 자리가 먼저**고, 그다음이 서버 판정이다.
    ///
    /// `canApply == false` 는 「정원이 찼다」일 수도 있고 「네가 이미 멤버다」일 수도 있다.
    /// 구분하지 않고 「신청 불가」로 적으면 자기가 연 모임에서도 거절당한 것처럼 보였다.
    private var applicationBadgeText: String {
        if isCurrentUserHost { return "내가 연 모임" }
        if isCurrentUserParticipant { return "참여 중" }
        // 신청해 두고 기다리는 사람에게 「신청 불가」는 틀린 말이다 — 막힌 게 아니라 **기다리는 중**이다.
        if isCurrentUserApplicant { return "승인 대기" }
        if serverCanApply == false { return "신청 불가" }
        return trip.canJoin ? "신청 가능" : "대기 가능"
    }

    /// 배지 색 — 내 자리를 알리는 배지는 경고색(코랄)이 아니다.
    private var isApplicationBadgeBlocking: Bool {
        !isCurrentUserHost && !isCurrentUserParticipant && !isCurrentUserApplicant
            && serverCanApply == false
    }

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
                    onSelect: onSelectParticipant,
                    nicknamesByUserID: participantNicknamesByUserID
                )
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text("\(trip.joined) / \(trip.capacity)명")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.ink)
                    Text(applicationBadgeText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isApplicationBadgeBlocking ? MoyeoTheme.coral : trip.status.tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((isApplicationBadgeBlocking ? MoyeoTheme.coral : trip.status.tint).opacity(0.14))
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
                            // ENV-009 — 글자 크기는 그대로 두고 누를 수 있는 넓이만 44x44 로 넓힌다
                            // (재던 값 34x14pt). 글자에만 반응하면 손가락으로는 거의 못 누른다.
                            Text("길 찾기")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(MoyeoTheme.brandText)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
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
                // 승인 방식은 **신청 버튼을 누르기 전에** 알아야 하는 값이다 — 예전에는
                // 상세가 이 값을 읽지 않아, 누르고 나서야 기다려야 하는지 알았다 (IOS-F103).
                // 2x2 가 아니라 한 줄을 통째로 쓰는 것은 설명 문장이 붙기 때문이다.
                if let title = trip.approvalModeTitle {
                    HStack(alignment: .top, spacing: 12) {
                        DetailInfoRow(
                            icon: trip.joinApprovalMode == "AUTO" ? "bolt.badge.checkmark" : "hand.raised",
                            title: "신청 승인",
                            value: title,
                            caption: trip.approvalModeDetail
                        )
                    }
                    .accessibilityIdentifier("trip.detail.approvalMode")
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
                    // 호스트 이름은 **공개 프로필에서 받아 온다.** 모집 상세 응답에는 없지만
                    // `GET /users/{userId}/profile` 이 준다 — 못 받았을 때만 줄을 비운다.
                    if let name = hostDisplayName {
                        Text(name)
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(MoyeoTheme.ink)
                    }
                    // 매너 점수는 아직 서버가 null 로 준다 — 지어내지 않고 줄을 만들지 않는다
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
    /// 값만으로는 뜻이 전해지지 않는 항목에 붙이는 한 줄(신청 승인 방식 등).
    var caption: String?

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
                if let caption {
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(MoyeoTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
                    fallback: { MoyeoMapUnavailableView(message: "지도를 불러오지 못했어요. 아래 방문지 목록으로 코스를 볼 수 있어요.") }
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
    /// 누를 수 있는 상태인지. false 면 회색으로 그리고 탭도 받지 않는다.
    var isEnabled = true
    let actionTitle: String
    let isApplied: Bool
    var isAppliedTitle = "모임 채팅으로 이동"
    let isFavorite: Bool
    /// 왜 못 누르는지 **버튼 위에서** 말한다 — 눌러야만 알던 실패를 미리 알린다. 없으면 줄을 그리지 않는다.
    var blockedReason: String?
    let onToggleFavorite: () -> Void
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let blockedReason {
                Text(blockedReason)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MoyeoTheme.coral)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("trip.detail.apply.blockedReason")
            }
            actionRow
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

    private var actionRow: some View {
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
                    .foregroundStyle(isEnabled ? .white : MoyeoTheme.text400)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(isEnabled ? MoyeoTheme.forest : MoyeoTheme.softLine)
                    .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .accessibilityIdentifier("trip.detail.apply")
        }
    }
}

extension TripRecruitment {
    /// 이 모집의 참가 조건을 한 줄로. 조건이 하나도 없으면 nil 이라 줄을 그리지 않는다.
    ///
    /// 서버 상세 응답이 `genderRestriction`·`minimumAge`·`maximumAge` 를 `canApply` 와 함께 주므로
    /// **막는 이유까지 화면에서 말할 수 있다**. 예: 「이 모집은 만 25~35세 여성만 참여할 수 있어요.」
    var conditionSentence: String? {
        var parts: [String] = []
        switch (minimumAge, maximumAge) {
        case let (minimum?, maximum?): parts.append("만 \(minimum)~\(maximum)세")
        case let (minimum?, nil): parts.append("만 \(minimum)세 이상")
        case let (nil, maximum?): parts.append("만 \(maximum)세 이하")
        case (nil, nil): break
        }
        // `genderRestriction` 은 이미 한국어 표기다 (`ServerChatRoomTripMapping.genderText`).
        switch genderRestriction {
        case "여성만": parts.append("여성")
        case "남성만": parts.append("남성")
        default: break
        }
        guard !parts.isEmpty else { return nil }
        return "이 모집은 \(parts.joined(separator: " "))만 참여할 수 있어요."
    }

    var detailMetaText: String {
        ([region] + tags.prefix(2))
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    /// 17-5 신청 승인 방식 — 신청하는 사람이 **누르기 전에** 알아야 하는 값이다.
    /// 서버가 안 줬거나 모르는 값이면 nil 이라 줄을 그리지 않는다 (IOS-F103).
    var approvalModeTitle: String? {
        switch joinApprovalMode {
        case "AUTO": return RecruitmentApprovalMode.automatic.rawValue
        case "MANUAL": return RecruitmentApprovalMode.manual.rawValue
        default: return nil
        }
    }

    /// 「그래서 내가 신청하면 어떻게 되는가」를 한 줄로 적는다.
    /// 만들기 화면(`RecruitmentApprovalMode.detail`)은 **호스트에게** 하는 말이라,
    /// 같은 뜻을 신청자 쪽에서 다시 썼다.
    var approvalModeDetail: String? {
        switch joinApprovalMode {
        // 웹·안드로이드와 **같은 문구**로 맞췄다 — iOS 만 「신청하는 대로 바로」였다.
        case "AUTO": return "조건에 맞으면 신청하는 즉시 합류해요."
        // 「호스트가 남긴 한마디」는 **호스트가** 적은 것처럼 읽힌다. 실제로는 신청자가 적는다.
        case "MANUAL": return "신청할 때 남긴 한마디를 호스트가 확인하고 수락하면 합류해요."
        default: return nil
        }
    }

    /// 서버 모임은 나이 제한이 없으면 null 을 내려준다 — "제한 없음"으로 표기한다.
    /// 예전에는 `0` 을 「없음」의 표시로 썼는데, 값이 없는 것과 0 은 다르다.
    var displayAgeRangeText: String {
        switch (minimumAge, maximumAge) {
        case let (minimum?, maximum?): return "\(minimum)~\(maximum)세"
        case let (minimum?, nil): return "\(minimum)세 이상"
        case let (nil, maximum?): return "\(maximum)세 이하"
        case (nil, nil): return "제한 없음"
        }
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

/// 호스트가 자기 모집 상세에서 18 모집 관리로 가는 줄.
/// 호스트에게 「함께 가기 신청」을 보여 줄 이유가 없고, 정작 필요한 관리 진입점은 없었다.
private struct TripDetailHostManageBar: View {
    let onOpenHostManage: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text("내가 연 모집이에요")
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.forest)
            Button(action: onOpenHostManage) {
                Text("모집 관리 · 신청 승인 · 여행 확정")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: MoyeoTheme.ctaHeight)
                    .background(MoyeoTheme.forest)
                    .clipShape(
                        RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("tripDetail.hostManage")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background(MoyeoTheme.card)
        .overlay(alignment: .top) { Rectangle().fill(MoyeoTheme.softLine).frame(height: 1) }
    }
}

/// 참가자 얼굴에서 여는 프로필 카드의 목적지.
/// `ProfileCardSubject` 는 `Identifiable` 이 아니라 `navigationDestination(item:)` 에 바로
/// 넘길 수 없어, userId 를 id 로 쓰는 얇은 껍데기를 둔다.
private struct TripParticipantProfileRoute: Identifiable, Hashable {
    let id: Int64
    let subject: ProfileCardSubject
}
