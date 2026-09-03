//
//  MoyeoTabDataStore.swift
//  MoyeoTrip
//
//  탭 전환보다 오래 사는 탭 데이터 보관소 (TAB-STATE-CANON R1).
//
//  `ContentView` 는 `switch selectedTab` 으로 탭 본문을 통째로 갈아끼운다. 그래서 화면 안의
//  `@State` 는 탭을 떠나는 순간 사라지고, 돌아올 때마다 로딩부터 다시 시작한다 —
//  사용자는 `불러오는 중이에요…` 를 다시 보고 썸네일이 기본 이미지로 깜빡이는 것을 본다.
//
//  값을 여기(탭 바깥)에 두면 화면은 읽기만 하고, 재진입 시 이미 받은 값을 즉시 그린다.
//
//  **서버에서 받은 값만 담는다** — 캐시를 목데이터로 채우지 않는다 (NO-MOCK-CANON R1).
//

import Combine
import Foundation

@MainActor
final class MoyeoTabDataStore: ObservableObject {
    // MARK: - 홈 (가진 것 보여주며 뒤에서 갱신 — R3)

    @Published private(set) var homeWeather: ServerGyeongbukWeather?
    /// 09 홈 · "지금 떠나기 좋은 코스" — `GET /travel-courses/public`
    @Published private(set) var homeCourses: [TravelCourse]?
    @Published private(set) var isLoadingHomeCourses = false
    /// 09 홈 · "인기 코스 TOP 3" — `GET /travel-courses/public/popular`
    ///
    /// **추천과 합치지 않는다.** 예전에는 인기 응답을 추천 자리에 써버려 섹션이 통째로 사라졌다
    /// (NO-MOCK-CANON §4-1). 웹·안드로이드와 같이 두 목록을 따로 담는다.
    @Published private(set) var homePopularCourses: [TravelCourse]?
    @Published private(set) var isLoadingHomePopularCourses = false

    // MARK: - 탐색 (보던 상태 유지 — R3)

    @Published private(set) var exploreRooms: [ServerChatRoomSummary]?
    @Published private(set) var exploreMapRooms: [ServerChatRoomSummary] = []
    /// 지도 조회가 `400 40040 INVALID_MAP_SEARCH_AREA` 로 막혔을 때 **서버가 준 문구**.
    /// 빈 지도(모임 0건)와 구분해 보여준다 — 그 밖의 실패는 예전처럼 조용히 넘긴다.
    @Published private(set) var exploreMapAreaError: String?
    @Published private(set) var isLoadingExploreRooms = false
    /// 찜 토글 결과. 서버 응답(`favorite`)이 기준이고, 토글한 방만 여기서 덮어쓴다.
    @Published var exploreFavoriteOverrides: [Int64: Bool] = [:]
    /// 고른 필터·검색어·지도 전환도 화면 밖에 둔다 — 탭을 다녀와도 그대로여야 한다 (R3).
    @Published var exploreSearchText = ""
    @Published var exploreCategory = MoyeoTabDataStore.defaultExploreCategory
    @Published var exploreShowsMap = false

    // MARK: - 모임 (보던 상태 유지 — R3)

    @Published private(set) var meetingWaitingRooms: [ServerWaitingRoom]?
    @Published private(set) var meetingRooms: [ServerMyChatRoom]?
    @Published private(set) var isLoadingMeetings = false
    @Published var meetingSegment: MeetingSegment = .ongoing

    // MARK: - 피드 (보던 상태 유지 — R3)

    /// 서버 탭(`FRIENDS`·`DISCOVER`)별 목록. 한 번 받은 탭은 재진입 시 다시 부르지 않는다.
    @Published private(set) var feedPostsByTab: [String: [FeedPost]] = [:]
    @Published private(set) var loadingFeedTab: String?
    @Published var feedSegment: FeedSegment = .discover

    // MARK: - 마이 (가진 것 보여주며 뒤에서 갱신 — R3)

    @Published private(set) var myProfile: ServerMyProfile?
    @Published private(set) var myRooms: [ServerMyChatRoom]?
    @Published var mySegment = MoyeoTabDataStore.defaultMySegment

    nonisolated static let defaultExploreCategory = "전체"
    nonisolated static let defaultMySegment = "진행중"

    /// 캡처가 지도 탐색으로 바로 들어오는 경우(`UITEST_SCREEN=11`)만 `true` 로 만든다.
    init(exploreShowsMap: Bool = false) {
        self.exploreShowsMap = exploreShowsMap
    }

    /// 지도 반경 조회의 기준점 — 경상북도 중심 근처.
    ///
    /// 화면 대각선으로 반경을 계산하는 방식은 지도 이동이 붙은 뒤에 쓴다. 지금은 경북 전역을 덮는
    /// 고정 반경으로 받는다. 서버가 2026-08-30 에 `radiusKm` **상한 200km** 를 세웠다 —
    /// 120 은 그 아래라 지금은 걸리지 않지만, 넘으면 `400 40040` 이다.
    nonisolated private static let gyeongbukCenterLatitude = 36.4
    nonisolated private static let gyeongbukCenterLongitude = 128.9
    nonisolated private static let gyeongbukRadiusKilometers = 120.0
    /// `40040 INVALID_MAP_SEARCH_AREA` — 위경도 범위 초과와 `radiusKm` 상한 초과가 같은 코드다.
    nonisolated private static let invalidMapSearchAreaCode = 40040
}

// MARK: - 갱신

extension MoyeoTabDataStore {
    /// 홈 히어로 날씨. 실패해도 가진 값을 지우지 않는다 (R2 — 오류로 덮지 않는다).
    func refreshHomeWeather() async {
        guard MoyeoServerSync.isEnabled else { return }
        guard let weather = try? await WeatherAPIClient.shared.gyeongbuk() else { return }
        homeWeather = weather
    }

    /// 홈 추천 코스. 이전 목록을 그대로 둔 채 뒤에서 갱신하고, 새 응답이 오면 조용히 바꿔 끼운다 (R3).
    func refreshHomeCourses() async {
        guard MoyeoServerSync.isEnabled, !isLoadingHomeCourses else { return }
        isLoadingHomeCourses = true
        defer { isLoadingHomeCourses = false }
        guard let publicCourses = try? await TravelCourseAPIClient.shared.publicCourses() else { return }
        homeCourses = publicCourses.map(ServerCourseMapper.course(from:))
    }

    /// 홈 인기 코스 TOP 3. 추천과 **다른 엔드포인트**이고 다른 섹션이다 — 합치지 않는다.
    /// 실패하면 가진 목록을 그대로 둔다 (R2 — 오류로 덮지 않는다).
    func refreshHomePopularCourses() async {
        guard MoyeoServerSync.isEnabled, !isLoadingHomePopularCourses else { return }
        isLoadingHomePopularCourses = true
        defer { isLoadingHomePopularCourses = false }
        guard let popular = try? await TravelCourseAPIClient.shared.popularCourses() else { return }
        homePopularCourses = popular.map(ServerCourseMapper.course(from:))
    }

    /// 탐색 목록과 지도 핀. 한 번 받으면 탭을 다녀와도 다시 부르지 않는다 (R3).
    ///
    /// **둘은 다른 엔드포인트다.** 검색 응답에는 집합 좌표가 없어서(2026-08-26 응답 축소)
    /// 지도 핀은 `GET /chat-rooms/map` 으로 따로 받아야 한다. 실패하면 좌표가 없으니 지도를 그리지 않는다.
    func loadExploreRoomsIfNeeded() async {
        guard MoyeoServerSync.isEnabled, exploreRooms == nil, !isLoadingExploreRooms else { return }
        isLoadingExploreRooms = true
        defer { isLoadingExploreRooms = false }
        exploreRooms = try? await ChatRoomAPIClient.shared.search()
        exploreMapAreaError = nil
        do {
            exploreMapRooms = try await ChatRoomAPIClient.shared.mapRooms(
                latitude: Self.gyeongbukCenterLatitude,
                longitude: Self.gyeongbukCenterLongitude,
                radiusKilometers: Self.gyeongbukRadiusKilometers
            )
        } catch {
            // `400 40040` 은 "모임이 없다"가 아니라 "검색 영역이 유효 범위를 벗어났다"다
            // (위경도 범위 초과와 `radiusKm` 상한 200km 초과가 같은 코드다).
            // 지금 보내는 120km 는 상한 안이라 걸리지 않지만, 걸리면 조용히 빈 지도가 되면 안 된다.
            // 문구는 서버 `errorMessage` 를 그대로 쓴다 — 클라가 새 문구를 지어내지 않는다.
            exploreMapRooms = []
            if (error as? MoyeoAPIError)?.serverCode == Self.invalidMapSearchAreaCode {
                exploreMapAreaError = (error as? LocalizedError)?.errorDescription
            }
        }
    }

    func loadMeetingsIfNeeded() async {
        guard MoyeoServerSync.isEnabled, meetingRooms == nil, !isLoadingMeetings else { return }
        isLoadingMeetings = true
        defer { isLoadingMeetings = false }
        meetingWaitingRooms = try? await ChatRoomAPIClient.shared.myWaitingRooms()
        meetingRooms = try? await ChatRoomAPIClient.shared.myRooms()
    }

    /// 신청을 취소한 방만 목록에서 뺀다 — 화면이 바꾼 항목만 갱신한다 (R4).
    func removeMeetingWaitingRoom(roomID: Int64) {
        meetingWaitingRooms?.removeAll { $0.roomId == roomID }
    }

    /// 피드는 탭(팔로잉·발견)마다 목록이 다르다 — 탭별로 따로 담고, 담긴 탭은 다시 부르지 않는다.
    func loadFeedIfNeeded(_ segment: FeedSegment) async {
        let tab = segment.serverTab
        guard MoyeoServerSync.isEnabled, feedPostsByTab[tab] == nil, loadingFeedTab != tab else { return }
        loadingFeedTab = tab
        defer { loadingFeedTab = nil }
        guard let page = try? await FeedAPIClient.shared.feeds(tab: tab) else { return }
        feedPostsByTab[tab] = page.feeds.map(ServerFeedMapper.post(from:))
    }

    func isLoadingFeed(_ segment: FeedSegment) -> Bool {
        loadingFeedTab == segment.serverTab
    }

    func feedPosts(for segment: FeedSegment) -> [FeedPost]? {
        feedPostsByTab[segment.serverTab]
    }

    /// 마이 — 가진 값을 지우지 않고 뒤에서 갱신한다 (R3). 갱신 중 로딩으로 덮지 않는다.
    func refreshMy() async {
        guard MoyeoServerSync.isEnabled else { return }
        if let profile = try? await UserProfileAPIClient.shared.myProfile() {
            myProfile = profile
        }
        if let rooms = try? await ChatRoomAPIClient.shared.myRooms() {
            myRooms = rooms
        }
    }

    /// 로그아웃·계정 전환 시 보관소를 비운다 (R4).
    /// 다른 사용자의 목록·프로필이 다음 로그인 화면에 남으면 안 된다.
    func reset() {
        homeWeather = nil
        homeCourses = nil
        isLoadingHomeCourses = false
        homePopularCourses = nil
        isLoadingHomePopularCourses = false
        exploreRooms = nil
        exploreMapRooms = []
        exploreMapAreaError = nil
        isLoadingExploreRooms = false
        exploreFavoriteOverrides = [:]
        exploreSearchText = ""
        exploreCategory = Self.defaultExploreCategory
        exploreShowsMap = false
        meetingWaitingRooms = nil
        meetingRooms = nil
        isLoadingMeetings = false
        meetingSegment = .ongoing
        feedPostsByTab = [:]
        loadingFeedTab = nil
        feedSegment = .discover
        myProfile = nil
        myRooms = nil
        mySegment = Self.defaultMySegment
    }
}
