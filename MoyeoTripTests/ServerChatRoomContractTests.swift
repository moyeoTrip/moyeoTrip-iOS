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

    @Test func noticeMappingSplitsFirstLineAndKeepsAuthor() throws {
        let history = try JSONDecoder().decode(
            ServerChatRoomNoticeHistory.self, from: Data(Self.noticesJSON.utf8)
        )
        #expect(history.allNotices.count == 2)
        let notice = ServerTripMapper.notice(from: history.pinnedNotices[0])
        #expect(notice.id == "server-notice-21")
        #expect(notice.title == "집합 시간 10분 전까지 안동역 1번 출구로 와주세요.")
        #expect(notice.body.isEmpty)
        #expect(notice.authorName == "따스한 기린 2334")
        #expect(notice.isPinned)

        let multiline = ServerChatRoomNotice(
            noticeId: 5, content: "집합 안내\n07:50 정문 앞", pinned: false,
            authorNickname: "호스트", createdAt: "2026-08-24T01:12:20.560012"
        )
        let mapped = ServerTripMapper.notice(from: multiline)
        #expect(mapped.title == "집합 안내")
        #expect(mapped.body == "07:50 정문 앞")
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

// MARK: - 코스 상세 (14)

@Suite
struct ServerTravelCourseDetailContractTests {
    @Test func courseDetailMapsCreatorIntoPublishingInfo() throws {
        let json = #"""
        {"courseId":77,"title":"주왕산 단풍길 코스","description":"완만한 숲길",
         "creatorNickname":"따스한 사슴 3492","creatorTravelStartDate":"2026-05-25",
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
        // 서버가 마스코트를 주지 않는다 — 지어내지 않는다
        #expect(publishing.travelerAvatar.isEmpty)
    }

    @Test func courseDetailWithoutCreatorHidesPublishingCard() throws {
        let json = #"""
        {"courseId":78,"title":"공개 코스","description":null,"creatorNickname":null,
         "creatorTravelStartDate":null,"creatorTravelEndDate":null,"chatRoomCount":0,
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
