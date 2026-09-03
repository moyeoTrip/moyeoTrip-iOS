//
//  TripStatusView.swift
//  MoyeoTrip
//
//  18-4 여행 확정 / 불발 (호스트). 정본 `ATTACH-COMPOSER-CANON.md` §6-1.
//
//  **서비스에서 가장 중요한 전환인데 누르는 화면이 없었다.** 참가자가 결과를 보는
//  20-4 여행 확정 모먼트는 있는데, 호스트가 그 버튼을 누르는 화면이 없어 확정이
//  사용자 조작 없이 저절로 일어나는 것처럼 그려져 있었다.
//
//  근거: `POST /api/v1/chat-rooms/{roomId}/status` `{ "status": "CONFIRMED" | "CANCELLED" }`
//  서버는 `RECRUITING` 방만 받는다 — `COMPLETED` 는 400(40000)이다.
//
//  인원·최소 인원은 `GET /api/v1/chat-rooms/{roomId}` 가 준다. 못 받으면 값을 지어내지 않고
//  빈 상태를 그리고 CTA 를 잠근다 (NO-MOCK-CANON R1).
//

import SwiftUI

struct TripStatusView: View {
    let roomID: Int64

    @Environment(\.dismiss) private var dismiss
    @State private var pick: ServerChatRoomTargetStatus = .confirmed
    @State private var detail: ServerChatRoomDetail?
    @State private var loadState: TripCompanionsState = .loading
    /// 불발은 되돌릴 수 없다 — 확인 시트를 거친 뒤에만 서버를 부른다.
    @State private var showsCancelConfirmation = false
    @StateObject private var sendState = AttachComposerSendState()

    private var approved: Int { detail?.participantCount ?? 0 }
    private var minimum: Int { detail?.minimumParticipants ?? 0 }
    /// 최소 인원을 모르는 동안에는 확정을 잠근다 — 모르는 채로 확정시키지 않는다.
    private var hasEnoughMembers: Bool { minimum > 0 && approved >= minimum }

    var body: some View {
        AttachComposerFrame(
            title: "여행 확정하기",
            cta: primaryTitle,
            isCTAEnabled: isPrimaryEnabled,
            identifier: "tripStatus",
            onSend: primaryAction
        ) {
            headcountSection

            AttachFieldLabel(text: "어떻게 할까요?").padding(.top, 20)

            TripStatusOptionRow(
                icon: "checkmark",
                title: "여행 확정하기",
                desc: "더 이상 신청을 받지 않고 이 인원으로 떠나요. 동행자 모두에게 알림이 가요.",
                isSelected: pick == .confirmed,
                isDanger: false,
                identifier: "tripStatus.option.confirmed"
            ) { pick = .confirmed }

            TripStatusOptionRow(
                icon: "xmark",
                title: "모집 불발 처리",
                desc: "이번 여행을 접어요. 승인된 동행자와 대기 중인 신청자 모두에게 알림이 가요.",
                isSelected: pick == .cancelled,
                isDanger: true,
                identifier: "tripStatus.option.cancelled"
            ) { pick = .cancelled }

            AttachNoteBox(lines: noteLines)
        }
        .overlay {
            if showsCancelConfirmation {
                MoyeoConfirmSheet(
                    title: "이번 모집을 접을까요?",
                    subject: detail?.title ?? "",
                    lines: [
                        "불발 처리하면 채팅방이 닫혀요. 되돌릴 수 없어요.",
                        "같은 코스로 다시 모집을 열 수는 있어요.",
                        "이미 나눈 대화는 사라져요."
                    ],
                    cancelTitle: "그대로 둘게요",
                    confirmTitle: "모집 불발 처리",
                    isDanger: true,
                    isBusy: sendState.isSending,
                    identifier: "tripStatusCancel",
                    onCancel: { showsCancelConfirmation = false },
                    onConfirm: { showsCancelConfirmation = false; submit(.cancelled) }
                )
            }
        }
        .task { await load() }
        .attachComposerFailureAlert(sendState)
    }

    /// 지금 몇 명인지 먼저 — 확정할지 접을지를 정하는 유일한 근거다.
    @ViewBuilder
    private var headcountSection: some View {
        switch loadState {
        case .loading:
            MoyeoEmptyStateView(
                message: MoyeoEmptyText.loading,
                accessibilityIdentifier: "tripStatus.state"
            )
        case .failed:
            MoyeoEmptyStateView(
                message: MoyeoEmptyText.loadFailed,
                onRetry: { Task { await reload() } },
                accessibilityIdentifier: "tripStatus.state"
            )
        case .empty:
            MoyeoEmptyStateView(
                message: MoyeoEmptyText.noRecruitments,
                accessibilityIdentifier: "tripStatus.state"
            )
        case .ready:
            TripStatusHeadcountCard(
                approved: approved,
                minimum: minimum,
                title: detail?.title ?? "",
                hasEnoughMembers: hasEnoughMembers
            )
        }
    }

    private var noteLines: [String] {
        pick == .confirmed
            ? [
                "확정하면 모집이 닫혀요. 다시 열 수 없어요.",
                "대기 중인 신청자에게는 마감 알림이 가요.",
                "여행 날이 되면 채팅방에 진행 위젯이 열려요."
            ]
            : [
                "불발 처리하면 채팅방이 닫혀요. 되돌릴 수 없어요.",
                "같은 코스로 다시 모집을 열 수는 있어요.",
                "이미 나눈 대화는 사라져요."
            ]
    }

    private var primaryTitle: String {
        if pick == .cancelled { return "모집 불발 처리" }
        return hasEnoughMembers ? "여행 확정하기" : "최소 \(minimum)명이 필요해요"
    }

    private var isPrimaryEnabled: Bool {
        guard loadState == .ready, !sendState.isSending else { return false }
        return pick == .cancelled || hasEnoughMembers
    }

    /// 확정은 바로 보낸다(늘리는 쪽이다). 불발은 되돌릴 수 없어 확인 시트를 먼저 띄운다.
    private func primaryAction() {
        if pick == .cancelled {
            showsCancelConfirmation = true
        } else {
            submit(.confirmed)
        }
    }

    private func submit(_ status: ServerChatRoomTargetStatus) {
        sendState.send(fallbackMessage: "여행 상태를 바꾸지 못했어요.") {
            try await ChatRoomWriteAPIClient.shared.changeStatus(roomID: roomID, status: status)
        } onSuccess: {
            dismiss()
        }
    }

    private func load() async {
        guard loadState == .loading, detail == nil else { return }
        await reload()
    }

    private func reload() async {
        loadState = .loading
        guard MoyeoServerSync.isEnabled else {
            loadState = .empty
            return
        }
        guard let loaded = try? await ChatRoomAPIClient.shared.detail(roomID: roomID) else {
            loadState = .failed
            return
        }
        detail = loaded
        loadState = .ready
    }
}

/// 승인된 동행자 수 카드. 서버가 준 인원만 적는다.
private struct TripStatusHeadcountCard: View {
    let approved: Int
    let minimum: Int
    let title: String
    let hasEnoughMembers: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(MoyeoTheme.forest)
            VStack(alignment: .leading, spacing: 3) {
                Text("승인된 동행자 \(approved)명")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                Text(subtitle)
                    .font(MoyeoTypography.tinyMeta)
                    .monospacedDigit()
                    .foregroundStyle(MoyeoTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Text(hasEnoughMembers ? "확정 가능" : "인원 부족")
                .font(.caption2.weight(.bold))
                .foregroundStyle(hasEnoughMembers ? MoyeoTheme.forest : MoyeoTheme.muted)
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(hasEnoughMembers ? MoyeoTheme.leaf : MoyeoTheme.subtleBackground)
                .clipShape(Capsule())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoyeoTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MoyeoTheme.softLine))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityIdentifier("tripStatus.headcount")
    }

    private var subtitle: String {
        // 서버가 최소 인원을 안 주면 그 줄을 지어내지 않고 모임 이름만 남긴다.
        [minimum > 0 ? "최소 인원 \(minimum)명" : "", title]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

/// 확정 / 불발 두 갈래. 고른 쪽만 테두리와 색이 살아난다.
private struct TripStatusOptionRow: View {
    let icon: String
    let title: String
    let desc: String
    let isSelected: Bool
    let isDanger: Bool
    let identifier: String
    let action: () -> Void

    private var accent: Color { isDanger ? MoyeoTheme.dangerRed : MoyeoTheme.forest }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 40, height: 40)
                    .background(isSelected ? MoyeoTheme.card : MoyeoTheme.subtleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(isDanger ? MoyeoTheme.dangerRed : MoyeoTheme.ink)
                    Text(desc)
                        .font(MoyeoTypography.tinyMeta)
                        .foregroundStyle(MoyeoTheme.muted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(accent)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? (isDanger ? MoyeoTheme.subtleBackground : MoyeoTheme.leaf) : MoyeoTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? accent : MoyeoTheme.softLine, lineWidth: isSelected ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 10)
        .accessibilityIdentifier(identifier)
    }
}
