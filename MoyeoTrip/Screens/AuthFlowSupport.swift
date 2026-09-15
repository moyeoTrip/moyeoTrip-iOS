//
//  AuthFlowSupport.swift
//  MoyeoTrip
//

import SwiftUI

struct AuthOnboardingPage: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let body: String
    let imageName: String

    var isLast: Bool {
        id == Self.pages.count - 1
    }

    static let pages = [
        AuthOnboardingPage(
            id: 0,
            title: "고민 없이 고르는\n경북 코스",
            subtitle: "날씨와 취향에 맞춰 추천해요",
            body: "날씨와 취향에 맞춰\n오늘 떠나기 좋은 코스를 추천해요.",
            imageName: "Onboarding1"
        ),
        AuthOnboardingPage(
            id: 1,
            title: "3명이 모이면\n채팅방이 열려요",
            subtitle: "모집 확정 후 바로 대화해요",
            body: "모집이 확정되면\n바로 대화가 시작돼요.",
            imageName: "Onboarding2"
        ),
        AuthOnboardingPage(
            id: 2,
            title: "여행 뒤엔\n자연스럽게 친구로",
            subtitle: "경로 피드와 도감으로 남겨요",
            body: "경로 피드와 도감으로\n함께한 순간을 남겨요.",
            imageName: "Onboarding3"
        )
    ]
}

typealias AuthProvider = AuthServiceProvider

extension AuthServiceProvider {
    /// 로그인 버튼 문구. **「제공자 이름 + 로그인」으로 통일한다** (2026-09-14 결정 ③).
    ///
    /// 예전에는 한 화면에 동사가 셋이었다 — 「카카오 로그인」·「Google로 계속하기」·
    /// 「이메일로 시작하기」. 같은 일을 하는 버튼이 서로 다른 약속을 하는 것처럼 읽힌다.
    /// 제공자 표기(`카카오`·`Google`·`Apple`)는 브랜드를 따르고 **뒤는 전부 「 로그인」**이다.
    /// 접근성 라벨도 같은 문장을 쓴다(`AuthProviderButton` 이 이 값을 그대로 읽는다).
    var title: String {
        switch self {
        case .kakao:
            return "카카오 로그인"
        case .email:
            return "이메일 로그인"
        case .google:
            return "Google 로그인"
        case .apple:
            return "Apple 로그인"
        }
    }

    var systemImage: String {
        switch self {
        case .kakao:
            return ""
        case .email:
            return "at"
        case .google:
            return ""
        case .apple:
            return ""
        }
    }

    var tint: Color {
        switch self {
        case .kakao:
            return Color(hex: "#FEE500")
        case .email:
            return MoyeoTheme.river
        case .google:
            return Color.white
        case .apple:
            return Color(hex: "#151A18")
        }
    }

    var foreground: Color {
        switch self {
        case .kakao, .google:
            return Color(hex: "#1F1F1F")
        case .email, .apple:
            return .white
        }
    }

    var border: Color {
        switch self {
        case .apple, .google:
            return Color.white.opacity(0.20)
        default:
            return Color.clear
        }
    }

    var accessibilityIdentifier: String {
        "auth.login.\(pathComponent)"
    }
}

struct AuthBirthdate: Equatable {
    let date: Date

    static let april1998 = AuthBirthdate(
        date: Calendar(identifier: .gregorian).date(from: DateComponents(year: 1998, month: 4, day: 12))!
    )

    var apiValue: String {
        Self.apiFormatter.string(from: date)
    }

    private static let apiFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

enum AuthGender: String, CaseIterable, Identifiable {
    case female
    case male
    case undisclosed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .female:
            return "여성"
        case .male:
            return "남성"
        case .undisclosed:
            return "선택 안 함"
        }
    }

    var accessibilityIdentifier: String {
        "auth.basic.gender.\(rawValue)"
    }

    var apiValue: String {
        switch self {
        case .female: return "F"
        case .male: return "M"
        case .undisclosed: return "N"
        }
    }
}

enum AuthTerm: String, CaseIterable, Identifiable {
    case age
    case service
    case privacy
    case marketing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .age:
            // 숫자는 `KoreanBirthdatePolicy.minimumSignupAge` 하나에서만 온다 —
            // 서버 `AuthService.MINIMUM_SIGNUP_AGE` 를 따르는 값이다 (BE-06).
            return "만 \(KoreanBirthdatePolicy.minimumSignupAge)세 이상"
        case .service:
            return "이용약관 동의"
        case .privacy:
            return "개인정보 처리방침"
        case .marketing:
            return "마케팅 정보 수신"
        }
    }

    var subtitle: String {
        isRequired ? "필수 항목" : "선택 항목"
    }

    var isRequired: Bool {
        self == .age || self == .service || self == .privacy
    }

    var accessibilityIdentifier: String {
        "auth.terms.\(rawValue)"
    }

    static let requiredTerms: [AuthTerm] = [.age, .service, .privacy]
}

struct AuthStepContainer<Content: View, Footer: View>: View {
    let title: String?
    let subtitle: String?
    let showsFooterInset: Bool
    let content: Content
    let footer: Footer

    init(
        title: String? = nil,
        subtitle: String? = nil,
        showsFooterInset: Bool = true,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showsFooterInset = showsFooterInset
        self.content = content()
        self.footer = footer()
    }

    @ViewBuilder
    var body: some View {
        let scrollContent = ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let title, let subtitle {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(MoyeoTheme.ink)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(MoyeoTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                content
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 132)
        }

        if showsFooterInset {
            scrollContent
                .safeAreaInset(edge: .bottom) {
                    footer
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        .padding(.bottom, 14)
                        .background(MoyeoTheme.background)
                }
        } else {
            scrollContent
        }
    }
}

struct AuthPrimaryButton: View {
    /// 비활성 CTA는 화면기획·웹·안드로이드처럼 회색 채움으로 그린다. 초록을 흐리게만 두면
    /// 같은 화면인데 플랫폼마다 CTA 색이 달라 보인다.
    @Environment(\.isEnabled) private var isEnabled

    let title: String
    /// 화면기획의 CTA는 글자만 있다. 호출부 호환을 위해 남겨두지만 그리지 않는다.
    var systemImage: String = ""
    var accessibilityIdentifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(isEnabled ? .white : MoyeoTheme.muted)
                .frame(maxWidth: .infinity)
                .frame(height: MoyeoTheme.ctaHeight)
                .background(isEnabled ? MoyeoTheme.forest : MoyeoTheme.subtleBackground)
                // 정본은 **높이 48 · 모서리 12** 이고 네 표면이 각자 이름 있는 상수로 그 값을 쓴다
                // (docs/ui-comparison/BUTTON-GEOMETRY.md). 여기만 카드용 반경(9)을 쓰고 있어
                // 같은 버튼이 iOS 에서만 덜 둥글었다 (TC REQ-008).
                .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.ctaRadius, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: MoyeoTheme.ctaRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

struct AuthSecondaryButton: View {
    /// 활성 보조 CTA는 화면기획·웹·안드로이드처럼 아웃라인(카드 배경 + 초록 테두리 + 진한 초록 글자)이다.
    /// leaf 채움 + forest 글자는 대비가 낮아 같은 버튼이 iOS에서만 비활성처럼 읽혔다.
    @Environment(\.isEnabled) private var isEnabled

    let title: String
    /// 화면기획의 CTA는 글자만 있다. 호출부 호환을 위해 남겨두지만 그리지 않는다.
    var systemImage: String = ""
    var accessibilityIdentifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(isEnabled ? MoyeoTheme.onLeaf : MoyeoTheme.muted)
                .frame(maxWidth: .infinity)
                // 보조 CTA 도 주 버튼과 **같은 높이·모서리**다 — 나란히 놓이는 두 버튼이
                // 48 과 50 으로 달라 한쪽만 커 보였다 (TC REQ-008).
                .frame(height: MoyeoTheme.ctaHeight)
                .background(isEnabled ? MoyeoTheme.card : MoyeoTheme.subtleBackground)
                .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.ctaRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MoyeoTheme.ctaRadius, style: .continuous)
                        .stroke(isEnabled ? MoyeoTheme.forest : MoyeoTheme.line, lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: MoyeoTheme.ctaRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}
