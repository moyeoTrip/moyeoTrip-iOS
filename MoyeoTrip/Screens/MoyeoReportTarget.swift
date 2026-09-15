//
//  MoyeoReportTarget.swift
//  MoyeoTrip
//
//  신고 대상별 계약 (2026-09-14 실서버 확인).
//
//  `REPORT-CANON.md` §1 의 「사용자·채팅방·댓글 신고 API 없음」은 **더 이상 사실이 아니다** —
//  세 대상 모두 접수 엔드포인트가 배포돼 있다. 그래서 `ReportUnsupportedDialog`
//  ("아직 앱에서 받지 못해요")로 끝나던 자리를 실제 접수로 바꿨다.
//
//  **세 사유 목록은 서로 다르다.** 피드/댓글 · 모집 · 멤버가 각각 다른 엔드포인트를 갖고,
//  모집에만 `COMMERCIAL_PURPOSE` 가 있고 `HARASSMENT` 는 없다. 목록을 돌려쓰면
//  서버에 없는 사유를 보내게 된다 — 대상이 자기 엔드포인트를 안다.
//
//  차단은 여기 들어오지 않는다. 신고와 분리해 따로 보낸다 (정본 §2·§3).
//

import Foundation

/// 세 목록을 한 모양으로 받는 화면용 사유. 서버 `displayName` 을 **그대로** 쓴다 (NO-MOCK R1).
struct MoyeoReportReason: Identifiable, Hashable {
    let reason: String
    let displayName: String

    var id: String { reason }
}

/// 신고 접수 결과 안내. 붉은 오류와 "이미 신고했어요" 안내를 섞지 않는다 (정본 §2).
enum MoyeoReportNotice: Equatable {
    /// 중립 안내 — 중복 신고·본인 대상처럼 **오류가 아닌** 결과.
    case info(String)
    /// 붉은 오류.
    case failure(String)
}

/// 신고 대상. 화면은 이 값 하나만 넘기고, 어디로 무엇을 보낼지는 여기서 정한다.
enum MoyeoReportTarget: Hashable {
    /// 23-1 피드 댓글.
    case comment(feedID: Int64, commentID: Int64)
    /// 15 모집(채팅방) 자체.
    case chatRoom(roomID: Int64)
    /// 20-1a 모임 멤버.
    case member(roomID: Int64, memberID: Int64)

    /// 시트 제목 아래 한 줄. 무엇을 신고하는지 먼저 말한다.
    var subjectText: String {
        switch self {
        case .comment:
            return "이 댓글을 신고해요."
        case .chatRoom:
            return "이 모집을 신고해요."
        case .member:
            return "이 멤버를 신고해요."
        }
    }

    /// 접수 성공 안내.
    var successText: String {
        "신고를 접수했어요."
    }

    var accessibilityPrefix: String {
        switch self {
        case .comment:
            return "commentReport"
        case .chatRoom:
            return "roomReport"
        case .member:
            return "memberReport"
        }
    }

    /// 대상별 사유 목록. **대상마다 다른 엔드포인트다.**
    func reasons() async throws -> [MoyeoReportReason] {
        switch self {
        case .comment:
            // 댓글 사유는 피드 신고와 같은 목록을 쓴다 (실서버 확인).
            return try await FeedAPIClient.shared.reportReasons()
                .map { MoyeoReportReason(reason: $0.reason, displayName: $0.displayName) }
        case .chatRoom:
            return try await ChatRoomWriteAPIClient.shared.roomReportReasons()
                .map { MoyeoReportReason(reason: $0.reason, displayName: $0.displayName) }
        case .member:
            return try await ChatRoomWriteAPIClient.shared.memberReportReasons()
                .map { MoyeoReportReason(reason: $0.reason, displayName: $0.displayName) }
        }
    }

    /// 접수. 성공은 모두 204 다.
    func submit(reason: String, details: String?) async throws {
        switch self {
        case .comment(let feedID, let commentID):
            try await FeedAPIClient.shared.reportComment(
                feedID: feedID, commentID: commentID, reason: reason, details: details
            )
        case .chatRoom(let roomID):
            try await ChatRoomWriteAPIClient.shared.reportRoom(
                roomID: roomID, reason: reason, details: details
            )
        case .member(let roomID, let memberID):
            try await ChatRoomWriteAPIClient.shared.reportMember(
                roomID: roomID, memberID: memberID, reason: reason, details: details
            )
        }
    }

    /// 서버 오류를 **대상별로 구분된 한국어**로 옮긴다.
    ///
    /// 상태 코드만 보면 400 두 종류(본인 대상 · 300자 초과)가 한 문구로 뭉개지고,
    /// 403·404 도 "요청에 실패했어요"가 된다. 업무 코드로 갈라 각각 다르게 적는다.
    func notice(for error: Error) -> MoyeoReportNotice {
        guard case MoyeoAPIError.server(let statusCode, let code, _) = error else {
            return .failure(error.moyeoUserMessage(fallback: "신고를 접수하지 못했어요."))
        }
        if let mapped = Self.sharedNotice(statusCode: statusCode, code: code) {
            return mapped
        }
        if let code, let mapped = codeNotice(code) {
            return mapped
        }
        return .failure(error.moyeoUserMessage(fallback: "신고를 접수하지 못했어요."))
    }

    /// 대상별 업무 코드 → 문구. 모르는 코드면 nil 이라 서버 원문으로 물러난다.
    private func codeNotice(_ code: Int) -> MoyeoReportNotice? {
        switch self {
        case .comment:
            return Self.commentNotice(code)
        case .chatRoom:
            switch code {
            case MoyeoServerErrorCode.roomReportSelf:
                return .info("본인이 연 모집은 신고할 수 없어요.")
            case MoyeoServerErrorCode.roomAlreadyReported:
                return .info("이미 신고한 모집이에요.")
            default:
                return nil
            }
        case .member:
            switch code {
            case MoyeoServerErrorCode.memberReportSelf:
                return .info("자기 자신은 신고할 수 없어요.")
            case MoyeoServerErrorCode.memberAlreadyReported:
                return .info("이미 신고한 사용자예요.")
            default:
                return nil
            }
        }
    }

    /// 댓글 신고 오류 4종 (SERVER-FACTS A). 상태 코드가 아니라 **업무 코드**로 가른다.
    private static func commentNotice(_ code: Int) -> MoyeoReportNotice? {
        switch code {
        case MoyeoServerErrorCode.commentReportSelf:
            return .info("본인이 쓴 댓글은 신고할 수 없어요.")
        case MoyeoServerErrorCode.commentAlreadyReported:
            return .info("이미 신고한 댓글이에요.")
        case MoyeoServerErrorCode.feedCommentNotFound:
            return .failure("삭제된 댓글이에요.")
        case MoyeoServerErrorCode.feedNotVisible:
            return .failure("볼 수 없는 피드의 댓글이에요.")
        default:
            return nil
        }
    }

    /// 대상과 무관하게 같은 뜻인 응답. 코드를 안 준 서버 응답도 여기서 받아낸다.
    private static func sharedNotice(statusCode: Int, code: Int?) -> MoyeoReportNotice? {
        if code == nil, statusCode == 409 {
            return .info("이미 신고했어요.")
        }
        if code == 40000 {
            // `details` 가 300자를 넘었을 때다. 화면이 먼저 자르므로 보통은 닿지 않는다.
            return .failure("상세 설명은 300자까지 쓸 수 있어요.")
        }
        return nil
    }
}
