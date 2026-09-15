//
//  AttachComposerFrame.swift
//  MoyeoTrip
//
//  20-2 첨부 메뉴에서 이어지는 작성 화면 6종(20-2a~20-2f)의 공통 골격.
//  정본: `docs/alignment/ATTACH-COMPOSER-CANON.md` R1 —
//  헤더(뒤로 + 가운데 제목) · 안내 한 줄 · 스크롤 본문 · **하단 고정 CTA 한 개**.
//
//  6종이 제각각이면 같은 시트에서 나온 화면으로 안 읽힌다. 기획의 `AttachFrame` 이 그 골격이다.
//

import Combine
import SwiftUI

/// 20-2a~20-2f 공통 뼈대.
struct AttachComposerFrame<Content: View>: View {
    let title: String
    /// 헤더 밑 한 줄 안내. 비면 그 줄을 그리지 않는다.
    var hint: String = ""
    let cta: String
    var isCTAEnabled = true
    /// CTA 바로 위에 띄우는 경고 한 줄. 비면 그 줄을 그리지 않는다.
    ///
    /// 본문 끝에 두면 스크롤 밖으로 밀려 **왜 저장이 막혔는지 보이지 않는다**
    /// — 실제로 화면(874pt) 밖 y≈997pt 에 떠서 못 읽었다 (IOS-F125, 2026-09-13).
    var warning: String = ""
    var identifier: String
    let onSend: () -> Void
    @ViewBuilder var content: () -> Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            if !hint.isEmpty {
                Text(hint)
                    .font(MoyeoTypography.tinyMeta)
                    .foregroundStyle(MoyeoTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(MoyeoTheme.softLine).frame(height: 1)
                    }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        // 바를 감추면 UIKit 이 엣지 스와이프를 스스로 끈다. 탭 루트에서 한 번 살려 둔 것이
        // **push 될 때마다 다시 꺼지므로** 이 화면들에서도 각각 되살린다 (TC NAV-017).
        .moyeoBackSwipeEnabled()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                if !warning.isEmpty {
                    Text(warning)
                        .font(MoyeoTypography.tinyMeta)
                        .foregroundStyle(MoyeoTheme.dangerRed)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("\(identifier).warning")
                }
                AuthPrimaryButton(title: cta, accessibilityIdentifier: "\(identifier).send", action: onSend)
                    .disabled(!isCTAEnabled)
            }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 28)
                .background(MoyeoTheme.card)
                .overlay(alignment: .top) {
                    Rectangle().fill(MoyeoTheme.softLine).frame(height: 1)
                }
        }
        .accessibilityIdentifier("screen.\(identifier)")
    }

    private var header: some View {
        ZStack {
            Text(title)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)
            HStack {
                Button(action: dismiss.callAsFunction) {
                    // NAV-017 · ENV-009 — 44x44 틀은 있었지만 `contentShape` 가 없어
                    // 실제로는 화살표 그림(9x14pt)에만 반응했다. 그림 크기는 그대로 둔다.
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(MoyeoTheme.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로")
                Spacer(minLength: 0)
            }
        }
        .frame(height: 56)
    }
}

/// 작성 화면마다 반복되는 작은 제목 (기획 `FieldLabel`).
struct AttachFieldLabel: View {
    let text: String
    var isRequired = false
    /// 화면의 **첫 칸**이면 위 여백을 주지 않는다 — 프레임이 이미 `.padding(.top, 16)` 을 준다.
    var isFirst = false

    var body: some View {
        HStack(spacing: 3) {
            Text(text)
            if isRequired {
                Text("*").foregroundStyle(MoyeoTheme.coral)
            }
        }
        .font(.caption.weight(.heavy))
        .foregroundStyle(MoyeoTheme.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        // 라벨은 **새 칸이 시작한다**는 표시다. 예전에는 아래 여백(8)만 있고 위가 0 이라,
        // 앞 칸의 힌트 줄과 다음 라벨이 딱 붙어 한 덩어리로 읽혔다
        // (사용자 지적 2026-09-12 — 「뷰들의 위아래로 너무 딱붙어 있다」).
        // 프레임의 content VStack 이 `spacing: 0` 이라 여백을 줄 곳이 여기뿐이다.
        .padding(.top, isFirst ? 0 : 20)
        .padding(.bottom, 8)
    }
}

/// 켜고 끄는 줄 — 익명·복수선택·상단 고정이 모두 같은 모양을 쓴다 (기획 `ToggleRow`).
struct AttachToggleRow: View {
    let label: String
    var desc: String = ""
    @Binding var isOn: Bool
    var identifier: String

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MoyeoTheme.ink)
                if !desc.isEmpty {
                    Text(desc)
                        .font(MoyeoTypography.tinyMeta)
                        .foregroundStyle(MoyeoTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(MoyeoTheme.forest)
        .padding(.vertical, 10)
        .accessibilityIdentifier(identifier)
    }
}

/// "이건 이렇게 동작해요" 안내 상자 (기획 `NoteBox`).
struct AttachNoteBox: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(MoyeoTheme.muted)
                        .frame(width: 4, height: 4)
                        .padding(.top, 7)
                    Text(line)
                        .font(MoyeoTypography.tinyMeta)
                        .foregroundStyle(MoyeoTheme.text700)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(MoyeoTheme.subtleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.top, 16)
    }
}

/// 한 줄 입력칸 — 6종이 같은 테두리·높이를 쓴다.
struct AttachTextField: View {
    let placeholder: String
    @Binding var text: String
    var identifier: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.subheadline)
            .foregroundStyle(MoyeoTheme.ink)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(MoyeoTheme.card)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityIdentifier(identifier)
    }
}

/// 20-2 작성 화면이 서버 전송 결과를 알리는 방식.
/// 실패하면 화면을 닫지 않고 이유만 알린다 — 보낸 것처럼 보이게 하지 않는다.
@MainActor
final class AttachComposerSendState: ObservableObject {
    @Published var isSending = false
    @Published var failureMessage: String?
    /// 한 번이라도 성공했는지. **성공하면 작성 화면을 닫는다.**
    ///
    /// 예전에는 성공해도 화면이 그대로 남아, 보낸 줄 모른 사용자가 다시 눌러
    /// 같은 카드를 두 번 세 번 올렸다 — 2026-09-13 기기 확인에서 공지 3건이 실제로 쌓였다
    /// (IOS-F71). `isSending` 가드는 **보내는 동안**만 막아서 이 경우를 못 막는다.
    @Published var didSend = false

    var isFailureShown: Binding<Bool> {
        Binding(get: { self.failureMessage != nil }, set: { if !$0 { self.failureMessage = nil } })
    }

    /// 서버 호출을 감싼다. 성공하면 `onSuccess`, 실패하면 서버 문구를 그대로 보여준다.
    func send(
        fallbackMessage: String,
        work: @escaping () async throws -> Void,
        onSuccess: @escaping () -> Void
    ) {
        guard !isSending, !didSend else { return }
        isSending = true
        Task {
            do {
                try await work()
                isSending = false
                didSend = true
                onSuccess()
            } catch {
                isSending = false
                failureMessage = error.moyeoUserMessage(fallback: fallbackMessage)
            }
        }
    }
}

/// 성공하면 **작성 화면을 스스로 닫는다.** 닫는 일을 부모(첨부 메뉴)에 맡기면
/// 그 위에 쌓인 작성 화면이 남아 중복 전송이 난다 (IOS-F71).
private struct AttachComposerSendOutcome: ViewModifier {
    @ObservedObject var state: AttachComposerSendState
    /// 성공하면 이 화면을 닫을지. **보내고 끝나는 화면만** 참이다 —
    /// 결과 화면을 이어 그리는 곳(27-2 여행 확정)이나 목록에 머무는 곳(23-1a 댓글 수정)은 거짓이다.
    let dismissesOnSuccess: Bool
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .alert("보내기", isPresented: state.isFailureShown) {
                Button("확인", role: .cancel) { state.failureMessage = nil }
            } message: {
                Text(state.failureMessage ?? "")
            }
            .onChange(of: state.didSend) { _, didSend in
                guard didSend, dismissesOnSuccess else { return }
                dismiss()
            }
    }
}

extension View {
    /// 같은 실패 알림을 쓴다. `dismissesOnSuccess` 를 켜면 성공 후 **스스로 닫는다**
    /// — 닫는 일을 부모에 맡기면 그 위에 쌓인 작성 화면이 남아 중복 전송이 난다 (IOS-F71).
    func attachComposerFailureAlert(
        _ state: AttachComposerSendState,
        dismissesOnSuccess: Bool = false
    ) -> some View {
        modifier(AttachComposerSendOutcome(state: state, dismissesOnSuccess: dismissesOnSuccess))
    }
}

/// 20-2 타일 → 작성 화면 6종을 잇는 분기. 방(roomID)이 없으면 어떤 화면도 열지 않는다.
struct AttachComposerDestination: View {
    let kind: ChatAttachmentMenuView.AttachmentKind
    let roomID: Int64
    let onSent: () -> Void

    var body: some View {
        switch kind {
        case .photo:
            AttachPhotoComposerView(roomID: roomID, onSent: onSent)
        case .place:
            AttachPlaceComposerView(roomID: roomID, onSent: onSent)
        case .map:
            AttachMapComposerView(roomID: roomID, onSent: onSent)
        case .poll:
            AttachPollComposerView(roomID: roomID, onSent: onSent)
        case .settlement:
            AttachSettlementComposerView(roomID: roomID, onSent: onSent)
        case .memo:
            AttachNoticeComposerView(roomID: roomID, onSent: onSent)
        }
    }
}
