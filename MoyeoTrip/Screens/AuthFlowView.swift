import SwiftUI

struct AuthFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AuthFlowViewModel
    @State private var onboardingIndex = 0
    @State private var nickname = ""
    @State private var selectedBirthdate: AuthBirthdate?
    @State private var selectedGender: AuthGender?
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var selectedProfileImageID: Int64?

    private let onComplete: () -> Void
    private let allowsDismissal: Bool
    private let shouldRestoreSession: Bool

    init(
        dependencies: AuthFlowDependencies? = nil,
        allowsDismissal: Bool = true,
        onComplete: @escaping () -> Void = {}
    ) {
        let model = AuthFlowViewModel(dependencies: dependencies)
        let showsProviderListForUITest = ProcessInfo.processInfo.arguments.contains("UITEST_AUTH_PROVIDER_LIST")
        if !allowsDismissal {
            model.stage = .splash
        } else if showsProviderListForUITest {
            model.stage = .login
        }
        _viewModel = StateObject(wrappedValue: model)
        self.allowsDismissal = allowsDismissal
        shouldRestoreSession = !showsProviderListForUITest
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.stage != .splash {
                AuthFlowHeader(
                    label: headerProgress.label,
                    currentStep: headerProgress.current,
                    totalSteps: headerProgress.total,
                    showsBackButton: showsBackButton,
                    showsCloseButton: allowsDismissal,
                    backAction: moveBack,
                    closeAction: dismiss.callAsFunction
                )
            }

            stageContent
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeInOut(duration: 0.22), value: viewModel.stage)
        .task {
            guard shouldRestoreSession else { return }
            if await viewModel.restoreSession() {
                completeFlow()
            }
        }
    }

    private var showsBackButton: Bool {
        guard !allowsDismissal else { return true }
        switch viewModel.stage {
        case .splash, .profileImage:
            return false
        case .onboarding:
            return onboardingIndex > 0
        default:
            return true
        }
    }

    @ViewBuilder
    private var stageContent: some View {
        switch viewModel.stage {
        case .splash:
            AuthFlowSplashView()
        case .onboarding:
            AuthOnboardingView(index: $onboardingIndex) {
                viewModel.stage = .login
            }
        case .login:
            AuthLoginView(
                loadingProvider: viewModel.loadingProvider,
                errorMessage: viewModel.errorMessage
            ) { provider in
                if provider == .email {
                    viewModel.stage = .emailLogin
                    return
                }
                Task {
                    if await viewModel.authenticate(with: provider) {
                        completeFlow()
                    }
                }
            }
        case .emailLogin:
            AuthEmailCredentialsView(
                mode: .signIn,
                email: $email,
                password: $password,
                passwordConfirmation: $passwordConfirmation,
                isSubmitting: viewModel.isSubmittingEmail,
                errorMessage: viewModel.errorMessage,
                submitAction: { authenticateEmail(mode: .signIn) },
                createAccountAction: {
                    viewModel.clearError()
                    password = ""
                    passwordConfirmation = ""
                    viewModel.stage = .emailRegistration
                },
                forgotPasswordAction: {
                    viewModel.clearError()
                    viewModel.stage = .passwordReset
                }
            )
        case .emailRegistration:
            AuthEmailCredentialsView(
                mode: .createAccount,
                email: $email,
                password: $password,
                passwordConfirmation: $passwordConfirmation,
                isSubmitting: viewModel.isSubmittingEmail,
                errorMessage: viewModel.errorMessage,
                submitAction: { authenticateEmail(mode: .createAccount) },
                createAccountAction: {},
                forgotPasswordAction: {}
            )
        case .passwordReset:
            AuthPasswordResetView(
                email: $email,
                isSubmitting: viewModel.isSubmittingEmail,
                errorMessage: viewModel.errorMessage,
                successMessage: viewModel.passwordResetMessage
            ) {
                Task { await viewModel.resetPassword(email: email) }
            }
        case .nickname:
            AuthNicknameView(
                nickname: $nickname,
                provider: viewModel.nicknameProvider,
                initialResponse: viewModel.nicknameResponse
            ) { nickname, selectionToken in
                viewModel.prepareSignup(nickname: nickname, selectionToken: selectionToken)
            }
        case .basics:
            AuthBasicsView(
                selectedBirthdate: $selectedBirthdate,
                selectedGender: $selectedGender,
                isSubmitting: viewModel.isSubmittingSignup,
                errorMessage: viewModel.errorMessage
            ) {
                submitSignup()
            }
        case .profileImage:
            AuthProfileImageView(
                nickname: viewModel.selectedNicknameForProfile,
                nicknameCandidate: viewModel.selectedNicknameCandidateForProfile,
                candidates: viewModel.profileImages,
                selectedCandidateID: $selectedProfileImageID,
                remainingGenerationCount: viewModel.remainingProfileGenerations,
                isLoading: viewModel.isLoadingProfileImages,
                isGenerating: viewModel.isGeneratingProfileImage,
                selectingImageID: viewModel.selectingProfileImageID,
                errorMessage: viewModel.errorMessage,
                retryAction: { Task { await viewModel.loadProfileImages() } },
                generateAction: { Task { await viewModel.generateProfileImage() } },
                confirmAction: {
                    guard let selectedProfileImageID,
                          let candidate = viewModel.profileImages.first(where: { $0.id == selectedProfileImageID }) else {
                        return
                    }
                    Task {
                        if await viewModel.selectProfileImage(candidate) {
                            completeFlow()
                        }
                    }
                }
            )
        }
    }

    private func submitSignup() {
        guard let selectedGender, let selectedBirthdate else { return }
        Task {
            await viewModel.submitSignup(gender: selectedGender, birthdate: selectedBirthdate)
        }
    }

    private func authenticateEmail(mode: AuthEmailMode) {
        Task {
            if await viewModel.authenticateEmail(email: email, password: password, mode: mode) {
                completeFlow()
            }
        }
    }

    private func completeFlow() {
        onComplete()
        if allowsDismissal {
            dismiss()
        }
    }

    private func moveBack() {
        guard !viewModel.isBusy else { return }
        viewModel.clearError()
        switch viewModel.stage {
        case .splash:
            dismissIfAllowed()
        case .onboarding:
            moveBackFromOnboarding()
        case .login:
            viewModel.stage = .onboarding
        case .emailLogin:
            viewModel.stage = .login
        case .emailRegistration, .passwordReset:
            viewModel.stage = .emailLogin
        case .nickname:
            viewModel.stage = .login
        case .basics:
            viewModel.stage = .nickname
        case .profileImage:
            dismissIfAllowed()
        }
    }

    private func moveBackFromOnboarding() {
        if onboardingIndex > 0 {
            onboardingIndex -= 1
        } else {
            dismissIfAllowed()
        }
    }

    private func dismissIfAllowed() {
        guard allowsDismissal else { return }
        dismiss()
    }

    private var headerProgress: AuthHeaderProgress {
        switch viewModel.stage {
        case .splash:
            return AuthHeaderProgress(label: "", current: 0, total: 7)
        case .onboarding:
            return AuthHeaderProgress(label: "온보딩", current: onboardingIndex + 1, total: 7)
        case .login:
            return AuthHeaderProgress(label: "로그인", current: 4, total: 7)
        case .emailLogin, .emailRegistration, .passwordReset:
            return AuthHeaderProgress(label: "이메일 로그인", current: 4, total: 7)
        case .nickname:
            return AuthHeaderProgress(label: "프로필 설정", current: 5, total: 7)
        case .basics:
            return AuthHeaderProgress(label: "프로필 설정", current: 6, total: 7)
        case .profileImage:
            return AuthHeaderProgress(label: "프로필 설정", current: 7, total: 7)
        }
    }
}

private struct AuthHeaderProgress {
    let label: String
    let current: Int
    let total: Int
}

private struct AuthFlowHeader: View {
    let label: String
    let currentStep: Int
    let totalSteps: Int
    let showsBackButton: Bool
    let showsCloseButton: Bool
    let backAction: () -> Void
    let closeAction: () -> Void

    var body: some View {
        VStack(spacing: 9) {
            HStack {
                if showsBackButton {
                    Button(action: backAction) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(MoyeoTheme.ink)
                            .frame(width: 38, height: 38)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("이전")
                    .accessibilityIdentifier("auth.back")
                } else {
                    Color.clear
                        .frame(width: 38, height: 38)
                }

                Spacer()

                if showsCloseButton {
                    Button(action: closeAction) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(MoyeoTheme.muted)
                            .frame(width: 38, height: 38)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("닫기")
                    .accessibilityIdentifier("auth.close")
                } else {
                    Color.clear
                        .frame(width: 38, height: 38)
                }
            }

            HStack {
                Text(label)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.forest)
                    .accessibilityIdentifier("auth.header.label")

                Spacer()

                Text("\(currentStep)/\(totalSteps)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.muted)
                    .accessibilityIdentifier("auth.header.step")
            }

            ProgressBar(value: Double(currentStep) / Double(totalSteps))
                .accessibilityIdentifier("auth.progress")
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 12)
        .background(MoyeoTheme.background)
    }
}
