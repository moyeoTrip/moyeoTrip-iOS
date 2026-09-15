import SwiftUI

struct SearchView: View {
    var tripContext = TripInteractionContext()
    @Environment(\.dismiss) private var dismiss
    @State private var query: String
    @State private var submittedQuery: String
    /// 최근 검색어 — 서버 API가 없어 `UserDefaults` 에 영구 저장한다.
    /// **캡처도 같은 저장소를 쓴다** — 목록을 채우려면 실제로 검색을 실행해야 한다
    /// (캡처 파이프라인이 12 앞에서 `search:<검색어>` 를 몇 번 돌린다).
    /// 예전 주석이 "캡처 모드는 기획 목데이터 고정" 이라고 적혀 있었는데 코드와 반대였다.
    @StateObject private var recentSearchModel = RecentSearchModel.forCurrentRuntime()
    /// 실서버 검색 결과 — 로그인 세션이 있고 검색 API가 성공했을 때만 채워진다 (nil = 목데이터)
    @State private var serverResults: [ServerChatRoomSummary]?
    /// 12-1 코스 결과 — `GET /travel-courses/search?keyword=` (정본 R6)
    @State private var courseResults: [ServerTravelCourse]?
    @State private var resultTab: SearchResultTab = .course
    /// 찜 토글 결과. 서버 응답(`favorite`)이 기준이고, 토글한 방만 여기서 덮어쓴다.
    @State private var serverFavoriteOverrides: [Int64: Bool] = [:]
    /// 찜이 실패한 까닭 — 목록 위 한 줄 (TC DETAIL-004 · 탐색과 같은 모양).
    @State private var favoriteErrorMessage: String?
    @State private var selectedServerTrip: TripRecruitment?
    @State private var selectedCourse: TravelCourse?
    /// 12 인기 검색어. 0건·실패를 가르는 규칙은 `SearchPopularKeywordModel` 이 갖는다.
    @StateObject private var popularKeywordModel = SearchPopularKeywordModel()

    init(tripContext: TripInteractionContext = TripInteractionContext()) {
        self.tripContext = tripContext
        let arguments = ProcessInfo.processInfo.arguments
        // 12 검색은 입력 상태, 12-1 은 **결과가 보이는** 상태를 찍어야 한다.
        // 검색어를 안 채우면 결과 탭이 안 열려 빈 화면이 찍힌다.
        // 12-1 의 검색어는 캡처가 준다 (`UITEST_SCREEN=search-results:주왕산`) — 앱이 짓지 않는다.
        let resultsArgument = arguments.first { $0.hasPrefix("UITEST_SCREEN=search-results") }
        let resultsKeyword = resultsArgument
            .flatMap { $0.split(separator: ":", maxSplits: 1).dropFirst().first }
            .map(String.init) ?? ""
        // 12 입력 화면의 검색어도 **캡처가 준다** — 앱이 짓지 않는다(NO-MOCK R2).
        // 예전에는 `"경주 단풍"` 이 여기 박혀 있어서, 12-1 은 캡처가 넘기는데 12 만 앱이 지어내는
        // 앞뒤가 다른 상태였다. 인자 형식은 12-1 과 같다: `UITEST_SCREEN=search:경주 단풍`
        let searchArgument = arguments.first { $0.hasPrefix("UITEST_SCREEN=search:") }
        let searchKeyword = searchArgument
            .flatMap { $0.split(separator: ":", maxSplits: 1).dropFirst().first }
            .map(String.init) ?? ""
        let previewQuery: String = resultsArgument != nil ? resultsKeyword : searchKeyword
        _query = State(initialValue: previewQuery)
        // 입력칸만 채우면 12 입력 화면이 그대로 찍힌다 — 결과를 그리려면 **제출까지** 되어 있어야 한다.
        // 12(`search`)는 입력 상태가 맞으므로 12-1 에서만 제출한다.
        _submittedQuery = State(initialValue: resultsArgument == nil ? "" : resultsKeyword)
    }

    private var trimmedQuery: String {
        submittedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 칩은 한 줄에 4개까지 — 기획 캡처(5개 = 4 + 1)와 같은 줄바꿈을 유지한다
    private var recentSearchChunks: [[String]] {
        let searches = recentSearchModel.searches
        return stride(from: 0, to: searches.count, by: 4).map { start in
            Array(searches[start..<min(start + 4, searches.count)])
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchHeader

            ScrollView {
                LazyVStack(spacing: 16) {
                    if submittedQuery.isEmpty {
                        discoveryContent
                    } else if let serverResults {
                        // 12-1 — 코스(travel-courses/search)와 모집(chat-rooms/search)을 탭으로 나눈다
                        SearchResultTabBar(
                            selection: $resultTab,
                            courseCount: courseResults?.count ?? 0,
                            roomCount: serverResults.count
                        )
                        resultsForSelectedTab(serverResults)
                    } else {
                        // 세션이 없으면 검색 자체가 불가능하다 (§2 미로그인 · 검색)
                        MoyeoEmptyStateView(
                            message: MoyeoEmptyText.signedOutSearch,
                            systemImage: "person.crop.circle",
                            accessibilityIdentifier: "search.signedOut"
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 48)
            }
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: TravelCourse.self) { course in
            CourseDetailView(course: course, tripContext: tripContext)
        }
        .navigationDestination(item: $selectedCourse) { course in
            CourseDetailView(course: course, tripContext: tripContext)
        }
        .navigationDestination(item: $selectedServerTrip) { trip in
            TripDetailView(
                trip: trip,
                isApplied: tripContext.isApplied(trip),
                threadProvider: tripContext.chatThreadProvider,
                onApplied: tripContext.onApplyTrip,
                onSendChatMessage: tripContext.onSendChatMessage
            )
        }
        .task(id: submittedQuery) {
            await loadServerResults()
        }
        .task { await popularKeywordModel.load() }
        .accessibilityIdentifier("screen.search")
    }

    private func loadServerResults() async {
        guard MoyeoServerSync.isEnabled, !trimmedQuery.isEmpty else {
            serverResults = nil
            courseResults = nil
            return
        }
        // 두 목록은 서로 다른 API 다 — 하나가 실패해도 나머지는 실제 값으로 그린다
        async let rooms = try? await ChatRoomAPIClient.shared.search(keyword: trimmedQuery)
        async let courses = try? await TravelCourseAPIClient.shared.searchCourses(keyword: trimmedQuery)
        let (loadedRooms, loadedCourses) = await (rooms, courses)
        serverResults = loadedRooms
        courseResults = loadedCourses
    }

    /// 고른 탭의 결과. 결과가 0건이면 정본 문구를 그대로 쓴다 (R9 · NO-MOCK §2).
    @ViewBuilder
    private func resultsForSelectedTab(_ rooms: [ServerChatRoomSummary]) -> some View {
        switch resultTab {
        case .course:
            if let courseResults, !courseResults.isEmpty {
                ForEach(courseResults) { course in
                    SearchCourseResultRow(
                        course: course,
                        // 14 코스 상세로 간다 — 이미 있는 `TravelCourse` 목적지를 그대로 쓴다
                        onOpen: { selectedCourse = ServerCourseMapper.course(from: course) }
                    )
                    .moyeoCard()
                }
            } else {
                SearchNoResultsView(query: trimmedQuery, tab: .course) {
                    query = ""
                    submittedQuery = ""
                }
            }
        case .room:
            if rooms.isEmpty {
                SearchNoResultsView(query: trimmedQuery, tab: .room) {
                    query = ""
                    submittedQuery = ""
                }
            } else {
                serverSearchResults(rooms)
            }
        }
    }

    @ViewBuilder
    private func serverSearchResults(_ rooms: [ServerChatRoomSummary]) -> some View {
        if let favoriteErrorMessage {
            MoyeoInlineErrorText(message: favoriteErrorMessage, identifier: "search.favorite.error")
        }
        ForEach(rooms) { room in
            ServerRoomSearchResultRow(
                room: room,
                isFavorite: isServerFavorite(room),
                onOpen: {
                    selectedServerTrip = ServerTripMapper.trip(from: room)
                },
                onToggleFavorite: {
                    toggleServerFavorite(room)
                }
            )
            .moyeoCard()
        }
    }

    /// 서버가 준 `favorite` 이 기준이고, 이 세션에서 토글한 방만 응답값으로 덮어쓴다.
    private func isServerFavorite(_ room: ServerChatRoomSummary) -> Bool {
        serverFavoriteOverrides[room.roomId] ?? room.favorite
    }

    /// 찜 토글. 서버 응답이 와야 하트를 바꾼다 — 서버와 다른 상태를 확정하지 않는다.
    /// 예전에는 `try?` 로 삼켜 **하트도 그대로, 안내도 없어** 탭이 안 먹은 것처럼 보였다.
    /// 탐색(`ExploreView`)에서 고친 것과 같은 결함이 검색에 남아 있었다 (TC DETAIL-004).
    private func toggleServerFavorite(_ room: ServerChatRoomSummary) {
        guard MoyeoServerSync.isEnabled else { return }
        Task {
            do {
                serverFavoriteOverrides[room.roomId] =
                    try await ChatRoomAPIClient.shared.toggleFavorite(roomID: room.roomId)
                favoriteErrorMessage = nil
            } catch {
                favoriteErrorMessage = error.moyeoUserMessage(
                    fallback: "찜을 바꾸지 못했어요. 잠시 후 다시 시도해주세요."
                )
            }
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 10) {
            Button(action: dismiss.callAsFunction) {
                // ENV-009 — 화살표 그림 크기는 그대로 두고 누를 넓이만 44x44 로 넓힌다
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(MoyeoTheme.ink)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("뒤로")

            // 안내 문구는 네 표면이 같아야 한다 — 11 탐색의 진입 칸과도 같은 말이다
            // (예전에는 iOS 「지역, 테마, 코스 검색」 · 안드 「지역, 테마, 모임 검색」 로 셋이 달랐다).
            SearchField(
                text: $query,
                placeholder: "어디로 떠나고 싶나요?",
                // 돋보기도 키보드 검색과 **같은 결과**를 낸다 (TC SEARCH-019).
                onSubmit: submitSearch
            )
                .frame(height: 44)
                .onChange(of: query) { _, newValue in
                    if newValue.isEmpty {
                        submittedQuery = ""
                    }
                }
                .onSubmit(submitSearch)

            // 「취소」는 **검색을 그만두는** 버튼이다 — 입력만 비우고 같은 화면에 남으면
            // 취소한 것처럼 보이지 않는다 (IOS-F10·F23).
            Button("취소") {
                query = ""
                submittedQuery = ""
                dismiss()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(MoyeoTheme.muted)
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.horizontal, 14)
        .frame(height: 64)
        .background(MoyeoTheme.background)
    }

    @ViewBuilder
    private var discoveryContent: some View {
        recentSearchSection
        // 인기 검색어. **0건이면** 이 블록이 통째로 사라진다 — 빈 상태 문구를 두지 않는다.
        // 다만 **못 받은 것**은 숨기지 않고 다시 시도할 길을 준다.
        if !popularKeywordModel.rows.isEmpty {
            SearchPopularKeywordSection(rows: popularKeywordModel.rows, onSelect: runSearch)
        } else if popularKeywordModel.didFail {
            MoyeoSectionRetryNotice(
                message: "인기 검색어를 불러오지 못했어요.",
                identifier: "search.popular"
            ) {
                Task { await popularKeywordModel.load() }
            }
        }
    }

    @ViewBuilder
    private var recentSearchSection: some View {
        if recentSearchModel.searches.isEmpty {
            MoyeoEmptyStateView(
                message: MoyeoEmptyText.noRecentSearches,
                systemImage: "clock.arrow.circlepath",
                accessibilityIdentifier: "search.recent.empty"
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("최근 검색어")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.ink)
                    Spacer()
                    Button("전체 삭제") {
                        recentSearchModel.clear()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.muted)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("search.recent.clearAll")
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(recentSearchChunks, id: \.first) { chunk in
                        recentSearchRow(chunk)
                    }
                }
            }
            .accessibilityIdentifier("search.recent.section")
        }
    }

    private func recentSearchRow(_ searches: [String]) -> some View {
        HStack(spacing: 7) {
            ForEach(searches, id: \.self) { keyword in
                HStack(spacing: 5) {
                    Button(keyword) {
                        runSearch(keyword)
                    }
                    .buttonStyle(.plain)
                    // 사용자가 직접 입력한 긴 검색어가 캡슐 밖으로 줄바꿈되지 않게 한다
                    .lineLimit(1)

                    Button {
                        recentSearchModel.remove(keyword)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(keyword) 삭제")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(MoyeoTheme.text700)
                .padding(.horizontal, 11)
                .frame(height: 32)
                .overlay {
                    Capsule().stroke(MoyeoTheme.line, lineWidth: 1)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func submitSearch() {
        runSearch(query)
    }

    /// 검색 실행 — 입력창을 채우고 결과를 그리고, 최근 검색어에 기록한다
    private func runSearch(_ keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        query = keyword
        submittedQuery = trimmed
        recentSearchModel.record(trimmed)
    }
}

/// 실서버 검색 결과 행 — 서버가 내려준 값만 그린다.
/// 상태 배지·찜 하트는 10 탐색 카드와 같은 표기를 쓴다(서버 `status`·`favorite` 근거).
/// 14 코스 상세의 `모집 중인 모임 보기`(`CourseRecruitmentsView`)도 같은 응답이라 이 행을 그대로 쓴다.
struct ServerRoomSearchResultRow: View {
    let room: ServerChatRoomSummary
    let isFavorite: Bool
    /// `NavigationLink` 안에 놓일 때는 거짓이다 — 안쪽 버튼이 링크의 탭을 먹지 않게 한다 (IOS-F45).
    var isOpenButtonEnabled = true
    let onOpen: () -> Void
    let onToggleFavorite: () -> Void

    private var scheduleLine: String {
        // 검색 응답에는 일정이 없다(2026-08-26 응답 축소) — 없으면 그 줄을 비운다.
        let schedule = room.startDate.map {
            ServerTripMapper.scheduleText(startDate: $0, endDate: room.endDate)
        } ?? ""
        // 당일 여행이면 시간까지, 숙박이면 서버가 시간을 null로 주므로 그 부분을 숨긴다.
        // 일정이 통째로 없으면(태그 검색·찜 목록 응답) 앞에 빈 구분점을 남기지 않는다.
        let dayTrip = room.dayTripTimeText ?? ""
        return [schedule, dayTrip, "\(room.participantCount)/\(room.maxParticipants)명"]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            // `NavigationLink` 안에서는 이 버튼을 **잠근다.** 살려 두면 안쪽 버튼이 탭을
            // 먼저 먹어 링크가 동작하지 않는다 — 찜한 모집 카드가 눌러도 아무 데도 안
            // 가던 이유다 (IOS-F45).
            Button(action: onOpen) {
                summary
            }
            .buttonStyle(.plain)
            .disabled(!isOpenButtonEnabled)
            .accessibilityLabel(room.title)
            .accessibilityIdentifier("search.serverRoom.\(room.roomId)")

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isFavorite ? MoyeoTheme.coral : MoyeoTheme.text700)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "찜 해제" : "찜")
            .accessibilityValue(isFavorite ? "선택됨" : "선택 안 됨")
            .accessibilityIdentifier("search.serverRoom.favorite.\(room.roomId)")
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            CachedRemoteImage(url: room.thumbnailURL, fallbackShape: .square) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                MoyeoTheme.leaf
            }
            .frame(width: 72, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                Text(room.statusBadgeText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(MoyeoTheme.forest)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .padding(4)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(room.title)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                    .lineLimit(1)
                Text(
                    ([room.courseTitle].compactMap { $0 } + room.tagNames.prefix(2))
                        .filter { !$0.isEmpty }
                        .joined(separator: " · ")
                )
                .font(.caption)
                .foregroundStyle(MoyeoTheme.muted)
                .lineLimit(1)
                Text(scheduleLine)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MoyeoTheme.text700)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct SearchNoResultsView: View {
    let query: String
    /// 지금 보고 있는 탭. 예전에는 모집 탭에서도 「지역이나 **코스**를 찾지 못했어요」라고
    /// 적혀, 무엇을 못 찾았다는 건지 어긋났다 (IOS-F25).
    let tab: SearchResultTab
    let onClear: () -> Void

    private var subjectText: String {
        switch tab {
        case .course: "지역이나 코스"
        case .room: "지역이나 모집"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title2.weight(.bold))
                .foregroundStyle(MoyeoTheme.forest)
                .frame(width: 44, height: 44)
                .background(MoyeoTheme.leaf)
                .clipShape(Circle())

            VStack(spacing: 5) {
                Text("검색 결과가 없어요")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                Text("'\(query)'에 맞는 \(subjectText)를 찾지 못했어요.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onClear) {
                Label("검색어 지우기", systemImage: "xmark.circle.fill")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(MoyeoTheme.forest)
                    .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                .stroke(MoyeoTheme.softLine, lineWidth: 1)
        }
        .accessibilityIdentifier("search.noResults")
    }
}
