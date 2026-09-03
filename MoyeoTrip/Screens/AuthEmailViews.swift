import SwiftUI

/// 이메일로 시작하기.
///
/// **로그인/새 계정 만들기를 사용자가 먼저 고르지 않는다.** 이메일이 이미 있는 계정인지
/// 사용자가 알아야 할 이유가 없다. 소셜 로그인과 같이 한 번 시도하고, 계정이 없으면
/// 그대로 새 계정을 만들어 서버가 알려주는 가입 단계로 이어간다.
struct AuthEmailCredentialsView: View {
    @Binding var email: String
    @Binding var password: String
    let isSubmitting: Bool
    let errorMessage: String?
    let submitAction: () -> Void
    let forgotPasswordAction: () -> Void

    private var canSubmit: Bool {
        EmailCredentialsPolicy.canSubmit(email: email, password: password)
    }

    var body: some View {
        AuthStepContainer(
            title: "이메일로 시작하기",
            subtitle: "이메일과 비밀번호를 입력하면 로그인하거나 새 계정을 만들어요.",
            showsFooterInset: false
        ) {
            VStack(spacing: 22) {
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

                    Button("비밀번호를 잊으셨나요?", action: forgotPasswordAction)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MoyeoTheme.forest)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityIdentifier("auth.email.forgotPassword")

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

    private var inlineFooter: some View {
        VStack(spacing: 10) {
            AuthPrimaryButton(
                title: isSubmitting ? "확인하고 있어요..." : "계속하기",
                accessibilityIdentifier: "auth.email.submit",
                action: submitAction
            )
            .disabled(!canSubmit || isSubmitting)

            Text("처음 쓰는 이메일이면 새 계정을 만들고, 가입 진행 단계는 서버 응답에 따라 이어집니다.")
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

    /// 로그인/가입을 따로 고르지 않으므로 "비밀번호 확인" 입력이 없다 —
    /// 로그인일 수도 있는 입력에 확인란을 요구할 수 없다.
    static func canSubmit(email: String, password: String) -> Bool {
        email.contains("@") && password.count >= minimumPasswordLength
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

/// 08-H 비밀번호 재설정. 08-A 이메일 로그인의 `비밀번호를 잊으셨나요?` 에서 온다.
///
/// 로그인하지 못하는 사람이 스스로 풀 수 있는 **유일한 길**이라, 없으면 문의 말고는 방법이 없다.
/// 메일을 보낸 뒤에도 화면을 닫지 않는다 — 메일이 안 오면 다시 보낼 곳이 필요하다 (기획 주석).
///
/// 근거: Firebase 비밀번호 재설정 메일 (`Auth.auth().sendPasswordReset`). 서버 API 가 아니다.
struct AuthPasswordResetView: View {
    @Binding var email: String
    let isSubmitting: Bool
    let errorMessage: String?
    let successMessage: String?
    let submitAction: () -> Void

    private var isSent: Bool { successMessage != nil }

    var body: some View {
        AuthStepContainer(
            title: isSent ? "메일을 보냈어요" : "가입하신 이메일을 알려주세요",
            subtitle: isSent
                ? "\(email) 으로 재설정 링크를 보냈어요.\n메일함을 확인해 주세요."
                : "비밀번호를 새로 정할 수 있는 링크를 보내드려요."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if !isSent {
                    AuthEmailField(text: $email, accessibilityIdentifier: "auth.reset.email")
                }
                if let errorMessage {
                    AuthInlineError(message: errorMessage, accessibilityIdentifier: "auth.reset.error")
                }
                AttachNoteBox(lines: isSent
                    ? [
                        "링크는 1시간 동안만 쓸 수 있어요.",
                        "메일이 안 보이면 스팸함도 확인해 주세요."
                    ]
                    : [
                        "카카오로 가입하셨다면 비밀번호가 없어요. 로그인 화면에서 카카오로 다시 들어와 주세요."
                    ])
                if isSent {
                    Button("다시 보내기", action: submitAction)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.forest)
                        .disabled(isSubmitting)
                        .accessibilityIdentifier("auth.reset.resend")
                }
            }
            .accessibilityIdentifier("auth.reset.body")
        } footer: {
            AuthPrimaryButton(
                title: isSubmitting ? "메일을 보내고 있어요..." : "재설정 링크 보내기",
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
            // 플레이스홀더를 직접 그린다.
            //
            // `textContentType(.emailAddress)` 가 붙은 TextField 는 iOS 가 자동완성 표시색(파랑)으로
            // 플레이스홀더를 그려서, 회색인 비밀번호 칸·안드로이드·웹과 색이 어긋났다.
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(verbatim: "name@example.com")
                        .foregroundStyle(MoyeoTheme.muted)
                        .allowsHitTesting(false)
                }
                TextField("", text: $text)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(MoyeoTheme.ink)
                    .accessibilityLabel("이메일")
                    .accessibilityIdentifier(accessibilityIdentifier)
            }
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
