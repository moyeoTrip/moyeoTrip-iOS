import SwiftUI
import UIKit

/// 지도 마커·경로선의 시각 언어 (화면기획 11 / 17-3 / 18-3).
/// 방문지 순번은 초록 원 + 흰 숫자, 경로선은 초록 실선, 집합 장소는 단일 핀이다.
enum MoyeoMapSymbols {
    static var markerFill: UIColor { UIColor(MoyeoTheme.forest) }
    static var markerStroke: UIColor { .white }
    static var routeColor: UIColor { UIColor(MoyeoTheme.forest) }
    static var routeStroke: UIColor { UIColor.white.withAlphaComponent(0.9) }

    /// 방문지 순번 마커. 앵커는 가운데(0.5, 0.5).
    ///
    /// 지름 24 · 글자 11. 예전 34/15 는 **코스 미리보기(높이 140~160)에서 너무 컸다** —
    /// 방문지가 10곳이면 마커가 지도를 덮는다. 안드로이드도 같은 값(24dp/11dp)이다.
    static func orderBadge(_ order: Int) -> UIImage {
        let side: CGFloat = 24
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { _ in
            markerStroke.setFill()
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: side, height: side)).fill()
            markerFill.setFill()
            UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: side - 4, height: side - 4)).fill()

            let label = "\(order)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .heavy),
                .foregroundColor: UIColor.white
            ]
            let textSize = label.size(withAttributes: attributes)
            label.draw(
                at: CGPoint(x: (side - textSize.width) / 2, y: (side - textSize.height) / 2),
                withAttributes: attributes
            )
        }
    }

    /// 집합 장소 핀. 작은 미리보기에서도 잘리지 않게 앵커는 가운데(0.5, 0.5)다.
    static var meetingPin: UIImage {
        let head: CGFloat = 24
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: head, height: head))
        return renderer.image { _ in
            markerStroke.setFill()
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: head, height: head)).fill()
            markerFill.setFill()
            UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: head - 4, height: head - 4)).fill()
            markerStroke.setFill()
            UIBezierPath(ovalIn: CGRect(x: head / 2 - 3.5, y: head / 2 - 3.5, width: 7, height: 7)).fill()
        }
    }
}

/// 중앙 고정 핀. 지도를 끌어 위치를 맞추는 17-3 집합 장소 지정에서 쓴다.
/// 촉 끝이 뷰 중심에 오도록 위로 올린다 — 중심 좌표를 그대로 위경도로 읽는다.
struct MoyeoMapCenterPin: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "mappin")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(MoyeoTheme.forest)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 3)
            Rectangle()
                .fill(MoyeoTheme.muted)
                .frame(width: 3, height: 12)
        }
        .offset(y: -23)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
