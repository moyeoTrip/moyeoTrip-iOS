import SwiftUI

enum TravelTasteSelection {
    /// 후보 목록은 여기 두지 않는다. 가입 전에도 로그인 뒤에도
    /// `GET users/me/profile/options` 응답만 쓴다 (정본 R4·R5, 2026-08-30 공개 확인).
    static func isComplete(styles: Set<Int64>, interestRegions: Set<Int64>) -> Bool {
        !styles.isEmpty && !interestRegions.isEmpty
    }
}

struct AuthTravelTasteView: View {
    @Binding var selectedTravelStyles: Set<Int64>
    @Binding var selectedInterestRegions: Set<Int64>
    /// 후보는 서버가 준다 — 클라가 스타일·지역 표를 갖지 않는다.
    @ObservedObject var options: AuthTasteOptionsModel
    var isSubmitting = false
    var errorMessage: String?
    let backAction: () -> Void
    let continueAction: () -> Void

    private var isComplete: Bool {
        TravelTasteSelection.isComplete(
            styles: selectedTravelStyles,
            interestRegions: selectedInterestRegions
        )
    }

    var body: some View {
        AuthStepContainer(
            title: "어떤 여행을 좋아하세요?",
            subtitle: "여행 스타일과 관심 지역을 알려주시면\n딱 맞는 모집을 먼저 보여드려요."
        ) {
            TravelTasteOptionSection(
                title: "여행 스타일",
                requirementHint: "1개 이상",
                options: options.travelStyles,
                selectedItems: $selectedTravelStyles,
                accessibilityPrefix: "auth.taste.style"
            )

            TravelTasteOptionSection(
                title: "관심 지역",
                requirementHint: "경북 안에서 1곳 이상",
                options: options.interestedRegions,
                selectedItems: $selectedInterestRegions,
                accessibilityPrefix: "auth.taste.region"
            )

            // 후보를 못 받으면 칩을 하나도 그리지 않고 다시 시도만 띄운다 — 표를 지어내지 않는다.
            if options.isLoading {
                MoyeoEmptyStateView(
                    message: MoyeoEmptyText.loading,
                    accessibilityIdentifier: "auth.taste.loading"
                )
            } else if options.loadFailed {
                MoyeoEmptyStateView(
                    message: MoyeoEmptyText.loadFailed,
                    onRetry: { Task { await options.load() } },
                    accessibilityIdentifier: "auth.taste.loadFailed"
                )
            }

            TravelTasteInfoCard()
            TravelTasteSelectionSummary(
                styleCount: selectedTravelStyles.count,
                regionCount: selectedInterestRegions.count,
                accessibilityIdentifier: "auth.taste.summary"
            )

            if let errorMessage {
                AuthInlineError(message: errorMessage, accessibilityIdentifier: "auth.taste.error")
            }
        } footer: {
            HStack(spacing: 10) {
                Button(action: backAction) {
                    Text("이전")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.ink)
                        .frame(width: 92, height: 52)
                        .background(MoyeoTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                                .stroke(MoyeoTheme.line, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("auth.taste.back")

                AuthPrimaryButton(
                    title: isSubmitting ? "계정을 만들고 있어요..." : "저장하고 프로필 만들기",
                    accessibilityIdentifier: "auth.taste.continue"
                ) {
                    continueAction()
                }
                .disabled(!isComplete || isSubmitting)
            }
        }
        // 약관 단계와 같은 방식으로, 단계에 들어갈 때 서버 후보를 받아온다.
        .task {
            if options.isEmpty && !options.loadFailed { await options.load() }
        }
    }
}

struct TravelTasteOptionSection: View {
    let title: String
    /// 화면기획의 "* · 1개 이상" 처럼 필수 조건을 섹션 제목 옆에 붙인다.
    var requirementHint: String?
    /// 후보는 항상 **서버 id 를 달고 온다** — 화면은 라벨을 그리고 전송은 id 로 한다.
    let options: [TravelTasteOption]
    @Binding var selectedItems: Set<Int64>
    let accessibilityPrefix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 4) {
                Text(title)
                    .font(MoyeoTypography.font(size: 13, weight: .heavy, relativeTo: .subheadline))
                    .foregroundStyle(MoyeoTheme.ink)
                if let requirementHint {
                    Text("*")
                        .font(MoyeoTypography.font(size: 13, weight: .heavy, relativeTo: .subheadline))
                        .foregroundStyle(MoyeoTheme.coral)
                    Text("· \(requirementHint)")
                        .font(MoyeoTypography.font(size: 12, relativeTo: .caption))
                        .foregroundStyle(MoyeoTheme.muted)
                }
                Spacer(minLength: 0)
            }

            // 화면기획·웹·안드로이드의 취향 후보는 줄바꿈되며 흐르는 pill 배열이다.
            // 4열 그리드로 그리면 칩이 폭을 억지로 채워 큰 사각 버튼처럼 읽힌다.
            MoyeoChipFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(options) { option in
                    TravelTasteChip(
                        title: option.label,
                        isSelected: selectedItems.contains(option.id)
                    ) {
                        toggle(option.id)
                    }
                    // 접근성 식별자는 계속 라벨로 만든다 — 캡처·UI 테스트가 이름으로 칩을 찾는다.
                    .accessibilityIdentifier("\(accessibilityPrefix).\(option.label)")
                }
            }
        }
        .accessibilityIdentifier("\(accessibilityPrefix).section")
    }

    private func toggle(_ optionID: Int64) {
        if selectedItems.contains(optionID) {
            selectedItems.remove(optionID)
        } else {
            selectedItems.insert(optionID)
        }
    }
}

struct TravelTasteChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    // 라운드 999 pill. 글자 폭에 맞춰 줄어들고, 줄바꿈은 MoyeoChipFlowLayout 이 맡는다.
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MoyeoTypography.font(size: 12.5, weight: .bold, relativeTo: .caption))
                .foregroundStyle(isSelected ? MoyeoTheme.brandText : MoyeoTheme.ink)
                .lineLimit(1)
                .padding(.horizontal, 18)
                .frame(height: 34)
                .background(isSelected ? MoyeoTheme.selectionSurface : MoyeoTheme.card)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? MoyeoTheme.forest : MoyeoTheme.line, lineWidth: 1)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "선택됨" : "선택 안 됨")
    }
}

/// 칩을 왼쪽부터 채우다 폭이 넘치면 다음 줄로 넘긴다.
/// LazyVGrid 는 열 수가 고정이라 글자 길이가 다른 칩을 억지로 같은 폭으로 늘린다.
struct MoyeoChipFlowLayout: Layout {
    var horizontalSpacing: CGFloat = 7
    var verticalSpacing: CGFloat = 7

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(maxWidth: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + verticalSpacing * CGFloat(max(rows.count - 1, 0))
        let widest = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? widest, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var originY = bounds.minY
        for row in rows(maxWidth: bounds.width, subviews: subviews) {
            var originX = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: originX, y: originY + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                originX += size.width + horizontalSpacing
            }
            originY += row.height + verticalSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let widthIfAppended = current.indices.isEmpty
                ? size.width
                : current.width + horizontalSpacing + size.width
            if !current.indices.isEmpty, widthIfAppended > maxWidth {
                rows.append(current)
                current = Row(indices: [index], width: size.width, height: size.height)
            } else {
                current.indices.append(index)
                current.width = widthIfAppended
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

struct TravelTasteInfoCard: View {
    var body: some View {
        Label("마이 > 프로필 수정에서 언제든 함께 바꿀 수 있어요", systemImage: "person.crop.circle.badge.checkmark")
            .font(MoyeoTypography.cardMeta)
            .foregroundStyle(MoyeoTheme.onLeaf)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(MoyeoTheme.leaf)
            .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                    .stroke(MoyeoTheme.forest.opacity(0.25), lineWidth: 1)
            }
    }
}

struct TravelTasteSelectionSummary: View {
    let styleCount: Int
    let regionCount: Int
    var accessibilityIdentifier: String?

    // 화면기획·웹·안드로이드는 두 개수를 한 줄로 가운데 모아 보여준다.
    var body: some View {
        Text("여행 스타일 \(styleCount)개 · 관심 지역 \(regionCount)곳 선택")
            .font(MoyeoTypography.font(size: 12.5, relativeTo: .caption))
            .foregroundStyle(MoyeoTheme.muted)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}
