import SwiftUI

struct SearchView: View {
    var tripContext = TripInteractionContext()
    @Environment(\.dismiss) private var dismiss
    @State private var query: String
    @State private var submittedQuery = ""
    /// 최근 검색어 — 서버 API가 없어 `UserDefaults` 에 영구 저장한다 (캡처 모드는 기획 목데이터 고정)
    @StateObject private var recentSearchModel = RecentSearchModel.forCurrentRuntime()
    /// 실서버 검색 결과 — 로그인 세션이 있고 검색 API가 성공했을 때만 채워진다 (nil = 목데이터)
    @State private var serverResults: [ServerChatRoomSummary]?
    /// 찜 토글 결과. 서버 응답(`favorite`)이 기준이고, 토글한 방만 여기서 덮어쓴다.
    @State private var serverFavoriteOverrides: [Int64: Bool] = [:]
    @State private var selectedServerTrip: TripRecruitment?

    private let popularSearches = [
        PopularSearch(rank: 1, keyword: "주왕산", isRising: true),
        PopularSearch(rank: 2, keyword: "안동 한옥마을", isRising: true),
        PopularSearch(rank: 3, keyword: "경주 야경", isRising: false),
        PopularSearch(rank: 4, keyword: "포항 호미곶", isRising: true),
        PopularSearch(rank: 5, keyword: "문경 새재", isRising: false)
    ]

    init(tripContext: TripInteractionContext = TripInteractionContext()) {
        self.tripContext = tripContext
        let arguments = ProcessInfo.processInfo.arguments
        let previewQuery = arguments.contains("UITEST_SCREEN=search") ? "경주 단풍" : ""
        _query = State(initialValue: previewQuery)
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

    private var results: [TravelCourse] {
        guard !trimmedQuery.isEmpty else { return [] }
        return MockData.courses.filter { course in
            course.title.localizedCaseInsensitiveContains(trimmedQuery)
                || course.region.localizedCaseInsensitiveContains(trimmedQuery)
                || course.tags.contains { $0.localizedCaseInsensitiveContains(trimmedQuery) }
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
                        // 실서버 검색 결과 — 서버가 준 모임만 그린다
                        if serverResults.isEmpty {
                            SearchNoResultsView(query: trimmedQuery) {
                                query = ""
                                submittedQuery = ""
                            }
                        } else {
                            serverSearchResults(serverResults)
                        }
                    } else if results.isEmpty {
                        SearchNoResultsView(query: trimmedQuery) {
                            query = ""
                            submittedQuery = ""
                        }
                    } else {
                        searchResults
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
        .accessibilityIdentifier("screen.search")
    }

    private func loadServerResults() async {
        guard MoyeoServerSync.isEnabled, !trimmedQuery.isEmpty else {
            serverResults = nil
            return
        }
        serverResults = try? await ChatRoomAPIClient.shared.search(keyword: trimmedQuery)
    }

    private func serverSearchResults(_ rooms: [ServerChatRoomSummary]) -> some View {
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

    private func toggleServerFavorite(_ room: ServerChatRoomSummary) {
        guard MoyeoServerSync.isEnabled else { return }
        Task {
            // 실패하면 화면 값을 바꾸지 않는다 — 서버 응답만 신뢰한다.
            if let favorite = try? await ChatRoomAPIClient.shared.toggleFavorite(roomID: room.roomId) {
                serverFavoriteOverrides[room.roomId] = favorite
            }
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 10) {
            Button(action: dismiss.callAsFunction) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(MoyeoTheme.ink)
                    .frame(width: 34, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("뒤로")

            SearchField(text: $query, placeholder: "지역, 테마, 코스 검색")
                .frame(height: 44)
                .onChange(of: query) { _, newValue in
                    if newValue.isEmpty {
                        submittedQuery = ""
                    }
                }
                .onSubmit(submitSearch)

            Button("취소") {
                query = ""
                submittedQuery = ""
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(MoyeoTheme.muted)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(height: 64)
        .background(MoyeoTheme.background)
    }

    @ViewBuilder
    private var discoveryContent: some View {
        // 비어 있으면 섹션 전체(제목 · 전체 삭제 · 칩)를 숨긴다 — 기획에 빈 상태 문구가 없다
        if !recentSearchModel.searches.isEmpty {
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

        VStack(alignment: .leading, spacing: 4) {
            Text("인기 검색어")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)
                .padding(.bottom, 6)

            ForEach(popularSearches) { item in
                Button {
                    runSearch(item.keyword)
                } label: {
                    HStack(spacing: 16) {
                        Text("\(item.rank)")
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(item.rank <= 3 ? MoyeoTheme.forest : MoyeoTheme.muted)
                            .frame(width: 18, alignment: .leading)
                        Text(item.keyword)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MoyeoTheme.ink)
                        Spacer()
                        Text(item.isRising ? "▲" : "−")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(item.isRising ? MoyeoTheme.coral : MoyeoTheme.text400)
                    }
                    .frame(height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }

        // 추천 검색 결과 섹션은 화면기획에 없다 — 최근 검색어와 인기 검색어까지만 보여준다
    }

    private var searchResults: some View {
        ForEach(results) { course in
            NavigationLink(value: course) {
                SupportCourseSummary(course: course, compact: true)
                    .moyeoCard()
            }
            .buttonStyle(.plain)
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
private struct ServerRoomSearchResultRow: View {
    let room: ServerChatRoomSummary
    let isFavorite: Bool
    let onOpen: () -> Void
    let onToggleFavorite: () -> Void

    private var scheduleLine: String {
        let schedule = ServerTripMapper.scheduleText(startDate: room.startDate, endDate: room.endDate)
        // 당일 여행이면 시간까지, 숙박이면 서버가 시간을 null로 주므로 그 부분을 숨긴다.
        let dayTrip = room.dayTripTimeText.map { " · \($0)" } ?? ""
        return "\(schedule)\(dayTrip) · \(room.participantCount)/\(room.maxParticipants)명"
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    CachedRemoteImage(url: room.thumbnailURL) { image in
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
                            ([room.courseTitle] + room.tagNames.prefix(2))
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
            .buttonStyle(.plain)
            .accessibilityLabel(room.title)
            .accessibilityIdentifier("search.serverRoom.\(room.roomId)")

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isFavorite ? MoyeoTheme.coral : MoyeoTheme.text700)
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "찜 해제" : "찜")
            .accessibilityValue(isFavorite ? "선택됨" : "선택 안 됨")
            .accessibilityIdentifier("search.serverRoom.favorite.\(room.roomId)")
        }
    }
}

private struct PopularSearch: Identifiable {
    let rank: Int
    let keyword: String
    let isRising: Bool

    var id: Int { rank }
}

private struct SearchNoResultsView: View {
    let query: String
    let onClear: () -> Void

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
                Text("'\(query)'에 맞는 지역이나 코스를 찾지 못했어요.")
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
