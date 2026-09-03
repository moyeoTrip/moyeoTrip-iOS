//
//  TermsAPIClient.swift
//  MoyeoTrip
//
//  약관 실서버 연동 (연동 대상 4) — 목록·본문(마크다운).
//

import Foundation

struct ServerTermSummary: Decodable, Identifiable, Hashable {
    let termId: Int64
    let title: String
    let required: Bool

    var id: Int64 { termId }
}

struct ServerTermDetail: Decodable, Hashable {
    let termId: Int64
    let title: String
    let required: Bool
    let version: String
    let content: String
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
}

/// 서버 약관 마크다운 본문 → 화면 섹션 (## 제목 단위로 나눈다)
enum ServerTermContentParser {
    static func sections(from markdown: String) -> [LegalDocumentContent.LegalSection] {
        var sections: [LegalDocumentContent.LegalSection] = []
        var currentTitle: String?
        var currentBody: [String] = []

        func flush() {
            guard let title = currentTitle else { return }
            let body = currentBody.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
            sections.append(.init(title: title, body: body))
            currentTitle = nil
            currentBody = []
        }

        for rawLine in markdown.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("## ") {
                flush()
                currentTitle = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("# ") {
                continue // 문서 제목은 화면 타이틀이 대신한다
            } else if !line.isEmpty {
                currentBody.append(line)
            }
        }
        flush()
        return sections
    }
}
