import Combine
import Foundation

/// 관광 콘텐츠 타입 (tourism-contents/types) — 17-1a 타입 필터
struct ServerTourismContentType: Decodable, Identifiable, Hashable {
    let contentTypeId: Int
    let contentTypeName: String

    var id: Int { contentTypeId }
}

/// 관광 콘텐츠 목록 한 페이지. 개수 표기는 클라가 센 값이 아니라 서버의 `totalElements` 를 쓴다 (17-1a).
nonisolated struct TourismPlacePage: Sendable {
    let places: [TourismPlace]
    let totalElements: Int?

    init(places: [TourismPlace], totalElements: Int? = nil) {
        self.places = places
        self.totalElements = totalElements
    }
}

protocol TourismContentProviding: Sendable {
    /// 17-1a 검색 — 검색어는 서버가 제목·기본주소·상세주소로 매칭한다. 화면에서 다시 거르지 않는다.
    func places(keyword: String, contentTypeID: Int?) async throws -> TourismPlacePage
    /// 같은 검색의 `page` 쪽(1부터). 목데이터 서비스는 한 장이 전부라 기본 구현이 빈 쪽을 준다.
    func places(keyword: String, contentTypeID: Int?, page: Int) async throws -> TourismPlacePage
    func place(id: String) async throws -> TourismPlace
    func contentTypes() async throws -> [ServerTourismContentType]
    /// 실서버 목록인지 — 목데이터 서비스는 false 다. 결과가 0건이어도 판별이 흔들리면 안 된다.
    var providesServerContent: Bool { get }
}

extension TourismContentProviding {
    /// 목데이터 서비스는 서버 타입 목록을 주지 않는다 — 화면은 기존 3종 필터를 유지한다
    func contentTypes() async throws -> [ServerTourismContentType] { [] }

    /// 쪽 개념이 없는 서비스는 첫 쪽만 주고 그 뒤는 비운다 — 없는 결과를 지어내지 않는다.
    func places(keyword: String, contentTypeID: Int?, page: Int) async throws -> TourismPlacePage {
        guard page <= 1 else { return TourismPlacePage(places: [], totalElements: nil) }
        return try await places(keyword: keyword, contentTypeID: contentTypeID)
    }

    var providesServerContent: Bool { false }
}

struct SampleTourismContentService: TourismContentProviding {
    /// 목데이터는 서버를 대신해 제목·주소를 직접 매칭한다.
    /// 캡처 경로(`UITEST_MODE`)는 네트워크를 타지 않고 이 목록을 그대로 그린다.
    func places(keyword: String, contentTypeID: Int?) async throws -> TourismPlacePage {
        let normalized = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let matched = TourismPlaceCatalog.places.filter { place in
            guard !normalized.isEmpty else { return true }
            return place.title.contains(normalized) || (place.address ?? "").contains(normalized)
        }
        return TourismPlacePage(places: matched, totalElements: matched.count)
    }

    func place(id: String) async throws -> TourismPlace {
        TourismPlaceCatalog.places.first { $0.id == id } ?? TourismPlaceCatalog.places[2]
    }
}

final class TourismAPIClient: TourismContentProviding, @unchecked Sendable {
    private let configuration: AuthAPIConfiguration
    private let session: URLSession
    private let sessionStore: AuthSessionStoring

    init(
        configuration: AuthAPIConfiguration = .current,
        session: URLSession = .shared,
        sessionStore: AuthSessionStoring = KeychainAuthSessionStore()
    ) {
        self.configuration = configuration
        self.session = session
        self.sessionStore = sessionStore
    }

    var providesServerContent: Bool { true }

    /// 17-1a 검색·타입 필터 — 검색어와 타입을 모두 서버로 넘긴다.
    /// 검색어가 비면 파라미터를 보내지 않는다(전체 조회). 결과 0건은 정상 응답이라 폴백하지 않는다.
    func places(keyword: String, contentTypeID: Int?) async throws -> TourismPlacePage {
        try await places(keyword: keyword, contentTypeID: contentTypeID, page: 1)
    }

    /// 서버 `page` 는 **1부터**고 `size` 는 100 이 상한이다(`TourismContentController:25-27`).
    /// 예전에는 `size=100` 한 번만 불러서, 「3,115곳」이라고 적어 놓고 **100번째에서 목록이
    /// 끝났다** — 더 볼 길도, 끝이 아니라는 표시도 없었다 (IOS-F91).
    func places(keyword: String, contentTypeID: Int?, page: Int) async throws -> TourismPlacePage {
        var query = [
            URLQueryItem(name: "size", value: "\(Self.pageSize)"),
            URLQueryItem(name: "page", value: "\(max(1, page))")
        ]
        let normalized = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.isEmpty {
            query.append(URLQueryItem(name: "keyword", value: normalized))
        }
        if let contentTypeID {
            query.append(URLQueryItem(name: "contentTypeId", value: "\(contentTypeID)"))
        }
        let data = try await get(path: "/api/v1/tourism-contents", query: query)
        return try TourismAPIResponseParser.page(from: data)
    }

    static let pageSize = 100

    func place(id: String) async throws -> TourismPlace {
        let encodedID = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let data = try await get(path: "/api/v1/tourism-contents/\(encodedID)")
        return try TourismAPIResponseParser.place(from: data)
    }

    func contentTypes() async throws -> [ServerTourismContentType] {
        let data = try await get(path: "/api/v1/tourism-contents/types")
        let types = try JSONDecoder().decode([ServerTourismContentType].self, from: data)
        guard !types.isEmpty else { throw TourismAPIError.invalidPayload }
        return types
    }

    private func get(path: String, query: [URLQueryItem] = []) async throws -> Data {
        var url = configuration.baseURL.appending(path: path)
        if !query.isEmpty {
            url.append(queryItems: query)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = try? sessionStore.load()?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TourismAPIError.transport(error.localizedDescription)
        }
        guard let response = response as? HTTPURLResponse else { throw TourismAPIError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else {
            throw TourismAPIError.server(statusCode: response.statusCode)
        }
        return data
    }
}

enum TourismAPIError: Error, Equatable {
    case transport(String)
    case invalidResponse
    case server(statusCode: Int)
    case invalidPayload
}

/// 서버 `homepage` 는 앵커 태그가 그대로 온다 (17-1b 실측):
/// `<a href="http://www.141minihotel.com/" target="_blank" title="새창 : …">http://www.141minihotel.com</a>`
/// 태그를 그대로 그리면 화면에 마크업이 노출된다 — URL(없으면 표시 텍스트)만 남기고, 못 얻으면 nil(줄 숨김)이다.
enum TourismHomepageText {
    static func displayText(from raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.contains("<") else { return decodingEntities(trimmed) }

        if let href = href(in: trimmed) {
            let value = decodingEntities(href)
            if !value.isEmpty { return value }
        }
        let stripped = decodingEntities(strippingTags(trimmed))
        return stripped.isEmpty ? nil : stripped
    }

    /// `href = "..."` / `href='...'` / 따옴표 없는 `href=...` 를 모두 읽는다.
    private static func href(in value: String) -> String? {
        guard let keyword = value.range(of: "href", options: .caseInsensitive) else { return nil }
        let afterKeyword = value[keyword.upperBound...]
        guard let equals = afterKeyword.firstIndex(of: "=") else { return nil }
        let afterEquals = afterKeyword[afterKeyword.index(after: equals)...]
        guard let opening = afterEquals.firstIndex(where: { !$0.isWhitespace }) else { return nil }

        let quote = afterEquals[opening]
        if quote == "\"" || quote == "'" {
            let start = afterEquals.index(after: opening)
            guard let closing = afterEquals[start...].firstIndex(of: quote) else { return nil }
            return String(afterEquals[start..<closing]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let end = afterEquals[opening...].firstIndex { $0.isWhitespace || $0 == ">" } ?? afterEquals.endIndex
        return String(afterEquals[opening..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

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
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodingEntities(_ value: String) -> String {
        var result = value
        for (entity, character) in [
            ("&amp;", "&"), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"),
            ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " ")
        ] {
            result = result.replacingOccurrences(of: entity, with: character)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum TourismAPIResponseParser {
    static func places(from data: Data) throws -> [TourismPlace] {
        try page(from: data).places
    }

    /// 목록 응답 한 페이지. 개수 표기에 쓰는 `totalElements` 까지 함께 읽는다 (17-1a).
    static func page(from data: Data) throws -> TourismPlacePage {
        let root = try JSONSerialization.jsonObject(with: data)
        guard let objects = findObjectArray(in: root) else { throw TourismAPIError.invalidPayload }
        let total = (root as? [String: Any])
            .flatMap { number($0, keys: ["totalElements", "totalCount", "total"]) }
            .map { Int($0) }
        return TourismPlacePage(places: objects.compactMap { makePlace($0, detail: false) }, totalElements: total)
    }

    static func place(from data: Data) throws -> TourismPlace {
        let root = try JSONSerialization.jsonObject(with: data)
        guard let object = findObject(in: root), let place = makePlace(object, detail: true) else {
            throw TourismAPIError.invalidPayload
        }
        return place
    }

    private static func findObjectArray(in value: Any) -> [[String: Any]]? {
        if let values = value as? [[String: Any]] { return values }
        guard let object = value as? [String: Any] else { return nil }
        for key in ["contents", "content", "items", "list", "results", "data"] {
            if let nested = object[key], let result = findObjectArray(in: nested) { return result }
        }
        return nil
    }

    private static func findObject(in value: Any) -> [String: Any]? {
        guard let object = value as? [String: Any] else { return nil }
        if string(object, keys: ["contentId", "id"]) != nil { return object }
        for key in ["content", "item", "result", "data"] {
            if let nested = object[key], let result = findObject(in: nested) { return result }
        }
        return nil
    }

    private static func makePlace(_ object: [String: Any], detail: Bool) -> TourismPlace? {
        // 서버 응답은 address1/address2 · zipcode · telephone(Name) · contentImages · originalImageUrl 을 쓴다.
        // 주소·좌표·전화는 모두 nullable 이다 — 없으면 지어내지 않고 nil 로 두어 화면에서 줄을 숨긴다.
        guard let id = string(object, keys: ["contentId", "id"]),
              let title = string(object, keys: ["title", "name"])
        else { return nil }

        let imageURLs = detail ? urls(object, keys: ["contentImages", "images", "imageList", "generalImages"]) : []
        let menuURLs = detail ? urls(object, keys: ["menuImages", "menuImageList"]) : []
        return TourismPlace(
            id: id,
            type: contentType(object),
            title: title,
            address: address(object),
            latitude: number(object, keys: ["latitude", "mapY", "mapy"]),
            longitude: number(object, keys: ["longitude", "mapX", "mapx"]),
            thumbnailURL: url(object, keys: ["thumbnail", "thumbnailUrl", "firstImage", "imageUrl"]),
            postalCode: string(object, keys: ["postalCode", "zipCode", "zipcode"]),
            phone: string(object, keys: ["phone", "tel", "telephone"]),
            phoneLabel: string(object, keys: ["phoneLabel", "telName", "telephoneName"]),
            homepage: TourismHomepageText.displayText(from: string(object, keys: ["homepage", "homePage", "website"])),
            // `overview` 는 HTML 조각으로 온다 — 태그·스타일을 걷어내고 문단만 남긴다.
            // 예전에는 원문 그대로 담아 `<div class="…">` 와 CSS 가 화면에 글자로 보였다.
            summary: TourismRichText.plainText(from: string(object, keys: ["summary", "overview", "description"])),
            imageLabels: imageURLs.indices.map { "장소 사진 \($0 + 1)" },
            menuImageLabels: menuURLs.indices.map { "메뉴판 \($0 + 1)" },
            imageURLs: imageURLs,
            menuImageURLs: menuURLs,
            serverContentTypeID: serverContentTypeID(object)
        )
    }

    /// 기본주소(`address1`)와 상세주소(`address2`)를 한 줄로 합친다. 둘 다 없으면 nil 이다.
    private static func address(_ object: [String: Any]) -> String? {
        let base = string(object, keys: ["address", "address1", "addr1"])
        guard let detail = string(object, keys: ["address2", "addr2"]) else { return base }
        guard let base else { return detail }
        return base.contains(detail) ? base : "\(base) \(detail)"
    }

    private static func serverContentTypeID(_ object: [String: Any]) -> Int? {
        guard let value = string(object, keys: ["contentTypeId", "contenttypeid"]) else { return nil }
        return Int(value)
    }

    private static func contentType(_ object: [String: Any]) -> TourismContentType {
        let value = string(object, keys: ["contentTypeName", "typeName", "contentType", "type", "category"])?.lowercased() ?? ""
        let typeID = string(object, keys: ["contentTypeId", "contenttypeid"]) ?? ""
        if value.contains("식") || value.contains("food") || value.contains("restaurant") || typeID == "39" { return .restaurant }
        if value.contains("숙") || value.contains("stay") || value.contains("lodging") || typeID == "32" { return .lodging }
        return .attraction
    }

    private static func string(_ object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = object[key] as? String, !value.isEmpty { return value }
            if let value = object[key] as? NSNumber { return value.stringValue }
        }
        return nil
    }

    private static func number(_ object: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = object[key] as? NSNumber { return value.doubleValue }
            if let value = object[key] as? String, let number = Double(value) { return number }
        }
        return nil
    }

    /// 관광 콘텐츠 이미지는 절대 URL 로 오지만, 상대 경로로 오는 값이 섞여도 한 곳에서 흡수한다.
    private static func url(_ object: [String: Any], keys: [String]) -> URL? {
        guard let value = string(object, keys: keys) else { return nil }
        return MoyeoImageURL.resolve(value)
    }

    private static func urls(_ object: [String: Any], keys: [String]) -> [URL] {
        for key in keys {
            guard let values = object[key] as? [Any] else { continue }
            return values.compactMap { value in
                if let value = value as? String { return MoyeoImageURL.resolve(value) }
                guard let value = value as? [String: Any] else { return nil }
                return url(value, keys: ["originalImageUrl", "url", "imageUrl", "originImageUrl", "originimgurl"])
            }
        }
        return []
    }
}

@MainActor
final class TourismPlaceSearchModel: ObservableObject {
    /// 목록. **번들 카탈로그로 미리 채우지 않는다** — 서버 응답 전에는 아무것도 없다.
    /// 예전에는 초기값이 `TourismPlaceCatalog.places` 라, 첫 진입에서 번들 예시가
    /// 실서버 결과인 것처럼 보이고 그 행을 누르면 실제로 없는 장소가 열렸다
    /// (정본 NO-MOCK-CANON R1 위반 · TC PLACE-002·PLACE-017).
    @Published private(set) var places: [TourismPlace] = []
    @Published private(set) var isLoading = false
    @Published private(set) var fallbackMessage: String?
    /// 서버 타입 목록 — 비어 있으면 화면은 기존 3종 필터를 유지한다 (17-1a)
    @Published private(set) var contentTypes: [ServerTourismContentType] = []
    @Published private(set) var selectedContentTypeID: Int?
    /// 목록이 서버 응답인지 — 서버 목록에서는 개수 표기와 정렬 문구가 달라진다
    @Published private(set) var isServerBacked = false
    /// 서버가 준 전체 결과 수 — 검색 결과 개수는 클라가 센 값이 아니라 이 값을 쓴다 (17-1a)
    @Published private(set) var totalElements: Int?
    let service: TourismContentProviding

    private(set) var keyword = ""
    private var hasLoaded = false
    /// 지금까지 받은 쪽 번호(1부터). 다음에 부를 쪽은 `loadedPage + 1` 이다.
    private var loadedPage = 0
    /// 더 받을 것이 남았는가. 서버가 빈 쪽을 주거나 `totalElements` 에 닿으면 false 다.
    @Published private(set) var hasMorePages = false
    @Published private(set) var isLoadingMore = false

    /// 검색어 한 글자마다 서버를 부르지 않도록 잠깐 기다린다
    static let searchDebounceNanoseconds: UInt64 = 300_000_000

    init(service: TourismContentProviding) {
        self.service = service
    }

    /// 17-1a 검색 — 검색어는 서버로 넘긴다. 첫 호출에서만 타입 목록을 함께 받는다.
    func apply(keyword newKeyword: String) async {
        let normalized = newKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if hasLoaded {
            guard normalized != keyword else { return }
            try? await Task.sleep(nanoseconds: Self.searchDebounceNanoseconds)
            guard !Task.isCancelled else { return }
        } else {
            contentTypes = (try? await service.contentTypes()) ?? []
            guard !Task.isCancelled else { return }
        }
        hasLoaded = true
        keyword = normalized
        await loadPlaces()
    }

    /// 17-1a 타입 칩 — 검색어와 함께 서버로 넘겨 목록을 다시 불러온다
    func selectContentType(_ contentTypeID: Int?) async {
        guard selectedContentTypeID != contentTypeID else { return }
        selectedContentTypeID = contentTypeID
        await loadPlaces()
    }

    private func loadPlaces() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // 결과 0건은 정상 응답이다 — 목데이터로 되돌리지 않고 빈 목록 그대로 둔다
            let page = try await service.places(keyword: keyword, contentTypeID: selectedContentTypeID, page: 1)
            places = page.places
            totalElements = page.totalElements
            loadedPage = 1
            hasMorePages = Self.hasMore(loaded: page.places.count, total: page.totalElements, received: page.places.count)
            fallbackMessage = nil
            isServerBacked = service.providesServerContent
        } catch {
            // 실패를 **예시 장소로 덮지 않는다** (NO-MOCK-CANON R1) — 빈 목록과
            // 실패 안내를 그려, 사용자가 「결과가 없다」와 「못 받았다」를 구분하게 한다.
            places = []
            totalElements = nil
            loadedPage = 0
            hasMorePages = false
            isServerBacked = false
            fallbackMessage = "방문지를 불러오지 못했어요. 잠시 후 다시 시도해주세요."
        }
    }

    /// 목록 끝에 닿으면 다음 쪽을 잇는다. 예전에는 100번째에서 그냥 끝났다 (IOS-F91).
    func loadNextPageIfNeeded() async {
        guard isServerBacked, hasMorePages, !isLoading, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let next = loadedPage + 1
        guard let page = try? await service.places(
            keyword: keyword, contentTypeID: selectedContentTypeID, page: next
        ) else {
            // 못 받았으면 **끝이라고 말하지 않는다** — 다음 스크롤에서 다시 해 본다.
            return
        }
        loadedPage = next
        // 서버가 같은 것을 다시 줄 수 있어 id 로 거른다.
        let known = Set(places.map(\.id))
        places.append(contentsOf: page.places.filter { !known.contains($0.id) })
        if let total = page.totalElements { totalElements = total }
        hasMorePages = Self.hasMore(loaded: places.count, total: totalElements, received: page.places.count)
    }

    /// 받은 쪽이 비었거나 전체 수에 닿았으면 끝이다.
    private static func hasMore(loaded: Int, total: Int?, received: Int) -> Bool {
        guard received > 0 else { return false }
        guard let total else { return received >= TourismAPIClient.pageSize }
        return loaded < total
    }
}
