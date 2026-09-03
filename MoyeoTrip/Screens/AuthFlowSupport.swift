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
    var title: String {
        switch self {
        case .kakao:
            return "카카오 로그인"
        case .email:
            return "이메일로 시작하기"
        case .google:
            return "Google로 계속하기"
        case .apple:
            return "Apple로 계속하기"
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
    case location
    case marketing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .age:
            return "만 18세 이상"
        case .service:
            return "이용약관 동의"
        case .privacy:
            return "개인정보 처리방침"
        case .location:
            return "위치정보 이용"
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

    var legalDocument: LegalDocumentKind? {
        switch self {
        case .age: nil
        case .service: .service
        case .privacy: .privacy
        case .location: .location
        case .marketing: .marketing
        }
    }

    init?(document: LegalDocumentKind) {
        switch document {
        case .service: self = .service
        case .privacy: self = .privacy
        case .location: self = .location
        case .marketing: self = .marketing
        }
    }
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
                .frame(height: 52)
                .background(isEnabled ? MoyeoTheme.forest : MoyeoTheme.subtleBackground)
                .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
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
                .frame(height: 50)
                .background(isEnabled ? MoyeoTheme.card : MoyeoTheme.subtleBackground)
                .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                        .stroke(isEnabled ? MoyeoTheme.forest : MoyeoTheme.line, lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}
