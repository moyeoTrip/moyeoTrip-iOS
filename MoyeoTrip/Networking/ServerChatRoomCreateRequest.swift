//
//  ServerChatRoomCreateRequest.swift
//  MoyeoTrip
//
//  17 모집 만들기 → `POST /chat-rooms` 요청 조립 (연동 대상 17).
//  요청은 multipart 이고 `request` 파트가 application/json 이다. 응답은 `201 {"roomId": …}` 이라
//  생성 후 15 모집 상세로 이동할 수 있다.
//

import Foundation

/// `POST /chat-rooms` 의 `request` 파트.
///
/// nil 옵셔널은 합성 인코딩이 키 자체를 빼기 때문에 "필드를 보내지 않는다" 규칙을 그대로 만족한다.
struct ServerCreateChatRoomRequest: Encodable, Equatable {
    let title: String
    let description: String?
    let maxParticipants: Int
    /// `DAY_TRIP` | `OVERNIGHT`
    let tripType: String
    let startDate: String
    /// 숙박 여행만 보낸다. 당일치기면 nil → 키가 빠진다 (상호배타 규칙, 에러코드 40008).
    let endDate: String?
    let recruitmentDeadlineDate: String
    /// 당일치기만 보낸다. 숙박이면 둘 다 nil → 키가 빠진다.
    let dayTripStartTime: String?
    let dayTripEndTime: String?
    let meetingLatitude: Double?
    let meetingLongitude: Double?
    let meetingDetails: String?
    let meetingDateTime: String
    let participationFee: Int64?
    /// `NONE` | `MALE_ONLY` | `FEMALE_ONLY`
    let genderRestriction: String
    let minimumAge: Int?
    let maximumAge: Int?
    /// `AUTO` | `MANUAL`
    let joinApprovalMode: String
    /// **필수** — `CUSTOM` | `PUBLIC`
    let courseType: String
    /// `courseType == "PUBLIC"` 일 때만 보낸다.
    let courseId: Int64?
    /// `courseType == "CUSTOM"` 일 때만 보낸다.
    let customCourse: ServerCreateCustomCourse?
}

/// 새 커스텀 코스. `places` 최소 2개 + `tagIds` 가 필수다.
struct ServerCreateCustomCourse: Encodable, Equatable {
    let title: String
    let description: String?
    let places: [ServerCreateCustomCoursePlace]
    let tagIds: [Int64]
}

struct ServerCreateCustomCoursePlace: Encodable, Equatable {
    let contentId: Int64
    let dayNumber: Int
    let sequence: Int
    /// `HH:mm`
    let visitTime: String
}

struct ServerCreateChatRoomResponse: Decodable, Equatable {
    let roomId: Int64
}

extension ChatRoomAPIClient {
    /// 17 모집 만들기 — multipart(`request` 파트가 application/json). 응답의 `roomId` 로 15 모집 상세로 이동한다.
    /// 썸네일은 선택 파트이고, 화면에 이미지 선택 단계가 없어 보내지 않는다.
    func create(request: ServerCreateChatRoomRequest) async throws -> ServerCreateChatRoomResponse {
        try await api.sendMultipart(
            "/api/v1/chat-rooms",
            method: "POST",
            jsonPartName: "request",
            jsonPart: request
        )
    }
}

/// 17 모집 만들기 초안(`RecruitmentDraft`) → `POST /chat-rooms` 요청 조립.
///
/// 순수 함수만 둔다 — 서버 규칙(필수 `courseType`, 당일치기/숙박 상호배타, 커스텀 코스 최소 조건)을
/// 여기서 지키고 단위 테스트로 고정한다.
enum ServerChatRoomCreateRequestBuilder {
    /// 연결할 코스. 서버는 `PUBLIC`(등록 코스 차용)과 `CUSTOM`(새 코스) 중 하나만 받는다.
    enum CourseSelection: Equatable {
        case publicCourse(Int64)
        case custom(ServerCreateCustomCourse)

        var courseType: String {
            switch self {
            case .publicCourse:
                return "PUBLIC"
            case .custom:
                return "CUSTOM"
            }
        }
    }

    /// 요청 조립. 날짜·시각을 서버 포맷으로 옮길 수 없으면 nil을 돌려주고 화면은 서버 전송을 하지 않는다.
    static func request(from draft: RecruitmentDraft, course: CourseSelection) -> ServerCreateChatRoomRequest? {
        guard
            let startDate = isoDate(from: draft.schedule.startDate),
            let deadlineDate = isoDate(from: draft.deadline),
            let meetingTime = isoTime(from: draft.meeting.meetingTime)
        else {
            return nil
        }

        // 당일치기/숙박 상호배타 규칙 (에러코드 40008)
        // - DAY_TRIP: endDate 를 보내지 않고 dayTripStartTime·dayTripEndTime 을 보낸다
        // - 1박 이상: endDate 만 보내고 시간 필드는 보내지 않는다
        let isDayTrip = draft.schedule.kind == .dayTrip
        var endDate: String?
        var dayTripStartTime: String?
        var dayTripEndTime: String?
        if isDayTrip {
            guard
                let startTime = isoTime(from: draft.schedule.startTime),
                let endTime = isoTime(from: draft.schedule.endTime)
            else {
                return nil
            }
            dayTripStartTime = startTime
            dayTripEndTime = endTime
        } else {
            guard let overnightEndDate = isoDate(from: draft.schedule.endDate) else { return nil }
            endDate = overnightEndDate
        }

        var courseID: Int64?
        var customCourse: ServerCreateCustomCourse?
        switch course {
        case .publicCourse(let identifier):
            courseID = identifier
        case .custom(let value):
            // places 최소 2개 + tagIds 는 서버 필수 조건이다.
            guard value.places.count >= 2, !value.tagIds.isEmpty else { return nil }
            customCourse = value
        }

        return ServerCreateChatRoomRequest(
            title: draft.recruitmentName,
            description: draft.note.isEmpty ? nil : draft.note,
            maxParticipants: draft.capacity,
            tripType: isDayTrip ? "DAY_TRIP" : "OVERNIGHT",
            startDate: startDate,
            endDate: endDate,
            recruitmentDeadlineDate: deadlineDate,
            dayTripStartTime: dayTripStartTime,
            dayTripEndTime: dayTripEndTime,
            meetingLatitude: draft.meeting.latitude,
            meetingLongitude: draft.meeting.longitude,
            meetingDetails: meetingDetailsText(draft.meeting),
            meetingDateTime: "\(startDate)T\(meetingTime):00",
            participationFee: participationFee(from: draft.estimatedCost),
            genderRestriction: genderRestriction(draft.genderRestriction),
            minimumAge: draft.minimumAge,
            maximumAge: draft.maximumAge,
            joinApprovalMode: draft.approvalMode == .automatic ? "AUTO" : "MANUAL",
            courseType: course.courseType,
            courseId: courseID,
            customCourse: customCourse
        )
    }

    /// 초안의 방문지 → 커스텀 코스. 서버 방문지 ID(`contentId`)가 없는 항목은 넣지 않는다.
    /// 남은 방문지가 2개 미만이거나 태그가 없으면 nil — 없는 값을 지어내지 않는다.
    static func customCourse(
        from draft: RecruitmentDraft,
        tagIDs: [Int64]
    ) -> ServerCreateCustomCourse? {
        var places: [ServerCreateCustomCoursePlace] = []
        for stop in draft.itinerary.sorted(by: { ($0.day, $0.order) < ($1.day, $1.order) }) {
            guard
                let placeID = stop.placeID,
                let contentID = Int64(placeID),
                let visitTime = isoTime(from: stop.time)
            else {
                continue
            }
            places.append(
                ServerCreateCustomCoursePlace(
                    contentId: contentID,
                    dayNumber: stop.day,
                    sequence: stop.order,
                    visitTime: visitTime
                )
            )
        }
        guard places.count >= 2, !tagIDs.isEmpty else { return nil }
        return ServerCreateCustomCourse(
            title: draft.course.title,
            description: draft.note.isEmpty ? nil : draft.note,
            places: places,
            tagIds: tagIDs
        )
    }

    /// 초안이 어떤 코스를 쓰는지 판단한다. 서버 근거(등록 코스 ID / 서버 방문지 ID + 태그 ID)가
    /// 없으면 nil — 서버 전송을 하지 않고 기존 로컬 흐름을 그대로 둔다.
    static func courseSelection(for draft: RecruitmentDraft, tagIDs: [Int64]) -> CourseSelection? {
        switch draft.source {
        case .linked:
            guard let courseID = draft.course.serverCourseID else { return nil }
            return .publicCourse(courseID)
        case .custom:
            guard let custom = customCourse(from: draft, tagIDs: tagIDs) else { return nil }
            return .custom(custom)
        }
    }

    // MARK: - 값 변환

    /// "2026. 05. 25 (토)" · "2026.05.25" · "2026-05-25" · "2026. 05. 22 (목) 23:59" → "2026-05-25"
    static func isoDate(from text: String?) -> String? {
        guard let text else { return nil }
        let groups = digitGroups(in: text)
        guard groups.count >= 3, groups[0].count == 4 else { return nil }
        guard let year = Int(groups[0]), let month = Int(groups[1]), let day = Int(groups[2]) else { return nil }
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// "07:50" · "7:5" · "09:00:00" → "07:50" / "07:05" / "09:00"
    static func isoTime(from text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        let groups = digitGroups(in: text)
        guard groups.count >= 2, let hour = Int(groups[0]), let minute = Int(groups[1]) else { return nil }
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return String(format: "%02d:%02d", hour, minute)
    }

    /// "1인 45,000원" → 45000 · 금액을 못 읽으면 nil(0원으로 지어내지 않는다)
    static func participationFee(from text: String) -> Int64? {
        // "1인" 의 1이 금액에 붙어 버리므로 먼저 떼고 읽는다
        let digits = text.replacingOccurrences(of: "1인", with: "").filter(\.isNumber)
        guard !digits.isEmpty, let value = Int64(digits) else { return nil }
        return value
    }

    static func genderRestriction(_ text: String) -> String {
        switch text {
        case RecruitmentGenderCondition.women.rawValue:
            return "FEMALE_ONLY"
        case RecruitmentGenderCondition.men.rawValue:
            return "MALE_ONLY"
        default:
            return "NONE"
        }
    }

    /// 집합 안내는 이름 + 상세를 합친다. 둘 다 비어 있으면 nil — 서버에 빈 문자열을 보내지 않는다.
    private static func meetingDetailsText(_ meeting: MeetingPointDetails) -> String? {
        let value = [meeting.name, meeting.detail]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return value.isEmpty ? nil : value
    }

    private static func digitGroups(in text: String) -> [String] {
        text.split(whereSeparator: { !$0.isNumber }).map(String.init)
    }
}
