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
    ///
    /// 서버가 주지 않으면(검색·지도 응답에는 없다) 빈 문자열이다 — 화면은 빈 값이면 그 줄을 숨긴다.
    var meetingTimeText: String {
        guard let meetingDateTime else { return "" }
        return ServerTripMapper.timeText(fromDateTime: meetingDateTime)
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

    /// 지도 응답 → 11 탐색 지도의 **지역 묶음 마커**. 위경도가 둘 다 있는 항목만 찍는다.
    ///
    /// 원 안 숫자는 화면기획 11 그대로 **그 자리의 모임 수**다(참가자 수가 아니다).
    /// 묶는 단위는 소수점 첫째 자리(≈10km) — 안드로이드 `meetingClusters()` 와 같은 규칙이다.
    /// 서버 검색 응답에 지역 필드가 없어 좌표로 묶는다. 지역명을 지어내지 않는다.
    static func mapMarkers(from rooms: [ServerChatRoomSummary]) -> [MoyeoMapMarker] {
        var order: [String] = []
        var groups: [String: [(roomId: Int64, coordinate: MoyeoMapCoordinate)]] = [:]
        for room in rooms {
            guard let coordinate = room.meetingCoordinate else { continue }
            let key = String(format: "%.1f,%.1f", coordinate.latitude, coordinate.longitude)
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append((room.roomId, coordinate))
        }
        return order.compactMap { key in
            guard let group = groups[key], !group.isEmpty else { return nil }
            let count = Double(group.count)
            let center = MoyeoMapCoordinate(
                latitude: group.reduce(0) { $0 + $1.coordinate.latitude } / count,
                longitude: group.reduce(0) { $0 + $1.coordinate.longitude } / count
            )
            let ids = group.map { String($0.roomId) }.joined(separator: "-")
            // id 는 `server-room-cluster-<방번호들>` 이다. **핀 탭이 이 값으로 방을 되찾으므로**
            // 형식을 바꾸면 `clusterRoomIDs(from:)` 도 같이 바꿔야 한다.
            return MoyeoMapMarker(
                id: "\(serverTripIDPrefix)cluster-\(ids)",
                coordinate: center,
                order: group.count
            )
        }
    }

    /// 묶음 마커 id 에서 방 번호를 되꺼낸다. 화면기획 11 핀 탭이 쓴다.
    /// 카드에 올릴 것은 **묶음의 첫 모집**이다 — 웹·안드로이드와 같은 선택 규칙이다.
    static func clusterRoomIDs(from markerID: String) -> [Int64] {
        let prefix = "\(serverTripIDPrefix)cluster-"
        guard markerID.hasPrefix(prefix) else { return [] }
        return markerID.dropFirst(prefix.count).split(separator: "-").compactMap { Int64($0) }
    }

    /// 서버 모임 마커가 하나도 없으면 nil — 화면은 기존 목업/목데이터 지도를 그대로 쓴다.
    static func mapContent(from rooms: [ServerChatRoomSummary]) -> MoyeoMapContent? {
        let markers = mapMarkers(from: rooms)
        guard let first = markers.first else { return nil }
        return MoyeoMapContent(center: first.coordinate, level: 9, markers: markers)
    }
}

extension ServerTripMapper {
    /// 서버 모임 id 만 아는 상태에서 여는 화면(20-3 공지 이력 직접 진입)용 최소 스레드.
    ///
    /// 화면이 스스로 상세·공지를 받아 채우므로 여기서는 `serverRoomID` 만 실어 보낸다.
    /// 이게 없으면 목데이터 스레드로 떨어져 실서버 화면에 목 공지가 찍힌다.
    /// 값만 만들어 돌려주는 순수 함수라 액터 격리가 필요 없다.
    nonisolated static func stubThread(serverRoomID roomID: Int64) -> ChatThread {
        ChatThread(
            id: "\(serverThreadIDPrefix)\(roomID)",
            tripTitle: "",
            region: "",
            mascot: "",
            lastMessage: "",
            updatedAt: "",
            unreadCount: 0,
            statusSummary: "",
            statusDetail: "",
            members: [],
            messages: [],
            isReadOnly: true,
            tripID: nil,
            recruitmentDeadline: "",
            scheduleSummary: "",
            serverRoomID: roomID,
            thumbnailURL: nil
        )
    }
}
