@testable import MoyeoTrip
import Testing

@Suite("changeLog01 domain policies")
struct Changelog01PolicyTests {
    @Test func routeEditMatrixMatchesCourseSourceAndConfirmation() {
        #expect(RoutePolicy.editState(source: .custom, isTripConfirmed: false) == .editable)
        #expect(RoutePolicy.editState(source: .linked, isTripConfirmed: false) == .linkedLocked)
        #expect(RoutePolicy.editState(source: .custom, isTripConfirmed: true) == .tripConfirmed)
        #expect(RoutePolicy.editState(source: .linked, isTripConfirmed: true) == .tripConfirmed)
    }

    @Test func customRouteRequiresTwoThroughTwentyStops() {
        let one = (0..<1).map(makeStop)
        let two = (0..<2).map(makeStop)
        let twenty = (0..<20).map(makeStop)
        let twentyOne = (0..<21).map(makeStop)

        #expect(!RoutePolicy.canSave(stops: one, state: .editable))
        #expect(RoutePolicy.canSave(stops: two, state: .editable))
        #expect(RoutePolicy.canSave(stops: twenty, state: .editable))
        #expect(!RoutePolicy.canSave(stops: twentyOne, state: .editable))
        #expect(!RoutePolicy.canSave(stops: two, state: .linkedLocked))
        #expect(!RoutePolicy.canSave(stops: two, state: .tripConfirmed))
    }

    @Test func normalizationRebuildsStableStopOrder() {
        let reversed: [ItineraryStop] = (0..<3).map(makeStop).reversed()
        let normalized = RoutePolicy.normalized(reversed)
        #expect(normalized.map(\.order) == [1, 2, 3])
        #expect(normalized.first?.name == "방문지 2")
    }

    @Test func scheduleRequiresModeSpecificFields() {
        let completeDay = TripScheduleDetails(
            kind: .dayTrip,
            startDate: "2026-05-25",
            startTime: "08:00",
            endTime: "18:00"
        )
        let incompleteDay = TripScheduleDetails(kind: .dayTrip, startDate: "2026-05-25")
        let completeOvernight = TripScheduleDetails(
            kind: .overnight,
            startDate: "2026-05-25",
            endDate: "2026-05-26"
        )

        #expect(RecruitmentSchedulePolicy.isComplete(completeDay))
        #expect(!RecruitmentSchedulePolicy.isComplete(incompleteDay))
        #expect(RecruitmentSchedulePolicy.isComplete(completeOvernight))
    }

    /// 상단 고정은 하나뿐이다 (정본 ATTACH-COMPOSER-CANON.md R5-1).
    @Test func pinnedNoticesAreCappedAtOne() {
        let notices = (0..<5).map { index in
            TripNotice(id: "notice-\(index)", body: "공지 \(index)", createdAt: "지금", isPinned: true)
        }
        #expect(RoutePolicy.pinnedNotices(from: notices).count == 1)
    }

    @Test func nicknameLimitIsTenCharacters() {
        #expect(NicknamePolicy.isValid("따스한사슴3492"))
        #expect(!NicknamePolicy.isValid("호기심많은너구리9027"))
    }

    private func makeStop(_ index: Int) -> ItineraryStop {
        ItineraryStop(
            id: "stop-\(index)",
            day: 1,
            order: index + 1,
            time: "09:00",
            name: "방문지 \(index)",
            memo: ""
        )
    }
}
