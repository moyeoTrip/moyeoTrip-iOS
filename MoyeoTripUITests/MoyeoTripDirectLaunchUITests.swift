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
        launch(screen: "course-detail:course-cheongsong-juwangsan")
        XCTAssertTrue(element("course.detail.course-cheongsong-juwangsan").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["주왕산 & 주산지 힐링 트레킹"].exists)
        XCTAssertTrue(element("course.publishingSource").exists)
        app.swipeUp()
        XCTAssertTrue(element("course.route.preview").waitForExistence(timeout: 2))

        relaunch(screen: "trip-detail:trip-ulleung-island")
        XCTAssertTrue(app.staticTexts["모집 상세"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["울릉도 2박 3일 섬 여행"].exists)

        relaunch(screen: "chat:chat-cheongsong-juwangsan")
        XCTAssertTrue(app.staticTexts["주왕산 & 주산지 힐링 트레킹"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.textFields["메시지 입력"].exists)
    }

    @MainActor
    func testFeedTimelineScrollsThroughTheLastMockPost() {
        launch(arguments: ["UITEST_TAB=feed"])
        XCTAssertTrue(element("screen.feed").waitForExistence(timeout: 4))

        let endMarker = element("feed.timeline.end")
        for _ in 0..<6 where !endMarker.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(endMarker.isHittable, "피드의 마지막 항목 뒤까지 스크롤할 수 있어야 합니다.")
    }

    @MainActor
    func testFeedWriteDirectLaunchIsStableInLightMode() {
        launch(screen: "feed-write-1", arguments: ["UITEST_FORCE_LIGHT"])
        XCTAssertTrue(element("screen.feedWrite.step1").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["STEP 1 · 코스 확인"].exists)

        relaunch(screen: "feed-write-5", arguments: ["UITEST_FORCE_LIGHT"])
        XCTAssertTrue(element("screen.feedWrite.step5").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["STEP 5 · 최종 확인"].exists)
    }

    @MainActor
    func testDirectLaunchOpensSupportAndMapScreens() {
        launch(screen: "auth")
        XCTAssertTrue(app.staticTexts["고민 없이 고르는 경북 코스"].waitForExistence(timeout: 4))

        relaunch(screen: "create-recruitment:course-gyeongju-history")
        XCTAssertTrue(element("screen.createRecruitment.course-gyeongju-history.step1").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["코스 선택"].exists)

        relaunch(screen: "search")
        XCTAssertTrue(app.staticTexts["최근 검색어"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["인기 검색어"].exists)

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
        // 여행 중 위치 공유는 기획에서 빠졌다
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

    @MainActor
    func testChangeLog0607ScreensOpenWithEntrySpecificActions() {
        assertDirectScreen("place-search", identifier: "screen.placeSearch")
        assertDirectScreen("place-detail", identifier: "screen.placeDetail.CT2299341")

        relaunch(screen: "create-people")
        XCTAssertTrue(app.staticTexts["나이대 제한"].waitForExistence(timeout: 4))
        assertStaticTextContaining("25 ~ 35세")

        relaunch(screen: "terms-privacy")
        XCTAssertTrue(element("screen.terms.privacy.signup").waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["동의하고 돌아가기"].exists)

        relaunch(screen: "terms-settings")
        XCTAssertTrue(element("screen.terms.service.settings").waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["동의하고 돌아가기"].exists)
    }

    @MainActor
    func testExactCaptureContractOpensIndependentSheetAlertAndLists() {
        launch(screen: "email-auth")
        XCTAssertTrue(element("auth.email.address").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["이메일로 시작하기"].exists)

        relaunch(screen: "apply")
        XCTAssertTrue(element("screen.applicationSheet").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["함께 가기 신청"].exists)

        relaunch(screen: "chat-list")
        XCTAssertTrue(element("screen.meetings").waitForExistence(timeout: 4))
        XCTAssertTrue(element("meeting.thread.chat-cheongsong-juwangsan").exists)

        relaunch(screen: "chat-list-applied")
        XCTAssertTrue(element("meeting.applied.trip-cheongsong-juwangsan").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["승인 대기"].exists)

        relaunch(screen: "leave")
        XCTAssertTrue(app.staticTexts["호스트가 나가면\n이 모임은 종료돼요"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["모임 종료"].exists)

        relaunch(screen: "terms-marketing")
        XCTAssertTrue(element("screen.terms.marketing.signup").waitForExistence(timeout: 4))
    }

    @MainActor
    func testOfflineChatDirectCaptureIncludesDeterministicPendingMessage() {
        launch(screen: "chat:chat-cheongsong-juwangsan", arguments: ["UITEST_OFFLINE_CHAT"])
        XCTAssertTrue(element("offline.chat.banner").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["연결되면 보내주세요"].exists)
        XCTAssertTrue(app.staticTexts["전송 대기"].exists)
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

    private func relaunch(screen: String, arguments: [String]) {
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 3)
        launch(screen: screen, arguments: arguments)
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
