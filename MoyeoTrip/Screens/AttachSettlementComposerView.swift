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
    /// 나눌 인원. **첫 값을 지어내지 않는다** — 방의 실제 참여 인원에서 온다.
    /// 예전에는 `2` 로 박아 두고 서버를 아예 부르지 않아, 참가자가 3명인 방에서도 2명으로 나눴다
    /// (TC EXTRA-008). 웹은 처음부터 방 인원을 읽고 있었다.
    @State private var people: Int?
    /// 방 인원을 못 받았을 때 그 자리에 적는 말. 조용히 어떤 숫자를 채워 넣지 않는다.
    @State private var peopleNotice: String?
    @State private var note = ""

    /// 서버 `CreateSettlementMemoRequest` 와 같은 한도.
    private static let memoLimit = 1000
    /// 하한은 **2** 다 — 혼자 나눌 정산은 없다. 예전에는 iOS 만 1 이라 안드·웹과 어긋났다.
    private static let peopleRange = 2...50

    /// 총 금액은 **9자리까지만** 센다. 더 길면 `Int` 변환이 nil 이 되어 조용히 0원이 됐다.
    private static let totalDigitLimit = 9

    private var totalDigits: String {
        String(totalText.filter(\.isNumber).prefix(Self.totalDigitLimit))
    }

    private var total: Int {
        Int(totalDigits) ?? 0
    }

    /// 입력한 글자와 계산에 쓴 숫자가 다르면 **무엇을 뺐는지 칸 아래에 적는다.**
    /// 예전에는 「1,234.56」을 붙여 넣으면 화면은 그대로 두고 계산만 `123456원` 으로
    /// 말없이 바뀌어, 보이는 총액과 1인당 금액이 어긋났다 (IOS-F72).
    private var totalAdjustmentNotice: String? {
        let typed = totalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return nil }
        let digits = totalDigits
        guard digits.isEmpty == false else { return "숫자를 찾지 못했어요. 총 금액을 숫자로 적어주세요." }
        guard digits != typed else { return nil }
        if typed.filter(\.isNumber).count > Self.totalDigitLimit {
            return "\(Self.totalDigitLimit)자리까지만 셀 수 있어요 — \(Self.won(total))원으로 봤어요."
        }
        return "숫자만 세서 \(Self.won(total))원으로 봤어요. 쉼표·소수점·단위는 빼고 계산해요."
    }

    /// 1인당 금액 — 10원 단위 올림 (R4). 인원을 아직 모르면 계산하지 않는다.
    private var eachAmount: Int? {
        guard total > 0, let people, people > 0 else { return nil }
        return Int((Double(total) / Double(people) / 10).rounded(.up)) * 10
    }

    private var canSend: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && eachAmount != nil
            && !sendState.isSending
    }

    /// 방의 실제 참여 인원을 읽어 첫 값으로 쓴다. 사용자가 이미 고쳤으면 덮어쓰지 않는다.
    private func loadRoomPeople() async {
        guard people == nil else { return }
        guard let list = try? await ChatRoomContentAPIClient.shared.members(roomID: roomID) else {
            peopleNotice = "방 인원을 확인하지 못했어요. 나눌 인원을 직접 정해 주세요."
            return
        }
        peopleNotice = nil
        let count = list.participantCount > 0 ? list.participantCount : list.members.count
        guard count > 0 else {
            peopleNotice = "방 인원을 확인하지 못했어요. 나눌 인원을 직접 정해 주세요."
            return
        }
        people = max(Self.peopleRange.lowerBound, min(Self.peopleRange.upperBound, count))
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
            AttachFieldLabel(text: "무엇을 정산하나요", isRequired: true, isFirst: true)
            AttachTextField(
                placeholder: "예: 점심 · 달기약수탕 백숙",
                text: $subject,
                identifier: "attachSettlement.subject"
            )

            amountRow
            perPersonCard

            AttachFieldLabel(text: "남길 말 (선택)").padding(.top, 18)
            noteEditor

            // 안내 한 줄은 **memo 본문에 넣지 않는다** — 서버로 나가는 값은 그대로 두고 화면에서만 읽힌다.
            // 여기는 메모를 **올리는 사람** 화면이라 신고 버튼을 두지 않는다 — 자기 자신은 신고할 수
            // 없다(서버 400 `40045`). 신고 진입점은 받는 사람이 금액을 보는 자리, 즉 채팅방 정산 카드다.
            AttachNoteBox(lines: [
                "모여트립은 송금을 하지 않아요. 실제 정산은 각자 하셔야 해요.",
                MoyeoSettlementReport.guide,
                "계좌번호는 아무나 볼 수 있으니 꼭 필요할 때만 남겨주세요."
            ])
        }
        .task { await loadRoomPeople() }
        .attachComposerFailureAlert(sendState, dismissesOnSuccess: true)
    }

    private var amountRow: some View {
        VStack(alignment: .leading, spacing: 0) {
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
            if let peopleNotice {
                Text(peopleNotice)
                    .font(MoyeoTypography.tinyMeta)
                    .foregroundStyle(MoyeoTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
                    .accessibilityIdentifier("attachSettlement.peopleNotice")
            }
            if let notice = totalAdjustmentNotice {
                Text(notice)
                    .font(MoyeoTypography.tinyMeta)
                    .foregroundStyle(MoyeoTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
                    .accessibilityIdentifier("attachSettlement.totalNotice")
            }
        }
        .padding(.top, 18)
    }

    private var stepper: some View {
        HStack(spacing: 0) {
            Button {
                if let people { self.people = max(Self.peopleRange.lowerBound, people - 1) }
            } label: {
                Image(systemName: "minus").font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MoyeoTheme.muted).frame(width: 32, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(people == nil)
            .accessibilityLabel("인원 줄이기")
            // 아직 방 인원을 못 받았으면 **숫자를 지어내지 않는다.**
            Text(people.map(String.init) ?? "-")
                .font(.subheadline.weight(.heavy))
                .monospacedDigit()
                .frame(maxWidth: .infinity)
            Button {
                people = min(Self.peopleRange.upperBound, (people ?? Self.peopleRange.lowerBound - 1) + 1)
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
                // 인원을 아직 모르면 금액도 아는 척하지 않는다.
                Text(eachAmount.map { "\(Self.won($0))원" } ?? "-")
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
        // `TextEditor` 에는 placeholder 가 없다 — 겹쳐 그린다.
        // 예전에는 안내 글자가 없어 iOS 만 빈 상자였다 (20-2e, 2026-09-09).
        TextEditor(text: $note)
            .font(.subheadline)
            .scrollContentBackground(.hidden)
            .overlay(alignment: .topLeading) {
                if note.isEmpty {
                    Text("예: 계좌는 채팅방에 따로 남길게요.")
                        .font(.subheadline)
                        .foregroundStyle(MoyeoTheme.text400)
                        .padding(.horizontal, 5)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
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
            "\(Self.won(total))원 / \(people ?? 0)명 = 1인 \(Self.won(eachAmount ?? 0))원 (10원 단위 올림)"
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
