//
//  AuthFlowControls.swift
//  MoyeoTrip
//

import SwiftUI

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

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .foregroundStyle(MoyeoTheme.forest)
                .frame(width: 22)
            SecureField(title, text: $text)
                .textContentType(.password)
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

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? MoyeoTheme.forest : MoyeoTheme.text400)
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
    var accessibilityIdentifier: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? MoyeoTheme.forest : MoyeoTheme.text400)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(MoyeoTheme.ink)
                        if isRequired {
                            Text("필수")
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(MoyeoTheme.coral)
                        }
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.muted)
                }

                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MoyeoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                    .stroke(MoyeoTheme.softLine, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
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
    var body: some View {
        Text(title)
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(MoyeoTheme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
