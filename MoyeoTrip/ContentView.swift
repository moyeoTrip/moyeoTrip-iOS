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
    case profile
    case profileEdit
    case profileTasteEdit
    case myFeed
    case friendDex
    case settings
    case customerCenter
    case friends
}

enum MeetingsRoute: Hashable {
    case specialMessages
}

// swiftlint:disable:next type_body_length
struct ContentView: View {
    @StateObject private var connectivity: MoyeoConnectivity
    @State private var selectedTab: MoyeoTab
    @State private var isShowingSplash: Bool
    @State private var homePath = NavigationPath()
    @State private var explorePath = NavigationPath()
    @State private var meetingsPath = NavigationPath()
    @State private var feedPath = NavigationPath()
    @State private var myPath = NavigationPath()
    @State private var isBottomNavigationSuppressed = false
    @State private var feedPosts = MockData.feedPosts
    @State private var chatThreads = MockData.chatThreads
    @State private var trips = MockData.trips
    @State private var profile = MockData.profile
    @State private var appliedTripIDs: Set<String> = []
    @State private var isAuthenticated: Bool
    private let currentUserService: AuthCurrentUserService
    private let initialFeedPostID: String?
    private let initialFeedStartsWriting: Bool
    private let initialFeedWriteStep: Int
    private let exploreStartsInMap: Bool
    private let meetingsInitialSegment: MeetingSegment
    private let forcedColorScheme: ColorScheme?
    private let keepsSplashVisibleForCapture: Bool
    private let splashHoldNanoseconds: UInt64 = 1_150_000_000

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let launchState = UITestInitialState(arguments: arguments)
        let keepsSplashVisibleForCapture = arguments.contains("UITEST_MODE")
            && arguments.contains("UITEST_SCREEN=splash")
        UITestCaptureSeed.prepare(arguments: arguments)
        let currentUserService = AuthCurrentUserService()
        self.currentUserService = currentUserService
        _connectivity = StateObject(wrappedValue: MoyeoConnectivity(arguments: arguments))

        _selectedTab = State(initialValue: launchState.selectedTab)
        _isShowingSplash = State(
            initialValue: !arguments.contains("UITEST_MODE") || keepsSplashVisibleForCapture
        )
        _profile = State(
            initialValue: currentUserService.cachedProfile().map(MockData.profile.applying) ?? MockData.profile
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
        exploreStartsInMap = launchState.exploreStartsInMap
        meetingsInitialSegment = launchState.meetingsInitialSegment
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
        .preferredColorScheme(forcedColorScheme)
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
                    MoyeoBottomNav(selectedTab: $selectedTab)
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
            return meetingsPath.isEmpty
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
                    isBottomNavigationSuppressed: $isBottomNavigationSuppressed,
                    tripContext: tripContext,
                    startsInMap: exploreStartsInMap
                )
            }
        case .meetings:
            NavigationStack(path: $meetingsPath) {
                MeetingsView(
                    chatThreads: $chatThreads,
                    tripContext: tripContext,
                    initialSegment: meetingsInitialSegment
                )
            }
        case .feed:
            if initialFeedStartsWriting {
                NavigationStack {
                    FeedWriteView(initialStep: initialFeedWriteStep) { post in
                        registerFeedPost(post)
                    }
                }
            } else {
                NavigationStack(path: $feedPath) {
                    FeedView(
                        feedPosts: $feedPosts,
                        isBottomNavigationSuppressed: $isBottomNavigationSuppressed,
                        onPublish: registerFeedPost,
                        initialPostID: initialFeedPostID,
                        feedWriteInitialStep: initialFeedWriteStep
                    )
                }
            }
        case .my:
            NavigationStack(path: $myPath) {
                MyView(
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
        homePath = NavigationPath()
        explorePath = NavigationPath()
        meetingsPath = NavigationPath()
        feedPath = NavigationPath()
        myPath = NavigationPath()
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
        upsertChatThread(updated.withSystemNotice("공지: \(notice.title) · \(notice.body)"), prioritize: true)
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
            ?? MockData.chatThread(forTripID: trip.id)
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

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MoyeoTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    MoyeoBottomNavItem(tab: tab, isSelected: selectedTab == tab)
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

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 28, height: 23)

                if tab == .meetings {
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
