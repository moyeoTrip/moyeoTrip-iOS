// swiftlint:disable file_length line_length
import SwiftUI

enum RecruitmentGenderCondition: String, CaseIterable, Hashable {
    case any = "제한 없음"
    case women = "여성만"
    case men = "남성만"
}

enum RecruitmentApprovalMode: String, CaseIterable, Hashable {
    case automatic = "자동 승인"
    case manual = "수동 승인"

    var detail: String {
        switch self {
        case .automatic:
            return "조건에 맞으면 바로 합류해요. 모임이 빨리 채워져요."
        case .manual:
            return "한마디와 매너 점수를 보고 호스트가 직접 수락해요."
        }
    }

    var icon: String {
        switch self {
        case .automatic:
            return "bolt.fill"
        case .manual:
            return "hand.raised.fill"
        }
    }
}

extension Array where Element == String {
    /// 비어 있지 않은 조각만 이어 붙인다 — 값이 없는 자리에 구분자만 남는 것을 막는다.
    func joinedNonEmpty(_ separator: String) -> String {
        filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: separator)
    }
}

struct RecruitmentDraft: Hashable {
    var source: CourseSource = .linked
    /// 고른 코스. 아직 못 고른 상태는 빈 코스다 — 기본 코스를 지어내지 않는다.
    var course: TravelCourse = .empty
    // 17-x 는 호스트가 채우는 입력 폼이다. 미리 채워 두면 남이 만든 모임이 내 초안처럼 보인다.
    var itinerary: [ItineraryStop] = []
    // 여행 시간 · 집합 시간 · 비용의 시작값은 **입력 폼의 기본값**이다 (남의 데이터가 아니다).
    // 안드로이드 `RecruitmentDraft`(startTime 08:00 · endTime 18:00 · meetingTime 08:00 · 비용 0)와 같은 값으로,
    // 인원·나이대·성별 기본값과 같은 성격이다. 날짜는 호스트가 골라야 하므로 비워 둔다.
    /// 여행 날짜와 모집 마감일의 **폼 기본값**이다.
    ///
    /// 예전에는 둘 다 비워 뒀다(「호스트가 골라야 한다」). 그런데 17-6 요약에서 「마감」 값이
    /// 통째로 비어 사용자가 「마감 일시가 안 보인다」고 지적했다 (2026-09-09).
    /// 웹은 이미 날짜 기본값을 갖고 있었으므로, 세 구현을 같은 규칙으로 맞춘다:
    /// **출발 = 2주 뒤 · 마감 = 출발 3일 전**. 호스트가 2단계에서 언제든 바꾼다.
    var schedule = TripScheduleDetails(
        kind: .dayTrip,
        startDate: RecruitmentDraft.defaultStartDate,
        startTime: "08:00",
        endTime: "18:00"
    )
    var deadline = RecruitmentDraft.defaultDeadline

    /// 「2026.09.23 (수)」 — 오늘부터 2주 뒤.
    static var defaultStartDate: String {
        dateText(daysFromToday: 14)
    }

    /// 「2026.09.20 (일) 23:59」 — 출발 3일 전 자정 직전.
    static var defaultDeadline: String {
        "\(dateText(daysFromToday: 11)) 23:59"
    }

    private static func dateText(daysFromToday days: Int) -> String {
        let target = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd (E)"
        return formatter.string(from: target)
    }
    /// 집합 장소. 이름·주소는 호스트가 지도를 끌어 정한다 —
    /// 위경도만 경북 중심으로 시작한다(값 표시가 아니라 지도 카메라의 첫 위치다).
    var meeting = MeetingPointDetails(
        name: "",
        address: "",
        detail: "",
        latitude: 36.4,
        longitude: 128.9,
        meetingTime: "08:00"
    )
    var capacity = 5
    var minimumParticipants = 3
    /// 직접 만든 코스의 이름. 서버 `CreateCustomCourseRequest.title` 이 `@NotBlank @Size(max = 100)` 이라 **필수**다.
    /// 등록 코스를 고를 때 채워지는 `course` 는 커스텀 경로에서 늘 `.empty` 라 이름을 담을 자리가 없었고,
    /// 그래서 커스텀 코스로는 요청을 조립할 수조차 없었다 (IOS-F124). 웹 `custom-course-title`·
    /// 안드 `RecruitmentDraft.customCourseTitle` 과 같은 값이다.
    var customCourseTitle = ""
    /// 직접 만든 코스의 태그 ID. 서버 `createCustomCourse` 가 `tagIds` 로 태그를 하나도 못 찾으면
    /// `TRAVEL_COURSE_TAG_NOT_FOUND` 로 거절한다 — 즉 **1개 이상**이 필수다.
    var customCourseTagIDs: [Int64] = []
    var recruitmentName = ""
    /// 호스트가 **적었을 때만** 값이 생긴다 — 기본은 미정(빈 문자열)이다.
    /// 예전에는 `"0원"` 이 미리 박혀 있어 손대지 않은 모집도 「1인 0원」으로 열렸다.
    var estimatedCost = ""
    /// 나이 제한은 **호스트가 정했을 때만** 건다. 기본은 제한 없음(`nil`)이다.
    /// 예전에는 `25~35` 가 기본이라, 호스트가 손대지 않아도 25세 미만·35세 초과가
    /// 전부 막힌 채로 모집이 열렸다 (사용자 지적 2026-09-13). 서버도 둘 다 nullable 이다.
    var minimumAge: Int?
    var maximumAge: Int?
    var genderRestriction = "성별 무관"
    var note = ""
    /// 17-5 신청 승인 방식. 화면기획 기본값은 자동 승인이고, 서버 요청의 `joinApprovalMode` 가 된다.
    var approvalMode = RecruitmentApprovalMode.automatic

    /// 화면에 적는 코스 이름. 등록 코스는 1단계에서 고른 코스 이름, 직접 만든 코스는 에디터에서 적은 이름이다.
    /// 커스텀의 `course` 는 늘 `.empty` 라, 예전에는 17-5 코스 줄과 17-6 요약 카드가 **빈 채로** 그려졌다.
    var displayCourseTitle: String {
        source == .custom ? customCourseTitle : course.title
    }

    /// 나이 제한 표기. 정하지 않았으면 「제한 없음」이라고 분명히 말한다.
    var ageRangeText: String {
        guard let minimumAge, let maximumAge else { return "나이 제한 없음" }
        return "\(minimumAge) ~ \(maximumAge)세"
    }

    static let preview = RecruitmentDraft()

    /// 17-6 요약 카드의 일정 줄. **값이 없으면 구분자도 찍지 않는다** —
    /// 예전에는 날짜·시간이 비면 `· · -` 처럼 구분자만 남았다.
    var scheduleSummary: String {
        switch schedule.kind {
        case .dayTrip:
            let head = [compactDate(schedule.startDate), "당일치기"].joinedNonEmpty(" ")
            let range = [schedule.startTime ?? "", schedule.endTime ?? ""].joinedNonEmpty(" - ")
            return [head, range].joinedNonEmpty(" · ")
        case .overnight:
            let start = compactDate(schedule.startDate)
            let end = compactDate(schedule.endDate ?? schedule.startDate)
            return start == end ? start : [start, end].joinedNonEmpty(" - ")
        }
    }

    /// 17-6 집합 줄 — 시간 · 장소 · 상세 안내 중 채워진 것만 잇는다.
    var meetingSummary: String {
        [meeting.meetingTime, meeting.name, meeting.detail].joinedNonEmpty(" ")
    }

    /// 17-6 비용 줄 — 아직 안 적었으면 `(예상)` 만 남기지 않고 아무것도 그리지 않는다.
    var estimatedCostSummary: String {
        let cost = estimatedCost.trimmingCharacters(in: .whitespaces)
        return cost.isEmpty ? "" : "1인 \(cost) (예상)"
    }

    /// 리뷰(17-7) 요약 카드용 성별 조건 표기 — 제한이 없으면 "성별 제한 없음"으로 읽는다.
    var genderSummary: String {
        switch genderRestriction {
        case RecruitmentGenderCondition.women.rawValue, RecruitmentGenderCondition.men.rawValue:
            return genderRestriction
        default:
            return "성별 제한 없음"
        }
    }

    /// 리뷰(17-7) 요약 카드용 마감 표기 — "5/22(목) 23:59 · D-3" 형태.
    var deadlineSummary: String {
        let parts = deadline.split(separator: " ").map(String.init)
        guard parts.count >= 5 else { return deadline }
        let compact = compactDate(parts.prefix(4).joined(separator: " "))
        return "\(compact) \(parts[4]) · D-3"
    }

    private func compactDate(_ value: String) -> String {
        let parts = value.split(separator: " ")
        guard parts.count >= 4,
              let month = Int(parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "."))),
              let day = Int(parts[2])
        else { return value }
        return "\(month)/\(day)\(parts[3])"
    }
}

struct RecruitmentCreationFlowView: View {
    let courseID: String
    let onCreated: (TripRecruitment, ChatThread) -> Void
    let onSendChatMessage: (ChatThread, ChatMessage) -> Void
    let onApproveApplicant: (TripRecruitment, Participant) -> Void
    let onRejectApplicant: (TripRecruitment, Participant) -> Void
    let onSetRecruitmentClosed: (TripRecruitment, Bool) -> Void
    /// 캡처가 실제 플로우의 특정 단계로 바로 들어올 때 쓴다. 기본은 1단계다.
    var initialStep = 1
    /// 집합 장소 화면(17-3)을 열린 상태로 시작한다.
    var startsAtMeetingPoint = false
    /// 5단계 리뷰를 커스텀 코스(17-6) / 등록 코스(17-7) 중 무엇으로 볼지.
    var initialSource: CourseSource?
    /// 3단계(17-4a · 17-4b) 캡처용 최대 인원 시작값. nil 이면 폼 기본값(5)이다.
    /// 멘트 3단계를 아트보드로 나눠 찍기 위한 것이고, 멘트 규칙 자체는 화면이 그대로 판단한다.
    var initialCapacity: Int?
    @Environment(\.dismiss) private var dismiss
    @State private var step: Int
    /// 17-3 집합 장소 지정. 2단계 일정 안에서 이어지는 화면이다(안드로이드와 같은 구성).
    @State private var showsMeetingPoint = false
    @State private var draft: RecruitmentDraft
    @State private var showCustomEditor = false
    @State private var createdTrip: TripRecruitment?
    @State private var createdThread: ChatThread?
    /// 실서버로 방을 만든 결과. 응답의 `roomId` 로 15 모집 상세를 연다.
    @State private var createdServerTrip: TripRecruitment?
    @State private var isCreatingOnServer = false
    @State private var creationErrorMessage: String?
    /// 커스텀 코스의 `tagIds` 근거. 서버 태그 목록에서 초안 태그 이름과 일치하는 것만 쓴다.
    @State private var serverCourseTags: [ServerCourseTag] = []
    /// 5단계에서 호스트가 고른 대표 사진. 서버 `thumbnail` 파트는 **필수**다.
    ///
    /// 예전에는 고르는 단계가 없어서, 앱이 내장 「이미지 없음」 일러스트를 대신 올렸다 —
    /// 목록에 회색 자리표시자가 진짜 사진인 양 걸려 사진이 정말 없는 방과 구분되지 않았다.
    @State private var roomThumbnail: UIImage?

    init(
        courseID: String,
        initialStep: Int = 1,
        startsAtMeetingPoint: Bool = false,
        initialSource: CourseSource? = nil,
        initialCapacity: Int? = nil,
        onCreated: @escaping (TripRecruitment, ChatThread) -> Void = { _, _ in },
        onSendChatMessage: @escaping (ChatThread, ChatMessage) -> Void = { _, _ in },
        onApproveApplicant: @escaping (TripRecruitment, Participant) -> Void = { _, _ in },
        onRejectApplicant: @escaping (TripRecruitment, Participant) -> Void = { _, _ in },
        onSetRecruitmentClosed: @escaping (TripRecruitment, Bool) -> Void = { _, _ in }
    ) {
        self.courseID = courseID
        self.initialStep = initialStep
        self.startsAtMeetingPoint = startsAtMeetingPoint
        self.initialSource = initialSource
        self.initialCapacity = initialCapacity
        _step = State(initialValue: initialStep)
        _showsMeetingPoint = State(initialValue: startsAtMeetingPoint)
        self.onCreated = onCreated
        self.onSendChatMessage = onSendChatMessage
        self.onApproveApplicant = onApproveApplicant
        self.onRejectApplicant = onRejectApplicant
        self.onSetRecruitmentClosed = onSetRecruitmentClosed
        // 코스는 1단계에서 서버 공개 코스 중에 고른다 — 여기서 목 코스를 심지 않는다.
        var value = RecruitmentDraft.preview
        if let initialSource { value.source = initialSource }
        if let initialCapacity {
            // 폼이 허용하는 범위(최소 인원 + 1 ... 20) 안으로만 받는다 — 스테퍼와 같은 한계다.
            value.capacity = min(20, max(value.minimumParticipants + 1, initialCapacity))
        }
        _draft = State(initialValue: value)
    }

    var body: some View {
        if let createdServerTrip {
            // 서버가 준 roomId 로 15 모집 상세를 연다 — 화면은 서버 상세 응답으로 스스로 채워진다.
            TripDetailView(
                trip: createdServerTrip,
                onSendChatMessage: onSendChatMessage
            )
        } else if let createdTrip {
            HostManageView(
                trip: createdTrip,
                thread: createdThread,
                onSendChatMessage: onSendChatMessage,
                onApproveApplicant: onApproveApplicant,
                onRejectApplicant: onRejectApplicant,
                onSetRecruitmentClosed: onSetRecruitmentClosed
            )
        } else {
            creationFlow
        }
    }

    private var creationFlow: some View {
        VStack(spacing: 0) {
            CreationHeader(step: step, back: goBack)
            CreationStepDots(current: step)
            Group {
                switch step {
                case 1: RecruitmentSourceView(draft: $draft) {
                    showCustomEditor = true
                }
                // 2단계 일정 → 집합 장소 지정(17-3) → 3단계 인원. 안드로이드와 같은 구성이다.
                // 이전에는 집합 장소 화면이 플로우에 없어서, 사용자가 한 번도 고르지 않은
                // 초안 기본 좌표(청송 시외버스터미널)가 그대로 서버로 나갔다.
                case 2:
                    if showsMeetingPoint {
                        RecruitmentMeetingView(draft: $draft)
                    } else {
                        RecruitmentScheduleView(draft: $draft)
                    }
                case 3: RecruitmentPeopleView(draft: $draft)
                case 4: RecruitmentDetailView(draft: $draft)
                default: RecruitmentSummaryView(
                    draft: $draft,
                    thumbnail: $roomThumbnail,
                    errorMessage: creationErrorMessage,
                    isSubmitting: isCreatingOnServer,
                    // 「이전」이 빈 클로저라 **5단계에서 뒤로 갈 수 없었다** — 앞 단계 값을
                    // 고치려면 화면을 나갔다 처음부터 다시 와야 했다 (2026-09-13).
                    onBack: goBack,
                    onCreate: createRecruitment
                )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if step < 5 {
                VStack(spacing: 0) {
                    // 왜 다음으로 못 가는지 **버튼 바로 위에** 적는다. 예전에는 마감일을 여행
                    // 시작일 뒤로 잡아도 5단계까지 그냥 넘어간 뒤 서버 400 으로 튕겼다 (IOS-F141).
                    if let stepBlockingReason {
                        Text(stepBlockingReason)
                            .font(.caption)
                            .foregroundStyle(MoyeoTheme.dangerRed)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            .accessibilityIdentifier("createRecruitment.blockingReason")
                    }
                    CreationFooter(
                        backTitle: step == 1 ? "" : "이전",
                        nextTitle: nextTitle,
                        back: goBack,
                        next: { advance() },
                        isNextEnabled: stepBlockingReason == nil
                    )
                }
                .background(MoyeoTheme.card)
            }
        }
        .sheet(isPresented: $showCustomEditor) {
            NavigationStack {
                CustomCourseEditorView(
                    stops: $draft.itinerary,
                    courseTitle: $draft.customCourseTitle,
                    selectedTagIDs: $draft.customCourseTagIDs,
                    tags: serverCourseTags
                ) {
                    showCustomEditor = false
                    withAnimation(.easeInOut(duration: 0.2)) { step = 2 }
                }
            }
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        // 바를 감추면 UIKit 이 엣지 스와이프를 스스로 끈다 — 화면마다 되살린다 (TC NAV-017).
        .moyeoBackSwipeEnabled()
        .task {
            // 커스텀 코스 요청에는 서버 태그 ID가 필요하다. 실패하면 서버 전송을 시도하지 않는다.
            guard MoyeoServerSync.isEnabled, serverCourseTags.isEmpty else { return }
            serverCourseTags = (try? await TravelCourseAPIClient.shared.tags()) ?? []
        }
        .accessibilityIdentifier(
            "screen.createRecruitment.\(courseID).step\(step)\(showsMeetingPoint ? ".meetingPoint" : "")"
        )
    }

    /// 이 단계에서 「다음」을 왜 못 누르는지. 누를 수 있으면 nil 이다.
    /// 지금은 2단계 일정만 본다 — 날짜 규칙을 여기서 못 잡으면 5단계까지 간 뒤 서버가 거절한다.
    private var stepBlockingReason: String? {
        // 집합 장소 화면은 **이름 없이 통과**했다 — 핀만 찍고 넘어가면 참가자에게 「」이 보였다 (IOS-F36).
        if step == 2, showsMeetingPoint {
            return draft.meeting.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "집합 장소를 검색해 이름을 정해 주세요." : nil
        }
        guard step == 2, !showsMeetingPoint else { return nil }
        guard let start = ServerChatRoomCreateRequestBuilder.isoDate(from: draft.schedule.startDate) else {
            return "여행 날짜를 정해 주세요."
        }
        guard let deadline = ServerChatRoomCreateRequestBuilder.isoDate(from: draft.deadline) else {
            return "모집 마감일을 정해 주세요."
        }
        if deadline > start { return "모집 마감일은 여행 날짜보다 앞이어야 해요." }
        if draft.schedule.kind == .overnight,
           let end = ServerChatRoomCreateRequestBuilder.isoDate(from: draft.schedule.endDate), end <= start {
            return "종료 날짜는 여행 시작 날짜보다 뒤여야 해요."
        }
        // 당일치기 시각 역전도 **여기서** 막는다. 날짜 3종은 2단계에서 막는데 시각만
        // 5단계 「모집 열기」까지 통과해, 09:30 출발에 06:00 종료인 요약을 세 화면이나
        // 지나 보고 나서야 거절당했다 (TC CREATE-029).
        // 규칙 문구는 전송 직전 검사(`ServerChatRoomCreateRequestBuilder`)와 **같은 말**을 쓴다.
        if draft.schedule.kind == .dayTrip,
           let startTime = ServerChatRoomCreateRequestBuilder.isoTime(from: draft.schedule.startTime),
           let endTime = ServerChatRoomCreateRequestBuilder.isoTime(from: draft.schedule.endTime),
           startTime >= endTime {
            return "여행 종료 시각은 시작 시각보다 뒤여야 해요."
        }
        return nil
    }

    private var nextTitle: String {
        if step == 1 {
            return draft.source == .custom ? "코스 만들러 가기" : "이 코스로 다음"
        }
        if step == 2, showsMeetingPoint { return "이 위치로 지정" }
        return "다음"
    }

    private func advance() {
        // 단계를 옮기면 앞 단계의 실패 문구를 지운다. 예전에는 지우는 곳이 「모집 열기」
        // 직전 한 곳뿐이라, 원인을 고치고 돌아와도 옛 경고가 그대로 붙어 있었다
        // (IOS-F144. 대비: 수정 화면 `RecruitEditView.swift:88` 은 `onChange` 마다 지운다).
        creationErrorMessage = nil
        if step == 1, draft.source == .custom {
            showCustomEditor = true
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            if step == 2, !showsMeetingPoint {
                showsMeetingPoint = true
            } else {
                showsMeetingPoint = false
                step += 1
            }
        }
    }

    private func goBack() {
        creationErrorMessage = nil
        if step == 2, showsMeetingPoint {
            withAnimation(.easeInOut(duration: 0.2)) { showsMeetingPoint = false }
        } else if step == 1 {
            dismiss()
        } else {
            step -= 1
        }
    }

    /// 서버로 보낼 코스 태그 ID.
    ///
    /// 커스텀 코스는 **에디터에서 호스트가 직접 고른 ID**를 쓴다 — 예전에는 `draft.course.tags`(이름)를
    /// 서버 목록과 맞췄는데, 커스텀의 `draft.course` 는 늘 `.empty` 라 결과가 항상 비어 있었다 (IOS-F124).
    /// 서버 목록에 없는 ID는 버린다(없는 ID를 지어내지 않는다).
    private var serverTagIDs: [Int64] {
        switch draft.source {
        case .custom:
            let known = Set(serverCourseTags.map(\.tagId))
            return draft.customCourseTagIDs.filter(known.contains)
        case .linked:
            return serverCourseTags.filter { draft.course.tags.contains($0.name) }.map(\.tagId)
        }
    }

    private func createRecruitment() {
        guard !isCreatingOnServer else { return }
        // 서버를 쓰는 중이면 **서버에 만들거나, 왜 못 만드는지 말하거나** 둘 중 하나다.
        // 예전에는 요청을 조립하지 못하면 조용히 `createLocalRecruitment()` 로 떨어져
        // 이 기기 안에만 있는 가짜 모집이 만들어졌다 — 호스트는 모집을 연 줄 알지만
        // 서버에는 없어 아무도 신청할 수 없었다 (2026-09-13).
        guard MoyeoServerSync.isEnabled else {
            createLocalRecruitment()
            return
        }
        if let invalid = ServerChatRoomCreateRequestBuilder.validationError(for: draft, tagIDs: serverTagIDs) {
            creationErrorMessage = invalid
            return
        }
        guard
            let selection = ServerChatRoomCreateRequestBuilder.courseSelection(for: draft, tagIDs: serverTagIDs),
            let request = ServerChatRoomCreateRequestBuilder.request(from: draft, course: selection)
        else {
            creationErrorMessage = "모집을 만들 수 없어요. 앞 단계의 값을 다시 확인해 주세요."
            return
        }
        // 대표 사진은 서버 필수 파트다. 없으면 **자리표시자를 대신 올리지 않고** 여기서 멈춘다.
        // (요약 화면이 이미 버튼을 잠그지만, 다른 진입로로 들어온 초안도 같은 규칙으로 막는다.)
        guard let thumbnail = thumbnailPart() else {
            creationErrorMessage = "대표 사진을 한 장 골라 주세요. 목록에 이 사진이 보여요."
            return
        }
        createOnServer(request, thumbnail: thumbnail)
    }

    /// 고른 사진을 multipart 파트로. JPEG 로 줄여 보낸다 — 서버가 저장 전에 FHD WebP 로 다시 바꾼다
    /// (18-6 모집 내용 수정과 같은 방식).
    private func thumbnailPart() -> MoyeoMultipartFile? {
        guard let data = roomThumbnail?.jpegData(compressionQuality: 0.9) else { return nil }
        return MoyeoMultipartFile(
            partName: "thumbnail",
            fileName: "thumbnail.jpg",
            mimeType: "image/jpeg",
            data: data
        )
    }

    private func createOnServer(_ request: ServerCreateChatRoomRequest, thumbnail: MoyeoMultipartFile) {
        isCreatingOnServer = true
        creationErrorMessage = nil
        Task {
            do {
                let response = try await ChatRoomAPIClient.shared.create(request: request, thumbnail: thumbnail)
                createdServerTrip = ServerTripMapper.placeholderTrip(
                    roomID: response.roomId,
                    title: draft.recruitmentName
                )
            } catch {
                creationErrorMessage = error.moyeoUserMessage(
                    fallback: "모집을 만들지 못했어요. 잠시 후 다시 시도해주세요."
                )
            }
            isCreatingOnServer = false
        }
    }

    /// 서버로 만들지 못했을 때 이 세션 안에서만 쓰는 모집. 참가자·호스트 이름은 서버 값이라
    /// 여기서 지어내지 않는다 — 비워 두면 화면이 그 줄을 그리지 않는다.
    private func createLocalRecruitment() {
        let id = "session-trip-\(UUID().uuidString)"
        let trip = TripRecruitment(
            id: id, courseID: draft.course.id, title: draft.recruitmentName, region: draft.course.region,
            coverMascot: draft.course.mascot, hostName: "", hostAvatar: "",
            schedule: draft.scheduleSummary, meetupPoint: draft.meeting.name, price: draft.estimatedCost,
            capacity: draft.capacity, joined: 1, minimumParticipants: draft.minimumParticipants,
            status: .open, summary: draft.note, vibe: "", tags: draft.course.tags,
            route: draft.itinerary.map(\.name), participants: [],
            courseSource: draft.source, itinerary: draft.itinerary, scheduleDetails: draft.schedule,
            meetingDetails: draft.meeting, recruitmentDeadline: draft.deadline,
            minimumAge: draft.minimumAge, maximumAge: draft.maximumAge,
            genderRestriction: draft.genderRestriction,
            routeEditState: draft.source == .custom ? .editable : .linkedLocked,
            serverCourseTitle: draft.displayCourseTitle
        )
        var thread = trip.createdChatThread(profile: .empty)
        thread.tripID = id
        thread.routeSummary = draft.itinerary
        thread.courseSource = draft.source
        thread.isCurrentUserHost = true
        onCreated(trip, thread)
        createdThread = thread
        createdTrip = trip
    }
}

private struct CreationHeader: View {
    let step: Int
    let back: () -> Void

    var body: some View {
        HStack {
            Button(action: back) {
                // ENV-009 — 44x44 틀은 있었지만 `contentShape` 가 없어 화살표 그림에만 반응했다
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("뒤로")
            Spacer()
            Text("모집 만들기 (\(step)/5)")
                .font(.system(size: 16, weight: .heavy))
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .foregroundStyle(MoyeoTheme.ink)
        .padding(.horizontal, 16)
        .frame(height: 56)
    }
}

struct CreationStepDots: View {
    let current: Int
    private let labels = ["코스", "일정", "인원", "세부", "리뷰"]
    private let icons = ["point.topleft.down.to.point.bottomright.curvepath", "calendar", "person.2", "doc.text", "star"]

    var body: some View {
        // 화면기획 17-x 공용 진행 단계 — 완료: 초록 테두리 원 + 초록 체크,
        // 현재: 틴트 원 + 초록 아이콘 + 초록 테두리, 미래: 회색 원 + 회색 아이콘.
        HStack {
            ForEach(labels.indices, id: \.self) { index in
                let isDone = index + 1 < current
                let isCurrent = index + 1 == current
                VStack(spacing: 5) {
                    Image(systemName: isDone ? "checkmark" : icons[index])
                        .font(.caption.weight(.bold))
                        .frame(width: 34, height: 34)
                        .foregroundStyle(isDone || isCurrent ? MoyeoTheme.brandText : MoyeoTheme.text400)
                        .background(isCurrent ? MoyeoTheme.leaf : MoyeoTheme.card)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(isDone || isCurrent ? MoyeoTheme.brandText : MoyeoTheme.line))
                    Text(labels[index])
                        .font(MoyeoTypography.font(size: 10, weight: .bold, relativeTo: .caption2))
                }
                .foregroundStyle(isDone || isCurrent ? MoyeoTheme.brandText : MoyeoTheme.text400)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
        .accessibilityIdentifier("createRecruitment.progress.\(current)of5")
    }
}

struct CreationFooter: View {
    let backTitle: String
    let nextTitle: String
    let back: () -> Void
    let next: () -> Void
    /// 채움 버튼을 누를 수 있는지. 못 누르면 회색으로 둔다.
    var isNextEnabled = true
    /// 화면마다 다른 접근성 식별자. 기본값은 모집 만들기 흐름의 것이다.
    var nextIdentifier = "createRecruitment.next"

    var body: some View {
        HStack(spacing: 14) {
            if !backTitle.isEmpty {
                // "코스 바꾸기"처럼 긴 라벨이 두 줄로 접히지 않게 폭을 내용에 맞춘다
                Button(action: back) {
                    Text(backTitle)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.ink)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 6)
                        .frame(minWidth: 56)
                        .frame(height: MoyeoTheme.ctaHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            // 꾸밈은 **버튼 라벨 안**에 둔다. 예전에는 `Button(nextTitle, action:)` 바깥에
            // `.frame`·`.background`·`.clipShape` 를 걸어, 초록 알약은 화면 폭만큼 그려지는데
            // **누를 수 있는 영역이 그 안에 생기지 않아** 눌러도 아무 일이 없었다.
            // 모집 만들기 1단계의 「이 코스로 다음」·「코스 만들러 가기」가 둘 다 죽어 있어
            // 이 화면에서 한 발짝도 나갈 수 없었다 (2026-09-14 기기에서 발견).
            Button(action: next) {
                Text(nextTitle)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: MoyeoTheme.ctaHeight)
                    .background(isNextEnabled ? MoyeoTheme.primary400 : MoyeoTheme.text400)
                    .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.ctaRadius))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isNextEnabled)
            .accessibilityIdentifier(nextIdentifier)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(MoyeoTheme.card)
        .overlay(alignment: .top) { Rectangle().fill(MoyeoTheme.softLine).frame(height: 1) }
    }
}

/// 모집 만들기 단계를 직접 열 때도 플로우와 같은 상단 단계 뷰와 하단 이전/다음을 갖게 한다.
/// 직접 실행 경로가 이 크롬을 건너뛰면 같은 단계인데도 화면 구조가 달라 보인다.
struct RecruitmentStepScaffold<Content: View>: View {
    let step: Int
    var nextTitle: String = "다음"
    var backTitle: String = "이전"
    /// 본문이 자체 CTA를 가진 단계(리뷰)에서는 하단 바를 두 번 그리지 않는다.
    var showsFooter = true
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            CreationStepDots(current: step)
            content
                .frame(maxHeight: .infinity)
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .navigationTitle("모집 만들기 (\(step)/5)")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if showsFooter {
                CreationFooter(
                    backTitle: backTitle,
                    nextTitle: nextTitle,
                    back: { dismiss() },
                    next: { dismiss() }
                )
            }
        }
    }
}

private struct RecruitmentSourceView: View {
    @Binding var draft: RecruitmentDraft
    let onOpenCustomEditor: () -> Void
    @State private var courseQuery = ""
    /// 등록된 코스 후보 — 서버 공개 코스뿐이다 (NO-MOCK-CANON R1)
    @State private var serverCourses: [TravelCourse] = []

    private var filteredCourses: [TravelCourse] {
        let query = courseQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return serverCourses }
        return serverCourses.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                DesignHeading("코스 선택", subtitle: "등록된 코스를 그대로 써도 되고, 직접 짜도 돼요.")
                SourceCard(source: .linked, selected: draft.source == .linked,
                           title: "등록된 코스로 떠나기",
                           detail: "검증된 동선을 기반으로 검증된 동선을 그대로 가져와요.",
                           note: "경로 수정 불가 · 집합 정보만 설정",
                           noteIcon: "lock.fill",
                           icon: "map.fill") {
                    draft.source = .linked
                }
                SourceCard(source: .custom, selected: draft.source == .custom,
                           title: "코스 직접 만들기",
                           detail: "방문지와 시간을 내가 짜요. 저장하면 다른 여행자에게도 코스로 노출돼요.",
                           note: "여행 확정 전까지 수정 가능",
                           noteIcon: "arrow.triangle.2.circlepath",
                           icon: "point.3.connected.trianglepath.dotted") {
                    draft.source = .custom
                }
                if draft.source == .linked {
                    LabelledSearchField(text: $courseQuery, prompt: "등록된 코스 검색")
                    if filteredCourses.isEmpty {
                        MoyeoEmptyStateView(
                            message: "아직 공개된 코스가 없어요.",
                            accessibilityIdentifier: "createSource.courses.empty"
                        )
                    } else {
                        VStack(spacing: 10) {
                            ForEach(filteredCourses.prefix(10)) { course in
                                linkedCourseRow(course)
                            }
                        }
                    }
                    DesignInfoBox(
                        icon: "lock.fill",
                        text: "등록된 코스는 방문지와 순서가 고정돼요. 대신 일정·집합 장소·인원 조건은 마감 전까지 자유롭게 바꿀 수 있어요.",
                        neutral: true
                    )
                } else {
                    Button("직접 만든 경로 편집", action: onOpenCustomEditor)
                        .buttonStyle(DesignOutlineButtonStyle())
                }
            }
            .padding(20)
        }
        .task {
            guard MoyeoServerSync.isEnabled, serverCourses.isEmpty else { return }
            serverCourses = (try? await TravelCourseAPIClient.shared.publicCourses())?
                .map(ServerCourseMapper.course(from:)) ?? []
        }
        .accessibilityIdentifier("screen.createSource")
    }

    private func linkedCourseRow(_ course: TravelCourse) -> some View {
        let selected = draft.course.id == course.id
        return Button {
            draft.course = course
            // 등록 코스는 방문지·순서가 코스에 딸려 온다 — 초안 경로도 그 좌표로 채운다.
            draft.itinerary = course.itinerary
        } label: {
            HStack(spacing: 10) {
                CachedRemoteImage(url: course.thumbnailURL, fallbackShape: .square) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    MoyeoTheme.leaf
                }
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.title)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.ink)
                        .lineLimit(1)
                    Text("\(course.duration) · 방문지 \(course.stops.count)")
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selected ? MoyeoTheme.forest : MoyeoTheme.text400)
            }
            .padding(8)
            .background(MoyeoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? MoyeoTheme.forest : MoyeoTheme.softLine)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("createSource.course.\(course.id)")
    }
}

private struct ApprovalModeCard: View {
    let mode: RecruitmentApprovalMode
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: mode.icon)
                    .frame(width: 42, height: 42)
                    .background(MoyeoTheme.leaf)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 5) {
                    Text(mode.rawValue).font(.subheadline.weight(.heavy))
                    Text(mode.detail).font(.caption.weight(.semibold)).foregroundStyle(MoyeoTheme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? MoyeoTheme.primary300 : MoyeoTheme.text400)
            }
            .foregroundStyle(MoyeoTheme.ink)
            .padding(14)
            .background(MoyeoTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(selected ? MoyeoTheme.primary300 : MoyeoTheme.line, lineWidth: selected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("createDetail.approval.\(mode.rawValue)")
    }
}

private struct SourceCard: View {
    let source: CourseSource
    let selected: Bool
    let title: String
    let detail: String
    let note: String
    let noteIcon: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(selected ? .white : MoyeoTheme.muted)
                    .frame(width: 38, height: 38)
                    .background(selected ? MoyeoTheme.forest : MoyeoTheme.leaf)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(MoyeoTypography.font(size: 13, weight: .bold, relativeTo: .subheadline))
                            .foregroundStyle(selected ? MoyeoTheme.onLeaf : MoyeoTheme.ink)
                        if selected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(MoyeoTheme.brandText)
                        }
                    }
                    Text(detail)
                        .font(MoyeoTypography.font(size: 11.5, relativeTo: .caption))
                        .foregroundStyle(MoyeoTheme.muted)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(note, systemImage: noteIcon)
                        .font(MoyeoTypography.font(size: 11, weight: .bold, relativeTo: .caption2))
                        .foregroundStyle(selected ? MoyeoTheme.brandText : MoyeoTheme.text400)
                        .padding(.top, 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(MoyeoTheme.ink)
            .padding(13)
            .background(selected ? MoyeoTheme.selectionSurface : MoyeoTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? MoyeoTheme.forest : MoyeoTheme.softLine, lineWidth: selected ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("createRecruitment.source.\(source.rawValue)")
    }
}

struct CustomCourseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding private var stops: [ItineraryStop]
    /// 코스 이름·태그는 서버 `customCourse` 의 **필수** 값이다. 예전에는 이 화면에 둘 다 없어서
    /// 커스텀 코스로 만든 모집이 요청 조립 단계에서 조용히 멈췄다 (IOS-F124).
    @Binding private var courseTitle: String
    @Binding private var selectedTagIDs: [Int64]
    /// `GET /travel-courses/tags` 로 받아 둔 서버 태그. 못 받았으면 **없는 태그를 지어내지 않고**
    /// 「불러오지 못했어요」를 적는다(웹·안드와 같은 규칙 — `CustomCourseTagPicker`).
    private let tags: [ServerCourseTag]
    private let onContinue: () -> Void
    /// 코스가 몇 날로 나뉘어 있는지. 예전에는 `includesNextDay: Bool` 이라 **둘째 날까지만** 되고,
    /// 그나마도 **일차 구역을 만들지 않아** 화면에는 「Day 1」 하나만 남았다. 그런데 새로 담는
    /// 방문지에는 `day: 2` 가 붙어 서버로 갔다 — **사용자가 보지 못한 일정이 저장됐다**(QA IOS-F104).
    /// 웹·안드로이드와 같은 구조(일차 수 + 담을 일차 선택)로 맞춘다.
    @State private var dayCount = 1
    @State private var activeDay = 1
    /// 방문 시각을 고치는 중인 방문지. 예전에는 고칠 길이 아예 없어 전부 `17:00` 으로 저장됐다.
    @State private var editingTimeStop: EditingStopTime?

    /// 일정은 최대 10일까지. 방문지 상한(20)보다 커질 이유가 없다 — 안드 `MAX_COURSE_DAYS` 와 같은 값이다.
    private static let maxDayCount = 10

    init(
        stops: Binding<[ItineraryStop]> = .constant([]),
        courseTitle: Binding<String> = .constant(""),
        selectedTagIDs: Binding<[Int64]> = .constant([]),
        tags: [ServerCourseTag] = [],
        onContinue: @escaping () -> Void = {}
    ) {
        _stops = stops
        _courseTitle = courseTitle
        _selectedTagIDs = selectedTagIDs
        self.tags = tags
        self.onContinue = onContinue
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    // ENV-009 — 44x44 틀은 있었지만 `contentShape` 가 없어 화살표 그림에만 반응했다
                    Image(systemName: "chevron.left")
                        .foregroundStyle(MoyeoTheme.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로")
                Spacer()
                Text("코스 직접 만들기").font(.headline.weight(.heavy))
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    RouteSchematic(stops: stops)
                    NavigationLink {
                        // 「N곳 담김」은 **지금 코스에 담긴 수**여야 한다 — 검색 화면이 따로 세면
                        // 담기지 않은 것(중복·20개 초과)까지 세어 카운터가 거짓말을 한다 (IOS-F120).
                        PlaceSearchView(onAdd: { place in add(place) }, addedCount: stops.count)
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "magnifyingglass")
                            // 검색어를 여기 되비추던 분기는 아무도 `search` 를 채우지 않아
                            // 늘 죽은 코드였다. 검색은 아래 시트 안에서 한다.
                            Text("방문지 검색")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MoyeoTheme.muted)
                        .padding(.horizontal, 13)
                        .frame(height: 48)
                        .background(MoyeoTheme.card)
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(MoyeoTheme.line))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("customCourse.placeSearch")
                    // 코스 이름·태그 — 서버가 둘 다 필수로 받는다. 없으면 모집을 만들 수 없다.
                    CustomCourseTitleField(title: $courseTitle)
                    CustomCourseTagPicker(tags: tags, selectedTagIDs: $selectedTagIDs)
                    HStack(alignment: .center) {
                        if dayCount == 1 {
                            Text("Day 1").font(.subheadline.weight(.heavy))
                        } else {
                            // 일차가 둘 이상이면 **어느 날에 담을지 골라야 한다.** 웹·안드도 같은 칩이다.
                            HStack(spacing: 6) {
                                ForEach(1...dayCount, id: \.self) { day in
                                    Button { activeDay = day } label: {
                                        Text("Day \(day)")
                                            .font(.caption.weight(.heavy))
                                            .foregroundStyle(day == activeDay ? Color.white : MoyeoTheme.brandText)
                                            .padding(.horizontal, 10)
                                            .frame(height: 28)
                                            .background(day == activeDay ? MoyeoTheme.forest : MoyeoTheme.leaf)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("customCourse.day\(day)")
                                    .accessibilityValue(day == activeDay ? "선택됨" : "")
                                }
                            }
                        }
                        Spacer()
                        Text("\(stops.count)개 방문지 · 최소 2개").font(.caption).foregroundStyle(MoyeoTheme.muted)
                    }
                    // 방문지를 **일차별로 나눠 그린다.** 예전에는 한 덩어리라, 담은 방문지가 몇 일차에
                    // 들어갔는지 화면에서 알 수 없었다.
                    ForEach(1...dayCount, id: \.self) { day in
                        let indices = stops.indices.filter { stops[$0].day == day }
                        if dayCount > 1 {
                            Text("Day \(day)")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(MoyeoTheme.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if indices.isEmpty {
                            Text("아직 담은 방문지가 없어요.")
                                .font(.caption)
                                .foregroundStyle(MoyeoTheme.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        ForEach(indices, id: \.self) { index in
                            ItineraryStopRow(stop: stops[index], canRemove: stops.count > 2,
                                             moveUp: { move(index, -1) }, moveDown: { move(index, 1) },
                                             remove: { stops.remove(at: index); normalize() },
                                             editTime: { editingTimeStop = EditingStopTime(id: stops[index].id) })
                        }
                    }
                    if !outOfOrderDays.isEmpty {
                        DesignInfoBox(
                            icon: "clock.badge.exclamationmark",
                            text: "\(outOfOrderDays.map { "Day \($0)" }.joined(separator: " · ")) 의 방문 시각이 순서와 어긋나요. "
                                + "되짚어 가는 일정이면 그대로 두셔도 돼요."
                        )
                    }
                    // 「방문지 추가」도 **장소 검색으로 보낸다.** 예전에는 여기서 contentId 없는
                    // 빈 「새 방문지」(UUID)를 만들었는데, 이름을 채울 길이 화면에 없어
                    // **어떤 경로로도 유효하게 만들 수 없는 방문지**가 생겼고, 마지막 「모집 열기」에서만
                    // 「방문지 검색에서 고른 곳이 아니라 보낼 수 없어요」로 막혔다 (IOS-F140).
                    NavigationLink {
                        PlaceSearchView(onAdd: { place in add(place) }, addedCount: stops.count)
                    } label: {
                        Label("방문지 추가", systemImage: "plus")
                    }
                    .buttonStyle(DesignOutlineButtonStyle(dashed: true))
                    .disabled(stops.count >= 20)
                    .accessibilityIdentifier("customCourse.addStop")
                    // 글자에 이미 '+'가 있으니 아이콘을 겹쳐 두지 않는다
                    // 마지막 일차만 늘린다 — 중간 일차를 지우면 남은 방문지의 일차가 어긋난다(웹과 같은 규칙).
                    Button {
                        guard dayCount < Self.maxDayCount else { return }
                        dayCount += 1
                        activeDay = dayCount
                    } label: {
                        Text(dayCount >= Self.maxDayCount ? "일정은 최대 10일까지예요" : "+ 다음 날 추가 (1박 이상일 때)")
                    }
                    .buttonStyle(DesignOutlineButtonStyle())
                    .disabled(dayCount >= Self.maxDayCount)
                    .accessibilityIdentifier("customCourse.addDay")
                    // 문구는 화면기획 17-1 을 그대로 쓴다 — 웹·안드로이드와 한 글자도 달라선 안 된다.
                    DesignInfoBox(icon: "sparkles", text: "직접 만든 코스는 여행이 확정되기 전까지 호스트가 언제든 고칠 수 있어요. 수정하면 채팅방 멤버 모두에게 알림이 가요.")
                }
                .padding(20)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                // 왜 못 누르는지 **버튼 바로 위에** 적는다. 잠가만 두면 화면을 뒤져도 이유를 알 수 없다.
                if let blockingReason {
                    Text(blockingReason)
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.dangerRed)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .accessibilityIdentifier("customCourse.blockingReason")
                }
                CreationFooter(
                    backTitle: "취소",
                    nextTitle: "이 코스로 계속하기",
                    back: { dismiss() },
                    next: {
                        dismiss()
                        onContinue()
                    },
                    // 방문지 2곳 이상 + 코스 이름 + 태그 1개 이상 — 셋 다 **서버가 요구하는 값**이다.
                    // 예전에는 방문지 수만 봤고, 이름·태그는 입력할 곳조차 없어서 다음 단계로 보낸 뒤
                    // 마지막 「모집 열기」에서 생성이 멈췄다 (IOS-F124).
                    isNextEnabled: blockingReason == nil
                )
            }
            .background(MoyeoTheme.card)
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        // 바를 감추면 UIKit 이 엣지 스와이프를 스스로 끈다 — 화면마다 되살린다 (TC NAV-017).
        .moyeoBackSwipeEnabled()
        .accessibilityIdentifier("screen.customCourse")
        .onAppear { restoreDayCount() }
        .sheet(item: $editingTimeStop) { editing in
            ItineraryTimeSheet(
                initial: stops.first { $0.id == editing.id }?.time ?? "10:00",
                onPick: { setTime($0, for: editing.id) }
            )
        }
    }

    /// 「이 코스로 계속하기」를 왜 못 누르는지 한국어 한 문장으로. 누를 수 있으면 nil 이다.
    /// 안드 `customCourseEditorError()` 와 같은 순서·같은 규칙이다 — 이 화면에서 눈으로 볼 수 있는
    /// 것만 본다(여행 일수와 코스 일차가 맞는지는 일정 단계를 지나야 알 수 있어 전송 직전에 본다).
    private var blockingReason: String? {
        if stops.count < 2 { return "방문지를 2곳 이상 담아 주세요." }
        if courseTitle.trimmingCharacters(in: .whitespaces).isEmpty { return "코스 이름을 적어 주세요." }
        if selectedTagIDs.isEmpty {
            return tags.isEmpty
                ? "코스 태그를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
                : "코스 태그를 하나 이상 골라 주세요."
        }
        return nil
    }

    /// 화면을 열 때 **담겨 있는 방문지의 일차까지 일차 수를 늘린다.**
    /// `dayCount` 가 늘 1 로 시작하던 탓에, Day 2 에 담아 둔 방문지가 있는 코스를 다시 열면
    /// Day 2 구역도 Day 탭도 그려지지 않아 **그 방문지가 화면에서 사라졌다.** 그런데 상단 카운터와
    /// 「모집 열기」 검사는 계속 세고 있어서, 보이지도 지울 수도 없는 방문지 때문에 모집이
    /// 영구히 막혔다 (IOS-F140).
    private func restoreDayCount() {
        let maxDay = stops.map(\.day).max() ?? 1
        dayCount = min(max(dayCount, maxDay), Self.maxDayCount)
        activeDay = min(max(activeDay, 1), dayCount)
    }

    private func add(_ place: TourismPlace) {
        guard stops.count < 20, !stops.contains(where: { $0.name == place.title }) else { return }
        let order = nextOrder(in: activeDay)
        stops.append(
            ItineraryStop(
                id: place.id,
                day: activeDay,
                order: order,
                time: Self.defaultTime(forOrder: order),
                name: place.title,
                memo: place.type.rawValue,
                // 서버로 보낼 때 쓰는 `contentId` 다. **여기에 담지 않으면** 요청 조립이
                // 「방문지 검색에서 고른 곳이 아니에요」로 막혀 **커스텀 코스를 한 건도 못 만든다**
                // (IOS-F134, 2026-09-13). `TourismPlace.id` 가 곧 `contentId` 다
                // (`TourismAPIClient` 가 `contentId` 를 그대로 `id` 로 읽는다).
                placeID: place.id,
                latitude: place.latitude,
                longitude: place.longitude
            )
        )
    }

    /// 담는 순서대로 **하루에 걸쳐 벌린다** — 10:00 부터 2시간 30분씩.
    /// 예전에는 무엇을 담아도 `17:00` 이라, 하루 일정이 전부 같은 시각으로 저장됐다
    /// (IOS-F121 · 웹 W-109 · 2026-09-12). 고칠 수단도 없었다.
    static func defaultTime(forOrder order: Int) -> String {
        let minutes = min(10 * 60 + (order - 1) * 150, 21 * 60)
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    /// 고른 시각을 그 방문지에 적는다.
    private func setTime(_ time: String, for stopID: String) {
        guard let index = stops.firstIndex(where: { $0.id == stopID }) else { return }
        stops[index].time = time
    }

    /// 같은 일차 안에서 시각이 순서를 거스르면 알려 준다 — 막지는 않는다.
    /// 되짚어 가는 일정도 있을 수 있으니 판단은 호스트에게 맡긴다.
    private var outOfOrderDays: [Int] {
        (1...max(dayCount, 1)).filter { day in
            let times = stops.filter { $0.day == day }.sorted { $0.order < $1.order }.map(\.time)
            return times != times.sorted()
        }
    }

    private func move(_ index: Int, _ offset: Int) {
        let destination = index + offset
        guard stops.indices.contains(destination) else { return }
        stops.swapAt(index, destination)
        normalize()
    }

    /// 같은 일차 안에서 다음 순서. 서버 `sequence` 는 **그 일차 안의 순번**이다
    /// (`CustomCoursePlaceRequest.sequence` — 「같은 일차 안의 방문 순서. 1부터 시작합니다.」).
    private func nextOrder(in day: Int) -> Int {
        stops.filter { $0.day == day }.count + 1
    }

    /// 순서를 **일차별로** 다시 매긴다. 예전에는 `order = index + 1` 로 전역 번호를 넣어서,
    /// Day 2 첫 방문지의 `sequence` 가 1 이 아니라 3 처럼 나갔다.
    private func normalize() {
        for day in 1...max(dayCount, 1) {
            var order = 1
            for index in stops.indices where stops[index].day == day {
                stops[index].order = order
                order += 1
            }
        }
    }
}

struct RecruitmentScheduleView: View {
    @Binding var draft: RecruitmentDraft
    /// 날짜·시각을 고르는 시트. 예전에는 이 줄들이 화살표만 있고 동작이 없었다.
    @State private var editor: RecruitmentFieldEditor?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DesignHeading("일정 정하기", subtitle: "당일치기인지 먼저 골라주세요. 입력하는 항목이 달라져요.")
                DesignSegment(
                    items: TripScheduleKind.allCases,
                    selected: $draft.schedule.kind,
                    subtitles: ["당일치기": "시작·종료 시간", "1박 이상": "시작·종료 날짜"]
                )
                DesignField(label: draft.schedule.kind == .dayTrip ? "여행 날짜 *" : "여행 시작 날짜 *",
                            icon: "calendar", value: draft.schedule.startDate,
                            placeholder: "날짜 고르기",
                            action: { editor = .startDate })
                    .accessibilityIdentifier("createSchedule.startDate")
                if draft.schedule.kind == .dayTrip {
                    HStack(spacing: 10) {
                        DesignField(label: "여행 시작 시간 *", icon: "clock",
                                    value: draft.schedule.startTime ?? "",
                                    placeholder: "시간 고르기",
                                    action: { editor = .startTime })
                            .accessibilityIdentifier("createSchedule.startTime")
                        DesignField(label: "여행 종료 시간 *", icon: "clock",
                                    value: draft.schedule.endTime ?? "",
                                    placeholder: "시간 고르기",
                                    action: { editor = .endTime })
                            .accessibilityIdentifier("createSchedule.endTime")
                    }
                    // 요약은 호스트가 고른 값에서 만든다 — 예전에는 `5/25(토) 08:00 - 18:00` 이
                    // 무엇을 고르든 그대로 남는 지어낸 문장이었다.
                    if !dayTripSummary.isEmpty {
                        DesignSummaryLine(dayTripSummary)
                    }
                } else {
                    DesignField(label: "여행 종료 날짜 *", icon: "calendar",
                                value: draft.schedule.endDate ?? "",
                                placeholder: "날짜 고르기",
                                action: { editor = .endDate })
                        .accessibilityIdentifier("createSchedule.endDate")
                }
                Divider().overlay(MoyeoTheme.softLine)
                DesignField(label: "모집 마감일 *", icon: "clock", value: draft.deadline,
                            placeholder: "마감일 고르기",
                            action: { editor = .deadline })
                    .accessibilityIdentifier("createSchedule.deadline")
                Text("출발 3일 전까지만 선택할 수 있어요. 마감일에 최소 인원을 못 채우면 자동으로 소멸해요.")
                    .font(.caption).foregroundStyle(MoyeoTheme.muted)
                // 집합 장소·시간은 다음 단계(15 집합 장소 정하기)에서 지도로 정한다 —
                // 여기서는 정해진 값을 되짚어 보여주기만 한다. 그래서 화살표를 그리지 않는다.
                DesignField(label: "집합 장소 · 집합 시간 *", icon: "mappin.and.ellipse",
                            value: draft.meetingSummary, detail: draft.meeting.address,
                            placeholder: "다음 단계에서 정해요")
                    .accessibilityIdentifier("createSchedule.meeting")
            }
            .padding(20)
        }
        .background(MoyeoTheme.background)
        .accessibilityIdentifier("screen.createSchedule")
        .sheet(item: $editor) { field in
            RecruitmentFieldSheet(field: field, draft: $draft) { editor = nil }
                .presentationDetents([.height(field.shape == .date ? 520 : 340)])
                .presentationCornerRadius(24)
                .presentationBackground(MoyeoTheme.card)
        }
    }

    /// 당일치기 요약 — 날짜·시간이 다 채워졌을 때만 만든다(부분 값으로 문장을 흉내내지 않는다).
    private var dayTripSummary: String {
        guard
            let startTime = draft.schedule.startTime, !startTime.isEmpty,
            let endTime = draft.schedule.endTime, !endTime.isEmpty,
            !draft.schedule.startDate.isEmpty
        else { return "" }
        return "당일치기   \(draft.schedule.startDate) \(startTime) - \(endTime)"
    }
}

private struct RecruitmentPeopleView: View {
    @Binding var draft: RecruitmentDraft
    /// 나이대 제한을 고치는 시트. 예전에는 화살표만 있고 동작이 없었다.
    @State private var editor: RecruitmentFieldEditor?

    // 최대 인원에 따라 분위기 안내가 달라진다 (화면기획과 같은 구간)
    private var moodText: String {
        switch draft.capacity {
        case ...4: "말 트기 좋은 작은 그룹이에요"
        case 5...8: "단체 사진 예쁘게 나오는 최적 인원이에요"
        default: "9명 이상은 친목이 쉽지 않을 수 있어요"
        }
    }

    private var moodIsWarning: Bool { draft.capacity > 8 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DesignHeading(
                    "몇 명이 모이면 좋을까요?",
                    subtitle: "최소 인원은 3명부터예요. 낯선 사람과 단둘이 되는 일은 생기지 않아요."
                )

                // 최소 / 최대는 좌우로 나란히 (화면기획 기준)
                HStack(alignment: .top, spacing: 10) {
                    PeopleStepper(
                        label: "최소 인원",
                        value: draft.minimumParticipants,
                        hint: "3명 미만은 선택할 수 없어요",
                        onMinus: { draft.minimumParticipants = max(3, draft.minimumParticipants - 1) },
                        onPlus: { draft.minimumParticipants = min(draft.capacity - 1, draft.minimumParticipants + 1) }
                    )
                    PeopleStepper(
                        label: "최대 인원",
                        value: draft.capacity,
                        hint: "최대 20명까지",
                        onMinus: { draft.capacity = max(draft.minimumParticipants + 1, draft.capacity - 1) },
                        onPlus: { draft.capacity = min(20, draft.capacity + 1) }
                    )
                }

                // 모집 카드 미리보기 — 인원 설정이 신청자에게 어떻게 보이는지 같은 컴포넌트로 확인한다
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text("모집 카드에는 이렇게 보여요")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(MoyeoTheme.ink)
                        Spacer()
                        Text("\(draft.minimumParticipants) / \(draft.capacity)명 · 최소 충족")
                            .font(.caption)
                            .foregroundStyle(MoyeoTheme.text400)
                            .monospacedDigit()
                    }
                    ProgressBar(
                        value: Double(draft.minimumParticipants) / Double(max(draft.capacity, 1)),
                        marker: Double(draft.minimumParticipants) / Double(max(draft.capacity, 1))
                    )
                    Text(moodText)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(moodIsWarning ? MoyeoTheme.warningText : MoyeoTheme.onLeaf)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MoyeoTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.softLine))
                .accessibilityIdentifier("createPeople.cardPreview")

                VStack(alignment: .leading, spacing: 8) {
                    Text("성별 제한")
                        .font(.subheadline.weight(.heavy))
                    DesignSegment(
                        items: RecruitmentGenderCondition.allCases,
                        selected: Binding(
                            get: { RecruitmentGenderCondition(rawValue: draft.genderRestriction) ?? .any },
                            set: { draft.genderRestriction = $0.rawValue }
                        )
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("나이대 제한")
                        .font(.subheadline.weight(.heavy))
                    DesignField(
                        label: "",
                        icon: "person.2",
                        value: draft.ageRangeText,
                        action: { editor = .ageRange }
                    )
                    .accessibilityIdentifier("createPeople.ageRange")
                    // 화면기획 17-4 — 설명은 행 안이 아니라 행 아래 캡션이다
                    Text("최소·최대 모두 \(RoomConditionAgePolicy.rangeText)세 사이에서 정할 수 있어요. 조건에 맞지 않는 사용자에게는 신청 버튼이 비활성으로 보여요.")
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("createPeople.ageCaption")
                }
            }
            .padding(20)
        }
        .accessibilityIdentifier("screen.createPeople")
        .sheet(item: $editor) { field in
            RecruitmentFieldSheet(field: field, draft: $draft) { editor = nil }
                .presentationDetents([.height(340)])
                .presentationCornerRadius(24)
                .presentationBackground(MoyeoTheme.card)
        }
    }
}

/// 화면기획의 인원 스테퍼 — 좌측 원형 감소, 가운데 값, 우측 브랜드색 증가.
private struct PeopleStepper: View {
    let label: String
    let value: Int
    let hint: String
    let onMinus: () -> Void
    let onPlus: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)
            HStack(spacing: 8) {
                Button(action: onMinus) {
                    Image(systemName: "minus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MoyeoTheme.text700)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(MoyeoTheme.line))
                }
                .buttonStyle(.plain)
                // ENV-006: 라벨이 없으면 VoiceOver 가 심볼 이름(「minus」)을 그대로 읽는다.
                .accessibilityLabel("\(label) 줄이기")

                Text("\(value)명")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)

                Button(action: onPlus) {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(MoyeoTheme.forest)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                // ENV-006: 라벨이 없으면 VoiceOver 가 심볼 이름(「plus」)을 그대로 읽는다.
                .accessibilityLabel("\(label) 늘리기")
            }
            .padding(.horizontal, 8)
            .frame(height: 48)
            .background(MoyeoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))

            Text(hint)
                .font(.caption2)
                .foregroundStyle(MoyeoTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RecruitmentMeetingView: View {
    @Binding var draft: RecruitmentDraft
    /// 상세 안내는 호스트가 적는 값이다 — 미리 채워 두면 남이 적은 안내가 내 초안처럼 보인다.
    @State private var detail = ""
    /// 집합 시간을 고치는 시트. 예전에는 화살표만 있고 동작이 없었다.
    @State private var editor: RecruitmentFieldEditor?
    /// 검색으로 이름을 정한 뒤 핀을 끌었는지. 끌었다면 이름·주소가 그 좌표를 가리키지 않는다 (IOS-F145).
    @State private var didMovePinAfterPick = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                DesignHeading("집합 장소 정하기", subtitle: "검색하거나 지도의 핀을 움직여 정확한 위치를 알려주세요.")
                ZStack(alignment: .top) {
                    MeetingMapCard(meeting: $draft.meeting, onMoved: pinDidMove)
                        .accessibilityIdentifier("createMeeting.map")
                        // 웹 · 안드로이드와 같은 자리(좌측 하단 14) · 같은 문구의 안내 칩이다.
                        .overlay(alignment: .bottomLeading) {
                            Text("핀을 끌어 위치를 조정하세요")
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(MoyeoTheme.text700)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(MoyeoTheme.card)
                                .overlay(Capsule().stroke(MoyeoTheme.line))
                                .clipShape(Capsule())
                                .padding(14)
                                .accessibilityIdentifier("createMeeting.pinHint")
                        }
                    // 검색해 고른 장소는 이름·주소·좌표를 한꺼번에 초안에 넣는다.
                    // 좌표가 바뀌면 위의 지도도 그 자리로 따라간다(`MoyeoMapView` 가 중심을 다시 잡는다).
                    MeetingPlaceSearchField(onSelect: applyPickedPlace)
                        .padding(12)
                }
                // 장소 이름은 위의 검색·지도 핀이 정한다 — 이 줄은 그 결과를 보여주는 자리라
                // 화살표를 그리지 않는다(누를 곳이 아니다).
                DesignField(label: "집합 장소 *", icon: "mappin.and.ellipse",
                            value: draft.meeting.name,
                            placeholder: "지도에서 핀을 옮겨 정해주세요")
                    .accessibilityIdentifier("createMeeting.placeName")
                // 핀을 옮기면 이름이 그 자리를 가리키지 않는다 — **말없이 두지 않고 적는다** (IOS-F145).
                if didMovePinAfterPick {
                    Text("핀을 옮겨서 「\(draft.meeting.name)」 위치와 달라졌어요. 이 이름 그대로 저장되니, 다른 곳이면 다시 검색해 주세요.")
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("createMeeting.pinMovedNotice")
                }
                // changeLog15 — 상세 안내는 추천 칩이 아니라 자유 텍스트 입력이다.
                VStack(alignment: .leading, spacing: 7) {
                    Text("상세 안내")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.text700)
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text")
                            .foregroundStyle(MoyeoTheme.muted)
                        TextField("만나는 위치를 자세히 남겨주세요 (예: 터미널 정문 앞)", text: $detail)
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(MoyeoTheme.ink)
                            .textInputAutocapitalization(.never)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 50)
                    .background(MoyeoTheme.card)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(MoyeoTheme.line))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .accessibilityIdentifier("createMeeting.detailInput")
                // 좌표 문자열은 화면에 내보이지 않는다 (21·15·17-1a·17-1b 에서 뺀 것과 같다).
                // 핀 위치는 지도가 보여주고, 값은 초안에 그대로 저장된다.
                DesignField(label: "집합 시간", icon: "clock", value: draft.meeting.meetingTime,
                            placeholder: "시간 고르기",
                            action: { editor = .meetingTime })
                    .accessibilityIdentifier("createMeeting.meetingTime")
                DesignInfoBox(icon: "bell.fill", text: "집합 시간 30분 전에 모든 멤버에게 알림이 가고, 채팅방 상단 공지에도 자동으로 올라가요.")
            }
            .padding(20)
        }
        // 검색칸에 글자를 넣으면 키보드가 「집합 장소 *」를 가렸는데, 닫을 길이 없었다 (IOS-F136).
        .scrollDismissesKeyboard(.interactively)
        .moyeoKeyboardDismissable()
        .background(MoyeoTheme.background)
        .accessibilityIdentifier("screen.createMeeting")
        // 호스트가 적은 상세 안내를 초안에 담는다 — 예전에는 화면에만 남고 버려졌다.
        .onChange(of: detail) { _, newValue in draft.meeting.detail = newValue }
        .sheet(item: $editor) { field in
            RecruitmentFieldSheet(field: field, draft: $draft) { editor = nil }
                .presentationDetents([.height(340)])
                .presentationCornerRadius(24)
                .presentationBackground(MoyeoTheme.card)
        }
    }

    /// 검색으로 고른 장소를 집합 장소로 삼는다.
    /// 좌표는 결과에 좌표가 있는 장소만 고를 수 있어(`MeetingPlaceSearchField`) 늘 채워진다.
    private func applyPickedPlace(_ place: TourismPlace) {
        draft.meeting.name = place.title
        draft.meeting.address = place.address ?? ""
        if let latitude = place.latitude, let longitude = place.longitude {
            draft.meeting.latitude = latitude
            draft.meeting.longitude = longitude
        }
        didMovePinAfterPick = false
    }

    /// 핀이 움직였다. 주소는 **확실히 틀린 값**이 되므로 지우고, 이름은 호스트가 판단하도록
    /// 남겨 둔 채 달라졌다는 사실을 화면에 적는다 (IOS-F145).
    private func pinDidMove() {
        draft.meeting.address = ""
        didMovePinAfterPick = !draft.meeting.name.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

private struct RecruitmentDetailView: View {
    @Binding var draft: RecruitmentDraft
    /// 예상 비용을 고치는 시트. 예전에는 화살표만 있고 동작이 없었다.
    @State private var editor: RecruitmentFieldEditor?

    /// 모집 이름 한도. **모집 내용 수정(18-6)의 `titleLimit` 과 같은 값**이어야 한다 —
    /// 다르면 생성 때 지은 제목을 나중에 고칠 수 없다 (IOS-F123).
    ///
    /// **서버가 받는 값(`CreateChatRoomRequest.title` · `@Size(max = 100)`)과 같은 100 이다.**
    /// 예전에는 24 로 막고 있어서, 서버가 받아 주는 제목을 앱이 미리 잘라 버렸다
    /// (2026-09-14 결정 ②).
    private static let recruitmentNameLimit = 100

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                DesignHeading("어떤 여행인지 알려주세요", subtitle: "신청 전에 가장 많이 읽는 부분이에요.")
                // 잠긴 줄이다 — 화살표를 그리지 않는다. 안내 문구가 "바꿀 수 없어요" 라고 하는데
                // 화살표가 있어서 눌러도 되는 것처럼 보였다.
                DesignField(
                    label: "코스",
                    icon: "lock.fill",
                    value: draft.displayCourseTitle,
                    detail: "Step 1에서 고른 코스 이름이에요. 여기서는 바꿀 수 없어요.",
                    detailBelowField: true
                )
                .accessibilityIdentifier("createDetail.course")
                VStack(alignment: .leading, spacing: 8) {
                    Text("모집 이름 (채팅방 이름) *")
                        .font(.subheadline.weight(.heavy))
                    TextField("어떤 사람들과 어떻게 떠날지 적어주세요", text: $draft.recruitmentName)
                        .textInputAutocapitalization(.never)
                        .designInput()
                        .accessibilityIdentifier("createDetail.recruitmentName")
                        // 여기에 한도가 없어서, 생성 때 지은 25자 이상 제목은 나중에
                        // 모집 내용 수정(24자)에서 **한 글자도 고칠 수 없었다** (IOS-F123).
                        .onChange(of: draft.recruitmentName) { _, value in
                            if value.count > Self.recruitmentNameLimit {
                                draft.recruitmentName = String(value.prefix(Self.recruitmentNameLimit))
                            }
                        }
                    Text("\(draft.recruitmentName.count) / \(Self.recruitmentNameLimit)")
                        .font(.caption2)
                        .foregroundStyle(MoyeoTheme.text400)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityIdentifier("createDetail.recruitmentNameCounter")
                    Text("코스 이름과 별개로 여행 분위기를 담아요. 채팅방 이름으로도 쓰여요.")
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.muted)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("소개글")
                        .font(.subheadline.weight(.heavy))
                    TextEditor(text: $draft.note)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 96)
                        .background(MoyeoTheme.card)
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(MoyeoTheme.line))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    // 화면기획·웹·안드로이드처럼 글자 수를 오른쪽 아래에 둔다
                    Text("\(draft.note.count) / 500")
                        .font(.caption2)
                        .foregroundStyle(MoyeoTheme.text400)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityIdentifier("createDetail.noteCounter")
                }
                // 코스별 예상 비용을 주는 API가 없다 — "보통 4~5만원" 같은 근거 없는 금액 안내는 하지 않는다.
                // 안내 문구는 기획·웹·안드로이드와 같은 문장이다.
                DesignField(label: "예상 1인당 비용", icon: "wonsign.circle", value: draft.estimatedCost,
                            detail: "정하지 않았으면 비워 두세요. 참고용으로만 보여줘요.",
                            detailBelowField: true,
                            placeholder: "비워 두면 참가비 없음",
                            action: { editor = .estimatedCost })
                    .accessibilityIdentifier("createDetail.estimatedCost")
                // 화면기획은 세그먼트가 아니라 설명이 붙은 선택 카드 두 장이다
                VStack(alignment: .leading, spacing: 8) {
                    Text("신청 승인 방식")
                        .font(.subheadline.weight(.heavy))
                    ForEach(RecruitmentApprovalMode.allCases, id: \.self) { mode in
                        ApprovalModeCard(mode: mode, selected: draft.approvalMode == mode) {
                            draft.approvalMode = mode
                        }
                    }
                }
                DesignInfoBox(icon: "person.badge.shield.checkmark", text: "마감 전까지 세부 조건을 수정할 수 있고 변경 내용은 신청자에게 안내돼요.")
            }
            .padding(20)
        }
        // 키보드를 닫을 길을 준다 — 없으면 소개글을 쓴 뒤 참가비·승인 방식에 손이 닿지 않는다 (IOS-F136).
        .scrollDismissesKeyboard(.interactively)
        .moyeoKeyboardDismissable()
        .background(MoyeoTheme.background)
        .accessibilityIdentifier("screen.createDetail")
        .sheet(item: $editor) { field in
            RecruitmentFieldSheet(field: field, draft: $draft) { editor = nil }
                .presentationDetents([.height(340)])
                .presentationCornerRadius(24)
                .presentationBackground(MoyeoTheme.card)
        }
    }
}

struct RecruitmentSummaryView: View {
    @Binding var draft: RecruitmentDraft
    /// 대표 사진. 서버 `thumbnail` 파트가 필수라 **고르기 전에는 모집을 열 수 없다**.
    @Binding var thumbnail: UIImage?
    /// 서버 생성이 실패했을 때만 채워진다 — 서버가 준 문구를 그대로 보여준다.
    var errorMessage: String?
    var isSubmitting = false
    let onBack: () -> Void
    let onCreate: () -> Void

    /// 왜 「모집 열기」를 못 누르는지. 누를 수 있으면 nil 이다.
    private var blockingReason: String? {
        thumbnail == nil ? "대표 사진을 한 장 골라 주세요. 목록에 이 사진이 보여요." : nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                DesignHeading("이대로 모집을 열까요?", subtitle: "등록 후에도 마감 전까지는 대부분 고칠 수 있어요.")
                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(draft.recruitmentName).font(.subheadline.weight(.heavy))
                            Label(draft.displayCourseTitle, systemImage: "map.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MoyeoTheme.muted)
                        }
                        Spacer()
                        Pill(text: draft.source.title)
                            .accessibilityIdentifier("createSummary.source")
                    }
                    // **값이 없는 줄은 그리지 않는다.** 라벨만 있고 값이 빈 줄은
                    // 「정보가 빠졌다」로 읽힌다 — 17-6 의 「마감」이 그렇게 비어 있었다
                    // (사용자 지적 2026-09-09).
                    //
                    // 좌표 줄은 **없앤다** — 위경도는 사용자가 읽을 값이 아니다
                    // (17-3 에서 네 표면 다 뺀 것과 같은 이유).
                    SummaryRow("calendar", "일정", draft.scheduleSummary)
                    SummaryRow("mappin.and.ellipse", "집합", draft.meetingSummary)
                    SummaryRow("person.2", "인원", "최소 \(draft.minimumParticipants)명 · 최대 \(draft.capacity)명")
                    SummaryRow("slider.horizontal.3", "조건", "\(draft.ageRangeText) · \(draft.genderSummary)")
                    SummaryRow("wonsign.circle", "비용", draft.estimatedCostSummary)
                    SummaryRow("clock", "마감", draft.deadlineSummary)
                }
                .padding(16)
                .background(MoyeoTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(MoyeoTheme.softLine))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                DesignInfoBox(
                    icon: draft.source == .custom ? "sparkles" : "lock.fill",
                    text: draft.source == .custom
                        ? "호스트가 직접 만든 코스예요. 여행이 확정되기 전까지 방문지·시간·순서를 자유롭게 고칠 수 있고, 수정하면 멤버 모두에게 알림이 가요."
                        : "서비스에 등록된 코스를 그대로 가져왔어요. **경로(방문지·순서)는 수정할 수 없고**, 일정·집합 장소·인원 조건은 마감 전까지 바꿀 수 있어요.",
                    neutral: draft.source == .linked
                )
                // 대표 사진 — 서버 필수 파트다. 웹 `create-room-thumbnail-pick` 과 같은 자리에 둔다.
                RecruitmentThumbnailPicker(image: $thumbnail)
                // 화면기획 17-7 — 두 번째 안내 카드는 아이콘 없이 텍스트만 둔다
                DesignInfoBox(icon: nil, text: "최소 \(draft.minimumParticipants)명이 모이면 채팅방이 자동으로 열리고, 마감일까지 못 채우면 자연스럽게 소멸돼요.")
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                // 실패 이유와 잠근 이유는 **버튼 바로 위**에 적는다. 예전에는 본문 끝에 둬서
                // 스크롤 밖으로 밀렸고, 「모집 열기」를 눌러도 **아무 일도 안 일어나는 것처럼**
                // 보였다 — 앱은 이유를 만들어 두고 보여 주지 못했다 (IOS-F134, 2026-09-13).
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.dangerRed)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .accessibilityIdentifier("createSummary.error")
                }
                if let blockingReason, errorMessage == nil {
                    Text(blockingReason)
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.dangerRed)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .accessibilityIdentifier("createSummary.blockingReason")
                }
                CreationFooter(
                    backTitle: "이전",
                    nextTitle: isSubmitting ? "모집 여는 중" : "모집 열기",
                    back: onBack,
                    next: onCreate,
                    isNextEnabled: blockingReason == nil && !isSubmitting
                )
                .disabled(isSubmitting)
            }
            .background(MoyeoTheme.card)
        }
        .accessibilityIdentifier("screen.createSummary")
    }
}

struct CourseRouteEditView: View {
    let trip: TripRecruitment
    let state: RouteEditState
    let onSaved: (TripRecruitment, [ItineraryStop]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var stops: [ItineraryStop]
    @State private var showNoticeComposer = false
    /// 18-5 집합 정보 수정으로 가는 길. 등록 코스라 경로는 못 고쳐도 집합은 고칠 수 있다.
    @State private var showMeetingInfoEdit = false
    /// 여행 일수는 모집 상세에만 있다(`GET /chat-rooms/{id}` 의 `tripDays`).
    /// 서버 규칙을 저장 전에 같은 말로 검사하려면 이 값이 있어야 한다.
    @State private var serverTripDays: Int?
    @State private var isSaving = false
    /// 저장을 막은 이유 또는 서버가 준 오류. 없으면 nil 이다.
    @State private var saveError: String?

    /// 이 모임이 실제로 가진 집합 시간·장소만 잇는다. 없는 값은 지어내지 않는다.
    private var meetingSummary: String {
        let time = trip.meetingDetails?.meetingTime ?? ""
        return [time, trip.meetupPoint].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    init(trip: TripRecruitment, state: RouteEditState? = nil,
         onSaved: @escaping (TripRecruitment, [ItineraryStop]) -> Void = { _, _ in }) {
        self.trip = trip
        self.state = state ?? trip.routeEditState
        self.onSaved = onSaved
        // 일정(`itinerary`)이 없는 모임은 이름만 있는 `route` 로 행을 세운다.
        // 방문 시각과 메모는 **서버가 준 값이 없으므로 비워 둔다** — 예전에는
        // `09:00 · 10:30 · 14:00 · 16:30` 과 「방문 장소」를 지어내, 호스트가 정한 적 없는
        // 시각이 화면에 떴다 (NO-MOCK-CANON R1 · R3).
        let route = trip.itinerary.isEmpty ? trip.route.enumerated().map {
            ItineraryStop(id: "\(trip.id)-\($0.offset)", day: 1, order: $0.offset + 1,
                          time: "", name: $0.element, memo: "")
        } : trip.itinerary
        _stops = State(initialValue: route)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // 색을 직접 준다 — 안 주면 시스템 강조색(파랑)이 나온다.
                // 「AccentColor」 자산도 브랜드 초록으로 채웠지만, 상단바 아이콘은
                // 기획·웹·안드로이드처럼 **글자색**이라 여기서 못박는다 (18-1, 2026-09-09).
                Button { dismiss() } label: {
                    // ENV-009 — 44x44 틀은 있었지만 `contentShape` 가 없어 화살표 그림에만 반응했다
                    Image(systemName: "chevron.left")
                        .foregroundStyle(MoyeoTheme.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                // ENV-006: 라벨이 없으면 VoiceOver 가 영어 시스템 문구(「Back」)로 읽는다.
                .accessibilityLabel("뒤로")
                Spacer()
                Text("여행 경로").font(.headline.weight(.heavy))
                Spacer()
                if state == .editable {
                    Button(isSaving ? "저장 중" : "저장") { save() }
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(isSaving ? MoyeoTheme.text400 : MoyeoTheme.primary300)
                        .disabled(isSaving)
                        .frame(width: 52)
                } else {
                    // 고칠 수 없는 방에는 **아무것도 두지 않는다** — 예전에는 이 자리에 ⋯ 아이콘이
                    // 남아 있어 눌러도 아무 일이 없었고, 화면 낭독기에는 이름 없는 요소로 잡혔다
                    // (TC HOST-034). 웹도 같은 이유로 이 자리를 비웠다(W-143). 여기서 열 메뉴가 없다.
                    // 제목을 가운데로 유지하려고 뒤로 버튼과 같은 폭만 남긴다.
                    Color.clear.frame(width: 44, height: 1)
                }
            }
            .padding(.horizontal, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading) {
                            // 화면기획 18-x — 헤더는 모집 이름이 아니라 코스 이름이다
                            Text(headerTitle).font(.subheadline.weight(.heavy))
                            Text(headerSubtitle).font(.caption).foregroundStyle(MoyeoTheme.muted)
                        }
                        Spacer()
                        // 등록 코스는 자물쇠를 함께 보여 "경로 고정"을 배지에서 바로 읽게 한다
                        CourseSourceBadge(source: displaySource)
                    }
                    policyNotice
                    RouteSchematic(stops: stops)
                    // 일차마다 머리글을 두고 그 아래에 그 일차 방문지만 그린다. 예전에는 「Day 1」
                    // 하나에 2일차 방문지까지 쏟아 넣고 번호도 통번호라, 2일차 첫 방문지가 화면엔
                    // 「3」인데 서버엔 `sequence 1` 로 저장돼 어긋나 보였다.
                    // 같은 파일의 코스 에디터(`screen.customCourse`)는 이미 이렇게 그린다.
                    ForEach(dayNumbers, id: \.self) { day in
                        HStack {
                            Text("Day \(day)").font(.subheadline.weight(.heavy))
                            Spacer()
                            if state != .editable {
                                Label("수정 불가", systemImage: "lock")
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(MoyeoTheme.muted)
                                    .accessibilityIdentifier("courseEdit.readOnlyBadge")
                            }
                        }
                        let indices = stops.indices.filter { stops[$0].day == day }
                        ForEach(indices, id: \.self) { index in
                            ItineraryStopRow(
                                // 번호는 일차별 1부터다 — 서버 `sequence` 가 그 일차 안의 순번이다.
                                stop: numbered(stops[index], order: roomCourseDayOrder(stops, at: index)),
                                canRemove: state == .editable && stops.count > 2,
                                locked: state != .editable,
                                // 순서 바꾸기는 **같은 일차 안에서만** 한다 — 일차 경계를 넘기면
                                // 방문지의 `day` 가 화면에 보이는 자리와 어긋난다(웹·안드로이드와 같은 규칙).
                                moveUp: { if index != indices.first { move(index, -1) } },
                                moveDown: { if index != indices.last { move(index, 1) } },
                                remove: { remove(at: index) }
                            )
                        }
                        // 방문지 추가는 **일차마다** 둔다 — 어느 날에 담기는지 자리로 알 수 있고,
                        // 순서 바꾸기가 일차 경계를 넘지 못하므로 담은 뒤에 날을 옮길 수도 없다.
                        if state == .editable {
                            NavigationLink {
                                PlaceSearchView(onAdd: { place in add(place, to: day) }, addedCount: stops.count)
                            } label: {
                                Label("Day \(day)에 방문지 추가", systemImage: "plus")
                            }
                            .buttonStyle(DesignOutlineButtonStyle(dashed: true))
                            .disabled(stops.count >= RoutePolicy.maximumStopCount)
                            .accessibilityIdentifier("courseEdit.addPlace.day\(day)")
                        }
                    }
                    // 무엇이 모자라 저장이 막혔는지 그 자리에 적는다 — 400 을 받아
                    // 「요청이 올바르지 않습니다」로 넘기지 않는다.
                    if let saveError {
                        Text(saveError)
                            .font(.caption)
                            .foregroundStyle(MoyeoTheme.dangerRed)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("courseEdit.saveError")
                    }
                    if state == .editable {
                        Text("방문지는 일차마다 2곳 이상, 모두 합쳐 \(RoutePolicy.maximumStopCount)곳까지 담을 수 있어요. 코스 이름과 소개는 「코스 이름 수정」에서 바꿔요.")
                            .font(.caption)
                            .foregroundStyle(MoyeoTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("집합 정보").font(.headline.weight(.heavy))
                    // 17-7 은 경로 편집 화면이다 — 집합 정보는 하단 「집합 정보 수정」이 고친다.
                    // 그래서 이 줄은 읽기 전용이고 화살표를 그리지 않는다.
                    // 시간도 모임이 가진 값만 쓴다 — 예전에는 어떤 모임이든 `07:50` 이었다.
                    DesignField(label: "집합 장소 · 집합 시간", icon: "mappin.and.ellipse",
                                value: meetingSummary,
                                placeholder: "집합 정보가 아직 없어요")
                }
                .padding(20)
            }
        }
        .safeAreaInset(edge: .bottom) {
            switch state {
            case .editable:
                CreationFooter(
                    backTitle: "취소",
                    nextTitle: isSaving ? "저장 중" : "저장하고 멤버에게 알리기",
                    back: { dismiss() },
                    next: save,
                    isNextEnabled: !isSaving
                )
            case .linkedLocked:
                // 「코스 바꾸기」는 **약속을 지킬 수 없는 이름**이었다 — 누르면 코스 선택 화면도
                // 안내도 없이 직전 화면으로 되돌아갔다 (IOS-F118). 모집을 연 뒤에 등록 코스를
                // 다른 코스로 갈아 끼우는 길은 앱에도 서버에도 없다
                // (`updateRoomCourse` 는 `type == CUSTOM` 인 코스만 받는다).
                // 그래서 **하는 일을 그대로 적고**, 왜 못 바꾸는지는 위 안내(`policyNotice`)가 말한다.
                // 예전에는 이 버튼도 `dismiss()` 만 불러 **이름만 바뀐 거짓 약속**이었다 —
                // 「집합 정보 수정」을 눌러도 모집 관리로 되돌아갈 뿐이었다 (TC HOST-035).
                // 실제 편집 화면(18-5 `MeetingInfoEditView`)으로 보낸다.
                CreationFooter(
                    backTitle: "닫기",
                    nextTitle: "집합 정보 수정",
                    back: { dismiss() },
                    next: { showMeetingInfoEdit = true },
                    isNextEnabled: trip.serverRoomID != nil
                )
            // 불발도 확정과 **똑같이 잠긴 바닥**을 쓴다 — 이유 문구만 위쪽 안내에서 갈린다.
            case .tripConfirmed, .tripCancelled:
                // 화면기획 18-3 — 공지로 알리기(외곽선) + 비활성 경로 수정 두 버튼
                HStack(spacing: 14) {
                    Button("공지로 알리기") { showNoticeComposer = true }
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.brandText)
                        .frame(maxWidth: .infinity)
                        .frame(height: MoyeoTheme.ctaHeight)
                        .background(MoyeoTheme.card)
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(MoyeoTheme.forest))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .accessibilityIdentifier("courseEdit.notifyByNotice")
                    Button("경로 수정") {}
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.text400)
                        .padding(.horizontal, 18)
                        .frame(height: 50)
                        .background(MoyeoTheme.subtleBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .disabled(true)
                        .accessibilityIdentifier("courseEdit.editDisabled")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(MoyeoTheme.card)
                .overlay(alignment: .top) { Rectangle().fill(MoyeoTheme.softLine).frame(height: 1) }
            }
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        // 바를 감추면 UIKit 이 엣지 스와이프를 스스로 끈다 — 화면마다 되살린다 (TC NAV-017).
        .moyeoBackSwipeEnabled()
        .task { await loadTripDays() }
        .alert("채팅방 공지 작성", isPresented: $showNoticeComposer) {
            Button("확인") {}
        } message: { Text("확정된 여행의 변경 사항은 경로를 수정하지 않고 공지로 안내해요.") }
        // 18-2 등록 코스 잠금 화면의 「집합 정보 수정」이 가는 곳 (18-5).
        .navigationDestination(isPresented: $showMeetingInfoEdit) {
            if let roomID = trip.serverRoomID {
                MeetingInfoEditView(roomID: roomID)
            }
        }
        .accessibilityIdentifier("screen.courseEdit.\(state.rawValue)")
    }

    /// 화면기획 18-x 헤더 타이틀 — 코스 이름 (모집 이름이 아니다).
    /// 서버가 코스 이름을 주지 않았으면 모집 이름으로 대신한다.
    private var headerTitle: String {
        trip.serverCourseTitle.flatMap { $0.isEmpty ? nil : $0 } ?? trip.title
    }

    /// 화면기획 18-x 헤더 부제 — "5/25(토) 당일치기 · 방문지 4개 · 2/5명"
    private var headerSubtitle: String {
        "\(compactScheduleText) · 방문지 \(stops.count)개 · \(trip.joined)/\(trip.capacity)명"
    }

    private var compactScheduleText: String {
        // "2026.05.25 (토) 08:00" → "5/25(토) 당일치기"
        let kind = trip.scheduleDetails?.kind ?? .dayTrip
        let parts = trip.schedule.split(separator: " ").map(String.init)
        guard parts.count >= 2 else { return trip.schedule }
        let dateParts = parts[0].split(separator: ".").map(String.init)
        guard dateParts.count >= 3, let month = Int(dateParts[1]), let day = Int(dateParts[2]) else {
            return trip.schedule
        }
        return "\(month)/\(day)\(parts[1]) \(kind.rawValue)"
    }

    /// 배지는 아트보드별 상태를 따른다 — 등록 코스 잠금(18-2)만 등록된 코스, 나머지는 호스트 직접 코스
    private var displaySource: CourseSource {
        state == .linkedLocked ? .linked : .custom
    }

    @ViewBuilder private var policyNotice: some View {
        switch state {
        case .editable:
            DesignInfoBox(icon: "sparkles", text: "마감 전까지 경로를 바꿀 수 있어요. 저장하면 채팅방에 변경 내역이 공지로 남고 멤버 모두에게 알림이 가요.")
        case .linkedLocked:
            // 「코스를 바꿀 수 있다」고 읽히지 않게, **바꾸려면 어떻게 해야 하는지**까지 적는다.
            DesignInfoBox(
                icon: "lock.fill",
                text: "등록 코스의 방문지·순서·시간은 고정돼요. 집합 정보와 모집 조건은 수정할 수 있어요. "
                    + "다른 코스로 떠나려면 그 코스로 모집을 새로 열어야 해요."
            )
        case .tripConfirmed:
            DesignWarningBox(text: "여행이 확정돼 경로가 잠겼어요. 변경이 필요하면 채팅방 공지로 알려주세요.")
        case .tripCancelled:
            // 잠금은 확정과 같고 **이유만 다르다.** 떠나지 않을 여행을 확정됐다고 말하지 않는다.
            DesignWarningBox(text: "모집이 불발돼 경로가 잠겼어요. 같은 코스로 다시 모집을 열 수 있어요.")
        }
    }

    /// 일차 머리글을 그릴 순서 — 작은 일차부터.
    ///
    /// 여행 일수(`tripDays`)를 알면 **1일차부터 마지막 일차까지 빠짐없이** 그린다.
    /// 서버가 그렇게 요구하고(`validateCustomCourseSchedule`), 방문지를 다 지워 비어 버린 일차에도
    /// 「방문지 추가」가 남아 있어야 다시 채울 수 있다.
    private var dayNumbers: [Int] {
        let fromStops = Set(stops.map(\.day))
        guard let tripDays = serverTripDays, tripDays > 0 else { return fromStops.sorted() }
        return Array(Set(1...tripDays).union(fromStops)).sorted()
    }

    /// 행에 보여 줄 번호만 일차별 순번으로 바꾼 사본이다.
    /// `ItineraryStopRow` 는 `stop.order` 를 그대로 그리는데, 편집 중인 목록의 `order` 는
    /// 지우기·순서 바꾸기 뒤에 어긋나 있어 화면에 보이는 자리로 다시 센다.
    private func numbered(_ stop: ItineraryStop, order: Int) -> ItineraryStop {
        var copy = stop
        copy.order = order
        return copy
    }

    private func remove(at index: Int) {
        guard stops.indices.contains(index) else { return }
        stops.remove(at: index)
        saveError = nil
    }

    /// 서버 모임이면 **서버에 저장한다**. 예전에는 세션 메모리만 고쳐서 화면은 바뀌었는데
    /// 서버 코스는 그대로였고, 다시 들어오면 고치기 전 경로가 다시 떴다.
    private func save() {
        // 역순 일정은 서버에 남기지 않는다 (IOS-F142).
        if let day = reversedTimeDay {
            saveError = "Day \(day) 의 방문 시각이 거꾸로 가요. 순서를 다시 맞춰 주세요."
            return
        }
        guard let roomID = trip.serverRoomID, state == .editable else {
            onSaved(trip, stops)
            dismiss()
            return
        }
        // 서버가 거절할 이유를 먼저 같은 말로 검사한다 — 400 을 받아
        // 「요청이 올바르지 않습니다」로 넘기지 않는다.
        guard let tripDays = serverTripDays else {
            saveError = "모임 정보를 아직 읽지 못했어요. 잠시 뒤 다시 시도해 주세요."
            return
        }
        if let blocked = roomCourseSaveError(stops, tripDays: tripDays) {
            saveError = blocked
            return
        }
        let places = roomCoursePlaceEdits(stops)
        isSaving = true
        saveError = nil
        Task {
            do {
                // 이름·소개는 보내지 않는다 — `PATCH` 는 생략한 필드를 그대로 두고
                // (BE `TravelCourse.updateInformation` 이 null 을 무시한다), 이름은 18-7 이 고친다.
                try await TravelCourseAPIClient.shared.updateRoomCourse(roomID: roomID, places: places)
                onSaved(trip, stops)
                dismiss()
            } catch {
                saveError = error.moyeoUserMessage(fallback: "경로를 저장하지 못했어요.")
            }
            isSaving = false
        }
    }

    /// 여행 일수를 받아 둔다 — 저장 전 검사(`roomCourseSaveError`)가 이 값을 쓴다.
    private func loadTripDays() async {
        guard let roomID = trip.serverRoomID, serverTripDays == nil else { return }
        serverTripDays = try? await ChatRoomAPIClient.shared.detail(roomID: roomID).tripDays
    }

    /// 장소 검색에서 고른 곳만 담는다 — `contentId`·좌표가 함께 들어온다 (IOS-F140).
    /// 시각은 코스 에디터와 **같은 기본 규칙**(첫 스톱 10:00, 2시간 30분 간격, 21:00 상한)이다.
    ///
    /// 서버 모임에서도 담을 수 있다 — `PATCH /travel-courses/chat-rooms/{roomId}` 는 `places` 를
    /// **통째로 갈아 끼우므로**, 담은 뒤 저장하면 추가도 그대로 반영된다.
    /// `placeID` 는 서버 `contentId` 그대로다(`TourismAPIClient.makePlace`) — 없으면 저장이 막힌다.
    private func add(_ place: TourismPlace, to day: Int) {
        guard stops.count < RoutePolicy.maximumStopCount,
              !stops.contains(where: { $0.day == day && $0.name == place.title })
        else { return }
        let order = stops.filter { $0.day == day }.count + 1
        // 시각은 **그 일차의 마지막 방문지 뒤**로 잡는다. 고정 시간표를 쓰면 이미 저장된
        // 시각보다 이른 값이 나와 저장이 통째로 막혔다 (`nextRoomCourseStopTime` 주석).
        let inserted = ItineraryStop(
            id: place.id, day: day, order: order,
            time: nextRoomCourseStopTime(
                afterLast: stops.last { $0.day == day }?.time,
                order: order
            ),
            name: place.title, memo: place.type.rawValue,
            placeID: place.id, latitude: place.latitude, longitude: place.longitude
        )
        // 그 일차의 **맨 뒤**에 꽂는다. 목록은 일차·순서대로 세워져 있어야 저장할 때
        // `sequence` 가 화면에 보이는 자리와 같아진다.
        if let lastIndexOfDay = stops.lastIndex(where: { $0.day == day }) {
            stops.insert(inserted, at: lastIndexOfDay + 1)
        } else {
            // 그 일차가 아직 비어 있으면 **다음 일차 앞**에 꽂는다 — 정렬을 새로 돌리면
            // 같은 일차 안의 순서까지 흐트러질 수 있다.
            stops.insert(inserted, at: stops.firstIndex { $0.day > day } ?? stops.count)
        }
        saveError = nil
    }

    /// 순서를 바꿔도 **방문 시각은 자리에 남는다.** 예전에는 시각이 장소에 붙어 따라다녀서,
    /// 「위로 이동」 한 번에 `1번 12:30 · 2번 10:00` 같은 역순 일정이 만들어지고 그대로 서버에
    /// 저장됐다. 이 화면에는 시각을 고칠 수단이 없어 호스트가 되돌릴 방법도 없었다 (IOS-F142).
    private func move(_ index: Int, _ offset: Int) {
        let target = index + offset
        guard stops.indices.contains(target), state == .editable else { return }
        let times = (stops[index].time, stops[target].time)
        stops.swapAt(index, target)
        stops[index].time = times.0
        stops[target].time = times.1
    }

    /// 같은 일차 안에서 방문 시각이 거꾸로 가면 저장을 막는다 — 서버에 역순 일정을 남기지 않는다.
    /// 시각이 비어 있는 방문지(서버가 시각을 주지 않은 옛 모임)는 견주지 않는다.
    private var reversedTimeDay: Int? {
        Set(stops.map(\.day)).sorted().first { day in
            let times = stops.filter { $0.day == day && !$0.time.isEmpty }.map(\.time)
            return times != times.sorted()
        }
    }
}

struct NoticeHistoryView: View {
    let thread: ChatThread
    let onCreate: (ChatThread, TripNotice) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var notices: [TripNotice]
    @State private var showComposer = false
    /// 실서버 공지 이력을 받았는지 — 받았으면 서버 공지만 그린다 (20-3)
    @State private var usesServerNotices = false
    /// 서버 모임 상세 — 머리말의 코스 이름과 지도 미리보기의 집합 좌표가 여기서 나온다.
    @State private var serverRoom: ServerChatRoomDetail?
    /// 고정 토글 요청 중인 공지 — 중복 탭을 막는다
    @State private var pinningNoticeIDs = Set<String>()
    /// 고정 토글이 서버에 거절됐을 때의 안내
    @State private var pinFailureMessage: String?
    /// 20-3a 공지 수정 · 삭제. 서버 공지 원본이 있어야 열 수 있다 (내용·고정을 그대로 실어 보낸다).
    @State private var serverNotices: [ServerChatRoomNotice] = []
    /// 공지 목록을 못 받았는지. 실패를 빈 목록으로 그리면 「공지가 없다」는 거짓말이 된다 (TC NOTICE-022).
    @State private var noticeLoadFailed = false
    @State private var editingNotice: ServerChatRoomNotice?

    init(thread: ChatThread, onCreate: @escaping (ChatThread, TripNotice) -> Void = { _, _ in }) {
        self.thread = thread
        self.onCreate = onCreate
        // 공지가 없으면 없는 대로 둔다 — 목 공지를 채우지 않는다 (NO-MOCK-CANON R1).
        _notices = State(initialValue: thread.pinnedNotices)
    }

    var body: some View {
        VStack(spacing: 0) {
            NoticeHistoryNavigationBar(onBack: dismiss.callAsFunction)
            ScrollView {
                // 화면기획은 코스 이름과 공지 개수를 먼저 두고, 섹션은 "상단 고정 중" / "지난 공지"다
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(headerTitle)
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(MoyeoTheme.ink)
                        // 상단 고정은 최대 1개다 (정본 R5-1, 기획 결정 2026-08-30)
                        // 못 받았으면 개수를 말하지 않는다 — 「0개」는 아는 척이다.
                        if !noticeLoadFailed {
                            Text("공지 \(notices.count)개 · 고정 \(notices.filter(\.isPinned).count) / 최대 1")
                                .font(.caption2)
                                .foregroundStyle(MoyeoTheme.muted)
                                .monospacedDigit()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if noticeLoadFailed {
                        // 예전에는 조회가 실패해도 「아직 등록된 공지가 없어요.」를 그렸다 —
                        // 공지가 있는데 없다고 말하고, 다시 볼 방법도 없었다 (TC NOTICE-022).
                        // 안드로이드는 이미 실패와 빈 목록을 갈라 두었다.
                        MoyeoEmptyStateView(
                            message: MoyeoEmptyText.loadFailed,
                            onRetry: {
                                if let roomID = thread.serverRoomID {
                                    Task { await reloadNotices(roomID: roomID) }
                                }
                            },
                            accessibilityIdentifier: "noticeHistory.failed"
                        )
                    } else if notices.isEmpty {
                        MoyeoEmptyStateView(
                            message: MoyeoEmptyText.noNotices,
                            accessibilityIdentifier: "noticeHistory.empty"
                        )
                    } else {
                        // 고정이 0개면 머리말만 남아 빈 자리가 생긴다 — 웹도
                        // `serverPinned.length > 0 && …` 로 머리말째 감춘다.
                        if notices.contains(where: \.isPinned) {
                            NoticeSectionTitle(title: "상단 고정 중")
                        }
                        ForEach(notices.filter(\.isPinned)) { notice in
                            NoticeCard(
                                notice: notice,
                                meetingCoordinate: meetingCoordinate,
                                isBusy: pinningNoticeIDs.contains(notice.id),
                                onTogglePin: canTogglePin(notice) ? { togglePin(notice) } : nil,
                                onEdit: serverNotice(for: notice).map { server in
                                    { editingNotice = server }
                                }
                            )
                        }
                        if notices.contains(where: { !$0.isPinned }) {
                            NoticeSectionTitle(title: "지난 공지")
                        }
                        ForEach(notices.filter { !$0.isPinned }) { notice in
                            NoticeCard(
                                notice: notice,
                                meetingCoordinate: meetingCoordinate,
                                isBusy: pinningNoticeIDs.contains(notice.id),
                                onTogglePin: canTogglePin(notice) ? { togglePin(notice) } : nil,
                                onEdit: serverNotice(for: notice).map { server in
                                    { editingNotice = server }
                                }
                            )
                        }
                    }

                    Text(
                        "공지는 호스트만 올릴 수 있고, 상단 고정은 하나만 둘 수 있어요. "
                            + "새로 고정하면 먼저 고정된 공지가 풀려요. 고정을 해제해도 이력에는 그대로 남아요."
                    )
                        .font(.caption2)
                        .foregroundStyle(MoyeoTheme.text400)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 60)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        // 바를 감추면 UIKit 이 엣지 스와이프를 스스로 끈다 — 화면마다 되살린다 (TC NAV-017).
        .moyeoBackSwipeEnabled()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // 화면기획은 하단 고정 CTA다 (툴바 + 아이콘이 아니라).
            // **호스트에게만** 보여준다 — 참가자가 누르면 서버가 403 으로 거절할 뿐이다.
            // 웹은 `{isHost && (…새 공지 작성 (호스트)…)}`, 안드로이드는
            // `bottom = if (!isHost) null else { … }` 로 이미 감춘다 (TC NOTICE-020).
            if isCurrentUserHost {
                AuthPrimaryButton(title: "＋ 새 공지 작성 (호스트)", accessibilityIdentifier: "noticeHistory.create") {
                    showComposer = true
                }
                .disabled(thread.serverRoomID == nil)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 28)
                .background(MoyeoTheme.card)
            }
        }
        // 20-3 하단 CTA → 20-2f 공지 작성 (정본 ATTACH-COMPOSER-CANON.md §2).
        // 예전에는 알림창에서 "호스트 새 공지" 라는 가짜 공지를 만들어 목록에 끼워 넣었다.
        .navigationDestination(isPresented: $showComposer) {
            if let roomID = thread.serverRoomID {
                AttachNoticeComposerView(roomID: roomID) {
                    showComposer = false
                    Task { await reloadNotices(roomID: roomID) }
                }
            }
        }
        .alert(
            "공지 고정",
            isPresented: Binding<Bool>(
                get: { pinFailureMessage != nil },
                set: { if !$0 { pinFailureMessage = nil } }
            )
        ) {
            Button("확인", role: .cancel) { pinFailureMessage = nil }
        } message: { Text(pinFailureMessage ?? "") }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .task {
            guard MoyeoServerSync.isEnabled, let roomID = thread.serverRoomID, !usesServerNotices else { return }
            // 상세는 공지와 별개로 받는다 — 하나가 실패해도 나머지는 실제 값으로 그린다.
            serverRoom = try? await ChatRoomAPIClient.shared.detail(roomID: roomID)
            guard let history = try? await ChatRoomContentAPIClient.shared.notices(roomID: roomID) else {
                noticeLoadFailed = true
                return
            }
            noticeLoadFailed = false
            serverNotices = history.allNotices
            notices = history.allNotices.map(ServerTripMapper.notice(from:))
            usesServerNotices = true
        }
        // 20-3a — 공지 카드의 `수정` 이 가는 곳. 예전에는 갈 곳이 없어 글자만 있었다.
        .navigationDestination(item: $editingNotice) { notice in
            if let roomID = thread.serverRoomID {
                NoticeEditView(roomID: roomID, notice: notice) {
                    Task { await reloadNotices(roomID: roomID) }
                }
            }
        }
        .accessibilityIdentifier("screen.noticeHistory")
    }

    /// 머리말은 코스 이름이다. 서버 모임이면 서버가 준 코스 이름이 우선이다 —
    /// 목데이터 스레드의 이름을 실서버 화면에 섞지 않는다.
    private var headerTitle: String {
        if let serverTitle = serverRoom?.courseTitle, !serverTitle.isEmpty { return serverTitle }
        if let roomTitle = serverRoom?.title, !roomTitle.isEmpty { return roomTitle }
        return thread.courseName.isEmpty ? thread.tripTitle : thread.courseName
    }

    /// 20-3 공지의 지도 미리보기는 **서버 상세의 집합 좌표**만 쓴다.
    /// 좌표가 없으면 nil 이고 지도를 그리지 않는다 (NO-MOCK-CANON R4).
    private var meetingCoordinate: MoyeoMapCoordinate? {
        MoyeoMapCoordinate(
            latitude: serverRoom?.meetingLatitude,
            longitude: serverRoom?.meetingLongitude
        )
    }

    /// 화면 모델(`TripNotice`)에 대응하는 서버 공지 원본. 목데이터 공지면 nil 이고 수정할 수 없다.
    /// 비호스트도 nil 이다 — 수정 화면 안에 삭제까지 들어 있어 진입 자체를 막아야 한다
    /// (`NoticeEditView` 「이 공지 삭제하기」).
    private func serverNotice(for notice: TripNotice) -> ServerChatRoomNotice? {
        guard
            isCurrentUserHost,
            thread.serverRoomID != nil,
            let noticeID = ServerTripMapper.noticeID(fromNoticeID: notice.id)
        else {
            return nil
        }
        return serverNotices.first { $0.noticeId == noticeID }
    }

    /// 공지의 고정·수정·삭제와 새 공지 작성은 **호스트만** 할 수 있다.
    /// 서버도 비호스트에게 403(`채팅방 호스트만 이 작업을 할 수 있습니다`)을 준다 —
    /// 참가자에게 버튼을 보여주면 눌러야만 거절을 알게 되는 죽은 UI 가 된다.
    /// 웹(`screens-additions.jsx` `isHost &&`)·안드로이드(`RecruitmentFlowScreens.kt:2417·2473`)는
    /// 이미 호스트에게만 보여준다 — iOS 만 모두에게 열어 두고 있었다 (TC NOTICE-020).
    ///
    /// 판정은 이 화면이 이미 받아 둔 서버 상세의 `hostId` 로 한다. 상세를 아직 못 받았으면
    /// 스레드가 들고 온 값을 쓰고, 그것도 없으면 **막는 쪽**으로 기운다(권한은 낙관하지 않는다).
    private var isCurrentUserHost: Bool {
        if let hostID = serverRoom?.hostId, let myID = MoyeoCurrentUser.id {
            return hostID == myID
        }
        return thread.isCurrentUserHost
    }

    /// 서버 공지이고 내가 호스트일 때만 고정 토글을 보낼 수 있다.
    private func canTogglePin(_ notice: TripNotice) -> Bool {
        MoyeoServerSync.isEnabled
            && isCurrentUserHost
            && thread.serverRoomID != nil
            && ServerTripMapper.noticeID(fromNoticeID: notice.id) != nil
    }

    /// 20-3 "다시 고정" / "수정" → `PUT /chat-rooms/{id}/notices/{noticeId}` 고정 토글.
    /// 서버가 204 를 준 뒤에 이력을 다시 읽어 화면을 갱신한다 — 낙관적 갱신을 하지 않는다.
    private func togglePin(_ notice: TripNotice) {
        guard
            let roomID = thread.serverRoomID,
            let noticeID = ServerTripMapper.noticeID(fromNoticeID: notice.id),
            !pinningNoticeIDs.contains(notice.id)
        else {
            return
        }
        pinningNoticeIDs.insert(notice.id)
        let pinsNow = !notice.isPinned
        Task {
            do {
                // 상단 고정은 하나만 남긴다 — 서버가 개수를 막지 않으므로 클라가 먼저 기존 고정을 푼다 (R5-1)
                if pinsNow {
                    for pinned in notices where pinned.isPinned {
                        guard let oldID = ServerTripMapper.noticeID(fromNoticeID: pinned.id) else { continue }
                        try? await ChatRoomWriteAPIClient.shared.setNoticePinned(
                            roomID: roomID, noticeID: oldID, pinned: false
                        )
                    }
                }
                try await ChatRoomWriteAPIClient.shared.setNoticePinned(
                    roomID: roomID, noticeID: noticeID, pinned: pinsNow
                )
                if let history = try? await ChatRoomContentAPIClient.shared.notices(roomID: roomID) {
                    serverNotices = history.allNotices
                    notices = history.allNotices.map { ServerTripMapper.notice(from: $0) }
                }
            } catch {
                pinFailureMessage =
                    error.moyeoUserMessage(fallback: "공지 고정을 바꾸지 못했어요.")
            }
            pinningNoticeIDs.remove(notice.id)
        }
    }

    /// 공지를 올린 뒤에는 서버 이력을 다시 읽는다 — 화면에서 만든 공지를 끼워 넣지 않는다.
    private func reloadNotices(roomID: Int64) async {
        guard let history = try? await ChatRoomContentAPIClient.shared.notices(roomID: roomID) else {
            // 「다시 시도」도 여기로 온다 — 또 실패하면 실패 상태를 그대로 둔다(조용히 빈 목록으로 바꾸지 않는다).
            noticeLoadFailed = true
            return
        }
        noticeLoadFailed = false
        serverNotices = history.allNotices
        notices = history.allNotices.map(ServerTripMapper.notice(from:))
        usesServerNotices = true
        if let latest = notices.first {
            onCreate(thread, latest)
        }
    }
}

private struct NoticeSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.heavy))
            .foregroundStyle(MoyeoTheme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }
}

private struct NoticeHistoryNavigationBar: View {
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Text("공지 이력")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)
            HStack {
                Button(action: onBack) {
                    // NAV-017 · ENV-009 — 44x44 틀은 있었지만 `contentShape` 가 없어
                    // 실제로는 화살표 그림(9x14pt)에만 반응했다. 그림 크기는 그대로 둔다.
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(MoyeoTheme.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로")
                Spacer()
            }
        }
        .frame(height: 56)
        .overlay(alignment: .bottom) {
            Rectangle().fill(MoyeoTheme.line).frame(height: 1)
        }
    }
}

private struct NoticeCard: View {
    let notice: TripNotice
    var meetingCoordinate: MoyeoMapCoordinate?
    /// 고정 토글 요청 중이면 문구를 잠근다
    var isBusy = false
    /// 서버 공지일 때만 채워진다 — nil 이면 기존처럼 정적 문구를 그린다
    var onTogglePin: (() -> Void)?
    /// 20-3a 공지 수정 · 삭제로 가는 길. 서버 공지일 때만 채워진다.
    var onEdit: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            // 제목 줄을 두지 않는다 — 본문이 카드의 주인공이다
            // (정본 `ATTACH-COMPOSER-CANON.md` §2, 기획 결정 2026-08-30).
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .font(.caption)
                    .foregroundStyle(notice.isPinned ? MoyeoTheme.forest : MoyeoTheme.muted)
                Spacer(minLength: 0)
                // 고정 여부를 배지로 — 화면기획과 같은 표기
                Text(notice.isPinned ? "📌 고정" : "고정 해제됨")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(notice.isPinned ? MoyeoTheme.forest : MoyeoTheme.muted)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(notice.isPinned ? MoyeoTheme.leaf : MoyeoTheme.subtleBackground)
                    .clipShape(Capsule())
            }
            Text(notice.body).font(.subheadline).foregroundStyle(MoyeoTheme.ink)
            // 공지 카드에 지도를 띄우지 않는다 — 여기서 장소를 바꾸는 게 아니라 읽기만 한다
            // (2026-08-31 사용자 지시). 집합 장소 변경은 18-5 집합 정보 수정에서 한다.
            // 웹·안드로이드도 지도를 그리지 않는다 — iOS 만 달랐다.
            HStack(spacing: 6) {
                // 작성자는 서버 공지만 안다 — 모르면 이름을 지어내지 않고 그 자리를 비운다
                if !notice.authorName.isEmpty {
                    Text(notice.authorName)
                    Text("·")
                }
                Text(notice.createdAt).monospacedDigit()
                Spacer(minLength: 0)
                // 화면기획 20-3 — 고정 토글과 「수정」을 **둘 다** 둔다.
                // 예전에는 고정된 공지에 「수정」만, 풀린 공지에 「다시 고정」만 있어서
                // 고정을 푸는 길이 iOS 에만 없었다 (웹·안드로이드는 둘 다 있다, 2026-09-09).
                if let onTogglePin {
                    Button(action: onTogglePin) {
                        Text(notice.isPinned ? "고정 해제" : "다시 고정")
                            .foregroundStyle(isBusy ? MoyeoTheme.text400 : MoyeoTheme.forest)
                            .fontWeight(.heavy)
                    }
                    .buttonStyle(.plain)
                    .disabled(isBusy)
                    .accessibilityIdentifier("noticeHistory.repin.\(notice.id)")
                }
                if let onEdit {
                    Button(action: onEdit) {
                        Text("수정")
                            .foregroundStyle(MoyeoTheme.forest)
                            .fontWeight(.heavy)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, onTogglePin == nil ? 0 : 12)
                    .accessibilityIdentifier("noticeHistory.edit.\(notice.id)")
                }
            }
            .font(.caption2)
            .foregroundStyle(MoyeoTheme.muted)
        }
        .padding(14)
        .background(notice.isPinned ? MoyeoTheme.leaf.opacity(0.45) : MoyeoTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MoyeoTheme.softLine))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// 여행 경로 지도 (화면기획 17-7 / 18-2 / 18-3).
/// 방문지 위경도가 모두 있을 때만 실지도에 순번 마커 + 경로선을 그린다.
/// 좌표가 없으면 손으로 그린 도식을 대신 두지 않는다 (NO-MOCK-CANON R4).
private struct RouteSchematic: View {
    let stops: [ItineraryStop]

    private var routeMarkers: [MoyeoMapMarker] {
        stops.compactMap { stop in
            guard let coordinate = MoyeoMapCoordinate(latitude: stop.latitude, longitude: stop.longitude) else {
                return nil
            }
            return MoyeoMapMarker(id: stop.id, coordinate: coordinate, order: stop.order)
        }
    }

    var body: some View {
        let markers = routeMarkers
        if !markers.isEmpty, markers.count == stops.count, let first = markers.first {
            MoyeoMapView(
                content: MoyeoMapContent(
                    center: first.coordinate,
                    level: 11,
                    markers: markers,
                    polyline: markers.map(\.coordinate)
                ),
                isInteractive: false,
                fallback: { MoyeoMapUnavailableView(message: "지도를 불러오지 못했어요.") }
            )
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("경로 지도, 방문지 \(stops.count)곳")
        }
    }
}

/// 17-3 집합 장소 지정. 실지도에서는 중앙 핀을 고정하고 지도를 끌어 좌표를 잡는다.
private struct MeetingMapCard: View {
    @Binding var meeting: MeetingPointDetails
    /// 핀을 끌어 좌표가 바뀌었을 때. 이름·주소가 더 이상 이 좌표를 가리키지 않는다는 뜻이라
    /// 부르는 쪽이 그 사실을 화면에 적는다 (IOS-F145·F36).
    var onMoved: (() -> Void)?

    var body: some View {
        MoyeoMapView(
            content: MoyeoMapContent(
                center: MoyeoMapCoordinate(latitude: meeting.latitude, longitude: meeting.longitude),
                level: 16,
                fitsContent: false
            ),
            draggablePin: true,
            onPinMove: updateCoordinate,
            fallback: { MoyeoMapUnavailableView(message: "지도를 불러오지 못했어요.") }
        )
        .frame(height: 210).clipShape(RoundedRectangle(cornerRadius: 9))
        .accessibilityLabel("지도 핀, \(meeting.name)")
    }

    /// 예전에는 위경도만 바꾸고 **이름·주소는 그대로 뒀다.** 「부산역」을 고른 뒤 핀을 산으로
    /// 끌어도 집합 장소가 「부산역」으로 저장돼, 참가자가 엉뚱한 곳으로 갔다 (IOS-F145).
    private func updateCoordinate(_ coordinate: MoyeoMapCoordinate) {
        let moved = meeting.latitude != coordinate.latitude || meeting.longitude != coordinate.longitude
        meeting.latitude = coordinate.latitude
        meeting.longitude = coordinate.longitude
        if moved { onMoved?() }
    }
}

private struct ItineraryStopRow: View {
    let stop: ItineraryStop
    let canRemove: Bool
    var locked = false
    let moveUp: () -> Void
    let moveDown: () -> Void
    let remove: () -> Void
    /// 방문 시각 고치기. 보기 전용 화면에서는 넘기지 않는다.
    var editTime: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Menu {
                Button("위로 이동", action: moveUp)
                Button("아래로 이동", action: moveDown)
                if let editTime {
                    Button("방문 시각 바꾸기", action: editTime)
                }
            } label: { Image(systemName: locked ? "lock.fill" : "line.3.horizontal").foregroundStyle(MoyeoTheme.muted).frame(width: 24, height: 44) }
            .disabled(locked)
            // ENV-006: 라벨이 없으면 VoiceOver 가 영어 시스템 문구(「Drag」)로 읽는다.
            .accessibilityLabel(locked ? "순서 이동 잠김" : "순서 이동 손잡이")
            // 잠긴 행의 순번 원은 화면기획의 중립 회색 톤이다
            Text("\(stop.order)").font(.caption.weight(.heavy)).foregroundStyle(.white).frame(width: 30, height: 30).background(locked ? MoyeoTheme.text400 : MoyeoTheme.primary300).clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    if let editTime {
                        Button(stop.time, action: editTime)
                            .buttonStyle(.plain)
                            .foregroundStyle(MoyeoTheme.primary300)
                            .accessibilityLabel("\(stop.name) 방문 시각 \(stop.time), 눌러서 바꾸기")
                            .accessibilityIdentifier("itinerary.stop.time.\(stop.id)")
                    } else {
                        Text(stop.time).foregroundStyle(MoyeoTheme.primary300)
                    }
                    Text(stop.name).foregroundStyle(MoyeoTheme.ink)
                }.font(.caption.weight(.heavy))
                Text(stop.memo).font(.caption2).foregroundStyle(MoyeoTheme.muted)
            }
            Spacer()
            if canRemove && !locked {
                Button(action: remove) {
                    Image(systemName: "xmark")
                        .foregroundStyle(MoyeoTheme.muted)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(stop.name) 삭제")
            }
        }
        .padding(.horizontal, 12).frame(minHeight: 56).background(MoyeoTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(MoyeoTheme.softLine)).clipShape(RoundedRectangle(cornerRadius: 9))
        .accessibilityIdentifier("itinerary.stop.\(stop.id)")
    }
}

private struct DesignHeading: View {
    let title: String
    let subtitle: String?
    init(_ title: String, subtitle: String?) { self.title = title; self.subtitle = subtitle }
    var body: some View { VStack(alignment: .leading, spacing: 5) { Text(title).font(.headline.weight(.heavy)).foregroundStyle(MoyeoTheme.ink); if let subtitle { Text(subtitle).font(.caption).foregroundStyle(MoyeoTheme.muted) } } }
}

/// 17-x 입력 폼의 한 줄. 값이 아직 없으면 `placeholder` 를 흐리게 보여준다.
///
/// **`action` 이 있는 줄만 `chevron.right` 를 그린다.** 예전에는 모든 줄이 화살표를 그려
/// 눌릴 것처럼 보였는데, 잠긴 코스 줄과 지도가 정하는 집합 장소 줄까지 화살표가 있었고
/// 고칠 수 있어야 하는 줄들은 정작 아무 동작이 없었다.
private struct DesignField: View {
    let label: String
    let icon: String
    let value: String
    var detail: String?
    /// 안내 문구를 **입력 뷰 아래**에 둘지. 기획·웹·안드로이드가 그렇게 그린다 —
    /// 뷰 안에 넣으면 값과 안내가 한 상자에 섞여 iOS 만 달라 보였다 (사용자 지적, 2026-09-09).
    var detailBelowField = false
    /// 값이 비었을 때 대신 보여줄 안내. 지어낸 기본값을 넣지 않기 위한 자리다.
    var placeholder: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if !label.isEmpty {
                Text(label).font(.caption.weight(.heavy)).foregroundStyle(MoyeoTheme.text700)
            }
            if let action {
                Button(action: action) { row }
                    .buttonStyle(.plain)
                    .accessibilityLabel(label.isEmpty ? value : "\(label) 고치기")
            } else {
                row
            }
            if detailBelowField, let detail {
                Text(detail).font(.caption).foregroundStyle(MoyeoTheme.muted)
            }
        }
    }

    private var isPlaceholder: Bool { value.isEmpty && placeholder != nil }

    private var row: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(MoyeoTheme.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text(isPlaceholder ? (placeholder ?? "") : value)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(isPlaceholder ? MoyeoTheme.muted : MoyeoTheme.ink)
                if let detail, !detailBelowField {
                    Text(detail).font(.caption2).foregroundStyle(MoyeoTheme.muted)
                }
            }
            Spacer()
            if action != nil {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(MoyeoTheme.text400)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: (detail == nil || detailBelowField) ? 50 : 60)
        .contentShape(Rectangle())
        .background(MoyeoTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(MoyeoTheme.line))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

private struct DesignSummaryLine: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.caption.weight(.heavy)).foregroundStyle(MoyeoTheme.ink).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(MoyeoTheme.card).overlay(RoundedRectangle(cornerRadius: 9).stroke(MoyeoTheme.softLine)).clipShape(RoundedRectangle(cornerRadius: 9)) }
}

private struct DesignInfoBox: View {
    /// nil이면 아이콘 없이 텍스트만 그린다 (17-7 두 번째 카드)
    let icon: String?
    let text: String
    var neutral = false
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let icon {
                Image(systemName: icon).foregroundStyle(neutral ? MoyeoTheme.muted : MoyeoTheme.primary300)
            }
            // 틴트 표면은 테마 토큰으로 — 밝은 값을 박아두면 다크에서 카드만 하얗게 남는다
            // `**…**` 마크다운은 그 부분만 굵게 그린다 (17-7 잠금 카드)
            Text(.init(text)).font(.caption).foregroundStyle(neutral ? MoyeoTheme.ink : MoyeoTheme.onLeaf)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(neutral ? MoyeoTheme.card : MoyeoTheme.leaf)
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(neutral ? MoyeoTheme.softLine : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

private struct DesignWarningBox: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "clock.badge.exclamationmark")
            Text(text).font(.caption)
            Spacer(minLength: 0)
        }
        .foregroundStyle(MoyeoTheme.warningText)
        .padding(14)
        .background(MoyeoTheme.warningBackground)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

private struct SummaryRow: View {
    let icon: String; let label: String; let value: String
    init(_ icon: String, _ label: String, _ value: String) { self.icon = icon; self.label = label; self.value = value }
    var body: some View {
        // 값이 없으면 **줄 자체를 그리지 않는다**. 예전에는 아이콘과 라벨만 남아
        // 「마감」 같은 칸이 빈 채로 남았고, 정보가 빠진 것처럼 읽혔다
        // (17-6, 사용자 지적 2026-09-09).
        if !value.isEmpty {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon).foregroundStyle(MoyeoTheme.muted).frame(width: 18)
                Text(label).font(.caption).foregroundStyle(MoyeoTheme.muted).frame(width: 36, alignment: .leading)
                Text(value).font(.caption.weight(.heavy)).foregroundStyle(MoyeoTheme.ink)
                Spacer(minLength: 0)
            }
        }
    }
}

/// 검색 입력 한 줄. 17-1a 장소 검색과 27-2 친구 검색이 같은 모양을 쓴다.
struct LabelledSearchField: View {
    @Binding var text: String
    let prompt: String
    // placeholder 는 SwiftUI 기본색(거의 안 보이는 회색)을 쓰지 않고 색을 직접 준다.
    // 웹(13px `text400`) · 안드로이드(bodyLarge `onSurfaceVariant`) 와 같은 정도로 보이게 맞췄다.
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(MoyeoTheme.muted)
            TextField("", text: $text, prompt: Text(prompt).foregroundColor(MoyeoTheme.muted))
                .font(.subheadline)
                .foregroundStyle(MoyeoTheme.ink)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(MoyeoTheme.background)
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(MoyeoTheme.line))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

private struct DesignSegment<T: Hashable & RawRepresentable>: View where T.RawValue == String {
    let items: [T]
    @Binding var selected: T
    /// 옵션 아래 작은 설명. 화면기획의 `sub`(예: 시작·종료 시간)와 같은 자리다.
    var subtitles: [String: String] = [:]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                let isSelected = selected == item
                Button {
                    selected = item
                } label: {
                    // 화면기획 — 선택된 옵션은 틴트 배경 + 초록 텍스트 + 초록 테두리로 표시한다
                    VStack(spacing: 3) {
                        Text(item.rawValue)
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(isSelected ? MoyeoTheme.onLeaf : MoyeoTheme.muted)
                        if let subtitle = subtitles[item.rawValue] {
                            Text(subtitle)
                                .font(.caption2)
                                .foregroundStyle(isSelected ? MoyeoTheme.brandText : MoyeoTheme.text400)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: subtitles.isEmpty ? 44 : 54)
                    .background(isSelected ? MoyeoTheme.leaf : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(MoyeoTheme.brandText, lineWidth: 1.2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(MoyeoTheme.subtleBackground)
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(MoyeoTheme.softLine))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

private struct DesignOutlineButtonStyle: ButtonStyle {
    var dashed = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(MoyeoTheme.brandText)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(dashed ? Color.clear : MoyeoTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(MoyeoTheme.line, style: StrokeStyle(lineWidth: 1, dash: dashed ? [4] : []))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private extension View {
    func designInput() -> some View { self.font(.subheadline.weight(.heavy)).foregroundStyle(MoyeoTheme.ink).padding(14).background(MoyeoTheme.card).overlay(RoundedRectangle(cornerRadius: 9).stroke(MoyeoTheme.line)).clipShape(RoundedRectangle(cornerRadius: 9)) }
}

private extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}

/// `sheet(item:)` 에 넘길 식별자 — `String` 은 `Identifiable` 이 아니다.
private struct EditingStopTime: Identifiable {
    let id: String
}

/// 방문 시각 고르기. 서버·화면 모두 `HH:mm` 을 쓴다.
private struct ItineraryTimeSheet: View {
    let initial: String
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var picked = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DatePicker("방문 시각", selection: $picked, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ko_KR"))
                    .accessibilityIdentifier("itinerary.timeSheet.picker")
                Spacer()
            }
            .padding(20)
            .navigationTitle("방문 시각")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("확인") {
                        onPick(Self.text(from: picked))
                        dismiss()
                    }
                    .accessibilityIdentifier("itinerary.timeSheet.confirm")
                }
            }
        }
        .presentationDetents([.height(320)])
        .onAppear { picked = Self.date(from: initial) ?? Date() }
    }

    private static func formatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    static func date(from text: String) -> Date? { formatter().date(from: String(text.prefix(5))) }

    static func text(from date: Date) -> String { formatter().string(from: date) }
}

// swiftlint:enable file_length line_length
