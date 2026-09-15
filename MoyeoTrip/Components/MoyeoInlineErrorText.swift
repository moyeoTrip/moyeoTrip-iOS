//
//  MoyeoInlineErrorText.swift
//  MoyeoTrip
//
//  사용자가 **누른 동작**이 실패했을 때 그 자리에 적는 한 줄.
//
//  화면 곳곳이 `try?` 와 빈 `catch` 로 실패를 삼켜, 버튼이 안 눌린 것처럼 보였다
//  (TC DETAIL-004 · SOCIAL-010 계열 · 웹 교차). 고칠 때마다 같은 모양의 Text 를
//  여섯 줄씩 다시 쓰게 돼 한 곳으로 모은다 — 찜 실패(`ExploreView`)가 쓰던 모양 그대로다.
//
//  **문장은 클라이언트가 소유한다** (2026-09-14 결정 ⑩). 서버 `errorMessage` 를 그대로
//  넘기지 말고 `error.moyeoUserMessage(fallback:)` 로 만든 값을 넘긴다.
//

import SwiftUI

struct MoyeoInlineErrorText: View {
    let message: String
    var identifier: String?

    var body: some View {
        Text(message)
            .font(.caption.weight(.semibold))
            .foregroundStyle(MoyeoTheme.dangerRed)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier(identifier ?? "")
    }
}
