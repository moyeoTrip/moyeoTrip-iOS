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
                        participantText: "\(approvedApplicants.count + 1)/\(trip.capacity)명",
                        status: isRecruitmentClosed ? "모집 취소됨" : trip.status.rawValue
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

                    HostManageSectionTitle(title: "승인된 동행자", count: approvedApplicants.count)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 12)

                    HostApprovedCompanionsRow(
                        avatars: [trip.hostAvatar] + approvedApplicants.map(\.avatar),
                        count: approvedApplicants.count + 1
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
                Text("채팅방 들어가기")
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
        .accessibilityIdentifier("screen.hostManage")
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
                HostCompactApplicantRow(applicant: applicant, detail: "신청 한마디 보기")
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
            return "여행 확정 전까지 수정할 수 있어요. 저장 시 멤버 모두에게 알려요."
        case .linkedLocked:
            return "등록 코스의 경로는 고정돼요. 집합 정보는 수정할 수 있어요."
        case .tripConfirmed:
            return "여행이 확정되어 경로가 잠겼어요. 변경은 공지로 알려주세요."
        }
    }

    private func approve(_ applicant: HostApplicant) {
        pendingApplicants.removeAll { $0.id == applicant.id }
        approvedApplicants.append(applicant)
        onApproveApplicant(trip, applicant.participant)
    }

    private func reject(_ applicant: HostApplicant) {
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

struct HostApplicant: Identifiable, Hashable {
    let id: String
    let name: String
    let avatar: String
    let note: String

    var participant: Participant {
        Participant(id: id, name: name, avatar: avatar)
    }

    static let mockPending = [
        HostApplicant(
            id: "applicant-deer",
            name: "따스한 사슴 3492",
            avatar: "🦌",
            note: "사진 찍는 속도에 맞춰 천천히 걷고 싶어요."
        ),
        HostApplicant(
            id: "applicant-turtle",
            name: "잔잔한 거북이 9032",
            avatar: "🐢",
            note: "초행이라 모이는 장소와 준비물을 미리 확인하고 싶어요."
        )
    ]

    static let mockApproved = [
        HostApplicant(id: "approved-bear", name: "우직한 곰 7821", avatar: "🐻", note: "기존 참여자")
    ]
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
            Text(trailingNote ?? "\(count)명")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MoyeoTheme.muted)
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
            // 신청 한마디는 인용 블록으로 (화면기획)
            Text("\u{201C}\(applicant.note)\u{201D}")
                .font(.caption)
                .foregroundStyle(MoyeoTheme.muted)
                .lineLimit(2)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                .background(MoyeoTheme.subtleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

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
            Text(applicant.avatar)
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(MoyeoTheme.leaf)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(applicant.name)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                Text("매너 4.8 · 최근 동행 2회")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.muted)
            }
            Spacer()
        }
    }
}

struct HostManagePill: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.heavy))
            .foregroundStyle(MoyeoTheme.forest)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(MoyeoTheme.leaf)
            .clipShape(Capsule())
    }
}
