//
//  AuthFlowSteps.swift
//  MoyeoTrip
//

import SwiftUI

struct AuthFlowSplashView: View {
    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .fill(MoyeoTheme.leaf)
                    .frame(width: 104, height: 104)
                Image(systemName: "map.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(MoyeoTheme.forest)
            }

            VStack(spacing: 8) {
                Text("모여트립")
                    .font(.system(size: 31, weight: .heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                Text("함께 떠날 준비를 하고 있어요")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.muted)
            }

            Spacer()

            ProgressView()
                .tint(MoyeoTheme.forest)
                .padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("screen.auth.splash")
    }
}
struct AuthOnboardingView: View {
    @Binding var index: Int
    let finishAction: () -> Void

    private var currentPage: AuthOnboardingPage {
        AuthOnboardingPage.pages[index]
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    AuthOnboardingPageView(page: currentPage)
                        .id(currentPage.id)
                        .accessibilityIdentifier("auth.onboarding.page.\(currentPage.id)")

                    HStack(spacing: 8) {
                        ForEach(AuthOnboardingPage.pages) { page in
                            Circle()
                                .fill(page.id == currentPage.id ? MoyeoTheme.forest : MoyeoTheme.softLine)
                                .frame(
                                    width: page.id == currentPage.id ? 9 : 7,
                                    height: page.id == currentPage.id ? 9 : 7
                                )
                        }
                    }
                    .accessibilityHidden(true)
                }
                .frame(minHeight: 430)
                .padding(.horizontal, 18)
                .padding(.top, 22)
                .padding(.bottom, 24)
            }

            Button(action: advance) {
                Label(
                    currentPage.isLast ? "로그인 시작" : "다음",
                    systemImage: currentPage.isLast ? "arrow.right.circle.fill" : "chevron.right"
                )
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(MoyeoTheme.forest)
                .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("auth.onboarding.next")
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 14)
            .background(MoyeoTheme.background)
        }
    }

    private func advance() {
        if currentPage.isLast {
            finishAction()
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            index += 1
        }
    }
}

struct AuthLoginView: View {
    let loadingProvider: AuthProvider?
    let errorMessage: String?
    let selectProvider: (AuthProvider) -> Void

    var body: some View {
        AuthStepContainer(
            title: "모여트립에 오신 걸 환영해요",
            subtitle: "30초 안에 시작할 수 있어요",
            showsFooterInset: false
        ) {
            VStack(spacing: 12) {
                ForEach(AuthProvider.allCases) { provider in
                    AuthProviderButton(
                        provider: provider,
                        isLoading: loadingProvider == provider,
                        isDisabled: loadingProvider != nil
                    ) {
                        selectProvider(provider)
                    }
                }

                if let errorMessage {
                    AuthInlineError(message: errorMessage, accessibilityIdentifier: "auth.login.error")
                }
            }
        } footer: {
            EmptyView()
        }
    }
}

struct AuthNicknameView: View {
    @Binding var nickname: String
    let continueAction: (String, String) -> Void
    @StateObject private var viewModel: AuthNicknameViewModel

    init(nickname: Binding<String>, continueAction: @escaping (String, String) -> Void) {
        _nickname = nickname
        _viewModel = StateObject(
            wrappedValue: AuthNicknameViewModel(selectedNickname: nickname.wrappedValue)
        )
        self.continueAction = continueAction
    }

    init(
        nickname: Binding<String>,
        provider: AuthNicknameCandidateProviding,
        initialResponse: AuthNicknameCandidatesResponse? = nil,
        continueAction: @escaping (String, String) -> Void
    ) {
        _nickname = nickname
        _viewModel = StateObject(
            wrappedValue: AuthNicknameViewModel(
                provider: provider,
                initialResponse: initialResponse ?? AuthNicknameViewModel.initialResponse,
                selectedNickname: nickname.wrappedValue
            )
        )
        self.continueAction = continueAction
    }

    private var canContinue: Bool {
        !viewModel.isLoading && !viewModel.selectedNickname.isEmpty
    }

    var body: some View {
        AuthStepContainer(
            title: "어떤 친구로 시작할까요?",
            subtitle: "본명 대신 동물 친구로 만나요.\n이름을 고르면 캐릭터를 그려드릴게요."
        ) {
            VStack(spacing: 10) {
                VStack(spacing: 9) {
                    if viewModel.isLoading {
                        ForEach(0..<3, id: \.self) { _ in
                            AuthNicknameSkeletonCard()
                        }
                    } else {
                        ForEach(viewModel.candidates) { candidate in
                            AuthNicknameCandidateButton(
                                candidate: candidate,
                                isSelected: viewModel.selectedNickname == candidate.nickname
                            ) {
                                viewModel.selectNickname(candidate.nickname)
                                nickname = candidate.nickname
                            }
                            .disabled(viewModel.isLoading)
                        }
                    }
                }

                Button {
                    Task { await refreshCandidates() }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(viewModel.isLoading ? "새 이름을 받고 있어요..." : "다른 이름 추천받기")
                    }
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(viewModel.isLoading ? MoyeoTheme.muted : MoyeoTheme.forest)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(viewModel.isLoading ? MoyeoTheme.elevatedCard : MoyeoTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                            .stroke(viewModel.isLoading ? MoyeoTheme.softLine : MoyeoTheme.forest, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canRefresh)
                .opacity(viewModel.canRefresh || viewModel.isLoading ? 1 : 0.44)
                .accessibilityIdentifier("auth.nickname.refresh")

                nicknameRefreshStatus
            }
        } footer: {
            AuthPrimaryButton(
                title: "다음",
                systemImage: "chevron.right",
                accessibilityIdentifier: "auth.nickname.continue"
            ) {
                continueAction(viewModel.selectedNickname, viewModel.selectionToken)
            }
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.44)
        }
    }

    @ViewBuilder
    private var nicknameRefreshStatus: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(MoyeoTheme.coral)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityIdentifier("auth.nickname.refresh.error")
        } else {
            Text("마음에 드는 이름이 나올 때까지 새로 받을 수 있어요")
                .font(.caption)
                .foregroundStyle(MoyeoTheme.muted)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityIdentifier("auth.nickname.refresh.remaining")
        }
    }

    private func refreshCandidates() async {
        if await viewModel.refreshCandidates() {
            nickname = viewModel.selectedNickname
        }
    }
}

struct AuthCharacterView: View {
    let nickname: String
    @Binding var isComplete: Bool
    let continueAction: () -> Void

    var body: some View {
        AuthStepContainer(title: "만나서 반가워요!", subtitle: "한 번 정한 친구는 바꿀 수 없어요") {
            VStack(spacing: 16) {
                AuthAnimalPreview(nickname: nickname, isComplete: isComplete)
            }
        } footer: {
            VStack(spacing: 10) {
                AuthSecondaryButton(
                    title: "캐릭터 생성",
                    systemImage: "wand.and.stars",
                    accessibilityIdentifier: "auth.character.generate"
                ) {
                    isComplete = true
                }

                AuthPrimaryButton(
                    title: "기본정보 입력",
                    systemImage: "checkmark.circle.fill",
                    accessibilityIdentifier: "auth.character.continue"
                ) {
                    continueAction()
                }
                .disabled(!isComplete)
                .opacity(isComplete ? 1 : 0.44)
            }
        }
    }
}

struct AuthBasicsView: View {
    @Binding var selectedBirthdate: AuthBirthdate?
    @Binding var selectedGender: AuthGender?
    var isSubmitting = false
    var errorMessage: String?
    let continueAction: () -> Void

    private var canContinue: Bool {
        selectedBirthdate != nil && selectedGender != nil
    }

    var body: some View {
        AuthStepContainer(title: "기본 정보", subtitle: "생년월일과 성별만 먼저 알려주세요.") {
            VStack(alignment: .leading, spacing: 20) {
                AuthSectionTitle(title: "생년월일")
                DatePicker(
                    "생년월일",
                    selection: Binding(
                        get: { selectedBirthdate?.date ?? AuthBirthdate.april1998.date },
                        set: { selectedBirthdate = AuthBirthdate(date: $0) }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "ko_KR"))
                .frame(maxWidth: .infinity)
                .frame(height: 176)
                .background(MoyeoTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                        .stroke(MoyeoTheme.line, lineWidth: 1)
                }
                .accessibilityLabel("생년월일")
                .accessibilityIdentifier("auth.basic.birthdate")
                .onAppear {
                    if selectedBirthdate == nil {
                        selectedBirthdate = .april1998
                    }
                }

                AuthSectionTitle(title: "성별")
                HStack(spacing: 10) {
                    ForEach(AuthGender.allCases) { gender in
                        AuthPillButton(
                            title: gender.title,
                            accessibilityIdentifier: gender.accessibilityIdentifier,
                            isSelected: selectedGender == gender
                        ) {
                            selectedGender = gender
                        }
                    }
                }

                if let errorMessage {
                    AuthInlineError(message: errorMessage, accessibilityIdentifier: "auth.signup.error")
                }
            }
        } footer: {
            AuthPrimaryButton(
                title: isSubmitting ? "계정을 만들고 있어요..." : "가입하고 프로필 만들기",
                systemImage: isSubmitting ? "hourglass" : "person.crop.circle.badge.plus",
                accessibilityIdentifier: "auth.basic.continue"
            ) {
                continueAction()
            }
            .disabled(!canContinue || isSubmitting)
            .opacity(canContinue && !isSubmitting ? 1 : 0.44)
        }
    }
}

struct AuthTermsView: View {
    @Binding var agreedTerms: Set<AuthTerm>
    let isSubmitting: Bool
    let errorMessage: String?
    let finishAction: () -> Void

    private var canFinish: Bool {
        AuthTerm.requiredTerms.allSatisfy { agreedTerms.contains($0) }
    }

    private var didAgreeAll: Bool {
        AuthTerm.allCases.allSatisfy { agreedTerms.contains($0) }
    }

    var body: some View {
        AuthStepContainer(title: "약관 동의", subtitle: "서비스 이용에 필요한 항목만 먼저 확인해요.") {
            VStack(spacing: 12) {
                AuthTermButton(
                    title: "모두 동의",
                    subtitle: "선택 항목까지 한 번에 동의",
                    accessibilityIdentifier: "auth.terms.allAgree",
                    isSelected: didAgreeAll
                ) {
                    agreedTerms = didAgreeAll ? [] : Set(AuthTerm.allCases)
                }

                ForEach(AuthTerm.allCases) { term in
                    AuthTermButton(
                        title: term.title,
                        subtitle: term.subtitle,
                        isRequired: term.isRequired,
                        accessibilityIdentifier: term.accessibilityIdentifier,
                        isSelected: agreedTerms.contains(term)
                    ) {
                        toggle(term)
                    }
                }

                if let errorMessage {
                    AuthInlineError(message: errorMessage, accessibilityIdentifier: "auth.signup.error")
                }
            }
        } footer: {
            AuthPrimaryButton(
                title: isSubmitting ? "계정을 만들고 있어요..." : "동의하고 프로필 만들기",
                systemImage: isSubmitting ? "hourglass" : "person.crop.circle.badge.plus",
                accessibilityIdentifier: "auth.terms.finish"
            ) {
                finishAction()
            }
            .disabled(!canFinish || isSubmitting)
            .opacity(canFinish && !isSubmitting ? 1 : 0.44)
        }
    }

    private func toggle(_ term: AuthTerm) {
        if agreedTerms.contains(term) {
            agreedTerms.remove(term)
        } else {
            agreedTerms.insert(term)
        }
    }
}

private struct AuthOnboardingPageView: View {
    let page: AuthOnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 16)

            Image(systemName: page.systemImage)
                .font(.system(size: 62, weight: .semibold))
                .foregroundStyle(page.tint)
                .frame(width: 132, height: 132)
                .background(page.tint.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(spacing: 10) {
                Text(page.title)
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                    .multilineTextAlignment(.center)
                Text(page.body)
                    .font(.subheadline)
                    .foregroundStyle(MoyeoTheme.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 28)
        }
        .padding(.horizontal, 20)
    }
}
