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

    /// 서버가 준 위경도를 **믿을 수 있을 때만** 좌표로 만든다.
    ///
    /// 예전에는 `nil` 만 걸렀다. 그래서 `0,0`(좌표 미입력의 흔한 표현)과 지구 밖 값이
    /// **유효한 좌표로 통과**했고, 11 지도 탐색은 그 값을 그대로 카메라 중심으로 썼다
    /// (`ServerTripMapper.mapContent` 가 `markers.first` 를 중심으로 잡는다).
    /// 응답 주입으로 확인한 실제 증상 — `0,0` 하나면 지도가 **서해(칭다오 앞바다)**,
    /// `60,200` 이면 **니가타 앞바다**를 비추고 경북 핀이 한 개도 안 보인다
    /// (TC SEARCH-016, 2026-09-15). 17-1a 방문지 지도만 `latitude != 0` 를 따로 걸고 있었는데,
    /// 화면마다 따로 거르면 이렇게 빠뜨린다 — **좌표를 만드는 이 한 곳**에서 거른다.
    init?(latitude: Double?, longitude: Double?) {
        guard let latitude, let longitude,
            latitude.isFinite, longitude.isFinite,
            // `0,0` 은 기니만 한복판이다. 이 서비스가 그곳을 가리킬 일은 없고,
            // 실제로는 「좌표가 없다」는 뜻으로 들어온다.
            !(latitude == 0 && longitude == 0),
            (-90...90).contains(latitude), (-180...180).contains(longitude)
        else {
            return nil
        }
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
