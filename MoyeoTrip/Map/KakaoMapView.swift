import SwiftUI
#if canImport(KakaoMapsSDK)
import KakaoMapsSDK
#endif

/// 앱 전체에서 쓰는 단 하나의 지도 뷰.
///
/// 키가 없거나 SDK 초기화·인증이 실패하거나 UITEST 캡처 모드면 `fallback` 의
/// 기존 목업 지도를 그린다. 지도 때문에 화면이 비는 경우는 없다.
struct MoyeoMapView<Fallback: View>: View {
    var content: MoyeoMapContent
    /// 중앙 고정 핀을 띄우고, 지도를 끌면 중심 좌표를 알려준다 (17-3 집합 장소 지정).
    var draggablePin = false
    /// 스크롤 안에 들어가는 미리보기 지도는 손가락을 부모 스크롤에 양보한다.
    var isInteractive = true
    /// 지도 위에 카드·탭바가 덮이는 화면에서 카카오 로고를 그만큼 띄운다 (로고는 가리면 안 된다).
    var logoBottomInset: CGFloat = 0
    var onPinMove: ((MoyeoMapCoordinate) -> Void)?
    /// 핀을 눌렀을 때 그 핀의 `MoyeoMapMarker.id`.
    /// 주지 않으면 핀은 **눌리지 않는다** — 코스 미리보기처럼 탭할 것이 없는 지도는 그대로 둔다.
    var onMarkerTap: ((String) -> Void)?
    @ViewBuilder var fallback: () -> Fallback

    @State private var liveMapUnavailable = false

    var body: some View {
        if MoyeoMapRuntime.rendersLiveMap, !liveMapUnavailable {
            liveMap
        } else {
            fallback()
        }
    }

    @ViewBuilder
    private var liveMap: some View {
        #if canImport(KakaoMapsSDK)
        ZStack {
            KakaoMapRepresentable(
                content: content,
                tracksCenter: draggablePin,
                isInteractive: isInteractive,
                logoBottomInset: logoBottomInset,
                onCenterChange: onPinMove,
                onMarkerTap: onMarkerTap,
                onUnavailable: { liveMapUnavailable = true }
            )
            if draggablePin {
                MoyeoMapCenterPin()
            }
        }
        #else
        fallback()
        #endif
    }
}

#if canImport(KakaoMapsSDK)

private struct KakaoMapRepresentable: UIViewControllerRepresentable {
    let content: MoyeoMapContent
    let tracksCenter: Bool
    let isInteractive: Bool
    let logoBottomInset: CGFloat
    let onCenterChange: ((MoyeoMapCoordinate) -> Void)?
    let onMarkerTap: ((String) -> Void)?
    let onUnavailable: () -> Void

    func makeUIViewController(context: Context) -> KakaoMapHostController {
        let host = KakaoMapHostController(
            content: content,
            tracksCenter: tracksCenter,
            isInteractive: isInteractive,
            logoBottomInset: logoBottomInset
        )
        host.onCenterChange = onCenterChange
        host.onMarkerTap = onMarkerTap
        host.onUnavailable = onUnavailable
        return host
    }

    func updateUIViewController(_ uiViewController: KakaoMapHostController, context: Context) {
        uiViewController.onCenterChange = onCenterChange
        uiViewController.onMarkerTap = onMarkerTap
        uiViewController.onUnavailable = onUnavailable
        uiViewController.update(content: content, tracksCenter: tracksCenter)
    }
}

/// `KMViewContainer` + `KMController` 라이프사이클을 담당한다.
final class KakaoMapHostController: UIViewController {
    private enum Identifier {
        static let mapView = "moyeoMapView"
        static let markerLayer = "moyeo.markers"
        static let routeLayer = "moyeo.route.layer"
        static let routeStyle = "moyeo.route.style"
    }

    private var engine: KMController?
    private var content: MoyeoMapContent
    private var tracksCenter: Bool
    private let isInteractive: Bool
    private let logoBottomInset: CGFloat
    private var appliedContent: MoyeoMapContent?
    private var cameraHandler: (any DisposableEventHandler)?
    /// 놓으면 핸들러가 바로 해제된다 — 레이어를 다시 만들 때마다 갱신한다.
    private var markerTapHandler: (any DisposableEventHandler)?

    /// 스크롤 안의 핀 드래그 지도는 부모 스크롤보다 먼저 손가락을 잡아야 한다.
    private lazy var mapPanRecognizer: UIPanGestureRecognizer = {
        let recognizer = UIPanGestureRecognizer(target: self, action: #selector(claimPan))
        recognizer.cancelsTouchesInView = false
        return recognizer
    }()

    var onCenterChange: ((MoyeoMapCoordinate) -> Void)?
    var onMarkerTap: ((String) -> Void)?
    var onUnavailable: (() -> Void)?

    init(content: MoyeoMapContent, tracksCenter: Bool, isInteractive: Bool, logoBottomInset: CGFloat) {
        self.content = content
        self.tracksCenter = tracksCenter
        self.isInteractive = isInteractive
        self.logoBottomInset = logoBottomInset
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("KakaoMapHostController는 코드로만 만든다")
    }

    override func loadView() {
        view = KMViewContainer()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let container = view as? KMViewContainer else { return }
        container.isUserInteractionEnabled = isInteractive
        let engine = KMController(viewContainer: container)
        engine.delegate = self
        self.engine = engine
    }

    @objc private func claimPan() {}

    /// 스크롤 뷰 안에서 핀 드래그 지도가 세로 스와이프를 잃지 않도록 우선순위를 잡는다.
    private func claimScrollGesture() {
        guard tracksCenter, isInteractive else { return }
        if mapPanRecognizer.view == nil {
            view.addGestureRecognizer(mapPanRecognizer)
        }
        var ancestor = view.superview
        while let current = ancestor {
            if let scrollView = current as? UIScrollView {
                scrollView.panGestureRecognizer.require(toFail: mapPanRecognizer)
                return
            }
            ancestor = current.superview
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let engine, !engine.isEnginePrepared else { return }
        guard engine.prepareEngine() else {
            onUnavailable?()
            return
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        claimScrollGesture()
        guard let engine, !engine.isEngineActive else { return }
        engine.activateEngine()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let map = mapView, map.viewRect.size != view.bounds.size else { return }
        map.viewRect = CGRect(origin: .zero, size: view.bounds.size)
        if !tracksCenter {
            moveCamera(on: map)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        engine?.pauseEngine()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        cameraHandler = nil
        appliedContent = nil
        engine?.resetEngine()
    }

    func update(content: MoyeoMapContent, tracksCenter: Bool) {
        self.tracksCenter = tracksCenter
        self.content = content
        applyContent()
    }

    private var mapView: KakaoMap? {
        engine?.getView(Identifier.mapView) as? KakaoMap
    }

    private func mapPoint(_ coordinate: MoyeoMapCoordinate) -> MapPoint {
        MapPoint(longitude: coordinate.longitude, latitude: coordinate.latitude)
    }

    private func applyContent() {
        guard let map = mapView else { return }
        registerCameraHandler(on: map)
        guard appliedContent != content else { return }
        appliedContent = content

        map.poiClickable = false
        map.setLogoPosition(
            origin: GuiAlignment(vAlign: .bottom, hAlign: .right),
            position: CGPoint(x: 12, y: max(12, logoBottomInset))
        )
        drawMarkers(on: map)
        drawPolyline(on: map)
        // 핀 드래그 지도는 사용자의 제스처가 기준이라 카메라를 다시 잡지 않는다.
        if !tracksCenter {
            moveCamera(on: map)
        }
    }

    private func drawMarkers(on map: KakaoMap) {
        let manager = map.getLabelManager()
        let layer = manager.getLabelLayer(layerID: Identifier.markerLayer)
            ?? manager.addLabelLayer(
                option: LabelLayerOptions(
                    layerID: Identifier.markerLayer,
                    competitionType: .none,
                    competitionUnit: .symbolFirst,
                    orderType: .rank,
                    zOrder: 10_001
                )
            )
        guard let layer else { return }
        // 핀 탭(화면기획 11) — 누른 핀의 `poiID` 가 곧 `MoyeoMapMarker.id` 다.
        // 카드를 바꾸는 것까지만 하고, 상세로 가는 건 **카드를 눌렀을 때**다.
        //
        // 핸들러는 **지도**에 건다(`KakaoMap.addPoisTappedEventHandler`).
        // `LabelLayer` 에는 이 함수가 없고, `LodPoi.addPoiTappedEventHandler` 는 핀 하나짜리다.
        if onMarkerTap != nil, markerTapHandler == nil {
            markerTapHandler = map.addPoisTappedEventHandler(target: self) { host in
                { param in
                    // 이 지도에는 마커 레이어가 하나뿐이지만, 경로·집합 핀이 늘면 다른 레이어의
                    // 탭까지 카드로 흘러온다 — 레이어를 확인해서 우리 마커만 받는다.
                    guard param.layerID == Identifier.markerLayer else { return }
                    host.onMarkerTap?(param.poiID)
                }
            }
        }
        layer.clearAllItems()

        for marker in content.markers {
            let styleID = "moyeo.marker.\(marker.order.map(String.init) ?? "meeting")"
            // 함수 참조(`map(MoyeoMapSymbols.orderBadge)`)로 넘기면 main-actor 격리가 벗겨져
            // Swift 6 에서 경고가 난다. 호출을 이 컨텍스트(=@MainActor) 안에 두고 값만 고른다.
            let symbol: UIImage = if let order = marker.order {
                MoyeoMapSymbols.orderBadge(order)
            } else {
                MoyeoMapSymbols.meetingPin
            }
            manager.addPoiStyle(
                PoiStyle(
                    styleID: styleID,
                    styles: [PerLevelPoiStyle(iconStyle: PoiIconStyle(symbol: symbol), level: 0)]
                )
            )
            let options = PoiOptions(styleID: styleID, poiID: marker.id)
            // 탭을 받을 화면에서만 켠다. 꺼져 있으면 핸들러를 걸어도 이벤트가 오지 않는다.
            options.clickable = onMarkerTap != nil
            options.rank = marker.order ?? 0
            layer.addPoi(option: options, at: mapPoint(marker.coordinate))?.show()
        }
    }

    private func drawPolyline(on map: KakaoMap) {
        let manager = map.getRouteManager()
        let layer = manager.getRouteLayer(layerID: Identifier.routeLayer)
            ?? manager.addRouteLayer(layerID: Identifier.routeLayer, zOrder: 10_000)
        guard let layer else { return }
        layer.clearAllRoutes()
        guard content.polyline.count > 1 else { return }

        manager.addRouteStyleSet(
            RouteStyleSet(
                styleID: Identifier.routeStyle,
                styles: [
                    RouteStyle(styles: [
                        PerLevelRouteStyle(
                            width: 10,
                            color: MoyeoMapSymbols.routeColor,
                            strokeWidth: 2,
                            strokeColor: MoyeoMapSymbols.routeStroke,
                            level: 0
                        )
                    ])
                ]
            )
        )
        let options = RouteOptions(routeID: Identifier.routeStyle, styleID: Identifier.routeStyle, zOrder: 0)
        options.segments = [RouteSegment(points: content.polyline.map(mapPoint), styleIndex: 0)]
        layer.addRoute(option: options)?.show()
    }

    private func moveCamera(on map: KakaoMap) {
        let coordinates = content.markers.map(\.coordinate) + content.polyline
        if content.fitsContent, coordinates.count > 1, let area = paddedArea(around: coordinates) {
            map.moveCamera(CameraUpdate.make(area: area))
        } else {
            map.moveCamera(CameraUpdate.make(target: mapPoint(content.center), zoomLevel: content.level, mapView: map))
        }
    }

    /// 마커가 화면 끝에 붙어 잘리지 않도록 경계 상자를 조금 넓힌다.
    private func paddedArea(around coordinates: [MoyeoMapCoordinate]) -> AreaRect? {
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        guard
            let minLatitude = latitudes.min(), let maxLatitude = latitudes.max(),
            let minLongitude = longitudes.min(), let maxLongitude = longitudes.max()
        else {
            return nil
        }
        let latitudePadding = max((maxLatitude - minLatitude) * 0.28, 0.004)
        let longitudePadding = max((maxLongitude - minLongitude) * 0.28, 0.004)
        return AreaRect(
            southWest: MapPoint(longitude: minLongitude - longitudePadding, latitude: minLatitude - latitudePadding),
            northEast: MapPoint(longitude: maxLongitude + longitudePadding, latitude: maxLatitude + latitudePadding)
        )
    }

    private func registerCameraHandler(on map: KakaoMap) {
        guard tracksCenter, cameraHandler == nil else { return }
        cameraHandler = map.addCameraStoppedEventHandler(target: self) { host in
            { _ in host.reportCenterCoordinate() }
        }
    }

    private func reportCenterCoordinate() {
        guard let map = mapView, let onCenterChange else { return }
        let coordinate = map.getPosition(CGPoint(x: view.bounds.midX, y: view.bounds.midY)).wgsCoord
        onCenterChange(MoyeoMapCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }
}

extension KakaoMapHostController: MapControllerDelegate {
    func addViews() {
        let info = MapviewInfo(
            viewName: Identifier.mapView,
            defaultPosition: mapPoint(content.center),
            defaultLevel: content.level
        )
        engine?.addView(info)
    }

    func addViewSucceeded(_ viewName: String, viewInfoName: String) {
        appliedContent = nil
        applyContent()
    }

    func addViewFailed(_ viewName: String, viewInfoName: String) {
        onUnavailable?()
    }

    func authenticationFailed(_ errorCode: Int, desc: String) {
        onUnavailable?()
    }

    func containerDidResized(_ size: CGSize) {
        guard let map = mapView else { return }
        map.viewRect = CGRect(origin: .zero, size: size)
        if !tracksCenter {
            moveCamera(on: map)
        }
    }
}

#endif
