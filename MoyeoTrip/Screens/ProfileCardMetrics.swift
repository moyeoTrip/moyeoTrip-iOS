//
//  ProfileCardMetrics.swift
//  MoyeoTrip
//
//  25 프로필 카드의 고정 수치와 기울기 계산. `ProfileCardView.swift` 가 500줄을 넘어 갈라냈다.
//

import SwiftUI

// MARK: - 수치 · 기울기 계산

/// 25 의 고정 수치. 화면기획(`ScreenPublicProfile`)의 px 값을 그대로 pt 로 쓴다.
enum ProfileCardMetrics {
  static let width: CGFloat = 318
  static let cornerRadius: CGFloat = 18
  static let glowCornerRadius: CGFloat = 26
  static let illustrationCornerRadius: CGFloat = 12
  /// 카드 안쪽 정사각형 일러스트의 한 변 (카드 폭 318 − 좌우 여백 12·2)
  static let illustrationSide: CGFloat = width - 24
  /// 화면기획의 CSS `perspective: 900px` 을 카드 폭 기준 상대값으로 옮긴 것 (318 / 900)
  static let perspective: CGFloat = 318.0 / 900.0
  /// 손을 떼면 900ms 로 가라앉는다. 260ms 로는 "띡" 하고 끊겼다 (changeLog18 §2-3).
  static let settleAnimation = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.9)
  /// 평평한 상태에서 누른 자리까지 들어가는 짧은 곡선. 없으면 처음 누를 때 각도가 튄다.
  static let enterAnimation = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.26)
  /// 뒤집기는 700ms (changeLog18 §2-4)
  static let flipAnimation = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.7)
  // 면 교체를 시간으로 미루던 값(`faceSwapDelay`)은 없앴다. 회전 곡선이 아주 빠른
  // ease-out 이라 "절반 시간"이 90도가 아니었고, 90도를 지난 뒤에도 한동안 앞면이
  // 거울상으로 보였다 — 프로필 이미지가 스쳐 보인 원인이다 (사용자가 발견).
  // 지금은 `ProfileCardFlip` 이 **실제 회전값**으로 고른다 (안드로이드와 같은 방식).
  /// 스와이프 뒤집기 최소 가로 이동
  static let flipSwipeDistance: CGFloat = 40

  /// 가로 이동이 세로보다 크고 40pt 이상일 때만 뒤집는다 — 세로 스크롤과 충돌하지 않게.
  static func isFlipSwipe(_ translation: CGSize) -> Bool {
    abs(translation.width) > flipSwipeDistance && abs(translation.width) > abs(translation.height)
  }

  /// CSS `linear-gradient(Ndeg, …)` 의 각도를 SwiftUI 의 시작·끝 `UnitPoint` 로 옮긴다.
  /// CSS 는 0deg 가 위쪽이고 시계 방향으로 커진다.
  static func gradientPoints(cssDegrees: Double) -> (start: UnitPoint, end: UnitPoint) {
    let radians = cssDegrees * .pi / 180
    let dx = sin(radians) / 2
    let dy = -cos(radians) / 2
    return (
      UnitPoint(x: 0.5 - dx, y: 0.5 - dy),
      UnitPoint(x: 0.5 + dx, y: 0.5 + dy)
    )
  }
}

/// 포인터 좌표 → 회전값. 순수 계산만 하므로 단위 테스트로 검증한다.
struct ProfileCardRotation: Equatable {
  var degreesX: Double = 0
  var degreesY: Double = 0
  var scale: Double = 1

  static let neutral = ProfileCardRotation()
  /// 중앙 기준 최대 기울기. 더 키우면 카드 안 글씨가 읽히지 않는다 (changeLog18 §2-3).
  static let maximumDegrees: Double = 10
  static let liftedScale: Double = 1.02

  /// 카드 안의 터치 좌표를 0...1 단위 좌표로 접는다. 카드 밖으로 끌어도 범위를 넘지 않는다.
  static func unitPoint(for location: CGPoint, in size: CGSize) -> UnitPoint {
    guard size.width > 0, size.height > 0 else { return .center }
    return UnitPoint(
      x: min(1, max(0, location.x / size.width)),
      y: min(1, max(0, location.y / size.height))
    )
  }

  /// 화면기획과 같은 식이다: rotateX = (0.5 - y) · 20, rotateY = (x - 0.5) · 20.
  static func following(_ point: UnitPoint) -> ProfileCardRotation {
    ProfileCardRotation(
      degreesX: (0.5 - Double(point.y)) * 2 * maximumDegrees,
      degreesY: (Double(point.x) - 0.5) * 2 * maximumDegrees,
      scale: liftedScale
    )
  }
}
