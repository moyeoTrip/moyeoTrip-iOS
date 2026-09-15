//
//  NotificationReadState.swift
//  MoyeoTrip
//
//  알림 읽음 표시 — 「모두 읽음」과 알림 하나 열기.
//
//  둘 다 **화면을 먼저 바꾸고** 서버에 알린다(눌린 느낌이 바로 와야 한다). 문제는 예전에
//  그 뒤를 `try?` 로 삼켰다는 것이다 — 서버에는 그대로 안 읽음인데 배지만 줄어, 다시 들어오면
//  배지가 되살아나 「눌렀는데 왜 또 있지」가 된다 (TC SOCIAL-010 계열, 안드 교차 지적).
//  **실패하면 화면을 되돌린다.** 알림창까지 띄울지는 그 동작이 사용자가 하려던 일이었는지로 가른다.
//
//  `NotificationCenterView` 본체에 두면 SwiftLint `type_body_length`(300줄)를 넘어 확장으로 뺐다.
//

import SwiftUI

extension NotificationCenterView {
    /// 「모두 읽음」 — 이건 **사용자가 하려던 일 그 자체**라 실패하면 말한다.
    func markAllRead() {
        let previousReadAll = readAll
        let previousUnreadCount = serverUnreadCount
        readAll = true
        guard serverNotifications != nil else { return }
        serverUnreadCount = 0
        Task {
            do {
                try await NotificationAPIClient.shared.markAllRead()
            } catch {
                readAll = previousReadAll
                serverUnreadCount = previousUnreadCount
                navigationAlertTitle = "읽음으로 바꾸지 못했어요"
                navigationMessage = error.moyeoUserMessage(
                    fallback: "잠시 후 다시 시도해주세요.")
            }
        }
    }

    /// 알림 하나를 열 때 딸려 가는 읽음 표시.
    ///
    /// 사용자가 하려던 일은 **알림을 여는 것**이고 그건 됐으므로 알림창은 띄우지 않는다.
    /// 다만 읽음이 서버에 남지 않았으면 배지도 되돌려 화면이 서버보다 앞서가지 않게 한다.
    func markRead(_ item: ServerNotification) {
        guard isServerUnread(item) else { return }
        let identifier = item.notificationId
        let previousUnreadCount = serverUnreadCount
        serverReadIDs.insert(identifier)
        serverUnreadCount = max(serverUnreadCount - 1, 0)
        Task {
            do {
                try await NotificationAPIClient.shared.markRead(notificationID: identifier)
            } catch {
                serverReadIDs.remove(identifier)
                serverUnreadCount = previousUnreadCount
            }
        }
    }
}
