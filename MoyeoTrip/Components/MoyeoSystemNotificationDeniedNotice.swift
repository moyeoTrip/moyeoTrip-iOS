//
//  MoyeoSystemNotificationDeniedNotice.swift
//  MoyeoTrip
//
//  기기(iOS) 알림 권한이 꺼져 있을 때 띄우는 안내.
//
//  앱 안의 알림 스위치는 **서버 값**이다. OS 가 알림을 막아 두면 그 스위치를 아무리 켜도
//  기기에는 아무것도 오지 않는데, 화면은 「켜짐」만 보여 줬다 — 사용자는 앱이 고장 났다고
//  읽는다 (TC NOTIF-016). 두 상태는 다른 것이므로 **따로** 말하고, 고칠 수 있는 곳으로 보낸다.
//

import SwiftUI

struct MoyeoSystemNotificationDeniedNotice: View {
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bell.slash.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MoyeoTheme.warningText)
            VStack(alignment: .leading, spacing: 6) {
                Text("기기에서 알림이 꺼져 있어요")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                Text("아래 설정을 켜 두어도 iOS 설정에서 모여트립 알림이 꺼져 있으면 기기에 알림이 오지 않아요.")
                    .font(.caption)
                    .foregroundStyle(MoyeoTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button("iOS 설정 열기", action: onOpenSettings)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.brandText)
                    .accessibilityIdentifier("notificationDetail.openSystemSettings")
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoyeoTheme.warningBackground)
        .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
        .accessibilityIdentifier("notificationDetail.systemDenied")
    }
}
