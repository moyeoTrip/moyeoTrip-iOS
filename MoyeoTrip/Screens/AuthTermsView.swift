import SwiftUI

/// 약관 동의 — **서버가 주는 목록을 그대로 그린다.**
///
/// 클라가 약관 목록을 갖지 않는다. 서버에서 약관이 늘거나 줄면 화면도 따라 바뀐다.
/// 동의한 `termId` 를 회원가입 요청의 `agreedTermIds` 로 보낸다 —
/// 보내지 않으면 서버가 400 `40012` 로 가입을 막는다.
///
/// **만 18세 이상**은 서버 약관이 아니라 별도 확인이다. 서버는 `birthDate` 로 나이를 검증하고
/// 약관 목록에는 연령 항목이 없다. 화면기획이 이 확인을 요구하므로 목록과 분리해 맨 위에 둔다.
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
                    title: "만 18세 이상",
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
                    kind: LegalDocumentKind(serverTitle: term.title),
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
