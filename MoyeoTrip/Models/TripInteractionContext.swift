//
//  TripInteractionContext.swift
//  MoyeoTrip
//

struct TripInteractionContext {
    var trips: [TripRecruitment] = MockData.trips
    var appliedTripIDs: Set<String> = []
    var chatThreadProvider: (TripRecruitment) -> ChatThread? = { MockData.chatThread(forTripID: $0.id) }
    var onApplyTrip: (TripRecruitment) -> Void = { _ in }
    var onCreateRecruitment: (TripRecruitment, ChatThread) -> Void = { _, _ in }
    var onSendChatMessage: (ChatThread, ChatMessage) -> Void = { _, _ in }
    var onApproveHostApplicant: (TripRecruitment, Participant) -> Void = { _, _ in }
    var onRejectHostApplicant: (TripRecruitment, Participant) -> Void = { _, _ in }
    var onSetRecruitmentClosed: (TripRecruitment, Bool) -> Void = { _, _ in }

    func isApplied(_ trip: TripRecruitment) -> Bool {
        appliedTripIDs.contains(trip.id)
    }
}

extension ChatThread {
    func withAppendedMessage(_ message: ChatMessage) -> ChatThread {
        ChatThread(
            id: id,
            tripTitle: tripTitle,
            region: region,
            mascot: mascot,
            lastMessage: "나: \(message.body)",
            updatedAt: "지금",
            unreadCount: 0,
            statusSummary: statusSummary,
            statusDetail: statusDetail,
            members: members,
            messages: messages + [message],
            isReadOnly: isReadOnly,
            closureReason: closureReason,
            archiveNotice: archiveNotice,
            archiveStatus: archiveStatus
        )
    }
}
