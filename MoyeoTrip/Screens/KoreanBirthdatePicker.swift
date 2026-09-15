import SwiftUI

enum KoreanBirthdatePolicy {
    static let calendar = Calendar(identifier: .gregorian)

    /// 가입 최소 연령. **서버 상수를 따른다** — `AuthService.MINIMUM_SIGNUP_AGE` ·
    /// `UserService.MINIMUM_PROFILE_AGE` 가 정본이고, 모자라면
    /// `40011 만 19세 이상만 가입할 수 있습니다.` 로 막힌다.
    ///
    /// 2026-09-14 BE-06 결정으로 20 → 19 가 되었다. 또 바뀔 수 있으니 **서버를 먼저 보고**
    /// 이 값 하나만 고친다 — 연·월·일 상한과 약관 확인 항목이 모두 여기를 본다.
    static let minimumSignupAge = 19

    /// 최소 연령에 닿는 마지막 날. 이 날보다 뒤에 태어났으면 가입할 수 없다.
    static func latestAllowedBirthdate(today: Date = Date()) -> Date {
        calendar.date(byAdding: .year, value: -minimumSignupAge, to: calendar.startOfDay(for: today))
            ?? calendar.startOfDay(for: today)
    }

    /// 고를 수 있는 연도. 예전에는 1900…**올해**를 전부 줘서, 오늘보다 뒤인 날짜도,
    /// 최소 연령이 안 되는 해도 고를 수 있었고 **가입 마지막 단계에서야** 거절됐다 (IOS-F58·F100).
    static func years(through date: Date = Date()) -> [Int] {
        let lastYear = calendar.component(.year, from: latestAllowedBirthdate(today: date))
        return Array((1900...max(1900, lastYear)).reversed())
    }

    /// 그 해에 고를 수 있는 월. 한도가 걸린 해에는 한도 달까지만 준다.
    static func months(year: Int, today: Date = Date()) -> [Int] {
        let limit = latestAllowedBirthdate(today: today)
        guard year == calendar.component(.year, from: limit) else { return Array(1...12) }
        return Array(1...calendar.component(.month, from: limit))
    }

    /// 그 달에 고를 수 있는 일. 한도가 걸린 달에는 한도 날까지만 준다.
    static func selectableDays(year: Int, month: Int, today: Date = Date()) -> [Int] {
        let limit = latestAllowedBirthdate(today: today)
        let total = days(year: year, month: month)
        guard year == calendar.component(.year, from: limit),
              month == calendar.component(.month, from: limit) else { return Array(1...total) }
        return Array(1...min(total, calendar.component(.day, from: limit)))
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
    private var availableMonths: [Int] { KoreanBirthdatePolicy.months(year: year) }
    private var availableDays: [Int] { KoreanBirthdatePolicy.selectableDays(year: year, month: month) }

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
                componentPicker(title: "월", selection: $month, values: availableMonths)
                componentPicker(title: "일", selection: $day, values: availableDays)
            }
            .frame(height: 230)
            .padding(.horizontal, 10)

            // 나이 기준을 **고르기 전에** 알린다. 예전에는 아무 해나 고르게 두고
            // 가입 마지막 단계에서 서버 `40011` 로 거절했다 (IOS-F100).
            Text("만 \(KoreanBirthdatePolicy.minimumSignupAge)세 이상만 가입할 수 있어요.")
                .font(MoyeoTypography.cardMeta)
                .foregroundStyle(MoyeoTheme.muted)
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
                .accessibilityIdentifier("auth.basic.birthdate.ageRule")

            Text("입력한 생년월일은 연령 확인과 여행 추천에만 사용해요.")
                .font(MoyeoTypography.cardMeta)
                .foregroundStyle(MoyeoTheme.muted)
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .onChange(of: year) { _, _ in clampToAllowedRange() }
        .onChange(of: month) { _, _ in clampToAllowedRange() }
        .onAppear { clampToAllowedRange() }
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

    /// 고른 값이 허용 범위를 벗어나면 범위 안으로 당긴다.
    /// 달을 바꿔 없는 날이 되는 경우(2월 31일)와, 최소 연령 한도를 넘는 월·일을
    /// 함께 막는다 — 예전에는 날짜 길이만 봤다 (IOS-F58).
    private func clampToAllowedRange() {
        if let newestYear = availableYears.first, year > newestYear { year = newestYear }
        let months = availableMonths
        if let last = months.last, month > last { month = last }
        if let first = months.first, month < first { month = first }
        let days = availableDays
        if let last = days.last, day > last { day = last }
        if let first = days.first, day < first { day = first }
        day = min(day, daysInSelectedMonth)
    }
}
