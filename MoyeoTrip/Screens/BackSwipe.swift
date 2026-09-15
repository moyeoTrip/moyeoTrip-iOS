//
//  BackSwipe.swift
//  MoyeoTrip
//
//  가장자리에서 밀어 뒤로 가기. 예전에는 **커스텀 헤더를 쓰는 화면 전체에서 되지 않았다** —
//  화면기획대로 헤더를 직접 그리려고 `.toolbar(.hidden, for: .navigationBar)` 를 걸었는데,
//  `UINavigationController` 의 `interactivePopGestureRecognizer` 는 **기본 내비게이션 바가
//  숨겨지면 스스로 꺼진다.** 그래서 17개 파일의 화면에서 왼쪽 가장자리를 밀어도 반응이 없고,
//  화면 좌상단의 작은 「뒤로」만이 유일한 출구였다 (IOS-F03).
//
//  제스처 인식기의 델리게이트를 비우면 바가 숨겨져 있어도 동작한다. 스택 하나에 한 번만
//  걸면 되므로(`UINavigationController` 는 그 스택이 공유한다) 각 탭의 `NavigationStack`
//  루트에서 부른다.
//

import SwiftUI
import UIKit

extension View {
    /// 이 뷰가 속한 `NavigationStack` 에서 가장자리 스와이프로 뒤로 가기를 되살린다.
    func moyeoBackSwipeEnabled() -> some View {
        background(MoyeoBackSwipeEnabler().frame(width: 0, height: 0))
    }
}

/// 뷰 계층을 타고 올라가 `UINavigationController` 를 찾아 제스처를 되살린다.
private struct MoyeoBackSwipeEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        MoyeoBackSwipeHostController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

private final class MoyeoBackSwipeHostController: UIViewController {
    /// `viewDidAppear` 에서 건다. `viewDidLoad` 시점에는 아직 부모 내비게이션 컨트롤러에
    /// 붙지 않아 `navigationController` 가 nil 이다.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        enableBackSwipe()
    }

    private func enableBackSwipe() {
        guard let navigationController = findNavigationController() else { return }
        guard let gesture = navigationController.interactivePopGestureRecognizer else { return }
        // 델리게이트를 비우면 「바가 숨겨져 있으니 밀지 마라」는 기본 판정이 사라진다.
        gesture.delegate = nil
        gesture.isEnabled = true
    }

    private func findNavigationController() -> UINavigationController? {
        var candidate: UIViewController? = parent ?? presentingViewController
        while let current = candidate {
            if let navigation = current as? UINavigationController { return navigation }
            if let navigation = current.navigationController { return navigation }
            candidate = current.parent
        }
        return navigationController
    }
}
