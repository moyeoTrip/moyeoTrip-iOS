import Foundation

// MARK: - 지도 반경 조회

extension ChatRoomAPIClient {
    /// 지도 반경 조회 — `GET /api/v1/chat-rooms/map`.
    ///
    /// **검색 응답(`/search`)에는 집합 좌표가 없다**(2026-08-26 응답 축소). 지도에 핀을 찍으려면
    /// 이 엔드포인트를 써야 한다. 좌표 없는 목록으로 지도를 그리려 하면 늘 목업으로 떨어진다.
    func mapRooms(
        latitude: Double,
        longitude: Double,
        radiusKilometers: Double
    ) async throws -> [ServerChatRoomSummary] {
        try await api.get(
            "/api/v1/chat-rooms/map",
            query: [
                URLQueryItem(name: "latitude", value: "\(latitude)"),
                URLQueryItem(name: "longitude", value: "\(longitude)"),
                URLQueryItem(name: "radiusKm", value: "\(radiusKilometers)")
            ]
        )
    }
}
