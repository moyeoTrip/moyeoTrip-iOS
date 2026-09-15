//
//  ChatRoomReportAPI.swift
//  MoyeoTrip
//
//  모집(채팅방)·멤버 신고 실서버 연동 (2026-09-14 실서버 확인).
//
//  `REPORT-CANON.md` §1 은 「채팅방·사용자 신고 API 없음」이라고 적고 있지만 **더 이상 사실이 아니다** —
//  두 엔드포인트 모두 배포돼 있다. 화면 쪽 계약은 `MoyeoReportTarget` 이 갖는다.
//
//  **세 사유 목록(피드 · 모집 · 멤버)은 서로 다르다.** 한 목록을 돌려쓰면 서버에 없는 사유를 보낸다.
//  `ChatRoomWriteAPIClient` 가 500줄을 넘어 이 파일로 갈라냈다 (SwiftLint file_length).
//

import Foundation

/// `GET /api/v1/chat-rooms/report-reasons` 항목 — **모집(채팅방) 신고 전용 목록**이다.
///
/// 피드·멤버 목록과 서로 다르다(모집에만 `COMMERCIAL_PURPOSE` 가 있고 `HARASSMENT` 는 없다).
/// 대상별로 맞는 엔드포인트를 부른다 — 한 목록을 돌려쓰면 서버에 없는 사유를 보내게 된다.
struct ServerChatRoomReportReason: Decodable, Hashable, Identifiable {
    let reason: String
    let displayName: String

    var id: String { reason }
}

/// `GET /api/v1/chat-rooms/member-report-reasons` 항목.
struct ServerMemberReportReason: Decodable, Hashable, Identifiable {
    let reason: String
    let displayName: String

    var id: String { reason }
}

/// `POST /chat-rooms/{roomId}/members/{memberId}/reports` — 사유는 필수, 상세는 선택(0~300자)다.
struct ServerCreateUserReportRequest: Encodable {
    let reason: String
    let details: String?
}

extension ChatRoomWriteAPIClient {
    // MARK: 모집(채팅방) 신고 (2026-09-14 실서버 확인)

    /// 모집 신고 사유 목록 — `GET /api/v1/chat-rooms/report-reasons`.
    ///
    /// 멤버 신고 목록(`member-report-reasons`)과 **다른 목록**이다. 하드코딩하지 않는다.
    func roomReportReasons() async throws -> [ServerChatRoomReportReason] {
        try await api.get("/api/v1/chat-rooms/report-reasons")
    }

    /// 모집 신고 — `POST /api/v1/chat-rooms/{roomId}/reports` → 204.
    ///
    /// 오류: 본인이 개설한 모집 400 `40044` · 중복 409 `40920`.
    func reportRoom(roomID: Int64, reason: String, details: String?) async throws {
        let trimmed = details?.trimmingCharacters(in: .whitespacesAndNewlines)
        try await api.sendVoid(
            "/api/v1/chat-rooms/\(roomID)/reports",
            method: "POST",
            body: ServerCreateUserReportRequest(
                reason: reason,
                details: (trimmed?.isEmpty == false) ? String(trimmed!.prefix(300)) : nil
            )
        )
    }

    // MARK: 멤버 신고 (BE-12 · 2026-09-14 실서버 확인)

    /// 멤버 신고 사유 목록 — `GET /api/v1/chat-rooms/member-report-reasons`.
    ///
    /// 코드와 표시 문구를 서버가 함께 준다 — **클라가 목록을 갖지 않는다**(정본 §2 · NO-MOCK R1).
    /// 못 받으면 사유를 지어내지 않고 빈 상태로 둔다.
    func memberReportReasons() async throws -> [ServerMemberReportReason] {
        try await api.get("/api/v1/chat-rooms/member-report-reasons")
    }

    /// 멤버 신고. 성공은 204 다.
    ///
    /// `details` 는 선택이고 서버 상한이 300자다.
    /// 오류: 자기 자신 신고 400 `40045` · 중복 신고 409 · 미참여 403.
    func reportMember(roomID: Int64, memberID: Int64, reason: String, details: String?) async throws {
        let trimmed = details?.trimmingCharacters(in: .whitespacesAndNewlines)
        try await api.sendVoid(
            "/api/v1/chat-rooms/\(roomID)/members/\(memberID)/reports",
            method: "POST",
            body: ServerCreateUserReportRequest(
                reason: reason,
                details: (trimmed?.isEmpty == false) ? String(trimmed!.prefix(300)) : nil
            )
        )
    }
}
