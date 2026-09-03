//
//  ContentView.swift
//  MoyeoTrip
//
//  Created by 김한빈 on 5/29/26.
//

// swiftlint:disable file_length
import Foundation
import SwiftUI

enum MoyeoTab: CaseIterable, Hashable {
    case home
    case explore
    case meetings
    case feed
    case my

    var title: String {
        switch self {
        case .home:
            return "홈"
        case .explore:
            return "탐색"
        case .meetings:
            return "모임"
        case .feed:
            return "피드"
        case .my:
            return "마이"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "house.fill"
        case .explore:
            return "magnifyingglass"
        case .meetings:
            return "person.3.fill"
        case .feed:
            return "doc.text.image.fill"
        case .my:
            return "person.fill"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .home:
            return "tab.home"
        case .explore:
            return "tab.explore"
        case .meetings:
            return "tab.meetings"
        case .feed:
            return "tab.feed"
        case .my:
            return "tab.my"
        }
    }

    static func uiTestInitialTab(from arguments: [String]) -> MoyeoTab? {
        guard let value = arguments
            .first(where: { $0.hasPrefix("UITEST_TAB=") })?
            .replacingOccurrences(of: "UITEST_TAB=", with: "")
        else {
            return nil
        }

        switch value {
        case "home":
            return .home
        case "explore":
            return .explore
        case "meetings":
            return .meetings
        case "feed":
            return .feed
        case "my":
            return .my
        default:
            return nil
        }
    }
}

enum MyRoute: Hashable {
    /// changeLog18 — 25 프로필 카드. 유저를 눌러 자세히 보는 모든 진입점이 이 화면으로 온다.
    /// `startsFlipped` 는 25-1 뒷면 캡처 전용이다 (실사용 기본값은 앞면).
    case profile(ProfileCardSubject, startsFlipped: Bool)
    case profileEdit
    case profileTasteEdit
    case myFeed
    case friendDex
    case settings
    case customerCenter
    case friends
}

enum MeetingsRoute: Hashable {
    /// 21 특수 메시지 카드 6종. 값은 카드를 뽑아 올 방 — 없으면 그릴 실제 메시지가 없다.
    case specialMessages(Int64?)
    /// 19-2 참가 신청 취소 확인. 값은 대상 방 — 없으면 내 신청 목록의 첫 건을 쓴다.
    case applyCancel(Int64?)
}

// swiftlint:disable:next type_body_length
struct ContentView: View {
    @StateObject private var connectivity: MoyeoConnectivity
    /// 탭 데이터는 탭 본문보다 오래 살아야 한다 — 여기 두면 탭을 오가도 다시 부르지 않는다
    /// (TAB-STATE-CANON R1). 로그아웃·계정 전환 때 비운다 (R4).
    @StateObject private var tabData: MoyeoTabDataStore

    /// 하단 `모임` 탭의 알림 점 — 참여 중인 방에 **읽지 않은 메시지가 있을 때만** 켠다.
    /// 근거는 `GET /chat-rooms/my` 의 `unreadMessageCount` 하나뿐이다.
    /// 목록을 아직 못 받았으면(nil) 켜지 않는다 — 모르는 상태를 "알림 있음" 으로 보이면 안 된다.
    private var hasMeetingAlert: Bool {
        guard let rooms = tabData.meetingRooms else { return false }
        return rooms.contains { ($0.unreadMessageCount ?? 0) > 0 }
    }
    /// 29 설정 › 화면 › 테마의 사용자 설정. 캡처의 강제 테마가 항상 이긴다.
    @ObservedObject private var themeStore = MoyeoThemeStore.shared
    @State private var selectedTab: MoyeoTab
    @State private var isShowingSplash: Bool
    @State private var homePath = NavigationPath()
    @State private var explorePath = NavigationPath()
    @State private var meetingsPath = NavigationPath()
    @State private var feedPath = NavigationPath()
    @State private var myPath = NavigationPath()
    @State private var isBottomNavigationSuppressed = false
    /// 세션 안에서 만들어진 값만 담는다. 서버에서 오는 목록은 각 화면이 직접 받는다.
    @State private var feedPosts: [FeedPost] = []
    @State private var chatThreads: [ChatThread] = []
    @State private var trips: [TripRecruitment] = []
    @State private var profile = ProfileSummary.empty
    @State private var appliedTripIDs: Set<String> = []
    @State private var isAuthenticated: Bool
    private let currentUserService: AuthCurrentUserService
    private let initialFeedPostID: String?
    private let initialFeedStartsWriting: Bool
    private let initialFeedWriteStep: Int
    /// 24-1~24-5 캡처가 지정한 기록 대상 방
    private let initialFeedWriteRoomID: Int64?
    private let forcedColorScheme: ColorScheme?
    private let keepsSplashVisibleForCapture: Bool
    private let splashHoldNanoseconds: UInt64 = 1_150_000_000

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let launchState = UITestInitialState(arguments: arguments)
        let keepsSplashVisibleForCapture = arguments.contains("UITEST_MODE")
            && arguments.contains("UITEST_SCREEN=splash")
        // 라이브 캡처(UITEST_LIVE_DATA)에서만 세션을 심는다. 목 캡처는 건드리지 않는다.
        UITestRuntime.prepareLiveSessionIfNeeded()
        let currentUserService = AuthCurrentUserService()
        self.currentUserService = currentUserService
        _connectivity = StateObject(wrappedValue: MoyeoConnectivity(arguments: arguments))
        // 캡처 진입(지도 탐색·모임 세그먼트)은 보관소 초기값으로 넣는다 —
        // 화면이 만들어질 때마다 다시 적용되면 사용자가 고른 값을 덮어쓴다.
        let tabData = MoyeoTabDataStore(exploreShowsMap: launchState.exploreStartsInMap)
        tabData.meetingSegment = launchState.meetingsInitialSegment
        _tabData = StateObject(wrappedValue: tabData)

        _selectedTab = State(initialValue: launchState.selectedTab)
        _isShowingSplash = State(
            initialValue: !arguments.contains("UITEST_MODE") || keepsSplashVisibleForCapture
        )
        _profile = State(
            initialValue: currentUserService.cachedProfile().map(ProfileSummary.empty.applying) ?? .empty
        )
        _isAuthenticated = State(
            initialValue: arguments.contains("UITEST_MODE") && !arguments.contains("UITEST_REQUIRE_AUTH")
        )
        _homePath = State(initialValue: launchState.homePath)
        _explorePath = State(initialValue: launchState.explorePath)
        _meetingsPath = State(initialValue: launchState.meetingsPath)
        _myPath = State(initialValue: launchState.myPath)
        initialFeedPostID = launchState.feedPostID
        initialFeedStartsWriting = launchState.feedStartsWriting
        initialFeedWriteStep = launchState.feedWriteInitialStep
        initialFeedWriteRoomID = launchState.feedWriteRoomID
        // 번호별 비교 캡처는 다크/라이트 두 테마를 모두 찍는다 — 양쪽 모두 명시 인자를 받는다
        if arguments.contains("UITEST_FORCE_DARK") {
            forcedColorScheme = .dark
        } else if arguments.contains("UITEST_FORCE_LIGHT") {
            forcedColorScheme = .light
        } else {
            forcedColorScheme = nil
        }
        self.keepsSplashVisibleForCapture = keepsSplashVisibleForCapture
    }

    /// 강제 테마 인자가 있으면 그것을, 없으면 설정 › 화면 › 테마를 따른다
    /// (`system` = nil → OS 설정을 그대로 따라가고 런타임 변경에도 즉시 반응한다).
    private var effectiveColorScheme: ColorScheme? {
        forcedColorScheme ?? themeStore.mode.colorScheme
    }

    var body: some View {
        ZStack {
            connectionAwareContent
                .opacity(isShowingSplash ? 0 : 1)
                .scaleEffect(isShowingSplash ? 0.985 : 1)
                .offset(y: isShowingSplash ? 12 : 0)
                .allowsHitTesting(!isShowingSplash)
                .accessibilityHidden(isShowingSplash)
                .animation(UITestRuntime.reducesVisualAnimations ? nil : .easeOut(duration: 0.42), value: isShowingSplash)

            if isShowingSplash {
                SplashView()
                    .transition(.opacity.combined(with: .scale(scale: 1.012)))
                    .zIndex(1)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MoyeoTheme.background.ignoresSafeArea())
        .preferredColorScheme(effectiveColorScheme)
        .onAppear {
            // 긴 화면의 스크롤 페이지 캡처 (UITEST_SCROLL_PAGE=N)
            UITestScrollDriver.applyIfRequested()
        }
        .task {
            guard isShowingSplash, !keepsSplashVisibleForCapture else { return }

            try? await Task.sleep(nanoseconds: splashHoldNanoseconds)
            withAnimation(UITestRuntime.reducesVisualAnimations ? nil : .easeInOut(duration: 0.42)) {
                isShowingSplash = false
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab != .home {
                isBottomNavigationSuppressed = false
            }
        }
        .task(id: isAuthenticated) {
            guard isAuthenticated, !ProcessInfo.processInfo.arguments.contains("UITEST_MODE") else { return }
            await MoyeoPushNotificationManager.shared.requestAuthorizationIfNeeded()
            if let cachedProfile = currentUserService.cachedProfile() {
                profile = profile.applying(cachedProfile)
            }
            if let authenticatedProfile = try? await currentUserService.refreshProfile() {
                profile = profile.applying(authenticatedProfile)
            }
        }
        .task(id: connectivity.recoveryToken) {
            guard connectivity.recoveryToken != nil, connectivity.status == .online, isAuthenticated else { return }
            if let authenticatedProfile = try? await currentUserService.refreshProfile() {
                profile = profile.applying(authenticatedProfile)
            }
        }
        .onChange(of: connectivity.status) { _, status in
            if status == .online, isAuthenticated {
                connectivity.markCacheAvailable()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .moyeoPushNotificationOpened)) { notification in
            guard isAuthenticated, let destination = notification.object as? MoyeoPushDestination else { return }
            openPushDestination(destination)
        }
        .onReceive(NotificationCenter.default.publisher(for: .moyeoSignupGateRequired)) { _ in
            returnToSignupFlow()
        }
    }

    /// 서버가 409 `40902`·`40918` 로 "가입이 아직 안 끝났다"고 알려온 경우 (정본 R1).
    ///
    /// 어느 단계로 갈지는 여기서 정하지 않는다 — 가입 흐름이 다시 뜨면서
    /// `restoreSession()` 이 서버 `signupState` 를 받아 그대로 따라간다(R3).
    /// 오류 코드보다 `signupState` 가 먼저다.
    private func returnToSignupFlow() {
        guard isAuthenticated else { return }
        // 가입 화면 뒤에 이전 세션의 화면 스택이 남아 있으면, 가입을 마친 뒤 남의 화면으로 돌아간다.
        clearSessionScopedState()
        isAuthenticated = false
    }

    /// 로그아웃·계정 전환·가입 게이트 복귀에서 이전 사용자의 흔적을 모두 지운다 (TAB-STATE-CANON R4).
    /// 보관소가 살아 있으면 다음 로그인 화면에 남의 목록·프로필이 그대로 남는다.
    private func clearSessionScopedState() {
        homePath = NavigationPath()
        explorePath = NavigationPath()
        meetingsPath = NavigationPath()
        feedPath = NavigationPath()
        myPath = NavigationPath()
        tabData.reset()
        feedPosts = []
        chatThreads = []
        trips = []
        appliedTripIDs = []
        profile = .empty
    }

    @ViewBuilder
    private var connectionAwareContent: some View {
        if connectivity.isOffline, !connectivity.hasCachedContent {
            OfflineEmptyView(onRetry: connectivity.retry)
        } else {
            VStack(spacing: 0) {
                if connectivity.isOffline {
                    MoyeoOfflineBanner(cachedContentAvailable: true)
                }
                rootContent
            }
            .environment(\.moyeoIsOffline, connectivity.isOffline)
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if isAuthenticated {
            mainTabs
                .transition(.opacity)
        } else {
            AuthFlowView(allowsDismissal: false) {
                withAnimation(UITestRuntime.reducesVisualAnimations ? nil : .easeInOut(duration: 0.28)) {
                    isAuthenticated = true
                }
            }
            .transition(.opacity)
            .accessibilityIdentifier("screen.authGate")
        }
    }

    private var mainTabs: some View {
        selectedRoot
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if shouldShowBottomNav {
                    MoyeoBottomNav(selectedTab: $selectedTab, hasMeetingAlert: hasMeetingAlert)
                }
            }
            .background(MoyeoTheme.background.ignoresSafeArea())
    }

    private var shouldShowBottomNav: Bool {
        switch selectedTab {
        case .home:
            return homePath.isEmpty && !isBottomNavigationSuppressed
        case .explore:
            return explorePath.isEmpty && !isBottomNavigationSuppressed
        case .meetings:
            // 19-2 신청 취소 확인 시트가 열려 있으면 탭바가 시트 버튼을 가린다.
            return meetingsPath.isEmpty && !isBottomNavigationSuppressed
        case .feed:
            return !initialFeedStartsWriting && feedPath.isEmpty && !isBottomNavigationSuppressed
        case .my:
            return myPath.isEmpty
        }
    }

    @ViewBuilder
    private var selectedRoot: some View {
        switch selectedTab {
        case .home:
            NavigationStack(path: $homePath) {
                HomeView(
                    tabData: tabData,
                    isBottomNavigationSuppressed: $isBottomNavigationSuppressed,
                    feedPosts: $feedPosts,
                    tripContext: tripContext,
                    onOpenCourseList: {
                        selectedTab = .explore
                    }
                )
            }
        case .explore:
            NavigationStack(path: $explorePath) {
                ExploreView(
                    tabData: tabData,
                    isBottomNavigationSuppressed: $isBottomNavigationSuppressed,
                    tripContext: tripContext
                )
            }
        case .meetings:
            NavigationStack(path: $meetingsPath) {
                MeetingsView(
                    tabData: tabData,
                    chatThreads: $chatThreads,
                    isBottomNavigationSuppressed: $isBottomNavigationSuppressed,
                    tripContext: tripContext
                )
            }
        case .feed:
            if initialFeedStartsWriting {
                NavigationStack {
                    FeedWriteView(
                        initialStep: initialFeedWriteStep,
                        requestedRoomID: initialFeedWriteRoomID
                    ) { post in
                        registerFeedPost(post)
                    }
                }
            } else {
                NavigationStack(path: $feedPath) {
                    FeedView(
                        tabData: tabData,
                        feedPosts: $feedPosts,
                        isBottomNavigationSuppressed: $isBottomNavigationSuppressed,
                        onPublish: registerFeedPost,
                        initialPostID: initialFeedPostID,
                        feedWriteInitialStep: initialFeedWriteStep,
                        feedWriteRoomID: initialFeedWriteRoomID
                    )
                }
            }
        case .my:
            NavigationStack(path: $myPath) {
                MyView(
                    tabData: tabData,
                    path: $myPath,
                    tripContext: tripContext,
                    profile: profile,
                    feedPosts: feedPosts,
                    onAuthenticationRequired: requireAuthentication
                )
            }
        }
    }

    private func requireAuthentication() {
        selectedTab = .home
        clearSessionScopedState()
        isBottomNavigationSuppressed = false
        withAnimation(UITestRuntime.reducesVisualAnimations ? nil : .easeInOut(duration: 0.28)) {
            isAuthenticated = false
        }
    }

    private func openPushDestination(_ destination: MoyeoPushDestination) {
        isBottomNavigationSuppressed = false
        switch destination {
        case .home:
            selectedTab = .home
            homePath = NavigationPath()
        case .notifications:
            selectedTab = .home
            homePath = NavigationPath()
            homePath.append(SupportRoute.notifications)
        case .explore:
            selectedTab = .explore
            explorePath = NavigationPath()
        case .meetings:
            selectedTab = .meetings
            meetingsPath = NavigationPath()
        case .feed:
            selectedTab = .feed
            feedPath = NavigationPath()
        case .my:
            selectedTab = .my
            myPath = NavigationPath()
        }
    }

    private var tripContext: TripInteractionContext {
        TripInteractionContext(
            trips: trips,
            chatThreads: chatThreads,
            appliedTripIDs: appliedTripIDs,
            chatThreadProvider: chatThread(for:),
            onApplyTrip: registerTripApplication,
            onCreateRecruitment: registerCreatedRecruitment,
            onSendChatMessage: updateChatThreadPreview,
            onApproveHostApplicant: approveHostApplicant,
            onRejectHostApplicant: rejectHostApplicant,
            onSetRecruitmentClosed: setRecruitmentClosed,
            onUpdateRoute: updateTripRoute,
            onCreateNotice: createNotice,
            onCancelApplication: cancelTripApplication
        )
    }

    private func registerCreatedRecruitment(trip: TripRecruitment, thread: ChatThread) {
        let isNewTrip = !trips.contains(where: { $0.id == trip.id })

        if isNewTrip {
            trips.insert(trip, at: 0)
            profile = profile.incrementingHostedTrips()
        } else if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
        }

        upsertChatThread(thread.withTripStatus(trip), prioritize: true)
    }

    private func registerFeedPost(_ post: FeedPost) {
        guard feedPosts.contains(where: { $0.id == post.id }) else { return }
        profile = profile.incrementingFeedCount()
    }

    private func registerTripApplication(_ trip: TripRecruitment) {
        let inserted = appliedTripIDs.insert(trip.id).inserted
        let updatedTrip = inserted ? trip.withAppliedCurrentUser(profile) : (trips.first { $0.id == trip.id } ?? trip)
        upsertTrip(updatedTrip, prioritize: inserted)

        if inserted {
            profile = profile.incrementingJoinedTrips()
        }

        let thread = chatThread(for: updatedTrip) ?? updatedTrip.createdChatThread(profile: profile)
        upsertChatThread(thread.withTripStatus(updatedTrip), prioritize: true)
    }

    private func approveHostApplicant(_ trip: TripRecruitment, participant: Participant) {
        let baseTrip = trips.first { $0.id == trip.id } ?? trip
        let updatedTrip = baseTrip.withHostApprovedParticipant(participant)
        let becameConfirmed = baseTrip.joined < baseTrip.minimumParticipants
            && updatedTrip.joined >= updatedTrip.minimumParticipants
        upsertTrip(updatedTrip, prioritize: true)

        let baseThread = chatThread(for: updatedTrip) ?? updatedTrip.createdChatThread(profile: profile)
        let message = "\(participant.name)님이 참여 확정됐어요."
        upsertChatThread(
            baseThread.withTripStatus(updatedTrip).withSystemNotice(message, avatar: participant.avatar),
            prioritize: true
        )

        if becameConfirmed {
            selectedTab = .home
            homePath.append(SupportRoute.tripConfirmed(updatedTrip.id))
        }
    }

    private func rejectHostApplicant(_ trip: TripRecruitment, participant: Participant) {
        let baseTrip = trips.first { $0.id == trip.id } ?? trip
        let baseThread = chatThread(for: baseTrip) ?? baseTrip.createdChatThread(profile: profile)
        let message = "\(participant.name)님의 신청을 거절했어요."
        upsertChatThread(
            baseThread.withTripStatus(baseTrip).withSystemNotice(message, avatar: participant.avatar),
            prioritize: true
        )
    }

    private func setRecruitmentClosed(_ trip: TripRecruitment, isClosed: Bool) {
        let baseTrip = trips.first { $0.id == trip.id } ?? trip
        let updatedTrip = baseTrip.withRecruitmentClosed(isClosed)
        upsertTrip(updatedTrip, prioritize: true)

        let baseThread = chatThread(for: updatedTrip) ?? updatedTrip.createdChatThread(profile: profile)
        let message = isClosed ? "호스트가 모집을 취소했어요." : "호스트가 모집을 다시 열었어요."
        upsertChatThread(baseThread.withTripStatus(updatedTrip).withSystemNotice(message), prioritize: true)
    }

    private func updateTripRoute(_ trip: TripRecruitment, stops: [ItineraryStop]) {
        guard trip.courseSource == .custom, trip.routeEditState == .editable else { return }
        guard let index = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        trips[index].itinerary = stops
        let summary = "여행 경로가 변경됐어요: " + stops.map(\.name).joined(separator: " → ")
        if let thread = chatThread(for: trips[index]) {
            var updated = thread.withSystemNotice(summary)
            if let lastIndex = updated.messages.indices.last {
                updated.messages[lastIndex].kind = .routeChanged
            }
            updated.routeSummary = stops
            upsertChatThread(updated, prioritize: true)
        }
    }

    private func createNotice(_ thread: ChatThread, notice: TripNotice) {
        var updated = thread
        updated.pinnedNotices.insert(notice, at: 0)
        updated.pinnedNotices = Array(updated.pinnedNotices.prefix(3))
        upsertChatThread(updated.withSystemNotice("공지: \(notice.body)"), prioritize: true)
    }

    private func cancelTripApplication(_ trip: TripRecruitment) {
        appliedTripIDs.remove(trip.id)
    }

    private func updateChatThreadPreview(thread: ChatThread, message: ChatMessage) {
        if let index = chatThreads.firstIndex(where: { $0.id == thread.id || $0.tripTitle == thread.tripTitle }) {
            chatThreads[index] = chatThreads[index].withAppendedMessage(message)
        } else {
            chatThreads.insert(thread.withAppendedMessage(message), at: 0)
        }
    }

    private func chatThread(for trip: TripRecruitment) -> ChatThread? {
        chatThreads.first { $0.id == trip.sessionChatID }
            ?? chatThreads.first { $0.tripTitle == trip.title && !$0.isReadOnly }
    }

    private func upsertTrip(_ trip: TripRecruitment, prioritize: Bool) {
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
            if prioritize {
                let updated = trips.remove(at: index)
                trips.insert(updated, at: 0)
            }
        } else {
            trips.insert(trip, at: 0)
        }
    }

    private func upsertChatThread(_ thread: ChatThread, prioritize: Bool) {
        if let index = chatThreads.firstIndex(where: { $0.id == thread.id }) {
            chatThreads[index] = thread
            if prioritize {
                let updated = chatThreads.remove(at: index)
                chatThreads.insert(updated, at: 0)
            }
        } else {
            chatThreads.insert(thread, at: 0)
        }
    }
}

private struct MoyeoBottomNav: View {
    @Binding var selectedTab: MoyeoTab
    /// 모임 탭 알림 점. **읽지 않은 메시지가 있을 때만** 켠다.
    let hasMeetingAlert: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MoyeoTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    MoyeoBottomNavItem(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        showsAlert: tab == .meetings && hasMeetingAlert
                    )
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(tab.accessibilityIdentifier)
                .accessibilityLabel(tab.title)
            }
        }
        .frame(height: 68, alignment: .top)
        .padding(.horizontal, 8)
        .padding(.top, 5)
        .background(MoyeoTheme.card)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MoyeoTheme.softLine)
                .frame(height: 1)
        }
        .background(MoyeoTheme.card.ignoresSafeArea(edges: .bottom))
    }
}

private struct MoyeoBottomNavItem: View {
    let tab: MoyeoTab
    let isSelected: Bool
    let showsAlert: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 28, height: 23)

                // 예전에는 `tab == .meetings` 만 보고 **조건 없이 항상** 점을 그렸다.
                // 알림이 하나도 없어도 초록 점이 계속 떠 있어 사용자가 지적했다.
                if showsAlert {
                    Circle()
                        .fill(MoyeoTheme.forest)
                        .frame(width: 6, height: 6)
                        .offset(x: 2, y: 1)
                }
            }

            Text(tab.title)
                .font(.caption2.weight(isSelected ? .bold : .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(isSelected ? MoyeoTheme.forest : MoyeoTheme.muted)
        .frame(maxWidth: .infinity)
        .frame(height: 47)
        .contentShape(Rectangle())
    }
}
