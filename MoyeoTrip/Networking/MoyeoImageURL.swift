//
//  MoyeoImageURL.swift
//  MoyeoTrip
//
//  서버가 준 이미지 값을 화면이 쓸 URL 로 바꾸는 **한 곳**.
//
//  `travel-courses` 계열은 썸네일을 **상대 경로**로 준다:
//
//      GET /travel-courses/public        → "tourism/image/269cab52….webp"                      (상대)
//      GET /travel-courses/{id}          → 같음 (places 의 thumbnail 도 동일)
//      GET /tourism-contents             → "https://moyeo-trip-cdn.jayden-bin.cc/tourism/…"    (절대)
//
//  세 플랫폼 소스 어디에도 CDN 호스트가 없어 코스 사진이 전부 자리표시자로 떨어지고 있었다
//  (09 홈 · 12-1 검색 결과 · 14 코스 상세). 확인한 사실:
//
//      https://moyeo-trip-cdn.jayden-bin.cc/tourism/image/…  → 200 image/webp
//      https://moyeo-trip-api.jayden-bin.cc/tourism/image/…  → 404
//      https://moyeo-trip-api.jayden-bin.cc/api/v1/tourism/image/… → 404
//
//  그래서 **값이 `http` 로 시작하지 않을 때만** CDN 호스트를 앞에 붙인다.
//  이미 절대 URL 인 값(`tourism-contents`·프로필 이미지)은 그대로 통과한다.
//  화면마다 흩어 놓지 않는다 — 플랫폼마다 각자 때우면 그게 새 불일치가 된다.
//
//  서버에 절대 URL 통일을 요청해 두었다 (`BE-요청사항-2026-08-29.md` §2-9).
//  서버가 절대 URL 로 바꿔도 이 함수는 그대로 통과시키므로 되돌릴 필요가 없다.
//

import Foundation

enum MoyeoImageURL {
    /// 실패해도 앱이 뜨도록 코드에 마지막 기본값을 둔다 (`MoyeoAPIClient` 의 baseURL 과 같은 방식).
    nonisolated private static let fallbackCDNBase = "https://moyeo-trip-cdn.jayden-bin.cc"

    /// `Info.plist` 의 `MOYEO_CDN_BASE_URL`. 환경마다 CDN 이 달라질 수 있어 빌드 설정에서 읽는다.
    nonisolated static var cdnBase: String {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "MOYEO_CDN_BASE_URL") as? String,
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return fallbackCDNBase
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 서버 이미지 값 → URL. 비었으면 nil 이고, 화면은 빈 썸네일을 그린다 (NO-MOCK-CANON R4).
    nonisolated static func resolve(_ value: String?) -> URL? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // 이미 절대 URL(`http`·`https`)이면 손대지 않는다.
        if trimmed.lowercased().hasPrefix("http") {
            return URL(string: trimmed)
        }
        let path = trimmed.hasPrefix("/") ? String(trimmed.dropFirst()) : trimmed
        return URL(string: "\(cdnBase)/\(path)")
    }
}
