//
//  RoomCourseEdit.swift
//  MoyeoTrip
//
//  18-1 여행 경로 수정이 서버로 되돌려 보내는 방문지 목록과, 보내기 전에 보는 서버 규칙.
//
//  서버 계약은 `ChatRoomService.updateRoomCourse` · `validateCustomCourseSchedule` 을 직접 읽고 옮겼다
//  (`moyeoTrip-BACKEND/src/main/kotlin/kr/hanchae/moyeotrip/service/chat/ChatRoomService.kt`).
//  안드로이드 `data/courses/RoomCourseEdit.kt` · 웹 `screens-additions.jsx` 와 같은 규칙이다.
//

import Foundation

/// 서버 `ChatRoomService.MIN_PLACES_PER_DAY` 와 같은 값이다
/// (`validateCustomCourseSchedule` 이 일차마다 이만큼을 요구한다).
private let minimumPlacesPerDay = 2

/// 같은 일차 안의 n 번째 방문지의 기본 시각 — 웹 `defaultStopTime` 과 같은 규칙이다
/// (10:00 부터 2시간 30분씩 벌리고 21:00 에서 멈춘다).
///
/// 읽기 응답의 `visitTime` 은 nullable 인데 **쓰기 요청의 `visitTime` 은 필수**다
/// (`CustomCoursePlaceRequest.visitTime: LocalTime`). 시각이 빈 방문지가 섞여 있으면
/// 순서만 바꾸려 해도 저장이 400 으로 튕기므로, 빈 자리만 이 값으로 채운다.
private func defaultStopTime(order: Int) -> String {
    let minutes = min(10 * 60 + (order - 1) * 150, 21 * 60)
    return String(format: "%02d:%02d", minutes / 60, minutes % 60)
}

/// 18-1 에서 그 일차 **맨 뒤에 새로 담는** 방문지의 시각.
///
/// 고정 시간표(`defaultStopTime`)만 쓰면 서버에서 읽어 온 기존 시각보다 이른 값이 나온다 —
/// 16:00 · 17:30 인 코스에 3번째를 담으면 15:00 이 붙어 「방문 시각이 거꾸로 가요」로 저장이
/// 막혔고, 이 화면에는 시각을 고칠 수단이 없어 **방문지 추가 자체가 불가능**했다
/// (2026-09-14 기기에서 확인). 그 일차의 마지막 시각 뒤(2시간 30분, 21:00 상한)로 붙인다.
func nextRoomCourseStopTime(afterLast lastTime: String?, order: Int) -> String {
    guard let lastTime, lastTime.count >= 5 else { return defaultStopTime(order: order) }
    let parts = lastTime.prefix(5).split(separator: ":")
    guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else {
        return defaultStopTime(order: order)
    }
    let minutes = min(hour * 60 + minute + 150, 21 * 60)
    return String(format: "%02d:%02d", minutes / 60, minutes % 60)
}

/// 18-1 이 `PATCH /travel-courses/chat-rooms/{roomId}` 로 되돌려 보낼 방문지 목록.
///
/// `sequence` 는 **그 일차 안의 순번**이다(BE `CustomCoursePlaceRequest.sequence` —
/// 「같은 일차 안의 방문 순서. 1부터 시작합니다.」). 전역 순번으로 보내면 거절당한다.
/// 화면에서 방문지를 지우거나 순서를 바꾸면 읽어 온 `order` 에 구멍이 나거나 값이 겹치는데,
/// 서버는 같은 일차 안에 겹치는 `sequence` 를 거절한다(`hasUniqueSequencesEveryDay`).
/// 그래서 보내기 직전에 **화면에 보이는 차례대로** 일차별로 다시 매긴다.
///
/// 목록의 순서가 곧 방문 순서라는 뜻이므로, 호출부는 일차·순서대로 세워 두고 부른다.
/// `contentId` 가 없는 방문지는 서버로 보낼 수 없다 — `roomCourseSaveError` 가 먼저 막는다.
func roomCoursePlaceEdits(_ stops: [ItineraryStop]) -> [ServerCoursePlaceEdit] {
    var sequenceByDay: [Int: Int] = [:]
    return stops.compactMap { stop in
        guard let placeID = stop.placeID, let contentID = Int64(placeID) else { return nil }
        let sequence = (sequenceByDay[stop.day] ?? 0) + 1
        sequenceByDay[stop.day] = sequence
        let time = String(stop.time.prefix(5))
        return ServerCoursePlaceEdit(
            contentId: contentID,
            dayNumber: stop.day,
            sequence: sequence,
            visitTime: time.isEmpty ? defaultStopTime(order: sequence) : time
        )
    }
}

/// 저장을 막는 이유를 **한국어 한 문장**으로 돌려준다. 보낼 수 있으면 nil 이다.
///
/// 서버 `validateCustomCourseSchedule` 과 **같은 것을 본다** — 1일차부터 여행 마지막 일차까지
/// 빠짐없이, 일차마다 2곳 이상. 여기에 `UpdateTravelCourseRequest.places` 의 `@Size(min = 2)` 를 더한다.
/// 그냥 보내면 서버가 `INVALID_TRAVEL_COURSE_SCHEDULE` 을 주고 화면에는 무엇이 모자란지 남지 않는다.
func roomCourseSaveError(_ stops: [ItineraryStop], tripDays: Int) -> String? {
    // 검색 결과에서 고르지 않은 방문지는 `contentId` 가 없어 서버로 보낼 수 없다
    // (17-4 코스 에디터의 `customCourseError` 와 같은 규칙).
    if let unsendable = stops.first(where: { Int64($0.placeID ?? "") == nil }) {
        return "‘\(unsendable.name)’ 은(는) 서버에 등록된 방문지가 아니라 보낼 수 없어요."
    }
    if stops.count < minimumPlacesPerDay { return "방문지는 2곳 이상이어야 해요." }
    let byDay = Dictionary(grouping: stops, by: \.day)
    for day in 1...max(tripDays, 1) {
        let count = byDay[day]?.count ?? 0
        if count < minimumPlacesPerDay {
            return "\(day)일차 방문지가 \(count)곳이에요. 일차마다 2곳 이상 남겨 주세요."
        }
    }
    if let beyond = byDay.keys.filter({ $0 > tripDays }).min() {
        return "여행은 \(tripDays)일인데 \(beyond)일차 방문지가 있어요. 모집 조건에서 일정을 늘려 주세요."
    }
    return nil
}

/// 화면에 그릴 번호. 서버 `sequence` 가 **일차별 1부터**라 통번호로 그리면
/// 「2일차 1번 장소」를 화면에서는 3번이라 불러야 한다.
///
/// 읽어 온 `order` 를 그대로 쓰지 않는 이유: 지우거나 순서를 바꾸는 중에는 값이 어긋나 있어서,
/// 지금 목록에 보이는 자리로 센다(17-4 코스 에디터·웹·안드로이드와 같은 계산).
func roomCourseDayOrder(_ stops: [ItineraryStop], at index: Int) -> Int {
    let day = stops[index].day
    return stops.prefix(index).filter { $0.day == day }.count + 1
}
