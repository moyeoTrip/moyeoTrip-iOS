//
//  RecruitmentFieldEditors.swift
//  MoyeoTrip
//
//  17-2 · 17-4 · 17-5 · 15 의 `DesignField` 한 줄을 실제로 고치는 시트.
//
//  예전에는 이 줄들이 `chevron.right` 만 그려 눌릴 것처럼 보였고 **아무 동작이 없었다** —
//  여행 날짜 · 시작/종료 시간 · 모집 마감일 · 나이대 · 집합 시간 · 예상 비용을 고칠 길이
//  화면에 아예 없었다. 값은 `RecruitmentDraft` 에만 쓴다(모집을 실제로 만드는 순간에 서버로 간다).
//

import SwiftUI

/// 17-x 에서 시트로 고치는 항목.
enum RecruitmentFieldEditor: String, Identifiable, Hashable {
    case startDate
    case endDate
    case deadline
    case startTime
    case endTime
    case meetingTime
    case ageRange
    case estimatedCost

    var id: String { rawValue }

    var title: String {
        switch self {
        case .startDate: return "여행 시작 날짜"
        case .endDate: return "여행 종료 날짜"
        case .deadline: return "모집 마감일"
        case .startTime: return "여행 시작 시간"
        case .endTime: return "여행 종료 시간"
        case .meetingTime: return "집합 시간"
        case .ageRange: return "나이대 제한"
        case .estimatedCost: return "예상 1인당 비용"
        }
    }

    /// 날짜 · 시각 · 나이대 · 금액 중 어느 입력기를 그릴지.
    enum Shape {
        case date
        case time
        case ageRange
        case money
    }

    var shape: Shape {
        switch self {
        case .startDate, .endDate, .deadline: return .date
        case .startTime, .endTime, .meetingTime: return .time
        case .ageRange: return .ageRange
        case .estimatedCost: return .money
        }
    }
}

/// 날짜·시각 문자열 ↔ `Date` 변환. 화면 표기는 화면기획의 `2026. 05. 26 (일)` · `08:00` 이고,
/// 서버 전송은 `ServerChatRoomCreateRequestBuilder` 가 이 표기에서 다시 ISO 로 옮긴다.
enum RecruitmentFieldFormat {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy. MM. dd (E)"
        return formatter
    }()

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func date(from text: String?) -> Date? {
        guard let iso = ServerChatRoomCreateRequestBuilder.isoDate(from: text) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: iso)
    }

    static func time(from text: String?) -> Date? {
        guard let iso = ServerChatRoomCreateRequestBuilder.isoTime(from: text) else { return nil }
        return timeFormatter.date(from: iso)
    }

    /// "45,000원" — 0 이면 화면기획처럼 `0원` 이다(빈칸으로 두지 않는다).
    static func money(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let digits = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return "\(digits)원"
    }

    /// 예상 비용은 **9자리까지만** 센다. 더 길면 `Int` 변환이 nil 이 되어 말없이 `0원` 이 됐다.
    /// 정산 메모(`AttachSettlementComposerView`)와 같은 기준이다 (IOS-F72·F39).
    static let amountDigitLimit = 9

    /// 계산에 실제로 쓰는 숫자. 붙여 넣은 「1,234.56」에서 `123456` 을 뽑는 바로 그 값이다.
    static func amountDigits(from text: String) -> String {
        String(text.filter(\.isNumber).prefix(amountDigitLimit))
    }

    static func amount(from text: String) -> Int {
        Int(amountDigits(from: text)) ?? 0
    }

    /// 입력한 글자와 계산에 쓴 숫자가 다르면 **무엇을 뺐는지 적는다.**
    /// 예전에는 「1,234.56」을 붙여 넣으면 화면은 그대로 두고 저장만 `123,456원` 으로
    /// 말없이 바뀌었고, 10자리를 넘기면 아무 말 없이 `0원` 이 됐다 (IOS-F39).
    static func amountAdjustmentNotice(for text: String) -> String? {
        let typed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return nil }
        let digits = amountDigits(from: typed)
        guard !digits.isEmpty else { return "숫자를 찾지 못했어요. 예상 비용을 숫자로 적어주세요." }
        guard digits != typed else { return nil }
        let amount = Int(digits) ?? 0
        if typed.filter(\.isNumber).count > amountDigitLimit {
            return "\(amountDigitLimit)자리까지만 셀 수 있어요 — \(money(amount))으로 봤어요."
        }
        return "숫자만 세서 \(money(amount))으로 봤어요. 쉼표·소수점·단위는 빼고 계산해요."
    }
}

/// 한 항목을 고치는 바텀시트. `저장` 을 눌러야 초안에 반영된다 — 취소하면 그대로다.
struct RecruitmentFieldSheet: View {
    let field: RecruitmentFieldEditor
    @Binding var draft: RecruitmentDraft
    let onClose: () -> Void

    @State private var pickedDate = Date()
    @State private var ageLimited = false
    @State private var minimumAge = RoomConditionAgePolicy.minimum
    @State private var maximumAge = RoomConditionAgePolicy.maximum
    @State private var costText = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            editor
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(20)
        }
        .background(MoyeoTheme.card)
        .onAppear(perform: load)
        // 금액 시트는 숫자 키패드라 Return 이 없다 — 닫을 길을 준다 (IOS-F136).
        .moyeoKeyboardDismissable()
        .accessibilityIdentifier("recruitment.field.\(field.rawValue)")
    }

    private var header: some View {
        HStack {
            Button("취소") { onClose() }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MoyeoTheme.muted)
            Spacer()
            Text(field.title)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)
            Spacer()
            Button("저장") {
                save()
                onClose()
            }
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(MoyeoTheme.forest)
            .accessibilityIdentifier("recruitment.field.save")
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .overlay(alignment: .bottom) { Rectangle().fill(MoyeoTheme.softLine).frame(height: 1) }
    }

    @ViewBuilder
    private var editor: some View {
        switch field.shape {
        case .date:
            // 고를 수 없는 날은 **피커에서 막는다** — 안드로이드 `RecruitmentFlowScreens.kt`
            // 의 `selectable` 과 같은 규칙이다. 예전에는 마감일을 여행 시작일 뒤로 잡아도
            // 아무도 안 막아서, 마지막 「모집 열기」에서 서버 400 으로 튕겼다 (IOS-F141).
            if let range = selectableDates {
                DatePicker("", selection: $pickedDate, in: range, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ko_KR"))
                    .accessibilityIdentifier("recruitment.field.datePicker")
            } else {
                DatePicker("", selection: $pickedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ko_KR"))
                    .accessibilityIdentifier("recruitment.field.datePicker")
            }
        case .time:
            DatePicker("", selection: $pickedDate, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("recruitment.field.timePicker")
        case .ageRange:
            ageRangeEditor
        case .money:
            moneyEditor
        }
    }

    /// 17-4 — 최소·최대 모두 `RoomConditionAgePolicy` 범위 안. 최소가 최대를 넘지 않게 함께 민다.
    private var ageRangeEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 호스트가 정하지 않으면 제한을 걸지 않는다 — 기본은 「제한 없음」이다.
            Picker("나이대 제한", selection: $ageLimited) {
                Text("제한 없음").tag(false)
                Text("직접 정하기").tag(true)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("recruitment.field.ageLimited")
            if !ageLimited {
                Text("나이와 상관없이 누구나 신청할 수 있어요.")
                    .font(.caption)
                    .foregroundStyle(MoyeoTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if ageLimited {
            Stepper(value: $minimumAge, in: RoomConditionAgePolicy.minimum...maximumAge) {
                Text("최소 \(minimumAge)세")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MoyeoTheme.ink)
                    .monospacedDigit()
            }
            .accessibilityIdentifier("recruitment.field.minimumAge")
            Stepper(value: $maximumAge, in: minimumAge...RoomConditionAgePolicy.maximum) {
                Text("최대 \(maximumAge)세")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MoyeoTheme.ink)
                    .monospacedDigit()
            }
            .accessibilityIdentifier("recruitment.field.maximumAge")
            Text("조건에 맞지 않는 사용자에게는 신청 버튼이 비활성으로 보여요.")
                .font(.caption)
                .foregroundStyle(MoyeoTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var moneyEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "wonsign.circle").foregroundStyle(MoyeoTheme.muted)
                TextField("0", text: $costText)
                    .keyboardType(.numberPad)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                    .monospacedDigit()
                Text("원").font(.subheadline.weight(.bold)).foregroundStyle(MoyeoTheme.muted)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(MoyeoTheme.subtleBackground)
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(MoyeoTheme.line))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .accessibilityIdentifier("recruitment.field.costInput")
            if let notice = RecruitmentFieldFormat.amountAdjustmentNotice(for: costText) {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(MoyeoTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("recruitment.field.costNotice")
            }
            Text("신청자가 신청 전에 가장 많이 확인하는 값이에요.")
                .font(.caption)
                .foregroundStyle(MoyeoTheme.muted)
        }
    }

    /// 이 날짜 항목이 고를 수 있는 범위. 범위를 만들 수 없으면(여행 날짜를 아직 못 읽었거나
    /// 이미 출발 3일 전을 지나 고를 날이 하나도 없으면) `nil` 을 돌려 제한 없이 그린다 —
    /// 빈 범위를 `DatePicker` 에 넘기면 앱이 죽는다.
    private var selectableDates: ClosedRange<Date>? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        switch field {
        case .deadline:
            guard let start = RecruitmentFieldFormat.date(from: draft.schedule.startDate),
                  let first = calendar.date(byAdding: .day, value: 1, to: today),
                  // 「출발 3일 전까지만 선택할 수 있어요.」 — 화면에 적힌 규칙 그대로다.
                  let last = calendar.date(byAdding: .day, value: -3, to: calendar.startOfDay(for: start)),
                  first <= last
            else { return nil }
            return first...last
        case .endDate:
            guard let start = RecruitmentFieldFormat.date(from: draft.schedule.startDate),
                  let first = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: start)),
                  let last = calendar.date(byAdding: .year, value: 2, to: today),
                  first <= last
            else { return nil }
            return first...last
        default:
            return nil
        }
    }

    private func load() {
        switch field {
        case .startDate:
            pickedDate = RecruitmentFieldFormat.date(from: draft.schedule.startDate) ?? Date()
        case .endDate:
            pickedDate = RecruitmentFieldFormat.date(from: draft.schedule.endDate)
                ?? RecruitmentFieldFormat.date(from: draft.schedule.startDate) ?? Date()
        case .deadline:
            pickedDate = RecruitmentFieldFormat.date(from: draft.deadline) ?? Date()
        case .startTime:
            pickedDate = RecruitmentFieldFormat.time(from: draft.schedule.startTime) ?? Date()
        case .endTime:
            pickedDate = RecruitmentFieldFormat.time(from: draft.schedule.endTime) ?? Date()
        case .meetingTime:
            pickedDate = RecruitmentFieldFormat.time(from: draft.meeting.meetingTime) ?? Date()
        case .ageRange:
            ageLimited = draft.minimumAge != nil && draft.maximumAge != nil
            minimumAge = draft.minimumAge ?? RoomConditionAgePolicy.minimum
            maximumAge = draft.maximumAge ?? RoomConditionAgePolicy.maximum
        case .estimatedCost:
            let amount = RecruitmentFieldFormat.amount(from: draft.estimatedCost)
            costText = amount == 0 ? "" : "\(amount)"
        }
        // 이미 범위를 벗어난 값(여행 날짜를 나중에 당긴 경우)은 범위 안으로 당겨 둔다.
        if let range = selectableDates {
            pickedDate = min(max(pickedDate, range.lowerBound), range.upperBound)
        }
    }

    private func save() {
        let dateText = RecruitmentFieldFormat.dateFormatter.string(from: pickedDate)
        let timeText = RecruitmentFieldFormat.timeFormatter.string(from: pickedDate)
        switch field {
        case .startDate: draft.schedule.startDate = dateText
        case .endDate: draft.schedule.endDate = dateText
        case .deadline: draft.deadline = dateText
        case .startTime: draft.schedule.startTime = timeText
        case .endTime: draft.schedule.endTime = timeText
        case .meetingTime: draft.meeting.meetingTime = timeText
        case .ageRange:
            // 「제한 없음」이면 **보내지 않는다** — 서버가 둘 다 nullable 이다.
            draft.minimumAge = ageLimited ? minimumAge : nil
            draft.maximumAge = ageLimited ? maximumAge : nil
        case .estimatedCost:
            // 비워서 저장하면 미정으로 되돌린다 — `0원` 을 지어내지 않는다
            let amount = RecruitmentFieldFormat.amount(from: costText)
            draft.estimatedCost = costText.contains(where: \.isNumber) ? RecruitmentFieldFormat.money(amount) : ""
        }
    }
}
