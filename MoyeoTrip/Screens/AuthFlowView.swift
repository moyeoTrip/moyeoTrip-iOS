import SwiftUI

enum AuthDirectScreen: String, Hashable {
    case onboarding1
    case onboarding2
    case onboarding3
    case login
    case emailLogin
    /// 08-H 비밀번호 재설정. 08-A 의 `비밀번호를 잊으셨나요?` 가 가는 곳이다 —
    /// 로그인하지 못하는 사람이 스스로 풀 수 있는 유일한 길이라 캡처 라우트도 따로 둔다.
    case passwordReset
    case nickname
    case profileBasic
    case profileTaste
    /// 약관 동의. 실제 가입 플로우의 단계를 그대로 연다 — 캡처 전용 화면을 따로 두지 않는다.
    case profileTerms
    case profileImage
}

struct AuthFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AuthFlowViewModel
    @State private var onboardingIndex = 0
    @State private var nickname = ""
    @State private var selectedBirthdate: AuthBirthdate?
    @State private var selectedGender: AuthGender?
    // 아무것도 고르지 않은 상태로 시작한다. 미리 골라두면 사용자가 고르지 않은 취향이
    // 본인 것으로 저장된다.
    // 담는 값은 **서버 id** 다. 라벨로 담으면 가입 요청에서 다시 id 를 찾아야 하고,
    // 표기가 조금만 달라도 선택이 통째로 유실된다 (정본 R4).
    @State private var selectedTravelStyles: Set<Int64> = []
    @State private var selectedInterestRegions: Set<Int64> = []
    /// 06-1 후보는 서버가 준다 (`GET /users/me/profile/options` · 토큰 없이 200).
    @StateObject private var tasteOptions = AuthTasteOptionsModel()
    @State private var agreedTermIDs: Set<Int64> = []
    @State private var confirmedMinimumAge = false
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var selectedProfileImageID: Int64?

    private let onComplete: () -> Void
    private let allowsDismissal: Bool
    private let shouldRestoreSession: Bool
    /// 화면을 직접 지정해 연 진입인지 — 캡처·QA 경로다.
    /// 정본 R2(40919 는 조용히 다음으로)를 여기서도 적용하면 화면이 홈으로 튀어
    /// 07 자리에 홈이 찍힌다. 안드로이드·웹도 같은 이유로 이 경로만 예외를 둔다.
    private let isDirectEntry: Bool

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
        // 생년월일도 사용자가 직접 고르는 값이다. 캡처 진입에서도 미리 채우지 않는다 —
        // 채워두면 캡처가 실제 첫 화면이 아니라 값이 들어간 화면을 찍는다.
        _selectedBirthdate = State(initialValue: nil)
        // 성별은 사용자가 직접 고르는 값이다. 화면기획·웹과 같이 진입 시점에는 아무것도 고르지 않은 상태.
        _selectedGender = State(initialValue: nil)
        self.allowsDismissal = allowsDismissal
        shouldRestoreSession = directScreen == nil && !showsProviderListForUITest
        isDirectEntry = directScreen != nil
        self.onComplete = onComplete
    }

    // 캡처 라우트 카탈로그라 분기가 화면 수만큼 늘어난다 — 쪼개면 오히려 찾기 어려워진다.
    // swiftlint:disable:next cyclomatic_complexity
    nonisolated private static func directConfiguration(
        _ screen: AuthDirectScreen
    ) -> (stage: AuthFlowStage, onboardingIndex: Int) {
        switch screen {
        case .onboarding1: (.onboarding, 0)
        case .onboarding2: (.onboarding, 1)
        case .onboarding3: (.onboarding, 2)
        case .login: (.login, 0)
        case .emailLogin: (.emailLogin, 0)
        case .passwordReset: (.passwordReset, 0)
        case .nickname: (.nickname, 0)
        case .profileBasic: (.basics, 0)
        case .profileTaste: (.taste, 0)
        case .profileTerms: (.terms, 0)
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
            // 직접 진입(캡처·QA)은 세션 복원을 타지 않는다 — 복원은 refreshToken 을 요구하는데
            // 캡처 세션에는 그 값이 없다(`UITestRuntime.prepareLiveSessionIfNeeded`).
            // 대신 라이브 캡처에서는 심어 둔 **액세스 토큰만** 채택해 07 이 서버 응답을 그린다.
            // 토큰이 없으면(목 캡처·실사용) 아무것도 부르지 않는다 — 부르면
            // `로그인 정보가 완전하지 않아요` 오류 배너만 뜬다.
            if isDirectEntry {
                guard viewModel.adoptLiveCaptureSessionIfNeeded() else { return }
                if viewModel.stage == .profileImage {
                    await viewModel.loadProfileImages()
                }
                return
            }
            guard shouldRestoreSession else { return }
            if await viewModel.restoreSession() {
                completeFlow()
            }
        }
        // 프로필 이미지 API 가 `40919`("이미 설정 완료")로 답하면 오류 대신 그냥 넘어간다 (정본 R2).
        .onChange(of: viewModel.signupDidComplete) { _, didComplete in
            guard didComplete, !isDirectEntry else { return }
            completeFlow()
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
        case .emailLogin, .emailRegistration:
            // 로그인/가입을 따로 고르지 않는다 — 한 번 시도하고 계정이 없으면 그대로 만든다.
            AuthEmailCredentialsView(
                email: $email,
                password: $password,
                isSubmitting: viewModel.isSubmittingEmail,
                errorMessage: viewModel.errorMessage,
                submitAction: { authenticateEmail() },
                forgotPasswordAction: {
                    viewModel.clearError()
                    viewModel.stage = .passwordReset
                }
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
                options: tasteOptions,
                isSubmitting: viewModel.isSubmittingSignup,
                errorMessage: viewModel.errorMessage,
                backAction: { moveBack() },
                continueAction: { viewModel.stage = .terms }
            )
        case .terms:
            termsStep
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

    private func authenticateEmail() {
        Task {
            if await viewModel.authenticateEmail(email: email, password: password) {
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
        if viewModel.stage == .onboarding {
            moveBackFromOnboarding()
        } else if let previous = Self.previousStage(before: viewModel.stage) {
            viewModel.stage = previous
        } else {
            dismissIfAllowed()
        }
    }

    /// 뒤로 갈 단계. `nil` 이면 플로우를 닫는다.
    nonisolated private static func previousStage(before stage: AuthFlowStage) -> AuthFlowStage? {
        switch stage {
        case .splash, .onboarding, .profileImage: nil
        case .login: .onboarding
        case .emailLogin: .login
        case .emailRegistration, .passwordReset: .emailLogin
        case .nickname: .login
        case .basics: .nickname
        case .taste: .basics
        case .terms: .taste
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
        case .terms:
            // 약관 동의는 프로필 8단계 밖의 보조 화면이다 — 안드로이드와 같이 프로그레스를 그리지 않는다.
            return nil
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

// MARK: - 약관 단계

private extension AuthFlowView {
    func submitSignup() {
        guard let selectedGender, let selectedBirthdate else { return }
        Task {
            await viewModel.submitSignup(
                gender: selectedGender,
                birthdate: selectedBirthdate,
                travelStyleIds: selectedTravelStyles.sorted(),
                interestedRegionIds: selectedInterestRegions.sorted(),
                agreedTermIds: agreedTermIDs.sorted()
            )
        }
    }

    var termsStep: some View {
        AuthTermsView(
            terms: viewModel.serverTerms,
            isLoading: viewModel.isLoadingTerms,
            loadFailed: viewModel.termsLoadFailed,
            agreedTermIDs: $agreedTermIDs,
            confirmedMinimumAge: $confirmedMinimumAge,
            isSubmitting: viewModel.isSubmittingSignup,
            errorMessage: viewModel.errorMessage,
            retryAction: { Task { await viewModel.loadTerms() } },
            finishAction: { submitSignup() }
        )
    }
}
