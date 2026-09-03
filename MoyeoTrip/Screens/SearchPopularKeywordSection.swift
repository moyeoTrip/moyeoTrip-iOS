//
//  SearchPopularKeywordSection.swift
//  MoyeoTrip
//
//  12 검색 · 인기 검색어 섹션. `SearchView.swift` 가 500줄을 넘어 갈라냈다.
//

import SwiftUI

/// 12 인기 검색어 (`GET /api/v1/search/popular-keywords?limit=10`).
///
/// 그리는 값은 서버가 준 `rank` · `keyword` · `searchCount` **뿐이다.**
/// 화면기획의 상승·하락 화살표(▲▼)는 목데이터였다 — 서버가 주지 않으므로 그리지 않는다.
/// 0건이면 화면이 이 섹션을 아예 만들지 않는다(빈 상태 문구를 새로 만들지 않는다).
struct SearchPopularKeywordSection: View {
    let rows: [ServerPopularKeyword]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("인기 검색어")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)

            VStack(spacing: 0) {
                ForEach(rows) { row in
                    Button { onSelect(row.keyword) } label: { rowLabel(row) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("search.popular.\(row.rank)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("search.popular.section")
    }

    private func rowLabel(_ row: ServerPopularKeyword) -> some View {
        HStack(spacing: 12) {
            Text("\(row.rank)")
                .font(.caption.weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(row.rank <= 3 ? MoyeoTheme.forest : MoyeoTheme.muted)
                .frame(width: 18, alignment: .leading)
            Text(row.keyword)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MoyeoTheme.ink)
                .lineLimit(1)
            Spacer(minLength: 8)
            // 서버가 주는 값은 여기까지다. 상승·하락 표시는 근거가 없어 그리지 않는다.
            Text("\(row.searchCount)회")
                .font(MoyeoTypography.tinyMeta)
                .monospacedDigit()
                .foregroundStyle(MoyeoTheme.text400)
        }
        .frame(height: 40)
        .contentShape(Rectangle())
    }
}
