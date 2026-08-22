//
//  AuthFlowControls.swift
//  MoyeoTrip
//

import SwiftUI

// This file contains the shared controls for the complete seven-step auth flow.
// swiftlint:disable file_length

struct AuthInlineError: View {
    let message: String
    let accessibilityIdentifier: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .padding(.top, 1)
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(MoyeoTheme.coral)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoyeoTheme.coral.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct AuthSecureField: View {
    let title: String
    @Binding var text: String
    let accessibilityIdentifier: String
    /// 비밀번호 확인 칸은 자동완성을 요청하지 않는다. 암호 관리자는 본 비밀번호 칸만 채우고,
    /// 확인 칸에 자동완성 오버레이가 뜨면 입력 포커스를 가져가 버린다.
    var contentType: UITextContentType? = .password

    var body: some View {
        HStack(spacing: 10) {
            SecureField(title, text: $text)
                .textContentType(contentType)
                .foregroundStyle(MoyeoTheme.ink)
                .accessibilityIdentifier(accessibilityIdentifier)
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                .stroke(MoyeoTheme.softLine, lineWidth: 1)
        }
    }
}

struct AuthProviderButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let provider: AuthProvider
    var isLoading = false
    var isDisabled = false
    var showsMark = true
    var titleOverride: String?
    var accessibilityIdentifierOverride: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            providerLabel
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(borderColor, lineWidth: borderWidth)
                }
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .disabled(isDisabled)
        .opacity(isDisabled && !isLoading ? 0.48 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(buttonTitle)
        .accessibilityIdentifier(accessibilityIdentifierOverride ?? provider.accessibilityIdentifier)
    }

    @ViewBuilder
    private var providerLabel: some View {
        if provider == .kakao {
            ZStack {
                Color(hex: "#FEE500")
                Text(buttonTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.85))

                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(Color.black.opacity(0.85))
                            .frame(width: 26, height: 26)
                    } else if showsMark {
                        Image("KakaoSymbolOfficial")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                            .frame(width: 26, height: 26)
                            .accessibilityHidden(true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
            }
        } else {
            ZStack {
                Text(buttonTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(foregroundColor)

                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(foregroundColor)
                            .frame(width: 26, height: 26)
                    } else if showsMark {
                        AuthProviderMark(provider: provider)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var buttonTitle: String {
        titleOverride ?? provider.title
    }

    private var backgroundColor: Color {
        switch provider {
        case .google:
            return colorScheme == .dark ? Color(hex: "#131314") : .white
        case .email:
            return MoyeoTheme.card
        case .kakao:
            return Color(hex: "#FEE500")
        case .apple:
            return colorScheme == .dark ? .white : .black
        }
    }

    private var foregroundColor: Color {
        switch provider {
        case .google:
            return colorScheme == .dark ? Color(hex: "#E3E3E3") : Color(hex: "#1F1F1F")
        case .email:
            return MoyeoTheme.ink
        case .kakao:
            return Color.black.opacity(0.85)
        case .apple:
            return colorScheme == .dark ? .black : .white
        }
    }

    private var borderColor: Color {
        switch provider {
        case .google:
            return colorScheme == .dark ? Color(hex: "#8E918F") : Color(hex: "#747775")
        case .email:
            return MoyeoTheme.line
        case .kakao, .apple:
            return .clear
        }
    }

    private var borderWidth: CGFloat {
        switch provider {
        case .email, .google:
            return 1
        case .kakao, .apple:
            return 0
        }
    }

    private var cornerRadius: CGFloat {
        12
    }
}

struct AuthProviderMark: View {
    let provider: AuthProvider

    var body: some View {
        switch provider {
        case .email:
            Text("@")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(MoyeoTheme.forest)
                .frame(width: 26, height: 26)
        case .google:
            Image("GoogleG")
                .resizable()
                .scaledToFit()
                .frame(width: 19, height: 19)
                .frame(width: 26, height: 26)
                .accessibilityHidden(true)
        case .kakao:
            EmptyView()
        case .apple:
            Image("AppleSymbolOfficial")
                .resizable()
                .scaledToFit()
                .frame(width: 19, height: 19)
                .frame(width: 26, height: 26)
                .accessibilityHidden(true)
        }
    }
}

struct AuthChoiceButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var tint: Color = MoyeoTheme.forest
    var accessibilityIdentifier: String?
    var detailAction: (() -> Void)?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.13))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.ink)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.muted)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? MoyeoTheme.forest : MoyeoTheme.text400)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? MoyeoTheme.leaf : MoyeoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                    .stroke(isSelected ? MoyeoTheme.forest : MoyeoTheme.softLine, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

struct AuthNicknameCandidateButton: View {
    let candidate: AuthNicknameCandidate
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(candidate.animalEmoji)
                    .font(.system(size: 27))
                    .frame(width: 52, height: 52)
                    .background(candidate.swatchColor.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(candidate.displayName)
                            .font(MoyeoTypography.cardBody)
                            .foregroundStyle(MoyeoTheme.ink)
                            .lineLimit(1)
                        Text(candidate.number)
                            .font(MoyeoTypography.cardMeta)
                            .foregroundStyle(MoyeoTheme.muted)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(candidate.swatchColor)
                                .frame(width: 8, height: 8)
                            Text(candidate.colorLabel)
                                .font(MoyeoTypography.cardMeta)
                                .foregroundStyle(MoyeoTheme.muted)
                        }
                    }
                    Text(candidate.description)
                        .font(MoyeoTypography.cardMeta)
                        .foregroundStyle(MoyeoTheme.muted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
                // 선택은 외곽선과 배경 틴트로만 표시한다 — 다른 플랫폼에 없는 라디오 원형은 두지 않는다
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .background(isSelected ? MoyeoTheme.leaf : MoyeoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                    .stroke(isSelected ? MoyeoTheme.forest : MoyeoTheme.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(candidate.nickname), \(candidate.colorLabel), \(candidate.description)")
        .accessibilityValue(isSelected ? "선택됨" : "선택 안 됨")
        .accessibilityIdentifier("auth.nickname.option.\(candidate.id)")
    }
}

struct AuthNicknameSkeletonCard: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                .fill(MoyeoTheme.softLine)
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 7) {
                Capsule()
                    .fill(MoyeoTheme.softLine)
                    .frame(width: 132, height: 14)
                Capsule()
                    .fill(MoyeoTheme.softLine)
                    .frame(width: 190, height: 11)
                Capsule()
                    .fill(MoyeoTheme.softLine)
                    .frame(width: 142, height: 11)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 76)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                .stroke(MoyeoTheme.line, lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

struct AuthPillButton: View {
    let title: String
    var accessibilityIdentifier: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(isSelected ? .white : MoyeoTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.84)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isSelected ? MoyeoTheme.forest : MoyeoTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                        .stroke(isSelected ? MoyeoTheme.forest : MoyeoTheme.softLine, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

struct AuthTermButton: View {
    let title: String
    let subtitle: String
    var isRequired = false
    var showsRequirement = true
    var accessibilityIdentifier: String?
    var detailAction: (() -> Void)?
    let isSelected: Bool
    let action: () -> Void

    // 약관은 항목마다 카드를 두지 않고 한 줄씩 수직으로 쌓는다 (화면기획 기준).
    // 카드가 6개 겹치면 필수/선택 위계가 읽히지 않는다.
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button(action: action) {
                    HStack(spacing: 8) {
                        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(isSelected ? MoyeoTheme.forest : MoyeoTheme.text400)

                        Text(title)
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(MoyeoTheme.ink)

                        if showsRequirement {
                            Text(isRequired ? "(필수)" : "(선택)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(MoyeoTheme.muted)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                if let detailAction {
                    Button(action: detailAction) {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MoyeoTheme.text400)
                            .frame(width: 36)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) 내용 보기")
                    .accessibilityIdentifier("\(accessibilityIdentifier ?? "auth.terms").detail")
                }
            }
            Divider().overlay(MoyeoTheme.softLine)
        }
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

struct AuthAnimalPreview: View {
    let nickname: String
    let isComplete: Bool

    private var animalSymbol: String {
        if nickname.contains("거북이") {
            return "tortoise.fill"
        }
        if nickname.contains("너구리") {
            return "pawprint.fill"
        }
        return "leaf.fill"
    }

    private var tint: Color {
        if nickname.contains("거북이") {
            return MoyeoTheme.river
        }
        if nickname.contains("너구리") {
            return MoyeoTheme.coral
        }
        return MoyeoTheme.forest
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(tint.opacity(0.15))
                    .frame(width: 148, height: 148)
                Image(systemName: animalSymbol)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(tint)
            }

            VStack(spacing: 5) {
                Text(nickname)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                Text(isComplete ? "여행 친구 생성 완료" : "버튼을 누르면 친구가 그려져요.")
                    .font(.caption)
                    .foregroundStyle(MoyeoTheme.muted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(MoyeoTheme.subtleBackground)
        .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
        .accessibilityIdentifier("auth.character.preview")
    }
}

struct AuthSectionTitle: View {
    let title: String
    var isRequired = false

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)
            if isRequired {
                Text("*")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.coral)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 06 단계 상단의 닉네임 카드 — 앞 단계에서 고른 친구를 다시 보여준다.
struct AuthSelectedNicknameCard: View {
    let nickname: String?
    let candidate: AuthNicknameCandidate?

    var body: some View {
        HStack(spacing: 12) {
            Text(candidate?.animalEmoji ?? "🦌")
                .font(.system(size: 26))
                .frame(width: 48, height: 48)
                .background((candidate?.swatchColor ?? MoyeoTheme.forest).opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(nickname ?? "따스한 사슴 3492")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.ink)
                Text("새 친구가 옆에 앉았어요")
                    .font(.caption)
                    .foregroundStyle(MoyeoTheme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoyeoTheme.subtleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier("auth.basic.nickname")
    }
}

/// 생년월일 아래 안내 — 공개되는 것은 나이대뿐임을 알려준다.
struct AuthAgeBandNote: View {
    let birthdate: AuthBirthdate?

    var body: some View {
        Text(noteText)
            .font(.caption2)
            .foregroundStyle(MoyeoTheme.muted)
            .accessibilityIdentifier("auth.basic.ageBand")
    }

    private var noteText: String {
        guard let band = ageBandLabel else { return "나이대만 공개됩니다" }
        return "나이대만 공개됩니다 (\(band))"
    }

    private var ageBandLabel: String? {
        guard let birthdate else { return nil }
        let calendar = Calendar(identifier: .gregorian)
        guard let age = calendar.dateComponents([.year], from: birthdate.date, to: Date()).year,
              age >= 10 else { return nil }
        let decade = (age / 10) * 10
        let remainder = age % 10
        let phase = remainder <= 3 ? "초반" : (remainder <= 6 ? "중반" : "후반")
        return "\(decade)대 \(phase)"
    }
}
