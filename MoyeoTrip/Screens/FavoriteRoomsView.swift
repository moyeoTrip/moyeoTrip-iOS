//
//  FavoriteRoomsView.swift
//  MoyeoTrip
//
//  26-1 찜한 모집. 정본 `ATTACH-COMPOSER-CANON.md` §6-1 · §6-2.
//
//  모집 상세 15와 탐색 10 카드에 하트가 있는데 **모아 보는 곳이 없었다.**
//  마이 26 의 `찜한 코스` 탭은 **코스**이지 모집이 아니다 — 서로 다른 것이다.
//
//  근거: `GET /api/v1/chat-rooms/my/favorites` (응답은 11 탐색 카드와 같은 `SearchChatRoomResponse`)
//        `POST /api/v1/chat-rooms/{roomId}/favorite` (여기서도 찜을 풀 수 있어야 한다)
//
//  같은 파일에 26 `찜한 코스` 도 있다 — `GET /api/v1/travel-courses/me/favorites`.
//  "찜 목록 조회 API 가 없다"는 주석이 오래 남아 탭이 늘 비어 있었다 (NO-MOCK-CANON §4-1).
//

import SwiftUI

/// 26-1 을 단독 화면으로 연다 (캡처 라우트 `favorite-rooms`).
struct FavoriteRoomsView: View {
    var tripContext = TripInteractionContext()

    @State private var selectedTrip: TripRecruitment?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                FavoriteRoomsSection { room in
                    selectedTrip = ServerTripMapper.trip(from: room)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .navigationTitle("찜한 모집")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedTrip) { trip in
            TripDetailView(
                trip: trip,
                isApplied: tripContext.isApplied(trip),
                threadProvider: tripContext.chatThreadProvider,
                onApplied: tripContext.onApplyTrip,
                onSendChatMessage: tripContext.onSendChatMessage
            )
        }
        .accessibilityIdentifier("screen.favoriteRooms")
    }
}

/// 26 마이 세그먼트와 26-1 화면이 함께 쓰는 목록.
/// 열기(`onOpen`)를 넘기지 않으면 26 마이의 `TripRecruitment` 목적지로 간다.
struct FavoriteRoomsSection: View {
    var onOpen: ((ServerChatRoomSummary) -> Void)?

    @State private var rooms: [ServerChatRoomSummary]?
    @State private var loadState: TripCompanionsState = .loading
    /// 찜 토글 결과. 서버 응답(`favorite`)이 기준이고, 토글한 방만 여기서 덮어쓴다.
    @State private var favoriteOverrides: [Int64: Bool] = [:]

    var body: some View {
        content
            .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .loading:
            MoyeoEmptyStateView(
                message: MoyeoEmptyText.loading,
                accessibilityIdentifier: "favoriteRooms.state"
            )
        case .failed:
            MoyeoEmptyStateView(
                message: MoyeoEmptyText.loadFailed,
                onRetry: { Task { await reload() } },
                accessibilityIdentifier: "favoriteRooms.state"
            )
        case .empty:
            MoyeoEmptyStateView(
                message: MoyeoEmptyText.noRecruitments,
                accessibilityIdentifier: "favoriteRooms.state"
            )
        case .ready:
            ForEach(rooms ?? []) { room in
                row(room)
            }
            Text("찜한 모집이 마감되거나 여행이 끝나도 목록에는 남아요. 하트를 다시 누르면 빠져요.")
                .font(MoyeoTypography.tinyMeta)
                .foregroundStyle(MoyeoTheme.text400)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func row(_ room: ServerChatRoomSummary) -> some View {
        if let onOpen {
            ServerRoomSearchResultRow(
                room: room,
                isFavorite: favoriteOverrides[room.roomId] ?? room.favorite,
                onOpen: { onOpen(room) },
                onToggleFavorite: { toggleFavorite(room) }
            )
            .moyeoCard()
        } else {
            // 26 마이 안에서는 이미 있는 `TripRecruitment` 목적지를 그대로 쓴다.
            NavigationLink(value: ServerTripMapper.trip(from: room)) {
                ServerRoomSearchResultRow(
                    room: room,
                    isFavorite: favoriteOverrides[room.roomId] ?? room.favorite,
                    onOpen: {},
                    onToggleFavorite: { toggleFavorite(room) }
                )
            }
            .buttonStyle(.plain)
            .moyeoCard()
        }
    }

    private func toggleFavorite(_ room: ServerChatRoomSummary) {
        Task {
            guard let favorite = try? await ChatRoomAPIClient.shared.toggleFavorite(roomID: room.roomId) else {
                return
            }
            favoriteOverrides[room.roomId] = favorite
        }
    }

    private func load() async {
        guard loadState == .loading, rooms == nil else { return }
        await reload()
    }

    private func reload() async {
        loadState = .loading
        guard MoyeoServerSync.isEnabled else {
            loadState = .empty
            return
        }
        guard let loaded = try? await ChatRoomAPIClient.shared.favoriteRooms() else {
            loadState = .failed
            return
        }
        rooms = loaded
        loadState = loaded.isEmpty ? .empty : .ready
    }
}

/// 26 마이 `찜한 코스` — `GET /api/v1/travel-courses/me/favorites`.
/// 오래 "조회 API 가 없다"고 적혀 있었지만 실서버는 200 을 준다 (NO-MOCK-CANON §4-1).
struct FavoriteCoursesSection: View {
    @State private var courses: [ServerLikedCourse]?
    @State private var loadState: TripCompanionsState = .loading

    var body: some View {
        content
            .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .loading:
            MoyeoEmptyStateView(
                message: MoyeoEmptyText.loading,
                accessibilityIdentifier: "my.savedCourse.state"
            )
        case .failed:
            MoyeoEmptyStateView(
                message: MoyeoEmptyText.loadFailed,
                onRetry: { Task { await reload() } },
                accessibilityIdentifier: "my.savedCourse.state"
            )
        case .empty:
            MoyeoEmptyStateView(
                message: "찜한 코스가 없어요.",
                accessibilityIdentifier: "my.savedCourse.empty"
            )
        case .ready:
            ForEach(courses ?? []) { course in
                NavigationLink(value: ServerCourseMapper.stubCourse(serverCourseID: course.courseId)) {
                    FavoriteCourseRow(course: course)
                }
                .buttonStyle(.plain)
                .moyeoCard()
            }
        }
    }

    private func load() async {
        guard loadState == .loading, courses == nil else { return }
        await reload()
    }

    private func reload() async {
        loadState = .loading
        guard MoyeoServerSync.isEnabled else {
            loadState = .empty
            return
        }
        guard let loaded = try? await TravelCourseAPIClient.shared.likedCourses() else {
            loadState = .failed
            return
        }
        courses = loaded
        loadState = loaded.isEmpty ? .empty : .ready
    }
}

/// 찜한 코스 한 줄. 이 응답은 소요 시간·거리·평점을 주지 않는다 — 그 자리를 지어내지 않는다.
private struct FavoriteCourseRow: View {
    let course: ServerLikedCourse

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            CachedRemoteImage(url: course.thumbnailURL, fallbackShape: .square) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                MoyeoTheme.leaf
            }
            .frame(width: 72, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(course.title)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                if !course.tags.isEmpty {
                    Text(course.tags.map(\.name).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.muted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("my.savedCourse.\(course.courseId)")
    }
}
