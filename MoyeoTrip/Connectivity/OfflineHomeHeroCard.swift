import SwiftUI

struct OfflineHomeHeroCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "cloud.slash.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(MoyeoTheme.warningText)
                    .frame(width: 42, height: 42)
                    .background(MoyeoTheme.warningBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("오늘의 날씨와 추천 코스")
                        .font(MoyeoTypography.cardTitle)
                        .foregroundStyle(MoyeoTheme.ink)
                    Text("연결되면 최신 경북 날씨로 다시 추천해드릴게요")
                        .font(MoyeoTypography.cardMeta)
                        .foregroundStyle(MoyeoTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Label("아래 코스는 기기에 저장된 내용이에요", systemImage: "arrow.down.circle")
                .font(MoyeoTypography.font(size: 12, weight: .bold, relativeTo: .caption))
                .foregroundStyle(MoyeoTheme.text700)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    MoyeoTheme.warningText.opacity(0.72),
                    style: StrokeStyle(lineWidth: 1.2, dash: [7, 5])
                )
        }
        .padding(.horizontal, 18)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.weatherHero.offline")
    }
}
