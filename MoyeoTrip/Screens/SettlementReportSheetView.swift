//
//  SettlementReportSheetView.swift
//  MoyeoTrip
//
//  정산 금액 신고 (2026-09-14 사용자 결정).
//
//  정산은 **서비스가 중개하지 않는 사람 간 거래**다. 서버가 금액을 검증하지 않고 모여트립이
//  환불·보상을 하지도 않는다. 그래서 안내 문구는 「돌려드릴게요」로 읽히지 않게 사실만 적고,
//  그 안내에서 이어지는 신고는 서버 사유 `UNFAIR_SETTLEMENT`(부당한 정산 요구)로 접수된다.
//
//  사유 **목록**은 서버가 준다 — `GET /api/v1/chat-rooms/member-report-reasons` 가 코드와
//  표시 문구를 함께 준다. 클라이언트가 목록을 갖지 않는다(NO-MOCK-CANON R1) —
//  못 받으면 사유를 지어내지 않고 오류와 `다시 시도` 만 남긴다 (30-2 와 같은 규칙).
//
//  접수는 `POST /api/v1/chat-rooms/{roomId}/members/{memberId}/reports` → 204.
//

import SwiftUI

/// 세 표면이 함께 쓰는 정산 신고 문구·사유 코드.
enum MoyeoSettlementReport {
    /// 정산 화면·카드에 한 줄로 적는 안내.
    ///
    /// **웹 `SETTLEMENT_REPORT_GUIDE` · 안드로이드 `SETTLEMENT_REPORT_GUIDE` 와 글자까지
    /// 같아야 한다** — 고칠 때 셋을 함께 고친다.
    static let guide = "금액이 부당하다고 느끼면 신고할 수 있어요. 정산은 멤버끼리 직접 하는 거래라 모여트립이 중개하지 않아요."

    /// 안내에서 신고로 이어질 때 미리 골라 두는 서버 사유 코드 — 「부당한 정산 요구」.
    /// 서버 목록에 이 코드가 없으면 아무것도 고르지 않는다.
    static let reason = "UNFAIR_SETTLEMENT"

    /// 서버 `details` 상한. 넘겨 보내면 400 `40000` 이다.
    static let detailsLimit = 300
}

/// 채팅방 정산 카드의 「금액이 부당해요 · 신고하기」에서 올라오는 시트.
struct SettlementReportSheetView: View {
    /// 사유 목록 요청 상태. `loaded` 가 아니면 사유 줄을 그리지 않는다.
    private enum ReasonsState {
        case loading
        case loaded([ServerMemberReportReason])
        case failed
    }

    let roomID: Int64
    let memberID: Int64
    let memberNickname: String

    @Environment(\.dismiss) private var dismiss
    @State private var reasonsState: ReasonsState = .loading
    @State private var selectedReason: String? = MoyeoSettlementReport.reason
    @State private var details = ""
    @State private var isSubmitting = false
    @State private var errorText: String?
    /// 접수 결과(중립)와 오류(붉은색)를 나눈다 — 409 는 오류가 아니라 「이미 신고한 사용자」 안내다.
    @State private var resultText: String?

    private var canSubmit: Bool {
        selectedReason != nil && !isSubmitting && resultText == nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(headline)
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    reasonList
                    detailsEditor
                    noticeRow
                    actionRow
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(MoyeoTheme.background)
            .navigationTitle("신고 사유를 알려주세요")
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier("settlementReport.sheet")
        .task { await loadReasons() }
    }

    private var headline: String {
        memberNickname.isEmpty
            ? MoyeoSettlementReport.guide
            : "\(memberNickname)님을 신고해요. \(MoyeoSettlementReport.guide)"
    }

    @ViewBuilder
    private var reasonList: some View {
        switch reasonsState {
        case .loading:
            Text(MoyeoEmptyText.loading)
                .font(.subheadline)
                .foregroundStyle(MoyeoTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 18)
                .accessibilityIdentifier("settlementReport.reasons.loading")
        case .failed:
            VStack(alignment: .leading, spacing: 8) {
                Text(MoyeoEmptyText.loadFailed)
                    .font(.subheadline)
                    .foregroundStyle(MoyeoTheme.muted)
                Button(MoyeoEmptyText.retry) {
                    reasonsState = .loading
                    Task { await loadReasons() }
                }
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(MoyeoTheme.brandText)
                .accessibilityIdentifier("settlementReport.reasons.retry")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .accessibilityIdentifier("settlementReport.reasons.failed")
        case .loaded(let reasons):
            // 표시 문구는 서버 displayName 그대로다 — 클라가 문구를 갖지 않는다.
            ForEach(reasons) { item in
                ChangelogRadioOption(title: item.displayName, isSelected: selectedReason == item.reason) {
                    selectedReason = item.reason
                }
            }
        }
    }

    private var detailsEditor: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if details.isEmpty {
                    Text("어떤 점이 문제인지 알려주세요 (선택)")
                        .font(.subheadline)
                        .foregroundStyle(MoyeoTheme.text400)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                }
                TextEditor(text: $details)
                    .font(.subheadline)
                    .foregroundStyle(MoyeoTheme.ink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 72)
                    .onChange(of: details) { _, value in
                        if value.count > MoyeoSettlementReport.detailsLimit {
                            details = String(value.prefix(MoyeoSettlementReport.detailsLimit))
                        }
                    }
                    .accessibilityIdentifier("settlementReport.details")
            }
            Text("\(details.count) / \(MoyeoSettlementReport.detailsLimit)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(MoyeoTheme.text400)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(10)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MoyeoTheme.line, lineWidth: 1)
        }
    }

    // 취소는 좁은 중립 글자, 신고하기는 넓은 채움 — 30-2 와 같은 위계다.
    private var actionRow: some View {
        HStack(spacing: 8) {
            Button(resultText == nil ? "취소" : "닫기") { dismiss() }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MoyeoTheme.ink)
                .frame(width: 62, height: 48)
                .accessibilityIdentifier("settlementReport.cancel")
            if resultText == nil {
                Button(action: submit) {
                    Text(isSubmitting ? "접수 중..." : "신고하기")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(canSubmit ? .white : MoyeoTheme.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(canSubmit ? MoyeoTheme.dangerRed : MoyeoTheme.subtleBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .accessibilityIdentifier("settlementReport.submit")
            }
        }
    }

    @ViewBuilder
    private var noticeRow: some View {
        if let resultText {
            Text(resultText)
                .font(.caption)
                .foregroundStyle(MoyeoTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("settlementReport.result")
        }
        if let errorText {
            Text(errorText)
                .font(.caption)
                .foregroundStyle(MoyeoTheme.dangerRed)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("settlementReport.error")
        }
    }

    private func loadReasons() async {
        do {
            let reasons = try await ChatRoomWriteAPIClient.shared.memberReportReasons()
            guard !reasons.isEmpty else {
                reasonsState = .failed
                return
            }
            reasonsState = .loaded(reasons)
            // 서버 목록에 미리 고른 코드가 없으면 선택을 비운다 —
            // 목록에 없는 사유를 몰래 보내지 않는다.
            if !reasons.contains(where: { $0.reason == selectedReason }) {
                selectedReason = nil
            }
        } catch {
            reasonsState = .failed
        }
    }

    private func submit() {
        guard let reason = selectedReason, !isSubmitting else { return }
        isSubmitting = true
        errorText = nil
        Task {
            do {
                try await ChatRoomWriteAPIClient.shared.reportMember(
                    roomID: roomID,
                    memberID: memberID,
                    reason: reason,
                    details: details
                )
                resultText = "신고를 접수했어요."
            } catch {
                // **문구는 일반 멤버 신고와 한 곳에서 나온다** (`MoyeoReportTarget.member`).
                // 예전에는 여기서만 따로 적어, 같은 `40921` 이 일반 경로에서는
                // 「이미 신고한 사용자예요.」·정산 카드에서는 「이미 신고한 멤버예요.」가 됐다 —
                // 어디서 들어왔느냐로 문장이 바뀌면 안 된다 (`REPORT-COPY-CANON.md`).
                // 중립 안내(이미 신고함·자기 자신)는 붉게 띄우지 않는다.
                switch MoyeoReportTarget.member(roomID: roomID, memberID: memberID).notice(for: error) {
                case .info(let message):
                    resultText = message
                case .failure(let message):
                    errorText = message
                }
            }
            isSubmitting = false
        }
    }
}
