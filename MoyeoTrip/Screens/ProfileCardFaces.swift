//
//  ProfileCardFaces.swift
//  MoyeoTrip
//
//  화면기획 25 프로필 카드의 앞면·뒷면 — changeLog18.
//

import SwiftUI

// MARK: - 앞면

/// 정체성과 지표 — 1:1 프로필 이미지, 닉네임, 나와 동행 N회, 지표 스트립, 최근 동행,
/// 한 줄 소개, 여행 스타일, 뒤집기 안내.
struct ProfileCardFrontFace: View {
  let companion: ProfileCardCompanion
  let palette: MoyeoUserCardPalette
  let holoPoint: UnitPoint
  let isLifted: Bool

  /// 뒷면에 그릴 것이 하나라도 있는지 — 매너 점수·함께한 여행·받은 평가.
  private var hasBackContent: Bool {
    companion.mannerRating != nil
      || !companion.memories.isEmpty
      || !companion.receivedReviews.isEmpty
  }

  /// 스와이프 안내 화살표를 살짝 움직이는 양. 두 번 왕복한 뒤 제자리에서 멈춘다.
  @State private var hintNudge: CGFloat = 0
  /// 움직임 줄이기를 켠 사람에게는 움직이지 않는다.
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(spacing: 0) {
      ProfileCardTitleBar(companion: companion, palette: palette, trailing: .tripCount)
      illustration
      details
    }
    .profileCardSurface(palette: palette, isLifted: isLifted, gradientDegrees: 160)
  }

  /// 프로필 이미지는 대부분 1:1 이므로 정사각형 프레임에 꽉 채운다.
  /// 없으면 27 도감의 동물 아바타를 같은 자리에 그린다.
  private var illustration: some View {
    ZStack {
      palette.plate
      if let url = companion.profileImageURL {
        CachedRemoteImage(url: url) { image in
          image
            .resizable()
            .scaledToFill()
        } placeholder: {
          mascot
        }
      } else {
        mascot
      }
      ProfileCardHolo(point: holoPoint, isLifted: isLifted)
    }
    .frame(width: ProfileCardMetrics.illustrationSide, height: ProfileCardMetrics.illustrationSide)
    .compositingGroup()
    .clipShape(
      RoundedRectangle(cornerRadius: ProfileCardMetrics.illustrationCornerRadius, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: ProfileCardMetrics.illustrationCornerRadius, style: .continuous)
        .stroke(palette.frame, lineWidth: 2)
    }
    .padding(.horizontal, 12)
  }

  @ViewBuilder
  private var mascot: some View {
    if let mascot = companion.mascot {
      Text(mascot)
        .font(.system(size: 200))
    } else {
      // 실서버 응답에는 동물 종류가 없다 — 27 도감의 서버 카드처럼 유저 색 판만 남긴다.
      Color.clear
    }
  }

  private var details: some View {
    VStack(alignment: .leading, spacing: 7) {
      if let mannerRating = companion.mannerRating {
        ProfileCardMetaRow(label: "매너 점수", value: "\(ProfileCardCompanion.ratingText(mannerRating))점")
      }
      if !companion.stats.isEmpty {
        ProfileCardStatStrip(stats: companion.stats, palette: palette)
      }
      if let latest = companion.latestTripText {
        ProfileCardMetaRow(label: "최근 동행", value: latest)
      }
      if let introduction = companion.introduction, !introduction.isEmpty {
        Text(introduction)
          .font(MoyeoTypography.font(size: 11))
          .lineSpacing(6)
          .foregroundStyle(MoyeoTheme.text700)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 10)
          .padding(.vertical, 8)
          .background(MoyeoTheme.subtleBackground)
          .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
          .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
              .stroke(MoyeoTheme.softLine, lineWidth: 1)
          }
      }
      if !companion.travelStyles.isEmpty {
        ProfileCardStyleChips(styles: companion.travelStyles, palette: palette)
      }
      // 뒷면에 볼 것이 하나라도 있을 때만 안내한다 — 없는 것을 "볼 수 있어요" 라고
      // 하면 뒤집어 본 사람이 속는다. 웹·안드로이드와 같은 조건이다.
      if hasBackContent {
        flipHint
      }
    }
    .padding(.horizontal, 14)
    .padding(.top, 10)
    .padding(.bottom, 13)
  }

  /// 뒤집을 수 있다는 걸 알 방법이 없으면 뒷면은 아무도 보지 못한다 (changeLog18 §2-2).
  ///
  /// 문구만으로는 "밀 수 있다"가 잘 읽히지 않아 화살표를 조금 움직인다. 다만 프로필 카드는
  /// 들여다보는 화면이라 계속 움직이면 눈이 그리로 끌려간다 — **세 번만** 움직이고 멈춘다.
  /// 폭도 3pt 로 둔다. 접근성 설정에서 움직임을 줄였으면 아예 움직이지 않는다.
  private var flipHint: some View {
    VStack(alignment: .leading, spacing: 0) {
      Rectangle()
        .fill(MoyeoTheme.softLine)
        .frame(height: 1)
        .padding(.bottom, 8)
      HStack(spacing: 5) {
        Image(systemName: "chevron.right")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(MoyeoTheme.text400)
          .offset(x: hintNudge)
        Text("옆으로 밀면 함께한 여행과 평가를 볼 수 있어요")
          .font(MoyeoTypography.font(size: 10, weight: .heavy))
          .foregroundStyle(MoyeoTheme.muted)
      }
    }
    .padding(.top, 2)
    .onAppear {
      // 움직임 줄이기를 켰으면 움직이지 않는다.
      guard !reduceMotion else { return }
      // 캡처에서는 끈다 — 움직이는 중간을 찍으면 같은 아트보드가 회차마다 달라진다.
      guard !UITestRuntime.isEnabled else { return }
      // 짝수로 왕복해 **제자리에서 끝난다**. 홀수면 화살표가 밀린 채 멈춘다.
      withAnimation(.easeInOut(duration: 0.62).repeatCount(4, autoreverses: true)) {
        hintNudge = 3
      }
    }
  }
}

// MARK: - 뒷면

/// 관계 기록 — 평균 매너 점수, 함께한 여행별 내가 남긴 메시지(27-1),
/// 다른 여행자들이 남긴 평가.
struct ProfileCardBackFace: View {
  let companion: ProfileCardCompanion
  let palette: MoyeoUserCardPalette
  let isLifted: Bool

  var body: some View {
    VStack(spacing: 0) {
      ProfileCardTitleBar(companion: companion, palette: palette, trailing: .backLabel)

      // 뒷면은 앞면과 같은 크기로 겹쳐 그린다 — 내용이 넘치면 카드를 늘리지 않고 안에서 스크롤한다.
      ScrollView {
        VStack(alignment: .leading, spacing: 9) {
          if let rating = companion.mannerRating {
            mannerBlock(rating)
          }
          if !companion.memories.isEmpty {
            memories
          }
          // 평가 칸은 **0건이어도 그린다** — 제목만 남고 아래가 비면 고장으로 읽힌다.
          // 뒷면에 다른 내용이 하나라도 있을 때만이다. 아무것도 없으면 아래 한 줄로 갈음한다.
          if !companion.receivedReviews.isEmpty
            || companion.mannerRating != nil
            || !companion.memories.isEmpty {
            reviews
          }
          // 매너 점수도 함께한 여행도 평가도 없으면 뒷면이 통째로 비어 있었다 —
          // 뒤집어 봤는데 아무것도 없으면 고장으로 읽힌다.
          if companion.mannerRating == nil
            && companion.memories.isEmpty
            && companion.receivedReviews.isEmpty {
            Text(MoyeoEmptyText.noCompanionHistory)
              .font(MoyeoTypography.font(size: 11, weight: .semibold))
              .lineSpacing(5)
              .foregroundStyle(palette.chipText.opacity(0.75))
              .multilineTextAlignment(.center)
              // 한 줄이 위에 붙어 있으면 카드가 여전히 비어 보인다 — 남은 자리 가운데 놓는다.
              .frame(maxWidth: .infinity, minHeight: 190, alignment: .center)
              .accessibilityIdentifier("profile.back.empty")
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
      }
      .scrollBounceBehavior(.basedOnSize)
      .scrollIndicators(.hidden)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .profileCardSurface(palette: palette, isLifted: isLifted, gradientDegrees: 200)
  }

  private func mannerBlock(_ rating: Double) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text(ProfileCardCompanion.ratingText(rating))
        .font(MoyeoTypography.font(size: 19, weight: .black))
        .monospacedDigit()
        .foregroundStyle(palette.chipText)
      Text("점")
        .font(MoyeoTypography.font(size: 10.5, weight: .heavy))
        .foregroundStyle(palette.chipText)
      Spacer(minLength: 6)
      Text("동행자들이 준 평균")
        .font(MoyeoTypography.font(size: 10, weight: .bold))
        .foregroundStyle(MoyeoTheme.muted)
    }
    .padding(.horizontal, 11)
    .padding(.vertical, 9)
    .background(palette.chipBackground)
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(palette.frame, lineWidth: 1)
    }
  }

  /// 함께한 여행 — 각 여행에서 내가 27-1 에 남긴 한 줄 메시지를 붙인다.
  private var memories: some View {
    VStack(alignment: .leading, spacing: 0) {
      ProfileCardSectionTitle(title: "함께한 여행")
      ForEach(companion.memories) { memory in
        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 0) {
            Text(memory.tripTitle)
              .font(MoyeoTypography.font(size: 11, weight: .heavy))
              .foregroundStyle(MoyeoTheme.ink)
            Text(" · \(memory.tripDate)")
              .font(MoyeoTypography.font(size: 11, weight: .semibold))
              .foregroundStyle(MoyeoTheme.muted)
          }
          if let review = memory.oneLineReview, !review.isEmpty {
            Text("내 메시지 \"\(review)\"")
              .font(MoyeoTypography.font(size: 10.5))
              .lineSpacing(5)
              .foregroundStyle(MoyeoTheme.text700)
          } else {
            Text("메시지를 남기지 않았어요")
              .font(MoyeoTypography.font(size: 10))
              .foregroundStyle(MoyeoTheme.muted)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(MoyeoTheme.subtleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 9, style: .continuous)
            .stroke(MoyeoTheme.softLine, lineWidth: 1)
        }
        .padding(.bottom, 6)
      }
    }
  }

  /// 다른 여행자들이 이 사람에게 남긴 평가.
  /// 도감의 `oneLineReview` 는 "내가 남긴" 값이라 여기 섞지 않는다.
  /// 응답에 여행 제목·작성 시각이 없어 그 줄은 만들지 않는다.
  private var reviews: some View {
    VStack(alignment: .leading, spacing: 0) {
      Rectangle()
        .fill(MoyeoTheme.softLine)
        .frame(height: 1)
        .padding(.bottom, 9)
      ProfileCardSectionTitle(title: "다른 여행자들이 남긴 평가")
        .padding(.bottom, 1)
      if companion.receivedReviews.isEmpty {
        Text(MoyeoEmptyText.noReceivedReviews)
          .font(MoyeoTypography.font(size: 10.5, weight: .semibold))
          .lineSpacing(4)
          .foregroundStyle(MoyeoTheme.muted)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 5)
          .padding(.bottom, 4)
          .accessibilityIdentifier("profile.back.noReviews")
      }
      ForEach(companion.receivedReviews) { review in
        HStack(alignment: .top, spacing: 7) {
          // 강조선은 그 평가를 남긴 사람의 색 — 카드 주인의 색과 헷갈리지 않게
          RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(MoyeoUserCardPalette(nicknameColor: review.reviewerNicknameColor).border)
            .frame(width: 3)
          VStack(alignment: .leading, spacing: 2) {
            Text("\"\(review.content)\"")
              .font(MoyeoTypography.font(size: 11))
              .lineSpacing(6)
              .foregroundStyle(MoyeoTheme.text700)
            // 남긴 사람 · 어느 여행 · 언제. 서버가 주지 않는 조각은 붙이지 않는다.
            Text([review.reviewerNickname, review.tripTitle, review.createdAt]
              .compactMap { $0 }
              .joined(separator: " · "))
              .font(MoyeoTypography.font(size: 9.5, weight: .bold))
              .foregroundStyle(MoyeoTheme.muted)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.bottom, 8)
      }
    }
  }
}
