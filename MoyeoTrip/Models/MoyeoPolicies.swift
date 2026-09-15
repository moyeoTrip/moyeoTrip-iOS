//
//  MoyeoPolicies.swift
//  MoyeoTrip
//

import Foundation

/// 모집 연령 조건(17-4 · 18-6)으로 고를 수 있는 범위.
///
/// **하한은 가입 최소 연령과 같은 값에서 파생한다** — 서버도 그렇게 정의한다
/// (`ChatRoom.MINIMUM_CONDITION_AGE = AgePolicy.MINIMUM_SIGNUP_AGE`).
/// 조건 하한이 가입 연령보다 높으면 **그 나이로 가입한 사람이 연령 조건이 걸린 모집에
/// 영영 들어갈 수 없다** — 2026-09-14 BE-06 으로 20 → 19 가 됐다.
/// 또 바뀌면 `KoreanBirthdatePolicy.minimumSignupAge` 하나만 고치면 된다.
enum RoomConditionAgePolicy {
    static var minimum: Int { KoreanBirthdatePolicy.minimumSignupAge }
    static let maximum = 100

    /// 안내 문구에 쓰는 범위 표기. 숫자는 이 타입 하나에서만 온다.
    static var rangeText: String { "\(minimum)~\(maximum)" }
}

enum WeatherCondition: CaseIterable, Hashable {
    case sunny
    case cloudy
    case rain
    case snow
    case fog
    case wind
    case heavyRain
    case heatwave
    case dust
}

enum WeatherHeroState: String, Hashable {
    case good
    case caution
    case blocked

    var badge: String {
        switch self {
        case .good:
            return "추천"
        case .caution:
            return "주의"
        case .blocked:
            return "대체 추천"
        }
    }
}

struct GeneratedImageAsset: Hashable {
    let catalogName: String
    let lightFileName: String
    let darkFileName: String
}

struct WeatherHeroContent: Hashable {
    let label: String
    let badge: String
    let copy: String
    let state: WeatherHeroState
    let imageAsset: GeneratedImageAsset
    let mood: CourseMood

    var imageAssetName: String {
        imageAsset.catalogName
    }
}

enum WeatherHeroPolicy {
    static let defaultCondition: WeatherCondition = .sunny

    static var defaultContent: WeatherHeroContent {
        content(for: defaultCondition)
    }

    static func content(for condition: WeatherCondition) -> WeatherHeroContent {
        contents[condition] ?? contents[defaultCondition]!
    }

    static var allImageAssets: [GeneratedImageAsset] {
        WeatherCondition.allCases.map { content(for: $0).imageAsset }
    }

    // 생성 이미지는 HEIC 로 들어 있다(2026-08-26 용량 절감으로 PNG → HEIC 교체).
    // 이 파일명은 런타임 로딩에 쓰이지 않는다 — 카탈로그는 이미지셋 이름으로 해석된다.
    // 카탈로그와 선언이 어긋나는 것을 테스트가 잡도록 실제 확장자를 적어 둔다.
    private static func generatedAsset(named fileBaseName: String) -> GeneratedImageAsset {
        GeneratedImageAsset(
            catalogName: fileBaseName.replacingOccurrences(of: "-", with: "_"),
            lightFileName: "\(fileBaseName).heic",
            darkFileName: "\(fileBaseName)-night.heic"
        )
    }

    private static let contents: [WeatherCondition: WeatherHeroContent] = [
        .sunny: WeatherHeroContent(
            label: "맑음",
            badge: WeatherHeroState.good.badge,
            copy: "햇살 좋은 날, 걷기 좋은 코스를 추천해드려요",
            state: .good,
            imageAsset: generatedAsset(named: "weather-sunny-cheomseongdae"),
            mood: .forest
        ),
        .cloudy: WeatherHeroContent(
            label: "구름",
            badge: WeatherHeroState.good.badge,
            copy: "선선한 날씨에 역사 산책 코스를 추천해드려요",
            state: .good,
            imageAsset: generatedAsset(named: "weather-cloudy-bulguksa"),
            mood: .sunrise
        ),
        .rain: WeatherHeroContent(
            label: "비",
            badge: WeatherHeroState.caution.badge,
            copy: "우산과 실내 동선을 챙겨 여유로운 코스를 골라드려요",
            state: .caution,
            imageAsset: generatedAsset(named: "weather-rain-hahoe"),
            mood: .river
        ),
        .snow: WeatherHeroContent(
            label: "눈",
            badge: WeatherHeroState.caution.badge,
            copy: "눈길 이동이 짧고 쉬어가기 좋은 코스를 먼저 보여드려요",
            state: .caution,
            imageAsset: generatedAsset(named: "weather-snow-buseoksa"),
            mood: .sunrise
        ),
        .fog: WeatherHeroContent(
            label: "안개",
            badge: WeatherHeroState.caution.badge,
            copy: "시야가 흐린 날엔 가까운 코스와 안전한 이동을 우선해요",
            state: .caution,
            imageAsset: generatedAsset(named: "weather-fog-seokguram"),
            mood: .blossom
        ),
        .wind: WeatherHeroContent(
            label: "강풍",
            badge: WeatherHeroState.blocked.badge,
            copy: "바람이 강한 날엔 해안 코스 대신 대체 코스를 추천해요",
            state: .blocked,
            imageAsset: generatedAsset(named: "weather-wind-homigot"),
            mood: .blossom
        ),
        .heavyRain: WeatherHeroContent(
            label: "폭우",
            badge: WeatherHeroState.blocked.badge,
            copy: "오늘은 무리하지 말고 실내형 코스를 먼저 확인해보세요",
            state: .blocked,
            imageAsset: generatedAsset(named: "weather-heavy-rain-woljeonggyo"),
            mood: .river
        ),
        .heatwave: WeatherHeroContent(
            label: "폭염",
            badge: WeatherHeroState.blocked.badge,
            copy: "더위가 심한 날엔 짧은 동선과 그늘 많은 장소를 추천해요",
            state: .blocked,
            imageAsset: generatedAsset(named: "weather-heatwave-dosan"),
            mood: .coral
        ),
        .dust: WeatherHeroContent(
            label: "미세먼지",
            badge: WeatherHeroState.blocked.badge,
            copy: "공기가 탁한 날엔 실내 휴식과 짧은 이동 코스를 우선해요",
            state: .blocked,
            imageAsset: generatedAsset(named: "weather-dust-donggung-wolji"),
            mood: .sunrise
        )
    ]
}

enum WeatherCoursePolicy {
    static func recommendedCourses(for condition: WeatherCondition, courses: [TravelCourse]) -> [TravelCourse] {
        let priorityIDs: [String]
        switch condition {
        case .sunny:
            priorityIDs = ["course-cheongsong-juwangsan", "course-andong-hahoe", "course-gyeongju-history"]
        case .cloudy:
            priorityIDs = ["course-gyeongju-history", "course-andong-hahoe", "course-cheongsong-juwangsan"]
        case .rain:
            priorityIDs = ["course-andong-hahoe", "course-gyeongju-history", "course-cheongsong-juwangsan"]
        case .snow:
            priorityIDs = ["course-andong-hahoe", "course-gyeongju-history", "course-cheongsong-juwangsan"]
        case .fog:
            priorityIDs = ["course-gyeongju-history", "course-andong-hahoe", "course-cheongsong-juwangsan"]
        case .wind:
            priorityIDs = ["course-andong-hahoe", "course-gyeongju-history", "course-cheongsong-juwangsan"]
        case .heavyRain:
            priorityIDs = ["course-gyeongju-history", "course-andong-hahoe", "course-cheongsong-juwangsan"]
        case .heatwave:
            priorityIDs = ["course-andong-hahoe", "course-cheongsong-juwangsan", "course-gyeongju-history"]
        case .dust:
            priorityIDs = ["course-gyeongju-history", "course-andong-hahoe", "course-cheongsong-juwangsan"]
        }

        let courseByID = Dictionary(uniqueKeysWithValues: courses.map { ($0.id, $0) })
        let prioritized = priorityIDs.compactMap { courseByID[$0] }
        return prioritized + courses.filter { !priorityIDs.contains($0.id) }
    }
}

enum SplashPolicy {
    static let imageAsset = GeneratedImageAsset(
        catalogName: "splash_generated",
        lightFileName: "splash-generated.heic",
        darkFileName: "splash-generated-night.heic"
    )
}

enum ApplicationNotePolicy {
    static let minimumLength = 10
    static let maximumLength = 200

    static func validationMessage(for note: String) -> String? {
        let count = note.trimmingCharacters(in: .whitespacesAndNewlines).count

        if count < minimumLength {
            return "한마디는 10자 이상 입력해주세요."
        }

        if count > maximumLength {
            return "한마디는 200자 이하로 입력해주세요."
        }

        return nil
    }
}

enum RoutePolicy {
    static let minimumStopCount = 2
    static let maximumStopCount = 20
    /// 상단 고정 공지는 **하나**다 (정본 `ATTACH-COMPOSER-CANON.md` R5-1, 기획 결정 2026-08-30).
    /// 서버는 개수를 막지 않으므로 클라가 지킨다.
    static let maximumPinnedNoticeCount = 1

    static func editState(source: CourseSource, isTripConfirmed: Bool) -> RouteEditState {
        if isTripConfirmed {
            return .tripConfirmed
        }
        return source == .custom ? .editable : .linkedLocked
    }

    static func canSave(stops: [ItineraryStop], state: RouteEditState) -> Bool {
        state == .editable && (minimumStopCount...maximumStopCount).contains(stops.count)
    }

    static func normalized(_ stops: [ItineraryStop]) -> [ItineraryStop] {
        stops.enumerated().map { index, stop in
            var value = stop
            value.order = index + 1
            return value
        }
    }

    static func pinnedNotices(from notices: [TripNotice]) -> [TripNotice] {
        Array(notices.filter(\.isPinned).prefix(maximumPinnedNoticeCount))
    }
}

enum RecruitmentSchedulePolicy {
    static func isComplete(_ schedule: TripScheduleDetails) -> Bool {
        switch schedule.kind {
        case .dayTrip:
            return !schedule.startDate.isEmpty
                && !(schedule.startTime ?? "").isEmpty
                && !(schedule.endTime ?? "").isEmpty
        case .overnight:
            return !schedule.startDate.isEmpty && !(schedule.endDate ?? "").isEmpty
        }
    }
}

enum NicknamePolicy {
    static let maximumLength = 10

    static func isValid(_ nickname: String) -> Bool {
        let value = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return !value.isEmpty && value.count <= maximumLength
    }
}
