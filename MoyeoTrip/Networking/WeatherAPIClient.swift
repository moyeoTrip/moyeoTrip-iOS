import Foundation

/// 09 홈 히어로의 날씨. `GET /api/v1/weather/gyeongbuk`
///
/// 2026-08-25 실측에서 숫자 필드(기온·습도·풍속·강수·미세먼지)는 **전부 null** 이다.
/// 지금 쓸 수 있는 값은 `condition` 과 `locationName` 뿐이라 나머지는 옵셔널로 둔다.
struct ServerGyeongbukWeather: Decodable, Hashable {
    let condition: String
    let locationName: String?
    let fallbackApplied: Bool?
    let forecastAt: String?
    let temperatureCelsius: Double?
    let humidityPercent: Double?
    let windSpeedMetersPerSecond: Double?
    let precipitationMillimeters: Double?
    let pm10: Double?
    let pm25: Double?
}

extension ServerGyeongbukWeather {
    /// 서버 `condition` 9종 → 히어로 시안 9종. 1:1 로 맞아떨어져 보정이 필요 없다.
    var heroCondition: WeatherCondition? {
        switch condition {
        case "SUNNY": return .sunny
        case "CLOUDY": return .cloudy
        case "RAIN": return .rain
        case "SNOW": return .snow
        case "FOG": return .fog
        case "STRONG_WIND": return .wind
        case "HEAVY_RAIN": return .heavyRain
        case "HEAT_WAVE": return .heatwave
        case "FINE_DUST": return .dust
        default: return nil
        }
    }
}

struct WeatherAPIClient {
    static let shared = WeatherAPIClient()

    private let api: MoyeoAPIClient

    init(api: MoyeoAPIClient = .shared) {
        self.api = api
    }

    func gyeongbuk() async throws -> ServerGyeongbukWeather {
        try await api.get("/api/v1/weather/gyeongbuk")
    }
}
