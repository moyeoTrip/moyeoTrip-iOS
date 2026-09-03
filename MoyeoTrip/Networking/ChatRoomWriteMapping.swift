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

    /// 18 모집 관리 승인 대기 카드. 서버가 주지 않는 값(성별·나이·매너)은 표기를 뺀다.
    /// `mannerRating` 은 실서버에서 항상 null 이라 "매너 4.9" 를 지어내지 않는다.
    static func hostApplicant(from application: ServerJoinApplication) -> HostApplicant {
        let profile = application.applicant
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
            id: "server-application-\(application.applicationId)",
            name: profile.nickname,
            avatar: "",
            meta: metaParts.joined(separator: " · "),
            note: application.applicationMessage ?? "",
            serverApplicationID: application.applicationId,
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
