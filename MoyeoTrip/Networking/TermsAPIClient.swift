//
//  TermsAPIClient.swift
//  MoyeoTrip
//
//  약관 실서버 연동 (연동 대상 4) — 목록·본문(마크다운).
//

import Foundation

struct ServerTermSummary: Decodable, Identifiable, Hashable {
    let termId: Int64
    /// 약관 **종류**를 가리키는 안정적인 식별자(`SERVICE`·`PRIVACY_COLLECTION`·`PRIVACY_POLICY`·`MARKETING`).
    ///
    /// `termId` 는 판본이 바뀔 때마다 새로 발급되므로 종류를 가리킬 수 없다.
    /// 아직 실서버에 배포되지 않은 필드라 `Optional` 이다 — 없으면 종류를 모르는 채로 두고
    /// 제목으로 **추측하지 않는다**(제목 추측이 처리방침 자리에 가입 동의서를 열었다, QA BE-03).
    let code: String?
    let title: String
    let required: Bool

    var id: Int64 { termId }
}

struct ServerTermDetail: Decodable, Hashable {
    let termId: Int64
    /// 약관 종류. `ServerTermSummary.code` 와 같은 이유로 `Optional` 이다.
    let code: String?
    let title: String
    let required: Bool
    let version: String
    /// Markdown 본문. **약관 본문의 유일한 출처다** — 앱은 사본을 들고 있지 않다.
    let content: String
}

/// 약관 **판본 목록** 한 줄 — `GET /api/v1/terms/history/{code}`.
///
/// 목록에는 비활성(지난) 판본까지 들어 있고 **최신순**이다. 목록은 `version` 을 주지만
/// **본문은 주지 않는다** — 본문은 `termId` 로 따로 받아야 하고, 지난 판본은 비활성이라
/// 그 API 가 404(`현재 활성 상태인 약관을 찾을 수 없습니다.`)를 준다 (2026-09-14 실서버 확인).
struct ServerTermHistoryEntry: Decodable, Identifiable, Hashable {
    let termId: Int64
    let code: String?
    let title: String
    let required: Bool
    let version: String

    var id: Int64 { termId }
}

final class TermsAPIClient: @unchecked Sendable {
    /// 상태가 없는 클라이언트다. 기본 인자(`= .shared`)로 쓰이는데 기본 인자 표현식은
    /// nonisolated 문맥에서 평가되므로, MainActor 기본 격리에 걸리지 않도록 명시한다.
    nonisolated static let shared = TermsAPIClient()

    private let api: MoyeoAPIClient

    init(api: MoyeoAPIClient = .shared) {
        self.api = api
    }

    /// 약관은 서버가 공개로 열어둔 엔드포인트다(`SecurityConfig` 허용 목록, 토큰 없이 200).
    /// 가입 중에는 아직 서비스 토큰이 없으므로 인증 없이 부른다.
    func terms() async throws -> [ServerTermSummary] {
        try await api.getPublic("/api/v1/terms")
    }

    func term(id: Int64) async throws -> ServerTermDetail {
        try await api.getPublic("/api/v1/terms/\(id)")
    }

    /// 종류(`code`)로 **현재 판본** 본문을 받는다. 설정 화면은 `termId` 를 알 수 없다 —
    /// 판본이 바뀔 때마다 새로 발급되기 때문이다.
    func latestTerm(code: String) async throws -> ServerTermDetail {
        try await api.getPublic("/api/v1/terms/latest/\(code)")
    }

    /// 종류(`code`)의 **판본 목록**. 지난 판본까지 최신순으로 온다 — 약관도 인증이 필요 없다.
    ///
    /// 서버가 주는 처리방침 본문이 「지난 판본은 약관 화면의 "지난 버전"에서 보실 수 있습니다」라고
    /// 약속하는데 **호출부가 앱에 0곳이었다** — 없는 길을 가리키고 있었다 (2026-09-14 결정 ①).
    func termHistory(code: String) async throws -> [ServerTermHistoryEntry] {
        try await api.getPublic("/api/v1/terms/history/\(code)")
    }
}
