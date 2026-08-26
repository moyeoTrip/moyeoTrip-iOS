//
//  MoyeoUserColor.swift
//  MoyeoTrip
//
//  유저 색상(`nicknameColor`)과 그 색으로 만드는 프로필 카드 팔레트 — changeLog18 §2-5.
//

import SwiftUI
import UIKit

/// 서버 `NicknameCandidate.color` 의 10가지 값.
///
/// 공개 프로필(`GET /users/{userId}/profile` → `nicknameColor`)과 받은 평가
/// (`reviewerNicknameColor`)로 내려온다. **도감 · 멤버 · 동행자 목록 응답에는 아직 없어서
/// 목록에서는 색을 쓰지 않는다.** 값이 없거나 모르는 값이면 브랜드 그린으로 떨어진다.
enum MoyeoUserColor: String, CaseIterable {
    case red = "RED"
    case orange = "ORANGE"
    case yellow = "YELLOW"
    case green = "GREEN"
    case blue = "BLUE"
    case navy = "NAVY"
    case purple = "PURPLE"
    case pink = "PINK"
    case skyBlue = "SKY_BLUE"
    case mint = "MINT"

    /// 브랜드 그린 — 색을 모를 때의 기본값 (primary-500).
    static let fallbackHex = "#2D8F5A"

    var hex: String {
        switch self {
        case .red:
            return "#D9534F"
        case .orange:
            return "#E8853A"
        case .yellow:
            return "#D9A81C"
        case .green:
            return "#2D8F5A"
        case .blue:
            return "#3B7DD8"
        case .navy:
            return "#2F4A86"
        case .purple:
            return "#7E5BC4"
        case .pink:
            return "#DE5D97"
        case .skyBlue:
            return "#3FA9D6"
        case .mint:
            return "#2FB79A"
        }
    }

    static func hex(for rawValue: String?) -> String {
        guard let rawValue, let color = MoyeoUserColor(rawValue: rawValue.uppercased()) else {
            return fallbackHex
        }
        return color.hex
    }
}

/// 유저 색상으로 만든 프로필 카드 팔레트.
///
/// 지정색을 그대로 쓰면 프로필 이미지 배경과 붙어 구분이 안 되므로, **테마 토큰과 섞어 3단으로 벌린다**
/// (changeLog18 §2-5). 웹은 `color-mix(in oklab, …)` 를 쓰고, iOS 는 같은 비율로 직접 보간한다.
/// 섞이는 상대가 테마 토큰이라 라이트/다크가 자동으로 따라온다.
struct MoyeoUserCardPalette: Equatable {
    /// 팔레트의 지정색. 라이트/다크를 따라가는 동적 `Color` 는 값끼리 비교되지 않으므로,
    /// 두 팔레트가 같은지는 이 지정색으로 판단한다.
    let baseHex: String
    /// 진한 톤 — 카드 테두리 (지정색 76% + line200)
    let border: Color
    /// 중간 톤 — 일러스트 프레임 · 지표 스트립 구분선 · 칩 테두리 (44% + bgRaised)
    let frame: Color
    /// 흐린 톤 — 카드 배경 그라디언트의 시작 (22% + bgRaised)
    let backgroundTop: Color
    /// 흐린 톤 — 일러스트 판 (10% + bgRaised)
    let plate: Color
    /// 칩 배경 (14% + bgRaised)
    let chipBackground: Color
    /// 칩 · 숫자 글자색 (66% + text900)
    let chipText: Color
    /// 카드 뒤 후광 (52% + 투명)
    let glow: Color

    static func == (lhs: MoyeoUserCardPalette, rhs: MoyeoUserCardPalette) -> Bool {
        lhs.baseHex == rhs.baseHex
    }

    init(nicknameColor: String?) {
        let baseHex = MoyeoUserColor.hex(for: nicknameColor)
        self.baseHex = baseHex
        border = Self.mix(baseHex, 0.76, with: MoyeoTheme.line)
        frame = Self.mix(baseHex, 0.44, with: MoyeoTheme.card)
        backgroundTop = Self.mix(baseHex, 0.22, with: MoyeoTheme.card)
        // 판이 밝으면 무지개가 묻힌다. 10% 에서 18% 로 올렸다.
        plate = Self.mix(baseHex, 0.18, with: MoyeoTheme.card)
        chipBackground = Self.mix(baseHex, 0.14, with: MoyeoTheme.card)
        chipText = Self.mix(baseHex, 0.66, with: MoyeoTheme.ink)
        glow = Color(hex: baseHex).opacity(0.52)
    }

    /// 지정색 `ratio` 만큼 + 테마 토큰 나머지. 감마를 편 선형 sRGB 에서 섞어
    /// 어두운 토큰과 섞을 때 탁해지지 않게 한다.
    private static func mix(_ baseHex: String, _ ratio: Double, with token: Color) -> Color {
        let base = UIColor(Color(hex: baseHex))
        let tokenColor = UIColor(token)
        return Color(uiColor: UIColor { trait in
            let lhs = base.resolvedColor(with: trait).linearComponents
            let rhs = tokenColor.resolvedColor(with: trait).linearComponents
            return UIColor(
                red: MoyeoUserCardPalette.encode(lhs.red * ratio + rhs.red * (1 - ratio)),
                green: MoyeoUserCardPalette.encode(lhs.green * ratio + rhs.green * (1 - ratio)),
                blue: MoyeoUserCardPalette.encode(lhs.blue * ratio + rhs.blue * (1 - ratio)),
                alpha: 1
            )
        })
    }

    /// 선형 값 → sRGB 성분
    private static func encode(_ value: Double) -> CGFloat {
        let clamped = min(1, max(0, value))
        let encoded = clamped <= 0.0031308
            ? clamped * 12.92
            : 1.055 * pow(clamped, 1 / 2.4) - 0.055
        return CGFloat(min(1, max(0, encoded)))
    }
}

/// 감마를 편 선형 sRGB 성분.
private struct LinearRGB {
    let red: Double
    let green: Double
    let blue: Double
}

private extension UIColor {
    var linearComponents: LinearRGB {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return LinearRGB(red: Self.linear(red), green: Self.linear(green), blue: Self.linear(blue))
    }

    static func linear(_ value: CGFloat) -> Double {
        let component = Double(min(1, max(0, value)))
        return component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }
}
