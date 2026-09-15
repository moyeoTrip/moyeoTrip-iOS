//
//  HostRejectedSection.swift
//  MoyeoTrip
//
//  18 모집 관리 · 「거절 기록」 섹션.
//
//  값은 전부 서버가 준다 — `GET /chat-rooms/{roomId}/applications/rejected` (BE-17).
//  호스트 전용이라 참가자는 403 이고, 그때는 호출부가 이 섹션을 아예 그리지 않는다.
//
//  `HostManageView` 의 타입 본문이 300줄을 넘어 갈라냈다 (SwiftLint `type_body_length`).
//

import SwiftUI

struct HostRejectedSection: View {
    let rejected: [HostApplicant]
    /// 줄 아래 설명(「N일 전 거절」). 서버 `rejectedAt` 에서 만든 값이다.
    let detailByID: [String: String]
    let onOpenProfile: (SupportRoute) -> Void

    var body: some View {
        HostManageSectionTitle(title: "거절 기록", count: rejected.count)
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)

        if rejected.isEmpty {
            // 받아 왔는데 0건인 것과 못 받은 것은 다르다 — 여기는 **0건**일 때만 온다.
            HostManageEmptyState {
                // 문구는 **웹을 기준**으로 셋을 맞춘다 — 같은 자리에서 플랫폼마다 문장이 달랐다.
                Text("거절한 신청이 없어요.")
                    .font(.subheadline)
                    .foregroundStyle(MoyeoTheme.muted)
            }
            .padding(.horizontal, 20)
            .accessibilityIdentifier("hostRejected.empty")
        }

        ForEach(rejected) { applicant in
            HostCompactApplicantRow(
                applicant: applicant,
                detail: detailByID[applicant.id] ?? "거절한 신청",
                action: applicant.profileCardRoute.map { route in { onOpenProfile(route) } }
            )
            .padding(.horizontal, 20)
            .accessibilityIdentifier("hostRejected.\(applicant.id)")
        }
    }
}
