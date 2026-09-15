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
import CoreGraphics
import Foundation

@MainActor
final class MoyeoTabDataStore: ObservableObject {
    // MARK: - 홈 (가진 것 보여주며 뒤에서 갱신 — R3)

    @Published private(set) var homeWeather: ServerGyeongbukWeather?
    /// 날씨 조회 실패 (HOME-016). 실패하면 **맑음으로 오인시키지 않고** 히어로에 안내를 띄운다.
    @Published private(set) var didFailHomeWeather = false
    /// 09 홈 · "지금 떠나기 좋은 코스" — `GET /travel-courses/public`
    @Published private(set) var homeCourses: [TravelCourse]?
    @Published private(set) var isLoadingHomeCourses = false
    /// 마지막 조회가 **실패**했는지. `nil` 목록만으로는 「아직 없다」와 「못 받았다」를
    /// 구분할 수 없어, 서버가 500 을 줘도 화면이 「아직 공개된 코스가 없어요.」로 보였다
    /// (정본 NO-MOCK-CANON R1 은 실패를 **오류 + 다시 시도**로 그리라고 못박는다 · TC HOME-014).
    @Published private(set) var didFailHomeCourses = false
    /// 09 홈 · "인기 코스 TOP 3" — `GET /travel-courses/public/popular`
    ///
    /// **추천과 합치지 않는다.** 예전에는 인기 응답을 추천 자리에 써버려 섹션이 통째로 사라졌다
    /// (NO-MOCK-CANON §4-1). 웹·안드로이드와 같이 두 목록을 따로 담는다.
    @Published private(set) var homePopularCourses: [TravelCourse]?
    @Published private(set) var isLoadingHomePopularCourses = false
    /// 인기 코스 조회 실패 (HOME-015). 추천과 다른 엔드포인트라 따로 센다.
    @Published private(set) var didFailHomePopularCourses = false

    // MARK: - 탐색 (보던 상태 유지 — R3)

    @Published private(set) var exploreRooms: [ServerChatRoomSummary]?
    @Published private(set) var exploreMapRooms: [ServerChatRoomSummary] = []
    /// 지도 조회가 `400 40040 INVALID_MAP_SEARCH_AREA` 로 막혔을 때 **서버가 준 문구**.
    /// 빈 지도(모임 0건)와 구분해 보여준다 — 그 밖의 실패는 예전처럼 조용히 넘긴다.
    @Published private(set) var exploreMapAreaError: String?
    /// 지도 핀 조회가 **실패**했는지. 예전에는 40040 이 아닌 실패(통신 끊김·500)를 조용히
    /// 삼켜서 지도가 「지금 모집 중인 모임이 없어요.」로 보였다 — 통신 실패를 0건이라고
    /// 말하는 셈이다 (TC SEARCH-014 · NO-MOCK-CANON R1).
    @Published private(set) var didFailExploreMapRooms = false
    @Published private(set) var isLoadingExploreRooms = false
    /// 탐색 목록 조회가 **실패**했는지. `exploreRooms == nil` 만 보면 「아직 못 받았다」와
    /// 「미로그인」을 구분할 수 없어, 서버가 500 을 줘도 화면이 로그인 안내를 띄웠다
    /// (로그인한 사용자에게 「로그인하면…」이라고 말하는 셈 · TC NAV-012·SEARCH-040).
    @Published private(set) var didFailExploreRooms = false
    /// 다음 페이지가 남아 있는지. **받은 개수가 `limit` 보다 적으면 마지막**이라는 서버 규칙으로만
    /// 판단한다(응답에 총 개수도 `nextId` 도 없다). 한 번 마지막에 닿으면 다시 부르지 않는다.
    @Published private(set) var hasMoreExploreRooms = true
    /// 다음 페이지를 받는 중인지. 첫 페이지 로딩(`isLoadingExploreRooms`)과 섞으면
    /// 목록이 있는데도 로딩 빈 상태로 덮인다 (R2).
    @Published private(set) var isLoadingMoreExploreRooms = false
    /// 찜 토글 결과. 서버 응답(`favorite`)이 기준이고, 토글한 방만 여기서 덮어쓴다.
    @Published var exploreFavoriteOverrides: [Int64: Bool] = [:]
    /// 고른 필터·검색어·지도 전환도 화면 밖에 둔다 — 탭을 다녀와도 그대로여야 한다 (R3).
    @Published var exploreSearchText = ""
    @Published var exploreCategory = MoyeoTabDataStore.defaultExploreCategory
    /// 탐색 목록의 스크롤 위치(세로 오프셋). 탭을 오간 뒤에도 보던 자리로 돌아온다
    /// (TAB-STATE-CANON R3 · R7 · TC NAV-007). 화면 안에 두면 탭을 떠날 때 사라진다.
    /// `@Published` 로 두면 스크롤하는 내내 본문이 다시 그려지므로 **일부러 알리지 않는다.**
    var exploreScrollOffset: CGFloat = 0
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
    /// 탭별 **조회 실패** 여부. 실패를 빈 목록으로 그리면 「아직 올라온 피드가 없어요.」가 떠
    /// 사용자가 글이 없다고 읽는다 (NO-MOCK-CANON R1 · TC FEED-038).
    @Published private(set) var failedFeedTabs: Set<String> = []
    @Published var feedSegment: FeedSegment = .discover
    /// 피드 탭별 스크롤 위치. 탭(팔로잉·발견)마다 보던 자리가 다르다 (TC NAV-009).
    var feedScrollOffsets: [String: CGFloat] = [:]

    // MARK: - 마이 (가진 것 보여주며 뒤에서 갱신 — R3)

    @Published private(set) var myProfile: ServerMyProfile?
    /// 26 상단 3칸 지표(`여행`·`매너`·`피드`) — `GET /users/{myId}/profile`.
    /// **화면 안(`@State`)에 두면 탭을 떠나는 순간 사라진다.** 탭을 오갈 때마다 줄이 통째로
    /// 없어졌다가 응답이 와야 다시 생겼고, 조회가 느리거나 실패하면 그동안 빈자리였다
    /// (TC NAV-011 · TAB-STATE-CANON R3 「가진 것을 보여주며 뒤에서 갱신한다」).
    @Published private(set) var myMetrics: ServerPublicProfile?
    @Published private(set) var myRooms: [ServerMyChatRoom]?
    /// 26 「내 여행」 조회가 **실패**했는지. 예전에는 실패도 `myRooms == nil` 이라
    /// 찜해 둔 게 있어도 「참여 중인 모임이 없어요.」로 보였다 — 통신 실패와 빈 목록이
    /// 구분되지 않았다(안드 `MyViewModel` 과 같은 결함, `didFailExploreRooms` 와 같은 규칙).
    @Published private(set) var didFailMyRooms = false
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

    /// 탐색 한 페이지 크기. 서버 기본값과 같은 20 이다 —
    /// 「받은 개수가 `limit` 보다 적으면 마지막」 판정이 이 값에 걸려 있다.
    nonisolated private static let explorePageSize = 20
}

// MARK: - 갱신

extension MoyeoTabDataStore {
    /// 홈 히어로 날씨. 실패해도 가진 값을 지우지 않는다 (R2 — 오류로 덮지 않는다).
    func refreshHomeWeather() async {
        guard MoyeoServerSync.isEnabled else { return }
        guard let weather = try? await WeatherAPIClient.shared.gyeongbuk() else {
            // 가진 값이 있으면 지우지 않는다 (R2). 없으면 **실패**라고 말한다 — 조용히 비우면
            // 날씨를 못 받은 것이 「날씨 정보 없음」처럼 보인다.
            didFailHomeWeather = homeWeather == nil
            return
        }
        homeWeather = weather
        didFailHomeWeather = false
    }

    /// 홈 추천 코스. 이전 목록을 그대로 둔 채 뒤에서 갱신하고, 새 응답이 오면 조용히 바꿔 끼운다 (R3).
    func refreshHomeCourses() async {
        guard MoyeoServerSync.isEnabled, !isLoadingHomeCourses else { return }
        isLoadingHomeCourses = true
        defer { isLoadingHomeCourses = false }
        guard let publicCourses = try? await TravelCourseAPIClient.shared.publicCourses() else {
            didFailHomeCourses = homeCourses == nil
            return
        }
        homeCourses = publicCourses.map(ServerCourseMapper.course(from:))
        didFailHomeCourses = false
    }

    /// 홈 인기 코스 TOP 3. 추천과 **다른 엔드포인트**이고 다른 섹션이다 — 합치지 않는다.
    /// 실패하면 가진 목록을 그대로 둔다 (R2 — 오류로 덮지 않는다).
    func refreshHomePopularCourses() async {
        guard MoyeoServerSync.isEnabled, !isLoadingHomePopularCourses else { return }
        isLoadingHomePopularCourses = true
        defer { isLoadingHomePopularCourses = false }
        guard let popular = try? await TravelCourseAPIClient.shared.popularCourses() else {
            didFailHomePopularCourses = homePopularCourses == nil
            return
        }
        homePopularCourses = popular.map(ServerCourseMapper.course(from:))
        didFailHomePopularCourses = false
    }

    /// 탐색 목록과 지도 핀. 한 번 받으면 탭을 다녀와도 다시 부르지 않는다 (R3).
    ///
    /// **둘은 다른 엔드포인트다.** 검색 응답에는 집합 좌표가 없어서(2026-08-26 응답 축소)
    /// 지도 핀은 `GET /chat-rooms/map` 으로 따로 받아야 한다. 실패하면 좌표가 없으니 지도를 그리지 않는다.
    func loadExploreRoomsIfNeeded() async {
        guard MoyeoServerSync.isEnabled, exploreRooms == nil, !isLoadingExploreRooms else { return }
        isLoadingExploreRooms = true
        defer { isLoadingExploreRooms = false }
        let firstPage = try? await ChatRoomAPIClient.shared.search(limit: Self.explorePageSize)
        exploreRooms = firstPage
        // 실패를 미로그인·빈 목록과 구분해 기록한다 (NO-MOCK-CANON R1).
        didFailExploreRooms = firstPage == nil
        hasMoreExploreRooms = (firstPage?.count ?? 0) >= Self.explorePageSize
        exploreMapAreaError = nil
        didFailExploreMapRooms = false
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
            didFailExploreMapRooms = true
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

    /// 모임 — **가진 값을 지우지 않고 뒤에서 다시 받는다** (R3, 마이 `refreshMy()` 와 같은 방식).
    ///
    /// `loadMeetingsIfNeeded()` 는 `meetingRooms != nil` 이면 아무것도 하지 않는다. 그래서 한 번
    /// 받아 둔 뒤에는 방 상태가 바뀌어도(불발 처리 등) 목록·탭 카운트가 그대로였고, 탭 전환도
    /// 당겨서 새로고침도 듣지 않아 **앱을 껐다 켜야** 맞는 값이 나왔다 (IOS-F143).
    /// 두 조회를 **한꺼번에 띄우고 끝나고 나서 한 번에 담는다.** 순서대로 돌리면
    /// 첫 응답을 `@Published` 에 담는 순간 화면이 다시 그려지고, `.refreshable` 이 물고 있던
    /// 태스크가 그때 취소돼 **두 번째 요청이 `NSURLErrorCancelled(-999)` 로 죽었다** —
    /// 그래서 당겨서 새로고침을 해도 방 목록·인원·마지막 메시지가 그대로였다
    /// (2026-09-14 기기 로그로 확인: `GET /chat-rooms/my?filter=ALL` 이 19ms 만에 cancelled).
    func refreshMeetings() async {
        guard MoyeoServerSync.isEnabled else { return }
        async let waitingTask = try? await ChatRoomAPIClient.shared.myWaitingRooms()
        async let roomsTask = try? await ChatRoomAPIClient.shared.myRooms()
        let (waiting, rooms) = await (waitingTask, roomsTask)
        if let waiting { meetingWaitingRooms = waiting }
        if let rooms { meetingRooms = rooms }
    }

    /// 탐색 — **가진 값을 지우지 않고 뒤에서 다시 받는다** (모임 `refreshMeetings()` 와 같은 방식).
    ///
    /// `loadExploreRoomsIfNeeded()` 는 `exploreRooms != nil` 이면 아무것도 하지 않는다. 그래서
    /// 한 번 받아 둔 뒤에는 새 모집이 열려도·인원이 차도 목록이 그대로였고, 당겨서 새로고침도
    /// 없어서 **앱을 껐다 켜야** 맞는 값이 나왔다 (IOS-F04).
    /// 모임과 같은 이유로 **두 조회를 동시에 띄우고 끝난 뒤 한 번에 담는다** —
    /// 순서대로 담으면 첫 응답의 화면 갱신이 `.refreshable` 태스크를 취소해 두 번째가 죽는다.
    func refreshExploreRooms() async {
        guard MoyeoServerSync.isEnabled else { return }
        async let roomsTask = try? await ChatRoomAPIClient.shared.search(limit: Self.explorePageSize)
        async let mapTask = try? await ChatRoomAPIClient.shared.mapRooms(
            latitude: Self.gyeongbukCenterLatitude,
            longitude: Self.gyeongbukCenterLongitude,
            radiusKilometers: Self.gyeongbukRadiusKilometers
        )
        let (rooms, mapRooms) = await (roomsTask, mapTask)
        didFailExploreRooms = rooms == nil && exploreRooms == nil
        if let rooms {
            exploreRooms = rooms
            // 첫 페이지부터 다시 세우므로 「더 있는지」도 다시 판단한다.
            hasMoreExploreRooms = rooms.count >= Self.explorePageSize
        }
        if let mapRooms {
            exploreMapRooms = mapRooms
            exploreMapAreaError = nil
            didFailExploreMapRooms = false
        } else if exploreMapRooms.isEmpty {
            // 다시 받기에 실패했다. 이미 찍어 둔 핀이 있으면 그대로 두고(R3),
            // 보여줄 핀이 하나도 없을 때만 실패를 말한다.
            didFailExploreMapRooms = true
        }
    }

    /// 탐색 다음 페이지 — 목록을 아래로 끝까지 내렸을 때 이어 받는다.
    ///
    /// 예전에는 `limit=20` 한 번만 불러서 **21번째부터는 어떤 방법으로도 볼 수 없었다.**
    /// 커서는 직전 페이지의 **마지막 `roomId`** 이고, 받은 개수가 `limit` 보다 적으면 마지막이다.
    ///
    /// 서버가 겹친 묶음을 주더라도 같은 카드가 두 번 그려지면 안 되므로 **이미 가진 `roomId` 는
    /// 건너뛴다.** 그렇게 걸러 새로 붙은 게 하나도 없으면 더 부르지 않는다 —
    /// 같은 페이지를 무한히 다시 받지 않기 위해서다.
    func loadMoreExploreRooms() async {
        // **`isLoadingExploreRooms` 로 막지 않는다.** 첫 페이지 조회는 목록을 담은 뒤에도
        // 지도 핀(`GET /chat-rooms/map`)을 마저 받느라 그 깃발을 내리지 않는다. 그 사이에
        // 마지막 카드의 `onAppear` 가 와서 막히면, 그 카드는 이미 만들어진 뒤라 **다시 오지
        // 않는다** — 실제로 그렇게 두 번째 묶음이 영영 안 붙는 걸 시뮬레이터로 확인했다.
        // 첫 페이지가 아직이면 `exploreRooms == nil` 이라 아래 guard 가 이미 막아 준다.
        guard MoyeoServerSync.isEnabled,
              hasMoreExploreRooms,
              !isLoadingMoreExploreRooms,
              let current = exploreRooms,
              let cursor = current.last?.roomId else { return }
        isLoadingMoreExploreRooms = true
        defer { isLoadingMoreExploreRooms = false }
        guard let page = try? await ChatRoomAPIClient.shared.search(
            cursor: cursor,
            limit: Self.explorePageSize
        ) else {
            // 실패하면 같은 커서로 무한히 다시 부르지 않도록 멈춘다.
            hasMoreExploreRooms = false
            return
        }
        let known = Set(current.map(\.roomId))
        let appended = page.filter { !known.contains($0.roomId) }
        exploreRooms = current + appended
        hasMoreExploreRooms = page.count >= Self.explorePageSize && !appended.isEmpty
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
        guard let page = try? await FeedAPIClient.shared.feeds(tab: tab) else {
            failedFeedTabs.insert(tab)
            return
        }
        feedPostsByTab[tab] = page.feeds.map(ServerFeedMapper.post(from:))
        failedFeedTabs.remove(tab)
    }

    func isLoadingFeed(_ segment: FeedSegment) -> Bool {
        loadingFeedTab == segment.serverTab
    }

    func feedPosts(for segment: FeedSegment) -> [FeedPost]? {
        feedPostsByTab[segment.serverTab]
    }

    /// 마이 — 가진 값을 지우지 않고 뒤에서 갱신한다 (R3). 갱신 중 로딩으로 덮지 않는다.
    /// 모임·탐색과 같은 이유로 **두 조회를 동시에 띄우고 끝난 뒤 한 번에 담는다** —
    /// 순서대로 담으면 첫 응답의 화면 갱신이 당겨서 새로고침 태스크를 취소해 두 번째가 죽는다.
    func refreshMy() async {
        guard MoyeoServerSync.isEnabled else { return }
        async let profileTask = try? await UserProfileAPIClient.shared.myProfile()
        async let roomsTask = try? await ChatRoomAPIClient.shared.myRooms()
        let (profile, rooms) = await (profileTask, roomsTask)
        if let profile {
            myProfile = profile
            persistDisplayProfile(profile)
        }
        if let rooms { myRooms = rooms }
        // 가진 값이 없는데 조회까지 실패했으면 「없음」이 아니라 「못 불러옴」이다.
        didFailMyRooms = rooms == nil && myRooms == nil
        await refreshMyMetrics()
    }

    /// 3칸 지표. 이미 가진 값이 있으면 **지우지 않고** 새 값이 올 때만 바꾼다 (R3).
    func loadMyMetricsIfNeeded() async {
        guard MoyeoServerSync.isEnabled, myMetrics == nil else { return }
        await refreshMyMetrics()
    }

    private func refreshMyMetrics() async {
        guard MoyeoServerSync.isEnabled, let userID = MoyeoCurrentUser.id else { return }
        // 못 받으면 가진 값을 그대로 둔다 — 숫자를 지어내지도, 있던 줄을 지우지도 않는다.
        if let metrics = try? await UserProfileAPIClient.shared.publicProfile(userID: userID) {
            myMetrics = metrics
        }
    }

    /// 24 피드 — 보고 있는 탭을 **다시 받는다**(당겨서 새로고침 · 정본 TAB-STATE-CANON R4).
    /// `loadFeedIfNeeded` 는 한 번 받은 탭을 다시 부르지 않아, 새 글이 올라와도
    /// 앱을 껐다 켜기 전에는 목록이 그대로였다.
    func refreshFeed(_ segment: FeedSegment) async {
        guard MoyeoServerSync.isEnabled else { return }
        let tab = segment.serverTab
        guard let page = try? await FeedAPIClient.shared.feeds(tab: tab) else {
            failedFeedTabs.insert(tab)
            return
        }
        feedPostsByTab[tab] = page.feeds.map(ServerFeedMapper.post(from:))
        failedFeedTabs.remove(tab)
    }

    func didFailFeed(_ segment: FeedSegment) -> Bool {
        failedFeedTabs.contains(segment.serverTab) && feedPostsByTab[segment.serverTab] == nil
    }

    /// 09 홈 — 날씨·추천·인기 셋을 **동시에** 다시 받는다 (당겨서 새로고침).
    func refreshHome() async {
        guard MoyeoServerSync.isEnabled else { return }
        async let weatherTask = try? await WeatherAPIClient.shared.gyeongbuk()
        async let coursesTask = try? await TravelCourseAPIClient.shared.publicCourses()
        async let popularTask = try? await TravelCourseAPIClient.shared.popularCourses()
        let (weather, courses, popular) = await (weatherTask, coursesTask, popularTask)
        if let weather { homeWeather = weather }
        didFailHomeWeather = weather == nil && homeWeather == nil
        if let courses { homeCourses = courses.map(ServerCourseMapper.course(from:)) }
        didFailHomeCourses = courses == nil && homeCourses == nil
        if let popular { homePopularCourses = popular.map(ServerCourseMapper.course(from:)) }
        didFailHomePopularCourses = popular == nil && homePopularCourses == nil
    }

    /// 다음 **콜드 스타트에서 프로필 사진이 한 박자 늦게 뜨지 않도록** URL 을 남긴다.
    ///
    /// 닉네임은 액세스 토큰에서 동기로 읽어 앱이 켜지는 순간 그려지는데(R6), 사진 URL 은
    /// `GET users/me/profile` 응답을 기다려야 해서 **닉네임만 먼저 뜨고 사진이 뒤따라왔다**
    /// (사용자가 발견 — 앱을 껐다 켤 때마다 반복됐다).
    ///
    /// 이미지 바이트는 디스크 캐시에 남아 있으므로 **URL 만 알면 즉시 그린다.**
    /// `ContentView` 가 시작할 때 `cachedProfile()` 로 이 값을 동기로 읽는다.
    /// 저장 자리는 가입 플로우가 쓰던 것과 같다 — 여기서는 실제 프로필 응답으로 덮는다
    /// (가입 후보 응답보다 이쪽이 지금 사진이다).
    private func persistDisplayProfile(_ profile: ServerMyProfile) {
        UserDefaultsAuthDisplayProfileStore().save(
            AuthDisplayProfile(
                nickname: profile.nickname,
                profileImageURL: MoyeoImageURL.resolve(profile.profileImageUrl)
            )
        )
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
        isLoadingMoreExploreRooms = false
        hasMoreExploreRooms = true
        exploreFavoriteOverrides = [:]
        exploreSearchText = ""
        exploreCategory = Self.defaultExploreCategory
        exploreScrollOffset = 0
        feedScrollOffsets = [:]
        exploreShowsMap = false
        meetingWaitingRooms = nil
        meetingRooms = nil
        isLoadingMeetings = false
        meetingSegment = .ongoing
        feedPostsByTab = [:]
        loadingFeedTab = nil
        feedSegment = .discover
        myProfile = nil
        myMetrics = nil
        // 저장해 둔 표시용 프로필도 지운다 — 다음 로그인 화면에 남의 사진이 남으면 안 된다.
        UserDefaultsAuthDisplayProfileStore().clear()
        myRooms = nil
        didFailMyRooms = false
        mySegment = Self.defaultMySegment
    }
}
