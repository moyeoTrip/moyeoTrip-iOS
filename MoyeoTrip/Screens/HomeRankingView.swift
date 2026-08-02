//
//  HomeRankingView.swift
//  MoyeoTrip
//

import SwiftUI

struct PopularCourseRanking: View {
    private let rankings = [
        RankedCourse(courseID: "course-cheongsong-juwangsan", title: "주왕산 단풍 물길", meta: "청송 · 자연"),
        RankedCourse(courseID: "course-andong-hahoe", title: "안동 하회마을 산책", meta: "안동 · 문화"),
        RankedCourse(courseID: "course-ulleung-island", title: "울릉도 2박 3일 섬 여행", meta: "울릉 · 힐링")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("인기 코스 TOP 3")
                .font(MoyeoTypography.sectionTitle)
                .foregroundStyle(MoyeoTheme.ink)

            VStack(spacing: 10) {
                ForEach(Array(rankings.enumerated()), id: \.offset) { index, ranking in
                    if let course = MockData.course(for: ranking.courseID) {
                        NavigationLink(value: course) {
                            rankingRow(index: index, ranking: ranking)
                        }
                        .buttonStyle(.plain)
                        .frame(height: 68)
                        .padding(.horizontal, 14)
                        .background(MoyeoTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                                .stroke(MoyeoTheme.softLine, lineWidth: 1)
                        }
                    }
                }
            }
        }
    }

    private func rankingRow(index: Int, ranking: RankedCourse) -> some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.subheadline.bold())
                .foregroundStyle(MoyeoTheme.forest)
                .frame(width: 32, height: 32)
                .background(MoyeoTheme.leaf)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(ranking.title)
                    .font(MoyeoTypography.cardTitle)
                    .foregroundStyle(MoyeoTheme.ink)
                    .accessibilityIdentifier("home.ranking.\(index + 1).title")
                Text(ranking.meta)
                    .font(MoyeoTypography.cardMeta)
                    .foregroundStyle(MoyeoTheme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(MoyeoTheme.text400)
        }
    }
}

private struct RankedCourse {
    let courseID: String
    let title: String
    let meta: String
}
