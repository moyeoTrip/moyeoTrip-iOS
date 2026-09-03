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

    static func amount(from text: String) -> Int {
        Int(text.filter(\.isNumber)) ?? 0
    }
}

/// 한 항목을 고치는 바텀시트. `저장` 을 눌러야 초안에 반영된다 — 취소하면 그대로다.
struct RecruitmentFieldSheet: View {
    let field: RecruitmentFieldEditor
    @Binding var draft: RecruitmentDraft
    let onClose: () -> Void

    @State private var pickedDate = Date()
    @State private var minimumAge = 20
    @State private var maximumAge = 100
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
            DatePicker("", selection: $pickedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "ko_KR"))
                .accessibilityIdentifier("recruitment.field.datePicker")
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

    /// 17-4 — 최소·최대 모두 20~100세 사이. 최소가 최대를 넘지 않게 함께 민다.
    private var ageRangeEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            Stepper(value: $minimumAge, in: 20...maximumAge) {
                Text("최소 \(minimumAge)세")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MoyeoTheme.ink)
                    .monospacedDigit()
            }
            .accessibilityIdentifier("recruitment.field.minimumAge")
            Stepper(value: $maximumAge, in: minimumAge...100) {
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
            Text("신청자가 신청 전에 가장 많이 확인하는 값이에요.")
                .font(.caption)
                .foregroundStyle(MoyeoTheme.muted)
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
            minimumAge = draft.minimumAge
            maximumAge = draft.maximumAge
        case .estimatedCost:
            let amount = RecruitmentFieldFormat.amount(from: draft.estimatedCost)
            costText = amount == 0 ? "" : "\(amount)"
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
            draft.minimumAge = minimumAge
            draft.maximumAge = maximumAge
        case .estimatedCost:
            draft.estimatedCost = RecruitmentFieldFormat.money(RecruitmentFieldFormat.amount(from: costText))
        }
    }
}
