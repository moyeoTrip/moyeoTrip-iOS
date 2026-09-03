//
//  ServerChatRoomContractTests.swift
//  MoyeoTripTests
//
//  2차 연동(iOS) 계약 테스트 — 실서버 응답 원문으로 디코딩과 화면 매핑을 고정한다.
//  본문 JSON은 2026-08-24 실서버(QA 계정 host userId 62 / room 21·22) 응답을 그대로 붙였다.
//

import Foundation
@testable import MoyeoTrip
import Testing

// 실서버 응답 원문을 그대로 붙여 두는 파일이라 길이 제한을 끈다 — 페이로드를 요약하면 계약이 흐려진다.
// swiftlint:disable file_length

@Suite
struct ServerChatRoomContractTests {
    // MARK: - chat-rooms/my (19 모임 목록 · 26 내 여행)

    private static let myRoomsJSON = #"""
    [
      {"roomId":22,"courseId":22,"title":"QA 자동승인 모임","description":"연동 검증용 모임입니다.",
       "startDate":"2026-09-20","chatAvailable":true,"status":"RECRUITING","recruitmentDDay":25,
       "ended":false,"coursePublicationAvailable":false,"participantCount":2,"maxParticipants":4,
       "unreadMessageCount":4,
       "latestMessage":{"type":"SYSTEM","senderNickname":"시스템",
         "content":"즐거운 고양이 4760님이 모임에서 제외되었어요.","sentAt":"2026-08-24T08:06:50.072025"}},
      {"roomId":21,"courseId":21,"title":"QA 시나리오 검증 모임","description":"연동 검증용 모임입니다.",
       "startDate":"2026-09-20","chatAvailable":true,"status":"CONFIRMED","recruitmentDDay":25,
       "ended":false,"coursePublicationAvailable":false,"participantCount":2,"maxParticipants":4,
       "unreadMessageCount":0,
       "latestMessage":{"type":"SYSTEM","senderNickname":"시스템",
         "content":"여행이 확정되었어요.","sentAt":"2026-08-24T08:05:55.150093"}}
    ]
    """#

    @Test func myChatRoomsDecodeAndMapToMeetingRows() throws {
        let rooms = try JSONDecoder().decode([ServerMyChatRoom].self, from: Data(Self.myRoomsJSON.utf8))
        #expect(rooms.count == 2)

        let confirmed = try #require(rooms.first { $0.roomId == 21 })
        let thread = ServerTripMapper.chatThread(from: confirmed)
        #expect(thread.id == "server-chat-21")
        #expect(thread.serverRoomID == 21)
        #expect(thread.isServerBacked)
        #expect(thread.tripTitle == "QA 시나리오 검증 모임")
        #expect(thread.statusSummary == "2/4명 · 여행 확정")
        #expect(thread.recruitmentDeadline == "D-25")
        #expect(thread.lastMessage == "여행이 확정되었어요.")
        #expect(!thread.isReadOnly)
        // 서버가 주지 않는 값은 비워 둔다 — 목데이터 자리 채우기를 하지 않는다
        #expect(thread.region.isEmpty)
        #expect(thread.mascot.isEmpty)
        #expect(thread.members.isEmpty)
        #expect(thread.courseDisplayName.isEmpty)
        #expect(thread.priceDisplayText.isEmpty)
        #expect(thread.ageRangeDisplayText.isEmpty)
        #expect(thread.genderDisplayText.isEmpty)

        let recruiting = try #require(rooms.first { $0.roomId == 22 })
        #expect(ServerTripMapper.chatThread(from: recruiting).unreadCount == 4)
        #expect(ServerTripMapper.statusText(for: recruiting) == "모집중")
    }

    @Test func endedRoomBecomesReadOnlyWithoutDeadline() throws {
        let json = #"""
        [{"roomId":9,"courseId":9,"title":"지난 여행","startDate":"2026-05-25","endDate":"2026-05-26",
          "chatAvailable":false,"ended":true,"coursePublicationAvailable":true}]
        """#
        let rooms = try JSONDecoder().decode([ServerMyChatRoom].self, from: Data(json.utf8))
        let thread = ServerTripMapper.chatThread(from: rooms[0])
        #expect(thread.isReadOnly)
        #expect(thread.recruitmentDeadline.isEmpty)
        // 지난 여행 요약은 인원을 주지 않는다 — 상태만 남는다
        #expect(thread.statusSummary == "여행 종료")
        #expect(thread.unreadCount == 0)
        #expect(thread.scheduleSummary.contains("2026.05.25"))
        #expect(thread.scheduleSummary.contains("2026.05.26"))
    }

    // MARK: - 방 내부 읽기 (20 · 20-1 · 20-3)

    private static let membersJSON = #"""
    {"participantCount":2,"maxParticipants":4,"waitlistCount":0,"members":[
      {"userId":62,"nickname":"따스한 기린 2334","profileImageUrl":null,
       "completedTripCount":0,"host":true,"me":true},
      {"userId":61,"nickname":"즐거운 고양이 4760",
       "profileImageUrl":"https://moyeo-trip-cdn.jayden-bin.cc/user/profile/image/b57bb679.webp",
       "completedTripCount":3,"host":false,"me":false}]}
    """#

    private static let noticesJSON = #"""
    {"pinnedNotices":[
      {"noticeId":21,"content":"집합 시간 10분 전까지 안동역 1번 출구로 와주세요.","pinned":true,
       "authorNickname":"따스한 기린 2334","createdAt":"2026-08-24T01:12:20.560012"}],
     "unpinnedNotices":[
      {"noticeId":41,"content":"재검증 공지","pinned":false,
       "authorNickname":"따스한 기린 2334","createdAt":"2026-08-24T08:04:37.218795"}]}
    """#

    private static let messagesJSON = #"""
    {"messages":[
      {"messageId":21,"type":"SYSTEM","senderId":null,"senderNickname":"시스템",
       "content":"따스한 기린 2334님이 모임을 개설했어요.","createdAt":"2026-08-23T20:11:35.942505",
       "imageUrl":null,"tourismContent":null,"location":null,"poll":null,"replyTo":null,"mentions":[]},
      {"messageId":47,"type":"POLL","senderId":62,"senderNickname":"따스한 기린 2334",
       "content":"점심 메뉴는 무엇으로 할까요?","createdAt":"2026-08-24T01:13:25.556421",
       "imageUrl":null,"tourismContent":null,"location":null,
       "poll":{"question":"점심 메뉴는 무엇으로 할까요?","anonymous":true,"totalVoteCount":0,
         "options":[{"optionId":1,"text":"한식","voteCount":0,"votedByMe":false,"voterNicknames":null},
                    {"optionId":2,"text":"카페","voteCount":0,"votedByMe":false,"voterNicknames":null}]},
       "replyTo":null,"mentions":[]},
      {"messageId":72,"type":"USER","senderId":61,"senderNickname":"즐거운 고양이 4760",
       "content":"안동역에서 만나요","createdAt":"2026-08-24T08:20:14.160347078",
       "imageUrl":null,"tourismContent":null,"location":null,"poll":null,"replyTo":null,"mentions":[]}],
     "nextId":null,"hasNext":false}
    """#

    private static let roomDetailJSON = #"""
    {"roomId":21,"title":"QA 시나리오 검증 모임","description":"연동 검증용 모임입니다.","thumbnail":null,
     "tripType":"DAY_TRIP","startDate":"2026-09-20","endDate":null,
     "recruitmentDeadlineDate":"2026-09-18","tripNights":0,"tripDays":1,
     "dayTripStartTime":"09:00:00","dayTripEndTime":"18:00:00",
     "meetingLatitude":36.5761,"meetingLongitude":128.9701,
     "meetingDetails":"안동역 1번 출구 앞 광장","meetingDateTime":"2026-09-20T08:40:00",
     "participationFee":0,"genderRestriction":"NONE","minimumAge":null,"maximumAge":null,
     "joinApprovalMode":"MANUAL","recruitmentDDay":25,"hostId":62,"hostProfileImageUrl":null,
     "participantCount":2,"maxParticipants":4,"status":"CONFIRMED","favorite":false,
     "latestPinnedNotice":null,"participants":[]}
    """#

    private func loadedContent() throws -> ServerChatRoomContent {
        let decoder = JSONDecoder()
        var content = ServerChatRoomContent(
            roomID: 21,
            memberList: try decoder.decode(
                ServerChatRoomMemberList.self, from: Data(Self.membersJSON.utf8)
            )
        )
        content.detail = try decoder.decode(ServerChatRoomDetail.self, from: Data(Self.roomDetailJSON.utf8))
        content.noticeHistory = try decoder.decode(
            ServerChatRoomNoticeHistory.self, from: Data(Self.noticesJSON.utf8)
        )
        content.messages = try decoder
            .decode(ServerChatMessagePage.self, from: Data(Self.messagesJSON.utf8))
            .messages
        return content
    }

    @Test func memberListIdentifiesCurrentUserAndProfileImages() throws {
        let content = try loadedContent()
        #expect(content.memberList.currentUserID == 62)
        #expect(content.memberList.waitlistCount == 0)
        #expect(content.memberList.profileImageURLsByUserID[61] != nil)
        // 프로필 이미지가 없는 동행자는 지도에 없는 값을 만들지 않는다
        #expect(content.memberList.profileImageURLsByUserID[62] == nil)
    }

    @Test func roomContentFillsChatRoomWithoutInventingValues() throws {
        let rooms = try JSONDecoder().decode([ServerMyChatRoom].self, from: Data(Self.myRoomsJSON.utf8))
        let base = ServerTripMapper.chatThread(from: try #require(rooms.first { $0.roomId == 21 }))
        let thread = ServerTripMapper.chatThread(base, applying: try loadedContent())

        #expect(thread.members.count == 2)
        #expect(thread.isCurrentUserHost)
        #expect(thread.statusSummary == "2/4명 · 여행 확정")
        #expect(thread.messages.count == 3)
        #expect(thread.pinnedNotices.count == 2)
        #expect(thread.pinnedNotices.filter(\.isPinned).count == 1)
        #expect(thread.meetupSummary == "08:40 안동역 1번 출구 앞 광장")
        #expect(thread.scheduleSummary == "2026.09.20 (일) · 당일치기 · 09:00 – 18:00")
        #expect(thread.genderDisplayText == "성별 무관")
        #expect(thread.priceDisplayText == "1인 0원")
        // 서버가 나이 제한을 null로 주면 기본값을 지어내지 않는다
        #expect(thread.ageRangeDisplayText.isEmpty)
    }

    @Test func messagesMapOwnershipSystemNoticesAndPollBodies() throws {
        let content = try loadedContent()
        let mine = ServerTripMapper.chatMessage(from: content.messages[2], currentUserID: 61)
        #expect(mine.isMine)
        #expect(mine.kind == .text)
        #expect(!mine.time.isEmpty)

        let system = ServerTripMapper.chatMessage(from: content.messages[0], currentUserID: 61)
        #expect(!system.isMine)
        #expect(system.kind == .system)
        #expect(system.isSystemNotice)

        let poll = ServerTripMapper.chatMessage(from: content.messages[1], currentUserID: 61)
        #expect(!poll.isMine)
        #expect(poll.body.contains("점심 메뉴는 무엇으로 할까요?"))
        #expect(poll.body.contains("한식"))
        #expect(poll.body.contains("카페"))
    }

    /// 공지는 본문만 있다 — 첫 줄을 제목으로 떼지 않는다 (정본 ATTACH-COMPOSER-CANON.md §2).
    @Test func noticeMappingKeepsWholeContentAsBody() throws {
        let history = try JSONDecoder().decode(
            ServerChatRoomNoticeHistory.self, from: Data(Self.noticesJSON.utf8)
        )
        #expect(history.allNotices.count == 2)
        let notice = ServerTripMapper.notice(from: history.pinnedNotices[0])
        #expect(notice.id == "server-notice-21")
        #expect(notice.body == "집합 시간 10분 전까지 안동역 1번 출구로 와주세요.")
        #expect(notice.authorName == "따스한 기린 2334")
        #expect(notice.isPinned)

        let multiline = ServerChatRoomNotice(
            noticeId: 5, content: "집합 안내\n07:50 정문 앞", pinned: false,
            authorNickname: "호스트", createdAt: "2026-08-24T01:12:20.560012"
        )
        let mapped = ServerTripMapper.notice(from: multiline)
        #expect(mapped.body == "집합 안내\n07:50 정문 앞")
    }

    @Test func inactiveRoadmapDecodesWithoutPlaces() throws {
        let json = #"{"active":false,"dayNumber":null,"totalDays":1,"currentPlace":null,"nextPlace":null,"places":[]}"#
        let roadmap = try JSONDecoder().decode(ServerCurrentRoadmap.self, from: Data(json.utf8))
        #expect(!roadmap.active)
        #expect(roadmap.places.isEmpty)
        #expect(roadmap.dayNumber == nil)
    }

    @Test func activeRoadmapCountsProgress() throws {
        let json = #"""
        {"active":true,"dayNumber":1,"totalDays":2,
         "currentPlace":{"contentId":11,"sequence":2,"title":"주왕산","thumbnail":null,
           "latitude":36.39,"longitude":129.17,"scheduledAt":"2026-09-20T11:00:00","progress":"CURRENT"},
         "nextPlace":{"contentId":12,"sequence":3,"title":"주산지","thumbnail":null,
           "latitude":36.34,"longitude":129.14,"scheduledAt":"2026-09-20T14:00:00","progress":"UPCOMING"},
         "places":[
          {"contentId":10,"sequence":1,"title":"청송터미널","thumbnail":null,"latitude":null,
           "longitude":null,"scheduledAt":null,"progress":"COMPLETED"},
          {"contentId":11,"sequence":2,"title":"주왕산","thumbnail":null,"latitude":36.39,
           "longitude":129.17,"scheduledAt":"2026-09-20T11:00:00","progress":"CURRENT"}]}
        """#
        let roadmap = try JSONDecoder().decode(ServerCurrentRoadmap.self, from: Data(json.utf8))
        #expect(roadmap.active)
        #expect(roadmap.places.filter(\.isCompleted).count == 1)
        #expect(roadmap.currentPlace?.isCurrent == true)
        #expect(roadmap.nextPlace?.title == "주산지")
    }

    // MARK: - 서버 날짜

    @Test func serverDateTimeParsesMicroAndNanoSecondFractions() {
        #expect(ServerDateTime.date(from: "2026-08-24T08:06:50.072025") != nil)
        #expect(ServerDateTime.date(from: "2026-08-24T08:20:14.160347078") != nil)
        #expect(ServerDateTime.date(from: "2026-09-20T08:40:00") != nil)
        #expect(ServerDateTime.date(from: "not-a-date") == nil)
        #expect(ServerDateTime.listTimeText(from: "not-a-date").isEmpty)
        #expect(ServerDateTime.noticeTimeText(from: "2026-08-24T01:12:20.560012").contains("8월 24일"))
    }
}

// MARK: - 모임 검색 (10 탐색 · 11 탐색 지도 · 12 검색)

/// 2026-08-24 서버 패치로 검색 응답에 들어온 9필드 계약.
/// 본문 JSON은 실서버 `GET /chat-rooms/search` 응답을 그대로 고정한 값이다.
@Suite
struct ServerChatRoomSearchContractTests {
    /// 첫 항목은 실서버 응답 원문(roomId 40)이다. 두 번째는 숙박(시간·집합 안내 null),
    /// 세 번째는 좌표가 한쪽만 온 경우다.
    private static let searchJSON = #"""
    [
      {"roomId":40,"title":"안동 하회마을 하루 코스","description":"가을 단풍을 함께 즐길 동행자를 구해요.",
       "thumbnail":null,"tripType":"DAY_TRIP","startDate":"2026-09-12","endDate":null,
       "dayTripStartTime":"09:00:00","dayTripEndTime":"18:00:00",
       "recruitmentDeadlineDate":"2026-09-09","recruitmentDDay":15,"status":"RECRUITING","favorite":false,
       "meetingLatitude":36.576,"meetingLongitude":128.97,"meetingDetails":"안동역 1번 출구 앞",
       "meetingDateTime":"2026-09-12T08:30:00","hostId":62,"participantCount":2,"maxParticipants":5,
       "courseTitle":"안동 하회마을 코스","tags":[{"tagId":4,"name":"자연"},{"tagId":7,"name":"역사"}]},
      {"roomId":41,"title":"울릉도 2박 3일 섬 여행","description":null,"thumbnail":null,
       "tripType":"OVERNIGHT","startDate":"2026-09-20","endDate":"2026-09-22",
       "dayTripStartTime":null,"dayTripEndTime":null,
       "recruitmentDeadlineDate":"2026-09-17","recruitmentDDay":0,"status":"CONFIRMED","favorite":true,
       "meetingLatitude":null,"meetingLongitude":null,"meetingDetails":null,
       "meetingDateTime":"2026-09-20T07:00:00","hostId":61,"participantCount":5,"maxParticipants":5,
       "courseTitle":"울릉도 일주 코스","tags":[]},
      {"roomId":42,"title":"좌표가 한쪽만 온 모임","description":null,"thumbnail":null,
       "tripType":"DAY_TRIP","startDate":"2026-10-01","endDate":null,
       "dayTripStartTime":"10:00","dayTripEndTime":"17:00",
       "recruitmentDeadlineDate":"2026-09-28","recruitmentDDay":33,"status":"CANCELLED","favorite":false,
       "meetingLatitude":36.1,"meetingLongitude":null,"meetingDetails":"미정 아님 · 좌표만 결측",
       "meetingDateTime":"2026-10-01T09:30:00","hostId":61,"participantCount":1,"maxParticipants":4,
       "courseTitle":"테스트 코스","tags":[]}
    ]
    """#

    private func rooms() throws -> [ServerChatRoomSummary] {
        try JSONDecoder().decode([ServerChatRoomSummary].self, from: Data(Self.searchJSON.utf8))
    }

    @Test func searchResponseDecodesNineNewFields() throws {
        let rooms = try rooms()
        #expect(rooms.count == 3)

        let dayTrip = try #require(rooms.first { $0.roomId == 40 })
        #expect(dayTrip.recruitmentDDay == 15)
        #expect(dayTrip.status == "RECRUITING")
        #expect(!dayTrip.favorite)
        #expect(dayTrip.meetingLatitude == 36.576)
        #expect(dayTrip.meetingLongitude == 128.97)
        #expect(dayTrip.meetingDetails == "안동역 1번 출구 앞")
        #expect(dayTrip.meetingDateTime == "2026-09-12T08:30:00")
        #expect(dayTrip.dayTripStartTime == "09:00:00")
        #expect(dayTrip.dayTripEndTime == "18:00:00")
    }

    @Test func dayTripTimesParseBothSecondAndMinutePrecision() throws {
        let rooms = try rooms()
        // 실제 응답은 HH:mm:ss 다
        #expect(try #require(rooms.first { $0.roomId == 40 }).dayTripTimeText == "09:00 – 18:00")
        // 문서상 포맷 HH:mm 도 같은 표기가 되어야 한다
        #expect(try #require(rooms.first { $0.roomId == 42 }).dayTripTimeText == "10:00 – 17:00")
        #expect(ServerTripMapper.shortTime("09:00:00") == "09:00")
        #expect(ServerTripMapper.shortTime("09:00") == "09:00")
        #expect(ServerTripMapper.shortTime(nil) == nil)
        #expect(ServerTripMapper.shortTime("") == nil)
    }

    @Test func overnightRoomHidesDayTripTimesAndMeetingDetails() throws {
        let overnight = try #require(try rooms().first { $0.roomId == 41 })
        // 숙박이면 서버가 시간을 둘 다 null로 준다 — 표기를 숨긴다
        #expect(overnight.dayTripTimeText == nil)
        // 집합 안내가 null이면 "미정" 같은 문구를 지어내지 않는다
        #expect(overnight.meetingDetailsText == nil)
        #expect(overnight.meetingCoordinate == nil)
        #expect(overnight.favorite)
        #expect(overnight.recruitmentDDayText == "D-Day")
    }

    @Test func mapMarkersDropRoomsWithOnlyOneCoordinate() throws {
        let rooms = try rooms()
        let markers = ServerTripMapper.mapMarkers(from: rooms)
        // 좌표가 둘 다 있는 40번만 남는다 (41번은 둘 다 null, 42번은 위도만 있다)
        #expect(markers.count == 1)
        // 마커는 0.1° 격자로 **군집**된다 — 방이 하나여도 `cluster-<ids>` 형식이고 `order` 는 방 수다.
        // 예전 단일 방 형식(`server-room-40` · `order == nil`)을 기대하고 있었다.
        #expect(markers[0].id == "server-room-cluster-40")
        #expect(markers[0].coordinate.latitude == 36.576)
        // 모임 집합 장소는 순번 원이 아니라 단일 핀이다
        #expect(markers[0].order == 1)

        // **핀 탭이 이 id 로 방을 되찾는다**(화면기획 11). 만드는 쪽과 파싱하는 쪽이 따로라
        // 형식이 어긋나면 탭이 조용히 아무 것도 못 찾는다 — 왕복을 검사해 둔다.
        #expect(ServerTripMapper.clusterRoomIDs(from: markers[0].id) == [40])
        // 묶음에 여럿이 있어도 순서대로 되꺼낸다. 카드에 올리는 건 **첫 방**이다.
        #expect(ServerTripMapper.clusterRoomIDs(from: "server-room-cluster-40-41-42") == [40, 41, 42])
        // 우리 형식이 아닌 id 는 빈 배열이다 — 다른 레이어의 핀을 방으로 착각하지 않는다.
        #expect(ServerTripMapper.clusterRoomIDs(from: "moyeo.route.point-1").isEmpty)

        let content = try #require(ServerTripMapper.mapContent(from: rooms))
        #expect(content.markers.count == 1)
        #expect(content.center.longitude == 128.97)
        // 좌표가 없으면 목업 지도를 쓰도록 nil을 돌려준다
        #expect(ServerTripMapper.mapContent(from: rooms.filter { $0.roomId == 41 }) == nil)
    }

    @Test func statusBadgeUsesPlanningWording() throws {
        let rooms = try rooms()
        #expect(try #require(rooms.first { $0.roomId == 40 }).statusBadgeText == "진행중")
        #expect(try #require(rooms.first { $0.roomId == 41 }).statusBadgeText == "확정")
        #expect(try #require(rooms.first { $0.roomId == 42 }).statusBadgeText == "모집취소")
    }

    @Test func summaryMapsIntoRecruitmentWithoutExtraDetailCall() throws {
        let rooms = try rooms()
        let dayTrip = ServerTripMapper.trip(from: try #require(rooms.first { $0.roomId == 40 }))
        #expect(dayTrip.serverRoomID == 40)
        #expect(dayTrip.status == .open)
        // 마감 배지는 여행 시작이 아니라 모집 마감 D-day 다
        #expect(dayTrip.recruitmentDeadline == "D-15 · 9/9")
        #expect(dayTrip.scheduleDetails?.kind == .dayTrip)
        #expect(dayTrip.scheduleDetails?.startTime == "09:00")
        #expect(dayTrip.scheduleDetails?.endTime == "18:00")
        #expect(dayTrip.meetingDetails?.latitude == 36.576)
        #expect(dayTrip.meetingDetails?.meetingTime == "08:30")
        #expect(dayTrip.meetupPoint == "안동역 1번 출구 앞")
        // 서버가 주지 않는 값은 비워 둔다
        #expect(dayTrip.region.isEmpty)
        #expect(dayTrip.hostName.isEmpty)

        let overnight = ServerTripMapper.trip(from: try #require(rooms.first { $0.roomId == 41 }))
        #expect(overnight.status == .confirmed)
        #expect(overnight.scheduleDetails?.kind == .overnight)
        #expect(overnight.scheduleDetails?.startTime == nil)
        #expect(overnight.scheduleDetails?.endTime == nil)
        // 좌표가 없으면 집합 장소 지도 자체를 만들지 않는다
        #expect(overnight.meetingDetails == nil)
        #expect(overnight.recruitmentDeadline == "D-Day · 9/17")

        let cancelled = ServerTripMapper.trip(from: try #require(rooms.first { $0.roomId == 42 }))
        #expect(cancelled.status == .cancelled)
        // 위도만 온 항목은 지도를 그리지 않는다
        #expect(cancelled.meetingDetails == nil)
    }
}

// MARK: - 모집 만들기 요청 조립 (17)

@Suite
struct ServerChatRoomCreateRequestContractTests {
    private func dayTripDraft() -> RecruitmentDraft {
        var draft = RecruitmentDraft.preview
        draft.source = .linked
        draft.course = serverCourse()
        draft.schedule = TripScheduleDetails(
            kind: .dayTrip, startDate: "2026. 09. 12 (토)", startTime: "09:00", endTime: "18:00"
        )
        draft.deadline = "2026. 09. 09 (수) 23:59"
        return draft
    }

    private func serverCourse() -> TravelCourse {
        var course = RecruitmentDraft.preview.course
        course.serverCourseID = 21
        return course
    }

    @Test func dayTripRequestSendsTimesWithoutEndDate() throws {
        let request = try #require(
            ServerChatRoomCreateRequestBuilder.request(from: dayTripDraft(), course: .publicCourse(21))
        )
        #expect(request.tripType == "DAY_TRIP")
        #expect(request.startDate == "2026-09-12")
        #expect(request.recruitmentDeadlineDate == "2026-09-09")
        // DAY_TRIP: endDate 를 보내지 않고 시간 필드를 보낸다 (에러코드 40008)
        #expect(request.endDate == nil)
        #expect(request.dayTripStartTime == "09:00")
        #expect(request.dayTripEndTime == "18:00")
        // courseType 은 필수다
        #expect(request.courseType == "PUBLIC")
        #expect(request.courseId == 21)
        #expect(request.customCourse == nil)

        let json = try #require(try JSONSerialization.jsonObject(
            with: try JSONEncoder().encode(request)
        ) as? [String: Any])
        // nil 옵셔널은 키 자체가 빠져야 한다 — 서버가 상호배타를 키 존재로 판단한다
        #expect(json["endDate"] == nil)
        #expect(json["dayTripStartTime"] as? String == "09:00")
        #expect(json["courseType"] as? String == "PUBLIC")
    }

    @Test func overnightRequestSendsEndDateWithoutTimes() throws {
        var draft = dayTripDraft()
        draft.schedule = TripScheduleDetails(
            kind: .overnight, startDate: "2026. 09. 20 (일)", endDate: "2026. 09. 22 (화)"
        )
        let request = try #require(
            ServerChatRoomCreateRequestBuilder.request(from: draft, course: .publicCourse(21))
        )
        #expect(request.tripType == "OVERNIGHT")
        #expect(request.endDate == "2026-09-22")
        // 1박 이상: 시간 필드를 보내지 않는다
        #expect(request.dayTripStartTime == nil)
        #expect(request.dayTripEndTime == nil)

        let json = try #require(try JSONSerialization.jsonObject(
            with: try JSONEncoder().encode(request)
        ) as? [String: Any])
        #expect(json["endDate"] as? String == "2026-09-22")
        #expect(json["dayTripStartTime"] == nil)
        #expect(json["dayTripEndTime"] == nil)
    }

    @Test func overnightWithoutEndDateIsNotSent() {
        var draft = dayTripDraft()
        draft.schedule = TripScheduleDetails(kind: .overnight, startDate: "2026. 09. 20 (일)")
        #expect(ServerChatRoomCreateRequestBuilder.request(from: draft, course: .publicCourse(21)) == nil)
    }

    @Test func dayTripWithoutTimesIsNotSent() {
        var draft = dayTripDraft()
        draft.schedule = TripScheduleDetails(kind: .dayTrip, startDate: "2026. 09. 12 (토)")
        #expect(ServerChatRoomCreateRequestBuilder.request(from: draft, course: .publicCourse(21)) == nil)
    }

    @Test func linkedCourseWithoutServerIDIsNotSent() {
        var draft = dayTripDraft()
        draft.course = RecruitmentDraft.preview.course
        // 목데이터 코스는 서버 courseId 가 없어 PUBLIC 요청을 만들 수 없다 — 지어내지 않는다
        #expect(ServerChatRoomCreateRequestBuilder.courseSelection(for: draft, tagIDs: [4]) == nil)
    }

    @Test func customCourseNeedsTwoServerPlacesAndTags() throws {
        var draft = dayTripDraft()
        draft.source = .custom
        draft.itinerary = [
            ItineraryStop(id: "a", day: 1, order: 1, time: "09:00", name: "주왕산", memo: "", placeID: "2017064"),
            ItineraryStop(id: "b", day: 1, order: 2, time: "14:00", name: "주산지", memo: "", placeID: "2599344")
        ]
        let value = try #require(
            ServerChatRoomCreateRequestBuilder.customCourse(from: draft, tagIDs: [4, 7])
        )
        #expect(value.places.count == 2)
        #expect(value.places.first?.contentId == 2_017_064)
        #expect(value.places.first?.visitTime == "09:00")
        #expect(value.tagIds == [4, 7])

        // 태그 ID가 없으면 보내지 않는다 (서버 필수 조건)
        #expect(ServerChatRoomCreateRequestBuilder.customCourse(from: draft, tagIDs: []) == nil)

        // 서버 방문지 ID가 없는 항목은 제외되므로 2개를 못 채우면 보내지 않는다
        var localOnly = draft
        localOnly.itinerary = [
            ItineraryStop(id: "a", day: 1, order: 1, time: "09:00", name: "주왕산", memo: "", placeID: "2017064"),
            ItineraryStop(id: "b", day: 1, order: 2, time: "14:00", name: "새 방문지", memo: "")
        ]
        #expect(ServerChatRoomCreateRequestBuilder.customCourse(from: localOnly, tagIDs: [4]) == nil)

        // 상호배타 규칙은 CUSTOM 에서도 같다
        let request = ServerChatRoomCreateRequestBuilder.request(
            from: draft, course: .custom(value)
        )
        #expect(request?.courseType == "CUSTOM")
        #expect(request?.courseId == nil)
        #expect(request?.endDate == nil)
        #expect(request?.customCourse?.places.count == 2)
    }

    @Test func requestCarriesApprovalModeGenderAndFee() throws {
        var draft = dayTripDraft()
        draft.approvalMode = .manual
        draft.genderRestriction = RecruitmentGenderCondition.women.rawValue
        draft.estimatedCost = "1인 45,000원"
        let request = try #require(
            ServerChatRoomCreateRequestBuilder.request(from: draft, course: .publicCourse(21))
        )
        #expect(request.joinApprovalMode == "MANUAL")
        #expect(request.genderRestriction == "FEMALE_ONLY")
        #expect(request.participationFee == 45_000)
        // 08:00 은 `RecruitmentDraft` 의 집합 시각 기본값이다 — 안드로이드 초안과 맞추려고
        // 07:50 에서 바꿨다(`Changelog01Screens.swift` 주석에 근거가 있다). 기대값만 안 따라왔었다.
        #expect(request.meetingDateTime == "2026-09-12T08:00:00")
        #expect(request.maxParticipants == draft.capacity)

        var automatic = draft
        automatic.approvalMode = .automatic
        automatic.genderRestriction = RecruitmentGenderCondition.any.rawValue
        let autoRequest = try #require(
            ServerChatRoomCreateRequestBuilder.request(from: automatic, course: .publicCourse(21))
        )
        #expect(autoRequest.joinApprovalMode == "AUTO")
        #expect(autoRequest.genderRestriction == "NONE")
    }

    @Test func createResponseDecodesRoomID() throws {
        let response = try JSONDecoder().decode(
            ServerCreateChatRoomResponse.self, from: Data(#"{"roomId":41}"#.utf8)
        )
        #expect(response.roomId == 41)
        // 응답의 roomId 로 15 모집 상세 진입용 껍데기를 만든다
        let trip = ServerTripMapper.placeholderTrip(roomID: response.roomId, title: "새 모집")
        #expect(trip.serverRoomID == 41)
        #expect(trip.id == "server-room-41")
    }
}

// MARK: - 코스 상세 (14)

@Suite
struct ServerTravelCourseDetailContractTests {
    @Test func courseDetailMapsCreatorIntoPublishingInfo() throws {
        let json = #"""
        {"courseId":77,"title":"주왕산 단풍길 코스","description":"완만한 숲길",
         "creatorNickname":"따스한 사슴 3492",
         "creatorProfileImageUrl":"https://moyeo-trip-cdn.jayden-bin.cc/user/profile/image/a.webp",
         "creatorTravelStartDate":"2026-05-25",
         "creatorTravelEndDate":null,"chatRoomCount":3,"travelTime":"6시간 30분","distanceKm":12.4,
         "averageRating":4.5,"ratingCount":12,"tags":[{"tagId":4,"name":"자연"}],"thumbnail":null,
         "places":[
          {"contentId":2599344,"dayNumber":1,"sequence":2,"visitTime":"14:00:00","title":"주산지",
           "thumbnail":null,"latitude":36.3494,"longitude":129.1436},
          {"contentId":2017064,"dayNumber":1,"sequence":1,"visitTime":"10:00:00","title":"주왕산",
           "thumbnail":null,"latitude":36.3931,"longitude":129.1728}]}
        """#
        let detail = try JSONDecoder().decode(ServerTravelCourseDetail.self, from: Data(json.utf8))
        let course = ServerCourseMapper.course(from: detail)

        #expect(course.id == "server-course-77")
        #expect(course.serverCourseID == 77)
        #expect(course.isServerBacked)
        #expect(course.duration == "6시간 30분")
        #expect(course.distance == "12.4km")
        #expect(course.serverAverageRating == 4.5)
        // 방문 순서는 일차·순번으로 정렬한다
        #expect(course.stops == ["주왕산", "주산지"])
        #expect(course.itinerary.first?.time == "10:00")

        let publishing = try #require(course.publishingInfo)
        #expect(publishing.travelerName == "따스한 사슴 3492")
        #expect(publishing.tripCount == 3)
        #expect(publishing.publishedAt == "2026.05.25 (월)")
        // 서버가 프로필 이미지를 주면 그게 근거다 (2026-09-02 추가) — 마스코트를 그리지 않는다
        #expect(
            publishing.travelerAvatarURL?.absoluteString
                == "https://moyeo-trip-cdn.jayden-bin.cc/user/profile/image/a.webp")
        // 이미지가 없을 때만 쓰는 대체 표시는 닉네임에서 유도한다 (표는 MoyeoNicknameAnimal 하나뿐)
        #expect(publishing.travelerAvatar == MoyeoNicknameAnimal.emoji(forNickname: "따스한 사슴 3492"))
    }

    @Test func courseDetailWithoutCreatorHidesPublishingCard() throws {
        let json = #"""
        {"courseId":78,"title":"공개 코스","description":null,"creatorNickname":null,
         "creatorProfileImageUrl":null,"creatorTravelStartDate":null,"creatorTravelEndDate":null,"chatRoomCount":0,
         "travelTime":"3시간","distanceKm":5.0,"averageRating":null,"ratingCount":0,
         "tags":[],"thumbnail":null,"places":[]}
        """#
        let detail = try JSONDecoder().decode(ServerTravelCourseDetail.self, from: Data(json.utf8))
        let course = ServerCourseMapper.course(from: detail)
        #expect(course.publishingInfo == nil)
        #expect(course.serverAverageRating == nil)
        #expect(course.distance == "5km")
    }
}

// MARK: - 피드 댓글 (23-1)

@Suite
struct ServerFeedCommentContractTests {
    /// 2026-09-02 서버 변경: 댓글 배열 단독 → `{comments, nextId}` 객체 (파괴적 변경).
    /// 마지막 묶음이면 `nextId` 가 `null` 이다.
    @Test func commentsDecodeAsPageWithNestedReplies() throws {
        let json = #"""
        {"comments":
         [{"commentId":1,"author":{"userId":61,"nickname":"즐거운 고양이 4760","profileImageUrl":null},
           "content":"이 코스 저도 가보고 싶네요.","createdAt":"2026-09-15T20:00:00",
           "replies":[{"commentId":2,"author":{"userId":62,"nickname":"따스한 기린 2334",
             "profileImageUrl":null},"content":"당일치기로 충분해요!",
             "createdAt":"2026-09-15T20:10:00","replies":[]}]},
          {"commentId":3,"author":{"userId":62,"nickname":"따스한 기린 2334","profileImageUrl":null},
           "content":"사진 더 올릴게요","createdAt":"2026-09-15T21:00:00","replies":[]}],
         "nextId":null}
        """#
        let page = try JSONDecoder().decode(ServerFeedCommentPage.self, from: Data(json.utf8))
        #expect(page.comments.count == 2)
        #expect(page.comments[0].replyList.count == 1)
        #expect(page.comments[0].replyList[0].content == "당일치기로 충분해요!")
        #expect(page.comments[1].replyList.isEmpty)
        // 마지막 묶음 — 다음 커서가 없다
        #expect(page.nextId == nil)
    }

    /// 다음 묶음이 있으면 마지막 최상위 댓글 id 가 `nextId` 로 온다 (실서버 확인: `?limit=1` → `nextId 3`).
    @Test func commentPageCarriesNextCursor() throws {
        let json = #"""
        {"comments":
         [{"commentId":3,"author":{"userId":61,"nickname":"즐거운 고양이 4760","profileImageUrl":null},
           "content":"이 코스 저도 가보고 싶네요.","createdAt":"2026-08-29T13:08:56.246064",
           "replies":[]}],
         "nextId":3}
        """#
        let page = try JSONDecoder().decode(ServerFeedCommentPage.self, from: Data(json.utf8))
        #expect(page.comments.count == 1)
        #expect(page.nextId == 3)
    }

    @Test func commentWithoutRepliesKeyStillDecodes() throws {
        let json = #"{"comments":[{"commentId":9,"author":null,"content":null,"createdAt":null}],"nextId":null}"#
        let page = try JSONDecoder().decode(ServerFeedCommentPage.self, from: Data(json.utf8))
        #expect(page.comments[0].replyList.isEmpty)
        // 서버가 값을 주지 않으면 지어내지 않는다
        #expect(page.comments[0].content == nil)
        #expect(page.comments[0].author == nil)
    }
}

// MARK: - 관광 콘텐츠 타입 (17-1a)

@Suite
struct ServerTourismContentTypeContractTests {
    @Test func contentTypesDecodeFromServerList() throws {
        let json = #"""
        [{"contentTypeId":12,"contentTypeName":"관광지"},{"contentTypeId":32,"contentTypeName":"숙박"},
         {"contentTypeId":39,"contentTypeName":"음식점"}]
        """#
        let types = try JSONDecoder().decode([ServerTourismContentType].self, from: Data(json.utf8))
        #expect(types.count == 3)
        #expect(types[0].id == 12)
        #expect(types.map(\.contentTypeName).contains("음식점"))
    }

    @Test func listParserReadsServerAddressAndContentTypeKeys() throws {
        // 실서버 목록은 address1 / contentTypeId 를 쓴다
        let json = #"""
        {"items":[{"contentId":2902799,"contentTypeId":39,"title":"1894사랑채",
          "address1":"경상북도 경주시 포석로1068번길 23","address2":null,
          "thumbnail":"https://tong.visitkorea.or.kr/a.jpg","longitude":129.21,"latitude":35.83}],
         "page":0,"size":1,"totalElements":750,"totalPages":750}
        """#
        let places = try TourismAPIResponseParser.places(from: Data(json.utf8))
        #expect(places.count == 1)
        #expect(places[0].address == "경상북도 경주시 포석로1068번길 23")
        #expect(places[0].serverContentTypeID == 39)
        #expect(places[0].type == .restaurant)
    }

    @Test func detailParserReadsContentImagesWithOriginalImageUrl() throws {
        let json = #"""
        {"contentId":2599344,"contentTypeId":32,"title":"박산정",
         "address1":"경상북도 안동시 민속촌길 190","zipcode":"36605","telephone":"054-000-0000",
         "telephoneName":"숙소 안내","homepage":"https://example.com","overview":"한옥 리조트",
         "thumbnail":null,"longitude":128.76,"latitude":36.57,
         "contentImages":[{"contentId":2599344,"imageName":"a.jpg",
           "originalImageUrl":"https://tong.visitkorea.or.kr/a.jpg","serialNumber":"1",
           "copyrightType":"Type1"}],
         "menuImages":[]}
        """#
        let place = try TourismAPIResponseParser.place(from: Data(json.utf8))
        #expect(place.imageURLs.count == 1)
        #expect(place.imageURLs[0].absoluteString == "https://tong.visitkorea.or.kr/a.jpg")
        #expect(place.postalCode == "36605")
        #expect(place.phone == "054-000-0000")
        #expect(place.summary == "한옥 리조트")
        #expect(place.type == .lodging)
        #expect(!place.showsMenuImages)
    }
}
