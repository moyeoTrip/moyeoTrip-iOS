//
//  ChatRoomWriteMapping.swift
//  MoyeoTrip
//
//  `ChatRoomWriteAPIClient` 응답 → 화면 모델 매핑.
//  쓰기 클라이언트가 500줄을 넘어 갈라냈다 (SwiftLint file_length).
//

import Foundation

// MARK: - 화면 모델 매핑

extension ServerTripMapper {
    /// 27-1 여행 마무리 · 27-4 코스 평가가 기준으로 삼는 "다녀온 여행".
    ///
    /// `ended` 만 보면 **불발(CANCELLED)된 방**이 먼저 잡힌다. 그런 방은 완료된 여행이 아니라
    /// 서버가 `409 40915` 를 주고, 화면이 근거 없이 빈 상태로 떨어진다.
    /// 확정(`CONFIRMED`)된 방을 먼저 고르고, 없으면 끝난 방 중 첫 번째로 물러난다.
    nonisolated static func latestCompletedRoom(in rooms: [ServerMyChatRoom]) -> ServerMyChatRoom? {
        rooms.first { $0.ended && $0.status == "CONFIRMED" } ?? rooms.first(where: \.ended)
    }

    /// 27-3 코스 공개의 대상 방. **서버가 준 자격(`coursePublicationAvailable`)을 본다.**
    ///
    /// 예전에는 「끝난 방 중 가장 최근 것」만 골라서, 남이 만든 공개 코스로 떠난 방도
    /// 대상이 됐다. 되돌릴 수 없다는 경고와 최종 확인 **두 단계를 모두 지난 뒤에야**
    /// 서버가 403(`해당 여행 코스를 공개할 호스트가 아닙니다.`)으로 거절했다 (TC AFTER-020).
    nonisolated static func latestPublishableRoom(in rooms: [ServerMyChatRoom]) -> ServerMyChatRoom? {
        let publishable = rooms.filter(isPublishable)
        return publishable.first { $0.status == "CONFIRMED" } ?? publishable.first
    }

    /// 공개할 자격이 있는 방인지. 위아래 두 함수가 **같은 조건**을 봐야 해서 한 곳에 둔다.
    nonisolated private static func isPublishable(_ room: ServerMyChatRoom) -> Bool {
        room.ended && room.coursePublicationAvailable
    }

    /// 끝난 방은 있는데 공개할 자격이 있는 방이 하나도 없는지 — 안내 문구를 가르는 데 쓴다.
    ///
    /// 예전에는 `latestPublishableRoom(in:) == nil` 로 적었다. 이 프로젝트는
    /// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 라 순수 데이터 구조체인 `ServerMyChatRoom` 의
    /// `Equatable` 적합성까지 메인 액터에 묶이고, 그것을 `nonisolated` 함수에서 쓰면
    /// **Swift 6 언어 모드에서 오류**가 된다. 값을 견주지 않고 조건을 직접 보면 그 의존이 사라진다.
    nonisolated static func hasCompletedButNotPublishableRoom(in rooms: [ServerMyChatRoom]) -> Bool {
        rooms.contains(where: \.ended) && !rooms.contains(where: isPublishable)
    }

    /// 18 모집 관리 승인 대기 카드. 서버가 주지 않는 값(성별·나이·매너)은 표기를 뺀다.
    /// `mannerRating` 은 실서버에서 항상 null 이라 "매너 4.9" 를 지어내지 않는다.
    /// 거절 기록 한 건 → 화면 모델 (`GET /chat-rooms/{roomId}/applications/rejected`).
    /// 승인 대기와 같은 줄 모양을 쓴다 — 다른 값은 줄 아래 설명(거절 시각)뿐이다.
    static func rejectedHostApplicant(from application: ServerRejectedJoinApplication) -> HostApplicant {
        applicantRow(
            applicationID: application.applicationId,
            profile: application.applicant,
            message: application.applicationMessage
        )
    }

    /// 거절 시각 줄. 상대 시각 정본을 따른다(`ServerFeedMapper.createdAtText`) —
    /// 「얼마 전에 거절했나」가 알고 싶은 값이라 강퇴 통지와 같은 성격의 자리다.
    static func rejectedDetailText(from application: ServerRejectedJoinApplication) -> String {
        let time = ServerFeedMapper.createdAtText(application.rejectedAt)
        return time.isEmpty ? "거절한 신청" : "\(time) 거절"
    }

    static func hostApplicant(from application: ServerJoinApplication) -> HostApplicant {
        applicantRow(
            applicationID: application.applicationId,
            profile: application.applicant,
            message: application.applicationMessage
        )
    }

    /// 승인 대기·거절 기록이 **같은 줄 모양**을 쓰도록 한 곳에 모았다.
    private static func applicantRow(
        applicationID: Int64,
        profile: ServerApplicantProfile,
        message: String?
    ) -> HostApplicant {
        var metaParts: [String] = []
        if let age = profile.age {
            metaParts.append("\(age)세")
        }
        if let genderText = applicantGenderText(profile.gender) {
            metaParts.append(genderText)
        }
        if let manner = profile.mannerRating {
            metaParts.append("매너 \(String(format: "%.1f", manner))")
        }
        metaParts.append("여행 \(profile.completedTripCount)회")

        return HostApplicant(
            id: "server-application-\(applicationID)",
            name: profile.nickname,
            avatar: "",
            meta: metaParts.joined(separator: " · "),
            note: message ?? "",
            serverApplicationID: applicationID,
            serverUserID: profile.userId,
            profileImageURL: profile.profileImageURL
        )
    }

    /// 18 모집 관리 「대기열」 한 줄.
    ///
    /// `position` 은 **서버가 준 순번을 그대로** 쓴다 — 클라가 다시 매기지 않는다.
    /// 1번이 자리가 나면 자동으로 합류할 사람이다.
    static func waitlistApplicant(from entry: ServerWaitlistEntry) -> HostApplicant {
        let profile = entry.applicant
        var metaParts = ["대기 \(entry.position)번"]
        if let age = profile.age {
            metaParts.append("\(age)세")
        }
        if let genderText = applicantGenderText(profile.gender) {
            metaParts.append(genderText)
        }
        metaParts.append("여행 \(profile.completedTripCount)회")

        return HostApplicant(
            id: "server-waitlist-\(entry.applicationId)",
            name: profile.nickname,
            avatar: "",
            meta: metaParts.joined(separator: " · "),
            note: entry.applicationMessage ?? "",
            serverApplicationID: entry.applicationId,
            serverUserID: profile.userId,
            profileImageURL: profile.profileImageURL
        )
    }

    /// 서버 성별 코드 → 화면 표기. 미입력(null)이면 표기를 숨긴다.
    static func applicantGenderText(_ gender: String?) -> String? {
        switch gender {
        case "M":
            return "남성"
        case "F":
            return "여성"
        default:
            return nil
        }
    }

    /// 20-1 동행자 줄의 부제 — "매너 4.8 · 여행 8회".
    /// 매너 점수는 완료 여행의 `companions` 응답에만 있고 값이 null 이면 빼고 그린다.
    static func memberDetailText(completedTripCount: Int, mannerRating: Double?) -> String {
        let trips = "여행 \(completedTripCount)회"
        guard let mannerRating else { return trips }
        return "매너 \(String(format: "%.1f", mannerRating)) · \(trips)"
    }

    /// `PUT /chat-rooms/{id}/meeting-info` 본문의 `meetingDateTime` 형식.
    static func meetingDateTimeText(date: String, time: String) -> String {
        let normalizedTime = time.split(separator: ":").count == 2 ? "\(time):00" : time
        return "\(date)T\(normalizedTime)"
    }
}
