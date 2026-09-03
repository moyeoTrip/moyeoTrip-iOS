//
//  ChatRoomWriteAPIClient.swift
//  MoyeoTrip
//
//  참여 중인 채팅방의 쓰기 연동 — 20-2 첨부 5종 · 투표 참여/취소 · 공지 고정 토글 ·
//  방별 알림 설정 · 집합 정보 수정 · 승인/거절 · 나가기/강퇴 · 동행자 조회/평가.
//
//  읽기(`ChatRoomContentAPIClient`)와 달리 이 파일의 호출은 **서버 상태를 바꾼다.**
//  화면은 실패하면 아무것도 바꾸지 않고 기존 값을 유지한다(목데이터 폴백 규칙과 같다).
//
//  파괴적 호출(`leave` · `kickMember` · `changeStatus` · `reviewCompanion`)은 QA 데이터를
//  되돌릴 수 없어 이 파일에만 배선되어 있고, 호출부에서 사용자 확인을 거친 뒤에만 실행된다.
//

import Foundation

// MARK: - 요청 모델

/// `POST /chat-rooms/{id}/messages` — 일반 텍스트 메시지 (1~1000자).
struct ServerSendChatMessageRequest: Encodable {
    let content: String
    let replyToMessageId: Int64?
    let mentionedUserIds: [Int64]
}

/// `POST /chat-rooms/{id}/messages/tourism-contents`
struct ServerShareTourismContentRequest: Encodable {
    let contentId: Int64
}

/// `POST /chat-rooms/{id}/messages/polls` — 선택지는 2~5개, `anonymous` 를 생략하면 익명이다.
/// 서버 필드명은 `question` 이다(`title` 이 아니다).
struct ServerCreatePollRequest: Encodable {
    let question: String
    let options: [String]
    let anonymous: Bool
}

/// `POST /chat-rooms/{id}/messages/settlement-memos` — 송금이 아니라 메모다.
struct ServerSettlementMemoRequest: Encodable {
    let memo: String
}

/// `POST /chat-rooms/{roomId}/status` — 호스트가 `CONFIRMED` · `CANCELLED` 로 전이시킨다.
struct ServerChatRoomStatusRequest: Encodable {
    let status: String
}

/// `POST /chat-rooms/{id}/notices`
struct ServerCreateNoticeRequest: Encodable {
    let notice: String
    let pinned: Bool
}

/// `PUT /chat-rooms/{id}/notices/{noticeId}` — 내용만 고칠 때는 `pinned` 를,
/// 고정만 토글할 때는 `notice` 를 null 로 둔다. **둘 다 null 이면 서버가 공지를 삭제한다.**
struct ServerUpdateNoticeRequest: Encodable {
    let notice: String?
    let pinned: Bool?
}

/// `PUT /chat-rooms/{id}/meeting-info` — `meetingDateTime` 만 필수다.
struct ServerUpdateMeetingInfoRequest: Encodable {
    let meetingLatitude: Double?
    let meetingLongitude: Double?
    let meetingDetails: String?
    let meetingDateTime: String
}

/// `DELETE /chat-rooms/{id}/members/{memberId}` — 사유는 필수(1~500자)다.
struct ServerKickMemberRequest: Encodable {
    let reason: String
}

/// `PUT /chat-rooms/{id}/companions/{companionUserId}/review`
struct ServerCompanionReviewRequest: Encodable {
    let mannerScore: Int
    let oneLineReview: String?
}

/// `PUT /notifications/settings/chat-rooms/{roomId}`
struct ServerChatRoomNotificationUpdate: Encodable {
    let enabled: Bool
}

// MARK: - 응답 모델

/// `GET·PUT /notifications/settings/chat-rooms/{roomId}` — 20-1 "이 모임의 알림만 끄기"
struct ServerChatRoomNotificationSetting: Decodable, Hashable {
    let roomId: Int64
    let enabled: Bool
}

/// `GET /chat-rooms/{roomId}/applications` — 18 모집 관리의 승인 대기 카드
struct ServerJoinApplication: Decodable, Identifiable, Hashable {
    let applicationId: Int64
    /// 스펙상 required 지만 타입이 nullable 이다 — 한마디를 안 남긴 신청이면 null 로 온다.
    let applicationMessage: String?
    let applicant: ServerApplicantProfile
    let appliedAt: String

    var id: Int64 { applicationId }
}

struct ServerApplicantProfile: Decodable, Hashable {
    let userId: Int64
    let nickname: String
    let profileImageUrl: String?
    /// `"M"` · `"F"` · null(생년월일·성별 미입력)
    let gender: String?
    let age: Int?
    /// 실서버에서 **항상 null** 이다 — 값이 없으면 매너 표기를 숨긴다.
    let mannerRating: Double?
    let completedTripCount: Int

    var profileImageURL: URL? {
        MoyeoImageURL.resolve(profileImageUrl)
    }
}

/// `POST .../applications/{applicationId}/approve` — 정원이 차면 `WAITLISTED` 다.
struct ServerApproveApplicationResult: Decodable, Hashable {
    let applicationId: Int64
    let result: String
    let waitlistPosition: Int?

    var isWaitlisted: Bool { result == "WAITLISTED" }
}

/// `DELETE /chat-rooms/{id}/members/me` — 호스트가 나가면 모임이 취소된다.
struct ServerLeaveChatRoomResult: Decodable, Hashable {
    let roomId: Int64
    let result: String
    let promotedUserId: Int64?

    /// `HOST_LEFT_AND_ROOM_CANCELLED` — 호스트 퇴장으로 모임 전체가 취소됐다
    var cancelledRoom: Bool { result == "HOST_LEFT_AND_ROOM_CANCELLED" }
}

/// `GET /chat-rooms/{id}/companions` — **완료된 여행 전용**.
/// 아직 끝나지 않은 여행에 부르면 `409 40915` 가 온다(권한 오류가 아니다).
struct ServerTripCompanion: Decodable, Identifiable, Hashable {
    // 2026-08-26 BE 변경: companionRecordId 가 응답에서 제거됐다(평가 경로 변수도 companionUserId 로 바뀜).
    // 식별자는 userId 하나다 — 필수로 디코딩하면 동행자 목록 파싱이 실패한다.
    let userId: Int64
    let nickname: String
    let profileImageUrl: String?
    /// 남들이 남긴 평균 매너 점수. 평가가 없으면 null — 표기를 숨긴다.
    let mannerRating: Double?
    /// 내가 이 동행자에게 남긴 점수. 미평가면 null.
    let mannerScore: Int?
    let oneLineReview: String?
    let reviewed: Bool

    var id: Int64 { userId }

    var profileImageURL: URL? {
        MoyeoImageURL.resolve(profileImageUrl)
    }
}

/// 완료 여행 전용 API 의 결과. `notCompleted` 는 오류가 아니라 "아직 여행 전"이다.
enum ServerCompanionsResult: Hashable {
    case companions([ServerTripCompanion])
    /// `409 40915` — 기획에 문구가 없으므로 화면은 해당 섹션을 숨긴다
    case notCompleted
    /// 그 밖의 실패(네트워크·403·500). 화면은 기존 표기를 유지한다
    case unavailable

    /// 실패 응답을 분기한다. `40915` 만 "아직 여행 전"이고 나머지는 표기를 그대로 두는 실패다.
    nonisolated static func failure(from error: Error) -> ServerCompanionsResult {
        guard let apiError = error as? MoyeoAPIError else { return .unavailable }
        return apiError.serverCode == MoyeoServerErrorCode.tripNotCompleted ? .notCompleted : .unavailable
    }
}

// MARK: - 클라이언트

final class ChatRoomWriteAPIClient: @unchecked Sendable {
    static let shared = ChatRoomWriteAPIClient()

    private let api: MoyeoAPIClient

    init(api: MoyeoAPIClient = .shared) {
        self.api = api
    }

    // MARK: 20 텍스트 메시지 전송

    /// 화면기획 20 입력창 전송. 201 을 준다.
    func sendMessage(
        roomID: Int64,
        content: String,
        replyToMessageID: Int64? = nil,
        mentionedUserIDs: [Int64] = []
    ) async throws -> ServerChatMessage {
        try await api.send(
            "/api/v1/chat-rooms/\(roomID)/messages",
            method: "POST",
            body: ServerSendChatMessageRequest(
                content: content,
                replyToMessageId: replyToMessageID,
                mentionedUserIds: mentionedUserIDs
            )
        )
    }

    // MARK: 20-2 첨부 5종

    /// 사진 공유 — `image` 파일 파트 + 선택 `caption` 텍스트 파트. 201 을 준다.
    func shareImage(
        roomID: Int64,
        imageData: Data,
        fileName: String = "photo.jpg",
        mimeType: String = "image/jpeg",
        caption: String? = nil
    ) async throws -> ServerChatMessage {
        var textParts: [String: String] = [:]
        if let caption, !caption.isEmpty {
            textParts["caption"] = caption
        }
        return try await api.sendMultipart(
            "/api/v1/chat-rooms/\(roomID)/messages/images",
            method: "POST",
            file: MoyeoMultipartFile(
                partName: "image",
                fileName: fileName,
                mimeType: mimeType,
                data: imageData
            ),
            textParts: textParts
        )
    }

    /// 관광 장소 카드 공유 (20-2 "장소").
    func shareTourismContent(roomID: Int64, contentID: Int64) async throws -> ServerChatMessage {
        try await api.send(
            "/api/v1/chat-rooms/\(roomID)/messages/tourism-contents",
            method: "POST",
            body: ServerShareTourismContentRequest(contentId: contentID)
        )
    }

    /// 만날 위치 공유 (20-2 "지도"). **본문이 없다** — 서버가 호스트가 등록한 집합 좌표를 그대로 카드로 만든다.
    /// 집합 좌표가 없으면 400 이라 화면은 실패를 조용히 무시하고 아무것도 바꾸지 않는다.
    func shareMeetingLocation(roomID: Int64) async throws -> ServerChatMessage {
        try await api.send("/api/v1/chat-rooms/\(roomID)/messages/locations", method: "POST")
    }

    /// 투표 개최 (20-2 "투표"). 선택지 2~5개, 중복 선택지는 400 이다.
    func createPoll(
        roomID: Int64,
        question: String,
        options: [String],
        anonymous: Bool = true
    ) async throws -> ServerChatMessage {
        try await api.send(
            "/api/v1/chat-rooms/\(roomID)/messages/polls",
            method: "POST",
            body: ServerCreatePollRequest(question: question, options: options, anonymous: anonymous)
        )
    }

    /// 정산 메모 공유 (20-2 "정산"). 송금 기능이 아니다.
    func shareSettlementMemo(roomID: Int64, memo: String) async throws -> ServerChatMessage {
        try await api.send(
            "/api/v1/chat-rooms/\(roomID)/messages/settlement-memos",
            method: "POST",
            body: ServerSettlementMemoRequest(memo: memo)
        )
    }

    // MARK: 20 투표 참여·취소

    func vote(roomID: Int64, messageID: Int64, optionID: Int64) async throws -> ServerChatMessage {
        try await api.send(
            "/api/v1/chat-rooms/\(roomID)/messages/\(messageID)/poll-options/\(optionID)/vote",
            method: "PUT"
        )
    }

    func cancelVote(roomID: Int64, messageID: Int64) async throws -> ServerChatMessage {
        try await api.send(
            "/api/v1/chat-rooms/\(roomID)/messages/\(messageID)/vote",
            method: "DELETE"
        )
    }

    // MARK: 20-3 공지

    func createNotice(roomID: Int64, notice: String, pinned: Bool) async throws -> ServerChatRoomNotice {
        try await api.send(
            "/api/v1/chat-rooms/\(roomID)/notices",
            method: "POST",
            body: ServerCreateNoticeRequest(notice: notice, pinned: pinned)
        )
    }

    /// 고정 토글 — 204 를 주고 본문이 없다. `notice` 는 건드리지 않도록 null 로 보낸다.
    func setNoticePinned(roomID: Int64, noticeID: Int64, pinned: Bool) async throws {
        try await api.sendVoid(
            "/api/v1/chat-rooms/\(roomID)/notices/\(noticeID)",
            method: "PUT",
            body: ServerUpdateNoticeRequest(notice: nil, pinned: pinned)
        )
    }

    /// 20-3a 공지 수정 — 내용과 고정을 함께 보낸다. 204 를 준다.
    /// **둘 다 null 이면 서버가 공지를 지운다** — 그래서 내용은 항상 채워서 보낸다.
    func updateNotice(roomID: Int64, noticeID: Int64, notice: String, pinned: Bool) async throws {
        try await api.sendVoid(
            "/api/v1/chat-rooms/\(roomID)/notices/\(noticeID)",
            method: "PUT",
            body: ServerUpdateNoticeRequest(notice: notice, pinned: pinned)
        )
    }

    /// 20-3a 공지 삭제 — **되돌릴 수 없다.** 호출부는 확인 단계를 거친 뒤에만 부른다. 204 를 준다.
    func deleteNotice(roomID: Int64, noticeID: Int64) async throws {
        try await api.sendVoid(
            "/api/v1/chat-rooms/\(roomID)/notices/\(noticeID)",
            method: "DELETE"
        )
    }

    // MARK: 17-3 집합 정보 수정 (호스트)

    /// 204 를 준다. `meetingDateTime` 은 `yyyy-MM-dd'T'HH:mm:ss` 로 보낸다.
    func updateMeetingInfo(roomID: Int64, request: ServerUpdateMeetingInfoRequest) async throws {
        try await api.sendVoid(
            "/api/v1/chat-rooms/\(roomID)/meeting-info",
            method: "PUT",
            body: request
        )
    }

    // MARK: 18 모집 상태 · 승인 · 거절

    /// 204 를 준다. `RECRUITING` 방만 `CONFIRMED` · `CANCELLED` 로 갈 수 있고 `COMPLETED` 는 400(40000) 이다.
    func changeStatus(roomID: Int64, status: ServerChatRoomTargetStatus) async throws {
        try await api.sendVoid(
            "/api/v1/chat-rooms/\(roomID)/status",
            method: "POST",
            body: ServerChatRoomStatusRequest(status: status.rawValue)
        )
    }

    func applications(roomID: Int64) async throws -> [ServerJoinApplication] {
        try await api.get("/api/v1/chat-rooms/\(roomID)/applications")
    }

    func approveApplication(
        roomID: Int64,
        applicationID: Int64
    ) async throws -> ServerApproveApplicationResult {
        try await api.send(
            "/api/v1/chat-rooms/\(roomID)/applications/\(applicationID)/approve",
            method: "POST"
        )
    }

    /// 거절은 신청 레코드 삭제다. 204 를 준다.
    func rejectApplication(roomID: Int64, applicationID: Int64) async throws {
        try await api.sendVoid(
            "/api/v1/chat-rooms/\(roomID)/applications/\(applicationID)",
            method: "DELETE"
        )
    }

    // MARK: 20-1 나가기 · 20-1b 내보내기

    func leaveRoom(roomID: Int64) async throws -> ServerLeaveChatRoomResult {
        try await api.send("/api/v1/chat-rooms/\(roomID)/members/me", method: "DELETE")
    }

    /// 204 를 주고 대상에게 `CHAT_ROOM_KICKED` 알림이 간다. 사유는 상대의 13-1 안내에 그대로 보인다.
    func kickMember(roomID: Int64, memberID: Int64, reason: String) async throws {
        try await api.sendVoid(
            "/api/v1/chat-rooms/\(roomID)/members/\(memberID)",
            method: "DELETE",
            body: ServerKickMemberRequest(reason: reason)
        )
    }

    // MARK: 20-1 동행자 · 27-1 평가

    /// 완료 여행에서만 200 이다. `409 40915` 는 "아직 여행 전"이라 오류로 그리지 않는다.
    func companions(roomID: Int64) async -> ServerCompanionsResult {
        do {
            let companions: [ServerTripCompanion] =
                try await api.get("/api/v1/chat-rooms/\(roomID)/companions")
            return .companions(companions)
        } catch {
            return ServerCompanionsResult.failure(from: error)
        }
    }

    /// 동행자 평가 — **되돌릴 수 없다.** 호출부는 사용자 확인 뒤에만 부른다.
    ///
    /// 경로의 `companionId` 는 **상대 사용자 ID** 다. 동행자 목록 응답이 함께 주는
    /// `companionRecordId` 를 넣으면 실패한다 — 실서버에서 확인했다.
    ///   `/companions/2/review`  (companionRecordId) → 400 `40028`
    ///   `/companions/62/review` (userId)            → 200
    func reviewCompanion(
        roomID: Int64,
        companionUserID: Int64,
        mannerScore: Int,
        oneLineReview: String?
    ) async throws -> ServerTripCompanion {
        try await api.send(
            "/api/v1/chat-rooms/\(roomID)/companions/\(companionUserID)/review",
            method: "PUT",
            body: ServerCompanionReviewRequest(mannerScore: mannerScore, oneLineReview: oneLineReview)
        )
    }

    // MARK: 20-1 방별 알림 설정

    func notificationSetting(roomID: Int64) async throws -> ServerChatRoomNotificationSetting {
        try await api.get("/api/v1/notifications/settings/chat-rooms/\(roomID)")
    }

    func updateNotificationSetting(
        roomID: Int64,
        enabled: Bool
    ) async throws -> ServerChatRoomNotificationSetting {
        try await api.send(
            "/api/v1/notifications/settings/chat-rooms/\(roomID)",
            method: "PUT",
            body: ServerChatRoomNotificationUpdate(enabled: enabled)
        )
    }
}

/// 20-2 첨부의 클라이언트 측 한도. 화면기획 문구("최대 20MB · 1장씩 전송")를 그대로 코드로 옮긴 값이다.
enum ServerChatShareLimits {
    nonisolated static let maximumPhotoBytes = 20 * 1024 * 1024
    /// 서버 검증과 같은 값 — 선택지 2~5개
    nonisolated static let pollOptionRange = 2...5
}

/// 호스트가 보낼 수 있는 방 상태. 서버 enum 에는 `COMPLETED` 도 있지만 클라가 보낼 수 있는 값은 둘이다.
enum ServerChatRoomTargetStatus: String {
    case confirmed = "CONFIRMED"
    case cancelled = "CANCELLED"
}
