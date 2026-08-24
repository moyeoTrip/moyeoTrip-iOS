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
    static let shared = TermsAPIClient()

    private let api: MoyeoAPIClient

    init(api: MoyeoAPIClient = .shared) {
        self.api = api
    }

    func terms() async throws -> [ServerTermSummary] {
        try await api.get("/api/v1/terms")
    }

    func term(id: Int64) async throws -> ServerTermDetail {
        try await api.get("/api/v1/terms/\(id)")
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
