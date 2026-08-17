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
        XCTAssertTrue(element("screen.createRecruitment.course-gyeongju-history.step1").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["코스 선택"].exists)

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

    @MainActor
    func testTripConfirmedUsesFinalHeroAndKeepsPrimaryActionVisible() {
        launch(screen: "trip-confirmed")

        XCTAssertTrue(element("screen.tripConfirmed").waitForExistence(timeout: 4))
        XCTAssertTrue(element("tripConfirmed.hero").exists)
        XCTAssertTrue(element("tripConfirmed.details").exists)
        XCTAssertTrue(element("tripConfirmed.openChat").isHittable)
        XCTAssertTrue(app.staticTexts["여행이 확정됐어요!"].exists)
    }

    @MainActor
    func testOfflineEmptyAndCachedStatesExplainWhatIsAvailable() {
        launch(arguments: ["UITEST_OFFLINE_EMPTY"])
        XCTAssertTrue(element("screen.offline.empty").waitForExistence(timeout: 4))
        let connectionIcon = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "인터넷 연결 없음"))
            .firstMatch
        XCTAssertTrue(connectionIcon.exists)
        XCTAssertTrue(app.staticTexts["연결 상태를\n확인해주세요"].exists)
        XCTAssertTrue(app.staticTexts["지금도 볼 수 있는 것"].exists)
        XCTAssertTrue(app.buttons["다시 시도"].exists)

        relaunch(arguments: ["UITEST_OFFLINE_CACHED"])
        XCTAssertTrue(element("screen.home").waitForExistence(timeout: 4))
        XCTAssertTrue(element("offline.banner").exists)
        XCTAssertTrue(element("home.weatherHero.offline").exists)
        XCTAssertFalse(app.buttons["모집 만들기"].isEnabled)
    }

    @MainActor
    func testOfflineChatQueuesMessageWithoutDisablingComposer() {
        launch(screen: "chat:chat-cheongsong-juwangsan", arguments: ["UITEST_OFFLINE_CHAT"])

        XCTAssertTrue(element("offline.chat.banner").waitForExistence(timeout: 4))
        XCTAssertFalse(element("chat.attachment").isEnabled)
        let composer = app.textFields["메시지 입력"]
        XCTAssertTrue(composer.isHittable)
        composer.tap()
        composer.typeText("연결되면 보내주세요")
        let sendButton = element("chat.message.send")
        XCTAssertTrue(sendButton.waitForExistence(timeout: 2))
        XCTAssertTrue(sendButton.isHittable)
        sendButton.tap()
        XCTAssertTrue(app.staticTexts["전송 대기"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testChangelogChatAndSafetyScreensOpenDirectly() {
        assertDirectScreen("chat-menu", identifier: "screen.chatMenu")
        assertDirectScreen("chat-attach", identifier: "screen.chatAttach")
        assertDirectScreen("friends", identifier: "screen.friends")
        assertDirectScreen("trip-message", identifier: "screen.tripMessage")
        assertDirectScreen("report", identifier: "screen.report")
        assertDirectScreen("blocked-users", identifier: "screen.blockedUsers")
    }

    @MainActor
    func testChangelogTripAndAccountScreensOpenDirectly() {
        launch(screen: "course-publish")
        XCTAssertTrue(element("screen.coursePublish").waitForExistence(timeout: 4))
        XCTAssertTrue(element("coursePublish.previewTitle").waitForExistence(timeout: 2))
        app.swipeUp()
        XCTAssertTrue(element("coursePublish.irreversibleWarning").waitForExistence(timeout: 2))

        launch(screen: "trip-day")
        XCTAssertTrue(element("screen.tripDay").waitForExistence(timeout: 4))
        assertStaticTextContaining("현재 방문지 2/4 · 주왕산")
        assertStaticTextContaining("다음 일정 ·")
        assertStaticTextContaining("3명이 위치를 공유 중이에요")
        assertStaticTextContaining("오늘 여행이 시작됐어요")
        assertStaticTextContaining("주산지 주차장")

        assertDirectScreen("notification-detail", identifier: "screen.notificationDetail")
        assertDirectScreen("account-delete", identifier: "screen.accountDelete")
    }

    @MainActor
    func testChangelogSystemAndCommentsScreensOpenDirectly() {
        assertDirectScreen("system-maintenance", identifier: "screen.systemMaintenance")
        assertDirectScreen("system-error", identifier: "screen.systemError")
        assertDirectScreen("feed-comments", identifier: "screen.feedComments")
    }

    private func launch(screen: String) {
        launch(screen: screen, arguments: [])
    }

    private func launch(screen: String? = nil, arguments: [String]) {
        XCUIDevice.shared.orientation = .portrait
        let launchedApp = XCUIApplication()
        launchedApp.launchArguments = [
            "UITEST_MODE",
            "UITEST_FAST_ANIMATIONS"
        ]
        if let screen {
            launchedApp.launchArguments.append("UITEST_SCREEN=\(screen)")
        }
        launchedApp.launchArguments.append(contentsOf: arguments)
        launchedApp.launch()
        app = launchedApp
    }

    private func relaunch(screen: String) {
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 3)
        launch(screen: screen)
    }

    private func relaunch(arguments: [String]) {
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 3)
        launch(arguments: arguments)
    }

    private func assertDirectScreen(_ screen: String, identifier: String) {
        if app == nil {
            launch(screen: screen)
        } else {
            relaunch(screen: screen)
        }
        XCTAssertTrue(element(identifier).waitForExistence(timeout: 4), "Missing direct screen: \(screen)")
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
