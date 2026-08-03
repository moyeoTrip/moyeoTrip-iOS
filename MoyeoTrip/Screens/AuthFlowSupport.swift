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
    let systemImage: String
    let tint: Color

    var isLast: Bool {
        id == Self.pages.count - 1
    }

    static let pages = [
        AuthOnboardingPage(
            id: 0,
            title: "고민 없이 고르는 경북 코스",
            subtitle: "날씨와 취향에 맞춰 추천해요",
            body: "날씨와 취향에 맞춰 오늘 떠나기 좋은 코스를 추천해요.",
            systemImage: "heart.fill",
            tint: MoyeoTheme.coral
        ),
        AuthOnboardingPage(
            id: 1,
            title: "3명이 모이면 채팅방이 열려요",
            subtitle: "모집 확정 후 바로 대화해요",
            body: "모집이 확정되면 바로 대화가 시작돼요.",
            systemImage: "calendar",
            tint: MoyeoTheme.river
        ),
        AuthOnboardingPage(
            id: 2,
            title: "여행 뒤엔 자연스럽게 친구로",
            subtitle: "경로 피드와 도감으로 남겨요",
            body: "경로 피드와 도감으로 함께한 순간을 남겨요.",
            systemImage: "star.fill",
            tint: MoyeoTheme.coral
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
            return "이메일로 계속하기"
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
            return "envelope.fill"
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
enum AuthNicknameOption: String, CaseIterable, Identifiable {
    case deer
    case turtle
    case raccoon

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deer:
            return "따스한 사슴 3492"
        case .turtle:
            return "잔잔한 거북이 1108"
        case .raccoon:
            return "호기심 많은 너구리 9027"
        }
    }

    var subtitle: String {
        switch self {
        case .deer:
            return "처음 만난 사람에게도 다정하게 말을 건네요"
        case .turtle:
            return "무리하지 않는 속도로 여행을 즐겨요"
        case .raccoon:
            return "새로운 골목과 맛집을 먼저 찾아봐요"
        }
    }

    var systemImage: String {
        switch self {
        case .deer:
            return "leaf.fill"
        case .turtle:
            return "tortoise.fill"
        case .raccoon:
            return "pawprint.fill"
        }
    }

    var tint: Color {
        switch self {
        case .deer:
            return MoyeoTheme.forest
        case .turtle:
            return MoyeoTheme.river
        case .raccoon:
            return MoyeoTheme.coral
        }
    }

    var accessibilityIdentifier: String {
        "auth.nickname.option.\(rawValue)"
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
            return "만 14세 이상"
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
    let title: String
    let systemImage: String
    var accessibilityIdentifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(MoyeoTheme.forest)
                .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

struct AuthSecondaryButton: View {
    let title: String
    let systemImage: String
    var accessibilityIdentifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(MoyeoTheme.forest)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(MoyeoTheme.leaf)
                .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}
