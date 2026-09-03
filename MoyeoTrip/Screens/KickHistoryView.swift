//
//  KickHistoryView.swift
//  MoyeoTrip
//
//  13-2 내 강퇴 이력. 정본 `ATTACH-COMPOSER-CANON.md` §6-5.
//
//  13-1 내보내기 안내는 **알림 한 건**을 여는 화면이라, 알림이 사라지면 사유를 다시 볼 길이 없었다.
//
//  근거: `GET /api/v1/chat-rooms/my-kick-histories` (목록)
//        ↔ `GET /api/v1/notifications/{notificationId}/kick-history` (단건 · 13-1 이 쓰는 것)
//

import SwiftUI

struct KickHistoryView: View {
    @State private var histories: [ServerKickHistory]?
    @State private var loadState: TripCompanionsState = .loading

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                content
                Text("내보낸 사유는 호스트가 직접 적은 글이에요. 부당하다고 느끼시면 고객센터로 알려주세요.")
                    .font(MoyeoTypography.tinyMeta)
                    .foregroundStyle(MoyeoTheme.text400)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .navigationTitle("내보내진 기록")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .accessibilityIdentifier("screen.kickHistory")
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .loading:
            MoyeoEmptyStateView(
                message: MoyeoEmptyText.loading,
                accessibilityIdentifier: "kickHistory.state"
            )
        case .failed:
            MoyeoEmptyStateView(
                message: MoyeoEmptyText.loadFailed,
                onRetry: { Task { await reload() } },
                accessibilityIdentifier: "kickHistory.state"
            )
        case .empty:
            MoyeoEmptyStateView(
                message: MoyeoEmptyText.noKickHistories,
                accessibilityIdentifier: "kickHistory.state"
            )
        case .ready:
            ForEach(histories ?? []) { history in
                KickHistoryCard(history: history)
            }
        }
    }

    private func load() async {
        guard loadState == .loading, histories == nil else { return }
        await reload()
    }

    private func reload() async {
        loadState = .loading
        guard MoyeoServerSync.isEnabled else {
            loadState = .empty
            return
        }
        guard let loaded = try? await ChatRoomAPIClient.shared.myKickHistories() else {
            loadState = .failed
            return
        }
        histories = loaded
        loadState = loaded.isEmpty ? .empty : .ready
    }
}

private struct KickHistoryCard: View {
    let history: ServerKickHistory

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(MoyeoTheme.dangerRed)
                Text(history.roomTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MoyeoTheme.ink)
                Spacer(minLength: 0)
                Text(kickedAtText)
                    .font(MoyeoTypography.tinyMeta)
                    .monospacedDigit()
                    .foregroundStyle(MoyeoTheme.text400)
            }
            Text(history.reason)
                .font(.subheadline)
                .foregroundStyle(MoyeoTheme.text700)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoyeoTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MoyeoTheme.softLine))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityIdentifier("kickHistory.\(history.kickHistoryId)")
    }

    /// "2026-08-24T08:06:49" → "2026.08.24"
    private var kickedAtText: String {
        guard let datePart = history.kickedAt.split(separator: "T").first else { return history.kickedAt }
        return datePart.replacingOccurrences(of: "-", with: ".")
    }
}
