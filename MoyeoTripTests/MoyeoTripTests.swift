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
    @Test func mockDataRelationshipsAreCoherent() {
        #expect(Set(MockData.courses.map(\.id)).count == MockData.courses.count)
        #expect(Set(MockData.trips.map(\.id)).count == MockData.trips.count)
        #expect(MockData.trips.allSatisfy { $0.joined <= $0.capacity })
        #expect(MockData.trips.allSatisfy { $0.minimumParticipants == 3 })
        #expect(MockData.feedPosts.allSatisfy { !$0.route.isEmpty })
        #expect(MockData.participants.allSatisfy { participant in
            participant.name.range(of: #"^[가-힣]+ [가-힣]+ [0-9]{4}$"#, options: .regularExpression) != nil
        })

        let tripIDs = Set(MockData.trips.map(\.id))
        let linkedTripIDs = MockData.spots.compactMap(\.linkedTripID)
        #expect(linkedTripIDs.allSatisfy { tripIDs.contains($0) })
        #expect(MockData.chatThreads.allSatisfy { !$0.messages.isEmpty })
        #expect(MockData.chatThreads.filter(\.isReadOnly).allSatisfy { thread in
            thread.archiveNotice?.contains("14일") == true
                && thread.archiveNotice?.contains("친구 도감") == true
                && thread.closureReason != nil
        })
        #expect(MockData.chatThread(forTripID: "trip-gyeongju-night")?.id == "chat-gyeongju-night")
        #expect(MockData.trips.allSatisfy { MockData.chatThread(forTripID: $0.id) != nil })
        #expect(MockData.courses.allSatisfy { MockData.trip(forCourseID: $0.id) != nil })
        #expect(MockData.course(forSpotID: "spot-ulleung")?.id == "course-ulleung-island")
        #expect(MockData.trip(forCourseID: "unknown-course") == nil)
    }

    @Test func visibleTripCountsStayAlignedWithPlanningData() {
        let hahoe = MockData.trip(for: "trip-andong-hahoe")
        let dosan = MockData.trip(for: "trip-andong-dosan")
        let hahoeThread = MockData.chatThread(forTripID: "trip-andong-hahoe")
        let dosanThread = MockData.chatThread(forTripID: "trip-andong-dosan")

        #expect(hahoe.map { "\($0.joined)/\($0.capacity)명" } == "3/6명")
        #expect(hahoeThread?.statusSummary.hasPrefix("3/6명") == true)
        #expect(dosan.map { "\($0.joined)/\($0.capacity)명" } == "2/4명")
        #expect(dosanThread?.statusSummary.hasPrefix("2/4명") == true)
        #expect(dosan?.status == .open)
        #expect(dosanThread?.statusSummary.contains("모집중") == true)
    }

    @Test func recruitmentSeatPolicyReflectsCapacity() {
        let openTrip = MockData.trips[0]
        // 자리 1개 남은 모집: 영주 부석사 눈꽃 산책(4/5명).
        // 경주 단풍·야경은 기준 목데이터에서 4/8명(모집중)으로 바뀌었다.
        let nearlyFullTrip = MockData.trip(for: "trip-yeongju-buseoksa")!
        let fullTrip = TripRecruitment(
            id: "full-trip",
            courseID: "course-test-full",
            title: "가득 찬 테스트 모임",
            region: "경주",
            coverMascot: "🐰",
            hostName: "테스터",
            hostAvatar: "🐰",
            schedule: "오늘",
            meetupPoint: "경주역",
            price: "무료",
            capacity: 4,
            joined: 4,
            minimumParticipants: 3,
            status: .confirmed,
            summary: "정원 계산 검증",
            vibe: "테스트",
            tags: [],
            route: [],
            participants: []
        )

        #expect(openTrip.remainingSeats == 3)
        #expect(openTrip.seatAvailability == .open(remainingSeats: 3))
        #expect(openTrip.needsMoreParticipants == 1)
        #expect(!openTrip.hasMetMinimumParticipants)
        #expect(nearlyFullTrip.hasMetMinimumParticipants)
        #expect(nearlyFullTrip.seatAvailability == .almostFull(remainingSeats: 1))
        #expect(fullTrip.seatAvailability == .full)
        #expect(fullTrip.progress == 1)
        #expect(!fullTrip.canJoin)
    }

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
        #expect(heavyRain.imageAsset.lightFileName == "weather-heavy-rain-woljeonggyo.png")
        #expect(heavyRain.imageAsset.darkFileName == "weather-heavy-rain-woljeonggyo-night.png")
        #expect(heavyRain.copy.contains("실내형 코스"))
        #expect(rain.state == .caution)
        #expect(rain.badge == "주의")
        #expect(rain.place == "안동 하회마을")
        #expect(rain.imageAssetName == "weather_rain_hahoe")
        #expect(dust.state == .blocked)
        #expect(dust.badge == "대체 추천")
        #expect(dust.imageAssetName == "weather_dust_donggung_wolji")
        #expect(MockData.currentWeatherCondition == .sunny)
        #expect(
            WeatherCoursePolicy.recommendedCourses(for: .sunny, courses: MockData.courses).prefix(3).map(\.id)
                == ["course-cheongsong-juwangsan", "course-andong-hahoe", "course-gyeongju-history"]
        )
        #expect(
            WeatherCoursePolicy.recommendedCourses(for: .heavyRain, courses: MockData.courses).first?.id
                == "course-gyeongju-history"
        )
        #expect(
            WeatherCoursePolicy.recommendedCourses(for: .wind, courses: MockData.courses).first?.id
                == "course-andong-hahoe"
        )
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

    @Test func courseStatusSeparatesWalkingLoad() {
        let balancedCourse = MockData.courses.first { $0.id == "course-cheongsong-juwangsan" }
        let activeCourse = MockData.courses.first { $0.id == "course-ulleung-island" }

        #expect(balancedCourse?.status == .balanced)
        #expect(balancedCourse?.isBeginnerFriendly == true)
        #expect(activeCourse?.status == .active)
        #expect(activeCourse?.isBeginnerFriendly == false)
    }

    @Test func visibilityDefaultsMatchPlanningRules() {
        #expect(FeedVisibility.friendsOnly.rawValue == "친구만")
        #expect(DogamVisibility.friendsOnly.rawValue == "친구에게만")
        #expect(MockData.feedPosts.first?.visibility == .friendsOnly)
        #expect(MockData.dogamFriends.first?.nickname.hasSuffix("3492") == true)
    }

    @Test func hostRecruitmentStatePropagatesToTripAndChatModels() {
        let trip = MockData.trips[0]
        let applicant = Participant(id: "applicant-deer", name: "따스한 사슴 3492", avatar: "🦌")
        let approvedTrip = trip.withHostApprovedParticipant(applicant)

        #expect(approvedTrip.joined == trip.joined + 1)
        #expect(approvedTrip.status == .confirmed)
        #expect(approvedTrip.participants.contains(applicant))
        #expect(approvedTrip.chatStatusSummary == "3/5명 · 확정")
        #expect(approvedTrip.chatStatusDetail == "출발 확정 · 신청 대기 0명")

        let closedTrip = approvedTrip.withRecruitmentClosed(true)

        #expect(closedTrip.status == .cancelled)
        #expect(!closedTrip.canJoin)
        #expect(closedTrip.applicationActionTitle == "모집 종료")
        #expect(closedTrip.chatStatusSummary == "3/5명 · 모집 취소")
        #expect(closedTrip.chatStatusDetail.contains("새 신청을 받지 않아요"))
        #expect(closedTrip.withAppliedCurrentUser(MockData.profile) == closedTrip)

        let reopenedTrip = closedTrip.withRecruitmentClosed(false)

        #expect(reopenedTrip.status == .confirmed)
        #expect(reopenedTrip.chatStatusSummary == "3/5명 · 확정")

        let thread = MockData.chatThreads[0].withTripStatus(approvedTrip)
        let noticedThread = thread.withSystemNotice("따스한 사슴 3492님이 참여 확정됐어요.")

        #expect(noticedThread.statusSummary == "3/5명 · 확정")
        #expect(noticedThread.lastMessage.contains("참여 확정"))
        #expect(noticedThread.messages.count == thread.messages.count + 1)
        #expect(noticedThread.messages.last?.senderName == "모여트립")
    }

    @Test func tripDetailScheduleTextFollowsRecruitmentSchedule() {
        let dateTexts = MockData.trips.map(\.detailDateText)
        let timeTexts = MockData.trips.map(\.detailTimeText)

        #expect(dateTexts == [
            "2026.05.25 (토)",
            "2026.06.09 (화)",
            "2026.06.05 (금)",
            "2026.06.15 (월)",
            "2026.07.12 (일)",
            "2026.10.31 (토)",
            "2026.12.14 (월)",
            "2026.07.07 (화)"
        ])
        #expect(timeTexts == ["08:00", "10:00", "14:00", "09:30", "09:00", "08:30", "10:00", "10:30"])
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
            lightFileName: "splash-generated.png",
            darkFileName: "splash-generated-night.png"
        )
    }

    private var expectedWeatherAssets: [GeneratedImageAsset] {
        [
            GeneratedImageAsset(
                catalogName: "weather_sunny_cheomseongdae",
                lightFileName: "weather-sunny-cheomseongdae.png",
                darkFileName: "weather-sunny-cheomseongdae-night.png"
            ),
            GeneratedImageAsset(
                catalogName: "weather_cloudy_bulguksa",
                lightFileName: "weather-cloudy-bulguksa.png",
                darkFileName: "weather-cloudy-bulguksa-night.png"
            ),
            GeneratedImageAsset(
                catalogName: "weather_rain_hahoe",
                lightFileName: "weather-rain-hahoe.png",
                darkFileName: "weather-rain-hahoe-night.png"
            ),
            GeneratedImageAsset(
                catalogName: "weather_snow_buseoksa",
                lightFileName: "weather-snow-buseoksa.png",
                darkFileName: "weather-snow-buseoksa-night.png"
            ),
            GeneratedImageAsset(
                catalogName: "weather_fog_seokguram",
                lightFileName: "weather-fog-seokguram.png",
                darkFileName: "weather-fog-seokguram-night.png"
            ),
            GeneratedImageAsset(
                catalogName: "weather_wind_homigot",
                lightFileName: "weather-wind-homigot.png",
                darkFileName: "weather-wind-homigot-night.png"
            ),
            GeneratedImageAsset(
                catalogName: "weather_heavy_rain_woljeonggyo",
                lightFileName: "weather-heavy-rain-woljeonggyo.png",
                darkFileName: "weather-heavy-rain-woljeonggyo-night.png"
            ),
            GeneratedImageAsset(
                catalogName: "weather_heatwave_dosan",
                lightFileName: "weather-heatwave-dosan.png",
                darkFileName: "weather-heatwave-dosan-night.png"
            ),
            GeneratedImageAsset(
                catalogName: "weather_dust_donggung_wolji",
                lightFileName: "weather-dust-donggung-wolji.png",
                darkFileName: "weather-dust-donggung-wolji-night.png"
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
        let model = AuthNicknameViewModel(
            provider: AuthNicknameTestProvider(result: .success(AuthNicknameViewModel.initialResponse))
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
        await model.submitSignup(gender: .female, birthdate: .april1998)

        #expect(model.stage == .profileImage)
        #expect(
            apiClient.capturedSignupRequest == AuthSignupRequest(
                idToken: "firebase-id-kakao",
                nicknameSelectionToken: "selection-test",
                nickname: "따스한 사슴 3492",
                gender: "F",
                birthDate: "1998-04-12",
                fcmToken: "fcm-test"
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

        #expect(!(await model.authenticateEmail(email: "moyeo@example.com", password: "password", mode: .signIn)))
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
        apiClient.refreshError = AuthClientError.server(statusCode: 404, message: "user missing")
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

        #expect(!(await model.authenticateEmail(
            email: "moyeo@example.com",
            password: "password",
            mode: .createAccount
        )))
        #expect(model.stage == .nickname)
        #expect(apiClient.capturedLoginProvider == .email)
        #expect(apiClient.capturedLoginRequest?.idToken == "firebase-id-email-signup")
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
            let payload = try JSONSerialization.jsonObject(with: data) as? [String: String]
            #expect(payload?["idToken"] == "firebase-id")
            #expect(payload?["nicknameSelectionToken"] == "selection-token")
            #expect(payload?["nickname"] == "따스한 사슴 3492")
            #expect(payload?["gender"] == "F")
            #expect(payload?["birthDate"] == "1998-04-12")
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
                fcmToken: nil
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
        apiClient.linkedProviderErrors = [AuthClientError.server(statusCode: 401, message: "expired")]
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
                fcmToken: nil
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
            AuthClientError.server(statusCode: 401, message: "expired")
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

    @Test func androidStyleMockIdentifiersResolveToIOSRecords() {
        let courseAliases = [
            ("cheongsong-juwangsan", "course-cheongsong-juwangsan"),
            ("andong-hahoe", "course-andong-hahoe"),
            ("ulleung-island", "course-ulleung-island"),
            ("gyeongju-healing", "course-gyeongju-history"),
            ("course-gyeongju-healing", "course-gyeongju-history"),
            ("pohang-sea", "course-pohang-drive"),
            ("course-pohang-sea", "course-pohang-drive"),
            ("mungyeong-saejae", "course-mungyeong-saejae"),
            ("yeongju-buseoksa", "course-yeongju-buseoksa"),
            ("andong-dosan", "course-andong-dosan")
        ]

        for (alias, iosID) in courseAliases {
            #expect(MockData.course(for: alias)?.id == iosID)
        }

        #expect(MockData.trip(forCourseID: "gyeongju-healing")?.id == "trip-gyeongju-night")
        #expect(MockData.trip(forCourseID: "pohang-sea")?.id == "trip-pohang-drive")
        #expect(MockData.trip(for: "gyeongju-healing")?.id == "trip-gyeongju-night")
        #expect(MockData.trip(for: "course-pohang-sea")?.id == "trip-pohang-drive")
        #expect(MockData.trip(for: "trip-gyeongju-history")?.id == "trip-gyeongju-night")

        for number in 1...7 {
            #expect(MockData.feedPost(for: "feed-\(number)")?.id == String(format: "feed-%02d", number))
        }

        let chatAliases = [
            ("chat-gyeongju-fall", "chat-gyeongju-night"),
            ("chat-juwangsan", "chat-cheongsong-juwangsan"),
            ("chat-andong-hanok", "chat-andong-hahoe")
        ]

        for (alias, iosID) in chatAliases {
            #expect(MockData.chatThread(for: alias)?.id == iosID)
        }

        #expect(MockData.chatThread(forTripID: "gyeongju-healing")?.id == "chat-gyeongju-night")
        #expect(MockData.chatThread(forTripID: "pohang-sea")?.id == "chat-pohang-drive")
        #expect(UITestInitialState(arguments: ["UITEST_SCREEN=feed-detail:feed-1"]).feedPostID == "feed-01")
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
        #expect(list[0].phone == "정보 없음")
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
        _ = try await client.places()
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

    @Test func placeDetailsExposeMenuImagesOnlyForRestaurants() {
        let restaurant = TourismPlaceCatalog.places.first(where: { $0.type == .restaurant })
        let nonRestaurants = TourismPlaceCatalog.places.filter { $0.type != .restaurant }

        #expect(restaurant?.showsMenuImages == true)
        #expect(nonRestaurants.allSatisfy { !$0.showsMenuImages })
        #expect(TourismPlaceCatalog.places.allSatisfy { !$0.address.isEmpty && !$0.phone.isEmpty })
    }

    @Test func recruitmentDataSeparatesRecruitmentAndCourseConditions() {
        let trip = MockData.trips[0]
        let thread = MockData.chatThread(forTripID: trip.id)

        #expect(trip.title != MockData.course(for: trip.courseID)?.title)
        #expect((20...100).contains(trip.minimumAge))
        #expect((20...100).contains(trip.maximumAge))
        #expect(thread?.tripTitle == trip.title)
        #expect(thread?.courseName == MockData.course(for: trip.courseID)?.title)
        #expect(thread?.ageRange == trip.ageRangeText)
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

/// 이메일 로그인·가입 입력 규칙 (화면에서 분리한 정책)
@Suite
struct EmailCredentialsPolicyTests {
    @Test func emailCredentialsPolicyBlocksMismatchedSignUp() {
        // 가입 모드에서는 비밀번호와 확인이 같아야 제출할 수 있다
        #expect(!EmailCredentialsPolicy.canSubmit(
            email: "moyeo@example.com", password: "password", passwordConfirmation: "different", isRegistration: true))
        #expect(EmailCredentialsPolicy.canSubmit(
            email: "moyeo@example.com", password: "password", passwordConfirmation: "password", isRegistration: true))
        // 로그인 모드에서는 확인 칸을 보지 않는다
        #expect(EmailCredentialsPolicy.canSubmit(
            email: "moyeo@example.com", password: "password", passwordConfirmation: "", isRegistration: false))
        // 이메일 형식과 최소 길이
        #expect(!EmailCredentialsPolicy.canSubmit(
            email: "moyeo", password: "password", passwordConfirmation: "password", isRegistration: true))
        #expect(!EmailCredentialsPolicy.canSubmit(
            email: "moyeo@example.com", password: "12345", passwordConfirmation: "12345", isRegistration: true))
        // 경고는 확인 칸에 입력이 있고 값이 다를 때만 보인다
        #expect(!EmailCredentialsPolicy.showsPasswordMismatch(password: "password", passwordConfirmation: ""))
        #expect(EmailCredentialsPolicy.showsPasswordMismatch(password: "password", passwordConfirmation: "diff"))
        #expect(!EmailCredentialsPolicy.showsPasswordMismatch(password: "password", passwordConfirmation: "password"))
    }
}
