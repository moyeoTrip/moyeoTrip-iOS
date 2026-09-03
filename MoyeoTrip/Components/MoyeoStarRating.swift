//
//  MoyeoStarRating.swift
//  MoyeoTrip
//
//  별점 입력 (1~5). 27-4 코스 평가와 27-1 매너 점수가 같은 것을 쓴다.
//
//  서버가 받는 값이 **정수 1~5** 라 반 개짜리 별을 두지 않는다
//  (`RateTravelCourseRequest.score` · `ReviewTravelCompanionRequest.mannerScore`).
//
//  이 입력이 한 픽셀도 없어서 앱 곳곳의 `매너 4.7` 을 만드는 사람이 아무도 없었다.
//

import SwiftUI

/// 별 1~5 입력. `score` 가 0 이면 "아직 고르지 않음"이다 — 기본값을 채워 넣지 않는다.
struct MoyeoStarRatingInput: View {
    @Binding var score: Int
    var size: CGFloat = 40
    var spacing: CGFloat = 8
    var identifier: String

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    score = value
                } label: {
                    Image(systemName: value <= score ? "star.fill" : "star")
                        .font(.system(size: size, weight: .medium))
                        .foregroundStyle(value <= score ? MoyeoTheme.sunrise : MoyeoTheme.line)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(value)점")
                .accessibilityIdentifier("\(identifier).\(value)")
            }
        }
        .accessibilityIdentifier(identifier)
    }
}

/// 고른 점수를 말로 옮긴 한 줄. 고르기 전에는 **아무 말도 하지 않는다** —
/// 기본 문구를 띄우면 이미 고른 것처럼 보인다 (기획 27-4 주석).
enum MoyeoStarRatingWord {
    nonisolated static let words = ["", "아쉬웠어요", "그저 그랬어요", "괜찮았어요", "좋았어요", "정말 좋았어요"]

    nonisolated static func text(for score: Int) -> String {
        guard words.indices.contains(score) else { return "" }
        return words[score]
    }
}
