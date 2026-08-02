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
    let forgotPasswordAction: () -> Void

    private var isRegistration: Bool { mode == .createAccount }
    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6 && (!isRegistration || password == passwordConfirmation)
    }

    var body: some View {
        AuthStepContainer(
            title: isRegistration ? "이메일로 새 계정 만들기" : "이메일로 로그인",
            subtitle: isRegistration ? "사용할 이메일과 비밀번호를 입력해주세요." : "가입한 이메일로 다시 만나요."
        ) {
            VStack(spacing: 12) {
                AuthEmailField(text: $email, accessibilityIdentifier: "auth.email.address")
                AuthSecureField(
                    title: "비밀번호",
                    text: $password,
                    accessibilityIdentifier: "auth.email.password"
                )

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
        } footer: {
            footer
        }
    }

    @ViewBuilder
    private var registrationFields: some View {
        AuthSecureField(
            title: "비밀번호 확인",
            text: $passwordConfirmation,
            accessibilityIdentifier: "auth.email.passwordConfirmation"
        )
        if !passwordConfirmation.isEmpty, password != passwordConfirmation {
            Text("비밀번호가 서로 같지 않아요.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MoyeoTheme.coral)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("auth.email.passwordMismatch")
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            AuthPrimaryButton(
                title: isSubmitting ? "확인하고 있어요..." : (isRegistration ? "새 계정 만들기" : "로그인"),
                systemImage: isRegistration ? "person.badge.plus" : "arrow.right.circle.fill",
                accessibilityIdentifier: "auth.email.submit",
                action: submitAction
            )
            .disabled(!canSubmit || isSubmitting)
            .opacity(canSubmit && !isSubmitting ? 1 : 0.44)

            if !isRegistration {
                AuthSecondaryButton(
                    title: "이메일로 새 계정 만들기",
                    systemImage: "person.badge.plus",
                    accessibilityIdentifier: "auth.email.createAccount",
                    action: createAccountAction
                )
            }
        }
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
                systemImage: "paperplane.fill",
                accessibilityIdentifier: "auth.reset.submit",
                action: submitAction
            )
            .disabled(!email.contains("@") || isSubmitting)
            .opacity(email.contains("@") && !isSubmitting ? 1 : 0.44)
        }
    }
}

private struct AuthEmailField: View {
    @Binding var text: String
    let accessibilityIdentifier: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "envelope.fill")
                .foregroundStyle(MoyeoTheme.forest)
                .frame(width: 22)
            TextField("이메일", text: $text)
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
