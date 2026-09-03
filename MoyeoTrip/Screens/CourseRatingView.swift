//
//  CourseRatingView.swift
//  MoyeoTrip
//
//  27-4 코스 평가 (별점 1~5). 정본 `ATTACH-COMPOSER-CANON.md` §6-1.
//
//  **이 화면이 없어서 14 코스 상세의 평점이 영원히 비어 있었다.** 코스 상세는
//  `averageRating`·`ratingCount` 를 그리는데 그 값을 만드는 곳이 어디에도 없었다.
//
//  근거: `POST /api/v1/travel-courses/chat-rooms/{roomId}/rating` `{ "score": 1~5 }`
//  서버 조건 — 확정된 여행이 끝난 채팅방 참가자만 평가할 수 있다.
//  평가할 코스는 `GET /api/v1/travel-courses/chat-rooms/{roomId}` 가 준다 —
//  방을 못 찾거나 코스가 없으면 지어내지 않고 빈 상태를 그린다 (NO-MOCK-CANON R1).
//

import SwiftUI

struct CourseRatingView: View {
    /// 평가 대상 방. 없으면 화면이 **가장 최근에 끝난 내 모임**을 스스로 찾는다.
    var roomID: Int64?

    @Environment(\.dismiss) private var dismiss
    @State private var score = 0
    @State private var resolvedRoomID: Int64?
    @State private var roomCourse: ServerRoomCourse?
    @State private var loadState: TripCompanionsState = .loading
    @StateObject private var sendState = AttachComposerSendState()

    var body: some View {
        AttachComposerFrame(
            title: "코스 평가",
            cta: score == 0 ? "별점을 골라주세요" : "평가 남기기",
            isCTAEnabled: score > 0 && resolvedRoomID != nil && !sendState.isSending,
            identifier: "courseRating",
            onSend: submit
        ) {
            Text("이번 코스, 어떠셨어요?")
                .font(MoyeoTypography.screenTitle)
                .foregroundStyle(MoyeoTheme.ink)
            Text("남겨주신 점수는 이 코스의 평균 별점에 반영돼요.")
                .font(.subheadline)
                .foregroundStyle(MoyeoTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            courseSection

            MoyeoStarRatingInput(score: $score, identifier: "courseRating.star")
                .frame(maxWidth: .infinity)
                .padding(.top, 30)

            Text(MoyeoStarRatingWord.text(for: score))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MoyeoTheme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 22)
                .padding(.top, 14)
                .accessibilityIdentifier("courseRating.word")

            AttachNoteBox(lines: [
                "점수만 남겨요. 글은 피드에 써주세요.",
                "누가 몇 점을 줬는지는 아무에게도 보이지 않아요.",
                "함께 간 사람들의 점수가 모여 코스 평균이 돼요."
            ])
        }
        .task { await load() }
        .attachComposerFailureAlert(sendState)
    }

    /// 무엇을 평가하는지 — 코스를 먼저 보여준다. 서버가 준 값만 그린다.
    @ViewBuilder
    private var courseSection: some View {
        switch loadState {
        case .loading:
            MoyeoEmptyStateView(
                message: MoyeoEmptyText.loading,
                accessibilityIdentifier: "courseRating.state"
            )
        case .failed:
            MoyeoEmptyStateView(
                message: MoyeoEmptyText.loadFailed,
                onRetry: { Task { await reload() } },
                accessibilityIdentifier: "courseRating.state"
            )
        case .empty:
            MoyeoEmptyStateView(
                message: "아직 평가할 코스가 없어요.",
                accessibilityIdentifier: "courseRating.state"
            )
        case .ready:
            if let course = roomCourse?.course {
                CourseRatingSubjectCard(course: course, room: roomCourse?.room)
                    .padding(.top, 18)
            }
        }
    }

    private func load() async {
        guard loadState == .loading, roomCourse == nil else { return }
        await reload()
    }

    private func reload() async {
        loadState = .loading
        guard MoyeoServerSync.isEnabled else {
            loadState = .empty
            return
        }
        guard let targetRoomID = await resolveRoomID() else {
            loadState = .empty
            return
        }
        resolvedRoomID = targetRoomID
        guard let loaded = try? await TravelCourseAPIClient.shared.roomCourse(roomID: targetRoomID) else {
            loadState = .failed
            return
        }
        roomCourse = loaded
        loadState = loaded.course == nil ? .empty : .ready
    }

    /// 진입점이 방을 넘겨주면 그 방이다. 아니면 27-1 과 같은 기준 —
    /// 가장 최근에 끝난 내 모임을 쓴다. 끝난 여행이 없으면 평가할 것이 없다.
    private func resolveRoomID() async -> Int64? {
        if let roomID { return roomID }
        guard let rooms = try? await ChatRoomAPIClient.shared.myRooms() else { return nil }
        // 불발된 방은 평가할 여행이 아니다 — 확정된 여행을 먼저 고른다.
        return ServerTripMapper.latestCompletedRoom(in: rooms)?.roomId
    }

    private func submit() {
        guard let targetRoomID = resolvedRoomID, score > 0 else { return }
        let value = score
        sendState.send(fallbackMessage: "평가를 남기지 못했어요.") {
            try await TravelCourseAPIClient.shared.rateCourse(roomID: targetRoomID, score: value)
        } onSuccess: {
            dismiss()
        }
    }
}

/// 평가 대상 코스 카드. 서버가 주지 않는 값은 줄째로 빼고 그린다.
private struct CourseRatingSubjectCard: View {
    let course: ServerTravelCourse
    let room: ServerRoomCourse.Room?

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            CachedRemoteImage(url: course.thumbnailURL, fallbackShape: .square) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                MoyeoTheme.leaf
            }
            .frame(width: 62, height: 62)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(course.title)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                    .multilineTextAlignment(.leading)
                if !metaText.isEmpty {
                    Text(metaText)
                        .font(MoyeoTypography.tinyMeta)
                        .monospacedDigit()
                        .foregroundStyle(MoyeoTheme.muted)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoyeoTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MoyeoTheme.softLine))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityIdentifier("courseRating.course.\(course.courseId)")
    }

    private var metaText: String {
        [
            room.map { "\($0.startDate.replacingOccurrences(of: "-", with: ".")) 다녀옴" } ?? "",
            "\(course.places.count)곳",
            ServerCourseMapper.distanceText(course.distanceKm)
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    }
}
