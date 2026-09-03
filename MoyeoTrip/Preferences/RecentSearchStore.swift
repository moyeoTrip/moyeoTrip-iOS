import Combine
import Foundation

/// 최근 검색어 규칙. 서버에 최근 검색어 API가 없어 100% 클라이언트 구현이다.
/// 세 플랫폼이 같은 규칙을 쓰도록 순수 함수로 떼어 둔다.
enum RecentSearchPolicy {
    /// 최대 보관 개수. 초과하면 오래된 것부터 버린다.
    static let limit = 10

    /// 공백 트림 · 빈 문자열 무시 · 중복은 최신순으로 끌어올림 · 최대 `limit` 개
    static func adding(_ keyword: String, to searches: [String]) -> [String] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return searches }

        var updated = searches.filter { $0 != trimmed }
        updated.insert(trimmed, at: 0)
        if updated.count > limit {
            updated.removeSubrange(limit..<updated.count)
        }
        return updated
    }

    static func removing(_ keyword: String, from searches: [String]) -> [String] {
        searches.filter { $0 != keyword }
    }

    /// 저장소에서 읽은 값을 신뢰하지 않는다 — 빈 값·중복·초과분을 걸러낸다.
    static func sanitized(_ searches: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for keyword in searches {
            let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            result.append(trimmed)
            if result.count == limit { break }
        }
        return result
    }
}

/// 최근 검색어 영구 저장소. `UserDefaultsAuthDisplayProfileStore` 와 같은 패턴이다.
protocol RecentSearchStoring {
    func load() -> [String]
    func save(_ searches: [String])
}

final class UserDefaultsRecentSearchStore: RecentSearchStoring {
    static let defaultsKey = "recent-searches"

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = UserDefaultsRecentSearchStore.defaultsKey) {
        self.defaults = defaults
        self.key = key
    }

    func load() -> [String] {
        RecentSearchPolicy.sanitized(defaults.stringArray(forKey: key) ?? [])
    }

    func save(_ searches: [String]) {
        defaults.set(searches, forKey: key)
    }
}

/// 디스크에 남기지 않는 저장소 — 테스트에서 쓴다.
final class InMemoryRecentSearchStore: RecentSearchStoring {
    private var searches: [String]

    init(searches: [String] = []) {
        self.searches = searches
    }

    func load() -> [String] { searches }

    func save(_ searches: [String]) {
        self.searches = searches
    }
}

@MainActor
final class RecentSearchModel: ObservableObject {
    @Published private(set) var searches: [String]

    private let store: RecentSearchStoring

    init(store: RecentSearchStoring) {
        self.store = store
        searches = store.load()
    }

    /// 캡처도 실제 앱과 같은 저장소를 쓴다 (NO-MOCK-CANON R2) — 캡처 전용 검색어 주입은 없다.
    static func forCurrentRuntime() -> RecentSearchModel {
        RecentSearchModel(store: UserDefaultsRecentSearchStore())
    }

    func record(_ keyword: String) {
        apply(RecentSearchPolicy.adding(keyword, to: searches))
    }

    func remove(_ keyword: String) {
        apply(RecentSearchPolicy.removing(keyword, from: searches))
    }

    func clear() {
        apply([])
    }

    private func apply(_ updated: [String]) {
        guard updated != searches else { return }
        searches = updated
        store.save(updated)
    }
}
