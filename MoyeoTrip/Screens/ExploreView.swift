import SwiftUI

// swiftlint:disable file_length

struct ExploreView: View {
    @Binding var isBottomNavigationSuppressed: Bool
    var tripContext = TripInteractionContext()
    @State private var searchText = ""
    @State private var selectedCategory = "전체"
    @State private var showingMap = false
    @State private var supportRoute: SupportRoute?
    @State private var selectedCourse: TravelCourse?
    @State private var favoriteCourseIDs: Set<String> = ["course-cheongsong-juwangsan"]
    /// 실서버 모임 목록 — 로그인 세션이 있고 검색 API가 성공했을 때만 채워진다 (nil = 목데이터)
    @State private var serverRooms: [ServerChatRoomSummary]?
    /// 찜 토글 결과. 서버 응답(`favorite`)이 기준이고, 토글한 방만 여기서 덮어쓴다.
    @State private var serverFavoriteOverrides: [Int64: Bool] = [:]
    @State private var selectedServerTrip: TripRecruitment?

    private let categories = ["전체", "자연", "역사", "체험", "힐링"]

    init(
        isBottomNavigationSuppressed: Binding<Bool>,
        tripContext: TripInteractionContext = TripInteractionContext(),
        startsInMap: Bool = false
    ) {
        _isBottomNavigationSuppressed = isBottomNavigationSuppressed
        self.tripContext = tripContext
        _showingMap = State(initialValue: startsInMap)
    }

    private var filteredServerRooms: [ServerChatRoomSummary]? {
        guard let serverRooms else { return nil }
        return serverRooms.filter { room in
            let matchesSearch = searchText.isEmpty
                || room.title.localizedCaseInsensitiveContains(searchText)
                || room.courseTitle.localizedCaseInsensitiveContains(searchText)
                || room.tagNames.contains { $0.localizedCaseInsensitiveContains(searchText) }
            let matchesCategory = selectedCategory == "전체"
                || room.tagNames.contains { $0.contains(selectedCategory) }
                || room.title.contains(selectedCategory)
            return matchesSearch && matchesCategory
        }
    }

    /// 11 탐색 지도 하단 카드에 그릴 서버 모임 — 좌표가 있어 지도에 실제로 찍히는 첫 모임이다.
    private var selectedMapServerRoom: ServerChatRoomSummary? {
        serverRooms?.first { $0.meetingCoordinate != nil }
    }

    private var filteredCourses: [TravelCourse] {
        MockData.courses.filter { course in
            let matchesSearch = searchText.isEmpty
                || course.title.localizedCaseInsensitiveContains(searchText)
                || course.region.localizedCaseInsensitiveContains(searchText)
                || course.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            let matchesCategory = selectedCategory == "전체"
                || course.tags.contains(selectedCategory)
                || (selectedCategory == "힐링" && course.title.contains("힐링"))
            return matchesSearch && matchesCategory
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if showingMap {
                ExploreMapView(
                    tripContext: tripContext,
                    serverRooms: serverRooms,
                    selectedServerRoom: selectedMapServerRoom,
                    isSelectedCourseFavorite: favoriteCourseIDs.contains(MockData.courses[0].id),
                    isSelectedServerRoomFavorite: selectedMapServerRoom.map(isServerFavorite) ?? false,
                    onClose: {
                        showingMap = false
                    },
                    onOpenSelectedCourse: {
                        selectedCourse = MockData.courses[0]
                    },
                    onToggleSelectedCourseFavorite: {
                        toggleFavorite(MockData.courses[0])
                    },
                    onOpenSelectedServerRoom: { room in
                        selectedServerTrip = ServerTripMapper.trip(from: room)
                    },
                    onToggleSelectedServerRoomFavorite: { room in
                        toggleServerFavorite(room)
                    }
                )
            } else {
                VStack(spacing: 0) {
                    MoyeoHeader(
                        title: "탐색",
                        rightSystemImage: "line.3.horizontal",
                        rightAccessibilityLabel: "지도 탐색"
                    ) {
                        supportRoute = nil
                        isBottomNavigationSuppressed = false
                        showingMap = true
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
                                            selectedCategory = category
                                        }
                                    }
                                }
                                .padding(.horizontal, 18)
                            }

                            VStack(spacing: 12) {
                                if let serverRoomList = filteredServerRooms {
                                    // 실서버 모임 목록 — 서버가 준 데이터만 그린다
                                    if serverRoomList.isEmpty {
                                        ExploreEmptyResultView()
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
                                } else if filteredCourses.isEmpty {
                                    ExploreEmptyResultView()
                                } else {
                                    ForEach(filteredCourses) { course in
                                        ExploreCourseRow(
                                            course: course,
                                            isFavorite: favoriteCourseIDs.contains(course.id),
                                            onOpen: {
                                                selectedCourse = course
                                            },
                                            onToggleFavorite: {
                                                toggleFavorite(course)
                                            }
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 18)
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 124)
                    }
                }
            }

            if !showingMap {
                Button {
                    supportRoute = .createRecruitment(filteredCourses.first?.id ?? MockData.courses[0].id)
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
        .task {
            guard MoyeoServerSync.isEnabled, serverRooms == nil else { return }
            serverRooms = try? await ChatRoomAPIClient.shared.search()
        }
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

    private func toggleFavorite(_ course: TravelCourse) {
        if favoriteCourseIDs.contains(course.id) {
            favoriteCourseIDs.remove(course.id)
        } else {
            favoriteCourseIDs.insert(course.id)
        }
    }

    /// 서버가 준 `favorite` 이 기준이고, 이 세션에서 토글한 방만 응답값으로 덮어쓴다.
    private func isServerFavorite(_ room: ServerChatRoomSummary) -> Bool {
        serverFavoriteOverrides[room.roomId] ?? room.favorite
    }

    private func toggleServerFavorite(_ room: ServerChatRoomSummary) {
        guard MoyeoServerSync.isEnabled else { return }
        Task {
            // 실패하면 화면 값을 바꾸지 않는다 — 서버 응답만 신뢰한다.
            if let favorite = try? await ChatRoomAPIClient.shared.toggleFavorite(roomID: room.roomId) {
                serverFavoriteOverrides[room.roomId] = favorite
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

private struct ExploreEmptyResultView: View {
    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: "map")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(MoyeoTheme.forest)
            Text("조건에 맞는 코스가 없어요")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)
            Text("다른 지역이나 테마로 다시 찾아보세요.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MoyeoTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                .stroke(MoyeoTheme.softLine, lineWidth: 1)
        }
    }
}

private struct MapPreviewCard: View {
    let spots: [ExploreSpot]
    private let positions = [
        CGPoint(x: 0.24, y: 0.28),
        CGPoint(x: 0.68, y: 0.34),
        CGPoint(x: 0.42, y: 0.62),
        CGPoint(x: 0.78, y: 0.72)
    ]

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                let size = proxy.size
                RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                    .fill(MoyeoTheme.leaf)

                Path { path in
                    path.move(to: CGPoint(x: size.width * 0.12, y: size.height * 0.72))
                    path.addCurve(
                        to: CGPoint(x: size.width * 0.88, y: size.height * 0.30),
                        control1: CGPoint(x: size.width * 0.30, y: size.height * 0.22),
                        control2: CGPoint(x: size.width * 0.56, y: size.height * 0.82)
                    )
                }
                .stroke(MoyeoTheme.river.opacity(0.34), style: StrokeStyle(lineWidth: 14, lineCap: .round))

                ForEach(Array(spots.prefix(4).enumerated()), id: \.element.id) { index, spot in
                    VStack(spacing: 4) {
                        Text(spot.mascot)
                            .font(.title2)
                            .frame(width: 42, height: 42)
                            .background(MoyeoTheme.elevatedCard)
                            .clipShape(Circle())
                            .shadow(color: MoyeoTheme.ink.opacity(0.12), radius: 8, x: 0, y: 4)
                        Text(spot.region)
                            .font(.caption2.bold())
                            .foregroundStyle(MoyeoTheme.ink)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(MoyeoTheme.elevatedCard.opacity(0.92))
                            .clipShape(Capsule())
                    }
                    .position(
                        x: size.width * positions[index % positions.count].x,
                        y: size.height * positions[index % positions.count].y
                    )
                }
            }
            .frame(height: 244)
        }
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 4) {
                Text("경북 여행 맵")
                    .font(.headline)
                    .foregroundStyle(MoyeoTheme.ink)
                Text("지역별 코스와 모집 흐름을 한눈에 둘러보세요.")
                    .font(.caption)
                    .foregroundStyle(MoyeoTheme.muted)
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
    }
}

private struct ExploreMapView: View {
    var tripContext = TripInteractionContext()
    /// 실서버 모임 목록 (nil = 미로그인·캡처 모드 → 목데이터 지도)
    let serverRooms: [ServerChatRoomSummary]?
    /// 하단 선택 카드에 그릴 서버 모임 (nil = 목데이터 코스 카드)
    let selectedServerRoom: ServerChatRoomSummary?
    let isSelectedCourseFavorite: Bool
    let isSelectedServerRoomFavorite: Bool
    let onClose: () -> Void
    let onOpenSelectedCourse: () -> Void
    let onToggleSelectedCourseFavorite: () -> Void
    let onOpenSelectedServerRoom: (ServerChatRoomSummary) -> Void
    let onToggleSelectedServerRoomFavorite: (ServerChatRoomSummary) -> Void

    private let clusters = [
        MapCluster(x: 0.20, y: 0.33, count: 1),
        MapCluster(x: 0.52, y: 0.29, count: 6),
        MapCluster(x: 0.78, y: 0.36, count: 2),
        MapCluster(x: 0.36, y: 0.58, count: 2),
        MapCluster(x: 0.68, y: 0.63, count: 2)
    ]
    private let photoPositions = [
        CGPoint(x: 0.66, y: 0.21),
        CGPoint(x: 0.24, y: 0.55),
        CGPoint(x: 0.83, y: 0.50)
    ]
    private let mapBase = adaptiveColor(light: "#E6F1E5", dark: "#101B16")
    private let mapHill = adaptiveColor(light: "#D8E8D5", dark: "#182C22")
    private let mapWater = adaptiveColor(light: "#C9E0E5", dark: "#17303B")

    /// 서버 모임 마커 → 없으면 목데이터 마커.
    /// 서버는 `meetingLatitude`/`meetingLongitude` 가 **둘 다** 있는 모임만 좌표를 주므로 그 항목만 찍힌다.
    private var mapContent: MoyeoMapContent {
        if let serverRooms, let serverContent = ServerTripMapper.mapContent(from: serverRooms) {
            return serverContent
        }
        return mockMapContent
    }

    /// 목데이터 위경도가 있는 명소만 실지도 마커로 찍는다. 원 안 숫자는 그 지역의 모집 수다.
    private var mockMapContent: MoyeoMapContent {
        let markers = MockData.spots.compactMap { spot -> MoyeoMapMarker? in
            guard let coordinate = MoyeoMapCoordinate(latitude: spot.latitude, longitude: spot.longitude) else {
                return nil
            }
            let recruitments = MockData.trips.count { $0.region == spot.region }
            return MoyeoMapMarker(id: spot.id, coordinate: coordinate, order: recruitments > 0 ? recruitments : nil)
        }
        let center = markers.first?.coordinate ?? MoyeoMapCoordinate(latitude: 36.4361, longitude: 129.0573)
        return MoyeoMapContent(center: center, level: 9, markers: markers)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // 하단 선택 카드와 탭바가 지도를 덮으므로 카카오 로고를 그 위로 올린다.
            MoyeoMapView(content: mapContent, logoBottomInset: 268) {
                mockupMap
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ExploreMapHeader(onClose: onClose)
                Spacer()
            }

            // 서버 마커를 찍는 상태에서 목데이터 코스 카드를 함께 보여주면 근거가 섞인다.
            // 서버 모임이 있으면 카드도 서버 값으로 그린다(카드 자리·생김새는 화면기획 그대로).
            if let room = selectedServerRoom {
                ExploreMapSelectedServerRoomCard(
                    room: room,
                    isFavorite: isSelectedServerRoomFavorite,
                    onOpen: { onOpenSelectedServerRoom(room) },
                    onToggleFavorite: { onToggleSelectedServerRoomFavorite(room) }
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 106)
            } else {
                ExploreMapSelectedCard(
                    course: MockData.courses[0],
                    isFavorite: isSelectedCourseFavorite,
                    onOpen: onOpenSelectedCourse,
                    onToggleFavorite: onToggleSelectedCourseFavorite
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 106)
            }
        }
        .background(mapBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var mockupMap: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                mapBase
                Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height * 0.27))
                    path.addCurve(
                        to: CGPoint(x: size.width, y: size.height * 0.24),
                        control1: CGPoint(x: size.width * 0.22, y: size.height * 0.16),
                        control2: CGPoint(x: size.width * 0.62, y: size.height * 0.43)
                    )
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.addLine(to: CGPoint(x: 0, y: size.height))
                    path.closeSubpath()
                }
                .fill(mapHill)
                Path { path in
                    path.move(to: CGPoint(x: size.width * 0.66, y: 0))
                    path.addCurve(
                        to: CGPoint(x: size.width, y: size.height * 0.30),
                        control1: CGPoint(x: size.width * 0.84, y: size.height * 0.12),
                        control2: CGPoint(x: size.width * 0.88, y: size.height * 0.24)
                    )
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.addLine(to: CGPoint(x: size.width * 0.76, y: size.height))
                    path.addCurve(
                        to: CGPoint(x: size.width * 0.66, y: 0),
                        control1: CGPoint(x: size.width * 0.80, y: size.height * 0.70),
                        control2: CGPoint(x: size.width * 0.62, y: size.height * 0.36)
                    )
                }
                .fill(mapWater)

                ForEach(clusters) { cluster in
                    MapClusterPin(cluster: cluster)
                        .position(x: size.width * cluster.x, y: size.height * cluster.y)
                }

                ForEach(Array(MockData.spots.prefix(3).enumerated()), id: \.element.id) { index, spot in
                    MapPhotoPin(spot: spot)
                        .position(
                            x: size.width * photoPositions[index].x,
                            y: size.height * photoPositions[index].y
                        )
                }
            }
        }
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

private struct MapCluster: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let count: Int
}

private struct MapClusterPin: View {
    let cluster: MapCluster

    var body: some View {
        Text("\(cluster.count)")
            .font(.caption.weight(.heavy))
            .foregroundStyle(adaptiveColor(light: "#FFFFFF", dark: "#F4F8F5"))
            .frame(width: 30, height: 30)
            .background(MoyeoTheme.forest)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.16), radius: 5, x: 0, y: 2)
    }
}

private struct MapPhotoPin: View {
    let spot: ExploreSpot

    var body: some View {
        Text(spot.mascot)
            .font(.title3)
            .frame(width: 52, height: 52)
            .background(MoyeoTheme.card)
            .clipShape(Circle())
            .overlay(Circle().stroke(MoyeoTheme.elevatedCard.opacity(0.84), lineWidth: 3))
            .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 4)
    }
}

private struct ExploreMapSelectedCard: View {
    let course: TravelCourse
    let isFavorite: Bool
    let onOpen: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        let meta = course.exploreRecruitmentMeta

        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    MoyeoPhotoTile(mascot: course.mascot, mood: course.mood, height: 76, cornerRadius: 10)
                        .frame(width: 84)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(course.title)
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(MoyeoTheme.ink)
                            .lineLimit(2)
                        Text("\(course.region) · 자연")
                            .font(.caption2)
                            .foregroundStyle(MoyeoTheme.muted)
                        Text(meta.peopleText)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MoyeoTheme.text700)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(course.title)
            .accessibilityIdentifier("explore.map.selectedCourse")
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
            .accessibilityIdentifier("explore.map.favorite.\(course.id)")
        }
        .frame(height: 96)
        .padding(10)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: MoyeoTheme.ink.opacity(0.10), radius: 16, x: 0, y: 8)
    }
}

/// 11 탐색 지도 하단 선택 카드의 실서버 판. 자리·크기·하트는 목데이터 카드와 같고 값만 서버가 준다.
private struct ExploreMapSelectedServerRoomCard: View {
    let room: ServerChatRoomSummary
    let isFavorite: Bool
    let onOpen: () -> Void
    let onToggleFavorite: () -> Void

    /// 집합 안내는 서버가 null 이면 표기 자체를 숨긴다 — "미정" 같은 문구를 지어내지 않는다.
    private var meetingLine: String? {
        guard let details = room.meetingDetailsText else { return nil }
        return "\(room.meetingTimeText) \(details)"
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    CachedRemoteImage(url: room.thumbnailURL) { image in
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

private struct ExploreCourseRow: View {
    let course: TravelCourse
    let isFavorite: Bool
    let onOpen: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        let meta = course.exploreRecruitmentMeta

        HStack(spacing: 11) {
            Button(action: onOpen) {
                HStack(spacing: 11) {
                    MoyeoPhotoTile(
                        mascot: course.mascot,
                        mood: course.mood,
                        height: 68,
                        cornerRadius: 9,
                        overlay: true
                    )
                    .frame(width: 88)
                    .overlay(alignment: .bottomLeading) {
                        Text(meta.statusText)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(MoyeoTheme.forest)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .padding(5)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(course.title)
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(MoyeoTheme.ink)
                            .lineLimit(2)
                        Text("\(course.region) · \(course.tags.prefix(2).joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(MoyeoTheme.muted)
                            .lineLimit(1)
                        Text(meta.peopleText)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MoyeoTheme.text700)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(course.title)
            .accessibilityIdentifier("explore.course.row.\(course.id)")

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
            .accessibilityIdentifier("explore.favorite.\(course.id)")
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

/// 실서버 모임 행 — 서버가 내려준 값(제목·코스명·태그·인원·썸네일·상태·찜)만 그린다.
/// 배지·하트는 목데이터 카드(`ExploreCourseRow`)와 같은 자리·같은 생김새다.
private struct ExploreServerRoomRow: View {
    let room: ServerChatRoomSummary
    let isFavorite: Bool
    let onOpen: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            Button(action: onOpen) {
                HStack(spacing: 11) {
                    CachedRemoteImage(url: room.thumbnailURL) { image in
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
                            ([room.courseTitle] + room.tagNames.prefix(2))
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

private struct ExploreRecruitmentMeta {
    let statusText: String
    let peopleText: String
}

private extension TravelCourse {
    /// 탐색 목록의 배지는 화면기획·웹·안드로이드와 같은 두 가지(진행중 / 확정)만 쓴다.
    /// 모집중·마감임박·출발확정 세 갈래는 모집 상세에서만 쓰는 표기다.
    var exploreRecruitmentMeta: ExploreRecruitmentMeta {
        if let trip = MockData.trip(forCourseID: id) {
            return ExploreRecruitmentMeta(
                statusText: trip.status == .confirmed ? "확정" : "진행중",
                peopleText: "\(trip.joined)/\(trip.capacity)명"
            )
        }

        return ExploreRecruitmentMeta(
            statusText: "진행중",
            peopleText: peopleText
        )
    }
}
