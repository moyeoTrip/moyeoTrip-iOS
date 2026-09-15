import SwiftUI

// Place and legal-detail screens intentionally live together as the changeLog06/07 surface.
// swiftlint:disable file_length

enum TourismContentType: String, CaseIterable, Identifiable {
    case attraction = "관광지"
    case restaurant = "식당"
    case lodging = "숙박"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .attraction: "mappin.and.ellipse"
        case .restaurant: "fork.knife"
        case .lodging: "bed.double.fill"
        }
    }

    /// 원격 썸네일이 없을 때 그릴 풍경 톤. 웹 프로토타입의 `Photo hue` 와 같은 축이다.
    var thumbnailMood: CourseMood {
        switch self {
        case .attraction: .forest
        case .restaurant: .sunrise
        case .lodging: .blossom
        }
    }
}

/// 서버가 주지 않는 값은 지어내지 않는다 — nullable 필드는 nil 로 두고 화면에서 그 줄을 숨긴다 (17-1b).
struct TourismPlace: Identifiable, Hashable {
    let id: String
    let type: TourismContentType
    let title: String
    let address: String?
    let latitude: Double?
    let longitude: Double?
    var thumbnailURL: URL?
    let postalCode: String?
    let phone: String?
    let phoneLabel: String?
    /// 앵커 태그를 벗겨 낸 홈페이지 주소. 추출에 실패하면 nil 이고 화면은 그 줄을 숨긴다.
    let homepage: String?
    let summary: String?
    let imageLabels: [String]
    let menuImageLabels: [String]
    var imageURLs: [URL] = []
    var menuImageURLs: [URL] = []
    /// 서버 관광 콘텐츠 유형 ID — 서버 장소일 때만 채워진다 (17-1a 타입 필터)
    var serverContentTypeID: Int?

    /// 메뉴판 탭은 **서버가 준 메뉴 사진이 있을 때만** 만든다.
    /// 라벨만 보고 탭을 만들면 실데이터에 0장인데도 빈 탭이 생긴다.
    var showsMenuImages: Bool {
        type == .restaurant && !menuImageURLs.isEmpty
    }

    /// 서버 콘텐츠 ID 만 아는 상태의 빈 장소.
    ///
    /// 상세 화면이 `loadDetail()` 로 실제 값을 채운다. 번들 목록에 없는 ID 로 들어왔을 때
    /// 엉뚱한 목데이터 장소로 떨어지면, 그 장소의 목 ID 로 서버를 불러 상세가 항상 실패한다.
    static func pending(id: String) -> TourismPlace {
        TourismPlace(
            id: id,
            type: .attraction,
            title: "",
            address: nil,
            latitude: nil,
            longitude: nil,
            thumbnailURL: nil,
            postalCode: nil,
            phone: nil,
            phoneLabel: nil,
            homepage: nil,
            summary: nil,
            imageLabels: [],
            menuImageLabels: []
        )
    }

    /// 좌표는 서버가 주지 않는 항목이 있다 — 둘 다 있을 때만 표기한다
    var coordinateText: String? {
        guard let latitude, let longitude else { return nil }
        return String(format: "%.6f, %.6f", latitude, longitude)
    }
}

enum TourismPlaceCatalog {
    static let places = [
        TourismPlace(
            id: "CT2864117", type: .attraction, title: "주왕산국립공원",
            address: "경상북도 청송군 부동면 공원길 226", latitude: 36.3931, longitude: 129.1728,
            postalCode: "37437", phone: "054-870-5300", phoneLabel: "주왕산국립공원사무소",
            homepage: "knps.or.kr/juwang", summary: "기암절벽과 폭포, 완만한 숲길이 이어지는 청송 대표 자연 관광지예요.",
            imageLabels: ["기암", "용연폭포", "주산지 숲길"], menuImageLabels: []
        ),
        TourismPlace(
            id: "CT2871004", type: .attraction, title: "주산지",
            address: "경상북도 청송군 부동면 주산지길 259", latitude: 36.3494, longitude: 129.1436,
            postalCode: "37437", phone: "054-870-6240", phoneLabel: "청송군 관광안내",
            homepage: "cs.go.kr/tour", summary: "왕버들이 물 위에 비치는 새벽 풍경으로 잘 알려진 조용한 산책 명소예요.",
            imageLabels: ["왕버들", "물안개", "산책로"], menuImageLabels: []
        ),
        TourismPlace(
            id: "CT2299341", type: .restaurant, title: "달기약수터 백숙거리",
            address: "경상북도 청송군 청송읍 약수길 5", latitude: 36.4278, longitude: 129.0489,
            postalCode: "37411", phone: "054-873-7777", phoneLabel: "달기약수터 관리사무소",
            homepage: "cheongsong.go.kr/tour",
            summary: "탄산이 섞인 달기약수로 끓여내는 백숙이 유명한 거리예요. 산행 뒤 늦은 점심 자리로 많이 찾아요.",
            // 화면기획·웹의 기준은 갤러리 8장(1/8 · 사진 8) + 메뉴판 4장이다.
            imageLabels: ["약수터", "백숙거리", "산책길", "약수 원탕", "가마솥", "상차림", "느티나무 쉼터", "저녁 거리"],
            menuImageLabels: ["닭백숙 정식", "오리 백숙", "한방 삼계탕", "더덕구이"]
        ),
        TourismPlace(
            id: "CT2740882", type: .lodging, title: "청송 솔기온천 한옥스테이",
            address: "경상북도 청송군 청송읍 금월로 273", latitude: 36.4361, longitude: 129.0573,
            postalCode: "37433", phone: "054-872-7000", phoneLabel: "숙소 안내",
            homepage: "solgi-stay.example", summary: "청송 여행을 마친 뒤 쉬어가기 좋은 한옥형 숙박 시설이에요.",
            imageLabels: ["한옥 전경", "객실", "마당"], menuImageLabels: []
        ),
        // 화면기획·웹·안드로이드의 "청송" 검색 결과는 5곳이다. 4곳만 두면 iOS 목록만 짧아진다.
        TourismPlace(
            id: "CT2612178", type: .attraction, title: "청송 객주문학관",
            address: "경상북도 청송군 진보면 청송로 6359", latitude: 36.4739, longitude: 129.0093,
            postalCode: "37414", phone: "054-874-4001", phoneLabel: "객주문학관 안내",
            homepage: "obju.or.kr", summary: "김주영 작가의 대하소설 「객주」를 주제로 꾸민 문학 전시관이에요. 진보면 시장 구경과 함께 보기 좋아요.",
            imageLabels: ["전시관", "집필실", "장터 마당"], menuImageLabels: []
        )
    ]
}

struct PlaceSearchView: View {
    var onAdd: (TourismPlace) -> Void = { _ in }
    /// 지금 코스에 담겨 있는 방문지 수. **부르는 쪽(코스 에디터)이 세어 준 실제 값**이다.
    ///
    /// 예전에는 화면이 `@State addedCount = 3` 으로 시작해, 아무것도 담지 않았는데도 「3곳 담김」이라고
    /// 했다. 검색어도 `"청송"` 이 박혀 있어 지난 세션의 검색어가 남은 것처럼 보였다 (IOS-F120).
    /// 카운터가 거짓말을 하면 「내가 고르지 않은 3곳이 딸려 들어간다」고 믿게 된다.
    var addedCount = 0

    /// 더 담을 수 없는 상태인지. `addedCount` 는 지금 코스에 담긴 방문지 수다.
    private var isStopLimitReached: Bool { addedCount >= RoutePolicy.maximumStopCount }
    @StateObject private var model: TourismPlaceSearchModel
    @State private var query = ""
    @State private var selectedType: TourismContentType?
    @State private var showsMap = false
    @Environment(\.dismiss) private var dismiss

    init(
        onAdd: @escaping (TourismPlace) -> Void = { _ in },
        addedCount: Int = 0,
        service: TourismContentProviding? = nil
    ) {
        self.onAdd = onAdd
        self.addedCount = addedCount
        let resolvedService = service ?? (UITestRuntime.usesMockTourism
            ? SampleTourismContentService()
            : TourismAPIClient())
        _model = StateObject(wrappedValue: TourismPlaceSearchModel(service: resolvedService))
    }

    /// 서버 타입 목록이 오면 타입 필터는 서버가 처리한다 — 화면에서 다시 걸러내지 않는다
    private var usesServerTypes: Bool {
        !model.contentTypes.isEmpty
    }

    /// 검색어 매칭은 서버가 한다 (17-1a) — 화면에서 다시 걸러내면 이중 필터가 된다.
    /// 서버 타입 목록이 없을 때(목데이터)만 기존 3종 타입 칩으로 거른다.
    private var filteredPlaces: [TourismPlace] {
        guard !usesServerTypes else { return model.places }
        return model.places.filter { selectedType == nil || $0.type == selectedType }
    }

    /// 검색 결과 개수는 서버의 `totalElements` 를 쓴다. 목데이터 목록은 기존 "근처순" 표기를 유지한다.
    /// 서버 타입 목록을 못 받아 화면이 직접 타입을 거른 경우에는 서버 전체 개수가 목록과 어긋나므로 쓰지 않는다.
    private var countText: String {
        // 예전에는 서버 목록이 아닐 때(=조회 실패 포함) `주왕산 코스 근처순` 을 붙였다 —
        // 서버가 정한 적 없는 정렬 기준이고 코스 이름까지 지어낸 것이다 (NO-MOCK-CANON R1).
        guard model.isServerBacked else { return "\(filteredPlaces.count)곳" }
        let filtersTypeLocally = !usesServerTypes && selectedType != nil
        guard !filtersTypeLocally, let total = model.totalElements else { return "\(filteredPlaces.count)곳" }
        return "\(total)곳"
    }

    /// 17-1a `지도에서 보기` — 목록이 이미 들고 있는 방문지 좌표를 그대로 순번 마커로 올린다.
    /// 새 API 는 필요 없고, 좌표가 없거나 (0,0)인 방문지는 지도에 올릴 근거가 없어 뺀다.
    /// 안드로이드 `PlaceAndTermsScreens.kt` 의 `place-search-map-toggle` 과 같은 규칙이다.
    private var mapMarkers: [MoyeoMapMarker] {
        let located: [(id: String, coordinate: MoyeoMapCoordinate)] = filteredPlaces
            .compactMap { place in
                guard
                    let coordinate = MoyeoMapCoordinate(latitude: place.latitude, longitude: place.longitude),
                    coordinate.latitude != 0, coordinate.longitude != 0
                else {
                    return nil
                }
                return (id: "place-\(place.id)", coordinate: coordinate)
            }
        return located.enumerated().map { index, item in
            MoyeoMapMarker(id: item.id, coordinate: item.coordinate, order: index + 1)
        }
    }

    /// 좌표가 하나도 없으면 **지도를 그리지 않는다** — 손으로 그린 가짜 지도를 두지 않는다 (NO-MOCK R4).
    @ViewBuilder
    private var mapPreview: some View {
        let markers = mapMarkers
        if let first = markers.first {
            MoyeoMapView(
                content: MoyeoMapContent(center: first.coordinate, level: 11, markers: markers),
                isInteractive: false,
                fallback: { MoyeoMapUnavailableView(message: "지도를 불러오지 못했어요.") }
            )
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("방문지 지도, \(markers.count)곳")
            .accessibilityIdentifier("placeSearch.mapPreview")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(MoyeoTheme.forest)
                    TextField("지역이나 장소 이름을 검색하세요", text: $query)
                        .textInputAutocapitalization(.never)
                    if !query.isEmpty {
                        // ENV-009 — 아이콘은 그대로 두고 누를 넓이만 44x44 로 (재던 값 16x16pt)
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(MoyeoTheme.text400)
                        .accessibilityLabel("검색어 지우기")
                        .accessibilityIdentifier("placeSearch.query.clear")
                    }
                }
                .padding(.horizontal, 13)
                .frame(height: 46)
                .background(MoyeoTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(MoyeoTheme.primary300))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier("placeSearch.query")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        if usesServerTypes {
                            // 17-1a — 서버가 주는 관광 콘텐츠 유형으로 필터를 그린다
                            serverFilterButton("전체", contentTypeID: nil)
                            ForEach(model.contentTypes) { type in
                                serverFilterButton(type.contentTypeName, contentTypeID: type.contentTypeId)
                            }
                        } else {
                            filterButton("전체", type: nil)
                            ForEach(TourismContentType.allCases) { type in
                                filterButton(type.rawValue, type: type)
                            }
                        }
                    }
                }

                if showsMap {
                    mapPreview
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if model.isLoading {
                        ProgressView("방문지를 불러오고 있어요")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    } else if let fallbackMessage = model.fallbackMessage {
                        Label(fallbackMessage, systemImage: "wifi.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(MoyeoTheme.warningText)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .accessibilityIdentifier("placeSearch.fallback")
                    }

                    // 서버는 정렬 기준을 주지 않는다 — 서버 목록에서는 "근처순" 표기를 뺀다
                    Text(countText)
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.muted)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)

                    // 코스는 방문지 20곳까지다(`RoutePolicy.maximumStopCount`). 예전에는 이 상한이
                    // 편집기 쪽에만 있고 **검색 목록에는 없어** 21곳째도 담겼다 (안드로이드 교차 발견).
                    if isStopLimitReached {
                        Text("방문지는 \(RoutePolicy.maximumStopCount)곳까지 담을 수 있어요. 더 담으려면 코스에서 몇 곳을 빼주세요.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MoyeoTheme.dangerRed)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                            .accessibilityIdentifier("placeSearch.limitReached")
                    }

                    // 서버 목록이 비면 **빈 상태**를 그린다. 예전에는 번들 카탈로그가
                    // 초기값이라 이 자리가 빌 일이 없었고, 그래서 「결과 0건」과
                    // 「아직 못 받음」을 화면에서 구분할 수 없었다 (NO-MOCK-CANON R1).
                    if filteredPlaces.isEmpty, !model.isLoading, model.fallbackMessage == nil {
                        MoyeoEmptyStateView(
                            message: "조건에 맞는 방문지가 없어요. 검색어를 바꿔보세요.",
                            systemImage: "mappin.slash",
                            accessibilityIdentifier: "placeSearch.empty"
                        )
                        .padding(.vertical, 30)
                    }
                    ForEach(filteredPlaces) { place in
                        NavigationLink(value: place) {
                            PlaceSearchRow(
                                place: place,
                                isAddEnabled: !isStopLimitReached,
                                onAdd: { onAdd(place) }
                            )
                        }
                        .buttonStyle(.plain)
                        // 마지막 줄이 보이면 다음 쪽을 잇는다. 예전에는 **100번째에서 목록이 끝났는데**
                        // 머리에는 「3,115곳」이라고 적혀 있었다 (IOS-F91).
                        .onAppear {
                            guard place.id == filteredPlaces.last?.id else { return }
                            Task { await model.loadNextPageIfNeeded() }
                        }
                    }

                    if model.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .accessibilityIdentifier("placeSearch.loadingMore")
                    }

                    Text("목록에는 제목·주소·썸네일·좌표만 표시해요. 전화번호와 상세 소개는 장소를 눌러 확인할 수 있어요.")
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.text400)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(20)
                }
            }
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .navigationTitle("방문지 검색")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 화면기획의 우측 상단 "지도에서 보기"
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsMap.toggle()
                } label: {
                    // ENV-009 — 아이콘 크기는 그대로, 누를 넓이만 44x44 (재던 값 30x36pt)
                    Image(systemName: "map")
                        .foregroundStyle(MoyeoTheme.ink)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("지도에서 보기")
                .accessibilityIdentifier("placeSearch.mapToggle")
            }
        }
        .safeAreaInset(edge: .bottom) {
            // 담긴 방문지 수와 코스 반영은 화면 바닥에 고정한다
            HStack(spacing: 10) {
                Text("\(addedCount)곳 담김")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                Spacer(minLength: 0)
                Button {
                    dismiss()
                } label: {
                    Text("코스에 반영")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .background(MoyeoTheme.forest)
                        .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("placeSearch.done")
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(MoyeoTheme.card)
            .overlay(alignment: .top) { Rectangle().fill(MoyeoTheme.softLine).frame(height: 1) }
        }
        .navigationDestination(for: TourismPlace.self) { place in
            PlaceDetailView(
                place: place,
                isAddEnabled: !isStopLimitReached,
                onAdd: onAdd,
                service: model.service
            )
        }
        // 검색어가 바뀌면 이전 요청은 취소되고, 모델이 잠깐 기다렸다가 서버로 다시 검색한다
        .task(id: query) {
            await model.apply(keyword: query)
        }
        // 결과를 고르려고 스크롤하면 키보드가 닫히고, 「완료」로도 닫을 수 있다 (IOS-F136).
        .scrollDismissesKeyboard(.interactively)
        .moyeoKeyboardDismissable()
        .accessibilityIdentifier("screen.placeSearch")
    }

    private func filterButton(_ title: String, type: TourismContentType?) -> some View {
        filterChip(title, isSelected: selectedType == type, identifier: title) {
            selectedType = type
        }
    }

    private func serverFilterButton(_ title: String, contentTypeID: Int?) -> some View {
        filterChip(
            title,
            isSelected: model.selectedContentTypeID == contentTypeID,
            identifier: title
        ) {
            Task { await model.selectContentType(contentTypeID) }
        }
    }

    private func filterChip(
        _ title: String,
        isSelected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .font(.caption.weight(.heavy))
            .foregroundStyle(isSelected ? MoyeoTheme.onLeaf : MoyeoTheme.ink)
            .padding(.horizontal, 13)
            .frame(height: 32)
            .background(isSelected ? MoyeoTheme.leaf : MoyeoTheme.card)
            .overlay(Capsule().stroke(isSelected ? MoyeoTheme.forest : MoyeoTheme.line))
            .clipShape(Capsule())
            .accessibilityIdentifier("placeSearch.filter.\(identifier)")
    }
}

private struct PlaceSearchRow: View {
    let place: TourismPlace
    /// 상한에 닿으면 담기 버튼을 잠근다 — 눌리는데 아무 일도 없는 것보다 낫다.
    var isAddEnabled = true
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            CachedRemoteImage(url: place.thumbnailURL, fallbackShape: .square) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                // 사진 자리에 카테고리 아이콘을 띄우면 사진 자리가 아이콘 자리로 읽힌다
                MoyeoPhotoTile(mascot: "", mood: place.type.thumbnailMood, height: 68, cornerRadius: 10)
            }
            .frame(width: 76, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(place.title).font(.subheadline.weight(.heavy)).lineLimit(1)
                    PlaceTypePill(type: place.type)
                }
                // 서버는 주소·좌표를 주지 않는 항목이 있다 — 없으면 줄을 지운다
                if let address = place.address {
                    Text(address).font(.caption).foregroundStyle(MoyeoTheme.muted).lineLimit(2)
                }
                // 주소 줄이 바로 위에 있다 — 좌표까지 보여줄 이유가 없다(기획에도 없다).
                // 좌표는 지도를 그리는 입력값이지 읽는 화면에 둘 값이 아니다.
            }
            Spacer(minLength: 4)
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.caption.weight(.bold))
                    .frame(width: 44, height: 44)
                    .background(MoyeoTheme.leaf)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(MoyeoTheme.primary300))
            }
            .buttonStyle(.plain)
            .disabled(!isAddEnabled)
            .opacity(isAddEnabled ? 1 : 0.4)
            .foregroundStyle(MoyeoTheme.forest)
            .accessibilityLabel("\(place.title) 코스에 담기")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(MoyeoTheme.softLine).frame(height: 1) }
    }
}

struct PlaceDetailView: View {
    @State private var place: TourismPlace
    /// 대표 사진 페이저에서 지금 보고 있는 장.
    @State private var heroPhotoIndex = 0

    /// 히어로에 걸 사진들. 서버가 사진을 안 주면 썸네일 한 장, 그것도 없으면 빈 배열이다
    /// (자리표시자는 `CachedRemoteImage` 의 placeholder 가 그린다).
    private var heroPhotoURLs: [URL] {
        if !place.imageURLs.isEmpty { return place.imageURLs }
        if let thumbnail = place.thumbnailURL { return [thumbnail] }
        return []
    }
    /// 코스 방문지 상한(20곳)에 닿으면 담기를 잠근다 (안드로이드 교차 발견).
    var isAddEnabled = true
    var onAdd: (TourismPlace) -> Void = { _ in }
    private let service: TourismContentProviding
    @Environment(\.dismiss) private var dismiss
    @State private var showsMenu = false
    @State private var isLoading = false
    @State private var fallbackMessage: String?

    init(
        place: TourismPlace,
        isAddEnabled: Bool = true,
        onAdd: @escaping (TourismPlace) -> Void = { _ in },
        service: TourismContentProviding? = nil
    ) {
        _place = State(initialValue: place)
        self.isAddEnabled = isAddEnabled
        self.onAdd = onAdd
        self.service = service ?? (UITestRuntime.usesMockTourism
            ? SampleTourismContentService()
            : TourismAPIClient())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 사진이 없을 때도 화면기획·웹·안드로이드처럼 풍경 자리표시자를 쓴다.
                // 아이콘만 크게 놓으면 같은 화면인데 iOS만 사진이 없는 것처럼 보인다.
                // 대표 사진은 **화면 좌우를 꽉 채운다** (기획·웹·안드로이드와 같다).
                // 예전에는 20pt 여백 안에 둥근 사각형으로 들어가 iOS 만 사진이 작아 보였다
                // (17-1b, 사용자 지적 2026-09-09). 아래 `.padding(20)` 을 되돌려 폭을 넓힌다.
                ZStack(alignment: .bottomTrailing) {
                    // 대표 사진은 **좌우로 넘길 수 있다.** 예전에는 `imageURLs.first` 한 장만
                    // 고정으로 그리고 배지도 `1/N` 로 박아 둬서, 서버가 여러 장을 줘도
                    // 첫 장 말고는 볼 수 없었고 배지가 늘 1페이지를 가리켰다 (TC PLACE-009).
                    TabView(selection: $heroPhotoIndex) {
                        ForEach(Array(heroPhotoURLs.enumerated()), id: \.offset) { index, url in
                            CachedRemoteImage(url: url, fallbackShape: .landscape) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                MoyeoPhotoTile(mascot: "", mood: .forest, height: 210, cornerRadius: MoyeoTheme.cardRadius)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 210)
                            .clipped()
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(maxWidth: .infinity)
                    .frame(height: 210)
                    .accessibilityIdentifier("placeDetail.heroPager")

                    // 사진 장수 배지는 **이미지 우측 하단**이다 (정본 `HERO-SCROLL-CANON.md` R1-1).
                    Text("\(heroPhotoURLs.isEmpty ? 1 : heroPhotoIndex + 1)/\(max(heroPhotoURLs.count, 1))")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(.black.opacity(0.46))
                        .clipShape(Capsule())
                        .padding(10)
                        .accessibilityIdentifier("placeDetail.photoCounter")
                }
                .padding(.horizontal, -20)
                .padding(.top, -20)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(place.title).font(.title3.weight(.heavy))
                    Spacer()
                    PlaceTypePill(type: place.type)
                }

                // 서버가 null 로 주는 줄은 숨긴다 — 값을 지어내지 않는다 (17-1b)
                VStack(spacing: 12) {
                    detailRow("mappin.and.ellipse", place.address, place.postalCode.map { "우편번호 \($0)" })
                    detailRow("phone", place.phone, place.phoneLabel, destination: placePhoneURL)
                    // 좌표가 있을 때만 이 행을 그리지만, **보여주는 것은 동작 문구**다.
                    // 좌표 숫자는 지도를 여는 입력값이지 읽는 사람에게 보일 값이 아니다.
                    detailRow("map", placeMapURL == nil ? nil : "지도에서 열기", nil, destination: placeMapURL)
                    detailRow("globe", place.homepage, "홈페이지", destination: placeHomepageURL)
                }
                .padding(14)
                .background(MoyeoTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.softLine))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if let summary = place.summary {
                    Text("소개").font(.headline)
                    // 문단(줄바꿈)을 살려 그린다 — `TourismRichText` 가 이미 문단만 남겼다.
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(MoyeoTheme.text700)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("placeDetail.summary")
                }

                if isLoading {
                    ProgressView("상세 정보를 불러오고 있어요")
                } else if let fallbackMessage {
                    Label(fallbackMessage, systemImage: "wifi.exclamationmark")
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.warningText)
                        .accessibilityIdentifier("placeDetail.fallback")
                }

                // 탭 숫자도 **서버가 준 사진 장수**다. 예전에는 번들 라벨 개수를 셌다.
                HStack(spacing: 20) {
                    tabButton("사진 \(place.imageURLs.count)", selected: !showsMenu) { showsMenu = false }
                    if place.showsMenuImages {
                        tabButton("메뉴판 \(place.menuImageURLs.count)", selected: showsMenu) { showsMenu = true }
                    }
                }

                let labels = showsMenu ? place.menuImageLabels : place.imageLabels
                let urls = showsMenu ? place.menuImageURLs : place.imageURLs
                // 서버가 준 사진만 그린다. 예전에는 라벨 수만큼 칸을 만들고
                // 색 타일(`galleryMood`)로 채워, 없는 사진이 있는 것처럼 보였다 (NO-MOCK R1).
                if urls.isEmpty {
                    MoyeoEmptyStateView(
                        message: "아직 등록된 사진이 없어요.",
                        accessibilityIdentifier: "placeDetail.photos.empty"
                    )
                } else {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                        spacing: 8
                    ) {
                        ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                            CachedRemoteImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                MoyeoTheme.leaf
                            }
                            .frame(maxWidth: .infinity, minHeight: 74)
                            .frame(height: 74)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .accessibilityLabel(
                                labels.indices.contains(index) ? labels[index] : "사진 \(index + 1)"
                            )
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 80)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 8) {
                Button("목록으로") { dismiss() }.buttonStyle(DesignSecondaryButtonStyle())
                Button {
                    onAdd(place)
                    dismiss()
                } label: {
                    Label(
                        isAddEnabled
                            ? "이 장소를 코스에 담기"
                            : "방문지 \(RoutePolicy.maximumStopCount)곳을 다 담았어요",
                        systemImage: "plus"
                    )
                }
                .buttonStyle(DesignPrimaryButtonStyle())
                .disabled(!isAddEnabled)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(MoyeoTheme.card)
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .navigationTitle("방문지 상세")
        .navigationBarTitleDisplayMode(.inline)
        // 결정 ⑬ — 우측 상단 공유를 뺐다. 공개 URL 규격이 없어 공유 본문에 링크가 없었다.
        .accessibilityIdentifier("screen.placeDetail.\(place.id)")
        .task { await loadDetail() }
    }

    /// 값이 없으면(서버가 null) 줄 자체를 그리지 않는다. 안내 문구도 값이 있을 때만 붙인다.
    ///
    /// `destination` 이 있으면 **누를 수 있는 줄**이다. 예전에는 「지도에서 열기」·홈페이지·전화가
    /// 전부 `Text` 라, 동작을 약속하는 문구를 읽고 눌러도 아무 일이 없었다 (IOS-F90).
    @ViewBuilder
    private func detailRow(
        _ icon: String,
        _ value: String?,
        _ caption: String?,
        destination: URL? = nil
    ) -> some View {
        if let value, !value.isEmpty {
            if let destination {
                Link(destination: destination) {
                    detailRowLabel(icon, value, caption, isActionable: true)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("placeDetail.action.\(icon)")
            } else {
                detailRowLabel(icon, value, caption, isActionable: false)
            }
        }
    }

    private func detailRowLabel(
        _ icon: String,
        _ value: String,
        _ caption: String?,
        isActionable: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(MoyeoTheme.muted).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(isActionable ? MoyeoTheme.forest : MoyeoTheme.ink)
                if let caption, !caption.isEmpty {
                    Text(caption).font(.caption2).foregroundStyle(MoyeoTheme.muted)
                }
            }
            Spacer()
            if isActionable {
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(MoyeoTheme.muted)
            }
        }
        // 누를 수 있는 줄은 44pt 를 채운다 — 글자 높이(약 16pt)로는 겨누기 어렵다.
        .frame(minHeight: isActionable ? 44 : 0)
        .contentShape(Rectangle())
    }

    /// 장소를 지도 앱에서 연다. 좌표가 둘 다 있을 때만 만든다 — 이름만으로는 엉뚱한 곳이 열린다.
    private var placeMapURL: URL? {
        guard let latitude = place.latitude, let longitude = place.longitude else { return nil }
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "q", value: place.title)
        ]
        return components?.url
    }

    /// 서버 `homepage` 는 스킴이 빠진 값도 온다(`cs.go.kr/tour`) — 붙여서 연다.
    private var placeHomepageURL: URL? {
        guard let homepage = place.homepage?.trimmingCharacters(in: .whitespacesAndNewlines),
              !homepage.isEmpty else { return nil }
        let text = homepage.lowercased().hasPrefix("http") ? homepage : "https://\(homepage)"
        guard let url = URL(string: text), url.host != nil else { return nil }
        return url
    }

    /// 전화는 숫자만 남겨 `tel:` 로 건다. 숫자가 없으면 거는 시늉을 하지 않는다.
    private var placePhoneURL: URL? {
        guard let phone = place.phone else { return nil }
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        guard digits.count >= 3 else { return nil }
        return URL(string: "tel:\(digits)")
    }

    private func tabButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            // ENV-009 — 글자·밑줄은 그대로 두고 누를 넓이만 44x44 로 (재던 값 47x26pt)
            Text(title)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(selected ? MoyeoTheme.forest : MoyeoTheme.muted)
                .padding(.bottom, 8)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(selected ? MoyeoTheme.primary300 : .clear).frame(height: 2)
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func loadDetail() async {
        isLoading = true
        defer { isLoading = false }
        do {
            place = try await service.place(id: place.id)
            fallbackMessage = nil
        } catch {
            fallbackMessage = "상세 API를 불러오지 못해 저장된 예시 정보를 보여드려요."
        }
    }
}

private struct PlaceTypePill: View {
    let type: TourismContentType

    var body: some View {
        Label(type.rawValue, systemImage: type.symbol)
            .font(.caption2.weight(.heavy))
            .foregroundStyle(MoyeoTheme.text700)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(MoyeoTheme.subtleBackground)
            .clipShape(Capsule())
    }
}

/// 설정·가입에서 여는 법적 문서의 **종류**. 본문은 들고 있지 않다 —
/// 본문·제목·버전·필수 여부는 전부 서버 원장(`GET /api/v1/terms/latest/{code}`)에서 온다.
///
/// 예전에는 앱이 사본을 들고 있었는데, 사본이 서버와 **다른 말을 하고 있었다**:
/// 사본 「탈퇴 시 30일간 보관 후 완전히 삭제」 / 서버 원장 「탈퇴 시 지체 없이 파기」.
/// 실제 구현은 즉시 삭제라 사본이 사실과 달랐다. 법적 고지가 두 곳에 있으면 반드시 어긋난다.
///
/// `rawValue` 는 서버 `code` 그대로다. 제목 문자열로 문서를 찾던 방식은
/// **처리방침 자리에 가입 동의서를 열었다** (QA BE-03).
/// **위치정보 이용 동의는 없다** (BE-04 · 2026-09-14 결정 B안) — 「내 위치」는 좌표를
/// 서버로 보내지도 저장하지도 않으므로 수집하는 위치정보가 없고, 서버도 그 약관을 주지 않는다.
enum LegalDocumentKind: String, CaseIterable, Identifiable {
    /// 서비스 이용약관 (가입 동의 대상)
    case service = "SERVICE"
    /// 개인정보 수집·이용 **동의서** (가입 동의 대상)
    case privacyCollection = "PRIVACY_COLLECTION"
    /// 개인정보 **처리방침** — 동의 대상이 아니라 고지 문서다. 설정에서만 연다.
    case privacyPolicy = "PRIVACY_POLICY"
    /// 마케팅 정보 수신 동의 (가입 동의 대상 · 선택)
    case marketing = "MARKETING"

    var id: String { rawValue }

    /// 서버 `code`. 같은 값이지만 부르는 쪽 의도가 드러나게 이름을 둔다.
    var serverCode: String { rawValue }

    /// 본문을 받기 전(로딩·실패)에 헤더에 적을 **화면 이름**이다. 약관 제목이 아니다 —
    /// 본문을 받으면 서버 `title` 로 덮는다. 설정 목록의 행 이름과 같은 말이어야 한다.
    var screenLabel: String {
        switch self {
        case .service: "이용약관"
        case .privacyCollection: "개인정보 수집·이용 동의"
        case .privacyPolicy: "개인정보 처리방침"
        case .marketing: "마케팅 정보 수신 동의"
        }
    }
}

enum LegalDocumentEntry: Hashable {
    case signup
    case settings
}

struct LegalDocumentDetailView: View {
    /// 열려는 약관의 **종류**. 설정에서는 이 값으로 현재 판본을 받는다.
    /// 서버가 종류를 알려주지 않은 약관에서 열렸으면 `nil` 이고, 그때는 `serverTermID` 로만 받는다.
    let kind: LegalDocumentKind?
    let entry: LegalDocumentEntry
    /// 가입 약관 목록에서 열렸을 때의 `termId`. 사용자가 **본 그 판본**에 동의해야 하므로
    /// 있으면 종류가 아니라 이 ID 로 받는다.
    var serverTermID: Int64?
    var onAgree: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    /// 「아직 못 받았다」·「받았다」·「받아 봤더니 본문이 없다」·「실패했다」를 구분한다.
    /// 예전에는 실패를 삼키고 내장 사본을 현행 문서처럼 보여줬다 (IOS-F30).
    enum LoadState: Equatable { case loading, ready, empty, failed }

    @State private var document: ServerTermDetail?
    @State private var state: LoadState = .loading

    /// 본문을 받기 전에는 화면 이름을, 받은 뒤에는 **서버 제목**을 쓴다.
    private var screenTitle: String { document?.title ?? kind?.screenLabel ?? "약관" }

    /// 현행 본문을 확인하기 전에는 동의를 받지 않는다 — 무엇에 동의하는지가 확실하지 않기 때문이다.
    private var isAgreeBlocked: Bool { state != .ready }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let document, state == .ready {
                    // 필수·선택과 판본은 서버가 준 값만 쓴다. 받기 전에 「필수」라고 적어 두면
                    // 서버가 선택이라고 해도 사용자는 필수로 읽고 지나간다.
                    header(for: document)
                }
                statusBanner
                if let document, state == .ready {
                    // 서버 약관은 표를 포함한 마크다운이다 — 줄을 그대로 이으면
                    // `| 구분 | 수집 항목 |` 과 구분선이 본문에 노출된다. 가입 약관 화면과 같은 렌더러다.
                    MoyeoMarkdownView(markdown: document.content)
                }
                // 「설정 › 이용약관 › 지난 버전」은 **이제 있다.**
                //
                // 예전에는 API 가 없어 「없는 길을 안내하지 않는다」고 이 줄을 두지 않았다
                // (IOS-F62). 지금은 `GET /api/v1/terms/history/{code}` 가 지난 판본까지
                // 최신순으로 준다(2026-09-14 실서버 확인) — 서버가 주는 처리방침 본문이
                // 약속하는 그 화면을 만들었다 (결정 ①). 그때의 판단을 뒤집는 것이라 주석도 고친다.
                historyLink
                Text("약관이 바뀌면 시행 7일 전에 공지와 푸시로 알려드려요.")
                    .font(.caption).foregroundStyle(MoyeoTheme.muted)
                    .padding(.top, 16)
                    .overlay(alignment: .top) { Rectangle().fill(MoyeoTheme.softLine).frame(height: 1) }
            }
            .padding(20)
            .padding(.bottom, entry == .signup ? 72 : 20)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { signupFooter }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .navigationTitle(screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadTerm() }
        // 결정 ⑬ — 우측 상단 공유를 뺐다(공개 URL 규격 없음).
        .accessibilityIdentifier(
            "screen.terms.\(kind?.rawValue ?? "server\(serverTermID.map(String.init) ?? "")").\(entry == .signup ? "signup" : "settings")"
        )
    }

    /// 「지난 버전」 줄. 판본 목록으로 간다 (결정 ①).
    ///
    /// **설정에서 연 약관에만 둔다.** 가입 동의(`.signup`)는 지금 동의할 그 판본을 읽는
    /// 자리이고, 아래에 「동의하고 돌아가기」가 붙어 있다 — 거기서 다른 판본 목록으로
    /// 빠져나가게 하면 무엇에 동의하는 중이었는지가 흐려진다.
    /// 판본 목록에서 다시 열린 본문(`serverTermID` 가 있는 경우)에도 두지 않는다 —
    /// 같은 목록으로 되돌아가는 줄이라 제자리를 도는 길이 된다.
    @ViewBuilder private var historyLink: some View {
        if entry == .settings, serverTermID == nil, let kind {
            NavigationLink {
                TermsHistoryView(kind: kind, currentTermID: document?.termId)
            } label: {
                HStack(spacing: 8) {
                    Text("지난 버전")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.ink)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MoyeoTheme.muted)
                }
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .overlay(alignment: .top) { Rectangle().fill(MoyeoTheme.softLine).frame(height: 1) }
            .accessibilityIdentifier("terms.detail.history")
        }
    }

    private func header(for document: ServerTermDetail) -> some View {
        HStack(spacing: 7) {
            Text(document.required ? "필수" : "선택")
                .font(.caption.weight(.heavy))
                .foregroundStyle(document.required ? MoyeoTheme.forest : MoyeoTheme.muted)
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(document.required ? MoyeoTheme.leaf : MoyeoTheme.subtleBackground)
                .clipShape(Capsule())
            // 서버는 시행일을 내려주지 않는다 — 버전만 표기한다.
            Text(document.version).font(.caption).foregroundStyle(MoyeoTheme.muted).monospacedDigit()
        }
    }

    /// 로딩·실패·빈 상태. **어느 경우에도 빈 화면을 남기지 않는다.**
    @ViewBuilder private var statusBanner: some View {
        switch state {
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                Text("약관을 불러오는 중이에요").font(.subheadline).foregroundStyle(MoyeoTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("terms.detail.loading")
        case .failed:
            noticeCard(
                message: "약관을 불러오지 못했어요. 약관 본문은 서버에만 있어 지금은 보여드릴 수 없어요.",
                identifier: "terms.detail.loadFailed"
            )
        case .empty:
            noticeCard(
                message: "이 약관은 아직 등록되지 않았어요. 등록되면 바로 여기에서 보실 수 있어요.",
                identifier: "terms.detail.empty"
            )
        case .ready:
            EmptyView()
        }
    }

    private func noticeCard(message: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MoyeoTheme.dangerRed)
                .fixedSize(horizontal: false, vertical: true)
            if entry == .signup {
                Text("현행 본문을 확인하기 전에는 동의를 받지 않아요.")
                    .font(.caption)
                    .foregroundStyle(MoyeoTheme.muted)
            }
            Button("다시 시도") { Task { await loadTerm(force: true) } }
                .font(.caption.weight(.bold))
                .foregroundStyle(MoyeoTheme.brandText)
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                .accessibilityIdentifier("terms.detail.retry")
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoyeoTheme.subtleBackground)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.dangerRed.opacity(0.4)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder private var signupFooter: some View {
        if entry == .signup {
            HStack(spacing: 8) {
                Button("닫기") { dismiss() }
                    .buttonStyle(DesignSecondaryButtonStyle())
                    .frame(width: 84)
                Button(document?.required == false ? "이 항목에 동의하기" : "동의하고 돌아가기") {
                    onAgree()
                    dismiss()
                }
                .buttonStyle(DesignPrimaryButtonStyle())
                .disabled(isAgreeBlocked)
                .accessibilityIdentifier("terms.detail.agree")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(MoyeoTheme.card)
        }
    }

    /// 본문을 서버에서 받는다. 가입에서 열렸으면 그 판본(`termId`)을, 설정에서 열렸으면 종류(`code`)를 쓴다.
    private func loadTerm(force: Bool = false) async {
        // 약관은 공개 엔드포인트다 — 가입 중(세션 없음)에도 본문을 받아야 한다.
        guard MoyeoServerSync.allowsPublicEndpoints else {
            state = .failed
            return
        }
        guard force || document == nil else { return }
        state = .loading
        do {
            let detail: ServerTermDetail
            if let serverTermID {
                detail = try await TermsAPIClient.shared.term(id: serverTermID)
            } else if let kind {
                detail = try await TermsAPIClient.shared.latestTerm(code: kind.serverCode)
            } else {
                state = .failed
                return
            }
            document = detail
            state = detail.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .empty : .ready
        } catch {
            document = nil
            state = .failed
        }
    }
}

struct DesignPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(MoyeoTheme.forest.opacity(configuration.isPressed ? 0.78 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

struct DesignSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(MoyeoTheme.ink)
            .frame(minWidth: 84, minHeight: 48)
            .background(MoyeoTheme.card.opacity(configuration.isPressed ? 0.72 : 1))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(MoyeoTheme.line))
            .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}
