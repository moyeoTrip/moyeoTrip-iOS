import SwiftUI

struct SearchView: View {
    var tripContext = TripInteractionContext()
    @Environment(\.dismiss) private var dismiss
    @State private var query: String
    @State private var submittedQuery = ""
    @State private var recentSearches = ["경주", "단풍", "황리단길", "안동 한옥", "주왕산"]

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
        .accessibilityIdentifier("screen.search")
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("최근 검색어")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                Spacer()
                Button("전체 삭제") {
                    recentSearches.removeAll()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(MoyeoTheme.muted)
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                recentSearchRow(Array(recentSearches.prefix(4)))
                recentSearchRow(Array(recentSearches.dropFirst(4)))
            }
        }

        VStack(alignment: .leading, spacing: 4) {
            Text("인기 검색어")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)
                .padding(.bottom, 6)

            ForEach(popularSearches) { item in
                Button {
                    query = item.keyword
                    submittedQuery = item.keyword
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
                        query = keyword
                        submittedQuery = keyword
                    }
                    .buttonStyle(.plain)

                    Button {
                        recentSearches.removeAll { $0 == keyword }
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
        submittedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
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
