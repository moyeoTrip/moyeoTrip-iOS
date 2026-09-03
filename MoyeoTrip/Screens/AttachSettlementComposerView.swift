//
//  AttachSettlementComposerView.swift
//  MoyeoTrip
//
//  20-2e 정산 메모. 정본 `ATTACH-COMPOSER-CANON.md` R1·R4.
//
//  **송금 기능이 아니다** — 얼마를 어떻게 나눌지 적어두는 메모다.
//  이 구분이 흐려지면 사용자가 앱에서 돈이 오가는 줄 안다.
//  1인당 금액은 입력이 아니라 **계산 결과**이고, 10원 단위 올림이다.
//

import SwiftUI

struct AttachSettlementComposerView: View {
    let roomID: Int64
    let onSent: () -> Void

    @StateObject private var sendState = AttachComposerSendState()
    @State private var subject = ""
    @State private var totalText = ""
    @State private var people = 2
    @State private var note = ""

    /// 서버 `CreateSettlementMemoRequest` 와 같은 한도.
    private static let memoLimit = 1000
    private static let peopleRange = 1...50

    private var total: Int {
        Int(totalText.filter(\.isNumber)) ?? 0
    }

    /// 1인당 금액 — 10원 단위 올림 (R4).
    private var eachAmount: Int {
        guard total > 0, people > 0 else { return 0 }
        return Int((Double(total) / Double(people) / 10).rounded(.up)) * 10
    }

    private var canSend: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && total > 0
            && !sendState.isSending
    }

    var body: some View {
        AttachComposerFrame(
            title: "정산 메모",
            hint: "얼마를 어떻게 나눌지 적어두는 메모예요. 앱에서 돈이 오가지는 않아요.",
            cta: "정산 메모 올리기",
            isCTAEnabled: canSend,
            identifier: "attachSettlement",
            onSend: send
        ) {
            AttachFieldLabel(text: "무엇을 정산하나요", isRequired: true)
            AttachTextField(
                placeholder: "예) 점심 · 달기약수탕 백숙",
                text: $subject,
                identifier: "attachSettlement.subject"
            )

            amountRow
            perPersonCard

            AttachFieldLabel(text: "남길 말 (선택)").padding(.top, 18)
            noteEditor

            AttachNoteBox(lines: [
                "모여트립은 송금을 하지 않아요. 실제 정산은 각자 하셔야 해요.",
                "계좌번호는 아무나 볼 수 있으니 꼭 필요할 때만 남겨주세요."
            ])
        }
        .attachComposerFailureAlert(sendState)
    }

    private var amountRow: some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                AttachFieldLabel(text: "총 금액", isRequired: true)
                HStack(spacing: 4) {
                    TextField("0", text: $totalText)
                        .keyboardType(.numberPad)
                        .font(.subheadline.weight(.heavy))
                        .monospacedDigit()
                        .accessibilityIdentifier("attachSettlement.total")
                    Text("원").font(.subheadline).foregroundStyle(MoyeoTheme.muted)
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(MoyeoTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 0) {
                AttachFieldLabel(text: "나눌 인원", isRequired: true)
                stepper
            }
            .frame(width: 116)
        }
        .padding(.top, 18)
    }

    private var stepper: some View {
        HStack(spacing: 0) {
            Button {
                people = max(Self.peopleRange.lowerBound, people - 1)
            } label: {
                Image(systemName: "minus").font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MoyeoTheme.muted).frame(width: 32, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("인원 줄이기")
            Text("\(people)")
                .font(.subheadline.weight(.heavy))
                .monospacedDigit()
                .frame(maxWidth: .infinity)
            Button {
                people = min(Self.peopleRange.upperBound, people + 1)
            } label: {
                Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MoyeoTheme.forest).frame(width: 32, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("인원 늘리기")
        }
        .frame(height: 44)
        .background(MoyeoTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier("attachSettlement.people")
    }

    /// 사람들이 실제로 궁금해하는 숫자라 크게 보여준다 — 입력이 아니라 계산 결과다.
    private var perPersonCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "wonsign.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(MoyeoTheme.forest)
            VStack(alignment: .leading, spacing: 2) {
                Text("1인당")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MoyeoTheme.brandText)
                Text("\(Self.won(eachAmount))원")
                    .font(MoyeoTypography.font(size: 21, weight: .bold, relativeTo: .title3))
                    .monospacedDigit()
                    .foregroundStyle(MoyeoTheme.brandText)
            }
            Spacer(minLength: 0)
            Text("10원 단위로\n올림했어요")
                .font(MoyeoTypography.tinyMeta)
                .foregroundStyle(MoyeoTheme.muted)
                .multilineTextAlignment(.trailing)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoyeoTheme.leaf)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MoyeoTheme.primary100))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.top, 16)
        .accessibilityIdentifier("attachSettlement.perPerson")
    }

    private var noteEditor: some View {
        TextEditor(text: $note)
            .font(.subheadline)
            .scrollContentBackground(.hidden)
            .padding(8)
            .frame(height: 76)
            .background(MoyeoTheme.card)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityLabel("남길 말")
            .accessibilityIdentifier("attachSettlement.note")
    }

    private static func won(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// 서버는 `memo` 문자열 하나만 받는다 — 화면에서 계산한 줄을 그대로 한 덩어리로 보낸다.
    private var memoText: String {
        var lines = [
            "\(subject.trimmingCharacters(in: .whitespacesAndNewlines))",
            "\(Self.won(total))원 / \(people)명 = 1인 \(Self.won(eachAmount))원 (10원 단위 올림)"
        ]
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty { lines.append(note) }
        lines.append("모여트립은 송금을 하지 않아요. 실제 정산은 각자 하셔야 해요.")
        return String(lines.joined(separator: "\n").prefix(Self.memoLimit))
    }

    private func send() {
        let memo = memoText
        sendState.send(fallbackMessage: "정산 메모를 올리지 못했어요.") {
            _ = try await ChatRoomWriteAPIClient.shared.shareSettlementMemo(roomID: roomID, memo: memo)
        } onSuccess: { onSent() }
    }
}
