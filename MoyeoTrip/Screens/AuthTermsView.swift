import SwiftUI

/// 약관 동의 — **서버가 주는 목록을 그대로 그린다.**
///
/// 클라가 약관 목록을 갖지 않는다. 서버에서 약관이 늘거나 줄면 화면도 따라 바뀐다.
/// 동의한 `termId` 를 회원가입 요청의 `agreedTermIds` 로 보낸다 —
/// 보내지 않으면 서버가 400 `40012` 로 가입을 막는다.
///
/// **만 N세 이상**은 서버 약관이 아니라 별도 확인이다. 서버는 `birthDate` 로 나이를 검증하고
/// 약관 목록에는 연령 항목이 없다. 화면기획이 이 확인을 요구하므로 목록과 분리해 맨 위에 둔다.
///
/// N 은 `KoreanBirthdatePolicy.minimumSignupAge` 하나에서만 온다 — 서버
/// `AuthService.MINIMUM_SIGNUP_AGE` 를 따르는 값이다. 예전에는 여기만 「만 18세」로 남아
/// 생년월일 피커(당시 20)와 **서로 다른 나이를 말했다** (BE-06 · 2026-09-14 에 19 로 통일).
struct AuthTermsView: View {
    let terms: [ServerTermSummary]
    let isLoading: Bool
    let loadFailed: Bool
    @Binding var agreedTermIDs: Set<Int64>
    @Binding var confirmedMinimumAge: Bool
    let isSubmitting: Bool
    let errorMessage: String?
    let retryAction: () -> Void
    let finishAction: () -> Void
    @State private var selectedTerm: ServerTermSummary?

    private var requiredTermIDs: [Int64] {
        terms.filter(\.required).map(\.termId)
    }

    private var canFinish: Bool {
        !terms.isEmpty
            && confirmedMinimumAge
            && requiredTermIDs.allSatisfy { agreedTermIDs.contains($0) }
    }

    private var didAgreeAll: Bool {
        !terms.isEmpty
            && confirmedMinimumAge
            && terms.allSatisfy { agreedTermIDs.contains($0.termId) }
    }

    var body: some View {
        AuthStepContainer(title: "약관 동의", subtitle: "모여트립 이용을 위해 동의가 필요해요") {
            VStack(spacing: 0) {
                AuthTermButton(
                    title: "모두 동의",
                    subtitle: "선택 항목까지 한 번에 동의",
                    showsRequirement: false,
                    accessibilityIdentifier: "auth.terms.allAgree",
                    isSelected: didAgreeAll
                ) {
                    let turningOff = didAgreeAll
                    confirmedMinimumAge = !turningOff
                    agreedTermIDs = turningOff ? [] : Set(terms.map(\.termId))
                }
                .disabled(terms.isEmpty)

                AuthTermButton(
                    title: "만 \(KoreanBirthdatePolicy.minimumSignupAge)세 이상",
                    subtitle: "필수 항목",
                    isRequired: true,
                    accessibilityIdentifier: "auth.terms.age",
                    isSelected: confirmedMinimumAge
                ) {
                    confirmedMinimumAge.toggle()
                }

                ForEach(terms) { term in
                    AuthTermButton(
                        title: term.displayTitle,
                        subtitle: term.required ? "필수 항목" : "선택 항목",
                        isRequired: term.required,
                        accessibilityIdentifier: "auth.terms.\(term.termId)",
                        detailAction: { selectedTerm = term },
                        isSelected: agreedTermIDs.contains(term.termId),
                        action: { toggle(term.termId) }
                    )
                }

                if isLoading {
                    AuthLoadingRow(message: "약관을 불러오는 중이에요")
                }

                if let errorMessage {
                    AuthInlineError(message: errorMessage, accessibilityIdentifier: "auth.signup.error")
                }

                if loadFailed {
                    Button("약관 다시 불러오기", action: retryAction)
                        .font(MoyeoTypography.font(size: 14, weight: .bold))
                        .foregroundStyle(MoyeoTheme.forest)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("auth.terms.retry")
                }
            }
        } footer: {
            AuthPrimaryButton(
                title: isSubmitting ? "계정을 만들고 있어요..." : "동의하고 시작",
                accessibilityIdentifier: "auth.terms.finish"
            ) {
                finishAction()
            }
            .disabled(!canFinish || isSubmitting)
        }
        .task {
            if terms.isEmpty && !loadFailed { retryAction() }
        }
        .fullScreenCover(item: $selectedTerm) { term in
            NavigationStack {
                LegalDocumentDetailView(
                    // 종류는 서버가 준 `code` 로만 정한다. 제목으로 추측하면 처리방침 자리에
                    // 가입 동의서가 열린다 (QA BE-03). `code` 가 없으면 nil 인 채로 두고,
                    // 본문은 `termId` 로 받으므로 화면은 그대로 그려진다.
                    kind: term.code.flatMap(LegalDocumentKind.init(rawValue:)),
                    entry: .signup,
                    serverTermID: term.termId,
                    onAgree: { agreedTermIDs.insert(term.termId) }
                )
            }
        }
    }

    private func toggle(_ termID: Int64) {
        if agreedTermIDs.contains(termID) {
            agreedTermIDs.remove(termID)
        } else {
            agreedTermIDs.insert(termID)
        }
    }
}

extension ServerTermSummary {
    /// 서버 제목은 "[필수] 모여트립 이용약관" 형태다. 필수/선택 배지를 따로 그리므로 접두사는 뗀다.
    var displayTitle: String {
        title
            .replacingOccurrences(of: "[필수]", with: "")
            .replacingOccurrences(of: "[선택]", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}
