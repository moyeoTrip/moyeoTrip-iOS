//
//  MoyeoScrollOffsetRestore.swift
//  MoyeoTrip
//
//  탭을 오간 뒤에도 보던 자리로 돌아오게 한다 (TC NAV-007 · NAV-009,
//  TAB-STATE-CANON R3 「목록·선택한 필터·스크롤 위치가 그대로다」).
//
//  `ContentView` 가 `switch selectedTab` 으로 탭 본문을 갈아끼우기 때문에 스크롤 위치를
//  화면 안에 두면 탭을 떠나는 순간 사라진다. 값은 탭 바깥(`MoyeoTabDataStore`)에 두고,
//  이 수정자가 저장·복원 시점만 맡는다.
//
//  **순서가 핵심이다.** 단순히 `onAppear` 에서 복원하면 안 된다 —
//  다시 그려진 목록은 첫 레이아웃에서 `contentOffset.y == 0` 을 보고하는데,
//  그것을 그대로 저장해 버리면 복원할 값이 0 으로 덮여 항상 최상단으로 돌아간다.
//  그래서 **복원을 마치기 전에는 저장하지 않는다.**
//
//  복원은 내용이 그만큼 길어진 뒤에 해야 한다. 아직 첫 페이지만 그려진 상태에서
//  스크롤을 걸면 목록 끝까지밖에 못 가고, 그 값이 다시 저장돼 위치가 조금씩 밀린다.
//

import SwiftUI

private struct MoyeoScrollOffsetRestore: ViewModifier {
    /// 보관소의 값. 읽기와 쓰기를 모두 이 바인딩으로 한다.
    @Binding var offset: CGFloat
    /// 목록이 **자리를 잡았는가**. 다음 페이지를 받는 중이면 `false` 다.
    ///
    /// 다음 페이지를 받는 동안에는 목록 끝에 「불러오는 중」 한 줄이 잠깐 붙는다(약 208pt).
    /// 그 줄이 있는 동안의 위치를 저장하면, 줄이 사라진 뒤에는 **닿을 수 없는 자리**가 된다 —
    /// 스크롤뷰가 최대값으로 깎아 내려 돌아올 때마다 그만큼(카드 두 장) 위에 멈췄다 (TC NAV-007).
    /// 그 사이에는 저장도 복원도 하지 않는다.
    let isSettled: Bool
    @State private var position = ScrollPosition()
    /// 복원을 시도해 끝냈는지. 끝나기 전에는 저장하지 않는다.
    @State private var hasRestored = false
    /// 되돌리기를 다시 건 횟수. 닿지 못하는 자리에서 무한히 매달리지 않게 막는다.
    @State private var restoreAttempts = 0
    /// 마지막으로 `scrollTo` 에 넘긴 값. 빗나간 만큼을 더해 다시 걸 때의 기준이다.
    @State private var appliedTarget: CGFloat?

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .onScrollGeometryChange(for: Snapshot.self) { geometry in
                Snapshot(
                    offsetY: geometry.contentOffset.y,
                    contentHeight: geometry.contentSize.height,
                    viewportHeight: geometry.containerSize.height
                )
            } action: { _, snapshot in
                guard isSettled else { return }
                guard hasRestored else {
                    restore(with: snapshot)
                    return
                }
                offset = snapshot.offsetY
            }
    }

    /// 저장된 자리까지 내용이 자랐을 때 되돌린다.
    ///
    /// **한 번만 걸고 끝내면 안 된다.** 목록은 다시 열릴 때 조금씩 자라는데,
    /// 아직 짧은 상태에서 스크롤을 걸면 끝까지밖에 못 가 목표보다 위에 멈춘다.
    /// 그 값을 저장해 버리면 돌아올 때마다 위치가 조금씩 밀린다(실제로 카드 두 장만큼 어긋났다).
    /// 그래서 **실제로 그 자리에 닿을 때까지** 다시 건다.
    private func restore(with snapshot: Snapshot) {
        let target = offset
        guard target > 0 else {
            // 최상단이면 되돌릴 것이 없다 — 곧바로 저장을 시작한다.
            hasRestored = true
            return
        }
        // 목록이 아직 목표만큼 자라지 않았다. 지금 걸면 끝에서 멈춘다 — 더 기다린다.
        guard snapshot.contentHeight - snapshot.viewportHeight >= target else { return }
        let error = target - snapshot.offsetY
        guard abs(error) > 1 else {
            // 닿았다. 이제부터 사용자의 스크롤을 저장한다.
            hasRestored = true
            return
        }
        // 목록이 계속 자라거나 줄어 영영 닿지 못하는 경우를 대비해 시도 횟수를 막아 둔다.
        guard restoreAttempts < 12 else {
            hasRestored = true
            return
        }
        restoreAttempts += 1
        // **같은 값을 다시 걸면 안 된다.** `scrollTo(y:)` 가 쓰는 원점과
        // `contentOffset.y` 의 원점이 (상단 인셋만큼) 어긋나 있어, 같은 값을 몇 번을 걸어도
        // 늘 같은 자리에 멈춘다 — 실제로 카드 두 장만큼 어긋난 채 30번을 헛돌았다.
        // 빗나간 만큼을 더해 다시 건다. 원점이 얼마나 어긋났든 몇 번 안에 수렴한다.
        let corrected = (appliedTarget ?? target) + error
        appliedTarget = corrected
        position.scrollTo(y: corrected)
    }

    private struct Snapshot: Equatable {
        let offsetY: CGFloat
        let contentHeight: CGFloat
        let viewportHeight: CGFloat
    }
}

extension View {
    /// 탭을 떠났다 돌아와도 보던 자리를 지킨다. `offset` 은 탭보다 오래 사는 곳에 둔다.
    /// - Parameter isSettled: 목록이 자리를 잡았는지. 다음 페이지를 받는 중이면 `false` 를 넘긴다.
    func moyeoRestoresScrollOffset(_ offset: Binding<CGFloat>, isSettled: Bool = true) -> some View {
        modifier(MoyeoScrollOffsetRestore(offset: offset, isSettled: isSettled))
    }
}
