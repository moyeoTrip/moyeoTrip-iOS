//
//  MoyeoTripTripApplicationUITests.swift
//  MoyeoTripUITests
//

import XCTest

final class MoyeoTripTripApplicationUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        launch(startTab: "my")
    }

    override func tearDownWithError() throws {
        app = nil
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
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "Missing \(identifier)", file: file, line: line)
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func tapButton(
        _ label: String,
        timeout: TimeInterval = 3,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let target = app.buttons[label]
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "Missing button \(label)", file: file, line: line)
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
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "Missing button containing \(text)", file: file, line: line)
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
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "Missing text containing \(text)", file: file, line: line)
    }

    @MainActor
    func testUlleungTripApplicationOpensUlleungChatThread() {
        XCTAssertTrue(app.staticTexts["내 여행"].waitForExistence(timeout: 3))
        app.buttons["찜한 코스"].tap()
        tapElement("my.savedCourse.course-ulleung-island", timeout: 5)

        XCTAssertTrue(element("course.detail.course-ulleung-island").waitForExistence(timeout: 3))
        tapButton("모집 중인 모임 보기")

        XCTAssertTrue(app.staticTexts["울릉도 2박 3일 섬 여행"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["trip.detail.apply"].waitForExistence(timeout: 3))
        app.buttons["trip.detail.apply"].tap()
        XCTAssertTrue(app.staticTexts["함께 가기 신청"].waitForExistence(timeout: 3))
        app.buttons["application.sheet.submit"].tap()
        XCTAssertTrue(app.staticTexts["모집에 참여됐어요"].waitForExistence(timeout: 3))
        app.buttons["application.sheet.openChat"].tap()

        XCTAssertTrue(app.staticTexts["울릉도 2박 3일 섬 여행"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["배편 시간 다시 확인했어요. 멀미약도 챙기면 좋아요."].waitForExistence(timeout: 3))
    }

    @MainActor
    func testEndedMeetingChatShowsArchivePolicyAndBlocksInput() {
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 3)
        launch(startTab: "meetings")

        XCTAssertTrue(element("screen.meetings").waitForExistence(timeout: 3))
        tapButtonContaining("종료")
        tapButtonContaining("안동 봄날")

        assertStaticTextContaining("여행이 종료됐어요")
        assertStaticTextContaining("보관 D-14")
        assertStaticTextContaining("채팅은 14일 동안 읽기 전용으로 보관되고 이후 친구 도감 기록만 남아요.")
        assertStaticTextContaining("종료된 모임이라 새 메시지를 보낼 수 없어요.")
        XCTAssertFalse(app.textFields["메시지 입력"].waitForExistence(timeout: 1))
    }
}
