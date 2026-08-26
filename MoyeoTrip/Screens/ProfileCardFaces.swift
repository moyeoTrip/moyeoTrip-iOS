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
      flipHint
    }
    .padding(.horizontal, 14)
    .padding(.top, 10)
    .padding(.bottom, 13)
  }

  /// 뒤집을 수 있다는 걸 알 방법이 없으면 뒷면은 아무도 보지 못한다 (changeLog18 §2-2).
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
        Text("옆으로 밀면 함께한 여행과 평가를 볼 수 있어요")
          .font(MoyeoTypography.font(size: 10, weight: .heavy))
          .foregroundStyle(MoyeoTheme.muted)
      }
    }
    .padding(.top, 2)
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

      VStack(alignment: .leading, spacing: 9) {
        if let rating = companion.mannerRating {
          mannerBlock(rating)
        }
        if !companion.memories.isEmpty {
          memories
        }
        if !companion.receivedReviews.isEmpty {
          reviews
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 14)
      .padding(.bottom, 12)
    }
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
            Text(review.reviewerNickname)
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
