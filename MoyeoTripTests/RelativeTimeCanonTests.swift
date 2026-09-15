import Foundation
@testable import MoyeoTrip
import Testing

/// 상대 시각 정본(`docs/alignment/RELATIVE-TIME-CANON.md`)의 **13개 표본**을 그대로 고정한다.
///
/// 값이 아니라 계산 규칙이라, 한 글자만 달라도 같은 글이 플랫폼마다 다른 시각으로 보인다.
/// 웹·안드로이드도 같은 표본을 쓴다.
@Suite("상대 시각 경계 (RELATIVE-TIME-CANON)")
struct RelativeTimeCanonTests {
    /// 기준 시각. 서버가 타임존 없는 로컬 date-time 을 주므로 **기기 시간대로** 만든다 —
    /// `ServerFeedMapper.createdAtText` 가 읽는 방식과 같아야 경계가 어긋나지 않는다.
    private static let now = Date(timeIntervalSince1970: 1_789_000_000)

    private static let serverFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    /// `now` 로부터 `seconds` 만큼 **과거**인 서버 문자열. 음수면 미래다.
    private static func serverText(secondsAgo seconds: TimeInterval) -> String {
        serverFormatter.string(from: now.addingTimeInterval(-seconds))
    }

    private static func text(secondsAgo seconds: TimeInterval) -> String {
        ServerFeedMapper.createdAtText(serverText(secondsAgo: seconds), now: now)
    }

    private static let minute: TimeInterval = 60
    private static let hour: TimeInterval = 60 * 60
    private static let day: TimeInterval = 24 * 60 * 60

    @Test func justNowCoversEverythingUnderOneMinute() {
        #expect(Self.text(secondsAgo: 0) == "방금 전")
        #expect(Self.text(secondsAgo: 59) == "방금 전")
    }

    @Test func minutesRunFromOneToFiftyNine() {
        #expect(Self.text(secondsAgo: Self.minute) == "1분 전")
        #expect(Self.text(secondsAgo: 59 * Self.minute) == "59분 전")
    }

    @Test func hoursRunFromOneToTwentyThree() {
        #expect(Self.text(secondsAgo: Self.hour) == "1시간 전")
        #expect(Self.text(secondsAgo: 23 * Self.hour) == "23시간 전")
    }

    /// 24~47시간이 모두 `어제`이고 48시간부터 `2일 전`이다.
    @Test func yesterdayCoversTwentyFourToFortySevenHours() {
        #expect(Self.text(secondsAgo: 24 * Self.hour) == "어제")
        #expect(Self.text(secondsAgo: 47 * Self.hour) == "어제")
        #expect(Self.text(secondsAgo: 48 * Self.hour) == "2일 전")
    }

    /// 29일까지 `N일 전`, 30일부터 `1개월 전`. **절대 날짜(`2026.09.07`)로 떨어지지 않는다.**
    @Test func daysStopAtTwentyNineAndMonthsStartAtThirty() {
        #expect(Self.text(secondsAgo: 29 * Self.day) == "29일 전")
        #expect(Self.text(secondsAgo: 30 * Self.day) == "1개월 전")
    }

    /// 개월/년의 갈림목은 **365일**이다 — 364일은 `12개월 전`이다.
    @Test func monthsStopAtThreeHundredSixtyFourDays() {
        #expect(Self.text(secondsAgo: 364 * Self.day) == "12개월 전")
        #expect(Self.text(secondsAgo: 365 * Self.day) == "1년 전")
    }

    /// 시계 오차로 미래 시각이 와도 「-3분 전」 같은 문자열을 만들지 않는다.
    @Test func futureTimestampsFallBackToJustNow() {
        #expect(Self.text(secondsAgo: -3 * Self.minute) == "방금 전")
        #expect(Self.text(secondsAgo: -2 * Self.day) == "방금 전")
    }

    /// 버림으로 계산한다 — 90분은 `2시간 전`이 아니다.
    @Test func elapsedTimeIsFloored() {
        #expect(Self.text(secondsAgo: 90 * Self.minute) == "1시간 전")
    }

    /// 파싱 실패는 **지어내지 않는다.** 날짜 부분만 보여주거나 받은 값을 그대로 둔다.
    @Test func unparsableValuesAreNotInvented() {
        #expect(ServerFeedMapper.createdAtText("", now: Self.now).isEmpty)
        #expect(ServerFeedMapper.createdAtText("2026-09-07T오후", now: Self.now) == "2026.09.07")
    }

    /// 나노초까지 붙은 실제 응답 모양도 읽는다 (`2026-08-24T08:06:50.072025`).
    @Test func fractionalSecondsAreParsed() {
        let then = Self.serverText(secondsAgo: 2 * Self.hour) + ".072025"
        #expect(ServerFeedMapper.createdAtText(then, now: Self.now) == "2시간 전")
    }

    /// 채팅용 `listTimeText` 는 **이 규칙을 따르지 않는다** — 정본이 뺀 예외다.
    /// 글 작성 시각 자리에서 이걸 쓰면 iOS 만 `오후 3:20`·`9월 7일` 이 된다.
    @Test func chatFormatterIsNotTheRelativeTimeRule() {
        let threeDaysAgo = Self.serverText(secondsAgo: 3 * Self.day)
        #expect(ServerDateTime.listTimeText(from: threeDaysAgo) != "3일 전")
        #expect(ServerFeedMapper.createdAtText(threeDaysAgo, now: Self.now) == "3일 전")
    }
}
