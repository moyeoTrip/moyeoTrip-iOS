import SwiftUI

// 09 홈 히어로. 날씨에 따라 시안이 9종이라 HomeView 에서 떼어 두었다
// (HomeView.swift 가 500줄 제한을 넘었다).

struct HomeHeroCard: View {
    let content: WeatherHeroContent
    /// 서버가 준 예보 지점. nil 이면 시안의 랜드마크를 쓴다.
    var place: String?
    // 9가지 날씨를 늘어놓던 칩 줄은 뺐다. 화면기획의 그 줄은 시안을 넘겨보기 위한
    // 프로토타입 조작 장치(onClick 으로 히어로를 바꾼다)이고 제품 기능이 아니다.
    // 현재 날씨는 히어로 이미지 위의 `맑음 · 경주 첨성대` 라벨이 이미 보여준다.

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("이번 주말, 어디로 떠나볼까요?")
                        .font(MoyeoTypography.sectionTitle)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(content.copy)
                        .font(MoyeoTypography.cardBody)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("home.weatherHero.copy")
                }
                Spacer(minLength: 10)
                Text(content.badge)
                    .font(MoyeoTypography.chip)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(.white.opacity(0.18))
                    .clipShape(Capsule())
            }

            WeatherHeroImage(content: content, place: place)
        }
        .padding(14)
        .background(content.state.cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 18)
        .accessibilityIdentifier("home.weatherHero")
    }
}

private struct WeatherHeroImage: View {
    let content: WeatherHeroContent
    /// 서버가 준 예보 지점. nil 이면 시안의 랜드마크를 쓴다.
    var place: String?

    private var placeText: String { place ?? content.place }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(content.imageAssetName)
                .resizable()
                .scaledToFill()
                // 화면기획·웹과 같은 높이(144)와 아래쪽 기준 크롭 — 가운데로 자르면 첨성대가 잘려 나간다.
                .frame(height: 144, alignment: .bottom)
                .clipped()
                .accessibilityIdentifier("home.weatherHero.image.\(content.imageAssetName)")
                .accessibilityLabel("\(content.label) 날씨 \(placeText) 이미지")
            Text("\(content.label) · \(placeText)")
                .font(MoyeoTypography.cardMeta)
                .foregroundStyle(content.state.selectedPillForeground)
                .lineLimit(1)
                .padding(.horizontal, 11)
                .frame(height: 30)
                .background(content.state.selectedPillBackground)
                .clipShape(Capsule())
                .padding(8)
        }
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
