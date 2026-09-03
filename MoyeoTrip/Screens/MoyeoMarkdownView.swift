import SwiftUI

/// 서버가 내려주는 마크다운 본문의 블록 단위.
///
/// 약관(`GET /api/v1/terms/{termId}`)은 표를 포함한 마크다운으로 온다.
/// 줄을 그대로 이어 그리면 `| 구분 | 수집 항목 |` 과 `| --- | --- |` 이 본문에 노출된다.
enum MoyeoMarkdownBlock: Identifiable, Hashable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullets([String])
    case ordered([String])
    case table(header: [String], rows: [[String]])

    var id: String {
        switch self {
        case .heading(let level, let text): "h\(level):\(text)"
        case .paragraph(let text): "p:\(text)"
        case .bullets(let items): "ul:\(items.joined(separator: "|"))"
        case .ordered(let items): "ol:\(items.joined(separator: "|"))"
        case .table(let header, let rows):
            "table:\(header.joined(separator: "|")):\(rows.count)"
        }
    }
}

enum MoyeoMarkdownParser {
    /// 마크다운 → 블록 목록.
    ///
    /// 지원 범위는 서버 약관이 실제로 쓰는 것에 맞춘다 — 제목(`#`~`###`), 문단, 표,
    /// 글머리(`-`·`*`), 번호 목록. 그 밖의 문법은 문단으로 둔다(내용을 잃지 않는다).
    static func blocks(from markdown: String) -> [MoyeoMarkdownBlock] {
        var blocks: [MoyeoMarkdownBlock] = []
        var paragraph: [String] = []
        var bullets: [String] = []
        var ordered: [String] = []
        var tableRows: [[String]] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: " ")))
            paragraph = []
        }
        func flushBullets() {
            guard !bullets.isEmpty else { return }
            blocks.append(.bullets(bullets))
            bullets = []
        }
        func flushOrdered() {
            guard !ordered.isEmpty else { return }
            blocks.append(.ordered(ordered))
            ordered = []
        }
        func flushTable() {
            guard !tableRows.isEmpty else { return }
            // 첫 줄을 머리로 본다. 구분선(`---`)은 파싱 단계에서 이미 버렸다.
            let header = tableRows[0]
            let rows = Array(tableRows.dropFirst())
            blocks.append(.table(header: header, rows: rows))
            tableRows = []
        }
        func flushAll() {
            flushParagraph()
            flushBullets()
            flushOrdered()
            flushTable()
        }

        for rawLine in markdown.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                flushAll()
                continue
            }
            if isTableSeparator(line) {
                // `|---|---|` 는 그리지 않는다. 표가 이어지고 있다는 신호일 뿐이다.
                continue
            }
            if line.hasPrefix("|") {
                flushParagraph()
                flushBullets()
                flushOrdered()
                tableRows.append(tableCells(line))
                continue
            }
            flushTable()

            if let heading = heading(from: line) {
                flushParagraph()
                flushBullets()
                flushOrdered()
                blocks.append(heading)
                continue
            }
            if let item = bulletItem(from: line) {
                flushParagraph()
                flushOrdered()
                bullets.append(item)
                continue
            }
            if let item = orderedItem(from: line) {
                flushParagraph()
                flushBullets()
                ordered.append(item)
                continue
            }
            flushBullets()
            flushOrdered()
            paragraph.append(line)
        }
        flushAll()
        return blocks
    }

    private static func heading(from line: String) -> MoyeoMarkdownBlock? {
        for level in [3, 2, 1] {
            let marker = String(repeating: "#", count: level) + " "
            if line.hasPrefix(marker) {
                return .heading(
                    level: level,
                    text: String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
                )
            }
        }
        return nil
    }

    private static func bulletItem(from line: String) -> String? {
        for marker in ["- ", "* ", "• "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private static func orderedItem(from line: String) -> String? {
        // "1. 내용" / "12) 내용"
        let digits = line.prefix { $0.isNumber }
        guard !digits.isEmpty else { return nil }
        let rest = line.dropFirst(digits.count)
        guard rest.hasPrefix(". ") || rest.hasPrefix(") ") else { return nil }
        return String(rest.dropFirst(2)).trimmingCharacters(in: .whitespaces)
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        guard line.hasPrefix("|") else { return false }
        let stripped = line.filter { !" |-:".contains($0) }
        return stripped.isEmpty && line.contains("-")
    }

    private static func tableCells(_ line: String) -> [String] {
        line
            .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

/// 마크다운 블록을 그린다.
///
/// 표는 좁은 화면에서 글자를 줄이지 않고 **가로로 스크롤**한다(개인정보 동의 표가 4열이다).
struct MoyeoMarkdownView: View {
    let markdown: String
    var spacing: CGFloat = 12

    private var blocks: [MoyeoMarkdownBlock] {
        MoyeoMarkdownParser.blocks(from: markdown)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(blocks) { block in
                view(for: block)
            }
        }
    }

    @ViewBuilder
    private func view(for block: MoyeoMarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(inline(text))
                .font(headingFont(level: level))
                .foregroundStyle(MoyeoTheme.ink)
                .padding(.top, level <= 2 ? 6 : 2)
        case .paragraph(let text):
            Text(inline(text))
                .font(MoyeoTypography.cardBody)
                .foregroundStyle(MoyeoTheme.text700)
                .fixedSize(horizontal: false, vertical: true)
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    listRow(marker: "•", text: item)
                }
            }
        case .ordered(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    listRow(marker: "\(index + 1).", text: item)
                }
            }
        case .table(let header, let rows):
            table(header: header, rows: rows)
        }
    }

    private func listRow(marker: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(verbatim: marker)
                .font(MoyeoTypography.cardBody)
                .foregroundStyle(MoyeoTheme.muted)
            Text(inline(text))
                .font(MoyeoTypography.cardBody)
                .foregroundStyle(MoyeoTheme.text700)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func table(header: [String], rows: [[String]]) -> some View {
        let columnCount = max(header.count, rows.map(\.count).max() ?? 0)
        return ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                tableRow(cells: header, columnCount: columnCount, isHeader: true)
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    Divider().overlay(MoyeoTheme.softLine)
                    tableRow(cells: row, columnCount: columnCount, isHeader: false)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(MoyeoTheme.softLine, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func tableRow(cells: [String], columnCount: Int, isHeader: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0..<columnCount, id: \.self) { index in
                Text(inline(index < cells.count ? cells[index] : ""))
                    .font(isHeader ? MoyeoTypography.font(size: 13, weight: .bold, relativeTo: .caption) : MoyeoTypography.cardMeta)
                    .foregroundStyle(isHeader ? MoyeoTheme.ink : MoyeoTheme.text700)
                    .frame(width: 132, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .fixedSize(horizontal: false, vertical: true)
                if index < columnCount - 1 {
                    Rectangle().fill(MoyeoTheme.softLine).frame(width: 1)
                }
            }
        }
        .background(isHeader ? MoyeoTheme.subtleBackground : Color.clear)
    }

    private func headingFont(level: Int) -> Font {
        switch level {
        case 1: MoyeoTypography.sectionTitle
        case 2: MoyeoTypography.cardTitle
        default: MoyeoTypography.font(size: 13, weight: .bold, relativeTo: .caption)
        }
    }

    /// 굵게·링크 같은 인라인 문법은 `AttributedString` 이 처리한다.
    /// 실패하면 원문을 그대로 보여준다 — 내용을 삼키지 않는다.
    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }
}
