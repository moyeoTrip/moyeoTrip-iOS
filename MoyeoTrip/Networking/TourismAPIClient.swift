import Combine
import Foundation

/// 관광 콘텐츠 타입 (tourism-contents/types) — 17-1a 타입 필터
struct ServerTourismContentType: Decodable, Identifiable, Hashable {
    let contentTypeId: Int
    let contentTypeName: String

    var id: Int { contentTypeId }
}

protocol TourismContentProviding: Sendable {
    func places() async throws -> [TourismPlace]
    func places(contentTypeID: Int?) async throws -> [TourismPlace]
    func place(id: String) async throws -> TourismPlace
    func contentTypes() async throws -> [ServerTourismContentType]
}

extension TourismContentProviding {
    func places(contentTypeID: Int?) async throws -> [TourismPlace] {
        try await places()
    }

    /// 목데이터 서비스는 서버 타입 목록을 주지 않는다 — 화면은 기존 3종 필터를 유지한다
    func contentTypes() async throws -> [ServerTourismContentType] { [] }
}

struct SampleTourismContentService: TourismContentProviding {
    func places() async throws -> [TourismPlace] { TourismPlaceCatalog.places }

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

    func places() async throws -> [TourismPlace] {
        try await places(contentTypeID: nil)
    }

    /// 17-1a 타입 필터 — 타입을 고르면 서버가 그 유형만 페이지로 준다.
    /// 서버에 키워드 검색이 없어 화면 검색창은 받아온 페이지 안에서만 걸러진다 — 한 페이지를 넉넉히 받는다.
    func places(contentTypeID: Int?) async throws -> [TourismPlace] {
        var query = [URLQueryItem(name: "size", value: "100")]
        if let contentTypeID {
            query.append(URLQueryItem(name: "contentTypeId", value: "\(contentTypeID)"))
        }
        let data = try await get(path: "/api/v1/tourism-contents", query: query)
        let places = try TourismAPIResponseParser.places(from: data)
        guard !places.isEmpty else { throw TourismAPIError.invalidPayload }
        return places
    }

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

enum TourismAPIResponseParser {
    static func places(from data: Data) throws -> [TourismPlace] {
        let root = try JSONSerialization.jsonObject(with: data)
        guard let objects = findObjectArray(in: root) else { throw TourismAPIError.invalidPayload }
        return objects.compactMap { makePlace($0, detail: false) }
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
        // 서버 응답은 address1/address2 · contentImages · originalImageUrl 을 쓴다 (실응답 확인)
        guard let id = string(object, keys: ["contentId", "id"]),
              let title = string(object, keys: ["title", "name"]),
              let address = string(object, keys: ["address", "address1", "addr1"])
        else { return nil }

        let type = contentType(object)
        let imageURLs = detail ? urls(object, keys: ["contentImages", "images", "imageList", "generalImages"]) : []
        let menuURLs = detail ? urls(object, keys: ["menuImages", "menuImageList"]) : []
        return TourismPlace(
            id: id,
            type: type,
            title: title,
            address: address,
            latitude: number(object, keys: ["latitude", "mapY", "mapy"]) ?? 0,
            longitude: number(object, keys: ["longitude", "mapX", "mapx"]) ?? 0,
            thumbnailURL: url(object, keys: ["thumbnail", "thumbnailUrl", "firstImage", "imageUrl"]),
            postalCode: string(object, keys: ["postalCode", "zipCode", "zipcode"]) ?? "정보 없음",
            phone: string(object, keys: ["phone", "tel", "telephone"]) ?? "정보 없음",
            phoneLabel: string(object, keys: ["phoneLabel", "telName", "telephoneName"]) ?? "전화 안내",
            homepage: string(object, keys: ["homepage", "homePage", "website"]) ?? "정보 없음",
            summary: string(object, keys: ["summary", "overview", "description"]) ?? "상세 소개가 아직 제공되지 않았어요.",
            imageLabels: imageURLs.indices.map { "장소 사진 \($0 + 1)" },
            menuImageLabels: menuURLs.indices.map { "메뉴판 \($0 + 1)" },
            imageURLs: imageURLs,
            menuImageURLs: menuURLs,
            serverContentTypeID: serverContentTypeID(object)
        )
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

    private static func url(_ object: [String: Any], keys: [String]) -> URL? {
        guard let value = string(object, keys: keys) else { return nil }
        return URL(string: value)
    }

    private static func urls(_ object: [String: Any], keys: [String]) -> [URL] {
        for key in keys {
            guard let values = object[key] as? [Any] else { continue }
            return values.compactMap { value in
                if let value = value as? String { return URL(string: value) }
                guard let value = value as? [String: Any] else { return nil }
                return url(value, keys: ["originalImageUrl", "url", "imageUrl", "originImageUrl", "originimgurl"])
            }
        }
        return []
    }
}

@MainActor
final class TourismPlaceSearchModel: ObservableObject {
    @Published private(set) var places = TourismPlaceCatalog.places
    @Published private(set) var isLoading = false
    @Published private(set) var fallbackMessage: String?
    /// 서버 타입 목록 — 비어 있으면 화면은 기존 3종 필터를 유지한다 (17-1a)
    @Published private(set) var contentTypes: [ServerTourismContentType] = []
    @Published private(set) var selectedContentTypeID: Int?
    /// 목록이 서버 응답인지 — 목데이터 장소에는 서버 유형 ID가 없다
    @Published private(set) var isServerBacked = false
    let service: TourismContentProviding

    init(service: TourismContentProviding) {
        self.service = service
    }

    func load() async {
        contentTypes = (try? await service.contentTypes()) ?? []
        await loadPlaces()
    }

    /// 17-1a 타입 칩 — 서버 타입으로 목록을 다시 불러온다
    func selectContentType(_ contentTypeID: Int?) async {
        guard selectedContentTypeID != contentTypeID else { return }
        selectedContentTypeID = contentTypeID
        await loadPlaces()
    }

    private func loadPlaces() async {
        isLoading = true
        defer { isLoading = false }
        do {
            places = try await service.places(contentTypeID: selectedContentTypeID)
            fallbackMessage = nil
            isServerBacked = places.contains { $0.serverContentTypeID != nil }
        } catch {
            places = TourismPlaceCatalog.places
            selectedContentTypeID = nil
            isServerBacked = false
            fallbackMessage = "관광 API를 불러오지 못해 저장된 예시 장소를 보여드려요."
        }
    }
}
