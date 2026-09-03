import Foundation
@testable import MoyeoTrip
import SwiftUI
import Testing

@Suite("25 프로필 카드 기울기·뒤집기 (changeLog18)")
struct ProfileCardRotationTests {
    @Test func neutralRotationIsFlat() {
        // 포인터가 없는 상태(최초 진입 · 캡처)는 기울기 0 이라 캡처가 결정적이다.
        #expect(ProfileCardRotation.neutral.degreesX == 0)
        #expect(ProfileCardRotation.neutral.degreesY == 0)
        #expect(ProfileCardRotation.neutral.scale == 1)
    }

    @Test func centerTouchKeepsTheCardFlatButLifted() {
        let rotation = ProfileCardRotation.following(.center)
        #expect(rotation.degreesX == 0)
        #expect(rotation.degreesY == 0)
        #expect(rotation.scale == ProfileCardRotation.liftedScale)
    }

    @Test func cornersStayWithinTenDegrees() {
        // 각도를 10°보다 키우면 카드 안 글씨가 읽히지 않는다 (changeLog18 §2-3).
        let corners = [
            UnitPoint(x: 0, y: 0), UnitPoint(x: 1, y: 0),
            UnitPoint(x: 0, y: 1), UnitPoint(x: 1, y: 1)
        ]
        for corner in corners {
            let rotation = ProfileCardRotation.following(corner)
            #expect(abs(rotation.degreesX) <= ProfileCardRotation.maximumDegrees)
            #expect(abs(rotation.degreesY) <= ProfileCardRotation.maximumDegrees)
        }
    }

    @Test func rotationFollowsThePointerLikeTheScreenPlan() {
        // 화면기획과 같은 식: rotateX = (0.5 - y) · 20, rotateY = (x - 0.5) · 20
        let topLeft = ProfileCardRotation.following(UnitPoint(x: 0, y: 0))
        #expect(topLeft.degreesX == 10)
        #expect(topLeft.degreesY == -10)

        let bottomRight = ProfileCardRotation.following(UnitPoint(x: 1, y: 1))
        #expect(bottomRight.degreesX == -10)
        #expect(bottomRight.degreesY == 10)
    }

    @Test func touchOutsideTheCardIsClampedToTheEdge() {
        let size = CGSize(width: 318, height: 500)
        let beyond = ProfileCardRotation.unitPoint(for: CGPoint(x: 900, y: -240), in: size)
        #expect(beyond == UnitPoint(x: 1, y: 0))

        let inside = ProfileCardRotation.unitPoint(for: CGPoint(x: 159, y: 250), in: size)
        #expect(inside == UnitPoint(x: 0.5, y: 0.5))
    }

    @Test func zeroSizedCardFallsBackToTheCenter() {
        #expect(ProfileCardRotation.unitPoint(for: CGPoint(x: 12, y: 12), in: .zero) == .center)
    }

    @Test func onlyHorizontalSwipesFlipTheCard() {
        // 가로 이동이 세로보다 크고 40pt 이상일 때만 뒤집는다 — 세로 스크롤과 충돌하지 않게.
        #expect(ProfileCardMetrics.isFlipSwipe(CGSize(width: 60, height: 10)))
        #expect(ProfileCardMetrics.isFlipSwipe(CGSize(width: -60, height: 10)))
        // 가로가 40pt 를 못 넘으면 뒤집지 않는다
        #expect(!ProfileCardMetrics.isFlipSwipe(CGSize(width: 39, height: 2)))
        // 세로가 더 크면 스크롤이다
        #expect(!ProfileCardMetrics.isFlipSwipe(CGSize(width: 60, height: 90)))
        // 탭(이동 없음)은 뒤집지 않는다
        #expect(!ProfileCardMetrics.isFlipSwipe(.zero))
    }

    @Test func holoStaysVisibleWhenTheCardIsNotTouched() {
        // 만지지 않아도 카드는 항상 홀로그램이다 — 손을 대면 조금 더 강해진다 (changeLog18 §2-3-1).
        // 한때 정지 상태에서 0.18 까지 잦아들게 했는데, 라이트 테마에서 광택이 아예 보이지 않았다.
        // 기획 기준값은 shine 0.62(정지) / 0.9(조작 중)에 그림 위에 얹는 0.65 를 곱한 값이다.
        #expect(abs(ProfileCardHolo.idleOpacity - 0.62 * 0.65) < 0.001)
        #expect(abs(ProfileCardHolo.liftedOpacity - 0.9 * 0.65) < 0.001)
        #expect(ProfileCardHolo.idleOpacity < ProfileCardHolo.liftedOpacity)
        // 정지 상태에서도 눈에 보여야 한다 — 0 에 가까우면 "항상 보인다"가 아니다.
        #expect(ProfileCardHolo.idleOpacity > 0.3)
    }

    @Test func gradientAngleMatchesTheCssConvention() {
        // CSS 는 0deg 가 위쪽이고 시계 방향으로 커진다.
        let up = ProfileCardMetrics.gradientPoints(cssDegrees: 0)
        #expect(abs(up.start.y - 1) < 0.0001)
        #expect(abs(up.end.y) < 0.0001)

        let right = ProfileCardMetrics.gradientPoints(cssDegrees: 90)
        #expect(abs(right.start.x) < 0.0001)
        #expect(abs(right.end.x - 1) < 0.0001)
    }
}

@Suite("유저 색상 팔레트 (changeLog18 §2-5)")
struct MoyeoUserColorTests {
    @Test func everyServerColorHasAHex() {
        #expect(MoyeoUserColor.allCases.count == 10)
        for color in MoyeoUserColor.allCases {
            #expect(color.hex.count == 7)
            #expect(color.hex.hasPrefix("#"))
        }
    }

    @Test func knownColorsResolveToTheirHex() {
        #expect(MoyeoUserColor.hex(for: "ORANGE") == "#E8853A")
        #expect(MoyeoUserColor.hex(for: "SKY_BLUE") == "#3FA9D6")
        #expect(MoyeoUserColor.hex(for: "MINT") == "#2FB79A")
    }

    @Test func unknownOrMissingColorFallsBackToBrandGreen() {
        #expect(MoyeoUserColor.hex(for: nil) == MoyeoUserColor.fallbackHex)
        #expect(MoyeoUserColor.hex(for: "") == MoyeoUserColor.fallbackHex)
        #expect(MoyeoUserColor.hex(for: "TEAL") == MoyeoUserColor.fallbackHex)
        #expect(MoyeoUserColor.fallbackHex == MoyeoUserColor.green.hex)
    }

    @Test func lowercaseServerValuesStillResolve() {
        #expect(MoyeoUserColor.hex(for: "orange") == MoyeoUserColor.orange.hex)
    }

    @Test func differentUsersGetDifferentPalettes() {
        // 받은 평가의 강조선은 남긴 사람의 색이다 — 카드 주인 색과 같으면 구분이 안 된다.
        let orange = MoyeoUserCardPalette(nicknameColor: "ORANGE")
        let mint = MoyeoUserCardPalette(nicknameColor: "MINT")
        #expect(orange.baseHex != mint.baseHex)
        #expect(orange != mint)
    }

    @Test func unknownColorsShareTheFallbackPalette() {
        // 색을 모르면 브랜드 그린 하나로 모인다
        #expect(MoyeoUserCardPalette(nicknameColor: nil) == MoyeoUserCardPalette(nicknameColor: "TEAL"))
        #expect(MoyeoUserCardPalette(nicknameColor: nil).baseHex == MoyeoUserColor.fallbackHex)
    }

    @Test func palettesAreBuiltFromTheServerColor() {
        #expect(MoyeoUserCardPalette(nicknameColor: "ORANGE").baseHex == MoyeoUserColor.orange.hex)
    }
}

@Suite("25 프로필 카드가 그리는 값 (changeLog18)")
struct ProfileCardCompanionTests {
    private func dexCompanion(
        mannerRating: Double? = 4.8,
        latestTripTitle: String = "경주 단풍·야경 모임",
        memories: [ServerTravelDexCompanion.Memory] = []
    ) throws -> ServerTravelDexCompanion {
        let json = """
        {
          "userId": 62,
          "nickname": "우직한 곰 7821",
          "profileImageUrl": null,
          "mannerRating": \(mannerRating.map { "\($0)" } ?? "null"),
          "tripCount": 2,
          "latestTripDate": "2026-08-23",
          "latestTripTitle": "\(latestTripTitle)",
          "memories": \(memoriesJSON(memories))
        }
        """
        return try JSONDecoder().decode(ServerTravelDexCompanion.self, from: Data(json.utf8))
    }

    private func memoriesJSON(_ memories: [ServerTravelDexCompanion.Memory]) -> String {
        let items = memories.map { memory in
            let review = memory.oneLineReview.map { "\"\($0)\"" } ?? "null"
            return """
            {"chatRoomId": \(memory.chatRoomId), "tripTitle": "\(memory.tripTitle)",
             "tripDate": "\(memory.tripDate)", "oneLineReview": \(review)}
            """
        }
        return "[\(items.joined(separator: ","))]"
    }

    // MARK: 서버 계약

    @Test func publicProfileDecodesTheLiveResponse() throws {
        // 라이브 서버 실측 응답 (2026-08-25)
        let json = """
        {"userId":62,"nickname":"따스한 기린 2334","nicknameColor":"ORANGE","profileImageUrl":null,
         "introduction":null,"travelStyles":[],"interestedRegions":[],"mannerRating":5.0}
        """
        let profile = try JSONDecoder().decode(ServerPublicProfile.self, from: Data(json.utf8))
        #expect(profile.userId == 62)
        #expect(profile.nickname == "따스한 기린 2334")
        #expect(profile.nicknameColor == "ORANGE")
        #expect(profile.introduction == nil)
        #expect(profile.mannerRating == 5.0)
        #expect(profile.travelStyleLabels.isEmpty)
        #expect(profile.interestedRegionNames.isEmpty)
    }

    @Test func publicProfileDecodesWithMissingArrays() throws {
        let json = #"{"nickname": "우직한 곰 7821", "introduction": null, "mannerRating": null}"#
        let profile = try JSONDecoder().decode(ServerPublicProfile.self, from: Data(json.utf8))
        #expect(profile.nicknameColor == nil)
        #expect(profile.travelStyleLabels.isEmpty)
    }

    @Test func publicProfileReadsTravelStylesAndRegions() throws {
        let json = """
        {
          "introduction": "사진 찍는 걸 좋아해요.",
          "nicknameColor": "MINT",
          "mannerRating": 4.8,
          "travelStyles": [{"id": 1, "label": "사진"}, {"id": 2, "label": "자연"}],
          "interestedRegions": [{"id": 7, "signguName": "경주시"}]
        }
        """
        let profile = try JSONDecoder().decode(ServerPublicProfile.self, from: Data(json.utf8))
        #expect(profile.travelStyleLabels == ["사진", "자연"])
        #expect(profile.interestedRegionNames == ["경주시"])
    }

    @Test func receivedTravelReviewDecodesTheLiveResponse() throws {
        let json = """
        [{"reviewerId": 2, "reviewerNickname": "고요한 두루미 1130",
          "reviewerNicknameColor": "SKY_BLUE", "reviewerProfileImageUrl": null,
          "content": "약속 시간을 정확히 지키고 사진도 많이 남겨주셨어요."}]
        """
        let reviews = try JSONDecoder().decode([ServerReceivedTravelReview].self, from: Data(json.utf8))
        #expect(reviews.count == 1)
        #expect(reviews[0].reviewerNicknameColor == "SKY_BLUE")
        #expect(reviews[0].id == 2)
    }

    // MARK: 값 합치기

    @Test func serverDatesAreShownInTheScreenPlanFormat() {
        #expect(ProfileCardCompanion.dateText("2026-08-23") == "2026.08.23")
    }

    @Test func dexEntryDrawsTheDexValuesEvenWithoutThePublicProfile() throws {
        let card = ProfileCardCompanion(
            subject: .serverCompanion(try dexCompanion()),
            profile: nil,
            receivedReviews: []
        )
        #expect(card.nickname == "우직한 곰 7821")
        #expect(card.tripCount == 2)
        #expect(card.latestTripText == "경주 단풍·야경 모임 · 2026.08.23")
        // 목록 응답에는 닉네임 색이 없다 — 공개 프로필을 받기 전에는 색이 정해지지 않는다
        #expect(card.nicknameColor == nil)
        #expect(card.introduction == nil)
        #expect(card.travelStyles.isEmpty)
    }

    @Test func publicProfileFillsColorIntroductionAndStyles() throws {
        let json = """
        {"nicknameColor": "BLUE", "introduction": "사진 찍는 걸 좋아해요.",
         "travelStyles": [{"id": 1, "label": "사진"}]}
        """
        let profile = try JSONDecoder().decode(ServerPublicProfile.self, from: Data(json.utf8))
        let card = ProfileCardCompanion(
            subject: .serverCompanion(try dexCompanion()),
            profile: profile,
            receivedReviews: []
        )
        #expect(card.nicknameColor == "BLUE")
        #expect(card.introduction == "사진 찍는 걸 좋아해요.")
        #expect(card.travelStyles == ["사진"])
    }

    @Test func publicProfileFillsTheMannerRatingWhenTheDexHasNone() throws {
        let profile = try JSONDecoder().decode(
            ServerPublicProfile.self,
            from: Data(#"{"mannerRating": 4.5}"#.utf8)
        )
        let card = ProfileCardCompanion(
            subject: .serverCompanion(try dexCompanion(mannerRating: nil)),
            profile: profile,
            receivedReviews: []
        )
        // 매너 점수는 지표 스트립이 아니라 별도 메타 줄로 나간다 (changeLog18 §2-6).
        #expect(card.mannerRating == 4.5)
        #expect(card.stats.isEmpty)
    }

    @Test func nullMannerRatingMakesNoStatCell() throws {
        let card = ProfileCardCompanion(
            subject: .serverCompanion(try dexCompanion(mannerRating: nil)),
            profile: nil,
            receivedReviews: []
        )
        #expect(card.mannerRating == nil)
        #expect(card.stats.isEmpty)
    }

    @Test func statStripIsEmptyBecauseNoCountsComeFromTheServer() {
        // 여행 · 호스트 · 피드 카운트는 어떤 응답에도 없다 — 칸 자체를 만들지 않는다 (changeLog18 §4).
        // 매너 점수도 이 스트립에 넣지 않는다. 단위가 다르고(점 vs 회), 매너만 내려오는
        // 진입점에서 한 칸짜리 전체폭 스트립이 남았다 (changeLog18 §2-6).
        let card = ProfileCardCompanion(
            subject: .serverUser(ProfileCardUserReference(userID: 62, nickname: "우직한 곰 7821")),
            profile: nil,
            receivedReviews: []
        )
        #expect(card.stats.isEmpty)
    }

    @Test func emptyLatestTripTitleMakesNoRow() throws {
        let card = ProfileCardCompanion(
            subject: .serverCompanion(try dexCompanion(latestTripTitle: "")),
            profile: nil,
            receivedReviews: []
        )
        #expect(card.latestTripText == nil)
    }

    @Test func memoriesKeepNullOneLineReviewsAsNull() throws {
        let source = try dexCompanion(memories: [
            ServerTravelDexCompanion.Memory(
                chatRoomId: 11,
                tripTitle: "경주 단풍·야경 모임",
                tripDate: "2026-08-23",
                oneLineReview: "사진 정말 잘 찍어주셨어요!"
            ),
            ServerTravelDexCompanion.Memory(
                chatRoomId: 12,
                tripTitle: "주왕산 힐링 트레킹",
                tripDate: "2026-06-14",
                oneLineReview: nil
            )
        ])
        let card = ProfileCardCompanion(
            subject: .serverCompanion(source),
            profile: nil,
            receivedReviews: []
        )
        #expect(card.memories.count == 2)
        #expect(card.memories[0].tripDate == "2026.08.23")
        #expect(card.memories[1].oneLineReview == nil)
        // 같은 채팅방이 두 번 와도 ForEach 가 흔들리지 않게 id 는 서로 다르다
        #expect(Set(card.memories.map(\.id)).count == 2)
    }

    @Test func receivedReviewsKeepTheReviewerColor() throws {
        let reviews = try JSONDecoder().decode(
            [ServerReceivedTravelReview].self,
            from: Data("""
            [{"reviewerId": 2, "reviewerNickname": "고요한 두루미 1130",
              "reviewerNicknameColor": "SKY_BLUE", "reviewerProfileImageUrl": null,
              "content": "약속 시간을 정확히 지켰어요."}]
            """.utf8)
        )
        let card = ProfileCardCompanion(
            subject: .serverCompanion(try dexCompanion()),
            profile: nil,
            receivedReviews: reviews
        )
        #expect(card.receivedReviews.count == 1)
        #expect(card.receivedReviews[0].reviewerNicknameColor == "SKY_BLUE")
    }

    // MARK: 진입점별 대상

    @Test func feedAuthorEntryOnlyKnowsTheNicknameAndImage() {
        let subject = ProfileCardSubject.serverUser(
            ProfileCardUserReference(userID: 62, nickname: "따스한 기린 2334")
        )
        let card = ProfileCardCompanion(subject: subject, profile: nil, receivedReviews: [])
        #expect(card.nickname == "따스한 기린 2334")
        // 나와 함께 간 횟수는 도감에서만 온다 — 모르면 캡슐을 만들지 않는다
        #expect(card.tripCount == nil)
        #expect(card.stats.isEmpty)
        #expect(card.memories.isEmpty)
    }

    @Test func unknownSubjectDrawsNothing() {
        // 목데이터 카드는 없어졌다 — 유저 id 를 모르면 그릴 근거가 없다 (NO-MOCK-CANON R1)
        let card = ProfileCardCompanion(subject: .unavailable, profile: nil, receivedReviews: [])
        #expect(card.nickname.isEmpty)
        #expect(card.stats.isEmpty)
        #expect(card.memories.isEmpty)
        #expect(card.receivedReviews.isEmpty)
        #expect(ProfileCardSubject.unavailable.isUnavailable)
    }

    @Test func onlyServerBackedSubjectsAreQueried() {
        #expect(ProfileCardSubject.unavailable.userID == nil)
        #expect(
            ProfileCardSubject.me(
                nickname: "우직한 곰 7821", profileImageURL: nil, introduction: nil, travelStyles: []
            ).userID == nil
        )
        #expect(
            ProfileCardSubject.serverUser(
                ProfileCardUserReference(userID: 62, nickname: "따스한 기린 2334")
            ).userID == 62
        )
    }

    @Test func routeKeysAreStableAcrossRuns() {
        // `hashValue` 는 실행마다 달라 라우트 식별에 쓸 수 없다
        #expect(ProfileCardSubject.unavailable.routeKey == "unavailable")
        #expect(
            ProfileCardSubject.me(
                nickname: "곰", profileImageURL: nil, introduction: nil, travelStyles: []
            ).routeKey == "me.곰"
        )
        #expect(
            ProfileCardSubject.serverUser(
                ProfileCardUserReference(userID: 62, nickname: "곰")
            ).routeKey == "user.62"
        )
    }

    @Test func serverFeedCarriesTheAuthorIDToTheCard() {
        // 서버 피드의 작성자를 눌러야 그 사람의 카드가 열린다
        var post = FeedPost(
            id: "feed-1", authorName: "우직한 곰 7821", authorAvatar: "", region: "",
            createdAt: "", photoMascot: "", caption: "", tags: [], route: [],
            visibility: .publicAll, likeCount: 0, commentCount: 0, mood: .forest
        )
        #expect(post.authorProfileSubject == .unavailable)
        post.serverAuthorID = 62
        #expect(post.authorProfileSubject.userID == 62)
    }
}

@Suite("25 · 25-1 캡처 라우트 (changeLog18)")
struct ProfileCardCaptureRouteTests {
    @Test func profileRouteOpensTheCardFrontSide() {
        let state = UITestInitialState(arguments: ["UITEST_MODE", "UITEST_SCREEN=profile"])
        #expect(state.selectedTab == .my)
        #expect(state.myPath.count == 1)
    }

    @Test func publicProfileAliasOpensTheSameScreen() {
        let state = UITestInitialState(arguments: ["UITEST_MODE", "UITEST_SCREEN=public-profile"])
        #expect(state.selectedTab == .my)
        #expect(state.myPath.count == 1)
    }

    @Test func backSideRouteOpensTheCardFlipped() {
        let state = UITestInitialState(
            arguments: ["UITEST_MODE", "UITEST_SCREEN=public-profile-back"]
        )
        #expect(state.selectedTab == .my)
        #expect(state.myPath.count == 1)
    }

    @Test func backSideAcceptsTheShortAlias() {
        let state = UITestInitialState(arguments: ["UITEST_MODE", "UITEST_SCREEN=profile-back"])
        #expect(state.selectedTab == .my)
        #expect(state.myPath.count == 1)
    }

    @Test func frontAndBackRoutesAreDifferentDestinations() {
        // 25 와 25-1 이 같은 값이면 두 아트보드에 같은 면이 찍힌다
        #expect(
            MyRoute.profile(.unavailable, startsFlipped: false)
                != MyRoute.profile(.unavailable, startsFlipped: true)
        )
    }

    @Test func dexCardRouteIsGone() {
        // 27-4 별도 화면은 없어졌다 (changeLog18 §2-1)
        let state = UITestInitialState(arguments: ["UITEST_MODE", "UITEST_SCREEN=dex-card"])
        #expect(state.myPath.isEmpty)
    }

    @Test func friendDexRouteStillOpensJustTheDex() {
        let state = UITestInitialState(arguments: ["UITEST_MODE", "UITEST_SCREEN=friend-dex"])
        #expect(state.selectedTab == .my)
        #expect(state.myPath.count == 1)
    }
}
