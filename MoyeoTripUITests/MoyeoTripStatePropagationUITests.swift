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
        completeRecruitmentFlow()
        XCTAssertTrue(element("screen.hostManage").waitForExistence(timeout: 3))
        tapButton("뒤로")

        tapElement("tab.my")
        XCTAssertTrue(app.staticTexts["1/5명"].waitForExistence(timeout: 3))
        tapButton("프로필 메뉴")

        assertElement("profile.stat.hosted.value", hasLabel: "4")
        assertElement("profile.stat.hosted.title", hasLabel: "호스트")
    }

    @MainActor
    func testExploreShowsRecruitmentMetadataAndFloatingCreateEntry() {
        launch(startTab: "explore")

        XCTAssertTrue(element("screen.explore").waitForExistence(timeout: 3))
        // 탐색 배지는 화면기획·웹·안드로이드와 같은 진행중 / 확정 두 가지다
        XCTAssertTrue(app.staticTexts["진행중"].firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["2/5명"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["확정"].firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["3/6명"].waitForExistence(timeout: 3))

        tapButton("모집 만들기")
        XCTAssertTrue(element("screen.createRecruitment.course-cheongsong-juwangsan.step1").waitForExistence(timeout: 3))
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
        // 태그 칩 줄이 빠져(부제 한 줄로 통일) 카드가 약 18pt 낮아졌다
        XCTAssertGreaterThanOrEqual(firstPost.frame.height, 240)
        XCTAssertLessThanOrEqual(firstPost.frame.height, 460)

        let author = app.staticTexts["feed.post.feed-01.author"]
        let title = app.staticTexts["feed.post.feed-01.title"]
        let subtitle = app.staticTexts["feed.post.feed-01.subtitle"]
        XCTAssertTrue(author.exists)
        XCTAssertTrue(title.exists)
        XCTAssertTrue(subtitle.exists)
        XCTAssertGreaterThanOrEqual(title.frame.minY - author.frame.maxY, 8)
        XCTAssertGreaterThanOrEqual(subtitle.frame.minY - title.frame.maxY, 4)
        XCTAssertLessThanOrEqual(subtitle.frame.maxX, firstPost.frame.maxX - 8)

        let writeButton = app.buttons["feed.write.open"].firstMatch
        XCTAssertTrue(writeButton.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(writeButton.frame.width, 44)
        XCTAssertGreaterThanOrEqual(writeButton.frame.height, 44)
    }

    private func launch(startTab: String) {
        XCUIDevice.shared.orientation = .portrait
        let launchedApp = XCUIApplication()
        launchedApp.launchArguments = [
            "UITEST_MODE",
            "UITEST_FAST_ANIMATIONS",
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

    private func completeRecruitmentFlow() {
        XCTAssertTrue(
            element("screen.createRecruitment.course-cheongsong-juwangsan.step1")
                .waitForExistence(timeout: 3)
        )
        tapButton("이 코스로 다음")
        for step in 2...4 {
            XCTAssertTrue(app.staticTexts["모집 만들기 (\(step)/5)"].waitForExistence(timeout: 3))
            tapButton("다음")
        }
        XCTAssertTrue(app.staticTexts["모집 만들기 (5/5)"].waitForExistence(timeout: 3))
        tapButton("모집 열기")
        XCTAssertTrue(element("screen.hostManage").waitForExistence(timeout: 3))
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
            for _ in 0..<12 where !target.exists || !target.isHittable {
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
            for _ in 0..<12 where !target.exists || !target.isHittable {
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
}
