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
            title: "여행 친구를 만들어볼까요?",
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
                        systemImage: "arrow.clockwise",
                        accessibilityIdentifier: "auth.profile.retry",
                        action: retryAction
                    )
                }
            }
        } footer: {
            VStack(spacing: 10) {
                AuthPrimaryButton(
                    title: generateButtonTitle,
                    systemImage: isGenerating ? "hourglass" : "wand.and.stars",
                    accessibilityIdentifier: "auth.profile.generate",
                    action: generateAction
                )
                .disabled(!canGenerate)
                .opacity(canGenerate ? 1 : 0.44)

                AuthPrimaryButton(
                    title: selectedCandidateID == nil ? "이 이미지를 선택해주세요" : "이 이미지로 시작",
                    systemImage: selectedCandidateID == nil ? "photo" : "checkmark.circle.fill",
                    accessibilityIdentifier: "auth.profile.confirm",
                    action: confirmAction
                )
                .disabled(selectedCandidateID == nil || selectingImageID != nil || isLoading || isGenerating)
                .opacity(selectedCandidateID == nil || selectingImageID != nil ? 0.44 : 1)
            }
        }
    }

    private var canGenerate: Bool {
        !isGenerating && !isLoading && selectingImageID == nil && remainingGenerationCount > 0
    }

    private var generateButtonTitle: String {
        if isGenerating { return "새 후보를 만들고 있어요..." }
        if remainingGenerationCount == 0 { return "새 후보 생성 기회를 모두 사용했어요" }
        return "새 후보 만들기 · 남은 \(remainingGenerationCount)회"
    }

    private var profileSubtitle: String {
        guard let nickname, !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "서버에 저장된 닉네임을 바탕으로 후보를 만들어요."
        }
        return "선택한 닉네임 ‘\(nickname)’을 바탕으로 후보를 만들어요."
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

    private var profileGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("프로필 후보 \(candidates.count)개")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                Spacer()
                Text("\(remainingGenerationCount)회 남음")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.forest)
            }

            if candidates.isEmpty {
                VStack(spacing: 12) {
                    Text("아직 만든 이미지가 없어요.")
                        .font(.subheadline)
                        .foregroundStyle(MoyeoTheme.muted)
                }
                .frame(maxWidth: .infinity, minHeight: 132)
                .background(MoyeoTheme.elevatedCard)
                .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                        profileCandidate(candidate, index: index)
                    }
                }
            }

            Text("새 후보는 기존 후보에 추가돼요. 남은 생성 횟수 \(remainingGenerationCount)회")
                .font(.caption)
                .foregroundStyle(MoyeoTheme.muted)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityIdentifier("auth.profile.remaining")
        }
        .padding(18)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                .stroke(MoyeoTheme.line, lineWidth: 1)
        }
    }

    private func profileCandidate(_ candidate: AuthProfileImageCandidate, index: Int) -> some View {
        Button {
            selectedCandidateID = candidate.id
        } label: {
            HStack(spacing: 14) {
                AsyncImage(url: candidate.profileImageUrl) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        Text("🧭")
                            .font(.system(size: 34))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(MoyeoTheme.leaf)
                    }
                }
                .frame(width: 66, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("여행 친구 \(index + 1)")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.ink)
                    Text("서버에서 생성된 프로필 이미지")
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.muted)
                    if let nicknameCandidate {
                        Text("닉네임 색상 · \(nicknameCandidate.colorLabel)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(nicknameCandidate.swatchColor)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Group {
                    if selectingImageID == candidate.id {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: selectedCandidateID == candidate.id ? "checkmark.circle.fill" : "circle")
                    }
                }
                .foregroundStyle(selectedCandidateID == candidate.id ? MoyeoTheme.forest : MoyeoTheme.ink)
            }
            .padding(12)
            .frame(height: 92)
            .background(MoyeoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                    .stroke(selectedCandidateID == candidate.id ? MoyeoTheme.forest : MoyeoTheme.line, lineWidth: selectedCandidateID == candidate.id ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading || isGenerating || selectingImageID != nil)
        .accessibilityLabel("프로필 후보 \(candidate.id)")
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
