//
//  TourismRichText.swift
//  MoyeoTrip
//
//  관광 API 의 `overview` 는 **HTML 조각**으로 온다. 태그와 스타일 블록이 섞여 있어
//  평문 `Text` 로 그리면 글자 그대로 화면에 노출됐다 — 달기약수탕 실측(2026-09-14):
//
//      <div class="text202503">…</div>.text202503{ COLOR: #FF0000; }
//
//  같은 파일의 `homepage` 는 이미 앵커 태그를 걷어내고 있었는데(`TourismHomepageText`)
//  `overview` 만 빠져 있었다 (웹 교차 발견 — 웹은 `tourism-api.js` 의 `plainText()` 로 고쳤다).
//
//  **글자는 줄이지 않는다.** 요약하거나 자르지 않고, 태그·스타일만 걷어내고 문단은 살린다.
//

import Foundation

enum TourismRichText {
    /// HTML 조각을 문단이 살아 있는 평문으로 바꾼다. 남는 것이 없으면 `nil` 이다.
    static func plainText(from raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // 태그도 스타일도 없으면 손대지 않는다 — 멀쩡한 글을 건드릴 이유가 없다.
        guard trimmed.contains("<") || trimmed.contains("{") else { return trimmed }

        var text = trimmed
        text = removingBlocks(in: text, tag: "style")
        text = removingBlocks(in: text, tag: "script")
        text = convertingLineBreaks(in: text)
        text = strippingTags(text)
        text = removingStyleRules(in: text)
        text = decodingEntities(text)
        text = collapsingBlankLines(in: text)

        let result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    /// `<style>…</style>` 처럼 **내용까지 통째로** 버려야 하는 구간.
    private static func removingBlocks(in value: String, tag: String) -> String {
        replacing(in: value, pattern: "<\(tag)\\b[^>]*>[\\s\\S]*?</\(tag)\\s*>", with: " ")
    }

    /// 문단을 만드는 태그는 줄바꿈으로 바꾼다 — 통째로 지우면 문단이 한 덩어리가 된다.
    private static func convertingLineBreaks(in value: String) -> String {
        var text = replacing(in: value, pattern: "<br\\s*/?>", with: "\n")
        text = replacing(in: text, pattern: "</\\s*(p|div|li|tr|h[1-6])\\s*>", with: "\n")
        return text
    }

    /// 남은 태그를 버린다. `TourismHomepageText` 와 같은 방식이다.
    private static func strippingTags(_ value: String) -> String {
        var result = ""
        var depth = 0
        for character in value {
            if character == "<" {
                depth += 1
            } else if character == ">" {
                depth = max(0, depth - 1)
            } else if depth == 0 {
                result.append(character)
            }
        }
        return result
    }

    /// 태그를 걷어내도 **본문에 남는 CSS 규칙**(`.text202503{ COLOR: #FF0000; }`)을 버린다.
    ///
    /// 중괄호가 있다고 무조건 지우면 본문 속 괄호까지 없어지므로,
    /// **중괄호 안에 `:` 가 있는 것**(선언처럼 보이는 것)만 버린다.
    private static func removingStyleRules(in value: String) -> String {
        replacing(in: value, pattern: "[^{}\\n]*\\{[^{}]*:[^{}]*\\}", with: " ")
    }

    private static func decodingEntities(_ value: String) -> String {
        var result = value
        for (entity, character) in [
            ("&amp;", "&"), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"),
            ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " ")
        ] {
            result = result.replacingOccurrences(of: entity, with: character)
        }
        return result
    }

    /// 태그를 걷어내면 빈 줄이 잔뜩 남는다. 문단 사이는 한 줄만 비운다.
    private static func collapsingBlankLines(in value: String) -> String {
        let lines = value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        var result: [String] = []
        for line in lines {
            if line.isEmpty, result.last?.isEmpty != false { continue }
            result.append(line)
        }
        while result.last?.isEmpty == true { result.removeLast() }
        return result.joined(separator: "\n")
    }

    private static func replacing(in value: String, pattern: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else { return value }
        let range = NSRange(value.startIndex..., in: value)
        return regex.stringByReplacingMatches(in: value, range: range, withTemplate: template)
    }
}
