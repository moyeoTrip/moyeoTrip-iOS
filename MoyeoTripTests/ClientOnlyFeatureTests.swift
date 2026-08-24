import Foundation
@testable import MoyeoTrip
import SwiftUI
import Testing

@Suite("최근 검색어 규칙 (화면 12)")
struct RecentSearchPolicyTests {
    @Test func addingTrimsWhitespaceAndIgnoresEmptyInput() {
        #expect(RecentSearchPolicy.adding("  경주  ", to: []) == ["경주"])
        #expect(RecentSearchPolicy.adding("   ", to: ["경주"]) == ["경주"])
        #expect(RecentSearchPolicy.adding("", to: ["경주"]) == ["경주"])
        #expect(RecentSearchPolicy.adding("\n\t", to: []).isEmpty)
    }

    @Test func addingPutsNewestFirst() {
        var searches: [String] = []
        searches = RecentSearchPolicy.adding("경주", to: searches)
        searches = RecentSearchPolicy.adding("단풍", to: searches)
        #expect(searches == ["단풍", "경주"])
    }

    @Test func addingDuplicateMovesItToTheFrontWithoutGrowing() {
        let searches = RecentSearchPolicy.adding("경주", to: ["단풍", "경주", "주왕산"])
        #expect(searches == ["경주", "단풍", "주왕산"])
    }

    @Test func addingTrimmedDuplicateIsStillTreatedAsDuplicate() {
        let searches = RecentSearchPolicy.adding("  경주 ", to: ["단풍", "경주"])
        #expect(searches == ["경주", "단풍"])
    }

    @Test func addingKeepsAtMostTenAndDropsTheOldest() {
        var searches = (1...10).reversed().map { "키워드\($0)" }
        #expect(searches.count == RecentSearchPolicy.limit)
        searches = RecentSearchPolicy.adding("새 검색어", to: searches)
        #expect(searches.count == 10)
        #expect(searches.first == "새 검색어")
        #expect(!searches.contains("키워드1"))
        #expect(searches.last == "키워드2")
    }

    @Test func removingDropsOnlyThatKeyword() {
        #expect(RecentSearchPolicy.removing("단풍", from: ["경주", "단풍", "주왕산"]) == ["경주", "주왕산"])
        #expect(RecentSearchPolicy.removing("없는 값", from: ["경주"]) == ["경주"])
    }

    @Test func sanitizedDropsEmptyDuplicateAndOverflowEntries() {
        let stored = ["경주", " 경주 ", "", "   ", "단풍"] + (1...12).map { "키워드\($0)" }
        let sanitized = RecentSearchPolicy.sanitized(stored)
        #expect(sanitized.count == RecentSearchPolicy.limit)
        #expect(sanitized.prefix(2) == ["경주", "단풍"])
        #expect(Set(sanitized).count == sanitized.count)
    }
}

@Suite("최근 검색어 저장소")
struct RecentSearchStoreTests {
    @Test func userDefaultsStoreRoundTripsAndSanitizesOnLoad() throws {
        let defaults = try makeIsolatedDefaults(#function)
        let store = UserDefaultsRecentSearchStore(defaults: defaults, key: "recent-searches-test")

        #expect(store.load().isEmpty)
        store.save(["경주", "단풍"])
        #expect(store.load() == ["경주", "단풍"])

        defaults.set(["경주", "경주", "", "단풍"], forKey: "recent-searches-test")
        #expect(store.load() == ["경주", "단풍"])
    }

    @MainActor
    @Test func modelPersistsRecordRemoveAndClear() throws {
        let defaults = try makeIsolatedDefaults(#function)
        let key = "recent-searches-model"
        let makeModel = {
            RecentSearchModel(store: UserDefaultsRecentSearchStore(defaults: defaults, key: key))
        }

        let model = makeModel()
        model.record("경주")
        model.record(" 단풍 ")
        model.record("경주")
        #expect(model.searches == ["경주", "단풍"])

        // 앱을 다시 켠 것과 같다 — 저장소에서 다시 읽는다
        #expect(makeModel().searches == ["경주", "단풍"])

        model.remove("경주")
        #expect(model.searches == ["단풍"])
        #expect(makeModel().searches == ["단풍"])

        model.clear()
        #expect(model.searches.isEmpty)
        #expect(makeModel().searches.isEmpty)
    }

    private func makeIsolatedDefaults(_ name: String) throws -> UserDefaults {
        let suite = "kr.hanchae.MoyeoTrip.tests.\(abs(name.hashValue))"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}

@Suite("테마 3상태 (화면 29)")
struct ThemePreferenceTests {
    @Test func rowValuesMatchPlanningCopy() {
        #expect(MoyeoThemeMode.system.rowValue == "시스템 기본")
        #expect(MoyeoThemeMode.light.rowValue == "라이트")
        #expect(MoyeoThemeMode.dark.rowValue == "다크")
    }

    @Test func systemModeLeavesTheColorSchemeToTheOS() {
        #expect(MoyeoThemeMode.system.colorScheme == nil)
        #expect(MoyeoThemeMode.light.colorScheme == ColorScheme.light)
        #expect(MoyeoThemeMode.dark.colorScheme == ColorScheme.dark)
    }

    @Test func tappingCyclesSystemLightDarkAndBack() {
        #expect(MoyeoThemeMode.system.next == .light)
        #expect(MoyeoThemeMode.light.next == .dark)
        #expect(MoyeoThemeMode.dark.next == .system)
    }

    @Test func storedValueResolutionFallsBackToSystem() {
        #expect(MoyeoThemeMode.resolved(from: "system") == .system)
        #expect(MoyeoThemeMode.resolved(from: "light") == .light)
        #expect(MoyeoThemeMode.resolved(from: "dark") == .dark)
        #expect(MoyeoThemeMode.resolved(from: nil) == .system)
        #expect(MoyeoThemeMode.resolved(from: "") == .system)
        #expect(MoyeoThemeMode.resolved(from: "sepia") == .system)
    }

    @MainActor
    @Test func storePersistsTheSelectedMode() throws {
        let suite = "kr.hanchae.MoyeoTrip.tests.theme"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let store = MoyeoThemeStore(defaults: defaults, key: "app-theme-mode")
        #expect(store.mode == .system)
        store.advance()
        #expect(store.mode == .light)
        store.advance()
        store.advance()
        #expect(store.mode == .system)

        store.update(.dark)
        // 앱을 다시 켠 것과 같다
        #expect(MoyeoThemeStore(defaults: defaults, key: "app-theme-mode").mode == .dark)
    }
}

@Suite("앱 버전 (화면 29)")
struct AppVersionInfoTests {
    @Test func displayTextCombinesShortVersionAndBuildNumber() {
        #expect(AppVersionInfo.displayText(shortVersion: "1.0", buildNumber: "1") == "1.0 (1)")
        #expect(AppVersionInfo.displayText(shortVersion: "1.0.4", buildNumber: "") == "1.0.4")
        #expect(AppVersionInfo.displayText(shortVersion: "", buildNumber: "12") == "(12)")
        #expect(AppVersionInfo.displayText(shortVersion: "", buildNumber: "").isEmpty)
    }

    @Test func bundleValuesAreReadFromTheRunningApp() {
        // 근거 없는 문구를 표시하지 않는다 — 실제 번들 값이 있어야 한다
        #expect(!AppVersionInfo.shortVersion.isEmpty)
        #expect(!AppVersionInfo.buildNumber.isEmpty)
    }
}

@Suite("오픈소스 라이선스 데이터 (29-4 · 29-4a)")
struct OSSLicenseCatalogTests {
    @Test func bundledCatalogCarriesTheTwentyIOSEntries() throws {
        let items = try OSSLicenseCatalog.loadItems()
        #expect(items.count == 20)
        #expect(items.first?.name == "Firebase iOS SDK")
        #expect(items.contains { $0.name == "Alamofire" && $0.license == "MIT" })
        #expect(items.allSatisfy { !$0.name.isEmpty && !$0.version.isEmpty && !$0.license.isEmpty })
        #expect(items.allSatisfy { !$0.url.isEmpty })
        #expect(Set(items.map(\.name)).count == items.count)
    }

    @Test func decodingKeepsOptionalTextIdAndNote() throws {
        let json = """
        {
          "platform": "ios",
          "items": [
            {
              "name": "Alamofire",
              "version": "5.12.0",
              "license": "MIT",
              "licenseTextId": "MIT",
              "url": "https://github.com/Alamofire/Alamofire"
            },
            {
              "name": "KakaoMapsSDK",
              "version": "2.12.19",
              "license": "카카오 지도 SDK 이용약관",
              "url": "https://apis.map.kakao.com",
              "note": "오픈소스 라이선스가 아닙니다."
            }
          ]
        }
        """
        let items = try OSSLicenseCatalog.decodeItems(from: Data(json.utf8))
        #expect(items.count == 2)
        #expect(items[0].licenseTextId == "MIT")
        #expect(items[0].note == nil)
        #expect(items[1].licenseTextId == nil)
        #expect(items[1].note == "오픈소스 라이선스가 아닙니다.")
    }

    @Test func selfDistributedSdkHasNoLicenseTextAndIsNotInvented() throws {
        let kakaoMaps = try #require(OSSLicenseCatalog.item(named: "KakaoMapsSDK"))
        #expect(kakaoMaps.licenseTextId == nil)
        #expect(OSSLicenseCatalog.licenseText(for: kakaoMaps) == nil)
        #expect(!(kakaoMaps.note ?? "").isEmpty)
    }

    @Test func everyLicenseTextIdResolvesToABundledFullText() throws {
        let items = try OSSLicenseCatalog.loadItems()
        let textIDs = Set(items.compactMap(\.licenseTextId))
        #expect(textIDs == ["Apache-2.0", "MIT", "BSD-3-Clause", "Zlib"])
        for item in items where item.licenseTextId != nil {
            let text = OSSLicenseCatalog.licenseText(for: item)
            #expect(text != nil, "\(item.name) 의 라이선스 전문을 번들에서 찾지 못했습니다")
            #expect(!(text ?? "").isEmpty)
        }
    }

    @Test func apacheFullTextComesFromTheDistributedLicenseFile() throws {
        let firebase = try #require(OSSLicenseCatalog.item(named: "Firebase iOS SDK"))
        let text = try #require(OSSLicenseCatalog.licenseText(for: firebase))
        #expect(text.contains("Apache License"))
        #expect(text.contains("Version 2.0, January 2004"))
    }

    @Test func templateTextsCarryNoInventedCopyrightLine() throws {
        let alamofire = try #require(OSSLicenseCatalog.item(named: "Alamofire"))
        let mit = try #require(OSSLicenseCatalog.licenseText(for: alamofire))
        #expect(mit.contains("Permission is hereby granted"))
        #expect(!mit.contains("Copyright (c)"))
    }
}
