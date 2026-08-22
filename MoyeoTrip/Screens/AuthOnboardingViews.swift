import SwiftUI

struct AuthOnboardingPageView: View {
    let page: AuthOnboardingPage

    // 화면기획의 온보딩은 카드에 담기지 않는다 — 배경 위에 이미지와 문구만 중앙 정렬한다
    var body: some View {
        VStack(spacing: 0) {
            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 224, height: 224)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .accessibilityIdentifier("auth-onboarding-illustration-\(page.id + 1)")
                .accessibilityHidden(true)
                .padding(.bottom, 26)

            VStack(spacing: 0) {
                Text(page.title)
                    .font(MoyeoTypography.font(size: 26, weight: .bold, relativeTo: .title2))
                    .foregroundStyle(MoyeoTheme.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity)
                Text(page.body)
                    .font(MoyeoTypography.font(size: 16, relativeTo: .body))
                    .foregroundStyle(MoyeoTheme.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

/// 온보딩 3단계 위치를 점으로 알려준다. 화면기획과 웹에 있는 요소다.
struct AuthOnboardingStepDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                let active = index == current
                Capsule()
                    .fill(active ? MoyeoTheme.forest : MoyeoTheme.softLine)
                    .frame(width: active ? 18 : 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("auth.onboarding.dots")
        .accessibilityLabel("온보딩 \(current + 1) / \(total) 단계")
    }
}
