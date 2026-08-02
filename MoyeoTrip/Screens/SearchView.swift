import SwiftUI

struct SearchView: View {
    var tripContext = TripInteractionContext()
    @State private var query = ""

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: [TravelCourse] {
        guard !trimmedQuery.isEmpty else { return MockData.courses }
        return MockData.courses.filter { course in
            course.title.localizedCaseInsensitiveContains(trimmedQuery)
                || course.region.localizedCaseInsensitiveContains(trimmedQuery)
                || course.tags.contains { $0.localizedCaseInsensitiveContains(trimmedQuery) }
        }
    }

    var body: some View {
        SupportList(title: "검색") {
            SearchField(text: $query, placeholder: "지역, 테마, 코스 검색")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["청송", "안동", "경주", "포항", "문경", "영주"], id: \.self) { keyword in
                        Button {
                            query = keyword
                        } label: {
                            Text(keyword)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(MoyeoTheme.forest)
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .background(MoyeoTheme.leaf)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if results.isEmpty {
                SearchNoResultsView(query: trimmedQuery) {
                    query = ""
                }
            } else {
                ForEach(results) { course in
                    NavigationLink(value: course) {
                        SupportCourseSummary(course: course, compact: true)
                            .moyeoCard()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationDestination(for: TravelCourse.self) { course in
            CourseDetailView(
                course: course,
                tripContext: tripContext
            )
        }
        .accessibilityIdentifier("screen.search")
    }
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
