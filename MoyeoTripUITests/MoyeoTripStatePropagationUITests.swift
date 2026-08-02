//
//  MoyeoTripStatePropagationUITests.swift
//  MoyeoTripUITests
//

import XCTest

final class MoyeoTripStatePropagationUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testFeedPublishIncrementsProfileFeedCount() {
        launch(startTab: "feed")

        openFeedWriter()
        completeFeedWriter()
        XCTAssertTrue(app.staticTexts["첫 반패키지 단풍 여행"].waitForExistence(timeout: 3))

        app.navigationBars.buttons.firstMatch.tap()
        tapElement("tab.my")

        assertElement("my.stat.feed.value", hasLabel: "22")
        assertElement("my.stat.feed.label", hasLabel: "피드")

        tapElement("my.feedShortcut")
        XCTAssertTrue(element("screen.myFeed").waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["첫 반패키지 단풍 여행"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testTripApplicationUpdatesProfileAndMyTripParticipantState() {
        launch(startTab: "my")

        tapButton("찜한 코스")
        tapElement("my.savedCourse.course-ulleung-island", timeout: 5)
        XCTAssertTrue(element("course.detail.course-ulleung-island").waitForExistence(timeout: 3))
        tapButton("모집 중인 모임 보기")

        XCTAssertTrue(app.buttons["trip.detail.apply"].waitForExistence(timeout: 3))
        app.buttons["trip.detail.apply"].tap()
        XCTAssertTrue(app.staticTexts["함께 가기 신청"].waitForExistence(timeout: 3))
        tapElement("application.sheet.submit")
        XCTAssertTrue(app.staticTexts["모집에 참여됐어요"].waitForExistence(timeout: 3))
        tapButton("닫기")

        tapButton("뒤로")
        app.navigationBars.buttons.firstMatch.tap()
        tapButton("진행중")

        assertElement("my.activeTrip.trip-ulleung-island.people", hasLabel: "4/5명")
        tapButton("프로필 메뉴")
        assertElement("profile.stat.joined.value", hasLabel: "13")
    }

    @MainActor
    func testCreatedRecruitmentIncrementsProfileHostedCount() {
        launch(startTab: "home")

        tapButton("모집 만들기", timeout: 5)
        XCTAssertTrue(element("screen.createRecruitment.course-cheongsong-juwangsan").waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["모집 정보"].waitForExistence(timeout: 3))
        replaceText(identifier: "createRecruitment.date", with: "2026.06.20 (토)")
        replaceText(identifier: "createRecruitment.time", with: "10:30 - 16:30")
        replaceText(identifier: "createRecruitment.place", with: "청송 시외버스터미널 2번 승강장")
        replaceText(identifier: "createRecruitment.note", with: "새로 만든 청송 숲길 모임이에요. 점심은 각자 준비해요.")
        XCTAssertTrue(element("createRecruitment.capacity").exists)
        tapButton("모집 만들기")
        XCTAssertTrue(app.buttons["채팅방 미리보기"].waitForExistence(timeout: 3))
        tapButton("채팅방 미리보기")
        XCTAssertTrue(app.staticTexts["새로 만든 청송 숲길 모임이에요. 점심은 각자 준비해요."].waitForExistence(timeout: 3))
        app.navigationBars.buttons.firstMatch.tap()

        tapButton("뒤로")
        tapElement("tab.my")
        XCTAssertTrue(app.staticTexts["2026.06.20 (토)"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["1/5명"].waitForExistence(timeout: 3))
        tapButton("프로필 메뉴")

        assertElement("profile.stat.hosted.value", hasLabel: "4")
        assertElement("profile.stat.hosted.title", hasLabel: "호스트")
    }

    @MainActor
    func testExploreShowsRecruitmentMetadataAndFloatingCreateEntry() {
        launch(startTab: "explore")

        XCTAssertTrue(element("screen.explore").waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["모집중"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["2/5명"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["출발확정"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["3/6명"].waitForExistence(timeout: 3))

        tapButton("모집 만들기")
        XCTAssertTrue(element("screen.createRecruitment.course-cheongsong-juwangsan").waitForExistence(timeout: 3))
    }

    @MainActor
    func testHostManageApprovesRejectsCancelsAndOpensChatAfterRecruitmentCreation() {
        launch(startTab: "home")

        tapButton("모집 만들기", timeout: 5)
        XCTAssertTrue(app.staticTexts["모집 정보"].waitForExistence(timeout: 3))
        tapButton("모집 만들기")
        XCTAssertTrue(app.buttons["채팅방 미리보기"].waitForExistence(timeout: 3))
        tapElement("createRecruitment.openManage")

        XCTAssertTrue(app.staticTexts["모집 관리"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["승인 대기"].exists)
        XCTAssertTrue(app.staticTexts["따스한 사슴 3492"].exists)
        tapButton("따스한 사슴 3492 승인")
        XCTAssertTrue(app.staticTexts["승인된 동행자"].exists)
        XCTAssertTrue(app.staticTexts["따스한 사슴 3492"].waitForExistence(timeout: 3))

        tapButton("잔잔한 거북이 9032 거절")
        XCTAssertTrue(app.staticTexts["거절 기록"].waitForExistence(timeout: 3))

        tapElement("hostManage.toggleClose")
        assertElement("hostManage.closeState", hasLabel: "모집 취소됨")
        assertElement("hostManage.toggleClose", hasLabel: "모집 다시 열기")
        tapElement("hostManage.openChat")
        XCTAssertTrue(app.textFields["메시지 입력"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["모집이 막 만들어졌어요. 함께 갈 사람을 기다려요."].exists)
    }

    @MainActor
    func testMeetingsAndFeedKeepComfortableTouchAndReadingSpace() {
        launch(startTab: "meetings")
        XCTAssertTrue(element("screen.meetings").waitForExistence(timeout: 3))

        let segmentByID = element("meetings.segment.진행중")
        let ongoingSegment = segmentByID.waitForExistence(timeout: 1)
            ? segmentByID
            : app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "진행중")).firstMatch
        XCTAssertTrue(ongoingSegment.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(ongoingSegment.frame.height, 34)
        XCTAssertLessThanOrEqual(ongoingSegment.frame.height, 44)

        let firstThread = app.buttons["meeting.thread.chat-gyeongju-night"]
        XCTAssertTrue(firstThread.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(firstThread.frame.height, 72)
        XCTAssertLessThanOrEqual(firstThread.frame.height, 96)
        XCTAssertGreaterThanOrEqual(firstThread.frame.minY - ongoingSegment.frame.maxY, 4)
        XCTAssertLessThanOrEqual(firstThread.frame.minY - ongoingSegment.frame.maxY, 28)

        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 3)
        launch(startTab: "feed")
        XCTAssertTrue(element("screen.feed").waitForExistence(timeout: 3))

        let discoverSegment = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "발견")).firstMatch
        XCTAssertTrue(discoverSegment.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(discoverSegment.frame.height, 48)

        let firstPost = app.buttons["feed.post.feed-01"]
        XCTAssertTrue(firstPost.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(firstPost.frame.height, 300)
        XCTAssertLessThanOrEqual(firstPost.frame.height, 460)

        let author = app.staticTexts["feed.post.feed-01.author"]
        let title = app.staticTexts["feed.post.feed-01.title"]
        let subtitle = app.staticTexts["feed.post.feed-01.subtitle"]
        let tagRow = element("feed.post.feed-01.tags")
        XCTAssertTrue(author.exists)
        XCTAssertTrue(title.exists)
        XCTAssertTrue(subtitle.exists)
        XCTAssertTrue(tagRow.exists)
        XCTAssertGreaterThanOrEqual(title.frame.minY - author.frame.maxY, 8)
        XCTAssertGreaterThanOrEqual(subtitle.frame.minY - title.frame.maxY, 4)
        XCTAssertGreaterThanOrEqual(tagRow.frame.minY - subtitle.frame.maxY, 8)
        XCTAssertLessThanOrEqual(tagRow.frame.maxX, firstPost.frame.maxX - 8)

        let writeButton = app.buttons["feed.write.open"].firstMatch
        XCTAssertTrue(writeButton.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(writeButton.frame.width, 44)
        XCTAssertGreaterThanOrEqual(writeButton.frame.height, 44)
    }

    private func launch(startTab: String) {
        let launchedApp = XCUIApplication()
        launchedApp.launchArguments = [
            "UITEST_MODE",
            "UITEST_TAB=\(startTab)"
        ]
        launchedApp.launch()
        app = launchedApp
    }

    private func openFeedWriter() {
        XCTAssertTrue(element("screen.feed").waitForExistence(timeout: 3))
        let writeButton = app.buttons["feed.write.open"].firstMatch
        if !writeButton.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(writeButton.waitForExistence(timeout: 3))
        writeButton.tap()
    }

    private func completeFeedWriter() {
        XCTAssertTrue(app.staticTexts["피드 글쓰기"].waitForExistence(timeout: 3))
        tapElement("feed.write.course.course-andong-hahoe")
        for _ in 0..<3 {
            tapElement("feed.write.next")
        }
        tapElement("feed.write.visibility.public")
        tapElement("feed.write.next")
        tapElement("feed.write.complete")
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func tapElement(
        _ identifier: String,
        timeout: TimeInterval = 3,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let target = element(identifier)
        if !target.waitForExistence(timeout: timeout) || !target.isHittable {
            for _ in 0..<5 where !target.exists || !target.isHittable {
                app.swipeUp()
                _ = target.waitForExistence(timeout: 1)
            }
        }
        XCTAssertTrue(target.exists, "Missing \(identifier)", file: file, line: line)
        XCTAssertTrue(target.isHittable, "Element is not hittable \(identifier)", file: file, line: line)
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func tapButton(
        _ label: String,
        timeout: TimeInterval = 3,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let target = app.buttons[label].firstMatch
        if !target.waitForExistence(timeout: timeout) || !target.isHittable {
            for _ in 0..<5 where !target.exists || !target.isHittable {
                app.swipeUp()
                _ = target.waitForExistence(timeout: 1)
            }
        }
        XCTAssertTrue(target.exists, "Missing button \(label)", file: file, line: line)
        XCTAssertTrue(target.isHittable, "Button is not hittable \(label)", file: file, line: line)
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func assertElement(
        _ identifier: String,
        hasLabel expectedLabel: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let target = element(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: 3), "Missing \(identifier)", file: file, line: line)
        XCTAssertEqual(target.label, expectedLabel, file: file, line: line)
    }

    private func replaceText(
        identifier: String,
        with replacement: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let target = element(identifier)
        if !target.waitForExistence(timeout: 3) || !target.isHittable {
            for _ in 0..<5 where !target.exists || !target.isHittable {
                app.swipeUp()
                _ = target.waitForExistence(timeout: 1)
            }
        }
        XCTAssertTrue(target.exists, "Missing \(identifier)", file: file, line: line)
        XCTAssertTrue(target.isHittable, "Element is not hittable \(identifier)", file: file, line: line)
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        target.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 80))
        target.typeText(replacement)
    }
}
