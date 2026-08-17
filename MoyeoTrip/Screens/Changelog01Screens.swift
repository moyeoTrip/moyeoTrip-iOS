// swiftlint:disable file_length line_length
import SwiftUI

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
                case 4: RecruitmentMeetingView(draft: $draft)
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
            id: id, courseID: draft.course.id, title: draft.course.title, region: draft.course.region,
            coverMascot: draft.course.mascot, hostName: MockData.profile.name, hostAvatar: MockData.profile.avatar,
            schedule: draft.scheduleSummary, meetupPoint: draft.meeting.name, price: "무료",
            capacity: draft.capacity, joined: 1, minimumParticipants: draft.minimumParticipants,
            status: .open, summary: draft.note, vibe: "함께 속도를 맞추는 여행", tags: draft.course.tags,
            route: draft.itinerary.map(\.name), participants: participants,
            courseSource: draft.source, itinerary: draft.itinerary, scheduleDetails: draft.schedule,
            meetingDetails: draft.meeting, recruitmentDeadline: draft.deadline,
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

private struct CreationStepDots: View {
    let current: Int
    private let labels = ["코스", "일정", "인원", "세부", "리뷰"]
    private let icons = ["point.topleft.down.to.point.bottomright.curvepath", "calendar", "person.2", "doc.text", "star.fill"]

    var body: some View {
        HStack {
            ForEach(labels.indices, id: \.self) { index in
                VStack(spacing: 5) {
                    Image(systemName: index + 1 < current ? "checkmark" : icons[index])
                        .font(.caption.weight(.bold))
                        .frame(width: 34, height: 34)
                        .foregroundStyle(index + 1 <= current ? MoyeoTheme.primary300 : MoyeoTheme.text400)
                        .overlay(Circle().stroke(index + 1 <= current ? MoyeoTheme.primary300 : MoyeoTheme.line))
                    Text(labels[index]).font(.caption2.weight(.bold))
                }
                .foregroundStyle(index + 1 <= current ? MoyeoTheme.primary300 : MoyeoTheme.text400)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
        .accessibilityIdentifier("createRecruitment.progress.\(current)of5")
    }
}

private struct CreationFooter: View {
    let backTitle: String
    let nextTitle: String
    let back: () -> Void
    let next: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            if !backTitle.isEmpty {
                Button(backTitle, action: back)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                    .frame(width: 56, height: 50)
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

private struct RecruitmentSourceView: View {
    @Binding var draft: RecruitmentDraft
    let onOpenCustomEditor: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                DesignHeading("코스 선택", subtitle: "등록된 코스를 그대로 써도 되고, 직접 짜도 돼요.")
                SourceCard(source: .linked, selected: draft.source == .linked,
                           title: "등록된 코스로 떠나기",
                           detail: "TourAPI·경북나드리 기반으로 검증된 동선을 그대로 가져와요.",
                           icon: "map.fill") {
                    draft.source = .linked
                }
                SourceCard(source: .custom, selected: draft.source == .custom,
                           title: "코스 직접 만들기",
                           detail: "방문지와 시간을 내가 짜요. 저장하면 다른 여행자에게도 코스로 노출돼요.",
                           icon: "point.3.connected.trianglepath.dotted") {
                    draft.source = .custom
                }
                if draft.source == .linked {
                    SupportCourseSummary(course: draft.course)
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
}

private struct SourceCard: View {
    let source: CourseSource
    let selected: Bool
    let title: String
    let detail: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .frame(width: 42, height: 42)
                    .background(MoyeoTheme.leaf)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.headline.weight(.heavy))
                    Text(detail).font(.caption.weight(.semibold)).foregroundStyle(MoyeoTheme.muted)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? MoyeoTheme.primary300 : MoyeoTheme.text400)
            }
            .foregroundStyle(MoyeoTheme.ink)
            .padding(16)
            .background(MoyeoTheme.card)
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(selected ? MoyeoTheme.primary300 : MoyeoTheme.line, lineWidth: selected ? 2 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 9))
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
                Button { dismiss() } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
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
                    LabelledSearchField(text: $search, prompt: "방문지 검색 (TourAPI · 경북 22개 시·군)")
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
                    Button { includesNextDay.toggle() } label: {
                        HStack {
                            Image(systemName: includesNextDay ? "checkmark.circle.fill" : "plus.circle")
                            Text(includesNextDay ? "Day 2가 추가됐어요" : "+ 다음 날 추가 (1박 이상일 때)")
                        }
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
                DesignSegment(items: TripScheduleKind.allCases, selected: $draft.schedule.kind)
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

private struct RecruitmentPeopleView: View {
    @Binding var draft: RecruitmentDraft

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DesignHeading("인원 정하기", subtitle: "최소 출발 인원과 최대 모집 인원을 정해주세요.")
                Stepper("최소 출발 인원  \(draft.minimumParticipants)명", value: $draft.minimumParticipants, in: 2...draft.capacity)
                    .designInput()
                Stepper("최대 모집 인원  \(draft.capacity)명", value: $draft.capacity, in: max(3, draft.minimumParticipants)...12)
                    .designInput()
                DesignInfoBox(icon: "bubble.left.and.bubble.right.fill", text: "최소 인원이 모이면 채팅방이 자동으로 열려요. 모집 마감 전까지 정원을 채울 수 있어요.")
            }
            .padding(20)
        }
        .accessibilityIdentifier("screen.createPeople")
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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["터미널 정문 앞", "2번 출구", "주차장 입구"], id: \.self) { option in
                            Button(option) { detail = option }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(detail == option ? MoyeoTheme.primary300 : MoyeoTheme.ink)
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .background(detail == option ? MoyeoTheme.leaf : MoyeoTheme.card)
                                .overlay(RoundedRectangle(cornerRadius: 17).stroke(detail == option ? MoyeoTheme.primary300 : MoyeoTheme.line))
                                .clipShape(RoundedRectangle(cornerRadius: 17))
                        }
                    }
                }
                DesignField(label: "집합 장소 *", icon: "mappin.and.ellipse", value: draft.meeting.name)
                DesignField(label: "상세 안내", icon: "signpost.right", value: detail)
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

struct RecruitmentSummaryView: View {
    @Binding var draft: RecruitmentDraft
    let onCreate: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                DesignHeading("이대로 모집을 열까요?", subtitle: "등록 후에도 마감 전까지는 대부분 고칠 수 있어요.")
                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        Text(draft.course.title).font(.subheadline.weight(.heavy))
                        Spacer()
                        Pill(text: draft.source.title)
                            .accessibilityIdentifier("createSummary.source")
                    }
                    SummaryRow("calendar", "일정", draft.scheduleSummary)
                    SummaryRow("mappin.and.ellipse", "집합", "\(draft.meeting.meetingTime) \(draft.meeting.name) \(draft.meeting.detail)")
                    SummaryRow("map", "좌표", String(format: "%.6f, %.6f", draft.meeting.latitude, draft.meeting.longitude))
                    SummaryRow("person.2", "인원", "최소 \(draft.minimumParticipants)명 · 최대 \(draft.capacity)명 · 성별 제한 없음")
                    SummaryRow("clock", "마감", draft.deadline)
                }
                .padding(16)
                .background(MoyeoTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(MoyeoTheme.softLine))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                DesignInfoBox(
                    icon: draft.source == .custom ? "sparkles" : "lock.fill",
                    text: draft.source == .custom
                        ? "호스트가 직접 만든 코스예요. 여행이 확정되기 전까지 방문지·시간·순서를 자유롭게 고칠 수 있고, 수정하면 멤버 모두에게 알림이 가요."
                        : "서비스에 등록된 코스를 그대로 가져왔어요. 경로(방문지·순서)는 수정할 수 없고, 일정·집합 장소·인원 조건은 마감 전까지 바꿀 수 있어요.",
                    neutral: draft.source == .linked
                )
                DesignInfoBox(icon: "bubble.left.fill", text: "최소 \(draft.minimumParticipants)명이 모이면 채팅방이 자동으로 열리고, 마감일까지 못 채우면 자연스럽게 소멸돼요.")
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            CreationFooter(backTitle: "이전", nextTitle: "모집 열기", back: {}, next: onCreate)
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
                            Text(trip.title).font(.subheadline.weight(.heavy))
                            Text("\(trip.schedule) · \(trip.joined)/\(trip.capacity)명").font(.caption).foregroundStyle(MoyeoTheme.muted)
                        }
                        Spacer()
                        Pill(text: trip.courseSource.title)
                    }
                    policyNotice
                    RouteSchematic(stops: stops)
                    Text("Day 1").font(.subheadline.weight(.heavy))
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
            if state == .editable {
                CreationFooter(backTitle: "취소", nextTitle: "저장하고 멤버에게 알리기", back: { dismiss() }, next: save)
            } else if state == .tripConfirmed {
                CreationFooter(backTitle: "", nextTitle: "공지로 알리기", back: {}, next: { showNoticeComposer = true })
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
    @State private var notices: [TripNotice]
    @State private var showComposer = false

    init(thread: ChatThread, onCreate: @escaping (ChatThread, TripNotice) -> Void = { _, _ in }) {
        self.thread = thread
        self.onCreate = onCreate
        _notices = State(initialValue: thread.pinnedNotices.isEmpty ? Self.previewNotices : thread.pinnedNotices)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                DesignHeading("고정 공지", subtitle: "채팅방 상단에는 최대 3개까지 고정할 수 있어요.")
                ForEach(notices.filter(\.isPinned)) { notice in NoticeCard(notice: notice) }
                DesignHeading("지난 공지", subtitle: nil)
                ForEach(notices.filter { !$0.isPinned }) { notice in NoticeCard(notice: notice) }
            }
            .padding(20)
        }
        .navigationTitle("공지 이력")
        .toolbar {
            if thread.isCurrentUserHost {
                Button { showComposer = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("공지 작성")
            }
        }
        .alert("새 공지", isPresented: $showComposer) {
            Button("작성") { createNotice() }
            Button("취소", role: .cancel) {}
        } message: { Text("집합 장소나 준비물 변경을 모든 멤버에게 알려요.") }
        .background(MoyeoTheme.background)
        .accessibilityIdentifier("screen.noticeHistory")
    }

    private func createNotice() {
        let notice = TripNotice(id: UUID().uuidString, title: "호스트 새 공지", body: "집합 정보를 다시 확인해주세요.", createdAt: "지금", isPinned: notices.filter(\.isPinned).count < 3)
        notices.insert(notice, at: 0)
        onCreate(thread, notice)
    }

    private static let previewNotices = [
        TripNotice(id: "notice-meet", title: "집합 장소 안내", body: "07:50 청송 시외버스터미널 정문 앞에서 만나요.", createdAt: "오늘", isPinned: true),
        TripNotice(id: "notice-route", title: "경로가 변경됐어요", body: "점심 장소가 달기약수탕으로 추가됐어요.", createdAt: "어제", isPinned: true),
        TripNotice(id: "notice-pack", title: "준비물 안내", body: "편한 신발과 개인 물을 준비해주세요.", createdAt: "3일 전", isPinned: false)
    ]
}

private struct NoticeCard: View {
    let notice: TripNotice
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { if notice.isPinned { Image(systemName: "pin.fill").foregroundStyle(MoyeoTheme.primary300) }; Text(notice.title).font(.subheadline.weight(.heavy)); Spacer(); Text(notice.createdAt).font(.caption).foregroundStyle(MoyeoTheme.muted) }
            Text(notice.body).font(.subheadline).foregroundStyle(MoyeoTheme.text700)
        }
        .padding(15).background(MoyeoTheme.card).overlay(RoundedRectangle(cornerRadius: 9).stroke(MoyeoTheme.softLine)).clipShape(RoundedRectangle(cornerRadius: 9))
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
            Text("\(stop.order)").font(.caption.weight(.heavy)).foregroundStyle(.white).frame(width: 30, height: 30).background(locked ? MoyeoTheme.muted : MoyeoTheme.primary300).clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                HStack { Text(stop.time).foregroundStyle(MoyeoTheme.primary300); Text(stop.name).foregroundStyle(MoyeoTheme.ink) }.font(.caption.weight(.heavy))
                Text(stop.memo).font(.caption2).foregroundStyle(MoyeoTheme.muted)
            }
            Spacer()
            if canRemove && !locked { Button(action: remove) { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("\(stop.name) 삭제") }
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
    let icon: String
    let text: String
    var neutral = false
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(neutral ? MoyeoTheme.muted : MoyeoTheme.primary300)
            Text(text).font(.caption).foregroundStyle(neutral ? MoyeoTheme.ink : Color(hex: "#264332"))
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(neutral ? MoyeoTheme.card : Color(hex: "#EEF7F1"))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(neutral ? MoyeoTheme.softLine : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

private struct DesignWarningBox: View {
    let text: String
    var body: some View { HStack(alignment: .top, spacing: 10) { Image(systemName: "clock.badge.exclamationmark"); Text(text).font(.caption); Spacer(minLength: 0) }.foregroundStyle(Color(hex: "#8B6421")).padding(14).background(Color(hex: "#FFF1D2")).clipShape(RoundedRectangle(cornerRadius: 9)) }
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
    var body: some View { HStack(spacing: 0) { ForEach(items, id: \.self) { item in Button { selected = item } label: { Text(item.rawValue).font(.caption.weight(.heavy)).foregroundStyle(selected == item ? MoyeoTheme.primary300 : MoyeoTheme.muted).frame(maxWidth: .infinity).frame(height: 44).background(selected == item ? MoyeoTheme.leaf : Color.clear).clipShape(RoundedRectangle(cornerRadius: 8)) }.buttonStyle(.plain) } }.padding(4).background(MoyeoTheme.card).overlay(RoundedRectangle(cornerRadius: 9).stroke(MoyeoTheme.softLine)).clipShape(RoundedRectangle(cornerRadius: 9)) }
}

private struct DesignOutlineButtonStyle: ButtonStyle {
    var dashed = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.heavy)).foregroundStyle(MoyeoTheme.primary300).frame(maxWidth: .infinity).frame(height: 48).background(MoyeoTheme.card).overlay(RoundedRectangle(cornerRadius: 9).stroke(MoyeoTheme.primary300.opacity(0.65), style: StrokeStyle(lineWidth: 1, dash: dashed ? [4] : []))).clipShape(RoundedRectangle(cornerRadius: 9)).opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private extension View {
    func designInput() -> some View { self.font(.subheadline.weight(.heavy)).foregroundStyle(MoyeoTheme.ink).padding(14).background(MoyeoTheme.card).overlay(RoundedRectangle(cornerRadius: 9).stroke(MoyeoTheme.line)).clipShape(RoundedRectangle(cornerRadius: 9)) }
}

private extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}
// swiftlint:enable file_length line_length
