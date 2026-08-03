//
//  ContentView.swift
//  MoyeoTrip
//
//  Created by 김한빈 on 5/29/26.
//

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
    case myFeed
    case friendDex
    case settings
    case customerCenter
}

enum MeetingsRoute: Hashable {
    case specialMessages
}

struct ContentView: View {
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
    private let exploreStartsInMap: Bool
    private let forcedColorScheme: ColorScheme?
    private let showsTestAuthEntry: Bool
    private let splashHoldNanoseconds: UInt64 = 1_150_000_000

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let launchState = UITestInitialState(arguments: arguments)
        let currentUserService = AuthCurrentUserService()
        self.currentUserService = currentUserService

        _selectedTab = State(initialValue: launchState.selectedTab)
        _isShowingSplash = State(initialValue: !arguments.contains("UITEST_MODE"))
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
        exploreStartsInMap = launchState.exploreStartsInMap
        forcedColorScheme = arguments.contains("UITEST_FORCE_DARK") ? .dark : nil
        showsTestAuthEntry = arguments.contains("UITEST_MODE")
    }

    var body: some View {
        ZStack {
            rootContent
                .opacity(isShowingSplash ? 0 : 1)
                .scaleEffect(isShowingSplash ? 0.985 : 1)
                .offset(y: isShowingSplash ? 12 : 0)
                .allowsHitTesting(!isShowingSplash)
                .accessibilityHidden(isShowingSplash)
                .animation(.easeOut(duration: 0.42), value: isShowingSplash)

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
        .task {
            guard isShowingSplash else { return }

            try? await Task.sleep(nanoseconds: splashHoldNanoseconds)
            withAnimation(.easeInOut(duration: 0.42)) {
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
            if let cachedProfile = currentUserService.cachedProfile() {
                profile = profile.applying(cachedProfile)
            }
            if let authenticatedProfile = try? await currentUserService.refreshProfile() {
                profile = profile.applying(authenticatedProfile)
            }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if isAuthenticated {
            mainTabs
                .transition(.opacity)
        } else {
            AuthFlowView(allowsDismissal: false) {
                withAnimation(.easeInOut(duration: 0.28)) {
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
            return feedPath.isEmpty && !isBottomNavigationSuppressed
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
                    showsAuthFlowEntry: showsTestAuthEntry,
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
                    tripContext: tripContext
                )
            }
        case .feed:
            NavigationStack(path: $feedPath) {
                FeedView(
                    feedPosts: $feedPosts,
                    isBottomNavigationSuppressed: $isBottomNavigationSuppressed,
                    onPublish: registerFeedPost,
                    initialPostID: initialFeedPostID,
                    startsWritingPost: initialFeedStartsWriting
                )
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
        withAnimation(.easeInOut(duration: 0.28)) {
            isAuthenticated = false
        }
    }

    private var tripContext: TripInteractionContext {
        TripInteractionContext(
            trips: trips,
            appliedTripIDs: appliedTripIDs,
            chatThreadProvider: chatThread(for:),
            onApplyTrip: registerTripApplication,
            onCreateRecruitment: registerCreatedRecruitment,
            onSendChatMessage: updateChatThreadPreview,
            onApproveHostApplicant: approveHostApplicant,
            onRejectHostApplicant: rejectHostApplicant,
            onSetRecruitmentClosed: setRecruitmentClosed
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
        upsertTrip(updatedTrip, prioritize: true)

        let baseThread = chatThread(for: updatedTrip) ?? updatedTrip.createdChatThread(profile: profile)
        let message = "\(participant.name)님이 참여 확정됐어요."
        upsertChatThread(
            baseThread.withTripStatus(updatedTrip).withSystemNotice(message, avatar: participant.avatar),
            prioritize: true
        )
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
