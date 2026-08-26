//
//  TourismContentContractTests.swift
//  MoyeoTripTests
//
//  17-1a 방문지 검색 · 17-1b 방문지 상세 계약 테스트.
//  본문 JSON 은 2026-08-25 재배포 뒤 실서버 응답 형태를 그대로 고정한 것이다
//  (`GET /api/v1/tourism-contents?keyword=` · `GET /api/v1/tourism-contents/{contentId}`).
//  응답을 요약하면 계약이 흐려지므로 파일 길이 제한을 끈다.
//

import Foundation
@testable import MoyeoTrip
import Testing

// swiftlint:disable file_length

// MARK: - 상세 응답 파싱 (17-1b)

@Suite
struct TourismContentDetailContractTests {
    /// 음식점 상세. `zipcode`·`telephone` 은 대부분의 항목에서 null 이고, `homepage` 는 앵커 태그로 온다.
    private static let restaurantDetailJSON = #"""
    {"contentId":2802238,"contentTypeId":39,"title":"141미니호텔 식당",
     "address1":"경상북도 경주시 원화로 141","address2":"1층",
     "zipcode":null,"telephone":null,"telephoneName":null,
     "homepage":"<a href=\"http://www.141minihotel.com/\" target=\"_blank\" title=\"새창 : 141미니호텔 홈페이지로 이동\">http://www.141minihotel.com</a>",
     "overview":"경주역 앞 한식당이에요.",
     "thumbnail":"https://tong.visitkorea.or.kr/cms/resource/thumb.jpg",
     "longitude":129.2249,"latitude":35.8562,
     "contentImages":[
       {"contentId":2802238,"imageName":"외관.jpg",
        "originalImageUrl":"https://tong.visitkorea.or.kr/cms/resource/out.jpg",
        "serialNumber":"3040993","copyrightType":"Type1"},
       {"contentId":2802238,"imageName":"내부.jpg",
        "originalImageUrl":"https://tong.visitkorea.or.kr/cms/resource/in.jpg",
        "serialNumber":"3040994","copyrightType":"Type1"}],
     "menuImages":[
       {"contentId":2802238,"imageName":"메뉴판.jpg",
        "originalImageUrl":"https://tong.visitkorea.or.kr/cms/resource/menu.jpg",
        "serialNumber":"3040995","copyrightType":"Type1"}]}
    """#

    @Test func restaurantDetailUsesServerFieldsAndKeepsMenuImages() throws {
        let place = try TourismAPIResponseParser.place(from: Data(Self.restaurantDetailJSON.utf8))

        #expect(place.id == "2802238")
        #expect(place.type == .restaurant)
        #expect(place.title == "141미니호텔 식당")
        // address1 + address2 를 한 줄로 합친다
        #expect(place.address == "경상북도 경주시 원화로 141 1층")
        #expect(place.summary == "경주역 앞 한식당이에요.")
        #expect(place.latitude == 35.8562)
        #expect(place.longitude == 129.2249)
        #expect(place.imageURLs.count == 2)
        #expect(place.menuImageURLs.count == 1)
        #expect(place.showsMenuImages)
        #expect(place.menuImageURLs[0].absoluteString == "https://tong.visitkorea.or.kr/cms/resource/menu.jpg")
    }

    @Test func nullFieldsStayNilInsteadOfInventedText() throws {
        let place = try TourismAPIResponseParser.place(from: Data(Self.restaurantDetailJSON.utf8))

        // 서버가 null 로 준 값은 지어내지 않는다 — 예전의 "정보 없음" · "전화 안내" 채우기를 되살리지 않는다
        #expect(place.postalCode == nil)
        #expect(place.phone == nil)
        #expect(place.phoneLabel == nil)
    }

    @Test func homepageAnchorTagIsNeverRendered() throws {
        let place = try TourismAPIResponseParser.place(from: Data(Self.restaurantDetailJSON.utf8))

        #expect(place.homepage == "http://www.141minihotel.com/")
        #expect(place.homepage?.contains("<a") == false)
        #expect(place.homepage?.contains("target=") == false)
        #expect(place.homepage?.contains("새창") == false)
    }

    /// 좌표·주소가 통째로 null 인 항목도 서버에는 있다. 0,0 좌표를 지어내면 지도에 없는 곳이 찍힌다.
    @Test func detailWithoutAddressOrCoordinatesHidesThoseLines() throws {
        let json = #"""
        {"contentId":126508,"contentTypeId":12,"title":"이름만 있는 콘텐츠",
         "address1":null,"address2":null,"zipcode":null,"telephone":null,"telephoneName":null,
         "homepage":null,"overview":null,"thumbnail":null,"longitude":null,"latitude":null,
         "contentImages":[],"menuImages":[]}
        """#
        let place = try TourismAPIResponseParser.place(from: Data(json.utf8))

        #expect(place.address == nil)
        #expect(place.latitude == nil)
        #expect(place.longitude == nil)
        #expect(place.coordinateText == nil)
        #expect(place.homepage == nil)
        #expect(place.summary == nil)
        #expect(place.imageURLs.isEmpty)
        #expect(!place.showsMenuImages)
    }

    @Test func telephoneNameIsUsedAsTheCaptionWhenServerProvidesIt() throws {
        let json = #"""
        {"contentId":2599344,"contentTypeId":32,"title":"박산정",
         "address1":"경상북도 안동시 민속촌길 190","address2":null,
         "zipcode":"36605","telephone":"054-000-0000","telephoneName":"숙소 안내",
         "homepage":"https://example.com","overview":"한옥 리조트","thumbnail":null,
         "longitude":128.76,"latitude":36.57,"contentImages":[],"menuImages":[]}
        """#
        let place = try TourismAPIResponseParser.place(from: Data(json.utf8))

        #expect(place.postalCode == "36605")
        #expect(place.phone == "054-000-0000")
        #expect(place.phoneLabel == "숙소 안내")
        // 태그가 없는 값은 그대로 쓴다
        #expect(place.homepage == "https://example.com")
        #expect(place.type == .lodging)
    }
}

// MARK: - homepage 앵커 태그 추출 (17-1b)

@Suite
struct TourismHomepageTextTests {
    @Test func extractsHrefFromAnchorTag() {
        let raw = "<a href=\"http://www.141minihotel.com/\" target=\"_blank\" "
            + "title=\"새창 : 141미니호텔 홈페이지로 이동\">http://www.141minihotel.com</a>"
        #expect(TourismHomepageText.displayText(from: raw) == "http://www.141minihotel.com/")
    }

    @Test func fallsBackToAnchorTextWhenHrefIsMissing() {
        let raw = "<a target=\"_blank\">http://www.cheongsong.go.kr</a>"
        #expect(TourismHomepageText.displayText(from: raw) == "http://www.cheongsong.go.kr")
    }

    @Test func readsSingleQuotedAndUnquotedHref() {
        #expect(TourismHomepageText.displayText(from: "<a href='https://a.example'>a</a>") == "https://a.example")
        #expect(TourismHomepageText.displayText(from: "<a href=https://b.example >b</a>") == "https://b.example")
    }

    @Test func decodesHtmlEntitiesInsideTheUrl() {
        let raw = "<a href=\"https://example.com/?a=1&amp;b=2\">example</a>"
        #expect(TourismHomepageText.displayText(from: raw) == "https://example.com/?a=1&b=2")
    }

    @Test func plainUrlPassesThroughUnchanged() {
        #expect(TourismHomepageText.displayText(from: "http://knps.or.kr/juwang") == "http://knps.or.kr/juwang")
    }

    /// 파싱 실패 시 그 줄을 숨긴다 — 마크업 조각이나 빈 문자열을 그리지 않는다
    @Test func returnsNilWhenNothingUsableRemains() {
        #expect(TourismHomepageText.displayText(from: nil) == nil)
        #expect(TourismHomepageText.displayText(from: "") == nil)
        #expect(TourismHomepageText.displayText(from: "   ") == nil)
        #expect(TourismHomepageText.displayText(from: "<a></a>") == nil)
        #expect(TourismHomepageText.displayText(from: "<br>") == nil)
    }
}

// MARK: - 목록 · 검색 응답 파싱 (17-1a)

@Suite
struct TourismContentSearchParsingTests {
    @Test func searchPageKeepsServerTotalElements() throws {
        // `GET /api/v1/tourism-contents?keyword=주왕산` — 실측 21건
        let json = #"""
        {"items":[
          {"contentId":126508,"contentTypeId":12,"title":"주왕산국립공원",
           "address1":"경상북도 청송군 부동면 공원길 226","address2":null,
           "thumbnail":"https://tong.visitkorea.or.kr/cms/resource/juwang.jpg",
           "longitude":129.1728,"latitude":36.3931},
          {"contentId":2871004,"contentTypeId":12,"title":"주왕산 주산지",
           "address1":"경상북도 청송군 부동면 주산지길 259","address2":null,
           "thumbnail":null,"longitude":129.1436,"latitude":36.3494}],
         "page":0,"size":100,"totalElements":21,"totalPages":1}
        """#
        let page = try TourismAPIResponseParser.page(from: Data(json.utf8))

        // 개수 표기는 클라가 센 값(2)이 아니라 서버가 준 totalElements 를 쓴다
        #expect(page.totalElements == 21)
        #expect(page.places.count == 2)
        #expect(page.places[0].title == "주왕산국립공원")
    }

    /// 과거 iOS 파서는 `address` 키만 찾다가 `address1` 을 놓쳐 목록을 통째로 버리고 목데이터로 폴백했다.
    /// 주소가 아예 null 인 항목까지 버리면 같은 증상이 다시 난다.
    @Test func itemsWithoutAddressStayInTheList() throws {
        let json = #"""
        {"items":[
          {"contentId":3001,"contentTypeId":39,"title":"주소 없는 음식점",
           "address1":null,"address2":null,"thumbnail":null,"longitude":null,"latitude":null},
          {"contentId":3002,"contentTypeId":32,"title":"주소 있는 숙소",
           "address1":"경상북도 안동시 민속촌길 190","address2":"별채",
           "thumbnail":null,"longitude":128.76,"latitude":36.57}],
         "page":0,"size":100,"totalElements":2,"totalPages":1}
        """#
        let page = try TourismAPIResponseParser.page(from: Data(json.utf8))

        #expect(page.places.count == 2)
        #expect(page.places[0].address == nil)
        #expect(page.places[0].type == .restaurant)
        #expect(page.places[1].address == "경상북도 안동시 민속촌길 190 별채")
    }

    /// 검색 결과 0건은 정상 응답이다 — 예외로 만들면 화면이 목데이터로 되돌아간다
    @Test func emptySearchResultIsNotAnError() throws {
        let json = #"{"items":[],"page":0,"size":100,"totalElements":0,"totalPages":0}"#
        let page = try TourismAPIResponseParser.page(from: Data(json.utf8))

        #expect(page.places.isEmpty)
        #expect(page.totalElements == 0)
    }

    @Test func nonPageShapedPayloadIsRejected() {
        #expect(throws: TourismAPIError.invalidPayload) {
            _ = try TourismAPIResponseParser.page(from: Data(#"{"code":40100}"#.utf8))
        }
    }
}

// MARK: - 검색어를 서버로 넘기는지 (17-1a)

@Suite
struct TourismAPIClientQueryTests {
    private func makeClient(
        respond: @escaping @Sendable (URLRequest) -> (Int, Data)
    ) -> TourismAPIClient {
        let baseURL = TourismURLProtocolStub.registerUniqueHost(handler: respond)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TourismURLProtocolStub.self]
        return TourismAPIClient(
            configuration: AuthAPIConfiguration(baseURL: baseURL),
            session: URLSession(configuration: configuration),
            sessionStore: StubTourismSessionStore()
        )
    }

    private static let onePlacePage = Data(#"""
    {"items":[{"contentId":126508,"contentTypeId":12,"title":"주왕산국립공원",
      "address1":"경상북도 청송군 부동면 공원길 226","address2":null,
      "thumbnail":null,"longitude":129.1728,"latitude":36.3931}],
     "page":0,"size":100,"totalElements":21,"totalPages":1}
    """#.utf8)

    @Test func keywordAndContentTypeAreSentTogether() async throws {
        let recorded = RecordedURL()
        let client = makeClient { request in
            recorded.value = request.url
            return (200, Self.onePlacePage)
        }

        let page = try await client.places(keyword: "주왕산", contentTypeID: 12)

        let items = URLComponents(url: try #require(recorded.value), resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.first { $0.name == "keyword" }?.value == "주왕산")
        #expect(items.first { $0.name == "contentTypeId" }?.value == "12")
        #expect(items.first { $0.name == "size" }?.value == "100")
        #expect(page.totalElements == 21)
    }

    @Test func blankKeywordIsNotSentAtAll() async throws {
        let recorded = RecordedURL()
        let client = makeClient { request in
            recorded.value = request.url
            return (200, Self.onePlacePage)
        }

        _ = try await client.places(keyword: "   ", contentTypeID: nil)

        let items = URLComponents(url: try #require(recorded.value), resolvingAgainstBaseURL: false)?.queryItems ?? []
        // 검색어가 비면 파라미터를 보내지 않는다 (전체 조회)
        #expect(!items.contains { $0.name == "keyword" })
        #expect(!items.contains { $0.name == "contentTypeId" })
    }

    @Test func keywordIsTrimmedBeforeItIsSent() async throws {
        let recorded = RecordedURL()
        let client = makeClient { request in
            recorded.value = request.url
            return (200, Self.onePlacePage)
        }

        _ = try await client.places(keyword: "  안동 ", contentTypeID: nil)

        let items = URLComponents(url: try #require(recorded.value), resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.first { $0.name == "keyword" }?.value == "안동")
    }

    @Test func zeroResultSearchReturnsAnEmptyPageInsteadOfThrowing() async throws {
        let client = makeClient { _ in
            (200, Data(#"{"items":[],"page":0,"size":100,"totalElements":0,"totalPages":0}"#.utf8))
        }

        let page = try await client.places(keyword: "없는검색어", contentTypeID: nil)

        #expect(page.places.isEmpty)
        #expect(page.totalElements == 0)
    }
}

// MARK: - 검색 모델 (17-1a)

@Suite
@MainActor
struct TourismPlaceSearchModelTests {
    @Test func searchDelegatesTheKeywordToTheServiceWithoutFilteringAgain() async {
        let service = RecordingTourismService(
            page: TourismPlacePage(places: [Self.serverPlace(title: "안동 하회마을")], totalElements: 259)
        )
        let model = TourismPlaceSearchModel(service: service)

        await model.apply(keyword: "안동")

        let keywords = service.recordedKeywords
        let placeCount = model.places.count
        let total = model.totalElements
        let isServerBacked = model.isServerBacked
        let fallback = model.fallbackMessage

        #expect(keywords == ["안동"])
        // 서버가 매칭한 결과를 화면이 다시 거르지 않는다
        #expect(placeCount == 1)
        #expect(total == 259)
        #expect(isServerBacked)
        #expect(fallback == nil)
    }

    @Test func contentTypeChipReusesTheCurrentKeyword() async {
        let service = RecordingTourismService(
            page: TourismPlacePage(places: [Self.serverPlace(title: "안동 하회마을")], totalElements: 259)
        )
        let model = TourismPlaceSearchModel(service: service)

        await model.apply(keyword: "안동")
        await model.selectContentType(39)

        let keywords = service.recordedKeywords
        let contentTypeIDs = service.recordedContentTypeIDs

        #expect(keywords == ["안동", "안동"])
        #expect(contentTypeIDs == [nil, 39])
    }

    @Test func zeroResultsKeepTheEmptyListInsteadOfFallingBackToMockPlaces() async {
        let service = RecordingTourismService(page: TourismPlacePage(places: [], totalElements: 0))
        let model = TourismPlaceSearchModel(service: service)

        await model.apply(keyword: "없는검색어")

        let isEmpty = model.places.isEmpty
        let total = model.totalElements
        let fallback = model.fallbackMessage

        #expect(isEmpty)
        #expect(total == 0)
        // 0건은 오류가 아니다 — 폴백 문구를 띄우지 않는다
        #expect(fallback == nil)
    }

    @Test func networkFailureKeepsTheStoredSamplePlaces() async {
        let service = RecordingTourismService(page: nil)
        let model = TourismPlaceSearchModel(service: service)

        await model.apply(keyword: "안동")

        let placeCount = model.places.count
        let catalogCount = TourismPlaceCatalog.places.count
        let fallback = model.fallbackMessage
        let isServerBacked = model.isServerBacked
        let total = model.totalElements

        #expect(placeCount == catalogCount)
        #expect(fallback != nil)
        #expect(!isServerBacked)
        #expect(total == nil)
    }

    /// 캡처 경로(`UITEST_MODE`)가 쓰는 목데이터 서비스는 기획 목록을 그대로 돌려준다
    @Test func sampleServiceStillMatchesThePlanningMockList() async throws {
        let service = SampleTourismContentService()

        let seeded = try await service.places(keyword: "청송", contentTypeID: nil)
        let all = try await service.places(keyword: "", contentTypeID: nil)
        let catalogCount = TourismPlaceCatalog.places.count

        #expect(seeded.places.count == 5)
        #expect(all.places.count == catalogCount)
        #expect(!service.providesServerContent)
    }

    private static func serverPlace(title: String) -> TourismPlace {
        TourismPlace(
            id: "1", type: .attraction, title: title, address: "경상북도 안동시",
            latitude: 36.5, longitude: 128.7, postalCode: nil, phone: nil, phoneLabel: nil,
            homepage: nil, summary: nil, imageLabels: [], menuImageLabels: [],
            serverContentTypeID: 12
        )
    }
}

// MARK: - 오류 코드 분기 (W3 · 409 40915)

@Suite
struct MoyeoServerErrorCodeTests {
    private func makeClient(
        respond: @escaping @Sendable (URLRequest) -> (Int, Data)
    ) -> MoyeoAPIClient {
        let baseURL = TourismURLProtocolStub.registerUniqueHost(handler: respond)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TourismURLProtocolStub.self]
        return MoyeoAPIClient(
            configuration: AuthAPIConfiguration(baseURL: baseURL),
            session: URLSession(configuration: configuration),
            sessionStore: StubTourismSessionStore()
        )
    }

    /// 아직 끝나지 않은 여행(방 22)에 완료 여행 전용 API 를 부르면 409 40915 다.
    /// 권한 오류(403 40301)와 같은 화면으로 묶으면 안 된다.
    @Test func tripNotCompletedIsDistinguishableFromPermissionErrors() async {
        let client = makeClient { _ in
            (409, Data(#"{"code":40915,"errorMessage":"아직 완료되지 않은 여행입니다."}"#.utf8))
        }

        do {
            let _: [String] = try await client.get("/api/v1/chat-rooms/22/companions")
            Issue.record("409 가 던져지지 않았다")
        } catch let error as MoyeoAPIError {
            #expect(error.serverCode == MoyeoServerErrorCode.tripNotCompleted)
            #expect(error.serverCode != MoyeoServerErrorCode.notParticipating)
            #expect(error == .server(statusCode: 409, code: 40915, message: "아직 완료되지 않은 여행입니다."))
        } catch {
            Issue.record("예상하지 못한 오류: \(error)")
        }
    }

    @Test func notParticipatingKeepsItsOwnCode() async {
        let client = makeClient { _ in
            (403, Data(#"{"code":40301,"errorMessage":"채팅방에 참여 중이 아닙니다."}"#.utf8))
        }

        await #expect(throws: MoyeoAPIError.server(
            statusCode: 403, code: MoyeoServerErrorCode.notParticipating, message: "채팅방에 참여 중이 아닙니다."
        )) {
            let _: [String] = try await client.get("/api/v1/chat-rooms/22/companions")
        }
    }

    @Test func missingChatRoomKeepsItsOwnCode() async {
        let client = makeClient { _ in
            (404, Data(#"{"code":40405,"errorMessage":"채팅방을 찾을 수 없습니다."}"#.utf8))
        }

        await #expect(throws: MoyeoAPIError.server(
            statusCode: 404, code: MoyeoServerErrorCode.chatRoomNotFound, message: "채팅방을 찾을 수 없습니다."
        )) {
            let _: [String] = try await client.get("/api/v1/chat-rooms/999/companions")
        }
    }

    /// 오류 본문이 없으면 코드는 nil 이다 — 없는 코드를 지어내지 않는다
    @Test func emptyErrorBodyLeavesTheCodeNil() async {
        let client = makeClient { _ in (500, Data()) }

        do {
            let _: [String] = try await client.get("/api/v1/chat-rooms/22/companions")
            Issue.record("500 이 던져지지 않았다")
        } catch let error as MoyeoAPIError {
            #expect(error.serverCode == nil)
        } catch {
            Issue.record("예상하지 못한 오류: \(error)")
        }
    }
}

// MARK: - 테스트 보조

private final class RecordedURL: @unchecked Sendable {
    var value: URL?
}

private final class RecordingTourismService: TourismContentProviding, @unchecked Sendable {
    private let page: TourismPlacePage?
    private(set) var recordedKeywords: [String] = []
    private(set) var recordedContentTypeIDs: [Int?] = []

    init(page: TourismPlacePage?) {
        self.page = page
    }

    var providesServerContent: Bool { true }

    func places(keyword: String, contentTypeID: Int?) async throws -> TourismPlacePage {
        recordedKeywords.append(keyword)
        recordedContentTypeIDs.append(contentTypeID)
        guard let page else { throw TourismAPIError.invalidPayload }
        return page
    }

    func place(id: String) async throws -> TourismPlace {
        throw TourismAPIError.invalidPayload
    }
}

private struct StubTourismSessionStore: AuthSessionStoring {
    func load() throws -> AuthTokens? {
        AuthTokens(accessToken: "access", refreshToken: "refresh")
    }

    func save(_ tokens: AuthTokens) throws {}

    func clear() throws {}
}

/// 테스트는 병렬로 돈다 — 응답 핸들러를 하나의 static 에 담으면 서로 덮어쓴다.
/// 테스트마다 고유한 호스트를 쓰고, 핸들러는 그 호스트로 찾아 쓴다.
private final class TourismURLProtocolStub: URLProtocol {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handlers: [String: @Sendable (URLRequest) -> (Int, Data)] = [:]

    /// 이 테스트만 쓰는 호스트를 만들어 핸들러를 걸고, 그 베이스 URL 을 돌려준다
    static func registerUniqueHost(handler: @escaping @Sendable (URLRequest) -> (Int, Data)) -> URL {
        let host = "\(UUID().uuidString.lowercased()).moyeo.test"
        lock.lock()
        handlers[host] = handler
        lock.unlock()
        return URL(string: "https://\(host)")!
    }

    private static func handler(for host: String) -> (@Sendable (URLRequest) -> (Int, Data))? {
        lock.lock()
        defer { lock.unlock() }
        return handlers[host]
    }

    override static func canInit(with request: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host(), let handler = Self.handler(for: host) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (statusCode, data) = handler(request)
        guard let response = HTTPURLResponse(
            url: url, statusCode: statusCode, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
