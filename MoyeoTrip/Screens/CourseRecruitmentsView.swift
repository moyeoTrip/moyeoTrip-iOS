//
//  CourseRecruitmentsView.swift
//  MoyeoTrip
//
//  14 코스 상세의 `모집 중인 모임 보기`. 정본 `ATTACH-COMPOSER-CANON.md` §4.
//
//  근거 API: `GET /api/v1/travel-courses/{courseId}/chat-rooms` —
//  *"모집 마감 전이고 로그인 사용자가 아직 참가하지 않은 방을 반환합니다."*
//  응답은 `SearchChatRoomResponse` 라 11 탐색·12 검색과 **같은 카드**를 쓴다.
//
//  결과가 0건이면 `지금 모집 중인 모임이 없어요.` (NO-MOCK-CANON §2).
//

import SwiftUI

struct CourseRecruitmentsView: View {
    let courseID: Int64
    var courseTitle: String = ""
    var tripContext = TripInteractionContext()

    @Environment(\.dismiss) private var dismiss
    @State private var rooms: [ServerChatRoomSummary]?
    @State private var didFail = false
    @State private var isLoading = true
    @State private var favoriteOverrides: [Int64: Bool] = [:]
    @State private var selectedTrip: TripRecruitment?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if !courseTitle.isEmpty {
                    Text(courseTitle)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 48)
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .navigationTitle("모집 중인 모임")
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
        .task { await load() }
        .accessibilityIdentifier("screen.courseRecruitments")
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            MoyeoEmptyStateView(
                message: MoyeoEmptyText.loading,
                accessibilityIdentifier: "courseRecruitments.loading"
            )
        } else if didFail {
            MoyeoEmptyStateView(
                message: MoyeoEmptyText.loadFailed,
                onRetry: { Task { await load(force: true) } },
                accessibilityIdentifier: "courseRecruitments.failed"
            )
        } else if let rooms, !rooms.isEmpty {
            ForEach(rooms) { room in
                ServerRoomSearchResultRow(
                    room: room,
                    isFavorite: favoriteOverrides[room.roomId] ?? room.favorite,
                    onOpen: { selectedTrip = ServerTripMapper.trip(from: room) },
                    onToggleFavorite: { toggleFavorite(room) }
                )
                .moyeoCard()
            }
        } else {
            MoyeoEmptyStateView(
                message: MoyeoEmptyText.noRecruitments,
                systemImage: "person.3",
                accessibilityIdentifier: "courseRecruitments.empty"
            )
        }
    }

    private func load(force: Bool = false) async {
        guard MoyeoServerSync.isEnabled else {
            isLoading = false
            didFail = true
            return
        }
        guard force || rooms == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            rooms = try await TravelCourseAPIClient.shared.recruitingRooms(courseID: courseID)
            didFail = false
        } catch {
            rooms = nil
            didFail = true
        }
    }

    private func toggleFavorite(_ room: ServerChatRoomSummary) {
        Task {
            // 실패하면 화면 값을 바꾸지 않는다 — 서버 응답만 신뢰한다.
            if let favorite = try? await ChatRoomAPIClient.shared.toggleFavorite(roomID: room.roomId) {
                favoriteOverrides[room.roomId] = favorite
            }
        }
    }
}
