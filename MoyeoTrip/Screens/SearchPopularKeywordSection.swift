//
//  SearchPopularKeywordSection.swift
//  MoyeoTrip
//
//  12 검색 · 인기 검색어 섹션. `SearchView.swift` 가 500줄을 넘어 갈라냈다.
//

import Combine
import SwiftUI

/// 12 인기 검색어 목록의 상태. **0건과 실패를 가른다.**
///
/// 0건이면 섹션을 감추는 게 맞지만(빈 상태 문구를 새로 만들지 않는다), 못 받은 것을 같이 감추면
/// 사용자는 「오늘은 인기 검색어가 없구나」로 읽는다 — 안드 `SEARCH-032` 와 같은 결함이었다.
@MainActor
final class SearchPopularKeywordModel: ObservableObject {
    @Published private(set) var rows: [ServerPopularKeyword] = []
    @Published private(set) var didFail = false

    /// 인증이 필요한 집계라 세션이 없으면 부르지 않는다.
    func load() async {
        guard MoyeoServerSync.isEnabled else { return }
        do {
            rows = try await SearchAPIClient.shared.popularKeywords(limit: 10)
            didFail = false
        } catch {
            rows = []
            didFail = true
        }
    }
}

/// 12 인기 검색어 (`GET /api/v1/search/popular-keywords?limit=10`).
///
/// 순위 · 검색어 · **등락**을 그린다. 등락은 서버가 준 `rankTrend`/`rankChange` 뿐이고
/// 기준은 **전일 순위**다 — 그래서 제목 옆에 「전일 대비」를 적는다.
/// 검색 횟수(`searchCount`)는 감춘다: QA 검색이 만든 숫자가 실제 인기와 무관해 보였다.
/// 0건이면 화면이 이 섹션을 아예 만들지 않는다(빈 상태 문구를 새로 만들지 않는다).
struct SearchPopularKeywordSection: View {
    let rows: [ServerPopularKeyword]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                // 글자 크기·간격은 화면기획 12 를 그대로 따른다 (제목 13 · 줄 14 · 등락 11).
                Text("인기 검색어")
                    .font(MoyeoTypography.font(size: 13, weight: .bold, relativeTo: .subheadline))
                    .foregroundStyle(MoyeoTheme.ink)
                Spacer(minLength: 8)
                // 등락의 기준 시점. 서버 집계가 **전일 순위 대비**다 (API 스펙).
                Text("전일 대비")
                    .font(MoyeoTypography.tinyMeta)
                    .foregroundStyle(MoyeoTheme.text400)
            }

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
        HStack(spacing: 16) {
            Text("\(row.rank)")
                .font(MoyeoTypography.font(size: 14, weight: .bold, relativeTo: .subheadline))
                .monospacedDigit()
                .foregroundStyle(row.rank <= 3 ? MoyeoTheme.forest : MoyeoTheme.muted)
                .frame(width: 16, alignment: .leading)
            Text(row.keyword)
                .font(MoyeoTypography.cardBody)
                .foregroundStyle(MoyeoTheme.ink)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let trend = Self.trendMark(row) {
                Text(trend.text)
                    .font(MoyeoTypography.font(size: 11, weight: .bold, relativeTo: .caption2))
                    .monospacedDigit()
                    .foregroundStyle(trend.color)
                    .accessibilityLabel(trend.label)
            }
        }
        .frame(height: 44)
        .contentShape(Rectangle())
    }

    /// 등락 글자·색·읽어줄 말. 서버가 등락을 주지 않은 줄은 `nil` 이고 **그 자리를 비운다.**
    static func trendMark(_ row: ServerPopularKeyword) -> RankTrendMark? {
        let step = abs(row.rankChange ?? 0)
        switch row.rankTrend {
        case .up:
            return RankTrendMark(text: step > 0 ? "▲\(step)" : "▲", color: MoyeoTheme.coral, label: "전일 대비 \(step)단계 상승")
        case .down:
            return RankTrendMark(text: step > 0 ? "▼\(step)" : "▼", color: MoyeoTheme.rankDown, label: "전일 대비 \(step)단계 하락")
        case .same:
            return RankTrendMark(text: "—", color: MoyeoTheme.text400, label: "전일과 같은 순위")
        case .new:
            return RankTrendMark(text: "NEW", color: MoyeoTheme.forest, label: "새로 진입")
        case .unknown, .none:
            return nil
        }
    }
}

/// 인기 검색어 한 줄의 등락 표시 — 글자 · 색 · 읽어줄 말.
struct RankTrendMark {
    let text: String
    let color: Color
    let label: String
}
