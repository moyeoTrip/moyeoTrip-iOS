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
    /// 찜이 실패한 까닭. 목록 위에 한 줄로 적는다 (TC DETAIL-004 · 탐색과 같은 모양).
    @State private var favoriteErrorMessage: String?
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
            if let favoriteErrorMessage {
                MoyeoInlineErrorText(
                    message: favoriteErrorMessage, identifier: "courseRecruitments.favorite.error")
            }
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

    /// 찜 토글. 서버 응답이 와야 하트를 바꾼다 — 서버와 다른 상태를 확정하지 않는다.
    ///
    /// 예전에는 `try?` 로 실패를 삼켜 **하트도 그대로, 안내도 없었다** (TC DETAIL-004).
    private func toggleFavorite(_ room: ServerChatRoomSummary) {
        Task {
            do {
                favoriteOverrides[room.roomId] =
                    try await ChatRoomAPIClient.shared.toggleFavorite(roomID: room.roomId)
                favoriteErrorMessage = nil
            } catch {
                favoriteErrorMessage = error.moyeoUserMessage(
                    fallback: "찜을 바꾸지 못했어요. 잠시 후 다시 시도해주세요."
                )
            }
        }
    }
}
