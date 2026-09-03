import Foundation
#if canImport(KakaoMapsSDK)
import KakaoMapsSDK
#endif

/// 지도에 찍는 좌표 하나. 서버/목데이터의 위경도를 그대로 담는다.
struct MoyeoMapCoordinate: Hashable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// 위경도가 비어 있는 목데이터는 지도를 그리지 않는다.
    init?(latitude: Double?, longitude: Double?) {
        guard let latitude, let longitude else { return nil }
        self.init(latitude: latitude, longitude: longitude)
    }
}

/// 지도 위 마커. `order` 가 있으면 기획의 초록 순번 원, 없으면 집합 장소 단일 핀.
struct MoyeoMapMarker: Identifiable, Hashable {
    let id: String
    let coordinate: MoyeoMapCoordinate
    var order: Int?
}

/// 실지도/목업 어느 쪽이든 같은 값으로 그린다.
struct MoyeoMapContent: Hashable {
    var center: MoyeoMapCoordinate
    var level: Int = 15
    var markers: [MoyeoMapMarker] = []
    var polyline: [MoyeoMapCoordinate] = []
    /// 마커·경로가 모두 보이도록 카메라를 맞출지. 단일 지점 지도는 false.
    var fitsContent = true
}

/// 카카오 지도 SDK를 쓸 수 있는지 한곳에서 판단한다.
///
/// 키 주입 경로는 카카오 로그인과 동일하다: `Secrets.xcconfig` → `App.xcconfig`
/// → `Info.plist` 의 `KAKAO_NATIVE_APP_KEY`. 코드에 키를 심지 않는다.
enum MoyeoMapRuntime {
    private static var initialization: Bool?

    static var nativeAppKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String) ?? ""
    }

    /// 앱 진입 시 한 번 호출한다. 키가 없거나 SDK가 링크되지 않았으면 초기화를 건너뛴다.
    @discardableResult
    static func initializeIfPossible() -> Bool {
        if let initialization { return initialization }

        #if canImport(KakaoMapsSDK)
        guard !nativeAppKey.isEmpty else {
            initialization = false
            return false
        }
        SDKInitializer.InitSDK(appKey: nativeAppKey)
        initialization = true
        return true
        #else
        initialization = false
        return false
        #endif
    }

    /// 실지도를 렌더할지. UITEST 캡처는 타일 로딩이 비결정적이라 항상 목업으로 남긴다.
    static var rendersLiveMap: Bool {
        // 목데이터 캡처에서는 실지도를 끈다 — 타일 로딩이 비결정적이라 번호별 비교가 깨진다.
        //
        // **라이브 캡처(`UITEST_LIVE_DATA`)는 예외다.** 실데이터를 보려고 찍는 캡처에서
        // 지도만 목업이면 "지도가 실제로 그려지는지"를 확인할 수 없다.
        // 안드로이드의 `LocalMapCaptureMode` 와 같은 취급이다.
        guard !UITestRuntime.isEnabled || UITestRuntime.usesLiveData else { return false }
        return initializeIfPossible()
    }
}
