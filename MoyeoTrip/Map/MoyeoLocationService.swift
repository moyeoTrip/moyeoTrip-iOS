//
//  MoyeoLocationService.swift
//  MoyeoTrip
//
//  11 탐색 지도의 「내 위치」. 예전에는 버튼 모양만 있고 `CLLocationManager` 도
//  `Info.plist` 의 위치 권한 키도 **앱 전체에 하나도 없었다** (IOS-F24).
//
//  **권한은 「내 위치」를 누른 그 순간에만 묻는다.** 앱을 켤 때 묻지 않는다 —
//  왜 필요한지 모르는 채로 뜨는 권한 팝업은 거절당하고, 한 번 거절당하면 되돌리기 어렵다.
//  그래서 이 타입은 **스스로 아무것도 시작하지 않고** `requestCurrentLocation()` 을 부를 때만 움직인다.
//
//  **Always 권한은 쓰지 않는다** — 지도를 보는 동안에만 필요하므로 When-In-Use 뿐이다.
//

import Combine
import CoreLocation
import Foundation

/// 「내 위치」를 누른 결과. 갈래마다 **화면이 다르게 말해야 한다** —
/// 어느 것도 죽은 버튼으로 두지 않는다.
enum MoyeoLocationOutcome: Equatable {
    /// 좌표를 받았다.
    case located(MoyeoMapCoordinate)
    /// 사용자가 권한을 거절했다. 설정에서만 되돌릴 수 있다.
    case denied
    /// 기기 정책(스크린타임 등)으로 막혔다 — **설정으로 가도 사용자가 못 바꾼다.**
    case restricted
    /// 권한은 있는데 좌표를 못 얻었다(실내·기기 오류). **좌표를 지어내지 않는다.**
    case unavailable
}

/// 위치 한 번 받아오기. 계속 따라다니지 않는다(`requestLocation` 은 1회성이다).
@MainActor
final class MoyeoLocationService: NSObject, ObservableObject {
    /// 마지막 결과. 화면이 이 값으로 문구를 고른다.
    @Published private(set) var outcome: MoyeoLocationOutcome?
    /// 묻는 중·받는 중. 버튼을 두 번 누르지 못하게 한다.
    @Published private(set) var isRequesting = false

    private let manager: CLLocationManager
    /// 권한 팝업의 답을 기다리는 중인지. 답이 오면 곧바로 좌표를 요청한다.
    private var isAwaitingAuthorization = false

    override init() {
        manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// 「내 위치」를 눌렀을 때. **여기서만** 권한을 묻는다.
    func requestCurrentLocation() {
        guard !isRequesting else { return }
        outcome = nil

        switch manager.authorizationStatus {
        case .notDetermined:
            isRequesting = true
            isAwaitingAuthorization = true
            manager.requestWhenInUseAuthorization()
        case .denied:
            outcome = .denied
        case .restricted:
            outcome = .restricted
        case .authorizedWhenInUse, .authorizedAlways:
            isRequesting = true
            manager.requestLocation()
        @unknown default:
            outcome = .unavailable
        }
    }

    /// 화면을 떠나거나 안내를 닫을 때 — 다음에 눌렀을 때 옛 문구가 남지 않게 한다.
    func clearOutcome() {
        outcome = nil
    }

    private func finish(_ result: MoyeoLocationOutcome) {
        isAwaitingAuthorization = false
        isRequesting = false
        outcome = result
    }
}

extension MoyeoLocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            // 권한 팝업을 띄운 경우에만 반응한다 — 다른 이유로 상태가 바뀌었을 때
            // 사용자가 누르지도 않은 위치 요청을 보내지 않는다.
            guard isAwaitingAuthorization else { return }
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                isAwaitingAuthorization = false
                manager.requestLocation()
            case .denied:
                finish(.denied)
            case .restricted:
                finish(.restricted)
            case .notDetermined:
                break
            @unknown default:
                finish(.unavailable)
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        let coordinate = locations.last?.coordinate
        Task { @MainActor in
            // 좌표를 못 읽었으면 **지어내지 않는다.** (0, 0)은 「측위 실패」의 흔한 표시라 함께 막는다.
            guard let coordinate,
                  CLLocationCoordinate2DIsValid(coordinate),
                  coordinate.latitude != 0 || coordinate.longitude != 0 else {
                finish(.unavailable)
                return
            }
            finish(.located(
                MoyeoMapCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
            ))
        }
    }

    /// 실패를 삼키지 않는다 — 화면이 「지금은 위치를 확인할 수 없어요」를 적을 수 있게 한다.
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let isDenied = (error as? CLError)?.code == .denied
        Task { @MainActor in
            finish(isDenied ? .denied : .unavailable)
        }
    }
}

/// 경상북도 대략 범위. 이 서비스는 경북 전용이라, 밖이면 **그 사실을 알린다** —
/// 다만 지도를 옮기는 것 자체는 막지 않는다(내 위치를 보는 것은 사용자의 자유다).
///
/// **동쪽을 넓게 잡는다 — 울릉군(울릉도·독도)이 경상북도다.**
/// 처음에는 `35.4...37.2` · `127.7...129.6` 으로 뒀는데, 그 사각형은
/// 울릉도(37.4845, 130.9057)와 독도(37.2428, 131.8664)를 **둘 다 빼버린다.**
/// 이 서비스에는 울릉도 코스가 실제로 있어서(「울릉도 일주 4박 5일」 등), 그대로 두면
/// **울릉도에 있는 사용자가 「경상북도 밖이에요」라는 틀린 안내**를 받는다.
/// 안드로이드 `GyeongbukBounds` 와 같은 값이다 (2026-09-14).
enum MoyeoGyeongbukRegion {
    static let latitudeRange = 35.35...37.55
    static let longitudeRange = 127.75...131.95

    static func contains(_ coordinate: MoyeoMapCoordinate) -> Bool {
        latitudeRange.contains(coordinate.latitude) && longitudeRange.contains(coordinate.longitude)
    }
}
