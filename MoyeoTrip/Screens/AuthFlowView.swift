import SwiftUI

enum AuthDirectScreen: String, Hashable {
    case onboarding1
    case onboarding2
    case onboarding3
    case login
    case emailLogin
    case nickname
    case profileBasic
    case profileTaste
    case profileImage
}

struct AuthFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AuthFlowViewModel
    @State private var onboardingIndex = 0
    @State private var nickname = ""
    @State private var selectedBirthdate: AuthBirthdate?
    @State private var selectedGender: AuthGender?
    @State private var selectedTravelStyles = TravelTasteSelection.defaultStyles
    @State private var selectedInterestRegions = TravelTasteSelection.defaultInterestRegions
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
        directScreen: AuthDirectScreen? = nil,
        onComplete: @escaping () -> Void = {}
    ) {
        let model = AuthFlowViewModel(dependencies: dependencies)
        let showsProviderListForUITest = ProcessInfo.processInfo.arguments.contains("UITEST_AUTH_PROVIDER_LIST")
        let directConfiguration = directScreen.map(Self.directConfiguration)
        if let directConfiguration {
            model.stage = directConfiguration.stage
        } else if !allowsDismissal {
            model.stage = .splash
        } else if showsProviderListForUITest {
            model.stage = .login
        }
        _viewModel = StateObject(wrappedValue: model)
        _onboardingIndex = State(initialValue: directConfiguration?.onboardingIndex ?? 0)
        // 닉네임은 사용자가 후보에서 직접 고르는 값이다. 화면기획·웹·안드로이드와 같이 진입 시점에는
        // 아무 후보도 선택되지 않은 상태여야 하고, 그래서 "다음" CTA도 비활성으로 시작한다.
        _nickname = State(initialValue: "")
        _selectedBirthdate = State(initialValue: directScreen == .profileBasic ? .april1998 : nil)
        // 성별은 사용자가 직접 고르는 값이다. 화면기획·웹과 같이 진입 시점에는 아무것도 고르지 않은 상태.
        _selectedGender = State(initialValue: nil)
        self.allowsDismissal = allowsDismissal
        shouldRestoreSession = directScreen == nil && !showsProviderListForUITest
        self.onComplete = onComplete
    }

    nonisolated private static func directConfiguration(
        _ screen: AuthDirectScreen
    ) -> (stage: AuthFlowStage, onboardingIndex: Int) {
        switch screen {
        case .onboarding1: (.onboarding, 0)
        case .onboarding2: (.onboarding, 1)
        case .onboarding3: (.onboarding, 2)
        case .login: (.login, 0)
        case .emailLogin: (.emailLogin, 0)
        case .nickname: (.nickname, 0)
        case .profileBasic: (.basics, 0)
        case .profileTaste: (.taste, 0)
        case .profileImage: (.profileImage, 0)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.stage != .splash {
                AuthFlowHeader(
                    progress: headerProgress,
                    showsBackButton: showsBackButton,
                    backAction: moveBack,
                    skipAction: skipAction
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
                signInAction: {},
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
                signInAction: {
                    viewModel.clearError()
                    password = ""
                    passwordConfirmation = ""
                    viewModel.stage = .emailLogin
                },
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
                nickname: viewModel.selectedNicknameForProfile,
                nicknameCandidate: viewModel.selectedNicknameCandidateForProfile,
                selectedBirthdate: $selectedBirthdate,
                selectedGender: $selectedGender,
                errorMessage: viewModel.errorMessage,
                backAction: { moveBack() },
                continueAction: { viewModel.stage = .taste }
            )
        case .taste:
            AuthTravelTasteView(
                selectedTravelStyles: $selectedTravelStyles,
                selectedInterestRegions: $selectedInterestRegions,
                isSubmitting: viewModel.isSubmittingSignup,
                errorMessage: viewModel.errorMessage,
                backAction: { moveBack() },
                continueAction: { submitSignup() }
            )
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
        case .taste:
            viewModel.stage = .basics
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

    // 온보딩에서만 오른쪽에 건너뛰기를 둔다. 화면기획·웹 헤더에는 닫기(X)가 없다.
    private var skipAction: (() -> Void)? {
        guard viewModel.stage == .onboarding else { return nil }
        return { viewModel.stage = .login }
    }

    private var headerProgress: AuthHeaderProgress? {
        switch viewModel.stage {
        case .splash:
            return nil
        case .onboarding:
            return AuthHeaderProgress(label: "온보딩", current: onboardingIndex + 1, total: 8)
        case .login:
            return AuthHeaderProgress(label: "로그인", current: 4, total: 8)
        case .emailLogin, .emailRegistration, .passwordReset:
            // 화면기획·웹의 이메일 화면은 8단계 프로그레스를 두지 않는 보조 화면이다.
            return nil
        case .nickname:
            return AuthHeaderProgress(label: "프로필 설정", current: 5, total: 8)
        case .basics:
            return AuthHeaderProgress(label: "프로필 설정", current: 6, total: 8)
        case .taste:
            return AuthHeaderProgress(label: "프로필 설정", current: 7, total: 8)
        case .profileImage:
            return AuthHeaderProgress(label: "프로필 설정", current: 8, total: 8)
        }
    }
}

private struct AuthHeaderProgress {
    let label: String
    let current: Int
    let total: Int
}

private struct AuthFlowHeader: View {
    let progress: AuthHeaderProgress?
    let showsBackButton: Bool
    let backAction: () -> Void
    let skipAction: (() -> Void)?

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

                if let skipAction {
                    Button("건너뛰기", action: skipAction)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MoyeoTheme.muted)
                        .buttonStyle(.plain)
                        .frame(height: 38)
                        .accessibilityIdentifier("auth.skip")
                } else {
                    Color.clear
                        .frame(width: 38, height: 38)
                }
            }

            // 단계 라벨은 8단계 프로그레스와 한 쌍이다. 프로그레스가 없는 보조 화면에서는 그리지 않는다.
            if let progress {
                HStack {
                    Text(progress.label)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.forest)
                        .accessibilityIdentifier("auth.header.label")

                    Spacer()

                    Text("\(progress.current)/\(progress.total)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MoyeoTheme.muted)
                        .accessibilityIdentifier("auth.header.step")
                }

                ProgressBar(value: Double(progress.current) / Double(progress.total))
                    .accessibilityIdentifier("auth.progress")
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 12)
        .background(MoyeoTheme.background)
    }
}
