//
//  TermsHistoryView.swift
//  MoyeoTrip
//
//  약관 「지난 버전」 — 판본 목록 (2026-09-14 결정 ①).
//
//  서버가 주는 개인정보 처리방침 본문이 「지난 판본은 약관 화면의 "지난 버전"에서 보실 수
//  있습니다」라고 **약속하는데 세 플랫폼 어디에도 그 화면이 없었다.** 법적 고지가 없는 길을
//  가리키고 있었다. API(`GET /api/v1/terms/history/{code}`)는 이미 있고 호출부만 없었다.
//

import SwiftUI

/// 한 종류(`code`)의 약관 판본 목록. 최신순으로 서버가 준 그대로 그린다.
///
/// **본문이 열리는 것은 현재 판본뿐이다.** 지난 판본은 비활성이라
/// `GET /api/v1/terms/{termId}` 가 404 를 준다(실서버 확인, 2026-09-14).
/// 그래서 지난 판본에는 **눌리는 모양을 주지 않는다** — 눌러도 아무 일도 없는 줄은
/// 죽은 UI 다.
struct TermsHistoryView: View {
    /// 판본을 볼 약관 종류.
    let kind: LegalDocumentKind
    /// 상세 화면이 이미 받아 둔 **현재 판본**의 `termId`.
    ///
    /// 목록 응답에는 활성 여부 필드가 없다. 「최신 한 줄이 현재」라고 **넘겨짚지 않고**,
    /// `GET /terms/latest/{code}` 가 준 id 와 맞춰 본 줄에만 「현재」를 붙인다.
    let currentTermID: Int64?

    /// 「아직 못 받았다」·「받았다」·「받아 봤더니 한 줄도 없다」·「실패했다」를 구분한다.
    enum LoadState: Equatable { case loading, ready, empty, failed }

    @State private var entries: [ServerTermHistoryEntry] = []
    @State private var state: LoadState = .loading

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                switch state {
                case .loading:
                    MoyeoEmptyStateView(
                        message: MoyeoEmptyText.loading,
                        accessibilityIdentifier: "terms.history.loading"
                    )
                case .failed:
                    MoyeoSectionRetryNotice(
                        message: "지난 버전을 불러오지 못했어요.",
                        identifier: "terms.history"
                    ) {
                        Task { await load(force: true) }
                    }
                case .empty:
                    // 서버가 한 줄도 주지 않았을 때만 여기로 온다. 판본이 하나뿐인 것은
                    // 빈 상태가 아니라 **정상**이다 (결정 ① — 지금은 각 약관의 판본이 하나뿐이다).
                    MoyeoEmptyStateView(
                        message: "등록된 판본이 없어요.",
                        accessibilityIdentifier: "terms.history.empty"
                    )
                case .ready:
                    ForEach(entries) { entry in
                        row(for: entry)
                    }
                    Text("지난 판본은 목록으로만 남아 있어요. 본문은 현재 판본만 열 수 있어요.")
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .navigationTitle("지난 버전")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .accessibilityIdentifier("screen.terms.history.\(kind.rawValue)")
    }

    /// 현재 판본인지. 상세가 받아 둔 id 를 모르면 **아무 줄도 현재라고 하지 않는다.**
    private func isCurrent(_ entry: ServerTermHistoryEntry) -> Bool {
        currentTermID == entry.termId
    }

    @ViewBuilder private func row(for entry: ServerTermHistoryEntry) -> some View {
        if isCurrent(entry) {
            // 현재 판본만 본문이 열린다 — 여기만 누를 수 있다.
            NavigationLink {
                LegalDocumentDetailView(kind: kind, entry: .settings, serverTermID: entry.termId)
            } label: {
                rowLabel(for: entry, showsChevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("terms.history.row.\(entry.termId)")
        } else {
            rowLabel(for: entry, showsChevron: false)
                .accessibilityIdentifier("terms.history.row.\(entry.termId)")
        }
    }

    private func rowLabel(for entry: ServerTermHistoryEntry, showsChevron: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(entry.version)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.ink)
                        .monospacedDigit()
                    if isCurrent(entry) {
                        Text("현재")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(MoyeoTheme.forest)
                            .padding(.horizontal, 8)
                            .frame(height: 21)
                            .background(MoyeoTheme.leaf)
                            .clipShape(Capsule())
                    }
                }
                Text(entry.title)
                    .font(.caption)
                    .foregroundStyle(MoyeoTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MoyeoTheme.muted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoyeoTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    private func load(force: Bool = false) async {
        // 약관은 공개 엔드포인트다 — 세션이 없어도 받는다.
        guard MoyeoServerSync.allowsPublicEndpoints else {
            state = .failed
            return
        }
        guard force || entries.isEmpty else { return }
        state = .loading
        do {
            let received = try await TermsAPIClient.shared.termHistory(code: kind.serverCode)
            entries = received
            state = received.isEmpty ? .empty : .ready
        } catch {
            entries = []
            state = .failed
        }
    }
}
