//
//  SearchAPIClient.swift
//  MoyeoTrip
//
//  12 검색 · 인기 검색어. 서버가 2026-08-30 에 집계 API 를 열어 되살린 섹션이다.
//

import Foundation

/// 인기 검색어 한 건 — `GET /api/v1/search/popular-keywords` 응답 그대로다.
///
/// 등락은 서버가 2026-09-09 에 열어줬다: `rankTrend` 와 `rankChange`.
/// 기준은 **전일 순위**다(API 스펙 `PopularSearchKeywordResponse`).
struct ServerPopularKeyword: Decodable, Hashable, Identifiable {
    /// 전일 순위 대비 등락. 스펙의 enum 은 UP · DOWN · SAME · NEW 다.
    ///
    /// `unknown` 은 **모르는 값이 왔을 때만** 쓴다 — 그때는 화면이 등락을 그리지 않는다.
    /// 지어내지 않는다(NO-MOCK-CANON R1).
    enum RankTrend: String, Decodable, Hashable {
        case up = "UP"
        case down = "DOWN"
        case same = "SAME"
        case new = "NEW"
        case unknown

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = RankTrend(rawValue: raw) ?? .unknown
        }
    }

    let rank: Int
    let keyword: String
    let searchCount: Int64
    /// 스펙상 필수지만, 낡은 응답을 받아도 화면이 죽지 않도록 옵셔널로 둔다.
    let rankTrend: RankTrend?
    /// 변동 폭. 양수는 상승 · 음수는 하락이고 **신규 진입은 `null`** 이다.
    let rankChange: Int?

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
