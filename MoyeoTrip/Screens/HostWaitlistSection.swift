//
//  HostWaitlistSection.swift
//  MoyeoTrip
//
//  18 모집 관리 「대기열」 (2026-09-14).
//
//  `GET /api/v1/chat-rooms/{roomId}/applications/waitlist` — 호스트만 200 이다.
//  정원이 찬 뒤 호스트가 승인한 신청은 멤버가 되지 않고 여기로 간다
//  (서버 `ApprovalResult.WAITLISTED`). 자리가 나면 순서대로 자동 합류한다.
//
//  「거절 기록」과 **같은 결**이다 — 같은 섹션 제목, 같은 접힌 줄(`HostCompactApplicantRow`).
//

import SwiftUI

struct HostWaitlistSection: View {
    /// `position` 오름차순으로 이미 정렬된 목록. **순번은 서버가 준 값 그대로다.**
    let waitlist: [HostApplicant]
    let onOpenProfile: (SupportRoute) -> Void

    var body: some View {
        HostManageSectionTitle(
            title: "대기열",
            count: waitlist.count,
            trailingNote: "자리가 나면 순서대로 합류"
        )
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 12)

        content
            .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var content: some View {
        if waitlist.isEmpty {
            HostManageEmptyState {
                // 정본 `REPORT-COPY-CANON.md` 「대기열 · 빈 상태」 문장 그대로다.
                // 웹·안드로이드는 이미 이 문장을 쓰고 iOS 만 달랐다.
                Text("대기 중인 사람이 없어요. 정원이 찬 뒤 승인한 신청이 이곳에 쌓여요.")
                    .font(.subheadline)
                    .foregroundStyle(MoyeoTheme.muted)
            }
            .accessibilityIdentifier("hostWaitlist.empty")
        } else {
            ForEach(waitlist) { applicant in
                HostCompactApplicantRow(
                    applicant: applicant,
                    // 「대기 1번 · 33세 · 남성 · 여행 0회」 — 순번이 맨 앞이다.
                    detail: applicant.meta,
                    action: applicant.profileCardRoute.map { route in { onOpenProfile(route) } }
                )
                .padding(.bottom, 8)
                .accessibilityIdentifier("hostWaitlist.\(applicant.id)")
            }
        }
    }
}
