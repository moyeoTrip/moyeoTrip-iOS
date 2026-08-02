import SwiftUI

enum SupportRoute: Hashable, Identifiable {
    case authFlow
    case notifications
    case createRecruitment(String)
    case hostManage(String)
    case search

    var id: String {
        switch self {
        case .authFlow:
            return "authFlow"
        case .notifications:
            return "notifications"
        case .createRecruitment(let courseID):
            return "createRecruitment.\(courseID)"
        case .hostManage(let tripID):
            return "hostManage.\(tripID)"
        case .search:
            return "search"
        }
    }
}

struct SupportDestinationView: View {
    let route: SupportRoute
    var tripContext = TripInteractionContext()
    var onAuthCompleted: () -> Void = {}
    @Binding var feedPosts: [FeedPost]

    init(route: SupportRoute, tripContext: TripInteractionContext = TripInteractionContext(),
         feedPosts: Binding<[FeedPost]> = .constant(MockData.feedPosts),
         onAuthCompleted: @escaping () -> Void = {}) {
        self.route = route
        self.tripContext = tripContext
        self.onAuthCompleted = onAuthCompleted
        _feedPosts = feedPosts
    }

    var body: some View {
        switch route {
        case .authFlow:
            AuthFlowView(onComplete: onAuthCompleted)
        case .notifications:
            NotificationCenterView(tripContext: tripContext, feedPosts: $feedPosts)
        case .createRecruitment(let courseID):
            CreateRecruitmentView(
                courseID: courseID,
                onCreated: tripContext.onCreateRecruitment,
                onSendChatMessage: tripContext.onSendChatMessage,
                onApproveApplicant: tripContext.onApproveHostApplicant,
                onRejectApplicant: tripContext.onRejectHostApplicant,
                onSetRecruitmentClosed: tripContext.onSetRecruitmentClosed
            )
        case .hostManage(let tripID):
            let trip = tripContext.trips.first { $0.id == tripID } ?? MockData.trip(for: tripID) ?? MockData.trips[0]
            HostManageView(
                trip: trip,
                thread: tripContext.chatThreadProvider(trip),
                onSendChatMessage: tripContext.onSendChatMessage,
                onApproveApplicant: tripContext.onApproveHostApplicant,
                onRejectApplicant: tripContext.onRejectHostApplicant,
                onSetRecruitmentClosed: tripContext.onSetRecruitmentClosed
            )
        case .search:
            SearchView(tripContext: tripContext)
        }
    }
}

private struct NotificationCenterView: View {
    var tripContext = TripInteractionContext()
    @Binding var feedPosts: [FeedPost]
    @State private var selectedCourse: TravelCourse?
    @State private var selectedTrip: TripRecruitment?
    @State private var selectedPost: FeedPost?

    private let items = [
        SupportNotification(
            title: "출발 확정까지 1명 남았어요",
            body: "주왕산 & 주산지 힐링 트레킹",
            time: "방금",
            icon: "bell.badge.fill",
            target: .trip("trip-cheongsong-juwangsan")
        ),
        SupportNotification(
            title: "새 댓글이 달렸어요",
            body: "경주 단풍·야경 기록에 반응이 왔어요",
            time: "12분 전",
            icon: "bubble.left.and.bubble.right.fill",
            target: .post("feed-03")
        ),
        SupportNotification(
            title: "날씨 추천이 바뀌었어요",
            body: "맑음 예보에 맞춰 경주 첨성대 코스를 추천해요",
            time: "오늘",
            icon: "sun.max.fill",
            target: .course("course-gyeongju-history")
        ),
        SupportNotification(
            title: "하회마을 모임이 확정됐어요",
            body: "모임 채팅방에서 준비물을 확인해보세요",
            time: "어제",
            icon: "checkmark.seal.fill",
            target: .trip("trip-andong-hahoe")
        )
    ]

    var body: some View {
        SupportList(title: "알림") {
            ForEach(items) { item in
                Button {
                    open(item.target)
                } label: {
                    SupportCard {
                        HStack(alignment: .top, spacing: 12) {
                            SupportIconBubble(systemImage: item.icon)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.title)
                                    .font(.subheadline.weight(.heavy))
                                    .foregroundStyle(MoyeoTheme.ink)
                                Text(item.body)
                                    .font(.subheadline)
                                    .foregroundStyle(MoyeoTheme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(item.time)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(MoyeoTheme.forest)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(MoyeoTheme.text400)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationDestination(item: $selectedCourse) { course in
            CourseDetailView(
                course: course,
                tripContext: tripContext
            )
        }
        .navigationDestination(item: $selectedTrip) { trip in
            TripDetailView(
                trip: trip,
                isApplied: tripContext.isApplied(trip),
                threadProvider: tripContext.chatThreadProvider,
                onApplied: tripContext.onApplyTrip,
                onSendChatMessage: tripContext.onSendChatMessage
            )
        }
        .navigationDestination(item: $selectedPost) { post in
            FeedDetailView(post: post) {
                incrementCommentCount(for: post.id)
            }
        }
    }

    private func open(_ target: SupportNotificationTarget) {
        switch target {
        case .course(let courseID):
            selectedCourse = MockData.course(for: courseID)
        case .trip(let tripID):
            selectedTrip = tripContext.trips.first { $0.id == tripID } ?? MockData.trip(for: tripID)
        case .post(let postID):
            selectedPost = MockData.feedPost(for: postID, in: feedPosts)
        }
    }

    private func incrementCommentCount(for postID: String) {
        guard let index = feedPosts.firstIndex(where: { $0.id == postID }) else { return }
        feedPosts[index].commentCount += 1
    }
}

private struct CreateRecruitmentView: View {
    let courseID: String
    let onCreated: (TripRecruitment, ChatThread) -> Void
    let onSendChatMessage: (ChatThread, ChatMessage) -> Void
    let onApproveApplicant: (TripRecruitment, Participant) -> Void
    let onRejectApplicant: (TripRecruitment, Participant) -> Void
    let onSetRecruitmentClosed: (TripRecruitment, Bool) -> Void
    @State private var createdTrip: TripRecruitment?
    @State private var createdThread: ChatThread?
    @State private var selectedThread: ChatThread?
    @State private var selectedHostContext: HostManageContext?
    @State private var scheduleDate = ""
    @State private var scheduleTime = ""
    @State private var meetingPoint = ""
    @State private var capacityText = "5"
    @State private var recruitmentNote = ""

    private var course: TravelCourse {
        MockData.course(for: courseID) ?? MockData.courses[0]
    }

    private var defaultSchedule: String {
        MockData.trips.first { $0.courseID == course.id }?.schedule ?? "2026.06.06 (토) 08:00"
    }

    private var defaultScheduleDate: String {
        let parts = defaultSchedule.split(separator: " ").map(String.init)
        guard parts.count >= 2 else { return defaultSchedule }
        return parts.prefix(2).joined(separator: " ")
    }

    private var defaultScheduleTime: String {
        let parts = defaultSchedule.split(separator: " ").map(String.init)
        guard parts.count > 2 else { return "08:00 - 18:00" }
        return parts.dropFirst(2).joined(separator: " ")
    }

    private var defaultMeetingPoint: String {
        MockData.trips.first { $0.courseID == course.id }?.meetupPoint ?? "\(course.region) 대표 터미널"
    }

    private var capacity: Int {
        let parsed = Int(capacityText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 5
        return min(max(parsed, 3), 12)
    }

    var body: some View {
        SupportList(title: "모집 만들기") {
            SupportCourseSummary(course: course)

            SupportCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("모집 정보")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.ink)
                    SupportEditableField(
                        title: "일정",
                        text: $scheduleDate,
                        identifier: "createRecruitment.date"
                    )
                    SupportEditableField(
                        title: "시간",
                        text: $scheduleTime,
                        identifier: "createRecruitment.time"
                    )
                    SupportEditableField(
                        title: "모이는 곳",
                        text: $meetingPoint,
                        identifier: "createRecruitment.place"
                    )
                    SupportEditableField(
                        title: "모집 정원",
                        text: Binding(
                            get: { capacityText },
                            set: { capacityText = String($0.filter(\.isNumber).prefix(2)) }
                        ),
                        helperText: "최소 3명, 최대 12명",
                        keyboardType: .numberPad,
                        identifier: "createRecruitment.capacity"
                    )
                    SupportField(title: "참가비", value: course.duration == "2박 3일" ? "1인 189,000원" : "1인 42,000원")
                }
            }

            SupportCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("소개글")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.ink)
                    TextField("함께 갈 사람들에게 보여줄 안내", text: $recruitmentNote, axis: .vertical)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MoyeoTheme.ink)
                        .lineLimit(3...5)
                        .padding(14)
                        .background(MoyeoTheme.subtleBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onChange(of: recruitmentNote) { _, value in
                            if value.count > 160 {
                                recruitmentNote = String(value.prefix(160))
                            }
                        }
                        .accessibilityIdentifier("createRecruitment.note")
                    HStack {
                        Text("\(recruitmentNote.count)/160자")
                        Spacer()
                        Text("\(safeScheduleDate) · \(safeMeetingPoint) · 1/\(capacity)명 모집")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.muted)
                }
            }

            if let createdTrip {
                SupportCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("모집이 준비됐어요", systemImage: "checkmark.seal.fill")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(MoyeoTheme.forest)
                        Text("\(createdTrip.title) 채팅방에서 참여자와 준비물을 나눌 수 있어요.")
                            .font(.subheadline)
                            .foregroundStyle(MoyeoTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            if let createdThread {
                                selectedHostContext = HostManageContext(trip: createdTrip, thread: createdThread)
                            }
                        } label: {
                            Label("모집 관리", systemImage: "person.2.badge.gearshape.fill")
                                .font(.subheadline.weight(.heavy))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MoyeoTheme.forest)
                        .accessibilityIdentifier("createRecruitment.openManage")

                        Button {
                            selectedThread = createdThread
                        } label: {
                            Label("채팅방 미리보기", systemImage: "bubble.left.and.bubble.right.fill")
                                .font(.subheadline.weight(.heavy))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MoyeoTheme.forest)
                    }
                }
            }

            if createdTrip == nil {
                Button {
                    createRecruitment()
                } label: {
                    Label("모집 만들기", systemImage: "person.3.fill")
                        .font(.subheadline.weight(.heavy))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(MoyeoTheme.forest)
            }
        }
        .navigationDestination(item: $selectedThread) { thread in
            ChatRoomView(thread: thread) { message in
                onSendChatMessage(thread, message)
            }
        }
        .navigationDestination(item: $selectedHostContext) { context in
            HostManageView(
                trip: context.trip,
                thread: context.thread,
                onSendChatMessage: onSendChatMessage,
                onApproveApplicant: onApproveApplicant,
                onRejectApplicant: onRejectApplicant,
                onSetRecruitmentClosed: onSetRecruitmentClosed
            )
        }
        .onAppear(perform: initializeFieldsIfNeeded)
        .accessibilityIdentifier("screen.createRecruitment.\(courseID)")
    }

    private func createRecruitment() {
        guard createdTrip == nil else { return }

        let tripID = "session-trip-\(course.id)-\(UUID().uuidString)"
        let threadID = "session-chat-\(tripID)"
        let participants = Array(MockData.participants.prefix(1))
        let trip = TripRecruitment(
            id: tripID,
            courseID: course.id,
            title: course.title,
            region: course.region,
            coverMascot: course.mascot,
            hostName: "다정한 곰 1001",
            hostAvatar: "🐻",
            schedule: "\(safeScheduleDate) \(safeScheduleTime)",
            meetupPoint: safeMeetingPoint,
            price: course.duration == "2박 3일" ? "1인 189,000원" : "1인 42,000원",
            capacity: capacity,
            joined: 1,
            minimumParticipants: 3,
            status: .open,
            summary: safeRecruitmentNote,
            vibe: "새로 만든 모임이라 동행자와 속도를 맞춰 천천히 준비해요.",
            tags: course.tags,
            route: course.stops,
            participants: participants
        )
        let thread = ChatThread(
            id: threadID,
            tripTitle: trip.title,
            region: trip.region,
            mascot: trip.coverMascot,
            lastMessage: "모집이 막 만들어졌어요. 함께 갈 사람을 기다려요.",
            updatedAt: "방금",
            unreadCount: 0,
            statusSummary: "\(trip.joined)/\(trip.capacity)명 · 모집중",
            statusDetail: "최소 \(trip.minimumParticipants)명까지 \(trip.needsMoreParticipants)명 남았어요.",
            members: participants,
            messages: [
                ChatMessage(
                    id: "\(threadID)-welcome",
                    senderName: "모여트립",
                    avatar: "🐻",
                    body: "모집이 막 만들어졌어요. 함께 갈 사람을 기다려요.",
                    time: "방금",
                    isMine: false
                ),
                ChatMessage(
                    id: "\(threadID)-note",
                    senderName: "다정한 곰 1001",
                    avatar: "🐻",
                    body: safeRecruitmentNote,
                    time: "방금",
                    isMine: true
                )
            ],
            isReadOnly: false
        )

        createdTrip = trip
        createdThread = thread
        onCreated(trip, thread)
    }

    private var safeScheduleDate: String {
        scheduleDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? defaultScheduleDate
            : scheduleDate.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var safeScheduleTime: String {
        scheduleTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? defaultScheduleTime
            : scheduleTime.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var safeMeetingPoint: String {
        meetingPoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? defaultMeetingPoint
            : meetingPoint.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var safeRecruitmentNote: String {
        let trimmed = recruitmentNote.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? course.subtitle : String(trimmed.prefix(160))
    }

    private func initializeFieldsIfNeeded() {
        guard scheduleDate.isEmpty, scheduleTime.isEmpty, meetingPoint.isEmpty, recruitmentNote.isEmpty else { return }
        scheduleDate = defaultScheduleDate
        scheduleTime = defaultScheduleTime
        meetingPoint = defaultMeetingPoint
        capacityText = "5"
        recruitmentNote = course.subtitle
    }
}

private struct SupportNotification: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let time: String
    let icon: String
    let target: SupportNotificationTarget
}

private enum SupportNotificationTarget {
    case course(String)
    case trip(String)
    case post(String)
}
