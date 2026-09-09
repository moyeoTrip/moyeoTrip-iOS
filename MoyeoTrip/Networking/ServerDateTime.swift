//
//  ServerDateTime.swift
//  MoyeoTrip
//
//  서버 날짜·시각 문자열 파싱과 표기.
//
//  `ChatRoomContentAPIClient.swift` 가 500줄 제한에 걸려 여기로 나눴다 —
//  날짜 파싱은 그 파일의 관심사가 아니고 다른 곳에서도 쓴다.
//

import Foundation

/// 서버는 나노초까지 붙은 로컬 date-time을 준다 ("2026-08-24T08:06:50.072025").
enum ServerDateTime {
    static func date(from value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = formatter.date(from: value) { return date }
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return formatter.date(from: value)
    }

    /// `startDate`·`endDate` 처럼 **날짜만** 오는 값(`2026-08-28`).
    static func date(fromDateOnly value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    /// 채팅 목록의 갱신 시각 — 오늘은 시각만, 어제는 "어제", 그 밖은 날짜
    static func listTimeText(from value: String) -> String {
        guard let date = date(from: value) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "a h:mm"
        } else if Calendar.current.isDateInYesterday(date) {
            return "어제"
        } else {
            formatter.dateFormat = "M월 d일"
        }
        return formatter.string(from: date)
    }

    /// 말풍선 시각 — "오후 1:30"
    static func bubbleTimeText(from value: String) -> String {
        guard let date = date(from: value) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter.string(from: date)
    }

    /// 공지 작성 시각 — "8월 24일 오전 1:12"
    static func noticeTimeText(from value: String) -> String {
        guard let date = date(from: value) else { return value }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 a h:mm"
        return formatter.string(from: date)
    }
}
