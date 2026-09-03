//
//  AttachPollComposerView.swift
//  MoyeoTrip
//
//  20-2d 투표 만들기. 정본 `ATTACH-COMPOSER-CANON.md` R1·R5.
//
//  항목은 2~5개다 — 2개에서 삭제가 잠기고(투표가 성립하지 않는다), 5개에서 추가가 잠긴다.
//  **익명이 기본값**이다. 서버 검증(`CreateChatPollRequest`)과 같은 한도를 화면에서 먼저 막는다.
//

import SwiftUI

struct AttachPollComposerView: View {
    let roomID: Int64
    let onSent: () -> Void

    @StateObject private var sendState = AttachComposerSendState()
    @State private var question = ""
    /// 시작은 빈 항목 2개다 — 예시 문구를 채워 넣으면 그대로 올라간다.
    @State private var options = ["", ""]
    @State private var isAnonymous = true

    /// 서버 한도: 질문 200자 · 선택지 2~5개 · 각 100자.
    private static let questionLimit = 200
    private static let optionLimit = 100

    private var filledOptions: [String] {
        options.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private var canSend: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && filledOptions.count == options.count
            && ServerChatShareLimits.pollOptionRange.contains(filledOptions.count)
            && Set(filledOptions).count == filledOptions.count
            && !sendState.isSending
    }

    var body: some View {
        AttachComposerFrame(
            title: "투표 만들기",
            hint: "항목은 2~5개까지예요.",
            cta: "투표 올리기",
            isCTAEnabled: canSend,
            identifier: "attachPoll",
            onSend: send
        ) {
            AttachFieldLabel(text: "무엇을 물어볼까요", isRequired: true)
            AttachTextField(placeholder: "예) 점심 뭐 먹을까요?", text: $question, identifier: "attachPoll.question")
                .onChange(of: question) { _, value in
                    if value.count > Self.questionLimit {
                        question = String(value.prefix(Self.questionLimit))
                    }
                }

            optionsSection
            togglesSection

            AttachNoteBox(lines: [
                "투표는 만든 사람이 언제든 마감할 수 있어요.",
                "마감하면 결과가 채팅방 카드에 그대로 남아요."
            ])
        }
        .attachComposerFailureAlert(sendState)
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            AttachFieldLabel(text: "선택 항목", isRequired: true)
            VStack(spacing: 8) {
                ForEach(options.indices, id: \.self) { index in
                    optionRow(index)
                }
            }
            addOptionButton
        }
        .padding(.top, 18)
    }

    private func optionRow(_ index: Int) -> some View {
        HStack(spacing: 9) {
            // 투표 카드에서 보일 모양 그대로 — 서버 투표는 한 사람이 하나만 고른다
            Circle()
                .stroke(MoyeoTheme.line, lineWidth: 1.6)
                .frame(width: 18, height: 18)
            TextField("항목 \(index + 1)", text: optionBinding(index))
                .font(.subheadline)
                .accessibilityIdentifier("attachPoll.option.\(index)")
            Button {
                options.remove(at: index)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MoyeoTheme.muted)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            // 2개까지는 지울 수 없다 — 투표가 성립하지 않는다 (R5)
            .disabled(options.count <= ServerChatShareLimits.pollOptionRange.lowerBound)
            .opacity(options.count <= ServerChatShareLimits.pollOptionRange.lowerBound ? 0.3 : 1)
            .accessibilityLabel("항목 \(index + 1) 삭제")
            .accessibilityIdentifier("attachPoll.option.remove.\(index)")
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(MoyeoTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func optionBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { options.indices.contains(index) ? options[index] : "" },
            set: { value in
                guard options.indices.contains(index) else { return }
                options[index] = String(value.prefix(Self.optionLimit))
            }
        )
    }

    private var addOptionButton: some View {
        let isFull = options.count >= ServerChatShareLimits.pollOptionRange.upperBound
        return Button {
            options.append("")
        } label: {
            Label(
                isFull ? "항목은 5개까지예요" : "항목 추가",
                systemImage: "plus"
            )
            .font(.caption.weight(.bold))
            .foregroundStyle(isFull ? MoyeoTheme.text400 : MoyeoTheme.forest)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(MoyeoTheme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
        }
        .buttonStyle(.plain)
        .disabled(isFull)
        .padding(.top, 8)
        .accessibilityIdentifier("attachPoll.addOption")
    }

    /// 기획의 "여러 개 고르기"는 두지 않는다 — 서버 `CreateChatPollRequest` 에 대응 필드가 없어
    /// 켜도 아무 데도 가지 않는다 (NO-MOCK-CANON R3 · §4 BE 요청 대상).
    private var togglesSection: some View {
        VStack(spacing: 0) {
            AttachToggleRow(
                label: "익명 투표",
                desc: "누가 무엇을 골랐는지 아무도 못 봐요. 결과 숫자만 보여요.",
                isOn: $isAnonymous,
                identifier: "attachPoll.anonymous"
            )
        }
        .padding(.top, 8)
        .overlay(alignment: .top) { Rectangle().fill(MoyeoTheme.softLine).frame(height: 1) }
    }

    private func send() {
        let question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let options = filledOptions
        sendState.send(fallbackMessage: "투표를 올리지 못했어요.") {
            _ = try await ChatRoomWriteAPIClient.shared.createPoll(
                roomID: roomID,
                question: question,
                options: options,
                anonymous: isAnonymous
            )
        } onSuccess: { onSent() }
    }
}
