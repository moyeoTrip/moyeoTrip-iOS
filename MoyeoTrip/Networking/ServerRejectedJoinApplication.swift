//
//  ServerRejectedJoinApplication.swift
//  MoyeoTrip
//
//  18 모집 관리 「거절 기록」 한 건 — `GET /chat-rooms/{roomId}/applications/rejected` (BE-17).
//
//  승인 대기와 달리 **거절한 시각**(`rejectedAt`)이 함께 온다. 서버가 최신 거절부터 준다.
//
//  예전에는 이 API 가 **없는 줄 알고** 화면에서 방금 거절한 건만 모아 두었다 —
//  화면을 다시 열면 비어서 섹션째 사라졌고 지난 거절은 어디에서도 볼 수 없었다 (TC HOST-010).
//  「화면에 없다」를 「서버에 없다」로 옮긴 오판이었다. 실서버로 찍어 확인하고 붙였다.
//

import Foundation

struct ServerRejectedJoinApplication: Decodable, Identifiable, Hashable {
    let applicationId: Int64
    /// 한마디를 안 남긴 신청이면 null 로 온다 (승인 대기와 같다).
    let applicationMessage: String?
    let applicant: ServerApplicantProfile
    let appliedAt: String
    let rejectedAt: String

    var id: Int64 { applicationId }
}
