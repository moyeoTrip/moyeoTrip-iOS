//
//  WithdrawalReasonAPI.swift
//  MoyeoTrip
//
//  29 계정 탈퇴의 사유 — **서버가 준다.**
//
//  `GET /api/v1/users/me/withdrawal-reasons` → `[{reason, displayName}]`
//  `DELETE /api/v1/users/me` 본문 `{reason, reasonDetail}` (둘 다 선택, 본문 없이도 탈퇴된다)
//
//  예전에는 화면에 다섯 문장을 **하드코딩**해 두고 고른 값을 **어디에도 보내지 않았다** —
//  「서비스를 고치는 데만 쓰여요. (필수)」라고 필수로 받아 놓고 버린 셈이다. 게다가 「기타」를
//  골라도 무엇이 기타인지 적을 자리가 없었다 (TC SET-039).
//  신고 사유와 같은 방식으로 **서버 목록을 그대로 그린다** — 문구를 앱에서 지어내지 않는다.
//

import Foundation

/// 서버가 주는 탈퇴 사유 한 줄.
struct ServerWithdrawalReason: Decodable, Identifiable, Hashable {
    /// `TRAVEL_LESS_OFTEN` · `NO_APPEALING_RECRUITMENT` · `BAD_EXPERIENCE`
    /// · `TOO_MANY_NOTIFICATIONS` · `OTHER`
    let reason: String
    let displayName: String

    var id: String { reason }

    /// 자유 입력을 함께 보내는 사유. 서버는 `OTHER` 가 아니면 `reasonDetail` 을 무시한다.
    var acceptsDetail: Bool { reason == "OTHER" }
}

@MainActor
final class WithdrawalReasonAPIClient {
    static let shared = WithdrawalReasonAPIClient()

    private let api = MoyeoAPIClient.shared

    func reasons() async throws -> [ServerWithdrawalReason] {
        try await api.get("/api/v1/users/me/withdrawal-reasons")
    }
}

/// `DELETE /users/me` 본문. 사유를 안 고르면 **본문 자체를 보내지 않는다**(서버가 그렇게 받는다).
struct ServerWithdrawRequest: Encodable {
    let reason: String?
    /// `reason == "OTHER"` 일 때만 채운다. 서버 제한은 200자다.
    let reasonDetail: String?
}
