//
//  ServerChatRoomWriteContractTests.swift
//  MoyeoTripTests
//
//  방 내부 쓰기 연동(20-2 첨부 · 투표 · 공지 고정 · 방별 알림 · 집합 정보 · 승인/거절 ·
//  나가기/강퇴 · 동행자) 계약 테스트.
//
//  **페이로드 출처**: `docs/api/evidence/openapi-2026-08-23.json` 의 응답 스키마(required·nullable)와
//  백엔드 DTO(`ChatResponses.kt` · `TravelCompanionResponses.kt` · `NotificationResponses.kt`),
//  그리고 `docs/api/API-연동-리포트.md` 의 08-24/08-25 실측 사실(예: `applications` 의 `mannerRating`
//  은 항상 null, `companions` 의 매너 두 필드가 모두 null)을 고정한 것이다.
//  이 세션에서는 QA 계정 자격정보가 없어 새로 실호출해 응답을 뜨지 못했다 — 그 점은 리포트에 적어 둔다.
//
//  응답을 요약하면 계약이 흐려지므로 파일 길이 제한을 끈다.
//

import Foundation
@testable import MoyeoTrip
import Testing

// swiftlint:disable file_length

// MARK: - 테스트 대역

/// 저장된 세션이 있는 상태를 만든다 — `MoyeoAPIClient` 는 세션이 없으면 요청 자체를 하지 않는다.
private struct StubAuthSessionStore: AuthSessionStoring {
    func load() throws -> AuthTokens? {
        AuthTokens(accessToken: "test-access", refreshToken: "test-refresh")
    }

    func save(_ tokens: AuthTokens) throws {}
    func clear() throws {}
}

/// 보낸 요청 본문을 그대로 붙잡아 두는 URLProtocol.
private final class WriteRequestCapturingProtocol: URLProtocol {
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var lastBody: Data?
    nonisolated(unsafe) static var statusCode = 201
    nonisolated(unsafe) static var responseBody = Data("{}".utf8)

    override static func canInit(with request: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        Self.lastBody = request.capturedBodyData
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.invalid")!,
            statusCode: Self.statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension URLRequest {
    /// `URLSession` 은 큰 본문을 스트림으로 바꿔 넘긴다 — 두 경로 모두에서 본문을 읽는다.
    var capturedBodyData: Data? {
        if let httpBody { return httpBody }
        guard let httpBodyStream else { return nil }
        httpBodyStream.open()
        defer { httpBodyStream.close() }
        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4_096)
        defer { buffer.deallocate() }
        while httpBodyStream.hasBytesAvailable {
            let count = httpBodyStream.read(buffer, maxLength: 4_096)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

/// multipart 본문 검사용 세션.
private struct MultipartCapturingSession {
    let urlSession: URLSession

    init() {
        WriteRequestCapturingProtocol.lastRequest = nil
        WriteRequestCapturingProtocol.lastBody = nil
        WriteRequestCapturingProtocol.statusCode = 201
        WriteRequestCapturingProtocol.responseBody = Data(#"""
        {"messageId":1026,"type":"IMAGE","senderId":61,"senderNickname":"따스한 사슴 3492",
         "content":"","createdAt":"2026-09-12T13:40:00",
         "imageUrl":"https://cdn.moyeotrip.example/chat/1026.jpg",
         "tourismContent":null,"location":null,"poll":null,"replyTo":null,"mentions":[]}
        """#.utf8)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [WriteRequestCapturingProtocol.self]
        urlSession = URLSession(configuration: configuration)
    }

    static var lastRequest: URLRequest? { WriteRequestCapturingProtocol.lastRequest }
    static var lastBody: Data? { WriteRequestCapturingProtocol.lastBody }
}

// MARK: - 18 모집 관리 (승인 대기 · 승인 결과)

@Suite
@MainActor
struct ServerJoinApplicationContractTests {
    /// `GET /api/v1/chat-rooms/21/applications`
    /// `applicationMessage` 는 required 인데 타입이 nullable 이다 — 두 경우를 모두 담았다.
    /// `mannerRating` 은 실서버에서 항상 null 이다(§5-25).
    private static let applicationsJSON = #"""
    [
      {"applicationId":30,"applicationMessage":"단풍 보러 가요. 사진 좋아해서 풍경 잘 담아드릴 수 있어요!",
       "applicant":{"userId":61,"nickname":"따스한 사슴 3492",
         "profileImageUrl":"https://cdn.moyeotrip.example/profile/61.png",
         "gender":"F","age":28,"mannerRating":null,"completedTripCount":3},
       "appliedAt":"2026-09-01T12:30:00"},
      {"applicationId":31,"applicationMessage":null,
       "applicant":{"userId":63,"nickname":"호기심 많은 너구리 9027",
         "profileImageUrl":null,"gender":null,"age":null,
         "mannerRating":null,"completedTripCount":0},
       "appliedAt":"2026-09-01T13:05:12.481902"}
    ]
    """#

    @Test func applicationsDecodeIntoHostApplicantCards() throws {
        let applications = try JSONDecoder()
            .decode([ServerJoinApplication].self, from: Data(Self.applicationsJSON.utf8))
        #expect(applications.count == 2)

        let first = try #require(applications.first { $0.applicationId == 30 })
        let card = ServerTripMapper.hostApplicant(from: first)
        #expect(card.id == "server-application-30")
        #expect(card.serverApplicationID == 30)
        #expect(card.serverUserID == 61)
        #expect(card.name == "따스한 사슴 3492")
        #expect(card.profileImageURL?.absoluteString == "https://cdn.moyeotrip.example/profile/61.png")
        // 매너 점수는 서버가 null 이라 표기하지 않는다 — "매너 4.9" 를 지어내지 않는다
        #expect(card.meta == "28세 · 여성 · 여행 3회")
        #expect(!card.meta.contains("매너"))
        #expect(card.note.contains("단풍"))
        // 서버 신청자는 마스코트가 없다
        #expect(card.avatar.isEmpty)
    }

    @Test func missingProfileFieldsAreOmittedNotInvented() throws {
        let applications = try JSONDecoder()
            .decode([ServerJoinApplication].self, from: Data(Self.applicationsJSON.utf8))
        let second = try #require(applications.first { $0.applicationId == 31 })
        let card = ServerTripMapper.hostApplicant(from: second)
        // 나이·성별·매너가 전부 null 이면 여행 횟수만 남는다
        #expect(card.meta == "여행 0회")
        #expect(card.profileImageURL == nil)
        // 한마디를 안 남긴 신청은 빈 인용을 그리지 않도록 빈 문자열이 된다
        #expect(card.note.isEmpty)
    }

    @Test func genderCodesMapOnlyForKnownValues() {
        #expect(ServerTripMapper.applicantGenderText("M") == "남성")
        #expect(ServerTripMapper.applicantGenderText("F") == "여성")
        // 스펙 enum 에는 N 도 있다 — 알 수 없는 값은 표기를 숨긴다
        #expect(ServerTripMapper.applicantGenderText("N") == nil)
        #expect(ServerTripMapper.applicantGenderText(nil) == nil)
    }

    @Test func approveResultDistinguishesWaitlist() throws {
        let joined = try JSONDecoder().decode(
            ServerApproveApplicationResult.self,
            from: Data(#"{"applicationId":30,"result":"JOINED","waitlistPosition":null}"#.utf8)
        )
        #expect(!joined.isWaitlisted)
        #expect(joined.waitlistPosition == nil)

        let waitlisted = try JSONDecoder().decode(
            ServerApproveApplicationResult.self,
            from: Data(#"{"applicationId":31,"result":"WAITLISTED","waitlistPosition":2}"#.utf8)
        )
        #expect(waitlisted.isWaitlisted)
        #expect(waitlisted.waitlistPosition == 2)
    }

    @Test func applicantMannerRatingIsShownWhenServerEventuallyProvidesIt() throws {
        // BE 가 §6-1 로 매너 점수를 채우면 표기가 살아나야 한다 — 그 계약을 미리 고정한다
        let json = #"""
        {"applicationId":32,"applicationMessage":"잘 부탁드려요",
         "applicant":{"userId":64,"nickname":"우직한 곰 7821","profileImageUrl":null,
           "gender":"M","age":31,"mannerRating":4.9,"completedTripCount":8},
         "appliedAt":"2026-09-02T09:00:00"}
        """#
        let application = try JSONDecoder().decode(ServerJoinApplication.self, from: Data(json.utf8))
        #expect(ServerTripMapper.hostApplicant(from: application).meta == "31세 · 남성 · 매너 4.9 · 여행 8회")
    }
}

// MARK: - 20-1 나가기 · 방별 알림 설정

@Suite
@MainActor
struct ServerChatRoomMembershipContractTests {
    @Test func leaveResultTellsHostCancellationApart() throws {
        let left = try JSONDecoder().decode(
            ServerLeaveChatRoomResult.self,
            from: Data(#"{"roomId":21,"result":"LEFT","promotedUserId":33}"#.utf8)
        )
        #expect(!left.cancelledRoom)
        #expect(left.promotedUserId == 33)

        let hostLeft = try JSONDecoder().decode(
            ServerLeaveChatRoomResult.self,
            from: Data(#"{"roomId":21,"result":"HOST_LEFT_AND_ROOM_CANCELLED","promotedUserId":null}"#.utf8)
        )
        #expect(hostLeft.cancelledRoom)
        #expect(hostLeft.promotedUserId == nil)
    }

    /// `GET·PUT /api/v1/notifications/settings/chat-rooms/21`
    @Test func chatRoomNotificationSettingDecodes() throws {
        let setting = try JSONDecoder().decode(
            ServerChatRoomNotificationSetting.self,
            from: Data(#"{"roomId":21,"enabled":false}"#.utf8)
        )
        #expect(setting.roomId == 21)
        #expect(!setting.enabled)
    }

    @Test func notificationUpdateBodyUsesEnabledFlag() throws {
        let body = try JSONEncoder().encode(ServerChatRoomNotificationUpdate(enabled: false))
        let decoded = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(decoded?["enabled"] as? Bool == false)
        #expect(decoded?.count == 1)
    }

    @Test func kickRequestSendsOnlyReason() throws {
        let body = try JSONEncoder().encode(ServerKickMemberRequest(reason: "반복적인 약속 불이행"))
        let decoded = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(decoded?["reason"] as? String == "반복적인 약속 불이행")
        #expect(decoded?.count == 1)
    }
}

// MARK: - 20-1 · 27-1 동행자 (완료 여행 전용)

@Suite
@MainActor
struct ServerTripCompanionContractTests {
    /// `GET /api/v1/chat-rooms/21/companions` — 08-25 에 403 이 풀려 200 이 됐다.
    /// 매너 두 필드(`mannerRating` · `mannerScore`)는 아직 둘 다 null 이다.
    private static let companionsJSON = #"""
    [
      {"companionRecordId":44,"userId":61,"nickname":"따스한 사슴 3492",
       "profileImageUrl":null,"mannerRating":null,"mannerScore":null,
       "oneLineReview":null,"reviewed":false},
      {"companionRecordId":45,"userId":63,"nickname":"우직한 곰 7821",
       "profileImageUrl":"https://cdn.moyeotrip.example/profile/63.png",
       "mannerRating":4.8,"mannerScore":5,
       "oneLineReview":"핑크뮬리 사진 잘 찍어주셔서 고마워요!","reviewed":true}
    ]
    """#

    @Test func companionsDecodeWithBothMannerFields() throws {
        let companions = try JSONDecoder()
            .decode([ServerTripCompanion].self, from: Data(Self.companionsJSON.utf8))
        #expect(companions.count == 2)

        let unreviewed = try #require(companions.first { $0.companionRecordId == 44 })
        #expect(!unreviewed.reviewed)
        #expect(unreviewed.mannerRating == nil)
        #expect(unreviewed.mannerScore == nil)
        #expect(unreviewed.oneLineReview == nil)

        let reviewed = try #require(companions.first { $0.companionRecordId == 45 })
        #expect(reviewed.reviewed)
        #expect(reviewed.mannerScore == 5)
        #expect(reviewed.profileImageURL != nil)
    }

    /// 20-1 동행자 줄 — 매너 점수는 완료 여행에서만 온다. null 이면 그 표기를 뺀다.
    @Test func memberDetailHidesMannerWhenServerHasNone() {
        #expect(
            ServerTripMapper.memberDetailText(completedTripCount: 3, mannerRating: nil)
                == "여행 3회"
        )
        #expect(
            ServerTripMapper.memberDetailText(completedTripCount: 8, mannerRating: 4.8)
                == "매너 4.8 · 여행 8회"
        )
    }

    @Test func reviewRequestKeepsOptionalOneLineReview() throws {
        let withReview = try JSONEncoder().encode(
            ServerCompanionReviewRequest(mannerScore: 5, oneLineReview: "덕분에 즐거웠어요")
        )
        let decoded = try JSONSerialization.jsonObject(with: withReview) as? [String: Any]
        #expect(decoded?["mannerScore"] as? Int == 5)
        #expect(decoded?["oneLineReview"] as? String == "덕분에 즐거웠어요")
    }
}

// MARK: - 20-2 첨부 5종 요청 본문

@Suite
@MainActor
struct ServerChatShareRequestContractTests {
    /// 서버 필드명은 `question` 이다 — `title` 로 보내면 400 이다.
    @Test func pollRequestUsesQuestionFieldAndDefaultsToAnonymous() throws {
        let body = try JSONEncoder().encode(
            ServerCreatePollRequest(question: "점심 메뉴는 무엇으로 할까요?", options: ["한식", "카페", "분식"], anonymous: true)
        )
        let decoded = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(decoded?["question"] as? String == "점심 메뉴는 무엇으로 할까요?")
        #expect((decoded?["options"] as? [String])?.count == 3)
        #expect(decoded?["anonymous"] as? Bool == true)
        #expect(decoded?["title"] == nil)
    }

    @Test func settlementMemoRequestSendsMemoOnly() throws {
        let body = try JSONEncoder().encode(
            ServerSettlementMemoRequest(memo: "점심 45,000원 / 5명 = 1인 9,000원")
        )
        let decoded = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(decoded?["memo"] as? String == "점심 45,000원 / 5명 = 1인 9,000원")
        #expect(decoded?.count == 1)
    }

    @Test func tourismContentShareSendsContentID() throws {
        let body = try JSONEncoder().encode(ServerShareTourismContentRequest(contentId: 126_508))
        let decoded = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(decoded?["contentId"] as? Int == 126_508)
    }

    @Test func textMessageRequestKeepsReplyAndMentionFields() throws {
        let body = try JSONEncoder().encode(
            ServerSendChatMessageRequest(content: "안녕하세요!", replyToMessageId: nil, mentionedUserIds: [])
        )
        let decoded = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(decoded?["content"] as? String == "안녕하세요!")
        #expect((decoded?["mentionedUserIds"] as? [Int])?.isEmpty == true)
    }

    /// 기획 20-2 "최대 20MB · 1장씩 전송" · "2~5개 · 익명 기본"
    @Test func shareLimitsMatchPlanAndServerValidation() {
        #expect(ServerChatShareLimits.maximumPhotoBytes == 20 * 1024 * 1024)
        #expect(ServerChatShareLimits.pollOptionRange == 2...5)
    }
}

// MARK: - 20-2 사진 multipart 본문

@Suite(.serialized)
@MainActor
struct MoyeoMultipartBodyTests {
    /// `POST /chat-rooms/{id}/messages/images` 는 `image` 파일 파트 + 선택 `caption` 텍스트 파트다.
    /// 실제 요청 본문을 만들어 파트 경계와 헤더가 스펙대로인지 고정한다.
    @Test func imagePartCarriesFilenameAndContentType() async throws {
        let session = MultipartCapturingSession()
        let client = MoyeoAPIClient(
            configuration: .current,
            session: session.urlSession,
            sessionStore: StubAuthSessionStore()
        )
        let write = ChatRoomWriteAPIClient(api: client)

        _ = try? await write.shareImage(
            roomID: 21,
            // 본문을 문자열로 검사하려면 UTF-8 로 읽히는 바이트여야 한다(실제 JPEG 바이트는 UTF-8 이 아니다)
            imageData: Data("jpeg-bytes".utf8),
            fileName: "juwangsan.jpg",
            caption: "주왕산 3폭포"
        )

        let request = try #require(MultipartCapturingSession.lastRequest)
        let contentType = try #require(request.value(forHTTPHeaderField: "Content-Type"))
        #expect(contentType.hasPrefix("multipart/form-data; boundary=moyeo."))
        #expect(request.url?.path == "/api/v1/chat-rooms/21/messages/images")
        #expect(request.httpMethod == "POST")

        let body = try #require(MultipartCapturingSession.lastBody)
        let text = try #require(String(data: body, encoding: .utf8))
        #expect(text.contains("Content-Disposition: form-data; name=\"image\"; filename=\"juwangsan.jpg\""))
        #expect(text.contains("Content-Type: image/jpeg"))
        #expect(text.contains("Content-Disposition: form-data; name=\"caption\""))
        #expect(text.contains("주왕산 3폭포"))
        // 마지막 경계는 닫혀 있어야 한다
        let boundary = contentType.replacingOccurrences(of: "multipart/form-data; boundary=", with: "")
        #expect(text.hasSuffix("--\(boundary)--\r\n"))
    }

    @Test func captionPartIsOmittedWhenEmpty() async throws {
        let session = MultipartCapturingSession()
        let client = MoyeoAPIClient(
            configuration: .current,
            session: session.urlSession,
            sessionStore: StubAuthSessionStore()
        )
        _ = try? await ChatRoomWriteAPIClient(api: client)
            .shareImage(roomID: 21, imageData: Data([0x00]), caption: nil)

        let body = try #require(MultipartCapturingSession.lastBody)
        let text = try #require(String(data: body, encoding: .utf8))
        #expect(!text.contains("name=\"caption\""))
    }
}

// MARK: - 17-3 집합 정보 · 18 상태 전이 요청 본문

@Suite
@MainActor
struct ServerChatRoomHostRequestContractTests {
    @Test func meetingInfoRequestKeepsNullableCoordinates() throws {
        let body = try JSONEncoder().encode(
            ServerUpdateMeetingInfoRequest(
                meetingLatitude: 36.5760,
                meetingLongitude: 128.9700,
                meetingDetails: "안동역 1번 출구 앞",
                meetingDateTime: "2026-09-12T08:30:00"
            )
        )
        let decoded = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(decoded?["meetingDateTime"] as? String == "2026-09-12T08:30:00")
        #expect(decoded?["meetingDetails"] as? String == "안동역 1번 출구 앞")
        #expect((decoded?["meetingLatitude"] as? Double) == 36.5760)
    }

    @Test func meetingDateTimeTextNormalizesShortTime() {
        #expect(
            ServerTripMapper.meetingDateTimeText(date: "2026-09-12", time: "08:30")
                == "2026-09-12T08:30:00"
        )
        // 서버가 HH:mm:ss 로 주는 값도 그대로 통과시킨다
        #expect(
            ServerTripMapper.meetingDateTimeText(date: "2026-09-12", time: "08:30:00")
                == "2026-09-12T08:30:00"
        )
    }

    /// 호스트가 보낼 수 있는 값은 둘이다. `COMPLETED` 는 서버가 400(40000)으로 거절한다(§4-3).
    @Test func statusRequestOnlyCarriesConfirmedOrCancelled() throws {
        for status in [ServerChatRoomTargetStatus.confirmed, .cancelled] {
            let body = try JSONEncoder().encode(ServerChatRoomStatusRequest(status: status.rawValue))
            let decoded = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            #expect(decoded?["status"] as? String == status.rawValue)
        }
        #expect(ServerChatRoomTargetStatus.confirmed.rawValue == "CONFIRMED")
        #expect(ServerChatRoomTargetStatus.cancelled.rawValue == "CANCELLED")
    }

    /// 고정 토글은 `notice` 를 null 로 보내 내용을 건드리지 않는다.
    /// **둘 다 null 이면 서버가 공지를 삭제**하므로 `pinned` 는 반드시 값이 있어야 한다.
    @Test func noticePinToggleSendsNullContentAndNonNullPinned() throws {
        let encoder = JSONEncoder()
        let body = try encoder.encode(ServerUpdateNoticeRequest(notice: nil, pinned: true))
        let text = try #require(String(data: body, encoding: .utf8))
        #expect(text.contains("\"pinned\":true"))
        // notice 키는 nil 이라 인코딩에서 빠진다 — 서버는 미전달을 null 로 읽는다
        #expect(!text.contains("\"notice\""))
    }

    @Test func noticeIDRoundTripsThroughScreenIdentifier() throws {
        let json = #"""
        {"pinnedNotices":[{"noticeId":12,"content":"집합 장소 · 시간\n07:50 청송 시외버스터미널",
          "pinned":true,"authorNickname":"숲속여행자","createdAt":"2026-09-01T12:00:00"}],
         "unpinnedNotices":[{"noticeId":9,"content":"주차 안내","pinned":false,
          "authorNickname":"숲속여행자","createdAt":"2026-08-30T19:30:00"}]}
        """#
        let history = try JSONDecoder()
            .decode(ServerChatRoomNoticeHistory.self, from: Data(json.utf8))
        let unpinned = try #require(history.unpinnedNotices.first)
        let card = ServerTripMapper.notice(from: unpinned)
        #expect(card.id == "server-notice-9")
        #expect(ServerTripMapper.noticeID(fromNoticeID: card.id) == 9)
        // 목데이터 공지에는 서버 id 가 없어 고정 토글을 보내지 않는다
        #expect(ServerTripMapper.noticeID(fromNoticeID: "notice-parking") == nil)
    }
}

// MARK: - 20 투표 응답 (참여·취소)

@Suite
@MainActor
struct ServerChatPollContractTests {
    /// `PUT .../poll-options/{optionId}/vote` 와 `DELETE .../vote` 는 갱신된 메시지를 그대로 돌려준다.
    private static let pollMessageJSON = #"""
    {"messageId":1024,"type":"POLL","senderId":62,"senderNickname":"숲속여행자",
     "content":"점심 메뉴는 무엇으로 할까요?","createdAt":"2026-09-12T13:30:00",
     "imageUrl":null,"tourismContent":null,"location":null,
     "poll":{"question":"점심 메뉴는 무엇으로 할까요?","anonymous":true,"totalVoteCount":3,
       "options":[
         {"optionId":23,"text":"한식","voteCount":2,"votedByMe":true,"voterNicknames":null},
         {"optionId":24,"text":"카페","voteCount":1,"votedByMe":false,"voterNicknames":null}]},
     "replyTo":null,"mentions":[]}
    """#

    @Test func voteResponseCarriesMyVoteBack() throws {
        let message = try JSONDecoder()
            .decode(ServerChatMessage.self, from: Data(Self.pollMessageJSON.utf8))
        let poll = try #require(message.poll)
        #expect(poll.question == "점심 메뉴는 무엇으로 할까요?")
        #expect(poll.totalVoteCount == 3)
        #expect(poll.options.first { $0.optionId == 23 }?.votedByMe == true)
        // 익명 투표는 투표자 닉네임을 주지 않는다 — 이름을 지어내지 않는다
        #expect(poll.options.allSatisfy { $0.voterNicknames == nil })
    }

    @Test func pollBubbleTextListsOptionsWithoutInventingValues() throws {
        let message = try JSONDecoder()
            .decode(ServerChatMessage.self, from: Data(Self.pollMessageJSON.utf8))
        let body = ServerTripMapper.messageBody(message)
        #expect(body.contains("점심 메뉴는 무엇으로 할까요?"))
        #expect(body.contains("한식 2"))
        #expect(body.contains("카페 1"))
    }

    /// 위치 공유 응답 — 서버가 호스트 등록 집합 좌표로 카드를 만든다.
    @Test func sharedLocationMessageKeepsServerCoordinates() throws {
        let json = #"""
        {"messageId":1025,"type":"LOCATION","senderId":61,"senderNickname":"따스한 사슴 3492",
         "content":"청송 시외버스터미널 정문 앞","createdAt":"2026-09-12T13:35:00",
         "imageUrl":null,"tourismContent":null,
         "location":{"latitude":36.435612,"longitude":129.057214,"name":"청송 시외버스터미널 정문 앞"},
         "poll":null,"replyTo":null,"mentions":[]}
        """#
        let message = try JSONDecoder().decode(ServerChatMessage.self, from: Data(json.utf8))
        #expect(message.location?.latitude == 36.435612)
        #expect(ServerTripMapper.messageBody(message).contains("청송 시외버스터미널 정문 앞"))
    }

    /// 사진 공유 응답 — `imageUrl` 이 채워지고 다른 카드 필드는 null 이다.
    @Test func sharedImageMessageExposesImageURL() throws {
        let json = #"""
        {"messageId":1026,"type":"IMAGE","senderId":61,"senderNickname":"따스한 사슴 3492",
         "content":"","createdAt":"2026-09-12T13:40:00",
         "imageUrl":"https://cdn.moyeotrip.example/chat/1026.jpg",
         "tourismContent":null,"location":null,"poll":null,"replyTo":null,"mentions":[]}
        """#
        let message = try JSONDecoder().decode(ServerChatMessage.self, from: Data(json.utf8))
        #expect(message.imageURL?.absoluteString == "https://cdn.moyeotrip.example/chat/1026.jpg")
        #expect(!message.isSystem)
    }
}

// MARK: - 409 40915 분기

@Suite
@MainActor
struct ServerCompanionsGateTests {
    /// 완료되지 않은 여행에 `companions` 를 부르면 `409 40915` 다.
    /// 권한 오류가 아니므로 화면은 오류를 띄우지 않고 섹션만 감춘다.
    @Test func tripNotCompletedIsNotAnError() {
        let error = MoyeoAPIError.server(
            statusCode: 409, code: 40915, message: "아직 완료되지 않은 여행입니다."
        )
        #expect(error.serverCode == MoyeoServerErrorCode.tripNotCompleted)
        #expect(ServerCompanionsResult.failure(from: error) == .notCompleted)
    }

    @Test func otherFailuresStayUnavailableSoScreenKeepsExistingValues() {
        // 403 미참가는 표기를 그대로 두는 실패다 — "아직 여행 전"과 구분한다
        let forbidden = MoyeoAPIError.server(
            statusCode: 403, code: 40301, message: "채팅방 참가자가 아닙니다."
        )
        #expect(ServerCompanionsResult.failure(from: forbidden) == .unavailable)
        #expect(ServerCompanionsResult.failure(from: MoyeoAPIError.missingSession) == .unavailable)
        #expect(ServerCompanionsResult.failure(from: MoyeoAPIError.transport("timeout")) == .unavailable)
        // 같은 409 라도 다른 업무 코드면 "아직 여행 전"이 아니다
        let otherConflict = MoyeoAPIError.server(statusCode: 409, code: 40901, message: "충돌")
        #expect(ServerCompanionsResult.failure(from: otherConflict) == .unavailable)
    }

    @Test func completedTripCompanionsAreCarriedThrough() throws {
        let companions = try JSONDecoder().decode(
            [ServerTripCompanion].self,
            from: Data(#"""
            [{"companionRecordId":44,"userId":61,"nickname":"따스한 사슴 3492","profileImageUrl":null,
              "mannerRating":null,"mannerScore":null,"oneLineReview":null,"reviewed":false}]
            """#.utf8)
        )
        #expect(ServerCompanionsResult.companions(companions) != .notCompleted)
        #expect(companions[0].companionRecordId == 44)
    }
}
