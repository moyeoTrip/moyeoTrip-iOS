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

    @Test func birthdateYearsAreNewestFirstAndNeverIncludeFutureYears() {
        let reference = KoreanBirthdatePolicy.date(year: 2026, month: 8, day: 17)
        let years = KoreanBirthdatePolicy.years(through: reference)
        #expect(years.first == 2026)
        #expect(years.last == 1900)
    }
}
