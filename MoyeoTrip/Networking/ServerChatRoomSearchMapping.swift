//
//  ServerChatRoomSearchMapping.swift
//  MoyeoTrip
//
//  `GET /chat-rooms/search` 신규 9필드를 화면 표기로 옮기는 순수 매핑.
//  2026-08-24 서버 패치로 찜 하트(`favorite`)·상태 배지(`status`)·마감 D-day(`recruitmentDDay`)·
//  집합 정보·당일 여행 시간이 목록 응답에 들어왔다. 항목별 상세 호출(N+1) 없이 카드를 그린다.
//

import Foundation

extension ServerChatRoomSummary {
    /// 위경도가 **둘 다** 있을 때만 좌표가 된다 — 한쪽만 오면 지도 마커에서 제외된다.
    var meetingCoordinate: MoyeoMapCoordinate? {
        MoyeoMapCoordinate(latitude: meetingLatitude, longitude: meetingLongitude)
    }

    /// 집합 장소 안내. 미정이면 서버가 null을 주므로 표기 자체를 숨긴다("미정"을 지어내지 않는다).
    var meetingDetailsText: String? {
        guard let meetingDetails, !meetingDetails.isEmpty else { return nil }
        return meetingDetails
    }

    /// 집합 일시의 시각 표기 — "2026-09-12T08:30:00" → "08:30"
    var meetingTimeText: String {
        ServerTripMapper.timeText(fromDateTime: meetingDateTime)
    }

    /// 당일 여행 시간 표기. 숙박이면 서버가 둘 다 null을 주므로 nil이 되어 화면에서 숨는다.
    var dayTripTimeText: String? {
        guard
            let start = ServerTripMapper.shortTime(dayTripStartTime),
            let end = ServerTripMapper.shortTime(dayTripEndTime)
        else {
            return nil
        }
        return "\(start) – \(end)"
    }

    /// 10 탐색 · 12 검색 카드의 상태 배지 문구
    var statusBadgeText: String {
        ServerTripMapper.exploreStatusText(status)
    }

    /// 모집 마감 D-day. 여행 시작 D-day가 아니라 **모집 마감** D-day다.
    var recruitmentDDayText: String {
        ServerTripMapper.dDayText(recruitmentDDay)
    }
}

extension ServerTripMapper {
    /// 10 탐색 · 12 검색 카드의 상태 배지 문구.
    /// 화면기획 카드 배지는 `진행중` / `확정` 두 가지이고, 서버의 `CANCELLED` 는 기존 표기 `모집취소` 를 쓴다.
    static func exploreStatusText(_ serverStatus: String) -> String {
        switch serverStatus {
        case "CONFIRMED":
            return "확정"
        case "CANCELLED":
            return RecruitmentStatus.cancelled.rawValue
        default:
            return "진행중"
        }
    }

    /// 검색 결과 → 11 탐색 지도 마커. **위경도가 둘 다 있는 항목만** 찍는다.
    static func mapMarkers(from rooms: [ServerChatRoomSummary]) -> [MoyeoMapMarker] {
        rooms.compactMap { room in
            guard let coordinate = room.meetingCoordinate else { return nil }
            // 순번 원은 코스 방문지 표기다. 모임 집합 장소는 단일 핀으로 찍는다(없는 숫자를 만들지 않는다).
            return MoyeoMapMarker(id: "\(serverTripIDPrefix)\(room.roomId)", coordinate: coordinate)
        }
    }

    /// 서버 모임 마커가 하나도 없으면 nil — 화면은 기존 목업/목데이터 지도를 그대로 쓴다.
    static func mapContent(from rooms: [ServerChatRoomSummary]) -> MoyeoMapContent? {
        let markers = mapMarkers(from: rooms)
        guard let first = markers.first else { return nil }
        return MoyeoMapContent(center: first.coordinate, level: 9, markers: markers)
    }
}
