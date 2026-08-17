import XCTest

final class Changelog01UITests: XCTestCase {
    private var app: XCUIApplication!

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testDirectLaunchDesignScreensExposePolicyControls() {
        launch("custom-course")
        XCTAssertTrue(element("screen.customCourse").waitForExistence(timeout: 4))
        XCTAssertTrue(element("customCourse.addStop").exists)

        relaunch("create-schedule")
        XCTAssertTrue(element("screen.createSchedule").waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["당일치기"].exists)
        XCTAssertTrue(element("createSchedule.meeting").exists)

        relaunch("create-meet")
        XCTAssertTrue(element("screen.createMeeting").waitForExistence(timeout: 4))
        XCTAssertTrue(element("createMeeting.map").exists)

        relaunch("create-summary")
        XCTAssertTrue(element("screen.createSummary").waitForExistence(timeout: 4))
        XCTAssertTrue(element("createSummary.source").exists)
    }

    @MainActor
    func testRouteModesAndNoticeHistoryLaunchAccessibly() {
        launch("course-edit:trip-cheongsong-juwangsan")
        XCTAssertTrue(element("screen.courseEdit.editable").waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["저장하고 멤버에게 알리기"].exists)

        relaunch("course-edit-linked:trip-cheongsong-juwangsan")
        XCTAssertTrue(element("screen.courseEdit.linkedLocked").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["등록 코스의 방문지·순서·시간은 고정돼요. 집합 정보와 모집 조건은 수정할 수 있어요."].exists)

        relaunch("course-edit-locked:trip-cheongsong-juwangsan")
        XCTAssertTrue(element("screen.courseEdit.tripConfirmed").waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["공지로 알리기"].exists)

        relaunch("notice-history:chat-cheongsong-juwangsan")
        XCTAssertTrue(element("screen.noticeHistory").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["고정 공지"].exists)
    }

    @MainActor
    func testMeetingsHasAppliedTabWithoutChatAccess() {
        launch("", tab: "meetings")
        XCTAssertTrue(app.staticTexts["신청"].waitForExistence(timeout: 4))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "신청")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["승인 전에는 채팅방에 들어갈 수 없어요."].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["채팅"].exists)
    }

    @MainActor
    func testRecruitmentCreationVisitsEveryStepInOrder() {
        launch("create")
        XCTAssertTrue(element("screen.createRecruitment.course-cheongsong-juwangsan.step1").waitForExistence(timeout: 4))

        app.buttons["이 코스로 다음"].tap()
        XCTAssertTrue(app.staticTexts["모집 만들기 (2/5)"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["일정 정하기"].exists)
        XCTAssertTrue(app.buttons["당일치기"].exists)

        app.buttons["다음"].tap()
        XCTAssertTrue(app.staticTexts["모집 만들기 (3/5)"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["인원 정하기"].exists)
        XCTAssertTrue(app.buttons["이전"].exists)

        app.buttons["다음"].tap()
        XCTAssertTrue(app.staticTexts["모집 만들기 (4/5)"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["집합 장소 정하기"].exists)
        XCTAssertTrue(element("createMeeting.map").exists)
        XCTAssertTrue(app.buttons["이전"].exists)

        app.buttons["다음"].tap()
        XCTAssertTrue(app.staticTexts["모집 만들기 (5/5)"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["이대로 모집을 열까요?"].exists)
        XCTAssertTrue(app.buttons["이전"].exists)
        XCTAssertTrue(app.buttons["모집 열기"].exists)
    }

    private func launch(_ screen: String, tab: String? = nil) {
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["UITEST_MODE", "UITEST_FAST_ANIMATIONS", "UITEST_FORCE_DARK"]
        if !screen.isEmpty { app.launchArguments.append("UITEST_SCREEN=\(screen)") }
        if let tab { app.launchArguments.append("UITEST_TAB=\(tab)") }
        app.launch()
    }

    private func relaunch(_ screen: String) {
        app.terminate()
        launch(screen)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
