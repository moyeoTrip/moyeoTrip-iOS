//
//  ProfileCardParts.swift
//  MoyeoTrip
//
//  화면기획 25 프로필 카드의 두 면이 공유하는 조각과 광택 — changeLog18.
//

import SwiftUI

// MARK: - 두 면이 함께 쓰는 조각

struct ProfileCardTitleBar: View {
  enum Trailing {
    case tripCount
    case backLabel
  }

  let companion: ProfileCardCompanion
  let palette: MoyeoUserCardPalette
  let trailing: Trailing

  var body: some View {
    HStack(spacing: 8) {
      Text(companion.nickname)
        .font(MoyeoTypography.font(size: 13.5, weight: .black))
        .kerning(-0.2)
        .foregroundStyle(MoyeoTheme.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)

      switch trailing {
      case .tripCount:
        // 나와 함께 간 횟수를 모르는 진입점(피드 작성자 등)에서는 캡슐을 만들지 않는다
        if let tripCount = companion.tripCount {
          tripCountCapsule(tripCount)
        }
      case .backLabel:
        Text("카드 뒷면")
          .font(MoyeoTypography.font(size: 9.5, weight: .heavy))
          .foregroundStyle(MoyeoTheme.muted)
      }
    }
    .padding(.horizontal, 12)
    .padding(.top, 9)
    .padding(.bottom, 7)
  }

  /// 포켓몬 카드의 HP 자리
  private func tripCountCapsule(_ tripCount: Int) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 2) {
      Text("\(tripCount)")
        .font(MoyeoTypography.font(size: 14, weight: .black))
        .monospacedDigit()
      Text("회 동행")
        .font(MoyeoTypography.font(size: 9.5, weight: .heavy))
    }
    .foregroundStyle(palette.chipText)
    .padding(.horizontal, 9)
    .frame(height: 22)
    .background(palette.chipBackground)
    .clipShape(Capsule())
    .overlay {
      Capsule().stroke(palette.frame, lineWidth: 1)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(tripCount)회 동행")
  }
}

struct ProfileCardStatStrip: View {
  let stats: [ProfileCardCompanion.Stat]
  let palette: MoyeoUserCardPalette

  var body: some View {
    HStack(spacing: 0) {
      ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
        VStack(spacing: 1) {
          Text(stat.label)
            .font(MoyeoTypography.font(size: 9, weight: .heavy))
            .foregroundStyle(MoyeoTheme.muted)
          Text(stat.value)
            .font(MoyeoTypography.font(size: 13, weight: .black))
            .monospacedDigit()
            .foregroundStyle(MoyeoTheme.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .overlay(alignment: .trailing) {
          if index < stats.count - 1 {
            Rectangle()
              .fill(palette.frame)
              .frame(width: 1)
          }
        }
      }
    }
    .background(palette.plate)
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(palette.frame, lineWidth: 1)
    }
  }
}

struct ProfileCardMetaRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(label)
        .font(MoyeoTypography.font(size: 10.5, weight: .bold))
        .foregroundStyle(MoyeoTheme.muted)
        .frame(minWidth: 52, alignment: .leading)
      Text(value)
        .font(MoyeoTypography.font(size: 11.5, weight: .bold))
        .foregroundStyle(MoyeoTheme.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

struct ProfileCardSectionTitle: View {
  let title: String

  var body: some View {
    Text(title)
      .font(MoyeoTypography.font(size: 10, weight: .heavy))
      .foregroundStyle(MoyeoTheme.muted)
      .padding(.bottom, 5)
  }
}

struct ProfileCardStyleChips: View {
  let styles: [String]
  let palette: MoyeoUserCardPalette

  var body: some View {
    HStack(spacing: 5) {
      ForEach(styles, id: \.self) { style in
        Text(style)
          .font(MoyeoTypography.font(size: 10, weight: .heavy))
          .foregroundStyle(palette.chipText)
          .padding(.horizontal, 8)
          .frame(height: 21)
          .background(palette.chipBackground)
          .clipShape(Capsule())
          .overlay {
            Capsule().stroke(palette.frame, lineWidth: 1)
          }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

extension View {
  /// 두 면이 공유하는 표면 — 유저 색 그라디언트 + 테두리 + 그림자.
  /// 그림자는 각 면이 직접 갖는다. 뒤집기 레이어에 그림자를 걸면 3D 가 평면으로 눌린다.
  func profileCardSurface(
    palette: MoyeoUserCardPalette,
    isLifted: Bool,
    gradientDegrees: Double
  ) -> some View {
    let points = ProfileCardMetrics.gradientPoints(cssDegrees: gradientDegrees)
    return background(
      LinearGradient(
        stops: [
          Gradient.Stop(color: palette.backgroundTop, location: 0),
          Gradient.Stop(color: MoyeoTheme.card, location: gradientDegrees == 160 ? 0.46 : 0.5),
          Gradient.Stop(color: MoyeoTheme.card, location: 1)
        ],
        startPoint: points.start,
        endPoint: points.end
      )
    )
    .clipShape(RoundedRectangle(cornerRadius: ProfileCardMetrics.cornerRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: ProfileCardMetrics.cornerRadius, style: .continuous)
        .stroke(palette.border, lineWidth: 2)
    }
    .shadow(
      color: Color.black.opacity(isLifted ? 0.28 : 0.16),
      radius: isLifted ? 22 : 13,
      x: 0,
      y: isLifted ? 22 : 10
    )
  }
}

// MARK: - 광택

/// 포인터 위치로 각도·위치가 바뀌는 무지개 포일. 프로필 이미지 "위"에 얹는다.
///
/// 뒤에 깔아봤는데, 실제 프로필 이미지가 정사각형을 꽉 채워 홀로그램이 완전히 가려졌다
/// (실서버 이미지로 확인). 그래서 위로 올린다.
///
/// 블렌드 모드로는 안 된다. 실제 프로필 이미지가 밝은 파스텔 톤이라
/// `softLight`·`overlay`·`colorDodge` 모두 — 참조 구현(pokemon-cards-css)의 대비 부스트를
/// 넣어도 — 거의 보이지 않았다. 그래서 색을 그대로 얹고 알파로 세기를 잡는다.
/// 알파가 낮아 그림의 형태는 그대로 읽힌다.
///
/// 만지지 않아도 항상 보인다 (changeLog18 §2-3-1).
struct ProfileCardHolo: View {
  let point: UnitPoint
  let isLifted: Bool

  /// 그림 위에 얹으므로 알파를 낮춘다. 0.62·0.9 에 0.65 를 곱한 값이다.
  static let idleOpacity: Double = 0.403
  static let liftedOpacity: Double = 0.585

  /// SwiftUI 에는 반복 그라디언트가 없다. 웹의 `repeating-linear-gradient` 와 띠 밀도를
  /// 맞추려고 무지개를 두 주기 넣는다.
  private static let stops: [Gradient.Stop] = {
    let cycle: [(Color, Double)] = [
      (Color(red: 255 / 255, green: 119 / 255, blue: 115 / 255).opacity(0.34), 0.00),
      (Color(red: 255 / 255, green: 237 / 255, blue: 140 / 255).opacity(0.30), 0.14),
      (Color(red: 168 / 255, green: 255 / 255, blue: 150 / 255).opacity(0.28), 0.28),
      (Color(red: 131 / 255, green: 240 / 255, blue: 247 / 255).opacity(0.30), 0.42),
      (Color(red: 140 / 255, green: 160 / 255, blue: 255 / 255).opacity(0.32), 0.56),
      (Color(red: 216 / 255, green: 140 / 255, blue: 255 / 255).opacity(0.30), 0.70),
      (Color.white.opacity(0.22), 0.84),
      (Color(red: 255 / 255, green: 119 / 255, blue: 115 / 255).opacity(0.34), 1.00)
    ]
    return (0..<2).flatMap { index in
      cycle.map { entry in
        Gradient.Stop(color: entry.0, location: (entry.1 + Double(index)) / 2)
      }
    }
  }()

  /// 웹의 `background-size: 320%` 에 맞춘 값.
  private static let scale: CGFloat = 3.2

  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      // 웹과 같은 식: 105 + (x - 0.5) * 90 도.
      let points = ProfileCardMetrics.gradientPoints(
        cssDegrees: 105 + (Double(point.x) - 0.5) * 90
      )
      // 웹은 배경 위치를 20~80% 로만 움직인다. 끝까지 밀면 띠가 화면에서 빠져나간다.
      let travelX = 0.2 + Double(point.x) * 0.6
      let travelY = 0.2 + Double(point.y) * 0.6
      LinearGradient(stops: Self.stops, startPoint: points.start, endPoint: points.end)
        .frame(width: size.width * Self.scale, height: size.height * Self.scale)
        .offset(
          x: -size.width * (Self.scale - 1) * travelX,
          y: -size.height * (Self.scale - 1) * travelY
        )
        .saturation(1.15)
    }
    .opacity(isLifted ? Self.liftedOpacity : Self.idleOpacity)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}
