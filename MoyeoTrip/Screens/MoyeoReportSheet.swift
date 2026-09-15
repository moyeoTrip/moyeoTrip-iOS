//
//  MoyeoReportSheet.swift
//  MoyeoTrip
//
//  댓글 · 모집 · 멤버 신고 시트 (2026-09-14).
//
//  **30-2 피드 신고 시트와 같은 결**이다 — 같은 손잡이·제목·사유 라디오·300자 상세·
//  좁은 「취소」와 넓은 붉은 「신고하기」. 다른 것은 대상뿐이라 모양까지 달라질 이유가 없다.
//
//  대상별 엔드포인트·사유 목록·오류 문구는 [MoyeoReportTarget] 이 갖는다.
//  이 파일은 **화면만** 한다.
//

import SwiftUI

/// 누른 자리 위에 얹는 신고 시트. 라우트가 아니라 오버레이다 —
/// 예전 `ReportUnsupportedDialog` 가 있던 자리를 그대로 받아 화면을 옮기지 않는다 (정본 §3).
struct MoyeoReportSheet: View {
    /// 사유 목록 요청 상태. `loaded` 가 아니면 사유 줄을 그리지 않는다 (NO-MOCK R1).
    private enum ReasonsState {
        case loading
        case loaded([MoyeoReportReason])
        case failed
    }

    /// 서버 `details` 상한. 넘겨 보내면 400 `40000` 이다.
    private static let detailsLimit = 300

    let target: MoyeoReportTarget
    /// 시트 위쪽 미리보기 한 줄(댓글 본문·모집 제목·멤버 이름). 없으면 줄을 두지 않는다.
    var previewText: String?
    let onClose: () -> Void

    @State private var reasonsState: ReasonsState = .loading
    @State private var selectedReason: String?
    @State private var details = ""
    @State private var isSubmitting = false
    @State private var notice: MoyeoReportNotice?
    /// 접수가 끝났는지. 끝나면 「신고하기」를 지우고 「닫기」만 남긴다 — 같은 신고를 두 번 보내지 않는다.
    @State private var didSubmit = false

    private var canSubmit: Bool {
        selectedReason != nil && !isSubmitting && !didSubmit
    }

    private var identifierPrefix: String { target.accessibilityPrefix }

    var body: some View {
        // **딤은 배경으로 깐다.** 예전에는 `overlayScrim.ignoresSafeArea()` 를 ZStack 의
        // 첫 자식으로 두었는데, 그러면 ZStack 의 레이아웃 프레임이 안전영역 밖까지 커져
        // **그려지는 자리와 탭을 받는 자리가 약 60pt(상단 안전영역만큼) 어긋났다** —
        // 시트 아래쪽 「취소 · 신고하기」가 보이는데 눌리지 않았다 (2026-09-14 기기 확인).
        // 레이아웃은 안전영역 안에 두고, 화면 끝까지 어둡게 하는 일만 배경이 맡는다.
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(MoyeoTheme.overlayScrim)
                .contentShape(Rectangle())
                .onTapGesture { onClose() }
            sheet
        }
        .background(MoyeoTheme.overlayScrim.ignoresSafeArea())
        // `.sheet` 가 아니라 화면 위에 겹쳐 그리는 오버레이라 UIKit 이 모달로 쳐 주지 않는다 —
        // 스크린리더가 시트 밖(뒤 화면)까지 계속 읽었다. 직접 모달이라고 알려 준다 (TC ENV-007).
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("screen.\(identifierPrefix)")
        .task { await loadReasons() }
    }

    /// 사유가 8종(멤버 신고)까지 오므로 **고르는 부분만** 스크롤하고
    /// 「취소 · 신고하기」는 바닥에 고정한다. 예전에는 버튼까지 스크롤 안에 있었고,
    /// 스크롤 콘텐츠가 시트 높이를 넘으면 그 줄이 그려지기만 하고 **탭이 닿지 않았다**
    /// (2026-09-14 기기에서 확인 — 보이는데 눌리지 않는 죽은 버튼).
    private var sheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(MoyeoTheme.softLine)
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("신고 사유를 알려주세요")
                        .font(MoyeoTypography.sectionTitle)
                    Text(target.subjectText)
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.muted)
                    previewRow
                    reasonList
                    if case .loaded = reasonsState {
                        detailsEditor
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(alignment: .leading, spacing: 0) {
                actionRow
                noticeRow
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(maxHeight: 560)
        // 다른 바텀시트(20-1a·31)와 같은 표면이다 — 카드색은 화면 바닥까지 내려가고
        // **내용은 안전영역 안에** 머문다. 버튼이 홈 인디케이터 위로 내려가면 눌리지 않는다.
        .moyeoBottomSheetSurface()
    }

    @ViewBuilder
    private var previewRow: some View {
        if let previewText, !previewText.isEmpty {
            Text(previewText)
                .font(.caption)
                .foregroundStyle(MoyeoTheme.ink)
                .lineLimit(2)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MoyeoTheme.subtleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityIdentifier("\(identifierPrefix).preview")
        }
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
                .accessibilityIdentifier("\(identifierPrefix).reasons.loading")
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
                .accessibilityIdentifier("\(identifierPrefix).reasons.retry")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .accessibilityIdentifier("\(identifierPrefix).reasons.failed")
        case .loaded(let reasons):
            // 표시 문구는 서버 displayName 그대로다. **미리 고르지 않는다** —
            // 첫 사유를 자동 선택하면 읽지도 않은 사유로 신고가 접수된다 (30-2 와 같은 규칙).
            ForEach(reasons) { item in
                ChangelogRadioOption(
                    title: item.displayName,
                    isSelected: selectedReason == item.reason
                ) {
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
                        if value.count > Self.detailsLimit {
                            details = String(value.prefix(Self.detailsLimit))
                        }
                    }
                    .accessibilityIdentifier("\(identifierPrefix).details")
            }
            Text("\(details.count) / \(Self.detailsLimit)")
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
            Button(didSubmit ? "닫기" : "취소") { onClose() }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MoyeoTheme.ink)
                .frame(width: 62, height: 48)
                .accessibilityIdentifier("\(identifierPrefix).cancel")
            if !didSubmit {
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
                .accessibilityIdentifier("\(identifierPrefix).submit")
            }
        }
    }

    @ViewBuilder
    private var noticeRow: some View {
        switch notice {
        case .none:
            EmptyView()
        case .info(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(MoyeoTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
                .accessibilityIdentifier("\(identifierPrefix).info")
        case .failure(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(MoyeoTheme.dangerRed)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
                .accessibilityIdentifier("\(identifierPrefix).error")
        }
    }

    private func loadReasons() async {
        guard MoyeoServerSync.isEnabled else {
            reasonsState = .failed
            return
        }
        do {
            let reasons = try await target.reasons()
            reasonsState = reasons.isEmpty ? .failed : .loaded(reasons)
        } catch {
            reasonsState = .failed
        }
    }

    private func submit() {
        guard let reason = selectedReason, !isSubmitting else { return }
        isSubmitting = true
        notice = nil
        Task {
            do {
                try await target.submit(reason: reason, details: details)
                notice = .info(target.successText)
                didSubmit = true
            } catch {
                let mapped = target.notice(for: error)
                notice = mapped
                // 「본인 것이라 안 된다」·「이미 신고했다」는 다시 눌러도 결과가 같다 —
                // 그 자리에서 닫도록 접수와 같은 상태로 둔다.
                if case .info = mapped { didSubmit = true }
            }
            isSubmitting = false
        }
    }
}
