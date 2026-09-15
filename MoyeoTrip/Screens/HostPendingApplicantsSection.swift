//
//  HostPendingApplicantsSection.swift
//  MoyeoTrip
//
//  화면기획 18 호스트 관리 — 「승인 대기」 구역.
//
//  `HostManageView` 안의 계산 프로퍼티로 두면 SwiftLint `type_body_length`(300줄)를 넘는다
//  (`ReportScreens.swift` 의 `ReportBackdrop` 과 같은 까닭).
//

import SwiftUI

struct HostPendingApplicantsSection: View {
    let applicants: [HostApplicant]
    /// 승인·거절이 실패한 까닭. 카드를 그대로 둔 채 구역 맨 위에 적는다 (TC SOCIAL-010 계열).
    let failureMessage: String?
    let onApprove: (HostApplicant) -> Void
    let onReject: (HostApplicant) -> Void
    let onOpenProfile: (SupportRoute) -> Void

    var body: some View {
        // 까닭은 목록보다 먼저, 목록이 비어도 그린다 — 실패한 뒤 목록을 다시 받아
        // 그 신청이 사라지면(다른 곳에서 먼저 처리됐거나 신청자가 취소) 대기가 0이 되는데,
        // 예전에는 이 문구가 카드와 함께 사라져 **무슨 일이 있었는지 알 수 없었다** (TC HOST-008).
        if let failureMessage {
            MoyeoInlineErrorText(message: failureMessage, identifier: "hostPending.error")
                .padding(.bottom, 8)
        }
        if applicants.isEmpty {
            HostManageEmptyState {
                Text("새 신청이 오면 이곳에서 승인하거나 거절할 수 있어요.")
                    .font(.subheadline)
                    .foregroundStyle(MoyeoTheme.muted)
            }
        } else {
            if let primaryApplicant = applicants.first {
                HostApplicantCard(
                    applicant: primaryApplicant,
                    primaryLabel: "승인",
                    secondaryLabel: "거절",
                    onPrimary: { onApprove(primaryApplicant) },
                    onSecondary: { onReject(primaryApplicant) },
                    onOpenProfile: primaryApplicant.profileCardRoute.map { route in
                        { onOpenProfile(route) }
                    }
                )
            }
            ForEach(Array(applicants.dropFirst())) { applicant in
                // 화면기획 18 — 접힌 대기자는 요약(나이·성별·매너)과 chevron만 보인다
                HostCompactApplicantRow(
                    applicant: applicant,
                    detail: applicant.meta,
                    action: applicant.profileCardRoute.map { route in { onOpenProfile(route) } }
                )
                .padding(.top, 8)
                .accessibilityIdentifier("hostPending.\(applicant.id)")
            }
        }
    }
}
