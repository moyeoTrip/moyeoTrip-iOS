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
    /// **필수** — 서버가 `@NotNull` + `@Min(3)` 으로 검증한다. 빠뜨리면 400
    /// 「minimumParticipants 필드는 필수입니다.」로 생성이 막힌다(2026-09-10 확인).
    let minimumParticipants: Int
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
    ///
    /// 2026-08-26 서버 변경으로 `thumbnail` 파트가 **필수**다(없으면 400 `40041`
    /// "채팅방 썸네일 이미지는 필수입니다"). **호스트가 고른 사진만** 올린다 —
    /// 예전에는 사진 고르는 단계가 없어 공용 플레이스홀더(「이미지 없음」 16:9 일러스트)를 대신 올렸고,
    /// 그 결과 목록에 회색 자리표시자가 진짜 사진인 양 걸려 사진이 없는 방과 구분되지 않았다.
    /// 사진이 없으면 파트를 보내지 않고 **서버가 400 으로 알려주게 둔다.**
    func create(
        request: ServerCreateChatRoomRequest,
        thumbnail: MoyeoMultipartFile?
    ) async throws -> ServerCreateChatRoomResponse {
        try await api.sendMultipart(
            "/api/v1/chat-rooms",
            method: "POST",
            jsonPartName: "request",
            jsonPart: request,
            file: thumbnail
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
            minimumParticipants: max(3, draft.minimumParticipants),
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
            // 여기까지 오기 전에 `validationError` 가 막는다 — 그래도 남으면 조용히 버리지 않고
            // 요청 자체를 만들지 않는다. 예전에는 `continue` 로 건너뛰어 **담은 방문지가
            // 소리 없이 빠진 코스**가 서버에 저장됐다.
            guard
                let placeID = stop.placeID,
                let contentID = Int64(placeID),
                let visitTime = isoTime(from: stop.time)
            else {
                return nil
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
        // 코스 이름은 **코스 에디터에서 호스트가 적은 값**이다. 예전에는 `draft.course.title` 을 썼는데
        // 커스텀 코스의 `draft.course` 는 늘 `.empty` 라 빈 제목이 나갔다 (IOS-F124).
        let title = draft.customCourseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard places.count >= 2, !tagIDs.isEmpty, !title.isEmpty else { return nil }
        return ServerCreateCustomCourse(
            title: title,
            description: draft.note.isEmpty ? nil : draft.note,
            places: places,
            tagIds: tagIDs
        )
    }

    /// 서버로 보낼 수 없는 이유를 **한국어 한 문장**으로 돌려준다. 보낼 수 있으면 nil 이다.
    ///
    /// 예전에는 요청을 조립하지 못하면 조용히 `createLocalRecruitment()` 로 떨어져
    /// **이 기기 안에만 있는 가짜 모집**이 만들어졌다 — 호스트는 모집을 연 줄 알지만
    /// 서버에는 없고 아무도 신청할 수 없었다 (AND-85 조사 중 발견, 2026-09-13).
    /// 안드로이드는 같은 상황에서 버튼을 잠갔고, iOS 는 만들어진 척을 했다.
    static func validationError(for draft: RecruitmentDraft, tagIDs: [Int64]) -> String? {
        if draft.recruitmentName.trimmingCharacters(in: .whitespaces).isEmpty { return "모집 이름을 적어 주세요." }
        if isoDate(from: draft.schedule.startDate) == nil { return "여행 날짜를 정해 주세요." }
        if isoDate(from: draft.deadline) == nil { return "모집 마감일을 정해 주세요." }
        if isoTime(from: draft.meeting.meetingTime) == nil { return "집합 시간을 정해 주세요." }
        // 서버 `ChatRoomService` 가 `recruitmentDeadlineDate <= startDate` 를 요구한다.
        // 생성 화면에만 이 검사가 없어서 마감일을 여행 뒤로 잡아도 마지막 단계까지 통과한 뒤
        // 서버 400 으로 튕겼다 — 모집 내용 수정 화면과 **같은 문구**로 맞춘다 (IOS-F141).
        if let start = isoDate(from: draft.schedule.startDate),
           let deadline = isoDate(from: draft.deadline), deadline > start {
            return "모집 마감일은 여행 날짜보다 앞이어야 해요."
        }
        if let scheduleProblem = scheduleError(for: draft) { return scheduleProblem }
        switch draft.source {
        case .linked:
            if draft.course.serverCourseID == nil { return "등록된 코스를 다시 골라 주세요." }
        case .custom:
            return customCourseError(for: draft, tagIDs: tagIDs)
        }
        return nil
    }

    /// 일정이 말이 되는지. 서버는 **날짜만** 보므로(`validateRoomDates` 가
    /// `meetingDateTime.toLocalDate()` 만 비교한다) 시각의 앞뒤는 여기서 잡는다 —
    /// 안 잡으면 「18:00 에 끝나는데 19:00 집합」 같은 모집이 그대로 열린다 (안드 AND-116).
    private static func scheduleError(for draft: RecruitmentDraft) -> String? {
        guard draft.schedule.kind == .dayTrip else {
            return isoDate(from: draft.schedule.endDate) == nil ? "1박 이상이면 여행 종료 날짜를 정해 주세요." : nil
        }
        guard
            let startTime = isoTime(from: draft.schedule.startTime),
            let endTime = isoTime(from: draft.schedule.endTime)
        else {
            return "당일치기는 시작·종료 시각을 정해 주세요."
        }
        if startTime >= endTime { return "여행 종료 시각은 시작 시각보다 뒤여야 해요." }
        if let meetingTime = isoTime(from: draft.meeting.meetingTime), meetingTime > endTime {
            return "집합 시간이 여행 종료 시각보다 늦어요."
        }
        return nil
    }

    /// 직접 만든 코스가 서버 규칙을 못 맞추는 이유. 서버 `validateCustomCourseSchedule` 과 같은 규칙이다.
    private static func customCourseError(for draft: RecruitmentDraft, tagIDs: [Int64]) -> String? {
        let title = draft.customCourseTitle.trimmingCharacters(in: .whitespaces)
        if title.isEmpty { return "코스 이름을 적어 주세요." }
        // 서버 `@Size(max = 100)`. 에디터가 이미 100자에서 자르지만, 다른 경로로 들어온 초안도 막는다.
        if title.count > 100 { return "코스 이름은 100자까지예요." }
        if tagIDs.isEmpty { return "코스 태그를 하나 이상 골라 주세요." }
        // 검색 결과에서 고르지 않은 방문지는 `contentId` 가 없어 서버로 보낼 수 없다.
        let unsendable = draft.itinerary.filter { Int64($0.placeID ?? "") == nil }
        if let first = unsendable.first {
            return "‘\(first.name)’ 은(는) 방문지 검색에서 고른 곳이 아니라 보낼 수 없어요. 검색으로 다시 담아 주세요."
        }
        let dayCount = tripDayCount(for: draft)
        let byDay = Dictionary(grouping: draft.itinerary, by: \.day)
        for day in 1...max(dayCount, 1) {
            let count = byDay[day]?.count ?? 0
            if count < 2 { return "\(day)일차 방문지가 \(count)곳이에요. 일차마다 2곳 이상 담아 주세요." }
        }
        if let extra = byDay.keys.filter({ $0 > dayCount }).min() {
            return "여행은 \(dayCount)일인데 코스에 \(extra)일차가 있어요. 일정이나 코스를 맞춰 주세요."
        }
        return nil
    }

    /// 여행 일수. 당일치기는 1일이고, 숙박은 시작·종료 날짜 사이의 날 수다(서버 `tripDays()` 와 같다).
    static func tripDayCount(for draft: RecruitmentDraft) -> Int {
        guard draft.schedule.kind != .dayTrip,
              let start = isoDate(from: draft.schedule.startDate),
              let end = isoDate(from: draft.schedule.endDate)
        else { return 1 }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let startDate = formatter.date(from: start), let endDate = formatter.date(from: end) else { return 1 }
        let days = Calendar(identifier: .gregorian).dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return max(1, days + 1)
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
