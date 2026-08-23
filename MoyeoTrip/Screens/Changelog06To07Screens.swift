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

struct TourismPlace: Identifiable, Hashable {
    let id: String
    let type: TourismContentType
    let title: String
    let address: String
    let latitude: Double
    let longitude: Double
    var thumbnailURL: URL?
    let postalCode: String
    let phone: String
    let phoneLabel: String
    let homepage: String
    let summary: String
    let imageLabels: [String]
    let menuImageLabels: [String]
    var imageURLs: [URL] = []
    var menuImageURLs: [URL] = []

    var showsMenuImages: Bool {
        type == .restaurant && !menuImageLabels.isEmpty
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
    @StateObject private var model: TourismPlaceSearchModel
    @State private var query = "청송"
    @State private var selectedType: TourismContentType?
    @State private var showsMap = false
    @State private var addedCount = 3
    @Environment(\.dismiss) private var dismiss

    init(
        onAdd: @escaping (TourismPlace) -> Void = { _ in },
        service: TourismContentProviding? = nil
    ) {
        self.onAdd = onAdd
        let resolvedService = service ?? (UITestRuntime.isEnabled
            ? SampleTourismContentService()
            : TourismAPIClient())
        _model = StateObject(wrappedValue: TourismPlaceSearchModel(service: resolvedService))
    }

    private var filteredPlaces: [TourismPlace] {
        model.places.filter { place in
            let matchesType = selectedType == nil || place.type == selectedType
            let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesQuery = normalized.isEmpty || place.title.contains(normalized) || place.address.contains(normalized)
            return matchesType && matchesQuery
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
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain)
                            .foregroundStyle(MoyeoTheme.text400)
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
                        filterButton("전체", type: nil)
                        ForEach(TourismContentType.allCases) { type in
                            filterButton(type.rawValue, type: type)
                        }
                    }
                }

                if showsMap {
                    MoyeoPhotoTile(mascot: "🗺️", mood: .forest, height: 150, cornerRadius: 12)
                        .accessibilityIdentifier("placeSearch.mapPreview")
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

                    Text("\(filteredPlaces.count)곳 · 주왕산 코스 근처순")
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.muted)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)

                    ForEach(filteredPlaces) { place in
                        NavigationLink(value: place) {
                            PlaceSearchRow(place: place, onAdd: {
                                onAdd(place)
                                addedCount += 1
                            })
                        }
                        .buttonStyle(.plain)
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
                    Image(systemName: "map")
                        .foregroundStyle(MoyeoTheme.ink)
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
            PlaceDetailView(place: place, onAdd: onAdd, service: model.service)
        }
        .task { await model.load() }
        .accessibilityIdentifier("screen.placeSearch")
    }

    private func filterButton(_ title: String, type: TourismContentType?) -> some View {
        let isSelected = selectedType == type
        return Button(title) { selectedType = type }
            .font(.caption.weight(.heavy))
            .foregroundStyle(isSelected ? MoyeoTheme.onLeaf : MoyeoTheme.ink)
            .padding(.horizontal, 13)
            .frame(height: 32)
            .background(isSelected ? MoyeoTheme.leaf : MoyeoTheme.card)
            .overlay(Capsule().stroke(isSelected ? MoyeoTheme.forest : MoyeoTheme.line))
            .clipShape(Capsule())
    }
}

private struct PlaceSearchRow: View {
    let place: TourismPlace
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            CachedRemoteImage(url: place.thumbnailURL) { image in
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
                Text(place.address).font(.caption).foregroundStyle(MoyeoTheme.muted).lineLimit(2)
                Text(String(format: "%.4f, %.4f", place.latitude, place.longitude))
                    .font(.caption2).foregroundStyle(MoyeoTheme.text400).monospacedDigit()
            }
            Spacer(minLength: 4)
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.caption.weight(.bold))
                    .frame(width: 32, height: 32)
                    .background(MoyeoTheme.leaf)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(MoyeoTheme.primary300))
            }
            .buttonStyle(.plain)
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
    var onAdd: (TourismPlace) -> Void = { _ in }
    private let service: TourismContentProviding
    @Environment(\.dismiss) private var dismiss
    @State private var showsMenu = false
    @State private var isLoading = false
    @State private var fallbackMessage: String?

    init(
        place: TourismPlace,
        onAdd: @escaping (TourismPlace) -> Void = { _ in },
        service: TourismContentProviding? = nil
    ) {
        _place = State(initialValue: place)
        self.onAdd = onAdd
        self.service = service ?? (UITestRuntime.isEnabled
            ? SampleTourismContentService()
            : TourismAPIClient())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 사진이 없을 때도 화면기획·웹·안드로이드처럼 풍경 자리표시자를 쓴다.
                // 아이콘만 크게 놓으면 같은 화면인데 iOS만 사진이 없는 것처럼 보인다.
                ZStack(alignment: .topTrailing) {
                    CachedRemoteImage(url: place.imageURLs.first ?? place.thumbnailURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        MoyeoPhotoTile(mascot: "", mood: .forest, height: 210, cornerRadius: MoyeoTheme.cardRadius)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius))

                    // 화면기획·웹의 사진 카운터
                    Text("1/\(max(place.imageLabels.count, 1))")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(.black.opacity(0.46))
                        .clipShape(Capsule())
                        .padding(10)
                        .accessibilityIdentifier("placeDetail.photoCounter")
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(place.title).font(.title3.weight(.heavy))
                    Spacer()
                    PlaceTypePill(type: place.type)
                }

                VStack(spacing: 12) {
                    detailRow("mappin.and.ellipse", place.address, "우편번호 \(place.postalCode)")
                    detailRow("phone", place.phone, place.phoneLabel)
                    detailRow("map", String(format: "%.6f, %.6f", place.latitude, place.longitude), "지도에서 열기")
                    detailRow("globe", place.homepage, "홈페이지")
                }
                .padding(14)
                .background(MoyeoTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.softLine))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Text("소개").font(.headline)
                Text(place.summary).font(.subheadline).foregroundStyle(MoyeoTheme.text700)

                if isLoading {
                    ProgressView("상세 정보를 불러오고 있어요")
                } else if let fallbackMessage {
                    Label(fallbackMessage, systemImage: "wifi.exclamationmark")
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.warningText)
                        .accessibilityIdentifier("placeDetail.fallback")
                }

                HStack(spacing: 20) {
                    tabButton("사진 \(place.imageLabels.count)", selected: !showsMenu) { showsMenu = false }
                    if place.showsMenuImages {
                        tabButton("메뉴판 \(place.menuImageLabels.count)", selected: showsMenu) { showsMenu = true }
                    }
                }

                let labels = showsMenu ? place.menuImageLabels : place.imageLabels
                let urls = showsMenu ? place.menuImageURLs : place.imageURLs
                // 화면기획·웹은 3열 풍경 타일이다. 아이콘 + 라벨 자리표시자는 사진이 깨진 것처럼 읽힌다.
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                    spacing: 8
                ) {
                    ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                        CachedRemoteImage(url: urls.indices.contains(index) ? urls[index] : nil) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            MoyeoPhotoTile(
                                mascot: "",
                                mood: Self.galleryMood(index: index, showsMenu: showsMenu),
                                height: 74,
                                cornerRadius: 10
                            )
                        }
                        .frame(maxWidth: .infinity, minHeight: 74)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .accessibilityLabel(label)
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
                    Label("이 장소를 코스에 담기", systemImage: "plus")
                }
                .buttonStyle(DesignPrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(MoyeoTheme.card)
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .navigationTitle("방문지 상세")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 화면기획·웹의 우측 상단 공유
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(MoyeoTheme.ink)
                }
                .accessibilityLabel("방문지 공유")
                .accessibilityIdentifier("placeDetail.share")
            }
        }
        .accessibilityIdentifier("screen.placeDetail.\(place.id)")
        .task { await loadDetail() }
    }

    /// 갤러리 타일 톤은 화면기획처럼 장마다 조금씩 달라야 한 장을 여러 번 붙인 것처럼 보이지 않는다.
    private static func galleryMood(index: Int, showsMenu: Bool) -> CourseMood {
        let photoMoods: [CourseMood] = [.sunrise, .forest, .coral, .blossom, .river, .sunrise, .forest, .coral]
        let menuMoods: [CourseMood] = [.sunrise, .coral, .blossom, .forest]
        let moods = showsMenu ? menuMoods : photoMoods
        return moods[index % moods.count]
    }

    private func detailRow(_ icon: String, _ value: String, _ caption: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(MoyeoTheme.muted).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.caption.weight(.heavy))
                Text(caption).font(.caption2).foregroundStyle(MoyeoTheme.muted)
            }
            Spacer()
        }
    }

    private func tabButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(selected ? MoyeoTheme.forest : MoyeoTheme.muted)
                .padding(.bottom, 8)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(selected ? MoyeoTheme.primary300 : .clear).frame(height: 2)
                }
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

enum LegalDocumentKind: String, CaseIterable, Identifiable {
    case service
    case privacy
    case location
    case marketing

    var id: String { rawValue }

    var content: LegalDocumentContent {
        switch self {
        case .service: .service
        case .privacy: .privacy
        case .location: .location
        case .marketing: .marketing
        }
    }
}

enum LegalDocumentEntry: Hashable {
    case signup
    case settings
}

struct AuthTermsDirectLaunchView: View {
    // 동의는 사용자가 직접 켜는 항목이다. 진입 상태는 화면기획·웹·안드로이드와 같이 모두 꺼짐.
    @State private var agreedTerms: Set<AuthTerm> = []

    var body: some View {
        AuthTermsView(
            agreedTerms: $agreedTerms,
            isSubmitting: false,
            errorMessage: nil,
            finishAction: {}
        )
        .accessibilityIdentifier("screen.authTerms.direct")
    }
}

struct LegalDocumentContent: Hashable {
    let title: String
    let isRequired: Bool
    let version: String
    let effectiveDate: String
    let summary: String
    let sections: [LegalSection]

    struct LegalSection: Hashable {
        let title: String
        let body: String
    }

    static let service = LegalDocumentContent(
        title: "이용약관", isRequired: true, version: "v1.2", effectiveDate: "2026년 5월 1일 시행",
        summary: "모여트립을 쓰면서 지켜야 할 것과, 우리가 약속하는 것을 적었어요.",
        sections: [
            .init(
                title: "제1조 (목적)",
                body:
                    "이 약관은 모여트립 in 경북(이하 “서비스”)이 제공하는 경상북도 여행 코스 기반 동행 매칭 서비스의 이용 조건과 절차, " +
                    "회사와 회원의 권리·의무를 정하는 것을 목적으로 합니다."
            ),
            .init(
                title: "제2조 (용어의 정의)",
                body:
                    "“모집”이란 회원이 특정 코스로 함께 떠날 동행을 구하는 게시물을 말합니다. “캠프”란 최소 인원이 충족되어 자동으로 열리는 " +
                    "채팅방을 말합니다. “호스트”란 모집을 개설한 회원을, “게스트”란 해당 모집에 참여한 회원을 말합니다."
            ),
            .init(
                title: "제3조 (모집의 성립과 소멸)",
                body:
                    "모집은 마감일까지 최소 인원(3명)을 충족한 경우에만 확정됩니다. 마감일 기준 인원이 미달한 모집은 자동으로 소멸하며, 이 " +
                    "경우 회원에게 별도의 책임이 발생하지 않습니다."
            ),
            .init(
                title: "제4조 (여행 중 발생하는 사항)",
                body:
                    "회사는 회원 간의 만남을 매개할 뿐, 여행 중 발생하는 이동·숙박·식음 등의 계약 당사자가 아닙니다. 여행 비용은 회원 간에 " +
                    "직접 정산하며, 서비스 내 정산 기능은 기록용 메모입니다."
            ),
            .init(
                title: "제5조 (금지 행위)",
                body:
                    "타인을 사칭하거나, 금전 거래를 유도하거나, 성적·차별적 표현으로 다른 회원에게 불쾌감을 주는 행위를 금지합니다. 위반 시 " +
                    "이용이 제한될 수 있습니다."
            ),
            .init(
                title: "제6조 (계정과 닉네임)",
                body:
                    "가입 시 선택한 닉네임과 캐릭터는 도감 기록의 동일성을 위해 변경되지 않습니다. 다만 회사는 서비스 정착 이후 정책을 변경할 " +
                    "수 있으며, 변경 시 사전에 공지합니다."
            )
        ]
    )

    static let privacy = LegalDocumentContent(
        title: "개인정보 처리방침", isRequired: true, version: "v1.4", effectiveDate: "2026년 7월 10일 시행",
        summary: "어떤 정보를 왜 받고, 얼마나 보관하는지 적었어요.",
        sections: [
            .init(
                title: "수집하는 정보",
                body:
                    "가입 시 소셜 로그인 식별자, 생년(나이대), 성별을 받습니다. 실명·연락처는 받지 않습니다. 서비스 이용 과정에서 작성한 " +
                    "모집·채팅·피드 내용과 접속 기록이 저장됩니다."
            ),
            .init(title: "이용 목적", body: "동행 매칭(나이대·성별 조건 확인), 안전한 이용 환경 유지(신고·차단 처리), 서비스 개선을 위한 통계 분석에 사용합니다."),
            .init(title: "다른 회원에게 보이는 정보", body: "닉네임·캐릭터·나이대·성별·매너 점수·여행 횟수가 공개됩니다. 생년월일과 로그인 계정 정보는 공개되지 않습니다."),
            .init(title: "보관 기간", body: "탈퇴 시 30일간 보관 후 완전히 삭제합니다. 다만 신고·분쟁 처리 이력은 관련 법령이 정한 기간 동안 별도 보관합니다."),
            .init(
                title: "위탁 및 제3자 제공",
                body:
                    "지도·관광정보 표시를 위해 한국관광공사 OpenAPI 등 외부 서비스를 이용하며, 이 과정에서 회원의 개인정보를 전달하지 " +
                    "않습니다."
            )
        ]
    )

    static let location = LegalDocumentContent(
        title: "위치정보 이용 동의", isRequired: false, version: "v1.0", effectiveDate: "2026년 5월 1일 시행",
        summary: "켜지 않아도 서비스를 쓸 수 있어요. 켜면 근처 모집을 먼저 보여드려요.",
        sections: [
            .init(title: "이용 목적", body: "현재 위치 기준 30km 이내에서 오늘 출발하는 모집을 홈 상단에 보여주고, 집합 장소까지의 길 찾기를 제공합니다."),
            .init(title: "동의를 거부할 경우", body: "근처 모집 추천과 길 찾기만 제한되고, 그 외 기능은 모두 동일하게 이용할 수 있습니다.")
        ]
    )

    static let marketing = LegalDocumentContent(
        title: "마케팅 정보 수신 동의", isRequired: false, version: "v1.0", effectiveDate: "2026년 5월 1일 시행",
        summary: "새 코스나 이벤트 소식을 받아볼지 정하는 항목이에요.",
        sections: [
            .init(title: "보내는 내용", body: "계절별 신규 코스 소개, 지역 축제 일정, 이벤트 안내를 앱 푸시로 보냅니다."),
            .init(title: "보내지 않는 것", body: "모집 승인·채팅·마감 임박처럼 이용에 꼭 필요한 알림은 이 동의와 무관하게 발송됩니다."),
            .init(title: "철회 방법", body: "설정 › 알림에서 언제든 끌 수 있고, 끄더라도 서비스 이용에는 아무런 제한이 없습니다.")
        ]
    )
}

struct LegalDocumentDetailView: View {
    let kind: LegalDocumentKind
    let entry: LegalDocumentEntry
    var onAgree: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    private var document: LegalDocumentContent { kind.content }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 7) {
                    Text(document.isRequired ? "필수" : "선택")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(document.isRequired ? MoyeoTheme.forest : MoyeoTheme.muted)
                        .padding(.horizontal, 9)
                        .frame(height: 24)
                        .background(document.isRequired ? MoyeoTheme.leaf : MoyeoTheme.subtleBackground)
                        .clipShape(Capsule())
                    Text("\(document.version) · \(document.effectiveDate)")
                        .font(.caption).foregroundStyle(MoyeoTheme.muted).monospacedDigit()
                }

                Text(document.summary)
                    .font(.subheadline)
                    .foregroundStyle(MoyeoTheme.text700)
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MoyeoTheme.subtleBackground)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.softLine))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                ForEach(document.sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title).font(.subheadline.weight(.heavy))
                        Text(section.body).font(.subheadline).foregroundStyle(MoyeoTheme.text700)
                    }
                }

                Text("이전 판본은 설정 › 이용약관 › 지난 버전에서 볼 수 있어요. 약관이 바뀌면 시행 7일 전에 공지와 푸시로 알려드려요.")
                    .font(.caption).foregroundStyle(MoyeoTheme.muted)
                    .padding(.top, 16)
                    .overlay(alignment: .top) { Rectangle().fill(MoyeoTheme.softLine).frame(height: 1) }
            }
            .padding(20)
            .padding(.bottom, entry == .signup ? 72 : 20)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if entry == .signup {
                HStack(spacing: 8) {
                    Button("닫기") { dismiss() }
                        .buttonStyle(DesignSecondaryButtonStyle())
                        .frame(width: 84)
                    Button(document.isRequired ? "동의하고 돌아가기" : "이 항목에 동의하기") {
                        onAgree()
                        dismiss()
                    }
                    .buttonStyle(DesignPrimaryButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(MoyeoTheme.card)
            }
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 화면기획·웹의 우측 상단 공유
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(MoyeoTheme.ink)
                }
                .accessibilityLabel("약관 공유")
                .accessibilityIdentifier("terms.detail.share")
            }
        }
        .accessibilityIdentifier("screen.terms.\(kind.rawValue).\(entry == .signup ? "signup" : "settings")")
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
