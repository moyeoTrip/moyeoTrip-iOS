//
//  UITestScrollDriver.swift
//  MoyeoTrip
//

import SwiftUI
import UIKit

/// 번호별 비교 캡처용 스크롤 드라이버.
///
/// 긴 화면은 한 화면분량씩 내려가며 여러 장을 찍어야 한다. `simctl` 에는 스와이프가 없고,
/// 화면마다 스크롤 앵커를 심는 방식은 74개 아트보드를 모두 덮지 못한다.
/// 그래서 실행 인자로 페이지를 받아 화면에 실제로 올라온 스크롤 뷰를 직접 옮긴다.
enum UITestScrollDriver {
    /// `UITEST_SCROLL_PAGE=2` 처럼 전달된 페이지. 1이면 스크롤하지 않는다.
    static var requestedPage: Int {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("UITEST_MODE") else { return 1 }
        guard let raw = arguments.first(where: { $0.hasPrefix("UITEST_SCROLL_PAGE=") }) else { return 1 }
        let value = Int(raw.dropFirst("UITEST_SCROLL_PAGE=".count)) ?? 1
        return max(1, min(value, 5))
    }

    /// 화면이 올라온 뒤 호출한다. 가장 큰 스크롤 뷰를 한 화면분량씩 내린다.
    static func applyIfRequested() {
        let page = requestedPage
        guard page > 1 else { return }

        // 화면 전환 애니메이션이 끝난 뒤에 옮겨야 위치가 유지된다.
        for delay in [0.6, 1.1, 1.6] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                scrollLargest(toPage: page)
            }
        }
    }

    private static func scrollLargest(toPage page: Int) {
        guard let window = keyWindow else { return }
        let candidates = scrollViews(in: window)
            .filter { $0.contentSize.height > $0.bounds.height + 8 }
            .sorted { lhs, rhs in
                (lhs.contentSize.height - lhs.bounds.height) > (rhs.contentSize.height - rhs.bounds.height)
            }
        guard let target = candidates.first else { return }

        let step = max(target.bounds.height - 40, 1)
        let maxOffset = max(target.contentSize.height - target.bounds.height, 0)
        let offset = min(maxOffset, step * CGFloat(page - 1))
        target.setContentOffset(CGPoint(x: target.contentOffset.x, y: offset), animated: false)
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }

    private static func scrollViews(in view: UIView) -> [UIScrollView] {
        var found: [UIScrollView] = []
        if let scrollView = view as? UIScrollView { found.append(scrollView) }
        for subview in view.subviews {
            found.append(contentsOf: scrollViews(in: subview))
        }
        return found
    }
}
