//
//  CourseTitleEditView.swift
//  MoyeoTrip
//
//  18-7 코스 이름 · 소개 수정 · 20-6 내 채팅 메시지 삭제.
//
//  기획 정본: `모여트립 in 경북/screens-edit-delete.jsx`
//  서버 계약: `docs/api/BACKEND_REQUEST_CHANGES_2026-09-04.md` §5·§6 (2026-09-04 BE 회신)
//

import SwiftUI

// MARK: - 18-7 코스 이름 · 소개 수정

/// `PATCH /travel-courses/chat-rooms/{roomId}` — 기존 요청에 `title`·`description` 선택 필드가
/// 붙었다 (BE 회신 §5). 이름을 고칠 길이 없어서 `27-3 검증용 커스텀 코스 모임` 같은 이름이
/// 홈에 그대로 걸려 있었다.
///
/// **호스트가 직접 만든 `CUSTOM` 코스이고, 여행 확정 전일 때만** 고칠 수 있다.
/// 등록 코스를 차용한 모임은 못 고친다(18-2 와 같은 규칙).
struct CourseTitleEditView: View {
    let roomID: Int64

    @Environment(\.dismiss) private var dismiss
    /// `ServerRoomCourse.course` 는 옵셔널이다 — 코스가 없는 방도 있다.
    @State private var course: ServerTravelCourse?
    @State private var loadState: TripCompanionsState = .loading
    @State private var title = ""
    @State private var descriptionText = ""
    @StateObject private var sendState = AttachComposerSendState()

    /// 서버 `UpdateTravelCourseRequest.title` 이 `@Size(max = 100)` 이다.
    /// 예전에는 24 라, 만들기 화면(100자)에서 지은 이름을 이 화면에서 열면
    /// 저장하는 것만으로 제목이 조용히 잘렸다 (IOS-F150).
    private static let titleLimit = 100
    /// 서버 `UpdateTravelCourseRequest.description` 이 `@Size(max = 500)` 이다 —
    /// 1,000 으로 두면 500자를 넘겨 쓴 소개가 저장 순간에 400 으로 튕긴다.
    private static let descriptionLimit = 500

    var body: some View {
        Group {
            switch loadState {
            case .loading:
                MoyeoEmptyStateView(
                    message: MoyeoEmptyText.loading,
                    accessibilityIdentifier: "courseTitleEdit.state"
                )
            case .failed:
                MoyeoEmptyStateView(
                    message: MoyeoEmptyText.loadFailed,
                    onRetry: { Task { await load() } },
                    accessibilityIdentifier: "courseTitleEdit.state"
                )
            case .empty:
                MoyeoEmptyStateView(
                    message: "직접 만든 코스만, 여행 확정 전에 고칠 수 있어요.",
                    accessibilityIdentifier: "courseTitleEdit.state"
                )
            case .ready:
                form
            }
        }
        .task { await load() }
        .attachComposerFailureAlert(sendState)
    }

    private var form: some View {
        AttachComposerFrame(
            title: "코스 이름 수정",
            cta: "수정 저장",
            isCTAEnabled: !title.trimmingCharacters(in: .whitespaces).isEmpty && !sendState.isSending,
            identifier: "courseTitleEdit",
            onSend: save
        ) {
            // 고칠 수 있는 화면이 열렸으면 고칠 수 있는 것이다 — 왜 열렸는지는 설명하지 않는다.
            // 못 고치는 경우는 이 화면이 아예 빈 상태로 이유를 말한다.
            AttachFieldLabel(text: "코스 이름", isRequired: true, isFirst: true)
            RecruitEditField(
                text: $title,
                limit: Self.titleLimit,
                hint: "\(Self.titleLimit)자까지 · 모임 목록과 홈에 이 이름이 보여요",
                isMultiline: false,
                identifier: "courseTitleEdit.title",
                truncatesOverflow: false
            )

            AttachFieldLabel(text: "코스 소개")
            RecruitEditField(
                text: $descriptionText,
                limit: Self.descriptionLimit,
                hint: "\(Self.descriptionLimit.formatted(.number.grouping(.automatic)))자까지 · 비워 두면 지금 소개가 그대로 남아요",
                isMultiline: true,
                identifier: "courseTitleEdit.description"
            )

            // 방문지·순서를 어디서 고치는지는 바로 아래 버튼 이름이 말한다.
            // 기획·웹에는 경로 수정으로 가는 버튼이 있다. 안내만 두고 갈 길을 안 주면
            // 사용자가 어디로 가야 하는지 모른다 (4열 비교에서 iOS 만 비어 있었다).
            NavigationLink(value: SupportRoute.courseEdit(String(roomID), .editable)) {
                Label("여행 경로 수정으로 가기", systemImage: "map")
                    .font(MoyeoTypography.font(size: 14, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(MoyeoTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(MoyeoTheme.subtleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .accessibilityIdentifier("courseTitleEdit.openRouteEdit")
        }
    }

    private func load() async {
        loadState = .loading
        guard MoyeoServerSync.isEnabled else {
            loadState = .empty
            return
        }
        guard let detail = try? await TravelCourseAPIClient.shared.roomCourse(roomID: roomID),
              let room = try? await ChatRoomAPIClient.shared.detail(roomID: roomID),
              let me = try? await UserProfileAPIClient.shared.myProfile() else {
            loadState = .failed
            return
        }
        // 직접 만든 코스 + 내 방 + 확정 전 — 세 조건이 다 맞아야 서버가 받는다.
        guard let myUserID = me.userId,
              let roomCourse = detail.course,
              room.hostId == myUserID,
              roomCourse.type == "CUSTOM",
              room.status == "RECRUITING" else {
            loadState = .empty
            return
        }
        course = roomCourse
        title = roomCourse.title
        descriptionText = roomCourse.description ?? ""
        loadState = .ready
    }

    /// 지금 방문지를 **그대로 되돌려 보내기 위한** 목록.
    ///
    /// `places` 는 선택이 아니라 **필수(최소 2개)** 다 — 제목·소개만 보내면 서버가
    /// 400 `40033` 을 낸다. 이 화면은 방문지를 바꾸지 않으므로 읽어 온 것을 그대로 다시 보낸다
    /// (W-115, 2026-09-13). 순서·시각을 고치는 곳은 18-1 여행 경로 수정이다.
    private var currentPlaces: [ServerCoursePlaceEdit] {
        (course?.places ?? []).map { place in
            ServerCoursePlaceEdit(
                contentId: place.contentId,
                dayNumber: place.dayNumber,
                sequence: place.sequence,
                // 서버는 응답의 `visitTime` 을 **nullable** 로 주면서 요청에서는 **필수**(`LocalTime`)로
                // 받는다. 빈 채로 되돌려 보내면 400 이라 코스를 만들 때와 같은 규칙으로 채운다.
                visitTime: place.visitTime.map { String($0.prefix(5)) }
                    ?? CustomCourseEditorView.defaultTime(forOrder: place.sequence)
            )
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.count <= Self.titleLimit else {
            sendState.failureMessage =
                "코스 이름이 \(trimmedTitle.count)자예요. \(Self.titleLimit)자까지만 저장할 수 있어요 — 먼저 줄여 주세요."
            return
        }
        let places = currentPlaces
        guard places.count >= 2 else {
            sendState.failureMessage = "방문지가 2곳 이상이어야 코스를 고칠 수 있어요."
            return
        }
        sendState.send(fallbackMessage: "코스 이름을 수정하지 못했어요.") {
            // 제목은 항상 보내고(빈 값은 서버가 400), 소개는 비었으면 **보내지 않아** 기존 값을 남긴다.
            try await TravelCourseAPIClient.shared.updateRoomCourse(
                roomID: roomID,
                title: trimmedTitle,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                places: places
            )
        } onSuccess: {
            dismiss()
        }
    }
}

// MARK: - 20-6 내 채팅 메시지 삭제

/// 길게 눌러 여는 시트다. **내 메시지에만** 열린다 — 시스템 메시지·남의 메시지는 서버가 막는다.
///
/// 행을 지우지 않고 본문을 `삭제된 메시지입니다` 로 바꾸므로
/// **id·보낸 사람·보낸 시각·답글 관계는 그대로 남는다** (BE 회신 §6).
struct MessageDeleteView: View {
    let roomID: Int64
    /// 지울 메시지. **길게 눌러 고른 그 메시지**가 들어온다.
    ///
    /// 비워 두면 예전처럼 「내가 보낸 가장 최근 메시지」를 찾아 쓴다 — 캡처 라우트가 그 판을 쓴다.
    /// 제품 화면에서는 반드시 고른 메시지를 넘긴다. 아무거나 지우면 안 되기 때문이다 (IOS-F16).
    var pickedMessage: ServerChatMessage?
    /// 삭제가 끝난 뒤 채팅방이 목록을 다시 읽게 한다.
    var onDeleted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var message: ServerChatMessage?
    @State private var loadState: TripCompanionsState = .loading
    /// 시트 뒤에 깔리는 채팅방. **기획·웹은 방이 보인다** — 빈 회색으로 두면
    /// 4열 비교에서 iOS 만 달라 보인다 (20-2 첨부·32 신고 시트와 같은 방식이다).
    @State private var backdropThread: ChatThread?
    @StateObject private var sendState = AttachComposerSendState()

    var body: some View {
        Group {
            switch loadState {
            case .loading:
                MoyeoEmptyStateView(
                    message: MoyeoEmptyText.loading,
                    accessibilityIdentifier: "messageDelete.state"
                )
            case .failed:
                MoyeoEmptyStateView(
                    message: MoyeoEmptyText.loadFailed,
                    onRetry: { Task { await load() } },
                    accessibilityIdentifier: "messageDelete.state"
                )
            case .empty:
                MoyeoEmptyStateView(
                    message: "내가 보낸 메시지만 지울 수 있어요.",
                    accessibilityIdentifier: "messageDelete.state"
                )
            case .ready:
                if let message { sheet(message) }
            }
        }
        .task { await load() }
        .attachComposerFailureAlert(sendState)
    }

    private func sheet(_ message: ServerChatMessage) -> some View {
        MoyeoConfirmSheet(
            title: "이 메시지를 삭제할까요?",
            subject: "“\(message.content)” · \(timeText(message))",
            lines: [
                "모두에게서 사라지고 “삭제된 메시지입니다”만 남아요.",
                "사진·위치·투표도 내용만 사라지고 자리는 남아요.",
                "보낸 시각과 이 메시지에 달린 답글은 그대로예요.",
                "되돌릴 수 없어요."
            ],
            cancelTitle: "그대로 둘게요",
            confirmTitle: "삭제하기",
            isDanger: true,
            isBusy: sendState.isSending,
            identifier: "messageDelete",
            onCancel: { dismiss() },
            onConfirm: { delete(message) }
        )
        .background(ChatRoomPlainBackdrop(thread: backdropThread))
        .navigationBarBackButtonHidden(true)
    }

    private func timeText(_ message: ServerChatMessage) -> String {
        String((message.createdAt).dropFirst(11).prefix(5))
    }

    private func load() async {
        loadState = .loading
        if let pickedMessage {
            message = pickedMessage
            backdropThread = ServerTripMapper.stubThread(serverRoomID: roomID)
            loadState = .ready
            return
        }
        guard MoyeoServerSync.isEnabled else {
            loadState = .empty
            return
        }
        guard let page = try? await ChatRoomContentAPIClient.shared.messages(roomID: roomID, limit: 50),
              let me = try? await UserProfileAPIClient.shared.myProfile() else {
            loadState = .failed
            return
        }
        // 내가 보낸 **일반** 메시지 중 가장 최근 것. 시스템 메시지는 지울 수 없다.
        let myUserID = me.userId
        message = page.messages.first { $0.senderId == myUserID && $0.type != "SYSTEM" }
        backdropThread = ServerTripMapper.stubThread(serverRoomID: roomID)
        loadState = message == nil ? .empty : .ready
    }

    private func delete(_ message: ServerChatMessage) {
        sendState.send(fallbackMessage: "메시지를 지우지 못했어요.") {
            try await ChatRoomWriteAPIClient.shared.deleteMessage(
                roomID: roomID, messageID: message.messageId
            )
        } onSuccess: {
            onDeleted()
            dismiss()
        }
    }
}
