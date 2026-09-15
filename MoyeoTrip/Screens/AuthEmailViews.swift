import Combine
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

    /// 형식이 틀렸을 때만 값이 있다. 아직 아무것도 안 썼으면 nil 이라 아무 말도 하지 않는다.
    private var emailValidationMessage: String? {
        EmailCredentialsPolicy.emailValidationMessage(for: email)
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
                    // 왜 「계속하기」가 안 눌리는지 **적어 준다.** 예전에는 `@` 만 있으면
                    // 통과라 형식 오류가 서버까지 가서야 막혔고, 그 전에는 버튼이 회색인
                    // 이유가 화면에 없었다 (IOS-F02·F55).
                    if let emailValidationMessage {
                        Text(emailValidationMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MoyeoTheme.dangerRed)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("auth.email.addressError")
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

    /// 이메일 형식 검사. 예전에는 **`@` 가 들어 있기만 하면** 통과라
    /// `@`·`a@`·`@b`·`a@b`(점 없음)·`a b@c.com`(공백)이 전부 제출됐고,
    /// 서버·Firebase 에서야 막혀 「알 수 없는 오류」로 돌아왔다 (IOS-F02·F55).
    ///
    /// 아주 엄격하게 하지 않는다 — 실제로 쓰이는 주소를 막는 쪽이 더 나쁘다.
    /// **`로컬@도메인.최상위`** 한 벌만 확인하고, 공백·연속 점·양끝 점을 막는다.
    static func isValidEmail(_ email: String) -> Bool {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value == email, !value.isEmpty, value.count <= 254 else { return false }
        guard value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return false }
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        let local = parts[0]
        let domain = parts[1]
        guard !local.isEmpty, local.count <= 64 else { return false }
        guard !domain.isEmpty, !domain.hasPrefix("."), !domain.hasSuffix(".") else { return false }
        guard !value.contains("..") else { return false }
        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, labels.allSatisfy({ !$0.isEmpty }) else { return false }
        // 최상위 도메인은 글자 두 개 이상이어야 한다 (`a@b.c` · `a@b.1` 를 막는다).
        guard let tld = labels.last, tld.count >= 2,
              tld.allSatisfy({ $0.isLetter }) else { return false }
        return true
    }

    /// 형식이 틀렸을 때 화면에 적을 이유. 맞으면 nil 이다.
    static func emailValidationMessage(for email: String) -> String? {
        guard !email.isEmpty else { return nil }
        return isValidEmail(email) ? nil : "이메일 형식을 확인해주세요. 예: name@example.com"
    }

    /// 로그인/가입을 따로 고르지 않으므로 "비밀번호 확인" 입력이 없다 —
    /// 로그인일 수도 있는 입력에 확인란을 요구할 수 없다.
    static func canSubmit(email: String, password: String) -> Bool {
        isValidEmail(email) && password.count >= minimumPasswordLength
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
    /// 한 번이라도 보냈는지. 제목·본문이 「보낸 뒤」 화면으로 바뀌는 기준이다.
    let hasSent: Bool
    /// 재전송 결과. **두 번째 발송부터만** 채워진다 — 첫 발송은 제목이 이미 말한다 (결정 ⑭).
    let resendMessage: String?
    /// 다시 보내기까지 남은 시간(초). 0 이면 지금 보낼 수 있다.
    let resendCooldownRemaining: () -> Int
    let submitAction: () -> Void

    /// 남은 시간을 1초마다 다시 읽어 버튼 문구·활성 상태를 갱신한다.
    @State private var cooldownRemaining = 0

    private let cooldownTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        AuthStepContainer(
            title: hasSent ? "메일을 보냈어요" : "가입하신 이메일을 알려주세요",
            subtitle: hasSent
                ? "\(email) 으로 재설정 링크를 보냈어요.\n메일함을 확인해 주세요."
                : "비밀번호를 새로 정할 수 있는 링크를 보내드려요."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if !hasSent {
                    AuthEmailField(text: $email, accessibilityIdentifier: "auth.reset.email")
                }
                if let errorMessage {
                    AuthInlineError(message: errorMessage, accessibilityIdentifier: "auth.reset.error")
                }
                AttachNoteBox(lines: hasSent
                    ? [
                        "링크는 1시간 동안만 쓸 수 있어요.",
                        "메일이 안 보이면 스팸함도 확인해 주세요."
                    ]
                    : [
                        "카카오로 가입하셨다면 비밀번호가 없어요. 로그인 화면에서 카카오로 다시 들어와 주세요."
                    ])
                if hasSent {
                    // 다시 보냈을 때만 — 화면이 그대로라 달라진 것을 알 수 없기 때문이다 (결정 ⑭).
                    if let resendMessage {
                        Text(resendMessage)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MoyeoTheme.forest)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("auth.reset.result")
                    }
                    // 보낸 뒤 재전송 컨트롤은 **정확히 하나다**(본문). 하단 CTA 를 함께 두면
                    // 같은 일을 하는 버튼이 둘이 돼 서로 다른 일로 읽힌다 (결정 ⑭ · 웹·안드와 같다).
                    Button(resendTitle) {
                        guard canResend else { return }
                        submitAction()
                    }
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(canResend ? MoyeoTheme.forest : MoyeoTheme.muted)
                    .disabled(!canResend)
                    .accessibilityIdentifier("auth.reset.resend")
                }
            }
            .accessibilityIdentifier("auth.reset.body")
            .onReceive(cooldownTicker) { _ in
                cooldownRemaining = resendCooldownRemaining()
            }
        } footer: {
            // 보내기 전에만 그린다.
            if !hasSent {
                AuthPrimaryButton(
                    title: isSubmitting ? "보내는 중..." : "재설정 링크 보내기",
                    accessibilityIdentifier: "auth.reset.submit",
                    action: submitAction
                )
                .disabled(!EmailCredentialsPolicy.isValidEmail(email) || isSubmitting)
            }
        }
    }

    private var canResend: Bool { !isSubmitting && cooldownRemaining == 0 }

    /// 쿨다운 중에도 **「다시 보내기」라는 이름을 남긴다** — 문구를 통째로 바꾸면
    /// 그 버튼이 무슨 버튼인지 사라진다 (결정 ⑭).
    private var resendTitle: String {
        if isSubmitting { return "보내는 중..." }
        guard cooldownRemaining > 0 else { return "다시 보내기" }
        return "다시 보내기 (\(cooldownRemaining)초 후 가능)"
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
