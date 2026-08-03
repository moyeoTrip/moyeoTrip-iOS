//
//  SessionStateExtensions.swift
//  MoyeoTrip
//

extension ProfileSummary {
    func applying(_ authenticatedProfile: AuthDisplayProfile) -> ProfileSummary {
        ProfileSummary(
            name: authenticatedProfile.nickname,
            handle: handle,
            avatar: avatar,
            profileImageURL: authenticatedProfile.profileImageURL,
            region: region,
            badges: badges,
            joinedTrips: joinedTrips,
            hostedTrips: hostedTrips,
            feedCount: feedCount,
            points: points,
            favoriteRegions: favoriteRegions
        )
    }

    func incrementingJoinedTrips() -> ProfileSummary {
        replacingCounts(joinedTrips: joinedTrips + 1, hostedTrips: hostedTrips, feedCount: feedCount)
    }

    func incrementingHostedTrips() -> ProfileSummary {
        replacingCounts(joinedTrips: joinedTrips, hostedTrips: hostedTrips + 1, feedCount: feedCount)
    }

    func incrementingFeedCount() -> ProfileSummary {
        replacingCounts(joinedTrips: joinedTrips, hostedTrips: hostedTrips, feedCount: feedCount + 1)
    }

    private func replacingCounts(joinedTrips: Int, hostedTrips: Int, feedCount: Int) -> ProfileSummary {
        ProfileSummary(
            name: name,
            handle: handle,
            avatar: avatar,
            profileImageURL: profileImageURL,
            region: region,
            badges: badges,
            joinedTrips: joinedTrips,
            hostedTrips: hostedTrips,
            feedCount: feedCount,
            points: points,
            favoriteRegions: favoriteRegions
        )
    }
}

extension TripRecruitment {
    var sessionChatID: String {
        "session-chat-\(id)"
    }

    func withAppliedCurrentUser(_ profile: ProfileSummary) -> TripRecruitment {
        guard canJoin else { return self }

        let currentUser = Participant(id: "participant-current-user", name: profile.name, avatar: profile.avatar)
        let nextJoined = min(joined + 1, capacity)
        let nextParticipants = participants.contains(where: { $0.id == currentUser.id })
            ? participants
            : Array((participants + [currentUser]).prefix(capacity))
        let nextStatus: RecruitmentStatus = nextJoined >= minimumParticipants ? .confirmed : status

        return replacing(joined: nextJoined, status: nextStatus, participants: nextParticipants)
    }

    func withHostApprovedParticipant(_ participant: Participant) -> TripRecruitment {
        guard status != .cancelled else { return self }

        let nextJoined = min(joined + 1, capacity)
        let nextParticipants = participants.contains(where: { $0.id == participant.id })
            ? participants
            : Array((participants + [participant]).prefix(capacity))
        let nextStatus: RecruitmentStatus = nextJoined >= minimumParticipants ? .confirmed : status

        return replacing(joined: nextJoined, status: nextStatus, participants: nextParticipants)
    }

    func withRecruitmentClosed(_ isClosed: Bool) -> TripRecruitment {
        let restoredStatus: RecruitmentStatus = joined >= minimumParticipants ? .confirmed : .open
        return replacing(
            joined: joined,
            status: isClosed ? .cancelled : restoredStatus,
            participants: participants
        )
    }

    func createdChatThread(profile: ProfileSummary) -> ChatThread {
        ChatThread(
            id: sessionChatID,
            tripTitle: title,
            region: region,
            mascot: coverMascot,
            lastMessage: "모집이 열렸어요. 함께 갈 사람을 기다려요.",
            updatedAt: "방금",
            unreadCount: 0,
            statusSummary: chatStatusSummary,
            statusDetail: chatStatusDetail,
            members: participants,
            messages: [
                ChatMessage(
                    id: "\(sessionChatID)-welcome",
                    senderName: "모여트립",
                    avatar: profile.avatar,
                    body: "모집이 열렸어요. 함께 갈 사람을 기다려요.",
                    time: "방금",
                    isMine: false
                )
            ],
            isReadOnly: false
        )
    }

    private func replacing(
        joined: Int,
        status: RecruitmentStatus,
        participants: [Participant]
    ) -> TripRecruitment {
        TripRecruitment(
            id: id,
            courseID: courseID,
            title: title,
            region: region,
            coverMascot: coverMascot,
            hostName: hostName,
            hostAvatar: hostAvatar,
            schedule: schedule,
            meetupPoint: meetupPoint,
            price: price,
            capacity: capacity,
            joined: joined,
            minimumParticipants: minimumParticipants,
            status: status,
            summary: summary,
            vibe: vibe,
            tags: tags,
            route: route,
            participants: participants
        )
    }

    var chatStatusSummary: String {
        "\(joined)/\(capacity)명 · \(status.chatLabel)"
    }

    var chatStatusDetail: String {
        if status == .cancelled {
            return "모집 취소 · 새 신청을 받지 않아요"
        }
        if status == .confirmed {
            return "출발 확정 · 신청 대기 0명"
        }
        if needsMoreParticipants == 0 {
            return "최소 인원을 채워 출발 확정 준비 중이에요."
        }
        return "최소 \(minimumParticipants)명까지 \(needsMoreParticipants)명 남았어요."
    }
}

extension RecruitmentStatus {
    var chatLabel: String {
        switch self {
        case .open:
            return "모집중"
        case .almostFull:
            return "마감 D-1"
        case .confirmed:
            return "확정"
        case .cancelled:
            return "모집 취소"
        }
    }
}

extension ChatThread {
    func withTripStatus(_ trip: TripRecruitment) -> ChatThread {
        ChatThread(
            id: id,
            tripTitle: tripTitle,
            region: region,
            mascot: mascot,
            lastMessage: lastMessage,
            updatedAt: updatedAt,
            unreadCount: unreadCount,
            statusSummary: trip.chatStatusSummary,
            statusDetail: trip.chatStatusDetail,
            members: trip.participants,
            messages: messages,
            isReadOnly: isReadOnly,
            closureReason: closureReason,
            archiveNotice: archiveNotice,
            archiveStatus: archiveStatus
        )
    }

    func withSystemNotice(_ message: String, avatar: String = "🌿") -> ChatThread {
        let notice = ChatMessage(
            id: "\(id)-notice-\(messages.count + 1)",
            senderName: "모여트립",
            avatar: avatar,
            body: message,
            time: "지금",
            isMine: false
        )

        return ChatThread(
            id: id,
            tripTitle: tripTitle,
            region: region,
            mascot: mascot,
            lastMessage: "시스템: \(message)",
            updatedAt: "지금",
            unreadCount: unreadCount,
            statusSummary: statusSummary,
            statusDetail: statusDetail,
            members: members,
            messages: messages + [notice],
            isReadOnly: isReadOnly,
            closureReason: closureReason,
            archiveNotice: archiveNotice,
            archiveStatus: archiveStatus
        )
    }
}
