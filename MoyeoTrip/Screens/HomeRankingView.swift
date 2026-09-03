//
//  HomeRankingView.swift
//  MoyeoTrip
//

import SwiftUI

/// 09 홈 · 인기 코스 TOP 3.
///
/// `GET /api/v1/travel-courses/public/popular` 상위 3개를 그린다 — 웹·안드로이드와 같은 섹션이다.
/// 순위 API가 없다고 잘못 판단해 섹션째 지웠던 자리를 되살렸다 (NO-MOCK-CANON §4-1).
///
/// 값은 전부 서버 응답이다. 못 받으면 지어내지 않고 §2 빈 상태·로딩을 그린다 (R1).
/// 갱신 중이라도 이미 받은 목록이 있으면 로딩으로 덮지 않는다 (TAB-STATE-CANON R2·R3).
struct PopularCourseRanking: View {
    let courses: [TravelCourse]?
    let isLoading: Bool

    private var topThree: [TravelCourse] {
        Array((courses ?? []).prefix(3))
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("인기 코스 TOP 3")
                    .font(MoyeoTypography.sectionTitle)
                    .foregroundStyle(MoyeoTheme.ink)
                Spacer()
            }

            if courses == nil, isLoading {
                message(MoyeoEmptyText.loading, identifier: "home.popularCourses.loading")
            } else if topThree.isEmpty {
                message("아직 인기 코스가 없어요.", identifier: "home.popularCourses.empty")
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(topThree.enumerated()), id: \.element.id) { index, course in
                        NavigationLink(value: course) {
                            PopularCourseRow(rank: index + 1, course: course)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("home.popularCourse.\(course.id)")
                    }
                }
            }
        }
    }

    private func message(_ text: String, identifier: String) -> some View {
        Text(text)
            .font(MoyeoTypography.cardMeta)
            .foregroundStyle(MoyeoTheme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .accessibilityIdentifier(identifier)
    }
}

/// 순위 한 줄 — 번호 · 코스 이름 · 한 줄 설명.
private struct PopularCourseRow: View {
    let rank: Int
    let course: TravelCourse

    /// 서버가 설명을 주지 않으면 소요 시간·거리로 대신한다 (안드로이드와 같은 규칙).
    /// 둘 다 없으면 줄을 아예 그리지 않는다 — 빈 자리를 지어내지 않는다.
    private var subtitle: String {
        if !course.subtitle.isEmpty { return course.subtitle }
        return [course.duration, course.distance]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(MoyeoTypography.chip)
                .foregroundStyle(MoyeoTheme.forest)
                .frame(width: 28, height: 28)
                .background(MoyeoTheme.leaf)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(course.title)
                    .font(MoyeoTypography.chip)
                    .foregroundStyle(MoyeoTheme.ink)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(MoyeoTypography.cardMeta)
                        .foregroundStyle(MoyeoTheme.muted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(MoyeoTheme.muted.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .frame(height: 62)
        .frame(maxWidth: .infinity)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                .stroke(MoyeoTheme.softLine, lineWidth: 1)
        }
    }
}
