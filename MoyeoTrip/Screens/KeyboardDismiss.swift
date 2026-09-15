//
//  KeyboardDismiss.swift
//  MoyeoTrip
//
//  키보드를 닫는 길. 예전에는 **어디에도 없었다** —
//  바깥을 탭해도, 화면을 스크롤해도, `Esc` 를 눌러도 키보드가 그대로 떠 있어
//  「집합 장소 *」·「예상 1인당 비용」·「신청 승인 방식」 같은 **필수 입력칸이 가려진 채** 손이
//  닿지 않았다. 여러 줄 입력(`TextEditor`)은 `Return` 이 줄바꿈이라 우회조차 없었다 (IOS-F136).
//
//  키보드 위 액세서리 「완료」 하나로 세 화면(모집 만들기 · 집합 장소 · 모집 내용 수정)을 함께 푼다.
//

import SwiftUI
import UIKit

extension View {
    /// 키보드 위에 「완료」를 얹는다. 누르면 지금 입력 중인 칸이 포커스를 놓는다.
    func moyeoKeyboardDismissable() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") { MoyeoKeyboard.dismiss() }
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.forest)
                    .accessibilityIdentifier("keyboard.done")
            }
        }
    }
}

enum MoyeoKeyboard {
    /// 지금 입력 중인 칸의 포커스를 놓는다. `@FocusState` 를 화면마다 새로 들일 필요가 없다.
    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }
}
