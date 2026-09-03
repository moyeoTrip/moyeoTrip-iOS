//
//  ServerChatRoomTripMapping.swift
//  MoyeoTrip
//
//  채팅방 응답 → 화면 모델 매핑. `ChatRoomAPIClient.swift` 가 500줄을 넘어 갈라 둔다.
//

import Foundation

// MARK: - 방 id 표기

/// 화면 id 한 개로 방 번호를 뽑는다.
///
/// 앱 안에서 방을 가리키는 문자열이 세 형식이다 — 모집(`server-room-121`) ·
/// 스레드(`server-chat-121`) · 그리고 캡처·딥링크가 넘기는 **순수 숫자**(`121`).
/// 화면마다 한 형식만 보다가 나머지를 nil 로 흘려서 "방을 못 찾았다"는 빈 상태가 찍혔다.
/// 값만 보고 값만 돌려주는 순수 함수라 액터 격리가 필요 없다 —
/// `UITestInitialState` 처럼 뷰 밖에서도 부른다.
enum MoyeoRoomIDText {
    nonisolated static func roomID(from id: String) -> Int64? {
        for prefix in ["server-chat-", "server-room-"] where id.hasPrefix(prefix) {
            return Int64(id.dropFirst(prefix.count))
        }
        return Int64(id)
    }
}

// MARK: - 화면 모델 매핑

enum ServerTripMapper {
    static let serverTripIDPrefix = "server-room-"

    static func roomID(fromTripID tripID: String) -> Int64? {
        guard tripID.hasPrefix(serverTripIDPrefix) else { return nil }
        return Int64(tripID.dropFirst(serverTripIDPrefix.count))
    }

    /// roomId만 아는 진입점(알림 등)용 빈 껍데기 — 상세 화면이 서버 상세로 다시 채운다
    static func placeholderTrip(roomID: Int64, title: String = "") -> TripRecruitment {
        TripRecruitment(
            id: "\(serverTripIDPrefix)\(roomID)",
            courseID: "",
            title: title,
            region: "",
            coverMascot: "",
            hostName: "",
            hostAvatar: "",
            schedule: "",
            meetupPoint: "",
            price: "",
            capacity: 0,
            joined: 0,
            minimumParticipants: 0,
            status: .open,
            summary: "",
            vibe: "",
            tags: [],
            route: [],
            participants: [],
            recruitmentDeadline: "",
            minimumAge: 0,
            maximumAge: 0,
            genderRestriction: "",
            serverRoomID: roomID
        )
    }

    /// 검색 결과 요약 → 모집 상세 진입용 최소 TripRecruitment.
    /// 서버가 주지 않는 값은 비워 두고, 화면은 서버 상세 응답으로 다시 채운다.
    static func trip(from summary: ServerChatRoomSummary) -> TripRecruitment {
        var meeting: MeetingPointDetails?
        if let coordinate = summary.meetingCoordinate {
            meeting = MeetingPointDetails(
                name: summary.meetingDetails ?? "",
                address: "",
                detail: "",
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                meetingTime: summary.meetingDateTime.map { timeText(fromDateTime: $0) } ?? ""
            )
        }
        // `map(displayDate)` 처럼 함수 참조로 넘기면 main-actor 격리가 벗겨져 Swift 6 경고가 난다.
        // 호출을 이 컨텍스트 안에 둔다.
        var endDateText: String?
        if let endDate = summary.endDate {
            endDateText = displayDate(endDate)
        }

        return TripRecruitment(
            id: "\(serverTripIDPrefix)\(summary.roomId)",
            courseID: "",
            title: summary.title,
            region: "",
            coverMascot: "",
            hostName: "",
            hostAvatar: "",
            // 검색·지도 응답에는 일정이 없다. 상세 응답이 들어오면 화면이 다시 채운다.
            schedule: summary.startDate.map { scheduleText(startDate: $0, endDate: summary.endDate) } ?? "",
            meetupPoint: summary.meetingDetails ?? "",
            price: "",
            capacity: summary.maxParticipants,
            joined: summary.participantCount,
            minimumParticipants: 0,
            status: status(from: summary.status),
            summary: summary.description ?? "",
            vibe: "",
            tags: summary.tagNames,
            route: [],
            participants: [],
            scheduleDetails: TripScheduleDetails(
                kind: summary.tripType == "OVERNIGHT" ? .overnight : .dayTrip,
                startDate: summary.startDate.map { displayDate($0) } ?? "",
                endDate: endDateText,
                startTime: shortTime(summary.dayTripStartTime),
                endTime: shortTime(summary.dayTripEndTime)
            ),
            meetingDetails: meeting,
            recruitmentDeadline: summary.recruitmentDeadlineDate.map {
                deadlineText(deadlineDate: $0, dDay: summary.recruitmentDDay)
            } ?? "",
            minimumAge: 0,
            maximumAge: 0,
            genderRestriction: "",
            serverRoomID: summary.roomId,
            heroImageURL: summary.thumbnailURL,
            serverCourseTitle: summary.courseTitle
        )
    }

    /// 채팅방 상세 응답 → 모집 상세 화면 모델
    static func trip(from detail: ServerChatRoomDetail, course: ServerTravelCourse?) -> TripRecruitment {
        let kind: TripScheduleKind = detail.tripType == "OVERNIGHT" ? .overnight : .dayTrip
        let meetingTime = timeText(fromDateTime: detail.meetingDateTime)
        let orderedPlaces = (course?.places ?? [])
            .sorted { ($0.dayNumber, $0.sequence) < ($1.dayNumber, $1.sequence) }

        var meeting: MeetingPointDetails?
        if let latitude = detail.meetingLatitude, let longitude = detail.meetingLongitude {
            meeting = MeetingPointDetails(
                name: detail.meetingDetails ?? "",
                address: "",
                detail: "",
                latitude: latitude,
                longitude: longitude,
                meetingTime: meetingTime
            )
        }

        return TripRecruitment(
            id: "\(serverTripIDPrefix)\(detail.roomId)",
            courseID: "",
            title: detail.title,
            region: "",
            coverMascot: "",
            hostName: "",
            hostAvatar: "",
            schedule: scheduleText(startDate: detail.startDate, endDate: detail.endDate),
            meetupPoint: detail.meetingDetails ?? "",
            price: detail.participationFee.map { "1인 \(decimalText($0))원" } ?? "무료 · 미정",
            capacity: detail.maxParticipants,
            joined: detail.participantCount,
            minimumParticipants: 0,
            status: status(from: detail.status),
            summary: detail.description ?? "",
            vibe: "",
            tags: course?.tags.map(\.name) ?? [],
            route: orderedPlaces.map(\.title),
            participants: [],
            courseSource: course?.type == "CUSTOM" ? .custom : .linked,
            // 15 코스 미리보기는 실지도다 — 방문지 위경도를 여기서 채워야 지도를 그릴 수 있다.
            itinerary: orderedPlaces.map { place in
                ItineraryStop(
                    id: "server-stop-\(place.contentId)-\(place.dayNumber)-\(place.sequence)",
                    day: place.dayNumber,
                    order: place.sequence,
                    time: shortTime(place.visitTime) ?? "",
                    name: place.title,
                    memo: "",
                    placeID: "\(place.contentId)",
                    latitude: place.latitude,
                    longitude: place.longitude
                )
            },
            scheduleDetails: TripScheduleDetails(
                kind: kind,
                startDate: displayDate(detail.startDate),
                // 함수 참조로 넘기면 main-actor 격리가 벗겨져 Swift 6 에서 경고가 난다.
                endDate: detail.endDate.map { displayDate($0) },
                startTime: shortTime(detail.dayTripStartTime),
                endTime: shortTime(detail.dayTripEndTime)
            ),
            meetingDetails: meeting,
            recruitmentDeadline: deadlineText(
                deadlineDate: detail.recruitmentDeadlineDate,
                dDay: detail.recruitmentDDay
            ),
            minimumAge: detail.minimumAge ?? 0,
            maximumAge: detail.maximumAge ?? 0,
            genderRestriction: genderText(detail.genderRestriction),
            serverRoomID: detail.roomId,
            heroImageURL: MoyeoImageURL.resolve(detail.thumbnail),
            hostProfileImageURL: MoyeoImageURL.resolve(detail.hostProfileImageUrl),
            serverCourseTitle: course?.title
        )
    }

    static func status(from serverStatus: String) -> RecruitmentStatus {
        switch serverStatus {
        case "CONFIRMED":
            return .confirmed
        case "CANCELLED":
            return .cancelled
        default:
            return .open
        }
    }

    static func genderText(_ restriction: String) -> String {
        switch restriction {
        case "FEMALE_ONLY":
            return "여성만"
        case "MALE_ONLY":
            return "남성만"
        default:
            return "성별 무관"
        }
    }

    /// "2026-09-12" → "2026.09.12 (토)"
    static func displayDate(_ isoDate: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: isoDate) else { return isoDate }
        formatter.dateFormat = "yyyy.MM.dd (E)"
        return formatter.string(from: date)
    }

    /// "2026-09-12" + 종료일 → "2026.09.12 (토)" 또는 "2026.09.12 (토) ~ 2026.09.13 (일)"
    static func scheduleText(startDate: String, endDate: String?) -> String {
        guard let endDate, !endDate.isEmpty else { return displayDate(startDate) }
        return "\(displayDate(startDate)) ~ \(displayDate(endDate))"
    }

    /// 서버 시각 → 화면 표기 `HH:mm`.
    /// 문서는 `HH:mm`, 실제 응답은 `HH:mm:ss` 라 **양쪽 모두** 받는다.
    static func shortTime(_ time: String?) -> String? {
        guard let time, !time.isEmpty else { return nil }
        let parts = time.split(separator: ":")
        guard parts.count >= 2 else { return nil }
        return "\(parts[0]):\(parts[1])"
    }

    /// "2026-09-12T08:30:00" → "08:30"
    static func timeText(fromDateTime dateTime: String) -> String {
        guard let timePart = dateTime.split(separator: "T").last else { return "" }
        return String(timePart.prefix(5))
    }

    /// 마감일 → "D-17 · 9/9" (기존 목데이터 표기와 같은 형태)
    static func deadlineText(deadlineDate: String, dDay: Int64?) -> String {
        let parts = deadlineDate.split(separator: "-")
        let shortDate: String
        if parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]) {
            shortDate = "\(month)/\(day)"
        } else {
            shortDate = deadlineDate
        }
        guard let dDay else { return shortDate }
        return dDay <= 0 ? "D-Day · \(shortDate)" : "D-\(dDay) · \(shortDate)"
    }

    static func decimalText(_ value: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
