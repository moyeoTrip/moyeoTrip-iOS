//
//  MoyeoTripUITests.swift
//  MoyeoTripUITests
//
//  Created by 김한빈 on 5/29/26.
//

import XCTest

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
final class MoyeoTripUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    private func launch(startTab: String? = nil, extraArguments: [String] = []) {
        XCUIDevice.shared.orientation = .portrait
        let launchedApp = XCUIApplication()
        launchedApp.launchArguments = ["UITEST_MODE", "UITEST_FAST_ANIMATIONS"]
        if let startTab {
            launchedApp.launchArguments.append("UITEST_TAB=\(startTab)")
        }
        launchedApp.launchArguments.append(contentsOf: extraArguments)
        launchedApp.launch()
        app = launchedApp
    }

    private func relaunch(startTab: String) {
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 3)
        launch(startTab: startTab)
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
        if !target.exists || !target.isHittable {
            if !target.exists {
                _ = target.waitForExistence(timeout: timeout)
            }
            for _ in 0..<12 where !target.exists || !target.isHittable {
                app.swipeUp()
                _ = target.waitForExistence(timeout: 0.25)
            }
        }
        XCTAssertTrue(target.exists || target.waitForExistence(timeout: 0.5), "Missing \(identifier)", file: file, line: line)
        XCTAssertTrue(waitForHittable(target, timeout: timeout), "Element is not hittable \(identifier)", file: file, line: line)
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        if element.isHittable { return true }
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND hittable == true"),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func performTransition(
        _ name: String,
        action: () -> Void,
        destination: XCUIElement,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actionStartedAt = ProcessInfo.processInfo.systemUptime
        action()
        let actionElapsed = ProcessInfo.processInfo.systemUptime - actionStartedAt
        let existenceStartedAt = ProcessInfo.processInfo.systemUptime
        let exists = destination.exists || destination.waitForExistence(timeout: timeout)
        let existenceElapsed = ProcessInfo.processInfo.systemUptime - existenceStartedAt
        let hittableStartedAt = ProcessInfo.processInfo.systemUptime
        let hittable = exists && waitForHittable(destination, timeout: timeout)
        let hittableElapsed = ProcessInfo.processInfo.systemUptime - hittableStartedAt

        let report = String(
            format: "%@ | tap %.3fs | existence %.3fs | hittable %.3fs",
            name,
            actionElapsed,
            existenceElapsed,
            hittableElapsed
        )
        print("TRANSITION_METRIC \(report)")
        let attachment = XCTAttachment(string: report)
        attachment.name = "transition-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertTrue(exists, "Transition did not show destination: \(name)", file: file, line: line)
        XCTAssertTrue(hittable, "Transition destination is not hittable: \(name)", file: file, line: line)
    }

    private func tapButton(
        _ label: String,
        timeout: TimeInterval = 3,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let target = app.buttons[label]
        XCTAssertTrue(
            target.exists || target.waitForExistence(timeout: timeout),
            "Missing button \(label)",
            file: file,
            line: line
        )
        XCTAssertTrue(waitForHittable(target, timeout: timeout), "Button is not hittable \(label)", file: file, line: line)
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func tapButtonContaining(
        _ text: String,
        timeout: TimeInterval = 3,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let target = app.buttons.matching(predicate).firstMatch
        XCTAssertTrue(
            target.exists || target.waitForExistence(timeout: timeout),
            "Missing button containing \(text)",
            file: file,
            line: line
        )
        XCTAssertTrue(waitForHittable(target, timeout: timeout), "Button is not hittable \(text)", file: file, line: line)
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func assertStaticTextContaining(
        _ text: String,
        timeout: TimeInterval = 3,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let target = app.staticTexts.matching(predicate).firstMatch
        XCTAssertTrue(
            target.exists || target.waitForExistence(timeout: timeout),
            "Missing text containing \(text)",
            file: file,
            line: line
        )
    }

    private func assertLoginProviderContracts() {
        XCTAssertTrue(app.staticTexts["모여트립에 오신 걸 환영해요"].waitForExistence(timeout: 3))
        XCTAssertTrue(element("auth.login.welcomeImage").waitForExistence(timeout: 3))
        XCTAssertEqual(element("auth.header.label").label, "로그인")
        XCTAssertEqual(element("auth.header.step").label, "4/7")
        XCTAssertTrue(element("auth.login.email").exists)
        XCTAssertTrue(element("auth.login.google").exists)
        XCTAssertTrue(element("auth.login.apple").exists)
        let termsCopy = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "계속 진행하면")).firstMatch
        XCTAssertFalse(termsCopy.exists)
    }

    private func openNicknameSelection(extraArguments: [String] = []) {
        app.terminate()
        // 재실행하면서 인자를 덮어쓰면 호출부가 넘긴 플래그가 사라진다
        launch(extraArguments: ["UITEST_SCREEN=auth"] + extraArguments)
        tapButton("다음", timeout: 5)
        tapButton("다음")
        tapButton("로그인 시작")
        tapElement("auth.login.kakao")
        XCTAssertTrue(app.staticTexts["어떤 친구로 시작할까요?"].waitForExistence(timeout: 3))
    }

    private func completeRecruitmentFlow() {
        XCTAssertTrue(app.staticTexts["모집 만들기 (1/5)"].waitForExistence(timeout: 3))
        tapButton("이 코스로 다음")
        for step in 2...4 {
            XCTAssertTrue(app.staticTexts["모집 만들기 (\(step)/5)"].waitForExistence(timeout: 3))
            tapButton("다음")
        }
        XCTAssertTrue(app.staticTexts["모집 만들기 (5/5)"].waitForExistence(timeout: 3))
        tapButton("모집 열기")
        XCTAssertTrue(element("screen.hostManage").waitForExistence(timeout: 3))
    }

    private func bottomExploreTabExists(timeout: TimeInterval = 3) -> Bool {
        if element("tab.explore").waitForExistence(timeout: timeout) {
            return true
        }
        if app.buttons["tab.explore"].waitForExistence(timeout: timeout) {
            return true
        }
        return app.buttons["탐색"].waitForExistence(timeout: timeout)
    }

    private var bottomExploreTabIsPresent: Bool {
        element("tab.explore").exists || app.buttons["tab.explore"].exists || app.buttons["탐색"].exists
    }

    private func scrollUntilElementIsAboveBottomNavigation(
        _ element: XCUIElement,
        bottomClearance: CGFloat = 112,
        maxSwipes: Int = 6
    ) -> Bool {
        for _ in 0...maxSwipes {
            if element.exists, element.frame.maxY < app.frame.maxY - bottomClearance {
                return true
            }
            app.swipeUp()
        }
        return element.exists && element.frame.maxY < app.frame.maxY - bottomClearance
    }

    private func assertActiveTripCardLayout(id: String, file: StaticString = #filePath, line: UInt = #line) {
        let prefix = "my.activeTrip.\(id)"
        let card = element(prefix)
        let title = app.staticTexts["\(prefix).title"]
        let date = app.staticTexts["\(prefix).date"]
        let meetup = app.staticTexts["\(prefix).meetup"]
        let people = app.staticTexts["\(prefix).people"]

        XCTAssertTrue(card.exists, "Missing active card \(id)", file: file, line: line)
        XCTAssertTrue(title.exists, "Missing active title \(id)", file: file, line: line)
        XCTAssertTrue(date.exists, "Missing active date \(id)", file: file, line: line)
        XCTAssertTrue(meetup.exists, "Missing active meetup \(id)", file: file, line: line)
        XCTAssertTrue(people.exists, "Missing active people \(id)", file: file, line: line)
        XCTAssertGreaterThanOrEqual(card.frame.height, 116, file: file, line: line)
        XCTAssertLessThanOrEqual(card.frame.height, 128, file: file, line: line)
        XCTAssertLessThan(title.frame.maxY, date.frame.minY, file: file, line: line)
        XCTAssertLessThan(date.frame.maxY, meetup.frame.minY, file: file, line: line)
        XCTAssertLessThanOrEqual(people.frame.maxX, card.frame.maxX - 12, file: file, line: line)
        XCTAssertLessThanOrEqual(people.frame.maxY, card.frame.maxY - 8, file: file, line: line)
    }

    private func assertSummaryTripCardLayout(prefix: String, file: StaticString = #filePath, line: UInt = #line) {
        let card = app.descendants(matching: .any).matching(identifier: prefix).firstMatch
        let title = app.staticTexts["\(prefix).title"]
        let subtitle = app.staticTexts["\(prefix).subtitle"]
        let meta = app.staticTexts["\(prefix).meta"]
        let badge = element("\(prefix).badge")

        XCTAssertTrue(card.exists, "Missing summary card \(prefix)", file: file, line: line)
        XCTAssertTrue(title.exists, "Missing summary title \(prefix)", file: file, line: line)
        XCTAssertTrue(subtitle.exists, "Missing summary subtitle \(prefix)", file: file, line: line)
        XCTAssertTrue(meta.exists, "Missing summary meta \(prefix)", file: file, line: line)
        XCTAssertTrue(badge.exists, "Missing summary badge \(prefix)", file: file, line: line)
        XCTAssertGreaterThanOrEqual(card.frame.height, 108, file: file, line: line)
        XCTAssertLessThanOrEqual(card.frame.height, 120, file: file, line: line)
        XCTAssertLessThan(title.frame.maxY, subtitle.frame.minY, file: file, line: line)
        XCTAssertLessThan(subtitle.frame.maxY, meta.frame.minY, file: file, line: line)
        XCTAssertLessThanOrEqual(meta.frame.maxY, card.frame.maxY - 8, file: file, line: line)
        XCTAssertLessThanOrEqual(badge.frame.maxX, card.frame.maxX - 10, file: file, line: line)
    }

    @MainActor
    func testLaunchShowsHomeContent() {
        XCTAssertTrue(app.staticTexts["모여트립 in 경북"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["추천"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["home.weatherHero"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["맑음 · 경주 첨성대"].exists)
        XCTAssertTrue(app.staticTexts["지금 떠나기 좋은 코스"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["인기 코스 TOP 3"].exists)
        XCTAssertTrue(app.staticTexts["주왕산 & 주산지 힐링 트레킹"].exists)
    }

    @MainActor
    func testHomeMoreCoursesSwitchesToExploreTab() {
        tapElement("home.moreCourses", timeout: 5)

        XCTAssertTrue(element("screen.explore").waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["검색"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["주왕산 & 주산지 힐링 트레킹"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testHomeBottomRankingClearsBottomNavigationAfterScroll() {
        XCTAssertTrue(app.staticTexts["인기 코스 TOP 3"].waitForExistence(timeout: 5))

        let thirdRanking = app.staticTexts["home.ranking.3.title"]
        XCTAssertTrue(
            scrollUntilElementIsAboveBottomNavigation(thirdRanking),
            "홈 TOP3의 세 번째 항목이 하단 탭바에 가려지지 않고 스크롤 영역 안에서 보여야 합니다."
        )
    }

    @MainActor
    func testHomeSupportActionsOpenConcreteScreens() {
        XCTAssertTrue(app.staticTexts["모여트립 in 경북"].waitForExistence(timeout: 5))

        app.buttons["알림"].tap()
        XCTAssertTrue(app.staticTexts["새 댓글이 달렸어요"].waitForExistence(timeout: 3))

        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 3)
        launch()

        app.buttons["모집 만들기"].tap()
        XCTAssertTrue(app.staticTexts["코스 선택"].waitForExistence(timeout: 3))
        XCTAssertFalse(element("screen.hostManage").exists)
        completeRecruitmentFlow()
        XCTAssertTrue(app.staticTexts["모집 관리"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testNotificationFeedCommentUpdatesSharedTimeline() {
        XCTAssertTrue(app.staticTexts["모여트립 in 경북"].waitForExistence(timeout: 5))

        app.buttons["알림"].tap()
        tapButtonContaining("새 댓글이 달렸어요")
        XCTAssertTrue(app.textFields["댓글을 입력하세요..."].waitForExistence(timeout: 3))

        app.textFields["댓글을 입력하세요..."].tap()
        app.typeText("알림에서 확인했어요")
        tapElement("feed.comment.send")
        XCTAssertTrue(app.staticTexts["나: 알림에서 확인했어요"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "댓글 13")).firstMatch.exists)

        app.navigationBars.buttons.firstMatch.tap()
        tapButton("뒤로")
        tapElement("tab.feed")

        let comments = element("feed.post.feed-03.comments")
        if !comments.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(comments.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["13"].exists)
    }

    @MainActor
    func testCreatedRecruitmentAppearsInSharedScreens() {
        XCTAssertTrue(app.staticTexts["모여트립 in 경북"].waitForExistence(timeout: 5))

        app.buttons["모집 만들기"].tap()
        completeRecruitmentFlow()
        tapElement("hostManage.openChat")
        XCTAssertTrue(app.textFields["메시지 입력"].waitForExistence(timeout: 3))
        app.textFields["메시지 입력"].tap()
        app.typeText("새 모집 준비물 확인했어요")
        tapElement("chat.message.send")
        XCTAssertTrue(app.staticTexts["새 모집 준비물 확인했어요"].waitForExistence(timeout: 3))

        app.navigationBars.buttons.firstMatch.tap()
        tapButton("뒤로")

        tapElement("tab.meetings")
        assertStaticTextContaining("나: 새 모집 준비물 확인했어요")

        tapElement("tab.my")
        XCTAssertTrue(element("my.activeTrip.trip-cheongsong-juwangsan.title").waitForExistence(timeout: 3))
    }

    @MainActor
    func testTripDetailChatUpdatesMeetingPreview() {
        XCTAssertTrue(app.staticTexts["모여트립 in 경북"].waitForExistence(timeout: 5))

        app.buttons["알림"].tap()
        tapButtonContaining("출발 확정까지")
        tapButton("채팅")

        XCTAssertTrue(app.textFields["메시지 입력"].waitForExistence(timeout: 3))
        app.textFields["메시지 입력"].tap()
        app.typeText("상세에서 보낸 메시지")
        tapElement("chat.message.send")
        XCTAssertTrue(app.staticTexts["상세에서 보낸 메시지"].waitForExistence(timeout: 3))

        app.navigationBars.buttons.firstMatch.tap()
        tapButton("뒤로")
        tapButton("뒤로")
        tapElement("tab.meetings")
        assertStaticTextContaining("나: 상세에서 보낸 메시지")
    }

    @MainActor
    func testMockAuthFlowCompletesBackToHome() {
        app.terminate()
        launch(extraArguments: ["UITEST_SCREEN=auth"])
        XCTAssertTrue(element("auth.header.step").waitForExistence(timeout: 5))

        assertStaticTextContaining("고민 없이 고르는 경북 코스", timeout: 5)
        XCTAssertEqual(element("auth.header.label").label, "온보딩")
        XCTAssertEqual(element("auth.header.step").label, "1/7")
        performTransition(
            "onboarding-1-to-2",
            action: { tapButton("다음", timeout: 5) },
            destination: app.staticTexts["3명이 모이면 채팅방이 열려요"]
        )
        assertStaticTextContaining("3명이 모이면 채팅방이 열려요")
        XCTAssertEqual(element("auth.header.step").label, "2/7")
        performTransition(
            "onboarding-2-to-3",
            action: { tapButton("다음") },
            destination: app.staticTexts["여행 뒤엔 자연스럽게 친구로"]
        )
        assertStaticTextContaining("여행 뒤엔 자연스럽게 친구로")
        XCTAssertEqual(element("auth.header.step").label, "3/7")
        performTransition(
            "onboarding-to-login",
            action: { tapButton("로그인 시작") },
            destination: element("auth.login.welcomeImage")
        )

        assertLoginProviderContracts()
        performTransition(
            "login-to-nickname",
            action: { tapElement("auth.login.kakao") },
            destination: element("auth.nickname.option.deer")
        )

        XCTAssertTrue(app.staticTexts["어떤 친구로 시작할까요?"].waitForExistence(timeout: 3))
        XCTAssertEqual(element("auth.header.label").label, "프로필 설정")
        XCTAssertEqual(element("auth.header.step").label, "5/7")
        XCTAssertTrue(element("auth.nickname.option.deer").exists)
        XCTAssertTrue(app.staticTexts["함께 천천히 경북을 둘러보는 여행자예요"].exists)
        XCTAssertFalse(element("auth.nickname.continue").isEnabled)
        tapElement("auth.nickname.option.deer")
        XCTAssertTrue(element("auth.nickname.continue").isEnabled)
        performTransition(
            "nickname-to-basics",
            action: { tapElement("auth.nickname.continue") },
            destination: element("auth.basic.birthdate")
        )

        XCTAssertTrue(element("auth.basic.nickname").waitForExistence(timeout: 3))
        XCTAssertEqual(element("auth.header.step").label, "6/7")
        XCTAssertTrue(element("auth.basic.birthdate").waitForExistence(timeout: 3))
        tapElement("auth.basic.gender.female")
        performTransition(
            "basics-to-profile-image",
            action: { tapElement("auth.basic.continue") },
            destination: element("auth.profile.generate")
        )

        XCTAssertTrue(app.staticTexts["여행에서 만날 내 친구를 골라주세요"].waitForExistence(timeout: 3))
        XCTAssertEqual(element("auth.header.step").label, "7/7")
        XCTAssertFalse(app.staticTexts["약관 동의"].exists)
        tapElement("auth.profile.generate")
        let generatingCard = element("auth.profile.generating")
        XCTAssertTrue(generatingCard.waitForExistence(timeout: 2))
        XCTAssertTrue(generatingCard.label.contains("프로필 이미지 생성 중"))
        let profileOption = element("auth.profile.option.1")
        XCTAssertTrue(profileOption.waitForExistence(timeout: 3))
        tapElement("auth.profile.option.1")
        XCTAssertFalse(app.staticTexts["모여트립 in 경북"].exists)
        XCTAssertTrue(element("auth.profile.confirm").isEnabled)
        performTransition(
            "profile-image-to-home",
            action: { tapElement("auth.profile.confirm") },
            destination: element("tab.home")
        )

        XCTAssertTrue(app.staticTexts["모여트립 in 경북"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testNicknameRefreshReplacesCandidatesAndClearsSelection() {
        openNicknameSelection()

        tapElement("auth.nickname.option.deer")
        XCTAssertTrue(element("auth.nickname.continue").isEnabled)

        tapElement("auth.nickname.refresh")
        XCTAssertFalse(element("auth.nickname.continue").isEnabled)
        let refreshedCandidate = element("auth.nickname.option.batch-2-0")
        XCTAssertTrue(refreshedCandidate.waitForExistence(timeout: 3))
        XCTAssertFalse(element("auth.nickname.option.deer").exists)
        XCTAssertFalse(element("auth.nickname.continue").isEnabled)
        XCTAssertTrue(app.staticTexts["마음에 들 때까지 새 후보를 받아보세요"].exists)
    }

    @MainActor
    func testNicknameRefreshFailureKeepsCandidatesAndSelection() {
        openNicknameSelection(extraArguments: ["UITEST_NICKNAME_REFRESH_FAIL"])

        tapElement("auth.nickname.option.deer")
        XCTAssertTrue(element("auth.nickname.continue").isEnabled)

        tapElement("auth.nickname.refresh")
        let errorText = element("auth.nickname.refresh.error")
        XCTAssertTrue(errorText.waitForExistence(timeout: 4))
        XCTAssertEqual(errorText.label, "새 이름을 불러오지 못했어요. 다시 시도해주세요.")
        XCTAssertTrue(element("auth.nickname.option.deer").exists)
        XCTAssertEqual(element("auth.nickname.option.deer").value as? String, "선택됨")
        XCTAssertTrue(element("auth.nickname.continue").isEnabled)
        XCTAssertFalse(element("auth.nickname.refresh.remaining").exists)
        XCTAssertFalse(element("auth.nickname.refresh.limit").exists)
    }

    @MainActor
    func testAuthProviderButtonsRemainUsableInDarkMode() {
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 3)
        launch(extraArguments: ["UITEST_FORCE_DARK", "UITEST_SCREEN=auth", "UITEST_AUTH_PROVIDER_LIST"])

        let kakao = element("auth.login.kakao")
        let google = element("auth.login.google")
        let email = element("auth.login.email")
        let apple = element("auth.login.apple")
        XCTAssertTrue(kakao.waitForExistence(timeout: 3))
        XCTAssertTrue(email.waitForExistence(timeout: 3))
        XCTAssertTrue(google.waitForExistence(timeout: 3))
        XCTAssertTrue(apple.waitForExistence(timeout: 3))
        XCTAssertTrue(kakao.isHittable)
        XCTAssertTrue(email.isHittable)
        XCTAssertTrue(google.isHittable)
        XCTAssertTrue(apple.isHittable)
        assertProviderButtonLayout([kakao, google, email, apple])
    }

    @MainActor
    func testAuthProviderBrandOrderAndSizingInLightMode() {
        app.terminate()
        launch(extraArguments: ["UITEST_SCREEN=auth", "UITEST_AUTH_PROVIDER_LIST"])

        let providers = [
            element("auth.login.kakao"),
            element("auth.login.google"),
            element("auth.login.email"),
            element("auth.login.apple")
        ]
        for provider in providers {
            XCTAssertTrue(provider.waitForExistence(timeout: 3))
        }
        assertProviderButtonLayout(providers)
    }

    @MainActor
    func testProfileRequiredUserResumesAtImageStep() {
        app.terminate()
        launch(extraArguments: ["UITEST_AUTH_PROFILE_REQUIRED", "UITEST_SCREEN=auth"])

        tapButton("다음", timeout: 5)
        tapButton("다음")
        tapButton("로그인 시작")
        tapElement("auth.login.apple")

        XCTAssertTrue(app.staticTexts["여행에서 만날 내 친구를 골라주세요"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["어떤 친구로 시작할까요?"].exists)
        XCTAssertFalse(element("auth.basic.birthdate").exists)
    }

    @MainActor
    func testExistingCompleteUserFinishesImmediatelyAfterLogin() {
        app.terminate()
        launch(extraArguments: ["UITEST_AUTH_EXISTING_USER", "UITEST_SCREEN=auth", "UITEST_AUTH_PROVIDER_LIST"])
        tapElement("auth.login.email")
        XCTAssertTrue(app.staticTexts["이메일로 시작하기"].waitForExistence(timeout: 3))
        let emailField = element("auth.email.address")
        emailField.tap()
        emailField.typeText("moyeo@example.com")
        let passwordField = element("auth.email.password")
        passwordField.tap()
        passwordField.typeText("password")
        tapElement("auth.email.submit")

        XCTAssertTrue(app.staticTexts["모여트립 in 경북"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["여행 친구를 만들어볼까요?"].exists)
    }

    @MainActor
    func testEmailRegistrationAndPasswordResetScreens() {
        app.terminate()
        launch(extraArguments: ["UITEST_SCREEN=auth", "UITEST_AUTH_PROVIDER_LIST"])
        tapElement("auth.login.email")

        XCTAssertTrue(app.staticTexts["이메일로 시작하기"].waitForExistence(timeout: 3))
        tapElement("auth.email.mode.create")
        XCTAssertTrue(element("auth.email.passwordConfirmation").waitForExistence(timeout: 3))
        XCTAssertTrue(element("auth.email.passwordConfirmation").exists)
        // SecureField 는 한 글자마다 포커스를 잃어 비밀번호 조합을 UI 테스트로 재현할 수 없다.
        // 불일치 경고 규칙은 EmailCredentialsPolicy 단위 테스트에서 검증하고,
        // 여기서는 가입 모드의 화면 구성과 제출 비활성만 확인한다.
        XCTAssertFalse(element("auth.email.submit").isEnabled)
        let email = element("auth.email.address")
        email.tap()
        email.typeText("moyeo@example.com")
        XCTAssertFalse(element("auth.email.submit").isEnabled)
        tapElement("auth.back")

        tapElement("auth.email.forgotPassword")
        XCTAssertTrue(app.staticTexts["비밀번호 재설정"].waitForExistence(timeout: 3))
        let resetEmail = element("auth.reset.email")
        XCTAssertTrue(resetEmail.waitForExistence(timeout: 3))
        XCTAssertEqual(resetEmail.value as? String, "moyeo@example.com")
        tapElement("auth.reset.submit")
        XCTAssertTrue(element("auth.reset.success").waitForExistence(timeout: 3))
    }

    private func assertProviderButtonLayout(
        _ providers: [XCUIElement],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let first = providers.first else {
            XCTFail("Provider buttons are missing", file: file, line: line)
            return
        }
        for provider in providers {
            XCTAssertEqual(provider.frame.height, 54, accuracy: 1, file: file, line: line)
            XCTAssertEqual(provider.frame.width, first.frame.width, accuracy: 1, file: file, line: line)
        }
        for pair in zip(providers, providers.dropFirst()) {
            XCTAssertLessThan(pair.0.frame.maxY, pair.1.frame.minY, file: file, line: line)
        }
    }

    @MainActor
    func testBottomTabsShowPrimaryScreens() {
        XCTAssertTrue(app.descendants(matching: .any)["screen.home"].waitForExistence(timeout: 3))

        relaunch(startTab: "meetings")
        XCTAssertTrue(app.descendants(matching: .any)["screen.meetings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["진행중"].exists)
        XCTAssertTrue(app.staticTexts["확정"].exists)
        XCTAssertTrue(app.staticTexts["종료"].exists)
        XCTAssertTrue(app.staticTexts["4/8명 · 마감 D-3"].exists)

        relaunch(startTab: "feed")
        XCTAssertTrue(app.descendants(matching: .any)["screen.feed"].waitForExistence(timeout: 3))
        let firstPost = app.buttons["feed.post.feed-01"]
        if !firstPost.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(firstPost.waitForExistence(timeout: 3))
    }

    @MainActor
    func testMyScreenShowsTrips() {
        relaunch(startTab: "my")
        XCTAssertTrue(app.staticTexts["마이"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("my.profileSummary").exists)
        XCTAssertTrue(app.staticTexts["혼자 떠나도 같이 웃을 수 있는 작은 여행을 좋아해요."].exists)
        XCTAssertTrue(app.staticTexts["매너"].exists)
        XCTAssertTrue(app.staticTexts["내 여행"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["진행중"].exists)
        XCTAssertTrue(app.buttons["지난여행"].exists)
        XCTAssertTrue(app.buttons["찜한 코스"].exists)
        XCTAssertTrue(element("my.activeTrip.trip-cheongsong-juwangsan.title").exists)
        XCTAssertTrue(app.staticTexts["청송 시외버스터미널"].exists)
        XCTAssertTrue(app.staticTexts["2/5명"].exists)
        XCTAssertFalse(app.staticTexts["지난 여행"].exists)
        assertActiveTripCardLayout(id: "trip-cheongsong-juwangsan")

        app.buttons["지난여행"].tap()
        XCTAssertTrue(app.staticTexts["월정교 야경과 첨성대 단풍길을 함께 걸었어요."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["2024.04.12 (금) · 여행 기록"].exists)
        assertSummaryTripCardLayout(prefix: "my.pastTrip.course-gyeongju-history")
        let pastCard = app.descendants(matching: .any)
            .matching(identifier: "my.pastTrip.course-gyeongju-history").firstMatch
        for _ in 0..<6 where !pastCard.isHittable {
            app.swipeUp()
        }
        pastCard.tap()
        XCTAssertTrue(element("course.detail.course-gyeongju-history").waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["경주 감성 힐링 코스"].exists)

        relaunch(startTab: "my")
        XCTAssertTrue(app.staticTexts["내 여행"].waitForExistence(timeout: 3))
        app.buttons["찜한 코스"].tap()
        XCTAssertTrue(app.staticTexts["울릉도 2박 3일 섬 여행"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["바다 전망과 짧은 트레킹, 섬마을 산책을 묶은 여유로운 일정이에요."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["2박 3일 · 12.4km"].exists)
        assertSummaryTripCardLayout(prefix: "my.savedCourse.course-ulleung-island")
    }

    @MainActor
    func testMyHubMenuRowsOpenConcreteDestinations() {
        relaunch(startTab: "my")
        let feedShortcut = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "내 피드")).firstMatch
        let scrollView = app.scrollViews.firstMatch
        for _ in 0..<10 where !feedShortcut.isHittable {
            scrollView.swipeUp()
        }
        XCTAssertTrue(feedShortcut.isHittable)
        feedShortcut.tap()
        XCTAssertTrue(element("screen.myFeed").waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["내가 남긴 경북 여행 기록"].waitForExistence(timeout: 3))
        tapElement("my.feedPost.feed-01")
        XCTAssertTrue(app.textFields["댓글을 입력하세요..."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["좋아요 128개"].exists)

        relaunch(startTab: "my")
        let customerCenter = element("my.customerCenterShortcut")
        let myScrollView = app.scrollViews.firstMatch
        let safeTapMaxY = app.frame.maxY - 170
        for _ in 0..<12 where !customerCenter.isHittable || customerCenter.frame.midY > safeTapMaxY {
            myScrollView.swipeUp()
        }
        XCTAssertTrue(customerCenter.waitForExistence(timeout: 3))
        XCTAssertTrue(customerCenter.isHittable)
        XCTAssertLessThan(customerCenter.frame.midY, safeTapMaxY)
        customerCenter.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(element("screen.customerCenter").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["문의 접수"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["자주 묻는 질문"].exists)
    }

    @MainActor
    func testProfileMenuEditAndDogamPreviewOpenDedicatedScreens() {
        relaunch(startTab: "my")
        tapElement("my.profileSummary")
        XCTAssertTrue(element("screen.profile").waitForExistence(timeout: 3))

        tapElement("profile.menu.edit")
        XCTAssertTrue(element("screen.profileEdit").waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["닉네임"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["관심 지역"].exists)
        tapButton("저장")
        XCTAssertTrue(app.alerts["저장 완료"].waitForExistence(timeout: 3))
        app.alerts["저장 완료"].buttons["확인"].tap()

        relaunch(startTab: "my")
        tapElement("my.profileSummary")
        XCTAssertTrue(element("screen.profile").waitForExistence(timeout: 3))
        // 프로필 메뉴는 내 정보 수정 · 친구 관리 · 차단한 사용자 세 줄이다
        tapElement("profile.menu.friends")
        XCTAssertTrue(element("screen.friends").waitForExistence(timeout: 3))
        XCTAssertTrue(element("friends.dexNotice").exists)
    }

    @MainActor
    func testFriendDexSearchAndFiltersUpdateResults() {
        relaunch(startTab: "my")

        let friendDexShortcut = element("my.friendDexShortcut")
        let scrollView = app.scrollViews.firstMatch
        for _ in 0..<10 where !friendDexShortcut.isHittable {
            scrollView.swipeUp()
        }
        XCTAssertTrue(friendDexShortcut.isHittable)
        friendDexShortcut.tap()

        XCTAssertTrue(element("screen.friendDex").waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["12"].waitForExistence(timeout: 3))

        tapElement("friendDex.filter.2회 이상 4")
        XCTAssertTrue(app.staticTexts["4"].waitForExistence(timeout: 3))

        tapElement("friendDex.filter.전체 12")
        tapButton("검색")
        let searchField = app.textFields["친구 이름 검색"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.tap()
        searchField.typeText("1130")

        XCTAssertTrue(app.staticTexts["1"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["고요한 두루미 1130"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["따스한 사슴 3492"].exists)
    }

    @MainActor
    func testSettingsRowsOpenMockDetailDialogs() {
        relaunch(startTab: "my")
        tapButton("설정", timeout: 5)

        tapElement("settings.action.theme")
        XCTAssertTrue(app.staticTexts["테마 설정"].waitForExistence(timeout: 3))
        tapButton("닫기")

        let logoutAction = element("settings.action.logout")
        for _ in 0..<5 where !logoutAction.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(logoutAction.waitForExistence(timeout: 3))
        XCTAssertTrue(logoutAction.isHittable)
        logoutAction.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["로그아웃 안내"].waitForExistence(timeout: 3))
        tapButton("취소")
    }

    @MainActor
    func testProviderManagementUsesStableOrderAndRevealsNewEmailFormOnDemand() {
        relaunch(startTab: "my")
        tapButton("설정", timeout: 5)
        tapElement("settings.action.loginMethod")

        let providerNames = ["카카오", "Google", "이메일", "Apple"]
        let providers = providerNames.map { app.staticTexts[$0].firstMatch }
        providers.forEach {
            XCTAssertTrue($0.waitForExistence(timeout: 3))
        }
        for pair in zip(providers, providers.dropFirst()) {
            XCTAssertLessThan(pair.0.frame.minY, pair.1.frame.minY)
        }

        XCTAssertFalse(element("providers.email.email").exists)
        XCTAssertFalse(element("providers.email.password").exists)
        tapElement("providers.email.link")
        XCTAssertTrue(element("providers.email.email").waitForExistence(timeout: 3))
        XCTAssertTrue(element("providers.email.password").waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["기존 이메일"].exists)
    }

    @MainActor
    func testUnauthenticatedLaunchShowsRequiredAuthFlow() {
        app.terminate()
        launch(extraArguments: ["UITEST_REQUIRE_AUTH"])

        XCTAssertTrue(app.staticTexts["고민 없이 고르는 경북 코스"].waitForExistence(timeout: 5))
        XCTAssertFalse(element("auth.back").exists)
        XCTAssertFalse(element("auth.close").exists)
        XCTAssertFalse(element("screen.home").exists)
    }

    @MainActor
    func testCourseDetailNavigationFromHome() {
        XCTAssertTrue(app.staticTexts["지금 떠나기 좋은 코스"].waitForExistence(timeout: 5))

        let firstCourse = app.buttons["course.card.course-cheongsong-juwangsan"]
        if firstCourse.waitForExistence(timeout: 3) {
            firstCourse.tap()
        } else {
            app.staticTexts["주왕산 & 주산지 힐링 트레킹"].tap()
        }

        XCTAssertTrue(element("course.detail.course-cheongsong-juwangsan").waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["코스 미리보기"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["주산지"].exists)
        XCTAssertTrue(app.buttons["이 코스로 모집 만들기"].exists)
    }

    @MainActor
    func testExploreOpensCourseDetailBeforeRecruitmentDetail() {
        relaunch(startTab: "explore")
        XCTAssertTrue(app.staticTexts["탐색"].waitForExistence(timeout: 3))

        app.staticTexts["경주 감성 힐링 코스"].tap()

        XCTAssertTrue(element("course.detail.course-gyeongju-history").waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["모집 중인 모임 보기"].exists)
    }

    @MainActor
    func testExploreFavoriteButtonsToggleWithoutOpeningDetail() {
        relaunch(startTab: "explore")
        XCTAssertTrue(app.staticTexts["탐색"].waitForExistence(timeout: 3))

        let listFavorite = element("explore.favorite.course-andong-hahoe")
        XCTAssertTrue(listFavorite.waitForExistence(timeout: 3))
        XCTAssertEqual(listFavorite.label, "찜")
        listFavorite.tap()
        XCTAssertTrue(element("screen.explore").waitForExistence(timeout: 1))
        XCTAssertFalse(app.staticTexts["코스 상세"].exists)
        XCTAssertEqual(element("explore.favorite.course-andong-hahoe").label, "찜 해제")
        element("explore.favorite.course-andong-hahoe").tap()
        XCTAssertEqual(element("explore.favorite.course-andong-hahoe").label, "찜")

        app.buttons["지도 탐색"].tap()
        XCTAssertTrue(app.staticTexts["지도 탐색"].waitForExistence(timeout: 3))
        let mapFavorite = app.buttons["찜 해제"].firstMatch
        XCTAssertTrue(mapFavorite.waitForExistence(timeout: 3))
        mapFavorite.tap()
        XCTAssertTrue(app.staticTexts["지도 탐색"].exists)
        XCTAssertFalse(app.staticTexts["코스 상세"].exists)
        XCTAssertTrue(app.buttons["찜"].firstMatch.waitForExistence(timeout: 3))

        tapButtonContaining("주왕산")
        XCTAssertTrue(app.staticTexts["코스 상세"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testApplicationCompletionOpensChatRoom() {
        XCTAssertTrue(app.staticTexts["지금 떠나기 좋은 코스"].waitForExistence(timeout: 5))
        tapElement("course.card.course-cheongsong-juwangsan", timeout: 5)
        XCTAssertTrue(element("course.detail.course-cheongsong-juwangsan").waitForExistence(timeout: 3))
        tapButton("모집 중인 모임 보기")

        XCTAssertTrue(app.buttons["trip.detail.apply"].waitForExistence(timeout: 3))
        app.buttons["trip.detail.apply"].tap()
        XCTAssertTrue(app.staticTexts["함께 가기 신청"].waitForExistence(timeout: 3))
        app.buttons["application.sheet.submit"].tap()
        XCTAssertTrue(app.staticTexts["모집에 참여됐어요"].waitForExistence(timeout: 3))
        app.buttons["application.sheet.openChat"].tap()

        XCTAssertTrue(app.staticTexts["모임 신청 후 대화가 이어져요"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testAppliedTripActionsHaveMatchingSizes() {
        relaunch(startTab: "meetings")
        let appliedSegmentByID = element("meetings.segment.신청")
        let appliedSegment = appliedSegmentByID.waitForExistence(timeout: 1)
            ? appliedSegmentByID
            : app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "신청")).firstMatch
        XCTAssertTrue(appliedSegment.waitForExistence(timeout: 3))
        appliedSegment.tap()

        let detail = app.buttons["모집 상세"].firstMatch
        let cancel = app.buttons["신청 취소"].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 3))
        XCTAssertTrue(cancel.waitForExistence(timeout: 3))
        XCTAssertEqual(detail.frame.width, cancel.frame.width, accuracy: 1)
        XCTAssertEqual(detail.frame.height, cancel.frame.height, accuracy: 1)
    }

    @MainActor
    func testFeedTimelineStaysAtTopAfterInitialLoad() {
        relaunch(startTab: "feed")
        XCTAssertTrue(app.descendants(matching: .any)["screen.feed"].waitForExistence(timeout: 3))

        let firstPost = app.buttons["feed.post.feed-01"]
        XCTAssertTrue(firstPost.waitForExistence(timeout: 3))
        let initialY = firstPost.frame.minY

        RunLoop.current.run(until: Date().addingTimeInterval(1.2))
        XCTAssertTrue(firstPost.exists)
        XCTAssertLessThan(
            abs(firstPost.frame.minY - initialY),
            4,
            "피드 진입 직후 QA 스크롤이나 anchor 변경으로 첫 카드 위치가 튀지 않아야 합니다."
        )
    }

    @MainActor
    func testFeedCardOpensDetailWithCommentInput() {
        relaunch(startTab: "feed")
        XCTAssertTrue(app.descendants(matching: .any)["screen.feed"].waitForExistence(timeout: 3))
        let firstPost = app.buttons["feed.post.feed-01"]
        if firstPost.waitForExistence(timeout: 2) {
            firstPost.tap()
        } else {
            app.staticTexts["주왕산 & 주산지 힐링 트레킹"].tap()
        }

        tapElement("feed.detail.more")
        XCTAssertTrue(element("screen.report").waitForExistence(timeout: 3))
        app.navigationBars.buttons.firstMatch.tap()

        XCTAssertTrue(app.textFields["댓글을 입력하세요..."].exists)
        let sendButton = element("feed.comment.send")
        XCTAssertTrue(sendButton.exists)
        XCTAssertGreaterThanOrEqual(sendButton.frame.width, 44)
        XCTAssertGreaterThanOrEqual(sendButton.frame.height, 44)
        app.textFields["댓글을 입력하세요..."].tap()
        app.typeText("다음에 저도 가보고 싶어요")
        tapElement("feed.comment.send")
        XCTAssertTrue(app.staticTexts["나: 다음에 저도 가보고 싶어요"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "댓글 19")).firstMatch.exists)

        let distanceMetric = app.staticTexts["이동 거리"]
        if !distanceMetric.waitForExistence(timeout: 1) {
            app.swipeUp()
        }
        XCTAssertTrue(distanceMetric.waitForExistence(timeout: 3))

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(element("screen.feed").waitForExistence(timeout: 3))
        XCTAssertTrue(element("feed.post.feed-01.comments").waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["19"].exists)
    }

    @MainActor
    func testChatMessageUpdatesMeetingPreview() {
        relaunch(startTab: "meetings")
        XCTAssertTrue(app.descendants(matching: .any)["screen.meetings"].waitForExistence(timeout: 3))
        tapElement("meeting.thread.chat-gyeongju-night")

        XCTAssertTrue(app.textFields["메시지 입력"].waitForExistence(timeout: 3))
        app.textFields["메시지 입력"].tap()
        app.typeText("날씨 확인하고 갈게요")
        tapElement("chat.message.send")
        XCTAssertTrue(app.staticTexts["날씨 확인하고 갈게요"].waitForExistence(timeout: 3))

        app.navigationBars.buttons.firstMatch.tap()
        assertStaticTextContaining("나: 날씨 확인하고 갈게요")
    }

    @MainActor
    func testFeedWritePublishesPostIntoTimeline() {
        relaunch(startTab: "feed")
        XCTAssertTrue(app.descendants(matching: .any)["screen.feed"].waitForExistence(timeout: 3))

        let writeButton = app.buttons["feed.write.open"].firstMatch
        if !writeButton.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(writeButton.waitForExistence(timeout: 3))
        writeButton.tap()

        XCTAssertTrue(app.staticTexts["피드 글쓰기"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["STEP 1 · 코스 확인"].waitForExistence(timeout: 3))
        tapElement("feed.write.course.course-andong-hahoe")
        XCTAssertTrue(app.staticTexts["안동 하회마을 하루 코스"].waitForExistence(timeout: 3))
        for _ in 0..<3 {
            tapElement("feed.write.next")
        }
        tapElement("feed.write.visibility.public")
        assertStaticTextContaining("발견 탭에서도 보이고")
        tapElement("feed.write.next")
        XCTAssertTrue(app.staticTexts["전체공개"].waitForExistence(timeout: 3))
        tapElement("feed.write.complete")

        let newPostTitle = app.staticTexts["첫 반패키지 단풍 여행"]
        XCTAssertTrue(newPostTitle.waitForExistence(timeout: 3))
        XCTAssertTrue(element("feed.detail.visibility").waitForExistence(timeout: 3))
        assertStaticTextContaining("#여행기록")
        assertStaticTextContaining("#전체공개")
        XCTAssertTrue(app.textFields["댓글을 입력하세요..."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["처음 반패키지 여행이었는데 동행분들이 너무 좋으셨어요.\n첨성대 야경이 진짜 인생샷..."].waitForExistence(timeout: 3))
    }

    @MainActor
    func testExploreMapFlowMatchesPlanning() {
        relaunch(startTab: "explore")
        XCTAssertTrue(app.staticTexts["탐색"].waitForExistence(timeout: 3))
        app.buttons["검색"].tap()
        XCTAssertTrue(app.staticTexts["최근 검색어"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["인기 검색어"].exists)
        app.buttons["뒤로"].tap()
        XCTAssertTrue(app.staticTexts["탐색"].waitForExistence(timeout: 3))

        app.buttons["지도 탐색"].tap()

        XCTAssertTrue(app.staticTexts["지도 탐색"].waitForExistence(timeout: 3))
        XCTAssertTrue(bottomExploreTabExists())
        let selectedMapCourse = element("explore.map.selectedCourse")
        if selectedMapCourse.waitForExistence(timeout: 2) {
            selectedMapCourse.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        } else {
            tapButtonContaining("주왕산")
        }
        XCTAssertTrue(app.staticTexts["코스 상세"].waitForExistence(timeout: 3))
        XCTAssertFalse(bottomExploreTabIsPresent)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["지도 탐색"].waitForExistence(timeout: 3))
        XCTAssertTrue(bottomExploreTabExists())
        let mapListButton = element("explore.map.list")
        if mapListButton.waitForExistence(timeout: 2) {
            mapListButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        } else {
            app.buttons["목록 탐색"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(app.buttons["지도 탐색"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
