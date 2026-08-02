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
        SupportList(title: "모집 관리") {
            SupportCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(trip.title)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.ink)
                    SupportField(title: "일정", value: trip.schedule)
                    SupportField(title: "모이는 곳", value: trip.meetupPoint)
                    HStack(spacing: 8) {
                        HostManagePill("\(approvedApplicants.count + 1)/\(trip.capacity)명")
                        HostManagePill("대기 \(pendingApplicants.count)")
                        HostManagePill(isRecruitmentClosed ? "모집 취소됨" : trip.status.rawValue)
                    }
                    Text(statusCopy)
                        .font(.subheadline)
                        .foregroundStyle(MoyeoTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityIdentifier("hostManage.summary")

            HostManageSectionTitle(title: "승인 대기", count: pendingApplicants.count)
            pendingContent

            HostManageSectionTitle(title: "승인된 동행자", count: approvedApplicants.count)
            ForEach(approvedApplicants) { applicant in
                SupportCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HostApplicantHeader(applicant: applicant)
                        Text("집결지와 쉬는 시간을 채팅방에서 함께 확인해요.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MoyeoTheme.muted)
                    }
                }
            }

            if !rejectedApplicants.isEmpty {
                HostManageSectionTitle(title: "거절 기록", count: rejectedApplicants.count)
                ForEach(rejectedApplicants) { applicant in
                    SupportCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HostApplicantHeader(applicant: applicant)
                            Text("거절 사유: 일정과 동선 조건이 맞지 않아요.")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(MoyeoTheme.coral)
                        }
                    }
                    .accessibilityIdentifier("hostRejected.\(applicant.id)")
                }
            }

            HostManageActions(
                isRecruitmentClosed: isRecruitmentClosed,
                hasThread: thread != nil,
                onOpenChat: { selectedThread = thread },
                onToggleClose: {
                    let nextValue = !isRecruitmentClosed
                    isRecruitmentClosed = nextValue
                    onSetRecruitmentClosed(trip, nextValue)
                }
            )
        }
        .navigationDestination(item: $selectedThread) { thread in
            ChatRoomView(thread: thread) { message in
                onSendChatMessage(thread, message)
            }
        }
        .accessibilityIdentifier("screen.hostManage")
    }

    @ViewBuilder
    private var pendingContent: some View {
        if pendingApplicants.isEmpty {
            SupportCard {
                Text("새 신청이 오면 이곳에서 승인하거나 거절할 수 있어요.")
                    .font(.subheadline)
                    .foregroundStyle(MoyeoTheme.muted)
            }
        } else {
            ForEach(pendingApplicants) { applicant in
                HostApplicantCard(
                    applicant: applicant,
                    primaryLabel: "승인",
                    secondaryLabel: "거절",
                    onPrimary: { approve(applicant) },
                    onSecondary: { reject(applicant) }
                )
            }
        }
    }

    private var statusCopy: String {
        if isRecruitmentClosed {
            return "모집이 취소되어 새 신청을 받지 않아요. 채팅방에서는 기존 안내를 확인할 수 있어요."
        }
        return "최소 \(trip.minimumParticipants)명 이상이면 출발 확정 상태로 전환돼요."
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

private struct HostApplicant: Identifiable, Hashable {
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

    var body: some View {
        HStack {
            Text(title)
                .font(.headline.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)
            Spacer()
            Text("\(count)명")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(MoyeoTheme.forest)
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
        SupportCard {
            VStack(alignment: .leading, spacing: 12) {
                HostApplicantHeader(applicant: applicant)
                Text(applicant.note)
                    .font(.subheadline)
                    .foregroundStyle(MoyeoTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button(action: onSecondary) {
                        Text(secondaryLabel)
                            .font(.subheadline.weight(.heavy))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MoyeoTheme.leaf)
                    .foregroundStyle(MoyeoTheme.forest)
                    .accessibilityLabel("\(applicant.name) \(secondaryLabel)")
                    .accessibilityIdentifier("hostApplicant.\(applicant.id).reject")

                    Button(action: onPrimary) {
                        Text(primaryLabel)
                            .font(.subheadline.weight(.heavy))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MoyeoTheme.forest)
                    .accessibilityLabel("\(applicant.name) \(primaryLabel)")
                    .accessibilityIdentifier("hostApplicant.\(applicant.id).approve")
                }
            }
        }
        .accessibilityIdentifier("hostApplicant.\(applicant.id)")
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

private struct HostManagePill: View {
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
