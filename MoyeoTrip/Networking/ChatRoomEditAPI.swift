//
//  ChatRoomEditAPI.swift
//  MoyeoTrip
//
//  18-6 모집 내용 수정 · 20-6 내 메시지 삭제.
//
//  2026-09-04 BE 회신으로 열렸다 (정본 `docs/api/BACKEND_REQUEST_CHANGES_2026-09-04.md`).
//  2026-09-07 실서버로 존재·권한을 확인했다 (없는 방 404 `40405`, 남의 방 403 `40307`).
//
//  `ChatRoomWriteAPIClient.swift` 가 500줄 제한에 걸려 여기로 나눴다 — 성격이 같은 쓰기 API 다.
//

import Foundation

/// `PATCH /chat-rooms/{roomId}` — 18-6 모집 내용 수정 (multipart 의 `request` 파트).
///
/// **모든 필드를 보낸다.** 부분 수정은 `thumbnail` 파트를 생략하는 것으로만 성립한다 —
/// JSON 필드를 빼면 서버가 400 `40033`(JSON 형식) 으로 떨어진다(2026-09-07 실측).
/// 그래서 화면은 방을 먼저 읽어 현재 값으로 채운 뒤 바뀐 것만 갈아 보낸다.
///
/// `tripType` 이 `DAY_TRIP` 이면 `dayTripStartTime`·`dayTripEndTime` 을 채우고 `endDate` 는 nil,
/// `OVERNIGHT` 이면 `endDate` 를 채우고 시각은 nil 이다(방 생성과 같은 규칙).
struct ServerUpdateChatRoomRequest: Encodable, Equatable {
    let title: String
    let description: String?
    let tripType: String
    let minimumParticipants: Int?
    let maxParticipants: Int
    let startDate: String
    let endDate: String?
    let recruitmentDeadlineDate: String
    let dayTripStartTime: String?
    let dayTripEndTime: String?
    let participationFee: Int64?
}

extension ChatRoomWriteAPIClient {
    /// 모집 내용 수정 — **multipart/form-data · PATCH** 다.
    ///
    /// `request` 파트가 `application/json`, 새 대표 사진은 **선택** `thumbnail` 파일 파트다.
    /// 썸네일을 생략하면 기존 값을 유지하는 부분 수정이라 `PUT` 이 아니라 `PATCH` 다
    /// (비우는 길은 없다 — 그래서 화면에도 "지우기" 를 두지 않는다).
    ///
    /// **모집 중인 방의 호스트만** 된다 — 남의 방은 403 `40307`, 없는 방은 404 `40405`.
    /// 최대 인원을 현재 참가자 수보다 작게 줄일 수 없다.
    /// 저장되면 방에 `호스트가 모집 정보를 수정했어요.` 시스템 메시지가 남고 참가자에게 알린다.
    func updateRoom(
        roomID: Int64,
        request: ServerUpdateChatRoomRequest,
        thumbnail: MoyeoMultipartFile? = nil
    ) async throws {
        // 서버는 **204 No Content** 다 — 본문이 없다.
        // 예전에는 빈 본문을 디코딩해서 저장이 됐는데도 「서버 응답을 이해하지 못했어요」가 떴고,
        // 다시 누르게 되어 시스템 메시지가 겹쳐 쌓였다 (IOS-F112, 2026-09-12).
        try await api.sendMultipartVoid(
            "/api/v1/chat-rooms/\(roomID)",
            method: "PATCH",
            jsonPartName: "request",
            jsonPart: request,
            file: thumbnail
        )
    }

    /// 내 메시지 삭제 — 204 No Content.
    ///
    /// 참가자가 **자기 메시지만** 지울 수 있다(시스템 메시지·남의 메시지는 안 된다).
    /// 행을 지우지 않고 본문을 `삭제된 메시지입니다` 로 바꾸므로
    /// **id·보낸 사람·보낸 시각·답글 관계는 그대로 남는다.**
    /// 없는 메시지는 404 `40423`.
    func deleteMessage(roomID: Int64, messageID: Int64) async throws {
        try await api.sendVoid(
            "/api/v1/chat-rooms/\(roomID)/messages/\(messageID)",
            method: "DELETE"
        )
    }
}
