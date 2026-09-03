//
//  SearchAPIClient.swift
//  MoyeoTrip
//
//  12 검색 · 인기 검색어. 서버가 2026-08-30 에 집계 API 를 열어 되살린 섹션이다.
//

import Foundation

/// 인기 검색어 한 건 — `GET /api/v1/search/popular-keywords` 응답 그대로다.
///
/// 서버가 주는 값은 **이 셋뿐이다.** 순위 변동(상승·하락)을 알려주는 필드가 없으므로
/// 화면기획의 화살표(▲▼)는 그리지 않는다 — 그건 목데이터였다 (NO-MOCK-CANON R1).
struct ServerPopularKeyword: Decodable, Hashable, Identifiable {
    let rank: Int
    let keyword: String
    let searchCount: Int64

    var id: Int { rank }
}

final class SearchAPIClient: @unchecked Sendable {
    static let shared = SearchAPIClient()

    private let api: MoyeoAPIClient

    init(api: MoyeoAPIClient = .shared) {
        self.api = api
    }

    /// 모임 검색 + 공개 코스 검색 합산 집계. 인증이 필요하다(토큰 없이 부르면 401 `40100`).
    ///
    /// 집계 시작 전이거나 Redis 장애면 빈 배열이 온다 — **실패가 아니다.**
    /// 0건이면 화면이 섹션 자체를 그리지 않는다(빈 상태 문구를 새로 만들지 않는다).
    func popularKeywords(limit: Int = 10) async throws -> [ServerPopularKeyword] {
        try await api.get(
            "/api/v1/search/popular-keywords",
            query: [URLQueryItem(name: "limit", value: "\(limit)")]
        )
    }
}
