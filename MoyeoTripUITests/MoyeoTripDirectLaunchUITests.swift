//
//  MoyeoTripDirectLaunchUITests.swift
//  MoyeoTripUITests
//

import XCTest

final class MoyeoTripDirectLaunchUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testDirectLaunchOpensFeedDetailAndWriteScreens() {
        launch(screen: "feed-detail:feed-03")
        XCTAssertTrue(app.staticTexts["고요한 두루미 1130"].waitForExistence(timeout: 4))
        assertStaticTextContaining("경주 역사 감성 여행은 월정교")
        XCTAssertTrue(app.textFields["댓글을 입력하세요..."].exists)

        relaunch(screen: "feed-write")
        XCTAssertTrue(app.staticTexts["피드 글쓰기"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["STEP 1 · 코스 확인"].exists)
    }

    @MainActor
    func testDirectLaunchOpensCourseTripAndChatScreens() {
        launch(screen: "course-detail:course-andong-hahoe")
        XCTAssertTrue(element("course.detail.course-andong-hahoe").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["안동 하회마을 하루 코스"].exists)

        relaunch(screen: "trip-detail:trip-ulleung-island")
        XCTAssertTrue(app.staticTexts["모집 상세"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["울릉도 2박 3일 섬 여행"].exists)

        relaunch(screen: "chat:chat-cheongsong-juwangsan")
        XCTAssertTrue(app.staticTexts["주왕산 & 주산지 힐링 트레킹"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.textFields["메시지 입력"].exists)
    }

    @MainActor
    func testDirectLaunchOpensSupportAndMapScreens() {
        launch(screen: "auth")
        XCTAssertTrue(app.staticTexts["고민 없이 고르는 경북 코스"].waitForExistence(timeout: 4))

        relaunch(screen: "create-recruitment:course-gyeongju-history")
        XCTAssertTrue(element("screen.createRecruitment.course-gyeongju-history").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["모집 정보"].exists)

        relaunch(screen: "search")
        XCTAssertTrue(app.staticTexts["검색"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["청송"].exists)

        relaunch(screen: "explore-map")
        XCTAssertTrue(app.staticTexts["지도 탐색"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["주왕산 & 주산지 힐링 트레킹"].exists)
        XCTAssertTrue(bottomExploreTabExists())
    }

    @MainActor
    func testDirectLaunchOpensMyHubSupportScreens() {
        launch(screen: "my-feed")
        XCTAssertTrue(element("screen.myFeed").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["내 피드"].exists)

        relaunch(screen: "customer-center")
        XCTAssertTrue(element("screen.customerCenter").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["고객센터"].exists)
    }

    private func launch(screen: String) {
        let launchedApp = XCUIApplication()
        launchedApp.launchArguments = [
            "UITEST_MODE",
            "UITEST_SCREEN=\(screen)"
        ]
        launchedApp.launch()
        app = launchedApp
    }

    private func relaunch(screen: String) {
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 3)
        launch(screen: screen)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func bottomExploreTabExists(timeout: TimeInterval = 3) -> Bool {
        if app.buttons["tab.explore"].waitForExistence(timeout: timeout) {
            return true
        }
        return app.buttons["탐색"].waitForExistence(timeout: timeout)
    }

    private func assertStaticTextContaining(
        _ text: String,
        timeout: TimeInterval = 3,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let target = app.staticTexts.matching(predicate).firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "Missing text containing \(text)", file: file, line: line)
    }
}
