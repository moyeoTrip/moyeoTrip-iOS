//
//  MoyeoConfirmSheet.swift
//  MoyeoTrip
//
//  되돌리기 어려운 행동을 묻는 바텀 시트. 19-2 신청 취소 · 29-1a 차단 해제가 같은 골격을 쓴다.
//
//  각자 다른 모양이면 사용자가 "이건 아까 그거랑 다른 건가" 하고 멈칫한다 (기획 `ConfirmSheet`).
//  시스템 알림창을 쓰지 않는 이유도 같다 — 세 플랫폼이 같은 모양이어야 한다.
//

import SwiftUI

extension View {
    /// 바닥에 **딱 붙는** 바텀 시트 표면.
    ///
    /// 배경을 `clipShape` 로 잘라 놓고 뒤에 `.ignoresSafeArea` 를 붙이면
    /// 표면이 안전 영역 앞에서 끝나 시트가 화면 바닥에서 떠 보인다(27-2a 에서 그랬다).
    /// 둥근 윗변을 **배경 도형 자체**로 그리고 그 도형을 안전 영역까지 늘린다.
    /// 20-1a · 20-1b 시트(`MemberSheetFlow`)가 이미 이 방식이다.
    func moyeoBottomSheetSurface() -> some View {
        frame(maxWidth: .infinity)
            .background {
                UnevenRoundedRectangle(
                    topLeadingRadius: 24,
                    topTrailingRadius: 24,
                    style: .continuous
                )
                .fill(MoyeoTheme.card)
                .ignoresSafeArea(edges: .bottom)
            }
    }
}

/// 이전 화면 위에 딤 + 바닥에 붙는 시트로 뜬다.
/// 확인 버튼을 누르기 전에는 **아무것도 서버에 보내지 않는다.**
struct MoyeoConfirmSheet: View {
    let title: String
    /// 무엇에 대한 확인인지 — 모임 이름·상대 닉네임처럼 대상을 한 줄로 적는다.
    var subject: String = ""
    /// 이 행동이 무엇을 바꾸는지. 서버가 준 값으로 만들 수 없는 줄은 넣지 않는다.
    var lines: [String] = []
    var cancelTitle = "돌아가기"
    let confirmTitle: String
    var isDanger = false
    var isBusy = false
    var identifier: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            MoyeoTheme.overlayScrim
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(alignment: .leading, spacing: 0) {
                Capsule()
                    .fill(MoyeoTheme.line)
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 16)

                Text(title)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if !subject.isEmpty {
                    Text(subject)
                        .font(.subheadline)
                        .foregroundStyle(MoyeoTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                }

                if !lines.isEmpty {
                    AttachNoteBox(lines: lines)
                }

                HStack(spacing: 8) {
                    Button(action: onCancel) {
                        Text(cancelTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MoyeoTheme.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("\(identifier).cancel")

                    Button(action: onConfirm) {
                        Text(confirmTitle)
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(isDanger ? MoyeoTheme.dangerRed : MoyeoTheme.forest)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isBusy)
                    .accessibilityIdentifier("\(identifier).confirm")
                }
                .padding(.top, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 16)
            .moyeoBottomSheetSurface()
        }
        .accessibilityIdentifier("screen.\(identifier)")
    }
}
