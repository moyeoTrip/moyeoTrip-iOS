import SwiftUI

// swiftlint:disable file_length

struct ExploreView: View {
    /// 목록·지도 핀·고른 필터가 모두 화면 밖 보관소에 있다 — 재진입 시 다시 부르지 않는다
    /// (TAB-STATE-CANON R1·R3).
    @ObservedObject var tabData: MoyeoTabDataStore
    @Binding var isBottomNavigationSuppressed: Bool
    var tripContext = TripInteractionContext()
    @State private var supportRoute: SupportRoute?
    @State private var selectedCourse: TravelCourse?
    @State private var selectedServerTrip: TripRecruitment?
    /// 11 지도에서 핀으로 고른 모집. nil 이면 첫 모집을 보여준다.
    @State private var selectedMapRoomID: Int64?

    private let categories = ["전체", "자연", "역사", "체험", "힐링"]

    /// 지도로 바로 여는 캡처 진입(`UITEST_SCREEN=11`)은 보관소 초기값으로 들어온다 —
    /// 화면을 만드는 동안 보관소를 건드리지 않는다.
    init(
        tabData: MoyeoTabDataStore,
        isBottomNavigationSuppressed: Binding<Bool>,
        tripContext: TripInteractionContext = TripInteractionContext()
    ) {
        self.tabData = tabData
        _isBottomNavigationSuppressed = isBottomNavigationSuppressed
        self.tripContext = tripContext
    }

    private var searchText: String {
        tabData.exploreSearchText
    }

    private var selectedCategory: String {
        tabData.exploreCategory
    }

    private var showingMap: Bool {
        tabData.exploreShowsMap
    }

    private var serverMapRooms: [ServerChatRoomSummary] {
        tabData.exploreMapRooms
    }

    private var filteredServerRooms: [ServerChatRoomSummary]? {
        guard let serverRooms = tabData.exploreRooms else { return nil }
        return serverRooms.filter { room in
            let matchesSearch = searchText.isEmpty
                || room.title.localizedCaseInsensitiveContains(searchText)
                || room.courseTitle?.localizedCaseInsensitiveContains(searchText) == true
                || room.tagNames.contains { $0.localizedCaseInsensitiveContains(searchText) }
            let matchesCategory = selectedCategory == MoyeoTabDataStore.defaultExploreCategory
                || room.tagNames.contains { $0.contains(selectedCategory) }
                || room.title.contains(selectedCategory)
            return matchesSearch && matchesCategory
        }
    }

    /// 11 탐색 지도 하단 카드에 그릴 서버 모임 — 지도에 실제로 찍히는 첫 모임이다.
    ///
    /// **지도 응답을 그대로 쓴다.** 지도 응답은 검색 응답의 상위집합이다 —
    /// 2026-08-26 응답 축소로 검색에서 `meetingLatitude`·`meetingLongitude`·`meetingDetails` 가
    /// 빠졌고, 지도 응답에만 남았다. 같은 방을 검색 쪽에서 골라 쓰면 집합 안내 줄이 조용히 사라진다.
    /// 화면기획 11: 핀을 누르면 아래 카드가 그 모집으로 바뀌고, **카드를 눌러야** 모집 상세로 간다.
    /// 누른 적이 없으면 첫 모집을 보여준다(웹·안드로이드 11과 같다).
    private var selectedMapServerRoom: ServerChatRoomSummary? {
        if let selectedMapRoomID,
           let room = serverMapRooms.first(where: { $0.roomId == selectedMapRoomID }) {
            return room
        }
        return serverMapRooms.first { $0.meetingCoordinate != nil }
    }

    /// 모집 만들기 플로팅 버튼. `body` 를 가볍게 유지하려고 분리한다.
    @ViewBuilder
    private var createRecruitmentButton: some View {
        if !showingMap {
            Button {
                supportRoute = .createRecruitment("")
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(MoyeoTheme.forest)
                    .clipShape(Circle())
                    .shadow(color: MoyeoTheme.forest.opacity(0.28), radius: 18, x: 0, y: 10)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, 86)
            .accessibilityLabel("모집 만들기")
            .accessibilityIdentifier("explore.floatingPlus")
        }
    }

    /// 탐색 결과 목록. `listScreen` 안에 두면 타입 검사가 한계를 넘는다.
    ///
    /// 서버가 준 모임만 그린다 — 못 받으면 §2 빈 상태를 그리고 목데이터로 채우지 않는다.
    @ViewBuilder
    private var resultList: some View {
        VStack(spacing: 12) {
            if let serverRoomList = filteredServerRooms {
                if serverRoomList.isEmpty {
                    MoyeoEmptyStateView(
                        message: MoyeoEmptyText.noRecruitments,
                        systemImage: "map",
                        accessibilityIdentifier: "explore.empty"
                    )
                } else {
                    ForEach(serverRoomList) { room in
                        ExploreServerRoomRow(
                            room: room,
                            isFavorite: isServerFavorite(room),
                            onOpen: {
                                selectedServerTrip = ServerTripMapper.trip(from: room)
                            },
                            onToggleFavorite: {
                                toggleServerFavorite(room)
                            }
                        )
                    }
                }
            } else if tabData.isLoadingExploreRooms {
                MoyeoEmptyStateView(
                    message: MoyeoEmptyText.loading,
                    accessibilityIdentifier: "explore.loading"
                )
            } else {
                MoyeoEmptyStateView(
                    message: MoyeoEmptyText.signedOutExplore,
                    systemImage: "person.crop.circle",
                    accessibilityIdentifier: "explore.signedOut"
                )
            }
        }
    }

    private var listScreen: some View {
            VStack(spacing: 0) {
                MoyeoHeader(
                    title: "탐색",
                    rightSystemImage: "line.3.horizontal",
                    rightAccessibilityLabel: "지도 탐색"
                ) {
                    supportRoute = nil
                    isBottomNavigationSuppressed = false
                    tabData.exploreShowsMap = true
                }

                ScrollView {
                    VStack(spacing: 16) {
                        SearchLaunchField(placeholder: "어디로 떠나고 싶나요?") {
                            supportRoute = .search
                        }
                        .padding(.horizontal, 18)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 9) {
                                ForEach(categories, id: \.self) { category in
                                    CategoryChip(
                                        title: category,
                                        isSelected: category == selectedCategory
                                    ) {
                                        tabData.exploreCategory = category
                                    }
                                }
                            }
                            .padding(.horizontal, 18)
                        }

                        resultList
                        .padding(.horizontal, 18)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 124)
                }
            }
    }

    /// 지도 탐색 화면.
    ///
    /// `body` 안에 그대로 두면 인자가 늘어날 때마다 타입 검사가 한계를 넘는다
    /// ("unable to type-check this expression in reasonable time"). 분리해 둔다.
    private var mapScreen: some View {
        ExploreMapView(
            mapRooms: serverMapRooms,
            areaErrorMessage: tabData.exploreMapAreaError,
            selectedServerRoom: selectedMapServerRoom,
            isSelectedServerRoomFavorite: selectedMapServerRoom.map(isServerFavorite) ?? false,
            onMarkerTap: { markerID in
                // 묶음의 첫 모집을 고른다 — 마커 하나가 여러 방을 덮을 수 있다.
                selectedMapRoomID = ServerTripMapper.clusterRoomIDs(from: markerID).first
            },
            onClose: {
                tabData.exploreShowsMap = false
            },
            onOpenSelectedServerRoom: { room in
                selectedServerTrip = ServerTripMapper.trip(from: room)
            },
            onToggleSelectedServerRoomFavorite: { room in
                toggleServerFavorite(room)
            }
        )
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if showingMap {
                mapScreen
            } else {
                listScreen
            }

            createRecruitmentButton
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .accessibilityIdentifier("screen.explore")
        .navigationDestination(item: $selectedCourse) { course in
            CourseDetailView(
                course: course,
                tripContext: tripContext
            )
        }
        .navigationDestination(item: $selectedServerTrip) { trip in
            TripDetailView(
                trip: trip,
                isApplied: tripContext.isApplied(trip),
                threadProvider: tripContext.chatThreadProvider,
                onApplied: tripContext.onApplyTrip,
                onSendChatMessage: tripContext.onSendChatMessage
            )
        }
        .task { await tabData.loadExploreRoomsIfNeeded() }
        .navigationDestination(item: $supportRoute) { route in
            SupportDestinationView(
                route: route,
                tripContext: tripContext
            )
        }
        .navigationDestination(for: SupportRoute.self) { route in
            SupportDestinationView(
                route: route,
                tripContext: tripContext
            )
        }
        .onAppear {
            isBottomNavigationSuppressed = selectedCourse != nil || supportRoute != nil || selectedServerTrip != nil
        }
        .onChange(of: supportRoute) { _, route in
            isBottomNavigationSuppressed = selectedCourse != nil || route != nil || selectedServerTrip != nil
        }
        .onChange(of: selectedCourse) { _, course in
            isBottomNavigationSuppressed = course != nil || supportRoute != nil || selectedServerTrip != nil
        }
        .onChange(of: selectedServerTrip) { _, trip in
            isBottomNavigationSuppressed = selectedCourse != nil || supportRoute != nil || trip != nil
        }
        .onDisappear {
            if selectedCourse == nil && supportRoute == nil && selectedServerTrip == nil {
                isBottomNavigationSuppressed = false
            }
        }
    }

    /// 서버가 준 `favorite` 이 기준이고, 이 세션에서 토글한 방만 응답값으로 덮어쓴다.
    private func isServerFavorite(_ room: ServerChatRoomSummary) -> Bool {
        tabData.exploreFavoriteOverrides[room.roomId] ?? room.favorite
    }

    private func toggleServerFavorite(_ room: ServerChatRoomSummary) {
        guard MoyeoServerSync.isEnabled else { return }
        Task {
            // 실패하면 화면 값을 바꾸지 않는다 — 서버 응답만 신뢰한다.
            if let favorite = try? await ChatRoomAPIClient.shared.toggleFavorite(roomID: room.roomId) {
                tabData.exploreFavoriteOverrides[room.roomId] = favorite
            }
        }
    }
}

private struct SearchLaunchField: View {
    let placeholder: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MoyeoTheme.muted)
                Text(placeholder)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.muted)
                Spacer()
            }
            .padding(.horizontal, 11)
            .frame(height: 38)
            .background(MoyeoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(MoyeoTheme.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("검색")
    }
}

private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isSelected ? .white : MoyeoTheme.text700)
                .frame(height: 34)
                .padding(.horizontal, 13)
                .background(isSelected ? MoyeoTheme.forest : MoyeoTheme.card)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? MoyeoTheme.forest : MoyeoTheme.line, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct ExploreMapView: View {
    /// 지도 핀 전용 목록 — `GET /chat-rooms/map`. 검색 응답에는 좌표가 없다.
    let mapRooms: [ServerChatRoomSummary]
    /// `400 40040 INVALID_MAP_SEARCH_AREA` 일 때 서버가 준 문구. 빈 지도와 구분해서 보여준다.
    var areaErrorMessage: String?
    /// 하단 선택 카드에 그릴 서버 모임
    let selectedServerRoom: ServerChatRoomSummary?
    let isSelectedServerRoomFavorite: Bool
    /// 핀을 눌렀을 때의 마커 id. 카드를 바꾸는 것까지만 한다.
    let onMarkerTap: (String) -> Void
    let onClose: () -> Void
    let onOpenSelectedServerRoom: (ServerChatRoomSummary) -> Void
    let onToggleSelectedServerRoomFavorite: (ServerChatRoomSummary) -> Void

    private let mapBase = adaptiveColor(light: "#E6F1E5", dark: "#101B16")

    /// 서버가 준 좌표만 찍는다. 손으로 그린 지도는 쓰지 않는다 (NO-MOCK-CANON R4) —
    /// 좌표가 하나도 없으면 지도를 그리지 않고 §2 빈 상태만 남긴다.
    private var mapContent: MoyeoMapContent? {
        ServerTripMapper.mapContent(from: mapRooms)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            mapSurface

            VStack(spacing: 0) {
                ExploreMapHeader(onClose: onClose)
                Spacer()
            }

            // 화면기획 11의 내 위치 버튼 — 카드 위 우측. 웹·안드로이드와 같은 자리·같은 표시다.
            // 위치 권한을 아직 쓰지 않아 표시만 한다(동작을 지어내지 않는다).
            HStack {
                Spacer()
                myLocationButton
            }
            .padding(.trailing, 18)
            // 카드와의 간격은 그대로 둔다 — 카드가 내려간 만큼(106 → 74) 같이 내린다.
            .padding(.bottom, 256)

            if let room = selectedServerRoom {
                ExploreMapSelectedServerRoomCard(
                    room: room,
                    isFavorite: isSelectedServerRoomFavorite,
                    onOpen: { onOpenSelectedServerRoom(room) },
                    onToggleFavorite: { onToggleSelectedServerRoomFavorite(room) }
                )
                .padding(.horizontal, 18)
                // 화면기획 11은 카드가 하단 탭바에 **붙어** 있다(카드 bottom 94 · 탭바 96 = 틈 2).
                //
                // 주의: 이 값은 **화면 바닥 기준**이다. 안드로이드는 스캐폴드가 탭바를 비켜 줘서
                // 같은 뜻의 값이 `2.dp` 지만, 여기서는 지도가 탭바 아래까지 덮고 있어서
                // 탭바 높이(68 + 하단 안전영역 34 = 102)를 더해야 같은 자리가 된다.
                // 2 로 두면 카드가 탭바 밑으로 들어간다 — 실제로 그렇게 찍혔다.
                //
                // 값은 **찍어서 재고** 정했다. 104 로 두니 탭바 윗변과 카드 아랫변 사이가 31.7pt 였다
                // (기획은 2). 74 면 약 1.7pt 로 기획과 같아진다. 숫자로 추정하지 말고 다시 재라 —
                // 하단 안전영역과 탭바가 겹쳐 계산이 직관과 어긋난다.
                .padding(.bottom, 74)
            }
        }
        .background(mapBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var mapSurface: some View {
        if let mapContent {
            // 하단 선택 카드와 탭바가 지도를 덮으므로 카카오 로고를 그 위로 올린다.
            // 카카오 로고는 **가리면 안 된다**(SDK 표시 의무). 카드 위에 남는다.
            // 178 로 줄였더니 카드 뒤로 숨어 오른쪽 끝만 삐져나왔다 — 찍어서 확인하고 236 으로 되돌렸다.
            MoyeoMapView(content: mapContent, logoBottomInset: 236, onMarkerTap: onMarkerTap) {
                mapBase
            }
            .ignoresSafeArea()
        } else if let areaErrorMessage {
            // 검색 영역이 유효 범위를 벗어난 것이지 "모임이 없다"가 아니다 —
            // 서버가 준 문구를 그대로 보여준다(클라가 새 문구를 짓지 않는다).
            MoyeoEmptyStateView(
                message: areaErrorMessage,
                systemImage: "map",
                accessibilityIdentifier: "explore.map.areaError"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            MoyeoEmptyStateView(
                message: MoyeoEmptyText.noRecruitments,
                systemImage: "map",
                accessibilityIdentifier: "explore.map.empty"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var myLocationButton: some View {
        Circle()
            .fill(MoyeoTheme.card)
            .frame(width: 44, height: 44)
            .overlay { Circle().stroke(MoyeoTheme.softLine, lineWidth: 1) }
            .overlay {
                // 십자선 모양 — 안드로이드 MyLocation·웹 LocateFixed 와 같은 표시다.
                Image(systemName: "dot.scope")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(MoyeoTheme.text700)
            }
            .shadow(color: .black.opacity(0.10), radius: 8, y: 2)
            .accessibilityLabel("내 위치")
            .accessibilityIdentifier("explore.map.myLocation")
    }
}

private struct ExploreMapHeader: View {
    let onClose: () -> Void

    var body: some View {
        HStack {
            Button {
                onClose()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(MoyeoTheme.ink)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("목록 탐색")
            .accessibilityIdentifier("explore.map.back")

            Spacer()

            Text("지도 탐색")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(MoyeoTheme.ink)

            Spacer()

            Button {
                onClose()
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(MoyeoTheme.ink)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("목록 탐색")
            .accessibilityIdentifier("explore.map.list")
        }
        .frame(height: 56)
        .padding(.horizontal, 8)
        .background(MoyeoTheme.background.opacity(0.92))
    }
}

private struct ExploreMapSelectedServerRoomCard: View {
    let room: ServerChatRoomSummary
    let isFavorite: Bool
    let onOpen: () -> Void
    let onToggleFavorite: () -> Void

    /// 집합 안내는 서버가 null 이면 표기 자체를 숨긴다 — "미정" 같은 문구를 지어내지 않는다.
    /// 구분자는 안드로이드·웹과 같은 " · " 다.
    private var meetingLine: String? {
        guard let details = room.meetingDetailsText else { return nil }
        let time = room.meetingTimeText
        return time.isEmpty ? details : "\(time) · \(details)"
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    CachedRemoteImage(url: room.thumbnailURL, fallbackShape: .square) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        MoyeoTheme.leaf
                    }
                    .frame(width: 84, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(room.title)
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(MoyeoTheme.ink)
                            .lineLimit(2)
                        if let meetingLine {
                            Text(meetingLine)
                                .font(.caption2)
                                .foregroundStyle(MoyeoTheme.muted)
                                .lineLimit(1)
                        }
                        Text("\(room.participantCount)/\(room.maxParticipants)명")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MoyeoTheme.text700)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(room.title)
            .accessibilityIdentifier("explore.map.selectedServerRoom")

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(isFavorite ? MoyeoTheme.coral : MoyeoTheme.text700)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "찜 해제" : "찜")
            .accessibilityValue(isFavorite ? "선택됨" : "선택 안 됨")
            .accessibilityIdentifier("explore.map.serverRoom.favorite.\(room.roomId)")
        }
        .frame(height: 96)
        .padding(10)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: MoyeoTheme.ink.opacity(0.10), radius: 16, x: 0, y: 8)
    }
}

private struct ExploreServerRoomRow: View {
    let room: ServerChatRoomSummary
    let isFavorite: Bool
    let onOpen: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            Button(action: onOpen) {
                HStack(spacing: 11) {
                    CachedRemoteImage(url: room.thumbnailURL, fallbackShape: .square) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        MoyeoTheme.leaf
                    }
                    .frame(width: 88, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(alignment: .bottomLeading) {
                        Text(room.statusBadgeText)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(MoyeoTheme.forest)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .padding(5)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(room.title)
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(MoyeoTheme.ink)
                            .lineLimit(2)
                        Text(
                            ([room.courseTitle].compactMap { $0 } + room.tagNames.prefix(2))
                                .filter { !$0.isEmpty }
                                .joined(separator: " · ")
                        )
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.muted)
                        .lineLimit(1)
                        Text("\(room.participantCount)/\(room.maxParticipants)명")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MoyeoTheme.text700)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(room.title)
            .accessibilityIdentifier("explore.serverRoom.\(room.roomId)")

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isFavorite ? MoyeoTheme.coral : MoyeoTheme.text700)
                    .frame(width: 38, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "찜 해제" : "찜")
            .accessibilityValue(isFavorite ? "선택됨" : "선택 안 됨")
            .accessibilityIdentifier("explore.serverRoom.favorite.\(room.roomId)")
        }
        .frame(height: 72)
        .padding(10)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                .stroke(MoyeoTheme.softLine, lineWidth: 1)
        }
    }
}
