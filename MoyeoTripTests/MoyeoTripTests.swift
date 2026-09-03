//
//  MoyeoTripTests.swift
//  MoyeoTripTests
//
//  Created by 김한빈 on 5/29/26.
//

import Foundation
@testable import MoyeoTrip
import SwiftUI
import Testing

// swiftlint:disable file_length

@Suite(.serialized)
@MainActor
struct MoyeoTripTests {
    @Test func weatherHeroPolicyChoosesSafeContentForRain() {
        let heavyRain = WeatherHeroPolicy.content(for: .heavyRain)
        let sunny = WeatherHeroPolicy.content(for: .sunny)
        let rain = WeatherHeroPolicy.content(for: .rain)
        let dust = WeatherHeroPolicy.content(for: .dust)

        #expect(WeatherHeroPolicy.defaultContent == sunny)
        #expect(sunny.badge == "추천")
        #expect(sunny.place == "경주 첨성대")
        #expect(heavyRain.badge == "대체 추천")
        #expect(heavyRain.place == "경주 월정교")
        #expect(heavyRain.imageAssetName == "weather_heavy_rain_woljeonggyo")
        #expect(heavyRain.imageAsset.lightFileName == "weather-heavy-rain-woljeonggyo.heic")
        #expect(heavyRain.imageAsset.darkFileName == "weather-heavy-rain-woljeonggyo-night.heic")
        #expect(heavyRain.copy.contains("실내형 코스"))
        #expect(rain.state == .caution)
        #expect(rain.badge == "주의")
        #expect(rain.place == "안동 하회마을")
        #expect(rain.imageAssetName == "weather_rain_hahoe")
        #expect(dust.state == .blocked)
        #expect(dust.badge == "대체 추천")
        #expect(dust.imageAssetName == "weather_dust_donggung_wolji")
        // 코스 추천은 서버 코스 목록으로만 돈다 — 목 코스 상수는 더 이상 없다 (NO-MOCK-CANON R1)
        #expect(WeatherCoursePolicy.recommendedCourses(for: .sunny, courses: []).isEmpty)
    }

    @Test func generatedAssetsHaveLightAndDarkCatalogVariants() throws {
        #expect(WeatherHeroPolicy.allImageAssets == expectedWeatherAssets)
        #expect(Set(WeatherHeroPolicy.allImageAssets.map(\.catalogName)).count == WeatherCondition.allCases.count)

        for asset in expectedWeatherAssets + [expectedSplashAsset] {
            try assertImageSetContainsLightAndDarkFiles(asset)
            #expect(!asset.catalogName.contains("-"))
            #expect(asset.lightFileName != asset.darkFileName)
        }

        #expect(SplashPolicy.imageAsset == expectedSplashAsset)
    }

    @Test func applicationNotePolicyUsesNotionLimits() {
        #expect(ApplicationNotePolicy.validationMessage(for: "짧음") != nil)
        #expect(ApplicationNotePolicy.validationMessage(for: String(repeating: "가", count: 200)) == nil)
        #expect(ApplicationNotePolicy.validationMessage(for: String(repeating: "가", count: 201)) != nil)
        #expect(ApplicationNotePolicy.validationMessage(for: "처음 참여라 집결지에서 같이 움직이고 싶어요.") == nil)
    }

    @Test func tabMetadataMatchesVisibleNavigation() {
        let titles = MoyeoTab.allCases.map(\.title)
        let images = MoyeoTab.allCases.map(\.systemImage)

        #expect(titles == ["홈", "탐색", "모임", "피드", "마이"])
        #expect(images == [
            "house.fill",
            "magnifyingglass",
            "person.3.fill",
            "doc.text.image.fill",
            "person.fill"
        ])
    }

    @Test func visibilityDefaultsMatchPlanningRules() {
        #expect(FeedVisibility.friendsOnly.rawValue == "친구만")
        #expect(DogamVisibility.friendsOnly.rawValue == "친구에게만")
    }

    @Test func systemNoticeSenderPolicyIncludesBrandNotices() {
        let systemMessage = ChatMessage(
            id: "notice-system",
            senderName: "시스템",
            avatar: "sparkles",
            body: "모집이 마감 임박합니다",
            time: "지금",
            isMine: false
        )
        let brandMessage = ChatMessage(
            id: "notice-brand",
            senderName: "모여트립",
            avatar: "sparkles",
            body: "참여 확정됐어요.",
            time: "지금",
            isMine: false
        )
        let hostMessage = ChatMessage(
            id: "notice-host",
            senderName: "호스트",
            avatar: "sparkles",
            body: "집결지를 확인해 주세요.",
            time: "지금",
            isMine: false
        )

        #expect(systemMessage.isSystemNotice)
        #expect(brandMessage.isSystemNotice)
        #expect(!hostMessage.isSystemNotice)
    }

    private var assetCatalogURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("MoyeoTrip")
            .appendingPathComponent("Assets.xcassets")
    }

    private func assertImageSetContainsLightAndDarkFiles(_ asset: GeneratedImageAsset) throws {
        let imageSetURL = assetCatalogURL.appendingPathComponent("\(asset.catalogName).imageset")
        let contentsURL = imageSetURL.appendingPathComponent("Contents.json")
        let data = try Data(contentsOf: contentsURL)
        let contents = try JSONDecoder().decode(AssetCatalogContents.self, from: data)

        let lightFileURL = imageSetURL.appendingPathComponent(asset.lightFileName)
        let darkFileURL = imageSetURL.appendingPathComponent(asset.darkFileName)

        #expect(FileManager.default.fileExists(atPath: lightFileURL.path))
        #expect(FileManager.default.fileExists(atPath: darkFileURL.path))
        #expect(contents.images.contains { $0.filename == asset.lightFileName && $0.appearances == nil })
        #expect(contents.images.contains { image in
            image.filename == asset.darkFileName && image.appearances?.contains(.darkLuminosity) == true
        })
    }

    private var expectedSplashAsset: GeneratedImageAsset {
        GeneratedImageAsset(
            catalogName: "splash_generated",
            lightFileName: "splash-generated.heic",
            darkFileName: "splash-generated-night.heic"
        )
    }

    private var expectedWeatherAssets: [GeneratedImageAsset] {
        [
            GeneratedImageAsset(
                catalogName: "weather_sunny_cheomseongdae",
                lightFileName: "weather-sunny-cheomseongdae.heic",
                darkFileName: "weather-sunny-cheomseongdae-night.heic"
            ),
            GeneratedImageAsset(
                catalogName: "weather_cloudy_bulguksa",
                lightFileName: "weather-cloudy-bulguksa.heic",
                darkFileName: "weather-cloudy-bulguksa-night.heic"
            ),
            GeneratedImageAsset(
                catalogName: "weather_rain_hahoe",
                lightFileName: "weather-rain-hahoe.heic",
                darkFileName: "weather-rain-hahoe-night.heic"
            ),
            GeneratedImageAsset(
                catalogName: "weather_snow_buseoksa",
                lightFileName: "weather-snow-buseoksa.heic",
                darkFileName: "weather-snow-buseoksa-night.heic"
            ),
            GeneratedImageAsset(
                catalogName: "weather_fog_seokguram",
                lightFileName: "weather-fog-seokguram.heic",
                darkFileName: "weather-fog-seokguram-night.heic"
            ),
            GeneratedImageAsset(
                catalogName: "weather_wind_homigot",
                lightFileName: "weather-wind-homigot.heic",
                darkFileName: "weather-wind-homigot-night.heic"
            ),
            GeneratedImageAsset(
                catalogName: "weather_heavy_rain_woljeonggyo",
                lightFileName: "weather-heavy-rain-woljeonggyo.heic",
                darkFileName: "weather-heavy-rain-woljeonggyo-night.heic"
            ),
            GeneratedImageAsset(
                catalogName: "weather_heatwave_dosan",
                lightFileName: "weather-heatwave-dosan.heic",
                darkFileName: "weather-heatwave-dosan-night.heic"
            ),
            GeneratedImageAsset(
                catalogName: "weather_dust_donggung_wolji",
                lightFileName: "weather-dust-donggung-wolji.heic",
                darkFileName: "weather-dust-donggung-wolji-night.heic"
            )
        ]
    }
}

extension MoyeoTripTests {
    @MainActor
    @Test func nicknameRefreshUpdatesServerTokenAndCandidates() async {
        let refreshedResponse = AuthNicknameCandidatesResponse(
            selectionToken: "server-selection-2",
            candidates: [
                AuthNicknameCandidate(id: "new-1", nickname: "포근한 두루미 4186", color: "NAVY"),
                AuthNicknameCandidate(id: "new-2", nickname: "느긋한 수달 7351", color: "MINT"),
                AuthNicknameCandidate(id: "new-3", nickname: "용감한 토끼 2640", color: "PINK")
            ]
        )
        let model = AuthNicknameViewModel(
            provider: AuthNicknameTestProvider(result: .success(refreshedResponse))
        )
        model.selectNickname("따스한 사슴 3492")

        let didRefresh = await model.refreshCandidates()

        #expect(didRefresh)
        #expect(model.selectionToken == "server-selection-2")
        #expect(model.candidates == refreshedResponse.candidates)
        #expect(model.candidates.allSatisfy { !$0.description.isEmpty })
        #expect(model.candidates.map(\.animalEmoji) == ["🪽", "🦦", "🐰"])
        #expect(model.candidates.map(\.colorLabel) == ["남색", "민트", "분홍"])
        #expect(model.refreshCount == 1)
        #expect(model.canRefresh)
        #expect(model.selectedNickname.isEmpty)
        #expect(model.errorMessage == nil)
    }

    @MainActor
    @Test func nicknameRefreshFailurePreservesExistingBatch() async {
        let model = AuthNicknameViewModel(
            provider: AuthNicknameTestProvider(result: .failure(AuthNicknameTestError.unavailable))
        )
        let originalCandidates = model.candidates
        let originalToken = model.selectionToken
        model.selectNickname("따스한 사슴 3492")

        let didRefresh = await model.refreshCandidates()

        #expect(!didRefresh)
        #expect(model.candidates == originalCandidates)
        #expect(model.selectionToken == originalToken)
        #expect(model.selectedNickname == "따스한 사슴 3492")
        #expect(model.refreshCount == 0)
        #expect(model.errorMessage == "새 이름을 불러오지 못했어요. 다시 시도해주세요.")
    }

    @MainActor
    @Test func nicknameRefreshDoesNotAddAClientSideLimit() async {
        // `initialResponse` 는 **후보가 빈** 자리다(NO-MOCK-CANON R1 — 화면이 스켈레톤을 그린다).
        // `refreshCandidates()` 는 후보 3개를 요구하므로 그걸 성공 픽스처로 쓰면 항상 실패한다.
        let model = AuthNicknameViewModel(
            provider: AuthNicknameTestProvider(
                result: .success(
                    AuthNicknameCandidatesResponse(
                        selectionToken: "server-selection-1",
                        candidates: [
                            AuthNicknameCandidate(id: "a", nickname: "포근한 두루미 4186", color: "NAVY"),
                            AuthNicknameCandidate(id: "b", nickname: "느긋한 수달 7351", color: "MINT"),
                            AuthNicknameCandidate(id: "c", nickname: "용감한 토끼 2640", color: "PINK")
                        ]
                    )
                )
            )
        )

        for _ in 0..<6 {
            #expect(await model.refreshCandidates())
        }

        #expect(model.canRefresh)
        #expect(model.refreshCount == 6)
    }

    @MainActor
    @Test func newUserSignupSendsFinalContractAndMovesToProfileImage() async {
        let apiClient = AuthFlowTestAPIClient(loginState: .userInfoRequired)
        let sessionStore = InMemoryAuthSessionStore()
        let model = AuthFlowViewModel(
            dependencies: AuthFlowDependencies(
                apiClient: apiClient,
                identityProvider: AuthIdentityTestProvider(),
                sessionStore: sessionStore,
                fcmTokenProvider: AuthFCMTokenTestProvider(token: "fcm-test")
            )
        )

        #expect(!(await model.authenticate(with: .kakao)))
        #expect(model.stage == .nickname)
        #expect(model.nicknameResponse.selectionToken == "selection-test")

        model.prepareSignup(nickname: "따스한 사슴 3492", selectionToken: "selection-test")
        #expect(model.stage == .basics)
        await model.submitSignup(
            gender: .female,
            birthdate: .april1998,
            travelStyleIds: [1, 3],
            interestedRegionIds: [4, 17],
            agreedTermIds: [1, 2]
        )

        #expect(model.stage == .profileImage)
        #expect(
            apiClient.capturedSignupRequest == AuthSignupRequest(
                idToken: "firebase-id-kakao",
                nicknameSelectionToken: "selection-test",
                nickname: "따스한 사슴 3492",
                gender: "F",
                birthDate: "1998-04-12",
                travelStyleIds: [1, 3],
                interestedRegionIds: [4, 17],
                fcmToken: "fcm-test",
                agreedTermIds: [1, 2]
            )
        )
        #expect(apiClient.capturedSignupProvider == .kakao)
        #expect(sessionStore.tokens == AuthTokens(accessToken: "access-test", refreshToken: "refresh-test"))
    }

    @MainActor
    @Test func existingCompleteUserFinishesLoginWithoutSignup() async {
        let apiClient = AuthFlowTestAPIClient(loginState: .signupComplete)
        let sessionStore = InMemoryAuthSessionStore()
        let fcmProvider = RecordingFCMTokenTestProvider(token: "fresh-fcm-token")
        let model = AuthFlowViewModel(
            dependencies: AuthFlowDependencies(
                apiClient: apiClient,
                identityProvider: AuthIdentityTestProvider(),
                sessionStore: sessionStore,
                fcmTokenProvider: fcmProvider
            )
        )

        #expect(await model.authenticate(with: .apple))
        #expect(apiClient.capturedSignupRequest == nil)
        #expect(apiClient.capturedLoginRequest?.fcmToken == "fresh-fcm-token")
        #expect(fcmProvider.registeredToken == "fresh-fcm-token")
        #expect(sessionStore.tokens?.accessToken == "access-test")
    }

    @MainActor
    @Test func profileRequiredLoginRestoresServerCandidatesAndGenerationCounts() async {
        let apiClient = AuthFlowTestAPIClient(loginState: .profileImageRequired)
        let restoredCandidates = [
            AuthFlowTestAPIClient.profileCandidate,
            AuthFlowTestAPIClient.profileCandidate(id: 12)
        ]
        apiClient.profileResponse = AuthProfileImagesResponse(
            candidates: restoredCandidates,
            generationCount: 2,
            remainingGenerationCount: 1,
            signupState: .profileImageRequired
        )
        let model = AuthFlowViewModel(
            dependencies: AuthFlowDependencies(
                apiClient: apiClient,
                identityProvider: AuthIdentityTestProvider(),
                sessionStore: InMemoryAuthSessionStore(),
                fcmTokenProvider: AuthFCMTokenTestProvider(token: nil)
            )
        )

        #expect(!(await model.authenticateEmail(email: "moyeo@example.com", password: "password")))
        #expect(model.stage == .profileImage)
        #expect(model.profileImages == restoredCandidates)
        #expect(model.remainingProfileGenerations == 1)
    }

    @MainActor
    @Test func generatedProfileCandidateAccumulatesWithoutReplacingRestoredCandidates() async {
        let apiClient = AuthFlowTestAPIClient(loginState: .profileImageRequired)
        let restoredCandidates = [
            AuthFlowTestAPIClient.profileCandidate,
            AuthFlowTestAPIClient.profileCandidate(id: 12)
        ]
        let generatedCandidate = AuthFlowTestAPIClient.profileCandidate(id: 13)
        apiClient.profileResponse = AuthProfileImagesResponse(
            candidates: restoredCandidates,
            generationCount: 2,
            remainingGenerationCount: 1,
            signupState: .profileImageRequired
        )
        apiClient.generationResponse = AuthProfileImageGenerationResponse(
            candidate: generatedCandidate,
            generationCount: 3,
            remainingGenerationCount: 0,
            signupState: .profileImageRequired
        )
        let model = AuthFlowViewModel(
            dependencies: AuthFlowDependencies(
                apiClient: apiClient,
                identityProvider: AuthIdentityTestProvider(),
                sessionStore: InMemoryAuthSessionStore(),
                fcmTokenProvider: AuthFCMTokenTestProvider(token: nil)
            )
        )

        #expect(!(await model.authenticate(with: .google)))

        await model.generateProfileImage()

        #expect(model.profileImages == restoredCandidates + [generatedCandidate])
        #expect(model.remainingProfileGenerations == 0)
    }

    @MainActor
    @Test func selectingProfileCandidateUsesPutResultAndPreservesAllCandidates() async {
        let apiClient = AuthFlowTestAPIClient(loginState: .profileImageRequired)
        let candidates = [
            AuthFlowTestAPIClient.profileCandidate,
            AuthFlowTestAPIClient.profileCandidate(id: 12),
            AuthFlowTestAPIClient.profileCandidate(id: 13)
        ]
        let selectedCandidate = AuthFlowTestAPIClient.profileCandidate(id: 12, selected: true)
        apiClient.profileResponse = AuthProfileImagesResponse(
            candidates: candidates,
            generationCount: 3,
            remainingGenerationCount: 0,
            signupState: .profileImageRequired
        )
        apiClient.selectionResponseCandidate = selectedCandidate
        let model = AuthFlowViewModel(
            dependencies: AuthFlowDependencies(
                apiClient: apiClient,
                identityProvider: AuthIdentityTestProvider(),
                sessionStore: InMemoryAuthSessionStore(),
                fcmTokenProvider: AuthFCMTokenTestProvider(token: nil)
            )
        )

        #expect(!(await model.authenticate(with: .apple)))
        #expect(await model.selectProfileImage(candidates[1]))
        #expect(apiClient.capturedSelectedProfileImageID == 12)
        #expect(model.profileImages.count == 3)
        #expect(model.profileImages.first(where: { $0.id == 12 })?.selected == true)
        #expect(model.profileImages.filter(\.selected).count == 1)
    }

    @MainActor
    @Test func serverSignupStateOverridesTokensPersistedOnThisDevice() async throws {
        let apiClient = AuthFlowTestAPIClient(loginState: .profileImageRequired)
        let sessionStore = InMemoryAuthSessionStore()
        try sessionStore.save(AuthTokens(accessToken: "stale-access", refreshToken: "stale-refresh"))
        let model = AuthFlowViewModel(
            dependencies: AuthFlowDependencies(
                apiClient: apiClient,
                identityProvider: AuthIdentityTestProvider(),
                sessionStore: sessionStore,
                fcmTokenProvider: AuthFCMTokenTestProvider(token: nil)
            )
        )

        #expect(!(await model.authenticate(with: .apple)))
        #expect(model.stage == .profileImage)
        #expect(sessionStore.tokens == AuthTokens(accessToken: "access-test", refreshToken: "refresh-test"))
    }

    @MainActor
    @Test func storedSessionRefreshResumesProfileImageWithExistingCandidates() async throws {
        let apiClient = AuthFlowTestAPIClient(loginState: .profileImageRequired)
        let restoredCandidates = [
            AuthFlowTestAPIClient.profileCandidate,
            AuthFlowTestAPIClient.profileCandidate(id: 12)
        ]
        apiClient.profileResponse = AuthProfileImagesResponse(
            candidates: restoredCandidates,
            generationCount: 2,
            remainingGenerationCount: 1,
            signupState: .profileImageRequired
        )
        let sessionStore = InMemoryAuthSessionStore()
        try sessionStore.save(AuthTokens(accessToken: "stale-access", refreshToken: "stale-refresh"))
        let model = AuthFlowViewModel(
            dependencies: AuthFlowDependencies(
                apiClient: apiClient,
                identityProvider: AuthIdentityTestProvider(),
                sessionStore: sessionStore,
                fcmTokenProvider: AuthFCMTokenTestProvider(token: nil)
            )
        )

        #expect(!(await model.restoreSession()))
        #expect(apiClient.capturedRefreshToken == "stale-refresh")
        #expect(model.stage == .profileImage)
        #expect(model.profileImages == restoredCandidates)
        #expect(sessionStore.tokens == AuthTokens(
            accessToken: "access-refreshed",
            refreshToken: "refresh-refreshed"
        ))
    }

    @MainActor
    @Test func storedCompleteSessionFinishesAuthAfterServerRefresh() async throws {
        let apiClient = AuthFlowTestAPIClient(loginState: .signupComplete)
        let sessionStore = InMemoryAuthSessionStore()
        try sessionStore.save(AuthTokens(accessToken: "stale-access", refreshToken: "stale-refresh"))
        let model = AuthFlowViewModel(
            dependencies: AuthFlowDependencies(
                apiClient: apiClient,
                identityProvider: AuthIdentityTestProvider(),
                sessionStore: sessionStore,
                fcmTokenProvider: AuthFCMTokenTestProvider(token: nil)
            )
        )

        #expect(await model.restoreSession())
        #expect(apiClient.capturedRefreshToken == "stale-refresh")
        #expect(sessionStore.tokens?.accessToken == "access-refreshed")
    }

    @MainActor
    @Test func missingWithdrawnUserClearsStoredSessionDuringLaunchRestore() async throws {
        let apiClient = AuthFlowTestAPIClient(loginState: .signupComplete)
        apiClient.refreshError = AuthClientError.server(statusCode: 404, code: nil, message: "user missing")
        let sessionStore = InMemoryAuthSessionStore()
        try sessionStore.save(AuthTokens(accessToken: "stale-access", refreshToken: "stale-refresh"))
        let model = AuthFlowViewModel(
            dependencies: AuthFlowDependencies(
                apiClient: apiClient,
                identityProvider: AuthIdentityTestProvider(),
                sessionStore: sessionStore,
                fcmTokenProvider: AuthFCMTokenTestProvider(token: nil)
            )
        )

        #expect(!(await model.restoreSession()))
        #expect(model.stage == .onboarding)
        #expect(sessionStore.tokens == nil)
    }

    @MainActor
    @Test func googleUsesBackendProviderAndServerSignupState() async {
        let apiClient = AuthFlowTestAPIClient(loginState: .userInfoRequired)
        let model = AuthFlowViewModel(
            dependencies: AuthFlowDependencies(
                apiClient: apiClient,
                identityProvider: AuthIdentityTestProvider(),
                sessionStore: InMemoryAuthSessionStore(),
                fcmTokenProvider: AuthFCMTokenTestProvider(token: nil)
            )
        )

        #expect(!(await model.authenticate(with: .google)))
        #expect(model.stage == .nickname)
        #expect(apiClient.capturedLoginProvider == .google)
        #expect(apiClient.capturedLoginRequest?.idToken == "firebase-id-google")
    }

    @MainActor
    @Test func emailButtonOnlyOpensCredentialsUntilCredentialsAreSubmitted() async {
        let apiClient = AuthFlowTestAPIClient(loginState: .userInfoRequired)
        let model = AuthFlowViewModel(
            dependencies: AuthFlowDependencies(
                apiClient: apiClient,
                identityProvider: AuthIdentityTestProvider(),
                sessionStore: InMemoryAuthSessionStore(),
                fcmTokenProvider: AuthFCMTokenTestProvider(token: nil)
            )
        )

        #expect(!(await model.authenticate(with: .email)))
        #expect(model.stage == .emailLogin)
        #expect(apiClient.capturedLoginProvider == nil)

        // 로그인/가입을 따로 고르지 않는다 — 먼저 로그인해 보고 계정이 없을 때만 만든다.
        // 여기서는 로그인이 성공하므로 로그인 토큰이 그대로 서버로 간다.
        #expect(!(await model.authenticateEmail(email: "moyeo@example.com", password: "password")))
        #expect(model.stage == .nickname)
        #expect(apiClient.capturedLoginProvider == .email)
        #expect(apiClient.capturedLoginRequest?.idToken == "firebase-id-email-signin")
    }

    /// 계정이 없으면(로그인이 `invalidCredential` 로 실패) 그대로 새 계정을 만든다.
    ///
    /// Email Enumeration Protection 때문에 "계정 없음"과 "비밀번호 틀림"이 같은 코드로 오므로,
    /// 가입 시도가 성공하면 계정이 없었던 것이다.
    @MainActor
    @Test func emailSignInFallsBackToAccountCreationWhenSignInMisses() async {
        let apiClient = AuthFlowTestAPIClient(loginState: .userInfoRequired)
        let model = AuthFlowViewModel(
            dependencies: AuthFlowDependencies(
                apiClient: apiClient,
                identityProvider: AuthIdentitySignInMissTestProvider(),
                sessionStore: InMemoryAuthSessionStore(),
                fcmTokenProvider: AuthFCMTokenTestProvider(token: nil)
            )
        )

        #expect(!(await model.authenticateEmail(email: "moyeo@example.com", password: "password")))
        #expect(apiClient.capturedLoginRequest?.idToken == "firebase-id-email-signup")
    }

    /// 계정은 있고 비밀번호가 틀린 경우 — 가입 시도가 `emailAlreadyInUse` 로 막힌다.
    @MainActor
    @Test func emailWrongPasswordSurfacesPasswordMessage() async {
        let apiClient = AuthFlowTestAPIClient(loginState: .userInfoRequired)
        let model = AuthFlowViewModel(
            dependencies: AuthFlowDependencies(
                apiClient: apiClient,
                identityProvider: AuthIdentityEmailExistsTestProvider(),
                sessionStore: InMemoryAuthSessionStore(),
                fcmTokenProvider: AuthFCMTokenTestProvider(token: nil)
            )
        )

        #expect(!(await model.authenticateEmail(email: "moyeo@example.com", password: "wrong")))
        #expect(model.errorMessage == AuthClientError.wrongEmailPassword.errorDescription)
        #expect(apiClient.capturedLoginRequest == nil)
    }

    @MainActor
    @Test func passwordResetUsesIdentityProviderWithoutCallingBackend() async {
        let apiClient = AuthFlowTestAPIClient(loginState: .signupComplete)
        let identityProvider = AuthIdentityTestProvider()
        let model = AuthFlowViewModel(
            dependencies: AuthFlowDependencies(
                apiClient: apiClient,
                identityProvider: identityProvider,
                sessionStore: InMemoryAuthSessionStore(),
                fcmTokenProvider: AuthFCMTokenTestProvider(token: nil)
            )
        )

        await model.resetPassword(email: "moyeo@example.com")

        #expect(model.passwordResetMessage == "비밀번호 재설정 메일을 보냈어요.")
        #expect(apiClient.capturedLoginProvider == nil)
    }

    @Test func httpClientUsesFinalSignupPathAndPayload() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AuthURLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        AuthURLProtocolStub.handler = { request in
            #expect(request.url?.path == "/api/v1/auth/signup")
            #expect(request.httpMethod == "POST")
            let data = try #require(request.authTestBodyData)
            // `travelStyleIds`·`interestedRegionIds` 가 배열로 추가되면서 `[String: String]` 캐스팅이
            // nil 로 떨어지고 아래 기대값이 **전부** 조용히 실패했다(테스트 밖 스텁이라 이름도 안 붙었다).
            // 그 필드 추가 자체는 결함 수정이었다 — 07 에서 고른 값이 어디로도 안 갔다.
            let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            #expect(payload?["idToken"] as? String == "firebase-id")
            #expect(payload?["nicknameSelectionToken"] as? String == "selection-token")
            #expect(payload?["nickname"] as? String == "따스한 사슴 3492")
            #expect(payload?["gender"] as? String == "F")
            #expect(payload?["birthDate"] as? String == "1998-04-12")
            let body = Data(
                #"{"accessToken":"access","refreshToken":"refresh","signupState":"PROFILE_IMAGE_REQUIRED"}"#.utf8
            )
            return (HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!, body)
        }
        let client = AuthAPIClient(
            configuration: AuthAPIConfiguration(baseURL: URL(string: "https://api.example.com")!),
            session: session
        )

        let response = try await client.signup(
            request: AuthSignupRequest(
                idToken: "firebase-id",
                nicknameSelectionToken: "selection-token",
                nickname: "따스한 사슴 3492",
                gender: "F",
                birthDate: "1998-04-12",
                fcmToken: nil,
                agreedTermIds: [1, 2]
            )
        )

        #expect(response.signupState == .profileImageRequired)
    }

    @Test func httpClientUsesUnifiedLoginPathWithoutProviderInURL() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AuthURLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        AuthURLProtocolStub.handler = { request in
            #expect(request.url?.path == "/api/v1/auth/login")
            #expect(request.httpMethod == "POST")
            let data = try #require(request.authTestBodyData)
            let payload = try JSONSerialization.jsonObject(with: data) as? [String: String]
            #expect(payload?["idToken"] == "firebase-google-id")
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(
                    #"""
                    {
                      "accessToken": "access",
                      "refreshToken": "refresh",
                      "isNewUser": false,
                      "signupState": "SIGNUP_COMPLETE",
                      "providerType": "GOOGLE"
                    }
                    """#.utf8
                )
            )
        }
        let client = AuthAPIClient(
            configuration: AuthAPIConfiguration(baseURL: URL(string: "https://api.example.com")!),
            session: session
        )

        let response = try await client.login(
            request: AuthLoginRequest(idToken: "firebase-google-id", fcmToken: nil)
        )

        #expect(response.providerType == .google)
        #expect(response.signupState == .signupComplete)
    }

    @Test func providerEndpointsUseBearerTokenAndFirebaseIDToken() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AuthURLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        var requestCount = 0
        AuthURLProtocolStub.handler = { request in
            requestCount += 1
            #expect(request.url?.path == "/api/v1/auth/providers")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer service-access")
            if request.httpMethod == "POST" {
                let data = try #require(request.authTestBodyData)
                let payload = try JSONSerialization.jsonObject(with: data) as? [String: String]
                #expect(payload?["idToken"] == "firebase-apple-id")
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(#"{"providers":["KAKAO","APPLE"]}"#.utf8)
                )
            }
            #expect(request.httpMethod == "GET")
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"{"providers":["KAKAO"]}"#.utf8)
            )
        }
        let client = AuthAPIClient(
            configuration: AuthAPIConfiguration(baseURL: URL(string: "https://api.example.com")!),
            session: session
        )

        #expect(try await client.linkedProviders(accessToken: "service-access").providers == [.kakao])
        #expect(
            try await client.linkProvider(
                idToken: "firebase-apple-id",
                fcmToken: nil,
                accessToken: "service-access"
            ).providers == [.kakao, .apple]
        )
        #expect(requestCount == 2)
    }

    @Test func displayProfileReadsCapitalizedNicknameClaimOnlyFromJWTBody() {
        let token = makeAuthTestJWT(nickname: "푸른 고래 2048")

        #expect(AuthDisplayProfile.nickname(fromAccessToken: token) == "푸른 고래 2048")
        #expect(AuthDisplayProfile.nickname(fromAccessToken: "not-a-jwt") == nil)
    }

    @Test func currentUserServiceUsesJWTNicknameAndSelectedServerImage() async throws {
        let apiClient = AuthFlowTestAPIClient(loginState: .signupComplete)
        apiClient.profileResponse = AuthProfileImagesResponse(
            candidates: [
                AuthFlowTestAPIClient.profileCandidate(id: 11),
                AuthFlowTestAPIClient.profileCandidate(id: 12, selected: true)
            ],
            generationCount: 2,
            remainingGenerationCount: 1,
            signupState: .signupComplete
        )
        let sessionStore = InMemoryAuthSessionStore()
        try sessionStore.save(
            AuthTokens(accessToken: makeAuthTestJWT(nickname: "잔잔한 거북이 9032"), refreshToken: "refresh")
        )
        let profileStore = InMemoryAuthDisplayProfileStore()
        let service = AuthCurrentUserService(
            apiClient: apiClient,
            sessionStore: sessionStore,
            profileStore: profileStore
        )

        let profile = try await service.refreshProfile()

        #expect(profile.nickname == "잔잔한 거북이 9032")
        #expect(profile.profileImageURL == URL(string: "https://example.com/profile-12.png"))
        #expect(profileStore.profile == profile)
    }

    @MainActor
    @Test func providerLookupRefreshesExpiredAccessAndPersistsRotatedTokens() async throws {
        let apiClient = AuthFlowTestAPIClient(loginState: .signupComplete)
        apiClient.linkedProviderErrors = [AuthClientError.server(statusCode: 401, code: nil, message: "expired")]
        let sessionStore = InMemoryAuthSessionStore()
        try sessionStore.save(AuthTokens(accessToken: "old-access", refreshToken: "old-refresh"))
        let service = AuthProviderLinkService(
            apiClient: apiClient,
            identityProvider: AuthIdentityTestProvider(),
            sessionStore: sessionStore
        )

        await service.load()

        #expect(apiClient.capturedLinkedProviderAccessTokens == ["old-access", "access-refreshed"])
        #expect(sessionStore.tokens == AuthTokens(
            accessToken: "access-refreshed",
            refreshToken: "refresh-refreshed"
        ))
        #expect(service.providers == [.kakao])
    }

    @MainActor
    @Test func providerLinkCanCreateAndAttachNewEmailIdentity() async throws {
        let apiClient = AuthFlowTestAPIClient(loginState: .signupComplete)
        let sessionStore = InMemoryAuthSessionStore()
        try sessionStore.save(AuthTokens(accessToken: "access", refreshToken: "refresh"))
        let service = AuthProviderLinkService(
            apiClient: apiClient,
            identityProvider: AuthIdentityTestProvider(),
            sessionStore: sessionStore
        )

        await service.linkEmail(email: "new@example.com", password: "password")

        #expect(apiClient.capturedLinkedProviderIDTokens == ["firebase-id-email-signup"])
        #expect(service.providers.contains(.email))
    }

    @Test func httpClientUsesKakaoCustomTokenAndSignupContracts() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AuthURLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        AuthURLProtocolStub.handler = { request in
            let data = try #require(request.authTestBodyData)
            let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            switch request.url?.path {
            case "/api/v1/auth/firebase/kakao/custom-token":
                #expect(payload?["accessToken"] as? String == "kakao-access")
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(#"{"customToken":"firebase-custom"}"#.utf8)
                )
            case "/api/v1/auth/signup":
                #expect(payload?["idToken"] as? String == "firebase-id")
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!,
                    Data(
                        #"{"accessToken":"access","refreshToken":"refresh","signupState":"PROFILE_IMAGE_REQUIRED"}"#.utf8
                    )
                )
            default:
                Issue.record("Unexpected Kakao auth path: \(request.url?.path ?? "nil")")
                throw AuthClientError.invalidResponse
            }
        }
        let client = AuthAPIClient(
            configuration: AuthAPIConfiguration(baseURL: URL(string: "https://api.example.com")!),
            session: session
        )

        #expect(try await client.kakaoFirebaseCustomToken(accessToken: "kakao-access") == "firebase-custom")
        let response = try await client.signup(
            request: AuthSignupRequest(
                idToken: "firebase-id",
                nicknameSelectionToken: "selection-token",
                nickname: "따스한 사슴 3492",
                gender: "F",
                birthDate: "1998-04-12",
                fcmToken: nil,
                agreedTermIds: [1, 2]
            )
        )
        #expect(response.signupState == .profileImageRequired)
    }

    @Test func httpClientRefreshesStoredSessionUsingBackendState() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AuthURLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        AuthURLProtocolStub.handler = { request in
            #expect(request.url?.path == "/api/v1/auth/refresh")
            #expect(request.httpMethod == "POST")
            let data = try #require(request.authTestBodyData)
            let payload = try JSONSerialization.jsonObject(with: data) as? [String: String]
            #expect(payload?["refreshToken"] == "stored-refresh")
            let body = Data(
                #"{"accessToken":"new-access","refreshToken":"new-refresh","signupState":"PROFILE_IMAGE_REQUIRED"}"#.utf8
            )
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let client = AuthAPIClient(
            configuration: AuthAPIConfiguration(baseURL: URL(string: "https://api.example.com")!),
            session: session
        )

        let response = try await client.refreshSession(refreshToken: "stored-refresh")

        #expect(response.tokens == AuthTokens(accessToken: "new-access", refreshToken: "new-refresh"))
        #expect(response.signupState == .profileImageRequired)
    }

    @Test func profileImageGenerationUsesExtendedRequestTimeout() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AuthURLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        AuthURLProtocolStub.handler = { request in
            #expect(request.url?.path == "/api/v1/users/me/profile-images")
            #expect(request.httpMethod == "POST")
            #expect(request.timeoutInterval == 180)
            let body = Data(
                #"""
                {
                  "candidate": {
                    "profileImageId": 1,
                    "profileImageUrl": "https://cdn.example/1.png",
                    "selected": false
                  },
                  "generationCount": 1,
                  "remainingGenerationCount": 2,
                  "signupState": "PROFILE_IMAGE_REQUIRED"
                }
                """#.utf8
            )
            return (HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!, body)
        }
        let client = AuthAPIClient(
            configuration: AuthAPIConfiguration(baseURL: URL(string: "https://api.example.com")!),
            session: session
        )

        let response = try await client.generateProfileImage(accessToken: "access")

        #expect(response.remainingGenerationCount == 2)
    }

    @Test func httpClientWithdrawsCurrentUserWithBearerTokenAndAcceptsNoContent() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AuthURLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        AuthURLProtocolStub.handler = { request in
            #expect(request.url?.path == "/api/v1/users/me")
            #expect(request.httpMethod == "DELETE")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access-to-delete")
            return (
                HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!,
                Data()
            )
        }
        let client = AuthAPIClient(
            configuration: AuthAPIConfiguration(baseURL: URL(string: "https://api.example.com")!),
            session: session
        )

        try await client.withdraw(accessToken: "access-to-delete")
    }

    @MainActor
    @Test func accountWithdrawalRefreshesExpiredAccessTokenThenClearsSession() async throws {
        let apiClient = AuthFlowTestAPIClient(loginState: .signupComplete)
        apiClient.withdrawErrors = [
            AuthClientError.server(statusCode: 401, code: nil, message: "expired")
        ]
        let sessionStore = InMemoryAuthSessionStore()
        try sessionStore.save(AuthTokens(accessToken: "old-access", refreshToken: "old-refresh"))
        let service = AuthAccountService(apiClient: apiClient, sessionStore: sessionStore)

        try await service.withdraw()

        #expect(apiClient.capturedWithdrawAccessTokens == ["old-access", "access-refreshed"])
        #expect(apiClient.capturedRefreshToken == "old-refresh")
        #expect(sessionStore.tokens == nil)
    }

    @MainActor
    @Test func logoutClearsStoredServiceSession() async throws {
        let sessionStore = InMemoryAuthSessionStore()
        let profileStore = InMemoryAuthDisplayProfileStore()
        try sessionStore.save(AuthTokens(accessToken: "access", refreshToken: "refresh"))
        profileStore.save(AuthDisplayProfile(nickname: "서버 닉네임", profileImageURL: nil))
        let service = AuthAccountService(
            apiClient: AuthFlowTestAPIClient(loginState: .signupComplete),
            sessionStore: sessionStore,
            profileStore: profileStore
        )

        try await service.logout()

        #expect(sessionStore.tokens == nil)
        #expect(profileStore.load() == nil)
    }

    @Test func changeLogDirectLaunchKeysResolveDeterministically() {
        let keys = [
            "onb-1", "onb-2", "onb-3", "login", "nickname", "profile-basic", "profile-image", "terms",
            "place-search", "place-detail", "terms-detail", "terms-privacy", "terms-location",
            "terms-marketing", "terms-settings", "create-detail", "create-people", "create-summary",
            "create-summary-custom"
        ]

        for key in keys {
            let state = UITestInitialState(arguments: ["UITEST_SCREEN=\(key)"])
            #expect(state.selectedTab == .home)
            #expect(state.homePath.count == 1)
        }
    }

    @Test func exactCaptureRoutesResolveIndependentSheetAlertAndMeetingStates() {
        let email = UITestInitialState(arguments: ["UITEST_SCREEN=email-auth"])
        #expect(email.homePath.count == 1)

        let application = UITestInitialState(arguments: ["UITEST_SCREEN=apply"])
        #expect(application.homePath.count == 1)

        let chatList = UITestInitialState(arguments: ["UITEST_SCREEN=chat-list"])
        #expect(chatList.selectedTab == .meetings)
        #expect(chatList.meetingsInitialSegment == .ongoing)

        let applied = UITestInitialState(arguments: ["UITEST_SCREEN=chat-list-applied"])
        #expect(applied.selectedTab == .meetings)
        #expect(applied.meetingsInitialSegment == .applied)

        let leave = UITestInitialState(arguments: ["UITEST_SCREEN=leave"])
        #expect(leave.homePath.count == 1)

        // changeLog14 — 20-1a · 20-1b 는 20-1 사이드 메뉴 위에 뜬 시트로 직접 진입한다
        for key in ["member-actions", "member-remove"] {
            let state = UITestInitialState(arguments: ["UITEST_SCREEN=\(key)"])
            #expect(state.selectedTab == .home)
            #expect(state.homePath.count == 1)
        }
    }

    @Test func tourismParserKeepsListAndDetailContractsSeparate() throws {
        let listJSON = #"""
        {"data":{"contents":[{
          "contentId":2299341,"contentTypeId":39,"title":"달기약수터 백숙거리",
          "address":"경상북도 청송군","thumbnailUrl":"https://cdn.example/list.jpg",
          "latitude":"36.4278","longitude":129.0489
        }]}}
        """#
        let list = try TourismAPIResponseParser.places(from: Data(listJSON.utf8))
        #expect(list.count == 1)
        #expect(list[0].type == .restaurant)
        // 목록 응답에는 전화가 없다 — "정보 없음" 같은 값을 지어내지 않고 nil 로 둔다 (17-1b)
        #expect(list[0].phone == nil)
        #expect(list[0].thumbnailURL?.absoluteString == "https://cdn.example/list.jpg")

        let detailJSON = #"""
        {"data":{
          "contentId":"2299341","contentTypeName":"음식점","title":"달기약수터 백숙거리",
          "addr1":"경상북도 청송군","mapY":36.4278,"mapX":129.0489,"zipCode":"37411",
          "tel":"054-873-7777","telName":"관광안내","homepage":"https://example.com",
          "overview":"백숙 거리 소개","images":[{"imageUrl":"https://cdn.example/a.jpg"}],
          "menuImages":["https://cdn.example/menu.jpg"]
        }}
        """#
        let detail = try TourismAPIResponseParser.place(from: Data(detailJSON.utf8))
        #expect(detail.phone == "054-873-7777")
        #expect(detail.summary == "백숙 거리 소개")
        #expect(detail.imageURLs.count == 1)
        #expect(detail.menuImageURLs.count == 1)
        #expect(detail.showsMenuImages)
    }

    @Test func tourismClientRequestsListAndDetailEndpointsWithBearerToken() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AuthURLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        let sessionStore = InMemoryAuthSessionStore()
        try sessionStore.save(AuthTokens(accessToken: "tourism-access", refreshToken: "tourism-refresh"))
        var requestedPaths: [String] = []

        AuthURLProtocolStub.handler = { request in
            #expect(request.httpMethod == "GET")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer tourism-access")
            requestedPaths.append(request.url?.path ?? "")

            let body: String
            if request.url?.path == "/api/v1/tourism-contents" {
                body = #"{"data":{"contents":[{"contentId":"101","title":"첨성대","address":"경상북도 경주시"}]}}"#
            } else {
                body = #"{"data":{"contentId":"101","title":"첨성대","address":"경상북도 경주시"}}"#
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(body.utf8))
        }
        defer { AuthURLProtocolStub.handler = nil }

        let client = TourismAPIClient(
            configuration: AuthAPIConfiguration(baseURL: URL(string: "https://api.example.test")!),
            session: session,
            sessionStore: sessionStore
        )
        _ = try await client.places(keyword: "", contentTypeID: nil)
        _ = try await client.place(id: "101")

        #expect(requestedPaths == [
            "/api/v1/tourism-contents",
            "/api/v1/tourism-contents/101"
        ])
    }

    @Test func changeLogLegalDocumentsKeepRequiredFlagsAndVersions() {
        #expect(LegalDocumentKind.service.content.isRequired)
        #expect(LegalDocumentKind.service.content.version == "v1.2")
        #expect(LegalDocumentKind.privacy.content.isRequired)
        #expect(LegalDocumentKind.privacy.content.version == "v1.4")
        #expect(!LegalDocumentKind.location.content.isRequired)
        #expect(!LegalDocumentKind.marketing.content.isRequired)
        #expect(LegalDocumentKind.allCases.allSatisfy { !$0.content.sections.isEmpty })
    }

    @Test func placeDetailsExposeMenuImagesOnlyForRestaurants() throws {
        let restaurant = TourismPlaceCatalog.places.first(where: { $0.type == .restaurant })
        let nonRestaurants = TourismPlaceCatalog.places.filter { $0.type != .restaurant }

        // 메뉴판 탭은 **서버가 준 메뉴 사진이 있을 때만** 만든다 — 라벨만 보고 만들면 빈 탭이 생긴다.
        // 번들 목록의 식당에는 사진이 없으니 규칙 자체를 검사한다(예전 기대값은 라벨만 봤다).
        #expect(restaurant?.showsMenuImages == false)
        var restaurantWithMenu = try #require(restaurant)
        restaurantWithMenu.menuImageURLs = [URL(string: "https://cdn.example/menu.webp")!]
        #expect(restaurantWithMenu.showsMenuImages == true)
        #expect(nonRestaurants.allSatisfy { !$0.showsMenuImages })
        // 기획 목데이터는 캡처 기준 화면이라 주소·전화가 비어 있으면 안 된다
        #expect(TourismPlaceCatalog.places.allSatisfy { ($0.address?.isEmpty == false) && ($0.phone?.isEmpty == false) })
    }

    @Test func pushTokenRegistrationStateTracksRefreshBoundary() {
        #expect(MoyeoPushTokenRegistrationState.pendingToken(cachedToken: nil, registeredToken: nil) == nil)
        #expect(
            MoyeoPushTokenRegistrationState.pendingToken(cachedToken: "token-a", registeredToken: "token-a") == nil
        )
        #expect(
            MoyeoPushTokenRegistrationState.pendingToken(cachedToken: "token-b", registeredToken: "token-a")
                == "token-b"
        )
    }
}

private struct AuthIdentityTestProvider: AuthIdentityProviding {
    func socialIDToken(for provider: AuthServiceProvider) async throws -> String {
        "firebase-id-\(provider.pathComponent)"
    }

    func signInWithEmail(_ email: String, password: String) async throws -> String {
        "firebase-id-email-signin"
    }

    func createEmailAccount(_ email: String, password: String) async throws -> String {
        "firebase-id-email-signup"
    }

    func sendPasswordReset(to email: String) async throws {}
}

/// 로그인은 실패(계정 없음/비밀번호 오류로 구분 불가)하고 가입은 성공하는 제공자.
private struct AuthIdentitySignInMissTestProvider: AuthIdentityProviding {
    func socialIDToken(for provider: AuthServiceProvider) async throws -> String {
        "firebase-id-\(provider.pathComponent)"
    }

    func signInWithEmail(_ email: String, password: String) async throws -> String {
        throw NSError(domain: "FIRAuthErrorDomain", code: 17004)
    }

    func createEmailAccount(_ email: String, password: String) async throws -> String {
        "firebase-id-email-signup"
    }

    func sendPasswordReset(to email: String) async throws {}
}

/// 로그인도 실패하고 가입도 `emailAlreadyInUse` 로 막히는 제공자 — 비밀번호가 틀린 경우다.
private struct AuthIdentityEmailExistsTestProvider: AuthIdentityProviding {
    func socialIDToken(for provider: AuthServiceProvider) async throws -> String {
        "firebase-id-\(provider.pathComponent)"
    }

    func signInWithEmail(_ email: String, password: String) async throws -> String {
        throw NSError(domain: "FIRAuthErrorDomain", code: 17004)
    }

    func createEmailAccount(_ email: String, password: String) async throws -> String {
        throw NSError(domain: "FIRAuthErrorDomain", code: 17007)
    }

    func sendPasswordReset(to email: String) async throws {}
}

private struct AuthFCMTokenTestProvider: AuthFCMTokenProviding {
    let token: String?

    func currentToken() async -> String? { token }
}

private final class RecordingFCMTokenTestProvider: AuthFCMTokenProviding {
    let token: String?
    private(set) var registeredToken: String?

    init(token: String?) {
        self.token = token
    }

    func currentToken() async -> String? { token }

    func markRegisteredWithBackend(_ token: String?) {
        registeredToken = token
    }
}

private final class AuthFlowTestAPIClient: AuthAPIClientProtocol {
    static let profileCandidate = AuthProfileImageCandidate(
        profileImageId: 11,
        profileImageUrl: URL(string: "https://example.com/profile.png")!,
        selected: false
    )

    static func profileCandidate(id: Int64, selected: Bool = false) -> AuthProfileImageCandidate {
        AuthProfileImageCandidate(
            profileImageId: id,
            profileImageUrl: URL(string: "https://example.com/profile-\(id).png")!,
            selected: selected
        )
    }

    let loginState: AuthSignupState
    var capturedSignupProvider: AuthServiceProvider?
    var capturedSignupRequest: AuthSignupRequest?
    var capturedLoginProvider: AuthServiceProvider?
    var capturedLoginRequest: AuthLoginRequest?
    var capturedRefreshToken: String?
    var capturedSelectedProfileImageID: Int64?
    var capturedWithdrawAccessTokens: [String] = []
    var capturedLinkedProviderAccessTokens: [String] = []
    var capturedLinkedProviderIDTokens: [String] = []
    var linkedProviderErrors: [Error] = []
    var withdrawErrors: [Error] = []
    var refreshError: Error?
    var selectionResponseCandidate = profileCandidate
    var profileResponse = AuthProfileImagesResponse(
        candidates: [],
        generationCount: 0,
        remainingGenerationCount: 3,
        signupState: .profileImageRequired
    )
    var generationResponse = AuthProfileImageGenerationResponse(
        candidate: profileCandidate,
        generationCount: 1,
        remainingGenerationCount: 2,
        signupState: .profileImageRequired
    )

    init(loginState: AuthSignupState) {
        self.loginState = loginState
    }

    func login(request: AuthLoginRequest) async throws -> AuthLoginResponse {
        let provider = provider(from: request.idToken)
        capturedLoginProvider = provider
        capturedLoginRequest = request
        let includesTokens = loginState != .userInfoRequired
        return AuthLoginResponse(
            accessToken: includesTokens ? "access-test" : nil,
            refreshToken: includesTokens ? "refresh-test" : nil,
            isNewUser: loginState == .userInfoRequired,
            signupState: loginState,
            providerType: provider
        )
    }

    func signup(request: AuthSignupRequest) async throws -> AuthSignupResponse {
        capturedSignupProvider = provider(from: request.idToken)
        capturedSignupRequest = request
        return AuthSignupResponse(
            accessToken: "access-test",
            refreshToken: "refresh-test",
            signupState: .profileImageRequired
        )
    }

    func kakaoFirebaseCustomToken(accessToken: String) async throws -> String {
        "kakao-custom-token"
    }

    func refreshSession(refreshToken: String) async throws -> AuthSignupResponse {
        capturedRefreshToken = refreshToken
        if let refreshError { throw refreshError }
        return AuthSignupResponse(
            accessToken: "access-refreshed",
            refreshToken: "refresh-refreshed",
            signupState: loginState
        )
    }

    func linkedProviders(accessToken: String) async throws -> AuthLinkedProvidersResponse {
        capturedLinkedProviderAccessTokens.append(accessToken)
        if !linkedProviderErrors.isEmpty {
            throw linkedProviderErrors.removeFirst()
        }
        return AuthLinkedProvidersResponse(providers: [.kakao])
    }

    func linkProvider(
        idToken: String,
        fcmToken: String?,
        accessToken: String
    ) async throws -> AuthLinkedProvidersResponse {
        capturedLinkedProviderIDTokens.append(idToken)
        return AuthLinkedProvidersResponse(providers: [.kakao, provider(from: idToken)])
    }

    func withdraw(accessToken: String) async throws {
        capturedWithdrawAccessTokens.append(accessToken)
        if !withdrawErrors.isEmpty {
            throw withdrawErrors.removeFirst()
        }
    }

    func fetchCandidates() async throws -> AuthNicknameCandidatesResponse {
        AuthNicknameCandidatesResponse(
            selectionToken: "selection-test",
            candidates: AuthNicknameViewModel.initialResponse.candidates
        )
    }

    func profileImages(accessToken: String) async throws -> AuthProfileImagesResponse {
        profileResponse
    }

    func generateProfileImage(accessToken: String) async throws -> AuthProfileImageGenerationResponse {
        generationResponse
    }

    func selectProfileImage(
        id: Int64,
        accessToken: String
    ) async throws -> AuthProfileImageSelectionResponse {
        capturedSelectedProfileImageID = id
        return AuthProfileImageSelectionResponse(
            selectedImage: selectionResponseCandidate,
            signupState: .signupComplete
        )
    }

    private func provider(from idToken: String) -> AuthServiceProvider {
        AuthServiceProvider.allCases.first { idToken.contains($0.pathComponent) } ?? .kakao
    }
}

private func makeAuthTestJWT(nickname: String) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: ["userId": 42, "nickName": nickname]) else {
        return ""
    }
    let payload = data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
    return "header.\(payload).signature"
}

private final class AuthURLProtocolStub: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override static func canInit(with request: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw AuthClientError.invalidResponse }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension URLRequest {
    var authTestBodyData: Data? {
        if let httpBody {
            return httpBody
        }
        guard let httpBodyStream else { return nil }
        httpBodyStream.open()
        defer { httpBodyStream.close() }

        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1_024)
        defer { buffer.deallocate() }
        while httpBodyStream.hasBytesAvailable {
            let count = httpBodyStream.read(buffer, maxLength: 1_024)
            guard count >= 0 else { return nil }
            if count == 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

private struct AuthNicknameTestProvider: AuthNicknameCandidateProviding {
    let result: Result<AuthNicknameCandidatesResponse, Error>

    func fetchCandidates() async throws -> AuthNicknameCandidatesResponse {
        try result.get()
    }
}

private enum AuthNicknameTestError: Error {
    case unavailable
}

private struct AssetCatalogContents: Decodable {
    let images: [AssetCatalogImage]
}

private struct AssetCatalogImage: Decodable {
    let filename: String?
    let appearances: [AssetCatalogAppearance]?
}

private struct AssetCatalogAppearance: Decodable, Equatable {
    let appearance: String
    let value: String

    static let darkLuminosity = AssetCatalogAppearance(
        appearance: "luminosity",
        value: "dark"
    )
}

/// 이메일로 시작하기 입력 규칙 (화면에서 분리한 정책)
///
/// 로그인/가입을 따로 고르지 않으므로 "비밀번호 확인" 입력이 없다 —
/// 로그인일 수도 있는 입력에 확인란을 요구할 수 없다.
@Suite
struct EmailCredentialsPolicyTests {
    @Test func emailCredentialsPolicyRequiresEmailAndMinimumPassword() {
        #expect(EmailCredentialsPolicy.canSubmit(email: "moyeo@example.com", password: "password"))
        // 이메일 형식
        #expect(!EmailCredentialsPolicy.canSubmit(email: "moyeo", password: "password"))
        // 최소 길이 6자
        #expect(!EmailCredentialsPolicy.canSubmit(email: "moyeo@example.com", password: "12345"))
        #expect(EmailCredentialsPolicy.canSubmit(email: "moyeo@example.com", password: "123456"))
    }
}
