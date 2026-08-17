import SwiftUI

enum KoreanBirthdatePolicy {
    static let calendar = Calendar(identifier: .gregorian)

    static func years(through date: Date = Date()) -> [Int] {
        let currentYear = calendar.component(.year, from: date)
        return Array((1900...currentYear).reversed())
    }

    static func days(year: Int, month: Int) -> Int {
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return 31
        }
        return range.count
    }

    static func date(year: Int, month: Int, day: Int) -> Date {
        let clampedDay = min(day, days(year: year, month: month))
        return calendar.date(from: DateComponents(year: year, month: month, day: clampedDay))
            ?? AuthBirthdate.april1998.date
    }
}

struct KoreanBirthdateField: View {
    @Binding var selection: AuthBirthdate?
    @State private var showsPicker = false

    private var selectedDate: Date {
        selection?.date ?? AuthBirthdate.april1998.date
    }

    var body: some View {
        Button {
            showsPicker = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(MoyeoTypography.font(size: 18, weight: .bold))
                    .foregroundStyle(MoyeoTheme.forest)
                    .frame(width: 42, height: 42)
                    .background(MoyeoTheme.leaf)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(Self.displayFormatter.string(from: selectedDate))
                        .font(MoyeoTypography.cardTitle)
                        .foregroundStyle(MoyeoTheme.ink)
                    Text("연도 · 월 · 일 순서로 선택해요")
                        .font(MoyeoTypography.cardMeta)
                        .foregroundStyle(MoyeoTheme.muted)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.up.chevron.down")
                    .font(MoyeoTypography.font(size: 13, weight: .bold))
                    .foregroundStyle(MoyeoTheme.text400)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(MoyeoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                    .stroke(MoyeoTheme.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("생년월일")
        .accessibilityValue(Self.displayFormatter.string(from: selectedDate))
        .accessibilityIdentifier("auth.basic.birthdate")
        .onAppear {
            if selection == nil {
                selection = .april1998
            }
        }
        .sheet(isPresented: $showsPicker) {
            KoreanBirthdatePickerSheet(initialDate: selectedDate) { date in
                selection = AuthBirthdate(date: date)
                showsPicker = false
            }
            .presentationDetents([.height(430)])
            .presentationDragIndicator(.visible)
        }
    }

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy년 M월 d일"
        return formatter
    }()
}

private struct KoreanBirthdatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var year: Int
    @State private var month: Int
    @State private var day: Int

    let onDone: (Date) -> Void

    private let calendar = KoreanBirthdatePolicy.calendar
    private var availableYears: [Int] { KoreanBirthdatePolicy.years() }
    private var availableDays: [Int] { Array(1...daysInSelectedMonth) }

    init(initialDate: Date, onDone: @escaping (Date) -> Void) {
        let calendar = Calendar(identifier: .gregorian)
        _year = State(initialValue: calendar.component(.year, from: initialDate))
        _month = State(initialValue: calendar.component(.month, from: initialDate))
        _day = State(initialValue: calendar.component(.day, from: initialDate))
        self.onDone = onDone
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("취소") { dismiss() }
                    .foregroundStyle(MoyeoTheme.muted)
                Spacer()
                Text("생년월일 선택")
                    .font(MoyeoTypography.cardTitle)
                    .foregroundStyle(MoyeoTheme.ink)
                Spacer()
                Button("완료") { onDone(selectedDate) }
                    .font(MoyeoTypography.cardBody)
                    .foregroundStyle(MoyeoTheme.forest)
                    .accessibilityIdentifier("auth.basic.birthdate.done")
            }
            .padding(.horizontal, 20)
            .frame(height: 56)

            Text("\(year)년 \(month)월 \(day)일")
                .font(MoyeoTypography.sectionTitle)
                .foregroundStyle(MoyeoTheme.ink)
                .padding(.top, 8)
                .accessibilityIdentifier("auth.basic.birthdate.summary")

            HStack(spacing: 0) {
                componentPicker(title: "년", selection: $year, values: availableYears)
                componentPicker(title: "월", selection: $month, values: Array(1...12))
                componentPicker(title: "일", selection: $day, values: availableDays)
            }
            .frame(height: 230)
            .padding(.horizontal, 10)

            Text("입력한 생년월일은 연령 확인과 여행 추천에만 사용해요.")
                .font(MoyeoTypography.cardMeta)
                .foregroundStyle(MoyeoTheme.muted)
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .onChange(of: year) { _, _ in clampDay() }
        .onChange(of: month) { _, _ in clampDay() }
    }

    private func componentPicker(title: String, selection: Binding<Int>, values: [Int]) -> some View {
        Picker(title, selection: selection) {
            ForEach(values, id: \.self) { value in
                Text("\(value)\(title)")
                    .font(MoyeoTypography.body)
                    .tag(value)
            }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityIdentifier("auth.basic.birthdate.\(title)")
    }

    private var selectedDate: Date {
        KoreanBirthdatePolicy.date(year: year, month: month, day: day)
    }

    private var daysInSelectedMonth: Int {
        KoreanBirthdatePolicy.days(year: year, month: month)
    }

    private func clampDay() {
        day = min(day, daysInSelectedMonth)
    }
}
