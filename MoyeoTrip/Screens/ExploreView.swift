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
                    isSelectedCourseFavorite: favoriteCourseIDs.contains(MockData.courses[0].id),
                    onClose: {
                        showingMap = false
                    },
                    onOpenSelectedCourse: {
                        selectedCourse = MockData.courses[0]
                    },
                    onToggleSelectedCourseFavorite: {
                        toggleFavorite(MockData.courses[0])
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
                                if filteredCourses.isEmpty {
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
            isBottomNavigationSuppressed = selectedCourse != nil || supportRoute != nil
        }
        .onChange(of: supportRoute) { _, route in
            isBottomNavigationSuppressed = selectedCourse != nil || route != nil
        }
        .onChange(of: selectedCourse) { _, course in
            isBottomNavigationSuppressed = course != nil || supportRoute != nil
        }
        .onDisappear {
            if selectedCourse == nil && supportRoute == nil {
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
    let isSelectedCourseFavorite: Bool
    let onClose: () -> Void
    let onOpenSelectedCourse: () -> Void
    let onToggleSelectedCourseFavorite: () -> Void

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

    var body: some View {
        ZStack(alignment: .bottom) {
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
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ExploreMapHeader(onClose: onClose)
                Spacer()
            }

            ExploreMapSelectedCard(
                course: MockData.courses[0],
                isFavorite: isSelectedCourseFavorite,
                onOpen: onOpenSelectedCourse,
                onToggleFavorite: onToggleSelectedCourseFavorite
            )
            .padding(.horizontal, 18)
            .padding(.bottom, 106)
        }
        .background(mapBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
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
