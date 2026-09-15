//
//  AuthPasswordResetThrottle.swift
//  MoyeoTrip
//

import Foundation

/// 비밀번호 재설정 메일을 **다시** 보낼 수 있을 때까지의 대기 (IOS-F56).
///
/// 이전에는 중복 방지가 「요청 중 버튼 비활성」뿐이라 끝난 뒤에는 몇 번이든 눌렸다.
/// 메일 제공자의 요청 제한에 먼저 걸리게 두는 대신, 화면이 남은 시간을 직접 말해 준다.
struct AuthPasswordResetThrottle: Equatable {
    static let cooldown: TimeInterval = 30

    private(set) var sendCount = 0
    private(set) var sentAt: Date?

    mutating func markSent(at date: Date = Date()) {
        sendCount += 1
        sentAt = date
    }

    /// 다시 보낼 수 있을 때까지 남은 초. 0 이면 지금 보낼 수 있다.
    func remainingSeconds(now: Date = Date()) -> Int {
        guard let sentAt else { return 0 }
        let elapsed = now.timeIntervalSince(sentAt).rounded(.down)
        return max(0, Int(Self.cooldown - elapsed))
    }
}
