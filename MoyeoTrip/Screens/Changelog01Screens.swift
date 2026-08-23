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

struct RecruitmentDraft: Hashable {
    var source: CourseSource = .linked
    var course: TravelCourse = MockData.courses[0]
    var itinerary: [ItineraryStop] = Self.previewStops
    var schedule = TripScheduleDetails(
        kind: .dayTrip,
        startDate: "2026. 05. 25 (토)",
        startTime: "08:00",
        endTime: "18:00"
    )
    var deadline = "2026. 05. 22 (목) 23:59"
    var meeting = MeetingPointDetails(
        name: "청송 시외버스터미널",
        address: "경북 청송군 청송읍 중앙로 184",
        detail: "정문 앞",
        latitude: 36.435612,
        longitude: 129.057214,
        meetingTime: "07:50"
    )
    var capacity = 5
    var minimumParticipants = 3
    var recruitmentName = "30대끼리 느긋하게 힐링 여행가요~"
    var estimatedCost = "1인 45,000원"
    var minimumAge = 25
    var maximumAge = 35
    var genderRestriction = "성별 무관"
    var note = "천천히 걷고 사진도 함께 남기는 숲길 모임이에요."

    static let preview = RecruitmentDraft()

    static let previewStops = [
        ItineraryStop(id: "stop-terminal", day: 1, order: 1, time: "09:00", name: "청송 시외버스터미널", memo: "집합 장소"),
        ItineraryStop(id: "stop-juwangsan", day: 1, order: 2, time: "10:30", name: "주왕산 국립공원", memo: "대전사 - 제3폭포"),
        ItineraryStop(id: "stop-jusanji", day: 1, order: 3, time: "14:00", name: "주산지", memo: "왕버들 산책로")
    ]

    var scheduleSummary: String {
        switch schedule.kind {
        case .dayTrip:
            return "\(compactDate(schedule.startDate)) 당일치기 · \(schedule.startTime ?? "") - \(schedule.endTime ?? "")"
        case .overnight:
            return "\(compactDate(schedule.startDate)) - \(compactDate(schedule.endDate ?? schedule.startDate))"
        }
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
    @Environment(\.dismiss) private var dismiss
    @State private var step = 1
    @State private var draft: RecruitmentDraft
    @State private var showCustomEditor = false
    @State private var createdTrip: TripRecruitment?
    @State private var createdThread: ChatThread?

    init(
        courseID: String,
        onCreated: @escaping (TripRecruitment, ChatThread) -> Void = { _, _ in },
        onSendChatMessage: @escaping (ChatThread, ChatMessage) -> Void = { _, _ in },
        onApproveApplicant: @escaping (TripRecruitment, Participant) -> Void = { _, _ in },
        onRejectApplicant: @escaping (TripRecruitment, Participant) -> Void = { _, _ in },
        onSetRecruitmentClosed: @escaping (TripRecruitment, Bool) -> Void = { _, _ in }
    ) {
        self.courseID = courseID
        self.onCreated = onCreated
        self.onSendChatMessage = onSendChatMessage
        self.onApproveApplicant = onApproveApplicant
        self.onRejectApplicant = onRejectApplicant
        self.onSetRecruitmentClosed = onSetRecruitmentClosed
        var value = RecruitmentDraft.preview
        value.course = MockData.course(for: courseID) ?? MockData.courses[0]
        value.itinerary = value.course.stops.enumerated().map {
            ItineraryStop(id: "\(value.course.id)-\($0.offset)", day: 1, order: $0.offset + 1,
                          time: ["09:00", "11:00", "14:00", "16:30"][safe: $0.offset] ?? "17:00",
                          name: $0.element, memo: $0.offset == 0 ? "집합 장소" : "방문 장소")
        }
        _draft = State(initialValue: value)
    }

    var body: some View {
        if let createdTrip {
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
                case 2: RecruitmentScheduleView(draft: $draft)
                case 3: RecruitmentPeopleView(draft: $draft)
                case 4: RecruitmentDetailView(draft: $draft)
                default: RecruitmentSummaryView(draft: $draft, onCreate: createRecruitment)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if step < 5 {
                CreationFooter(
                    backTitle: step == 1 ? "" : "이전",
                    nextTitle: step == 1
                        ? (draft.source == .custom ? "코스 만들러 가기" : "이 코스로 다음")
                        : "다음",
                    back: goBack
                ) {
                    if step == 1, draft.source == .custom {
                        showCustomEditor = true
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) { step += 1 }
                    }
                }
            }
        }
        .sheet(isPresented: $showCustomEditor) {
            NavigationStack {
                CustomCourseEditorView(stops: $draft.itinerary) {
                    showCustomEditor = false
                    withAnimation(.easeInOut(duration: 0.2)) { step = 2 }
                }
            }
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("screen.createRecruitment.\(courseID).step\(step)")
    }

    private func goBack() {
        if step == 1 { dismiss() } else { step -= 1 }
    }

    private func createRecruitment() {
        let id = "session-trip-\(UUID().uuidString)"
        let participants = Array(MockData.participants.prefix(1))
        let trip = TripRecruitment(
            id: id, courseID: draft.course.id, title: draft.recruitmentName, region: draft.course.region,
            coverMascot: draft.course.mascot, hostName: MockData.profile.name, hostAvatar: MockData.profile.avatar,
            schedule: draft.scheduleSummary, meetupPoint: draft.meeting.name, price: draft.estimatedCost,
            capacity: draft.capacity, joined: 1, minimumParticipants: draft.minimumParticipants,
            status: .open, summary: draft.note, vibe: "함께 속도를 맞추는 여행", tags: draft.course.tags,
            route: draft.itinerary.map(\.name), participants: participants,
            courseSource: draft.source, itinerary: draft.itinerary, scheduleDetails: draft.schedule,
            meetingDetails: draft.meeting, recruitmentDeadline: draft.deadline,
            minimumAge: draft.minimumAge, maximumAge: draft.maximumAge,
            genderRestriction: draft.genderRestriction,
            routeEditState: draft.source == .custom ? .editable : .linkedLocked
        )
        var thread = trip.createdChatThread(profile: MockData.profile)
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
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
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

    var body: some View {
        HStack(spacing: 14) {
            if !backTitle.isEmpty {
                // "코스 바꾸기"처럼 긴 라벨이 두 줄로 접히지 않게 폭을 내용에 맞춘다
                Button(backTitle, action: back)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 6)
                    .frame(minWidth: 56)
                    .frame(height: 50)
            }
            Button(nextTitle, action: next)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(MoyeoTheme.primary400)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .accessibilityIdentifier("createRecruitment.next")
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                DesignHeading("코스 선택", subtitle: "등록된 코스를 그대로 써도 되고, 직접 짜도 돼요.")
                SourceCard(source: .linked, selected: draft.source == .linked,
                           title: "등록된 코스로 떠나기",
                           detail: "TourAPI·경북나드리 기반으로 검증된 동선을 그대로 가져와요.",
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
                    VStack(spacing: 10) {
                        ForEach(MockData.courses.prefix(3)) { course in
                            linkedCourseRow(course)
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
        .accessibilityIdentifier("screen.createSource")
    }

    private func linkedCourseRow(_ course: TravelCourse) -> some View {
        let selected = draft.course.id == course.id
        return Button {
            draft.course = course
        } label: {
            HStack(spacing: 10) {
                MoyeoPhotoTile(mascot: course.mascot, mood: course.mood, height: 54, cornerRadius: 9)
                    .frame(width: 54)
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.title)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.ink)
                        .lineLimit(1)
                    Text("\(course.region) · \(course.duration) · 방문지 \(course.stops.count)")
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
    private let onContinue: () -> Void
    @State private var search = ""
    @State private var includesNextDay = false

    init(
        stops: Binding<[ItineraryStop]> = .constant(RecruitmentDraft.previewStops),
        onContinue: @escaping () -> Void = {}
    ) {
        _stops = stops
        self.onContinue = onContinue
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(MoyeoTheme.ink)
                        .frame(width: 44, height: 44)
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
                        PlaceSearchView { place in
                            add(place)
                        }
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "magnifyingglass")
                            Text(search.isEmpty ? "방문지 검색 (TourAPI · 경북 22개 시·군)" : search)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(search.isEmpty ? MoyeoTheme.muted : MoyeoTheme.ink)
                        .padding(.horizontal, 13)
                        .frame(height: 48)
                        .background(MoyeoTheme.card)
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(MoyeoTheme.line))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("customCourse.placeSearch")
                    HStack {
                        Text("Day 1").font(.subheadline.weight(.heavy))
                        Spacer()
                        Text("\(stops.count)개 방문지 · 최소 2개").font(.caption).foregroundStyle(MoyeoTheme.muted)
                    }
                    ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                        ItineraryStopRow(stop: stop, canRemove: stops.count > 2,
                                         moveUp: { move(index, -1) }, moveDown: { move(index, 1) },
                                         remove: { stops.remove(at: index); normalize() })
                    }
                    Button { addStop() } label: { Label("방문지 추가", systemImage: "plus") }
                        .buttonStyle(DesignOutlineButtonStyle(dashed: true))
                        .disabled(stops.count >= 20)
                        .accessibilityIdentifier("customCourse.addStop")
                    // 글자에 이미 '+'가 있으니 아이콘을 겹쳐 두지 않는다
                    Button { includesNextDay.toggle() } label: {
                        Text(includesNextDay ? "Day 2가 추가됐어요" : "+ 다음 날 추가 (1박 이상일 때)")
                    }
                    .buttonStyle(DesignOutlineButtonStyle())
                    DesignInfoBox(icon: "sparkles", text: "직접 만든 코스는 여행이 확정되기 전까지 방문지·시간·순서를 고칠 수 있어요. 수정하면 멤버 모두에게 알림이 가요.")
                }
                .padding(20)
            }
        }
        .safeAreaInset(edge: .bottom) {
            CreationFooter(
                backTitle: "취소",
                nextTitle: "이 코스로 계속하기",
                back: { dismiss() },
                next: {
                    dismiss()
                    onContinue()
                }
            )
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("screen.customCourse")
    }

    private func addStop() {
        guard stops.count < 20 else { return }
        stops.append(ItineraryStop(id: UUID().uuidString, day: includesNextDay ? 2 : 1,
                                   order: stops.count + 1, time: "17:00", name: "새 방문지", memo: "메모를 입력하세요"))
    }

    private func add(_ place: TourismPlace) {
        guard stops.count < 20, !stops.contains(where: { $0.name == place.title }) else { return }
        stops.append(
            ItineraryStop(
                id: place.id,
                day: includesNextDay ? 2 : 1,
                order: stops.count + 1,
                time: "17:00",
                name: place.title,
                memo: place.type.rawValue
            )
        )
    }

    private func move(_ index: Int, _ offset: Int) {
        let destination = index + offset
        guard stops.indices.contains(destination) else { return }
        stops.swapAt(index, destination)
        normalize()
    }

    private func normalize() {
        for index in stops.indices { stops[index].order = index + 1 }
    }
}

struct RecruitmentScheduleView: View {
    @Binding var draft: RecruitmentDraft

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
                            icon: "calendar", value: draft.schedule.startDate)
                if draft.schedule.kind == .dayTrip {
                    HStack(spacing: 10) {
                        DesignField(label: "여행 시작 시간 *", icon: "clock", value: draft.schedule.startTime ?? "08:00")
                        DesignField(label: "여행 종료 시간 *", icon: "clock", value: draft.schedule.endTime ?? "18:00")
                    }
                    DesignSummaryLine("당일치기   5/25(토) 08:00 - 18:00 · 10시간")
                } else {
                    DesignField(label: "여행 종료 날짜 *", icon: "calendar", value: draft.schedule.endDate ?? "2026. 05. 26 (일)")
                }
                Divider().overlay(MoyeoTheme.softLine)
                DesignField(label: "모집 마감일 *", icon: "clock", value: draft.deadline)
                Text("출발 3일 전까지만 선택할 수 있어요. 마감일에 최소 인원을 못 채우면 자동으로 소멸해요.")
                    .font(.caption).foregroundStyle(MoyeoTheme.muted)
                DesignField(label: "집합 장소 · 집합 시간 *", icon: "mappin.and.ellipse",
                            value: "\(draft.meeting.meetingTime) \(draft.meeting.name)", detail: draft.meeting.address)
                    .accessibilityIdentifier("createSchedule.meeting")
            }
            .padding(20)
        }
        .background(MoyeoTheme.background)
        .accessibilityIdentifier("screen.createSchedule")
    }
}

struct RecruitmentSchedulePreviewView: View {
    @State private var draft = RecruitmentDraft.preview

    var body: some View {
        RecruitmentStepScaffold(step: 2) {
            RecruitmentScheduleView(draft: $draft)
        }
        .accessibilityIdentifier("screen.createSchedule.preview")
    }
}

private struct RecruitmentPeopleView: View {
    @Binding var draft: RecruitmentDraft

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
                        value: "\(draft.minimumAge) ~ \(draft.maximumAge)세"
                    )
                    // 화면기획 17-4 — 설명은 행 안이 아니라 행 아래 캡션이다
                    Text("최소·최대 모두 20~100세 사이에서 정할 수 있어요. 조건에 맞지 않는 사용자에게는 신청 버튼이 비활성으로 보여요.")
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("createPeople.ageCaption")
                }
            }
            .padding(20)
        }
        .accessibilityIdentifier("screen.createPeople")
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

struct RecruitmentMeetingPreviewView: View {
    @State private var draft = RecruitmentDraft.preview

    var body: some View {
        RecruitmentStepScaffold(step: 2, nextTitle: "이 위치로 지정") {
            RecruitmentMeetingView(draft: $draft)
        }
        .accessibilityIdentifier("screen.createMeeting.preview")
    }
}

struct RecruitmentPeoplePreviewView: View {
    @State private var draft = RecruitmentDraft.preview

    var body: some View {
        RecruitmentStepScaffold(step: 3) {
            RecruitmentPeopleView(draft: $draft)
        }
    }
}

struct RecruitmentMeetingView: View {
    @Binding var draft: RecruitmentDraft
    @State private var search = ""
    @State private var detail = "터미널 정문 앞"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                DesignHeading("집합 장소 정하기", subtitle: "검색하거나 지도의 핀을 움직여 정확한 위치를 알려주세요.")
                ZStack(alignment: .top) {
                    MeetingMapCard(meeting: draft.meeting)
                        .accessibilityIdentifier("createMeeting.map")
                    LabelledSearchField(text: $search, prompt: "장소 검색 (TourAPI)")
                        .padding(12)
                }
                DesignField(label: "집합 장소 *", icon: "mappin.and.ellipse", value: draft.meeting.name)
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
                DesignSummaryLine(String(format: "좌표 (자동 저장)   %.6f, %.6f", draft.meeting.latitude, draft.meeting.longitude))
                DesignField(label: "집합 시간", icon: "clock", value: draft.meeting.meetingTime)
                DesignInfoBox(icon: "bell.fill", text: "집합 시간 30분 전에 모든 멤버에게 알림이 가고, 채팅방 상단 공지에도 자동으로 올라가요.")
            }
            .padding(20)
        }
        .background(MoyeoTheme.background)
        .accessibilityIdentifier("screen.createMeeting")
    }
}

private struct RecruitmentDetailView: View {
    @Binding var draft: RecruitmentDraft
    @State private var approvalMode = RecruitmentApprovalMode.automatic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                DesignHeading("어떤 여행인지 알려주세요", subtitle: "신청 전에 가장 많이 읽는 부분이에요.")
                DesignField(
                    label: "코스",
                    icon: "lock.fill",
                    value: draft.course.title,
                    detail: "Step 1에서 고른 코스라 여기서는 바꿀 수 없어요."
                )
                VStack(alignment: .leading, spacing: 8) {
                    Text("모집 이름 (채팅방 이름) *")
                        .font(.subheadline.weight(.heavy))
                    TextField("어떤 사람들과 어떻게 떠날지 적어주세요", text: $draft.recruitmentName)
                        .textInputAutocapitalization(.never)
                        .designInput()
                        .accessibilityIdentifier("createDetail.recruitmentName")
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
                DesignField(label: "예상 1인당 비용", icon: "wonsign.circle", value: draft.estimatedCost)
                // 화면기획은 세그먼트가 아니라 설명이 붙은 선택 카드 두 장이다
                VStack(alignment: .leading, spacing: 8) {
                    Text("신청 승인 방식")
                        .font(.subheadline.weight(.heavy))
                    ForEach(RecruitmentApprovalMode.allCases, id: \.self) { mode in
                        ApprovalModeCard(mode: mode, selected: approvalMode == mode) {
                            approvalMode = mode
                        }
                    }
                }
                DesignInfoBox(icon: "person.badge.shield.checkmark", text: "마감 전까지 세부 조건을 수정할 수 있고 변경 내용은 신청자에게 안내돼요.")
            }
            .padding(20)
        }
        .background(MoyeoTheme.background)
        .accessibilityIdentifier("screen.createDetail")
    }
}

struct RecruitmentDetailPreviewView: View {
    @State private var draft = RecruitmentDraft.preview

    var body: some View {
        RecruitmentStepScaffold(step: 4) {
            RecruitmentDetailView(draft: $draft)
        }
    }
}

struct RecruitmentSummaryView: View {
    @Binding var draft: RecruitmentDraft
    let onCreate: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                DesignHeading("이대로 모집을 열까요?", subtitle: "등록 후에도 마감 전까지는 대부분 고칠 수 있어요.")
                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(draft.recruitmentName).font(.subheadline.weight(.heavy))
                            Label(draft.course.title, systemImage: "map.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MoyeoTheme.muted)
                        }
                        Spacer()
                        Pill(text: draft.source.title)
                            .accessibilityIdentifier("createSummary.source")
                    }
                    SummaryRow("calendar", "일정", draft.scheduleSummary)
                    SummaryRow("mappin.and.ellipse", "집합", "\(draft.meeting.meetingTime) \(draft.meeting.name) \(draft.meeting.detail)")
                    SummaryRow("map", "좌표", String(format: "%.6f, %.6f", draft.meeting.latitude, draft.meeting.longitude))
                    SummaryRow("person.2", "인원", "최소 \(draft.minimumParticipants)명 · 최대 \(draft.capacity)명")
                    SummaryRow("slider.horizontal.3", "조건", "\(draft.minimumAge)~\(draft.maximumAge)세 · \(draft.genderSummary)")
                    SummaryRow("wonsign.circle", "비용", "\(draft.estimatedCost) (예상)")
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
                // 화면기획 17-7 — 두 번째 안내 카드는 아이콘 없이 텍스트만 둔다
                DesignInfoBox(icon: nil, text: "최소 \(draft.minimumParticipants)명이 모이면 채팅방이 자동으로 열리고, 마감일까지 못 채우면 자연스럽게 소멸돼요.")
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            CreationFooter(backTitle: "이전", nextTitle: "모집 열기", back: {}, next: onCreate)
        }
        .accessibilityIdentifier("screen.createSummary")
    }
}

struct RecruitmentSummaryPreviewView: View {
    let source: CourseSource
    @State private var draft: RecruitmentDraft

    init(source: CourseSource) {
        self.source = source
        var preview = RecruitmentDraft.preview
        preview.source = source
        _draft = State(initialValue: preview)
    }

    var body: some View {
        RecruitmentStepScaffold(step: 5, showsFooter: false) {
            RecruitmentSummaryView(draft: $draft, onCreate: {})
        }
        .accessibilityIdentifier("screen.createSummary.\(source.rawValue)")
    }
}

struct CourseRouteEditView: View {
    let trip: TripRecruitment
    let state: RouteEditState
    let onSaved: (TripRecruitment, [ItineraryStop]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var stops: [ItineraryStop]
    @State private var showNoticeComposer = false

    init(trip: TripRecruitment, state: RouteEditState? = nil,
         onSaved: @escaping (TripRecruitment, [ItineraryStop]) -> Void = { _, _ in }) {
        self.trip = trip
        self.state = state ?? trip.routeEditState
        self.onSaved = onSaved
        let route = trip.itinerary.isEmpty ? trip.route.enumerated().map {
            ItineraryStop(id: "\(trip.id)-\($0.offset)", day: 1, order: $0.offset + 1,
                          time: ["09:00", "10:30", "14:00", "16:30"][safe: $0.offset] ?? "17:00",
                          name: $0.element, memo: "방문 장소")
        } : trip.itinerary
        _stops = State(initialValue: route)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                Spacer()
                Text("여행 경로").font(.headline.weight(.heavy))
                Spacer()
                if state == .editable {
                    Button("저장") { save() }.font(.subheadline.weight(.heavy)).foregroundStyle(MoyeoTheme.primary300)
                        .frame(width: 44)
                } else {
                    Image(systemName: "ellipsis").frame(width: 44)
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
                    HStack {
                        Text("Day 1").font(.subheadline.weight(.heavy))
                        Spacer()
                        if state != .editable {
                            Label("수정 불가", systemImage: "lock")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(MoyeoTheme.muted)
                                .accessibilityIdentifier("courseEdit.readOnlyBadge")
                        }
                    }
                    ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                        ItineraryStopRow(stop: stop, canRemove: state == .editable && stops.count > 2,
                                         locked: state != .editable,
                                         moveUp: { move(index, -1) }, moveDown: { move(index, 1) },
                                         remove: { stops.remove(at: index) })
                    }
                    if state == .editable {
                        Button { addStop() } label: { Label("방문지 추가", systemImage: "plus") }
                            .buttonStyle(DesignOutlineButtonStyle(dashed: true))
                    }
                    Text("집합 정보").font(.headline.weight(.heavy))
                    DesignField(label: "집합 장소 · 집합 시간", icon: "mappin.and.ellipse",
                                value: "07:50 · \(trip.meetupPoint)")
                }
                .padding(20)
            }
        }
        .safeAreaInset(edge: .bottom) {
            switch state {
            case .editable:
                CreationFooter(backTitle: "취소", nextTitle: "저장하고 멤버에게 알리기", back: { dismiss() }, next: save)
            case .linkedLocked:
                // 경로는 못 바꾸지만 코스 교체와 집합 정보 수정은 열려 있다 (화면기획)
                CreationFooter(
                    backTitle: "코스 바꾸기",
                    nextTitle: "집합 정보 수정",
                    back: { dismiss() },
                    next: { dismiss() }
                )
            case .tripConfirmed:
                // 화면기획 18-3 — 공지로 알리기(외곽선) + 비활성 경로 수정 두 버튼
                HStack(spacing: 14) {
                    Button("공지로 알리기") { showNoticeComposer = true }
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.brandText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
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
        .alert("채팅방 공지 작성", isPresented: $showNoticeComposer) {
            Button("확인") {}
        } message: { Text("확정된 여행의 변경 사항은 경로를 수정하지 않고 공지로 안내해요.") }
        .accessibilityIdentifier("screen.courseEdit.\(state.rawValue)")
    }

    /// 화면기획 18-x 헤더 타이틀 — 코스 이름 (모집 이름이 아니다)
    private var headerTitle: String {
        MockData.course(for: trip.courseID)?.title ?? trip.title
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
            DesignInfoBox(icon: "lock.fill", text: "등록 코스의 방문지·순서·시간은 고정돼요. 집합 정보와 모집 조건은 수정할 수 있어요.")
        case .tripConfirmed:
            DesignWarningBox(text: "여행이 확정돼 경로가 잠겼어요. 변경이 필요하면 채팅방 공지로 알려주세요.")
        }
    }

    private func save() { onSaved(trip, stops); dismiss() }
    private func addStop() { guard stops.count < 20 else { return }; stops.append(ItineraryStop(id: UUID().uuidString, day: 1, order: stops.count + 1, time: "17:00", name: "새 방문지", memo: "메모")) }
    private func move(_ index: Int, _ offset: Int) { let target = index + offset; guard stops.indices.contains(target), state == .editable else { return }; stops.swapAt(index, target) }
}

struct NoticeHistoryView: View {
    let thread: ChatThread
    let onCreate: (ChatThread, TripNotice) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var notices: [TripNotice]
    @State private var showComposer = false

    init(thread: ChatThread, onCreate: @escaping (ChatThread, TripNotice) -> Void = { _, _ in }) {
        self.thread = thread
        self.onCreate = onCreate
        _notices = State(initialValue: thread.pinnedNotices.isEmpty ? Self.previewNotices : thread.pinnedNotices)
    }

    var body: some View {
        VStack(spacing: 0) {
            NoticeHistoryNavigationBar(onBack: dismiss.callAsFunction)
            ScrollView {
                // 화면기획은 코스 이름과 공지 개수를 먼저 두고, 섹션은 "상단 고정 중" / "지난 공지"다
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(thread.courseName.isEmpty ? thread.tripTitle : thread.courseName)
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(MoyeoTheme.ink)
                        Text("공지 \(notices.count)개 · 고정 \(notices.filter(\.isPinned).count) / 최대 3")
                            .font(.caption2)
                            .foregroundStyle(MoyeoTheme.muted)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    NoticeSectionTitle(title: "상단 고정 중")
                    ForEach(notices.filter(\.isPinned)) { notice in NoticeCard(notice: notice) }
                    NoticeSectionTitle(title: "지난 공지")
                    ForEach(notices.filter { !$0.isPinned }) { notice in NoticeCard(notice: notice) }

                    Text("공지는 호스트만 올릴 수 있고, 고정은 최대 3개까지예요. 고정을 해제해도 이력에는 그대로 남아요.")
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // 화면기획은 하단 고정 CTA다 (툴바 + 아이콘이 아니라).
            // 20-3은 호스트 시점 화면이라 기획·웹·안드로이드 모두 버튼을 항상 보여준다.
            AuthPrimaryButton(title: "＋ 새 공지 작성 (호스트)", accessibilityIdentifier: "noticeHistory.create") {
                showComposer = true
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 28)
            .background(MoyeoTheme.card)
        }
        .alert("새 공지", isPresented: $showComposer) {
            Button("작성") { createNotice() }
            Button("취소", role: .cancel) {}
        } message: { Text("집합 장소나 준비물 변경을 모든 멤버에게 알려요.") }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .accessibilityIdentifier("screen.noticeHistory")
    }

    private func createNotice() {
        let notice = TripNotice(id: UUID().uuidString, title: "호스트 새 공지", body: "집합 정보를 다시 확인해주세요.", createdAt: "지금", isPinned: notices.filter(\.isPinned).count < 3)
        notices.insert(notice, at: 0)
        onCreate(thread, notice)
    }

    // 공지 이력은 실제로 쌓였을 때의 다양함을 보여줘야 검수가 된다 (화면기획 기준 목데이터)
    private static let previewNotices = [
        TripNotice(
            id: "notice-meet",
            title: "집합 장소 · 시간",
            body: "5/25(토) 07:50 청송 시외버스터미널 정문 앞\n08:00 정각에 출발해요. 늦으면 채팅방에 남겨주세요!",
            createdAt: "5월 20일 오후 2:14",
            isPinned: true
        ),
        TripNotice(
            id: "notice-pack",
            title: "준비물",
            body: "편한 운동화, 얇은 바람막이, 물 500ml 정도면 충분해요.",
            createdAt: "5월 21일 오전 10:02",
            isPinned: true
        ),
        TripNotice(
            id: "notice-parking",
            title: "주차 안내",
            body: "터미널 공영주차장 이용하시면 돼요 (하루 3,000원)",
            createdAt: "5월 18일 오후 7:30",
            isPinned: false
        ),
        TripNotice(
            id: "notice-lunch",
            title: "점심 메뉴 투표 결과",
            body: "달기약수탕 백숙으로 정해졌어요 🍲",
            createdAt: "5월 17일 오후 9:12",
            isPinned: false
        )
    ]
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
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(MoyeoTheme.ink)
                        .frame(width: 44, height: 44)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .font(.caption)
                    .foregroundStyle(notice.isPinned ? MoyeoTheme.forest : MoyeoTheme.muted)
                Text(notice.title)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(notice.isPinned ? MoyeoTheme.forest : MoyeoTheme.text700)
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
            if notice.id == "notice-meet" {
                NoticeRoutePreview()
                    .frame(height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            HStack(spacing: 6) {
                Text("숲속여행자 (호스트)")
                Text("·")
                Text(notice.createdAt).monospacedDigit()
                Spacer(minLength: 0)
                Text(notice.isPinned ? "수정" : "다시 고정")
                    .foregroundStyle(MoyeoTheme.forest)
                    .fontWeight(.heavy)
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

/// 집합 장소 공지의 지도 미리보기 (화면기획 20-3).
/// 경로선을 그리면 선 그래프처럼 읽힌다 — 집합 한 지점이므로 지도면 + 가운데 핀만 둔다.
private struct NoticeRoutePreview: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                MoyeoTheme.mapGreen
                Path { path in
                    path.move(to: CGPoint(x: 0, y: proxy.size.height * 0.72))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height * 0.72))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height))
                    path.addLine(to: CGPoint(x: 0, y: proxy.size.height))
                    path.closeSubpath()
                }
                .fill(MoyeoTheme.mapWater.opacity(0.45))
                Image(systemName: "mappin")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(MoyeoTheme.forest)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 2.5))
                    .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.44)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("집합 장소 지도")
    }
}

private struct RouteSchematic: View {
    let stops: [ItineraryStop]
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                MoyeoTheme.mapGreen
                Path { path in
                    let count = max(stops.count, 2)
                    for index in 0..<count {
                        let x = 55 + CGFloat(index) * max((proxy.size.width - 110) / CGFloat(count - 1), 1)
                        let y = proxy.size.height - 38 - CGFloat(index) * 22
                        if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }.stroke(MoyeoTheme.primary300, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                ForEach(Array(stops.prefix(6).enumerated()), id: \.element.id) { index, stop in
                    let count = max(min(stops.count, 6), 2)
                    Text("\(stop.order)").font(.caption.weight(.heavy)).foregroundStyle(.white)
                        .frame(width: 30, height: 30).background(MoyeoTheme.primary300).clipShape(Circle())
                        .position(x: 55 + CGFloat(index) * max((proxy.size.width - 110) / CGFloat(count - 1), 1),
                                  y: proxy.size.height - 38 - CGFloat(index) * 22)
                }
            }
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("경로 지도, 방문지 \(stops.count)곳")
    }
}

private struct MeetingMapCard: View {
    let meeting: MeetingPointDetails
    var body: some View {
        ZStack {
            MoyeoTheme.mapGreen
            VStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill").font(.system(size: 42)).foregroundStyle(MoyeoTheme.primary300)
                Text(meeting.name).font(.caption.weight(.heavy))
                Text("핀을 움직여 위치 조정").font(.caption2).foregroundStyle(MoyeoTheme.muted)
            }
        }
        .frame(height: 210).clipShape(RoundedRectangle(cornerRadius: 9))
        .accessibilityLabel("지도 핀, \(meeting.name)")
    }
}

private struct ItineraryStopRow: View {
    let stop: ItineraryStop
    let canRemove: Bool
    var locked = false
    let moveUp: () -> Void
    let moveDown: () -> Void
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Menu {
                Button("위로 이동", action: moveUp)
                Button("아래로 이동", action: moveDown)
            } label: { Image(systemName: locked ? "lock.fill" : "line.3.horizontal").foregroundStyle(MoyeoTheme.muted).frame(width: 24, height: 44) }
            .disabled(locked)
            // 잠긴 행의 순번 원은 화면기획의 중립 회색 톤이다
            Text("\(stop.order)").font(.caption.weight(.heavy)).foregroundStyle(.white).frame(width: 30, height: 30).background(locked ? MoyeoTheme.text400 : MoyeoTheme.primary300).clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                HStack { Text(stop.time).foregroundStyle(MoyeoTheme.primary300); Text(stop.name).foregroundStyle(MoyeoTheme.ink) }.font(.caption.weight(.heavy))
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

private struct DesignField: View {
    let label: String
    let icon: String
    let value: String
    var detail: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(.caption.weight(.heavy)).foregroundStyle(MoyeoTheme.text700)
            HStack(spacing: 10) { Image(systemName: icon).foregroundStyle(MoyeoTheme.muted); VStack(alignment: .leading, spacing: 2) { Text(value).font(.subheadline.weight(.heavy)).foregroundStyle(MoyeoTheme.ink); if let detail { Text(detail).font(.caption2).foregroundStyle(MoyeoTheme.muted) } }; Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(MoyeoTheme.text400) }
                .padding(.horizontal, 14).frame(minHeight: detail == nil ? 50 : 60).background(MoyeoTheme.card).overlay(RoundedRectangle(cornerRadius: 9).stroke(MoyeoTheme.line)).clipShape(RoundedRectangle(cornerRadius: 9))
        }
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
    var body: some View { HStack(alignment: .top, spacing: 10) { Image(systemName: icon).foregroundStyle(MoyeoTheme.muted).frame(width: 18); Text(label).font(.caption).foregroundStyle(MoyeoTheme.muted).frame(width: 36, alignment: .leading); Text(value).font(.caption.weight(.heavy)).foregroundStyle(MoyeoTheme.ink); Spacer(minLength: 0) } }
}

private struct LabelledSearchField: View {
    @Binding var text: String
    let prompt: String
    var body: some View { HStack { Image(systemName: "magnifyingglass"); TextField(prompt, text: $text) }.font(.caption).foregroundStyle(MoyeoTheme.muted).padding(.horizontal, 14).frame(height: 44).background(MoyeoTheme.background).overlay(RoundedRectangle(cornerRadius: 9).stroke(MoyeoTheme.line)).clipShape(RoundedRectangle(cornerRadius: 9)) }
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
// swiftlint:enable file_length line_length
