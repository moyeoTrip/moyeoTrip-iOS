import Foundation
@testable import MoyeoTrip
import Testing

@Suite("offline and birthdate contracts")
struct OfflineAndBirthdateContractTests {
    @Test func pendingMessagesPreserveCreationOrderAndCanBeRemovedAfterDelivery() {
        let suiteName = "OfflineChatQueueTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let later = OfflinePendingChatMessage(
            id: "later",
            threadID: "thread-a",
            body: "두 번째",
            createdAt: Date(timeIntervalSince1970: 2)
        )
        let earlier = OfflinePendingChatMessage(
            id: "earlier",
            threadID: "thread-a",
            body: "첫 번째",
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let otherThread = OfflinePendingChatMessage(
            id: "other",
            threadID: "thread-b",
            body: "다른 채팅방",
            createdAt: Date(timeIntervalSince1970: 0)
        )

        OfflineChatQueue.enqueue(later, defaults: defaults)
        OfflineChatQueue.enqueue(earlier, defaults: defaults)
        OfflineChatQueue.enqueue(otherThread, defaults: defaults)

        #expect(OfflineChatQueue.messages(for: "thread-a", defaults: defaults).map(\.id) == ["earlier", "later"])

        OfflineChatQueue.remove(ids: ["earlier", "later"], defaults: defaults)
        #expect(OfflineChatQueue.messages(for: "thread-a", defaults: defaults).isEmpty)
        #expect(OfflineChatQueue.messages(for: "thread-b", defaults: defaults).map(\.id) == ["other"])
    }

    @Test func duplicatePendingMessageIsQueuedOnlyOnce() {
        let suiteName = "OfflineChatQueueTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let pending = OfflinePendingChatMessage(
            id: "same-id",
            threadID: "thread-a",
            body: "한 번만 전송",
            createdAt: Date(timeIntervalSince1970: 1)
        )
        OfflineChatQueue.enqueue(pending, defaults: defaults)
        OfflineChatQueue.enqueue(pending, defaults: defaults)

        #expect(OfflineChatQueue.messages(for: "thread-a", defaults: defaults).count == 1)
    }

    @Test func koreanBirthdatePolicyHandlesLeapYearsAndClampsMonthEnd() {
        #expect(KoreanBirthdatePolicy.days(year: 2024, month: 2) == 29)
        #expect(KoreanBirthdatePolicy.days(year: 2023, month: 2) == 28)

        let clamped = KoreanBirthdatePolicy.date(year: 2023, month: 2, day: 31)
        let components = KoreanBirthdatePolicy.calendar.dateComponents([.year, .month, .day], from: clamped)
        #expect(components.year == 2023)
        #expect(components.month == 2)
        #expect(components.day == 28)
    }

    /// 예전에는 `years.first == 2026`(그 해)이었다. 미래 날짜도, 최소 연령이 안 되는 해도
    /// 고를 수 있었고 가입 마지막 단계에서 서버 `40011` 로 거절됐다 (IOS-F58·F100).
    ///
    /// 한도 연도는 `minimumSignupAge` 에서 역산한다 — 서버가 또 바뀌면(2026-09-14 BE-06: 20 → 19)
    /// 상수 하나만 고쳐도 이 경계 테스트가 새 기준을 그대로 지킨다.
    @Test func birthdateYearsStopAtTheMinimumSignupAge() {
        #expect(KoreanBirthdatePolicy.minimumSignupAge == 19)
        let reference = KoreanBirthdatePolicy.date(year: 2026, month: 8, day: 17)
        let limitYear = 2026 - KoreanBirthdatePolicy.minimumSignupAge
        #expect(limitYear == 2007)
        let years = KoreanBirthdatePolicy.years(through: reference)
        #expect(years.first == limitYear)
        #expect(years.last == 1900)
        #expect(!years.contains(2026))
        #expect(!years.contains(limitYear + 1))
    }

    /// 한도가 걸린 해에는 **월·일까지** 잘라야 한다. 연도만 막으면 2007-12-31 이
    /// 여전히 고를 수 있고, 그 사람은 2026-08-17 에 아직 만 19세가 아니다.
    @Test func birthdateMonthAndDayAreClampedInTheLimitYear() {
        let today = KoreanBirthdatePolicy.date(year: 2026, month: 8, day: 17)
        let limitYear = 2026 - KoreanBirthdatePolicy.minimumSignupAge
        #expect(KoreanBirthdatePolicy.months(year: limitYear, today: today) == Array(1...8))
        #expect(KoreanBirthdatePolicy.months(year: limitYear - 1, today: today) == Array(1...12))
        #expect(KoreanBirthdatePolicy.selectableDays(year: limitYear, month: 8, today: today) == Array(1...17))
        #expect(KoreanBirthdatePolicy.selectableDays(year: limitYear, month: 7, today: today) == Array(1...31))
    }
}
