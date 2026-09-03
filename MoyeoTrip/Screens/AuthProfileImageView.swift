import SwiftUI

struct AuthProfileImageView: View {
    let nickname: String?
    let nicknameCandidate: AuthNicknameCandidate?
    let candidates: [AuthProfileImageCandidate]
    @Binding var selectedCandidateID: Int64?
    let remainingGenerationCount: Int
    let isLoading: Bool
    let isGenerating: Bool
    let selectingImageID: Int64?
    let errorMessage: String?
    let retryAction: () -> Void
    let generateAction: () -> Void
    let confirmAction: () -> Void

    var body: some View {
        AuthStepContainer(
            title: "여행에서 만날 내 친구를 골라주세요",
            subtitle: profileSubtitle
        ) {
            VStack(spacing: 14) {
                if isGenerating {
                    ProfileImageGeneratingView(nickname: nickname)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }

                if isLoading && candidates.isEmpty {
                    profileLoadingView
                } else {
                    profileGrid
                }

                if let errorMessage {
                    AuthInlineError(message: errorMessage, accessibilityIdentifier: "auth.profile.error")
                    AuthSecondaryButton(
                        title: "다시 시도",
                        accessibilityIdentifier: "auth.profile.retry",
                        action: retryAction
                    )
                }
            }
        } footer: {
            VStack(spacing: 10) {
                AuthSecondaryButton(
                    title: generateButtonTitle,
                    accessibilityIdentifier: "auth.profile.generate",
                    action: generateAction
                )
                .disabled(!canGenerate)
                .opacity(canGenerate ? 1 : 0.44)

                AuthPrimaryButton(
                    title: "이 친구로 시작하기",
                    accessibilityIdentifier: "auth.profile.confirm",
                    action: confirmAction
                )
                .disabled(selectedCandidateID == nil || selectingImageID != nil || isLoading || isGenerating)
            }
        }
    }

    private var canGenerate: Bool {
        !isGenerating && !isLoading && selectingImageID == nil && remainingGenerationCount > 0
    }

    private var generateButtonTitle: String {
        if isGenerating { return "새 후보를 만들고 있어요..." }
        if remainingGenerationCount == 0 { return "새 후보 생성 기회를 모두 사용했어요" }
        return "새 후보 만들기 · \(remainingGenerationCount)회 남음"
    }

    private var profileSubtitle: String {
        guard let nickname, !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "서버에 저장된 닉네임을 바탕으로 후보를 하나씩 추가해요."
        }
        return "\(nickname) 닉네임을 바탕으로 후보를 하나씩 추가해요. 이전에 만든 후보는 사라지지 않아요."
    }

    private var profileLoadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text("만들어둔 프로필을 확인하고 있어요")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MoyeoTheme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
    }

    // 후보는 항상 수평 배치 — 1개는 가운데(폭 1/3), 2개는 좌우 절반, 3개는 3등분.
    // 카드 래퍼와 "여행 친구 N / 서버에서 생성된 …" 같은 부가 문구는 두지 않는다 (화면기획 기준).
    private var profileGrid: some View {
        Group {
            if candidates.isEmpty {
                Text("아래 버튼을 눌러 첫 프로필 이미지를 만들어보세요.")
                    .font(.subheadline)
                    .foregroundStyle(MoyeoTheme.muted)
                    .frame(maxWidth: .infinity, minHeight: 150)
                    .background(MoyeoTheme.subtleBackground.opacity(0.35))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                MoyeoTheme.line,
                                style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                // 타일은 **정사각**이다 — 후보 이미지가 정사각이라 겉 테두리도 정사각이라야
                // 이미지와 맞는다. 예전에는 `GeometryReader` 로 폭을 재고 높이를 132/200 으로
                // 하드코딩했는데, 그러면 ① 겉 카드가 1:1.16 이라 이미지 위아래로 여백이 남아
                // 테두리가 세로로 길쭉해 보이고(사용자가 발견) ② 컨테이너 폭이 바뀌면
                // 하드코딩 높이와 실제 타일 높이가 어긋났다.
                // `aspectRatio` 로 폭에서 높이를 파생시켜 둘 다 없앴다.
                HStack(spacing: 10) {
                    if candidates.count == 1 {
                        // 1개는 가운데(폭 1/3) — 좌우에 같은 비율의 빈 칸을 둬 3등분을 만든다.
                        Color.clear.aspectRatio(1, contentMode: .fit)
                        profileCandidate(candidates[0], index: 0)
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    } else {
                        // 2개는 좌우 절반, 3개는 3등분 — HStack 이 폭을 균등 분배한다.
                        ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                            profileCandidate(candidate, index: index)
                        }
                    }
                }
            }
        }
    }

    private func profileCandidate(
        _ candidate: AuthProfileImageCandidate,
        index: Int
    ) -> some View {
        let isSelected = selectedCandidateID == candidate.id
        return Button {
            selectedCandidateID = candidate.id
        } label: {
            ZStack {
                CachedRemoteImage(url: candidate.profileImageUrl) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Text("🧭")
                        .font(.system(size: 34))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(MoyeoTheme.leaf)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if selectingImageID == candidate.id {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(10)
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(isSelected ? MoyeoTheme.leaf : MoyeoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? MoyeoTheme.forest : MoyeoTheme.line,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading || isGenerating || selectingImageID != nil)
        .accessibilityLabel("프로필 후보 \(index + 1)")
        .accessibilityIdentifier("auth.profile.option.\(candidate.id)")
        .onAppear {
            if selectedCandidateID == nil, candidate.selected {
                selectedCandidateID = candidate.id
            }
        }
    }
}

private struct ProfileImageGeneratingView: View {
    let nickname: String?

    @State private var startedAt = Date()

    private let messages = [
        "닉네임에서 여행 친구의 분위기를 찾고 있어요",
        "어울리는 표정과 성격을 떠올리고 있어요",
        "여행 친구의 옷과 색을 고르고 있어요",
        "경북 여행에 어울리는 소품을 더하고 있어요",
        "마지막 색을 입히고 있어요"
    ]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = max(0, Int(context.date.timeIntervalSince(startedAt)))
            let messageIndex = min(elapsed / 4, messages.count - 1)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(MoyeoTheme.leaf)
                        .frame(width: 64, height: 64)
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(MoyeoTheme.forest)
                        .rotationEffect(.degrees(elapsed.isMultiple(of: 2) ? -5 : 7))
                        .scaleEffect(elapsed.isMultiple(of: 2) ? 0.96 : 1.04)
                        .animation(.easeInOut(duration: 0.8), value: elapsed)
                }

                VStack(spacing: 5) {
                    Text(messages[messageIndex])
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MoyeoTheme.ink)
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)
                    Text(generationCaption)
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.muted)
                        .multilineTextAlignment(.center)
                }

                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(MoyeoTheme.forest)

                Text("조금 오래 걸릴 수 있어요. 다른 화면으로 이동해도 완성된 후보는 서버에 보관돼요.")
                    .font(.caption2)
                    .foregroundStyle(MoyeoTheme.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(MoyeoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                    .stroke(MoyeoTheme.line, lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("프로필 이미지 생성 중, \(messages[messageIndex])")
            .accessibilityIdentifier("auth.profile.generating")
        }
        .onAppear { startedAt = Date() }
    }

    private var generationCaption: String {
        guard let nickname, !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "나만의 경북 여행 친구를 만들고 있어요"
        }
        return "‘\(nickname)’만의 경북 여행 친구를 만들고 있어요"
    }
}
