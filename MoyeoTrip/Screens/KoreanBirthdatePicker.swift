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

    /// 피커를 열 때의 시작 위치. 값이 아직 없으면 화면기획의 기준 날짜에서 시작한다 —
    /// 오늘 날짜에서 시작하면 사용자가 수십 년을 스크롤해야 한다.
    private var pickerStartDate: Date {
        selection?.date ?? AuthBirthdate.april1998.date
    }

    /// 아직 고르지 않았음을 그대로 보여준다.
    private var displayText: String {
        guard let selection else { return "생년월일을 선택해주세요" }
        return Self.displayFormatter.string(from: selection.date)
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
                    Text(displayText)
                        .font(MoyeoTypography.cardTitle)
                        .foregroundStyle(selection == nil ? MoyeoTheme.muted : MoyeoTheme.ink)
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
        .accessibilityValue(displayText)
        .accessibilityIdentifier("auth.basic.birthdate")
        // 화면에 뜨는 것만으로 기본값을 확정하지 않는다.
        // 이전에는 여기서 1998-04-12(화면기획 샘플 값)를 넣어, 사용자가 생년월일을 한 번도
        // 고르지 않아도 그 날짜가 그대로 가입 요청에 실려 나갔다. 나이 확인이 무의미해진다.
        .sheet(isPresented: $showsPicker) {
            KoreanBirthdatePickerSheet(initialDate: pickerStartDate) { date in
                selection = AuthBirthdate(date: date)
                showsPicker = false
            }
            .presentationDetents([.height(430)])
            .presentationDragIndicator(.visible)
            // 시트는 기본적으로 시스템 배경을 깔아, 손잡이가 있는 상단 띠와 아래 여백이
            // 본문과 다른 색으로 보인다. 시트 배경 자체를 앱 배경색으로 맞춘다.
            .presentationBackground(MoyeoTheme.background)
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

            // Text 의 기본 보간은 LocalizedStringKey 라서 Int 에 천단위 구분자가 붙는다("1,997년").
            // 연도·월·일은 수치가 아니라 표기이므로 verbatim 으로 그린다.
            Text(verbatim: "\(year)년 \(month)월 \(day)일")
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
                // 여기도 verbatim — 그러지 않으면 연도가 "1,997년" 으로 나온다.
                Text(verbatim: "\(value)\(title)")
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
