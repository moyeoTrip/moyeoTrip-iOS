//
//  RecruitEditFields.swift
//  MoyeoTrip
//
//  18-6 모집 내용 수정의 **날짜·인원·참가비 입력 부품**.
//  예전에는 읽기 전용 줄로만 그려 놓고 필수(*) 표시와 규칙 안내까지 달아
//  아무것도 고칠 수 없었다 (IOS-F114, 2026-09-12). 서버는 이 값들을 모두 받는다.
//
//  `RecruitEditView.swift` 가 500줄 제한에 걸려 이 파일로 나눴다.
//

import SwiftUI

/// 서버가 쓰는 문자열(`2026-10-24` · `09:00:00`)과 `Date` 를 오간다.
/// 화면 표기는 `ServerTripMapper.displayDate` 가 맡고, 여기는 **주고받는 꼴**만 책임진다.
enum RecruitEditDates {
    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = format
        return formatter
    }

    static func date(_ isoDay: String?) -> Date? {
        guard let isoDay, !isoDay.isEmpty else { return nil }
        return formatter("yyyy-MM-dd").date(from: isoDay)
    }

    /// 서버는 `HH:mm:ss` 를 주는데 문서는 `HH:mm` 이라 **양쪽 모두** 받는다.
    static func time(_ isoTime: String?) -> Date? {
        guard let isoTime, !isoTime.isEmpty else { return nil }
        return formatter("HH:mm:ss").date(from: isoTime) ?? formatter("HH:mm").date(from: isoTime)
    }

    static func isoDay(_ date: Date) -> String { formatter("yyyy-MM-dd").string(from: date) }

    static func isoTime(_ date: Date) -> String { formatter("HH:mm:ss").string(from: date) }
}

/// 한 줄짜리 날짜 고르기. 잠긴 줄과 높이·테두리를 맞춰 같은 칸으로 읽히게 한다.
struct RecruitEditDateRow: View {
    let label: String
    @Binding var date: Date
    let hint: String
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DatePicker(label, selection: $date, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: "ko_KR"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .frame(height: 46)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
                .accessibilityIdentifier(identifier)
                .accessibilityLabel(label)
            if !hint.isEmpty {
                Text(hint)
                    .font(MoyeoTypography.tinyMeta)
                    .foregroundStyle(MoyeoTheme.text400)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// 여행 날짜 — 당일치기면 날짜 하나 + 시각 둘, 1박 이상이면 시작·종료 날짜.
struct RecruitEditScheduleFields: View {
    let isDayTrip: Bool
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var dayTripStart: Date
    @Binding var dayTripEnd: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RecruitEditDateRow(
                label: "여행 시작 날짜",
                date: $startDate,
                hint: "",
                identifier: "recruitEdit.startDate"
            )
            if isDayTrip {
                HStack(spacing: 8) {
                    timeBox("시작 시각", $dayTripStart, "recruitEdit.startTime")
                    timeBox("종료 시각", $dayTripEnd, "recruitEdit.endTime")
                }
            } else {
                RecruitEditDateRow(
                    label: "여행 종료 날짜",
                    date: $endDate,
                    hint: "",
                    identifier: "recruitEdit.endDate"
                )
            }
            Text(isDayTrip ? "모집 마감일보다 뒤여야 해요" : "종료 날짜는 시작 날짜보다 뒤여야 해요")
                .font(MoyeoTypography.tinyMeta)
                .foregroundStyle(MoyeoTheme.text400)
        }
    }

    private func timeBox(_ label: String, _ date: Binding<Date>, _ identifier: String) -> some View {
        DatePicker(label, selection: date, displayedComponents: .hourAndMinute)
            .labelsHidden()
            .datePickerStyle(.compact)
            .environment(\.locale, Locale(identifier: "ko_KR"))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .frame(height: 46)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
            .accessibilityIdentifier(identifier)
            .accessibilityLabel(label)
    }
}

/// 최소·최대 인원. 서버가 3~20 명만 받으므로 그 범위를 벗어나게 만들지 않는다.
struct RecruitEditParticipantsFields: View {
    @Binding var minimum: Int
    @Binding var maximum: Int
    let participantCount: Int

    private static let range = 3...20

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            stepper("최소 인원", value: $minimum, identifier: "recruitEdit.minParticipants")
            stepper("최대 인원", value: $maximum, identifier: "recruitEdit.maxParticipants")
            Text("최대 인원은 지금 참여 중인 \(participantCount)명보다 적게 줄일 수 없어요 · 3~20명")
                .font(MoyeoTypography.tinyMeta)
                .foregroundStyle(MoyeoTheme.text400)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func stepper(_ label: String, value: Binding<Int>, identifier: String) -> some View {
        Stepper(value: value, in: Self.range) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MoyeoTheme.text700)
                Spacer()
                Text("\(value.wrappedValue)명")
                    .font(.system(size: 13, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(MoyeoTheme.ink)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
        .accessibilityIdentifier(identifier)
    }
}

/// 금액 입력. 숫자만 남기고 자릿수를 막는다 —
/// 쉼표나 마이너스를 조용히 지우면 사용자가 낸 값과 저장된 값이 달라진다.
struct RecruitEditNumberRow: View {
    @Binding var text: String
    let suffix: String
    let maxDigits: Int
    let hint: String
    let identifier: String
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                TextField("0", text: $text)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .font(.subheadline)
                    .monospacedDigit()
                    .textFieldStyle(.plain)
                    .accessibilityIdentifier(identifier)
                    .focused($isFocused)
                    // 칸을 누르면 **캐럿을 값 끝에 놓는다.** 오른쪽 정렬이라 값 왼쪽의 빈 자리를
                    // 누르면 캐럿이 0번에 놓였고, 그 상태로 `7` 을 치면 `45000` 이 `745000` 이 됐다.
                    // 백스페이스도 지울 글자가 앞에 없어 먹지 않았다 (IOS-F126).
                    // 값을 비웠다 되돌리면 SwiftUI 가 캐럿을 끝으로 옮긴다.
                    .onChange(of: isFocused) { _, focused in
                        guard focused, !text.isEmpty else { return }
                        let restored = text
                        text = ""
                        Task { @MainActor in text = restored }
                    }
                    .onChange(of: text) { _, value in
                        // 숫자만 남기고 자릿수를 막는다. **「0」을 미리 채워 두지 않는다** —
                        // 채워 두면 캐럿이 그 「0」 앞에 놓여 45000 을 치면 450000 이 되고
                        // 백스페이스도 안 먹었다 (IOS-F126). 빈 칸은 placeholder 가 「0」을 보여 주고,
                        // 저장할 때 빈 값은 0 원으로 읽는다.
                        let digits = String(value.filter(\.isNumber).prefix(maxDigits))
                        if digits != value { text = digits }
                    }
                Text(suffix)
                    .font(MoyeoTypography.tinyMeta)
                    .foregroundStyle(MoyeoTheme.text400)
            }
            .padding(.horizontal, 12)
            .frame(height: 46)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))

            Text(hint)
                .font(MoyeoTypography.tinyMeta)
                .foregroundStyle(MoyeoTheme.text400)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
