import SwiftUI

struct AuthEmailCredentialsView: View {
    let mode: AuthEmailMode
    @Binding var email: String
    @Binding var password: String
    @Binding var passwordConfirmation: String
    let isSubmitting: Bool
    let errorMessage: String?
    let submitAction: () -> Void
    let createAccountAction: () -> Void
    let signInAction: () -> Void
    let forgotPasswordAction: () -> Void

    private var isRegistration: Bool { mode == .createAccount }
    private var canSubmit: Bool {
        EmailCredentialsPolicy.canSubmit(
            email: email,
            password: password,
            passwordConfirmation: passwordConfirmation,
            isRegistration: isRegistration
        )
    }
    private var showsMismatch: Bool {
        EmailCredentialsPolicy.showsPasswordMismatch(
            password: password,
            passwordConfirmation: passwordConfirmation
        )
    }

    var body: some View {
        AuthStepContainer(
            title: "이메일로 시작하기",
            subtitle: "가입했던 이메일로 로그인하거나 새 계정을 만들어요.",
            showsFooterInset: false
        ) {
            VStack(spacing: 22) {
                modeSegments

                VStack(spacing: 12) {
                    // 라벨은 인풋 위에 둔다 — 값이 비었을 때 플레이스홀더와 구분되지 않으면
                    // 무엇을 넣는 칸인지 알 수 없다
                    AuthLabeledField(label: "이메일") {
                        AuthEmailField(text: $email, accessibilityIdentifier: "auth.email.address")
                    }
                    AuthLabeledField(label: "비밀번호") {
                        AuthSecureField(
                            title: "6자 이상 입력",
                            text: $password,
                            accessibilityIdentifier: "auth.email.password"
                        )
                    }

                    if isRegistration {
                        registrationFields
                    } else {
                        Button("비밀번호를 잊으셨나요?", action: forgotPasswordAction)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MoyeoTheme.forest)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .accessibilityIdentifier("auth.email.forgotPassword")
                    }

                    if let errorMessage {
                        AuthInlineError(message: errorMessage, accessibilityIdentifier: "auth.email.error")
                    }
                }

                // 웹처럼 입력 항목을 확인한 직후에 CTA를 둔다. 공통 바닥 고정 CTA는
                // 이메일 로그인에서만 입력 흐름과 너무 멀어져 이 화면에서는 쓰지 않는다.
                inlineFooter
            }
        } footer: {
            EmptyView()
        }
    }

    /// 로그인 / 새 계정 만들기는 하나의 세그먼트다 — 떨어진 버튼 2개로 보이면 서로 다른 동작처럼 읽힌다
    private var modeSegments: some View {
        HStack(spacing: 0) {
            segment(title: "로그인", isSelected: !isRegistration, identifier: "auth.email.mode.signIn") {
                if isRegistration { signInAction() }
            }
            Divider().overlay(MoyeoTheme.line).frame(width: 1)
            segment(title: "새 계정 만들기", isSelected: isRegistration, identifier: "auth.email.mode.create") {
                if !isRegistration { createAccountAction() }
            }
        }
        .frame(height: 48)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                .stroke(MoyeoTheme.line, lineWidth: 1)
        }
    }

    private func segment(
        title: String,
        isSelected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .heavy : .semibold))
                .foregroundStyle(isSelected ? MoyeoTheme.forest : MoyeoTheme.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isSelected ? MoyeoTheme.leaf : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private var registrationFields: some View {
        AuthLabeledField(label: "비밀번호 확인") {
            AuthSecureField(
                title: "비밀번호를 다시 입력",
                text: $passwordConfirmation,
                accessibilityIdentifier: "auth.email.passwordConfirmation",
                contentType: nil
            )
        }
        if showsMismatch {
            Text("비밀번호가 서로 같지 않아요.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MoyeoTheme.coral)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("auth.email.passwordMismatch")
        }
    }

    private var inlineFooter: some View {
        VStack(spacing: 10) {
            AuthPrimaryButton(
                title: isSubmitting ? "확인하고 있어요..." : (isRegistration ? "새 계정 만들기" : "로그인"),
                accessibilityIdentifier: "auth.email.submit",
                action: submitAction
            )
            .disabled(!canSubmit || isSubmitting)

            Text("이메일 인증 후에도 가입 진행 단계는 서버 응답에 따라 이어집니다.")
                .font(.caption)
                .foregroundStyle(MoyeoTheme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("auth.email.progressNotice")
        }
    }
}

/// 이메일 로그인·가입 입력 규칙. 화면에서 분리해 단위 테스트로 검증한다.
/// (SecureField 는 한 글자마다 포커스를 잃어 UI 테스트로 비밀번호 조합을 재현할 수 없다.)
enum EmailCredentialsPolicy {
    static let minimumPasswordLength = 6

    static func canSubmit(
        email: String,
        password: String,
        passwordConfirmation: String,
        isRegistration: Bool
    ) -> Bool {
        guard email.contains("@"), password.count >= minimumPasswordLength else { return false }
        return !isRegistration || password == passwordConfirmation
    }

    static func showsPasswordMismatch(password: String, passwordConfirmation: String) -> Bool {
        !passwordConfirmation.isEmpty && password != passwordConfirmation
    }
}

/// 인풋 위에 붙는 필드 라벨.
struct AuthLabeledField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AuthPasswordResetView: View {
    @Binding var email: String
    let isSubmitting: Bool
    let errorMessage: String?
    let successMessage: String?
    let submitAction: () -> Void

    var body: some View {
        AuthStepContainer(title: "비밀번호 재설정", subtitle: "가입한 이메일로 재설정 링크를 보내드려요.") {
            VStack(spacing: 12) {
                AuthEmailField(text: $email, accessibilityIdentifier: "auth.reset.email")
                if let errorMessage {
                    AuthInlineError(message: errorMessage, accessibilityIdentifier: "auth.reset.error")
                }
                if let successMessage {
                    Label(successMessage, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MoyeoTheme.forest)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("auth.reset.success")
                }
            }
        } footer: {
            AuthPrimaryButton(
                title: isSubmitting ? "메일을 보내고 있어요..." : "재설정 메일 보내기",
                accessibilityIdentifier: "auth.reset.submit",
                action: submitAction
            )
            .disabled(!email.contains("@") || isSubmitting)
        }
    }
}

private struct AuthEmailField: View {
    @Binding var text: String
    let accessibilityIdentifier: String

    var body: some View {
        HStack(spacing: 10) {
            TextField("name@example.com", text: $text)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
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
