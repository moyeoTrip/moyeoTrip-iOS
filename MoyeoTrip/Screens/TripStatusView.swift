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
    /// 서버로 실제 전이가 끝난 상태. nil 이 아니면 결과 화면을 그린다 (IOS-F127).
    @State private var completedStatus: ServerChatRoomTargetStatus?
    @StateObject private var sendState = AttachComposerSendState()

    private var approved: Int { detail?.participantCount ?? 0 }
    private var minimum: Int { detail?.minimumParticipants ?? 0 }
    /// 최소 인원을 모르는 동안에는 확정을 잠근다 — 모르는 채로 확정시키지 않는다.
    private var hasEnoughMembers: Bool { minimum > 0 && approved >= minimum }

    var body: some View {
        if let completedStatus {
            // 전이가 끝났으면 **성공했다고 말한다.** 예전에는 아무 말 없이 모집 관리로 돌아가서
            // 실패한 것처럼 보였다 (IOS-F127). 문구의 근거는 서버가 방금 준 방 상세다.
            resultScreen(completedStatus)
        } else {
            picker
        }
    }

    private var picker: some View {
        AttachComposerFrame(
            title: "여행 확정하기",
            cta: primaryTitle,
            isCTAEnabled: isPrimaryEnabled,
            identifier: "tripStatus",
            onSend: primaryAction
        ) {
            headcountSection

            AttachFieldLabel(text: "어떻게 할까요?", isFirst: true).padding(.top, 20)

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
                    lines: Self.cancelNoteLines,
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

    /// 전이 결과 화면. 서버가 다시 준 상태(`detail.status`)를 그대로 적는다 — 내가 보낸 값이 아니라
    /// 서버가 확인해 준 값이다. CTA 로만 나갈 수 있게 해서, 되돌아간 모집 관리가 새로 읽게 한다.
    private func resultScreen(_ status: ServerChatRoomTargetStatus) -> some View {
        AttachComposerFrame(
            title: status == .confirmed ? "여행을 확정했어요" : "모집을 접었어요",
            cta: "모집 관리로 돌아가기",
            identifier: "tripStatusDone",
            onSend: goBack
        ) {
            TripStatusHeadcountCard(
                approved: approved,
                minimum: minimum,
                title: detail?.title ?? "",
                hasEnoughMembers: hasEnoughMembers
            )
            AttachNoteBox(
                lines: status == .confirmed
                    ? [
                        "이제 새 신청을 받지 않아요. 동행자 모두에게 알림이 갔어요.",
                        "여행 날이 되면 채팅방에 진행 위젯이 열려요."
                    ]
                    : [
                        "채팅방이 닫혀 더는 글을 쓸 수 없어요.",
                        "채팅방은 14일 동안 읽기 전용으로 유지된 후 사라져요.",
                        "같은 코스로 다시 모집을 열 수는 있어요."
                    ]
            )
            .padding(.top, 16)
        }
        .accessibilityIdentifier("screen.tripStatusDone")
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
            : Self.cancelNoteLines
    }

    /// 불발 안내. **서버가 실제로 하는 일**만 적는다 — `ChatRoomService.changeStatus` 가
    /// `ChatRoom.cancel()` 을 불러 상태를 CANCELLED 로 바꾸고(`canChat()` 이 false 가 되어 글을 못 쓴다),
    /// `deletionScheduledDate = 오늘 + 14일` 을 건다. 메시지 읽기는 그대로 되고,
    /// 14일 뒤 `deleteExpiredRooms()` 가 방과 대화를 함께 지운다.
    ///
    /// 예전에는 이 화면이 「이미 나눈 대화는 사라져요」라 하고 18-6 모집 내용 수정은
    /// 「채팅방은 읽기 전용으로 남아요」라고 해서 정반대로 안내했다 (IOS-F128).
    /// 세 표면이 같은 말을 쓰도록 21-x 나가기 확인 문구(`SupportScreens` 의 호스트 문장)와 맞춘다.
    private static let cancelNoteLines = [
        "불발 처리하면 채팅방이 닫혀 더는 글을 쓸 수 없어요. 되돌릴 수 없어요.",
        "같은 코스로 다시 모집을 열 수는 있어요.",
        "채팅방은 14일 동안 읽기 전용으로 유지된 후 사라져요."
    ]

    private var primaryTitle: String {
        if pick == .cancelled { return "모집 불발 처리" }
        return hasEnoughMembers ? "여행 확정하기" : "최소 \(minimum)명이 필요해요"
    }

    private var isPrimaryEnabled: Bool {
        guard loadState == .ready, !sendState.isSending else { return false }
        return pick == .cancelled || hasEnoughMembers
    }

    private func goBack() {
        dismiss()
    }

    /// 확정은 바로 보낸다(늘리는 쪽이다). 불발은 되돌릴 수 없어 확인 시트를 먼저 띄운다.
    private func primaryAction() {
        if pick == .cancelled {
            showsCancelConfirmation = true
        } else {
            submit(.confirmed)
        }
    }

    /// 상태를 바꾼 뒤 **방 상세를 다시 읽는다.** 예전에는 곧바로 `dismiss()` 해서, 돌아온 모집 관리가
    /// 계속 「모집중」으로 보이고 성공 안내도 없었다 — 앱을 다시 켜야 반영됐다 (IOS-F127).
    /// 서버 응답으로 바뀐 상태를 확인한 뒤에 결과 화면을 그린다(내가 바꿨다고 말하지 않는다).
    private func submit(_ status: ServerChatRoomTargetStatus) {
        sendState.send(fallbackMessage: "여행 상태를 바꾸지 못했어요.") {
            do {
                try await ChatRoomWriteAPIClient.shared.changeStatus(roomID: roomID, status: status)
            } catch let error as MoyeoAPIError
                where error.serverCode == MoyeoServerErrorCode.minimumParticipantsNotMet {
                // 인원 미달은 **조건 안내**지 서버 오류가 아니다 (BE-31). CTA 가 미리 잠그지만
                // 화면을 띄운 뒤 누가 나가면 여기로 온다 — 인원을 다시 읽어 카드부터 맞춘다.
                // 서버 `errorMessage` 를 그대로 쓰지 않고 `code` 로 갈라 내 문장을 쓴다(결정 ⑩).
                await reload()
                throw TripStatusBlockedError.notEnoughMembers(minimum: minimum)
            }
        } onSuccess: {
            Task { await confirmApplied(status) }
        }
    }

    /// 서버가 준 상태를 읽어 `completedStatus` 에 담는다. 다시 읽지 못하면 화면을 바꾸지 않고
    /// 실패로 말한다 — 바뀌었는지 모르는 채로 「됐어요」라고 하지 않는다.
    private func confirmApplied(_ status: ServerChatRoomTargetStatus) async {
        guard let loaded = try? await ChatRoomAPIClient.shared.detail(roomID: roomID) else {
            sendState.failureMessage = "상태는 바뀐 것 같은데 다시 읽지 못했어요. 모집 관리에서 확인해 주세요."
            return
        }
        detail = loaded
        loadState = .ready
        completedStatus = status
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
                    // 장식이다. 「확정하기」 쪽 아이콘이 `checkmark` 라서, 고르지도 않은 행이
                    // 보이스오버에 **선택됨**으로 읽혔다 (IOS-F132).
                    .accessibilityHidden(true)
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
                        .accessibilityHidden(true)
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
        // 선택 상태는 **행 하나에** 붙인다. 예전에는 두 행이 동시에 `selected` 로 읽혀,
        // 되돌릴 수 없는 두 조작이 모두 골라진 것처럼 들렸다 (IOS-F132).
        //
        // **2026-09-13 덤프 확인.** `tripStatus.option.confirmed` 에만 `selected` 가 붙고
        // `…cancelled` 에는 안 붙는다 — 이 항목은 이걸로 닫힌다.
        // 다만 장식용 `checkmark` 가 「Selected」라는 시스템 영어 이름으로 트리에 남는다.
        // `children: .ignore` 도 대 봤는데 **버튼 요소가 하나 더 생기고** 이미지는 그대로라
        // 더 나빴다. SwiftUI 가 `Button` 안쪽 요소를 지워 주지 않는 한계다 (잔여는 IOS-F98).
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(identifier)
    }
}

/// 서버가 확정을 막은 까닭. **오류가 아니라 조건 안내다** — 서버가 준 문장 대신
/// `code`(409 `40924`)로 갈라 클라이언트가 쓴 문구를 보여준다 (결정 ⑩ · BE-31).
private enum TripStatusBlockedError: LocalizedError {
    case notEnoughMembers(minimum: Int)

    var errorDescription: String? {
        switch self {
        case .notEnoughMembers(let minimum):
            let head = minimum > 0 ? "최소 출발 인원 \(minimum)명을" : "최소 출발 인원을"
            return "\(head) 채워야 여행을 확정할 수 있어요. 동행자를 더 승인한 뒤 다시 시도해주세요."
        }
    }
}
