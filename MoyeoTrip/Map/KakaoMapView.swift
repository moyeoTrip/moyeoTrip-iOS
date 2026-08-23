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
    let onUnavailable: () -> Void

    func makeUIViewController(context: Context) -> KakaoMapHostController {
        let host = KakaoMapHostController(
            content: content,
            tracksCenter: tracksCenter,
            isInteractive: isInteractive,
            logoBottomInset: logoBottomInset
        )
        host.onCenterChange = onCenterChange
        host.onUnavailable = onUnavailable
        return host
    }

    func updateUIViewController(_ uiViewController: KakaoMapHostController, context: Context) {
        uiViewController.onCenterChange = onCenterChange
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

    /// 스크롤 안의 핀 드래그 지도는 부모 스크롤보다 먼저 손가락을 잡아야 한다.
    private lazy var mapPanRecognizer: UIPanGestureRecognizer = {
        let recognizer = UIPanGestureRecognizer(target: self, action: #selector(claimPan))
        recognizer.cancelsTouchesInView = false
        return recognizer
    }()

    var onCenterChange: ((MoyeoMapCoordinate) -> Void)?
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
        layer.clearAllItems()

        for marker in content.markers {
            let styleID = "moyeo.marker.\(marker.order.map(String.init) ?? "meeting")"
            let symbol = marker.order.map(MoyeoMapSymbols.orderBadge) ?? MoyeoMapSymbols.meetingPin
            manager.addPoiStyle(
                PoiStyle(
                    styleID: styleID,
                    styles: [PerLevelPoiStyle(iconStyle: PoiIconStyle(symbol: symbol), level: 0)]
                )
            )
            let options = PoiOptions(styleID: styleID, poiID: marker.id)
            options.clickable = false
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
