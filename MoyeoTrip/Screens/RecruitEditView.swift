//
//  RecruitEditView.swift
//  MoyeoTrip
//
//  18-6 모집 내용 수정 (호스트) · 18-7 코스 이름·소개 수정 · 20-6 내 채팅 메시지 삭제.
//
//  기획 정본: `모여트립 in 경북/screens-edit-delete.jsx`
//  서버 계약: `docs/api/BACKEND_REQUEST_CHANGES_2026-09-04.md` §4·§5·§6 (2026-09-04 BE 회신)
//  2026-09-07 실서버로 존재·권한을 확인했다 (남의 방 403 `40307`, 없는 방 404 `40405`).
//
//  18-5 집합 정보 수정과 **다른 화면**이다 — 그쪽은 `PUT .../meeting-info` 다.
//  **모집 중인 방의 호스트만** 되고, 확정한 뒤에는 아무것도 못 고친다.
//

import PhotosUI
import SwiftUI

// MARK: - 18-6 모집 내용 수정

struct RecruitEditView: View {
    let roomID: Int64

    @Environment(\.dismiss) private var dismiss
    @State private var room: ServerChatRoomDetail?
    @State private var loadState: TripCompanionsState = .loading
    @State private var title = ""
    @State private var descriptionText = ""
    @State private var isDayTrip = true
    /// 날짜·인원·참가비도 **서버가 받는 값**이다 (`PUT /chat-rooms/{roomId}`).
    /// 예전에는 읽기 전용 줄로만 그려 놓고 필수(*) 표시와 규칙 안내까지 달아
    /// **아무것도 고칠 수 없었다** (IOS-F114, 2026-09-12).
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var deadlineDate = Date()
    @State private var dayTripStart = Date()
    @State private var dayTripEnd = Date()
    @State private var minimumParticipants = 3
    @State private var maximumParticipants = 4
    @State private var participationFeeText = "0"
    @State private var validationMessage = ""
    /// 18-7 코스 이름·소개 수정. 화면은 만들어져 있는데 **여는 곳이 앱에 없었다** (IOS-F119).
    @State private var courseTitleEditRoomID: Int64?
    /// 이 방에 연결된 코스가 직접 만든 코스(`CUSTOM`)인지. `GET /travel-courses/chat-rooms/{roomId}` 의
    /// `course.type` 이 근거다 — 방 상세(`GET /chat-rooms/{roomId}`)에는 코스 종류가 없다.
    ///
    /// 18-7 은 **CUSTOM + 확정 전**일 때만 서버가 받는다(`CourseTitleEditView.load()` 가 보는 조건과 같다).
    /// 등록 코스 방에서도 버튼이 눌려서, 누르면 문장 한 줄뿐인 빈 화면이 열렸다 (IOS-F131).
    @State private var isCustomCourse = false
    /// 18-4 여행 확정 / 불발. 「모집을 그만두려면」 카드에 설명만 있고 누를 곳이 없었다 (IOS-F129).
    @State private var tripStatusRoomID: Int64?
    /// 새 대표 사진. 고르지 않으면 **파트를 보내지 않아** 서버가 지금 사진을 그대로 둔다
    /// (PATCH 규칙 · BE 회신 §4). 비우는 길은 없다.
    @State private var pickedThumbnail: PhotosPickerItem?
    @State private var thumbnailImage: UIImage?
    @StateObject private var sendState = AttachComposerSendState()

    /// 서버가 받는 값(`UpdateChatRoomRequest.title` · `@Size(max = 100)`)과 같은 100 이다.
    /// 예전에는 24 였다 — 25자 이상으로 만든 모집은 **한 글자도 안 고쳤는데 저장이 거절됐다**
    /// (2026-09-14 결정 ②). 모집 생성(17-x)의 `recruitmentNameLimit` 과 같은 값이어야 한다.
    private static let titleLimit = 100
    /// 서버가 500 자까지 받는다. 1,000 자까지라고 안내하면 그 사이 길이는 저장할 때 400 이 난다.
    private static let descriptionLimit = 500

    var body: some View {
        Group {
            switch loadState {
            case .loading:
                MoyeoEmptyStateView(
                    message: MoyeoEmptyText.loading,
                    accessibilityIdentifier: "recruitEdit.state"
                )
            case .failed:
                MoyeoEmptyStateView(
                    message: MoyeoEmptyText.loadFailed,
                    onRetry: { Task { await load() } },
                    accessibilityIdentifier: "recruitEdit.state"
                )
            case .empty:
                MoyeoEmptyStateView(
                    message: "모집 중인 내 모임만 수정할 수 있어요.",
                    accessibilityIdentifier: "recruitEdit.state"
                )
            case .ready:
                if let room { form(room) }
            }
        }
        .task { await load() }
        // 숫자 키패드에는 Return 이 없어 참가비 칸을 누르면 키보드를 닫을 길이 없었다 (IOS-F136).
        .moyeoKeyboardDismissable()
        .onChange(of: startDate) { _, _ in clearValidation() }
        .onChange(of: endDate) { _, _ in clearValidation() }
        .onChange(of: deadlineDate) { _, _ in clearValidation() }
        .onChange(of: dayTripStart) { _, _ in clearValidation() }
        .onChange(of: dayTripEnd) { _, _ in clearValidation() }
        .onChange(of: minimumParticipants) { _, _ in clearValidation() }
        .onChange(of: maximumParticipants) { _, _ in clearValidation() }
        .onChange(of: isDayTrip) { _, _ in clearValidation() }
        .attachComposerFailureAlert(sendState)
        .navigationDestination(item: $courseTitleEditRoomID) { id in
            CourseTitleEditView(roomID: id)
        }
        .navigationDestination(item: $tripStatusRoomID) { id in
            TripStatusView(roomID: id)
        }
    }

    private func form(_ room: ServerChatRoomDetail) -> some View {
        AttachComposerFrame(
            title: "모집 내용 수정",
            cta: "수정 저장",
            isCTAEnabled: !title.trimmingCharacters(in: .whitespaces).isEmpty && !sendState.isSending,
            warning: validationMessage,
            identifier: "recruitEdit",
            onSend: save
        ) {
            // 문구는 네 표면이 **한 문단으로 같게** 쓴다 (기획 기준).
            // 두 줄로 쪼갰더니 iOS 만 불릿 두 개로 보여 4열 비교에서 눈에 걸렸다.
            AttachNoteBox(lines: [
                "모집 중이라 아직 고칠 수 있어요. 여행을 확정하면 더는 고칠 수 없어요 — "
                    + "이미 신청한 분의 약속이 달라지니까요."
            ])

            AttachFieldLabel(text: "모집 제목", isRequired: true, isFirst: true)
            RecruitEditField(
                text: $title,
                limit: Self.titleLimit,
                hint: "\(Self.titleLimit)자까지",
                isMultiline: false,
                identifier: "recruitEdit.title"
            )

            AttachFieldLabel(text: "소개")
            RecruitEditField(
                text: $descriptionText,
                limit: Self.descriptionLimit,
                hint: "\(Self.descriptionLimit.formatted(.number.grouping(.automatic)))자까지",
                isMultiline: true,
                identifier: "recruitEdit.description"
            )

            AttachFieldLabel(text: "대표 사진")
            thumbnailRow

            AttachFieldLabel(text: "여행 유형", isRequired: true)
            HStack(spacing: 8) {
                tripTypeButton("당일치기", isSelected: isDayTrip) { isDayTrip = true }
                tripTypeButton("1박 이상", isSelected: !isDayTrip) { isDayTrip = false }
            }
            Text("당일치기는 시작·종료 시각을, 1박 이상은 종료 날짜를 받아요")
                .font(MoyeoTypography.tinyMeta)
                .foregroundStyle(MoyeoTheme.text400)
                .padding(.top, 6)

            readOnlySections(room)
        }
    }

    /// 서버가 검증까지 하는 값들 + 안내 + 취소 안내.
    /// `form` 이 80줄 제한을 넘어 여기로 나눴다 — 화면 순서는 그대로다.
    @ViewBuilder
    private func readOnlySections(_ room: ServerChatRoomDetail) -> some View {
            AttachFieldLabel(text: "여행 날짜", isRequired: true)
            RecruitEditScheduleFields(
                isDayTrip: isDayTrip,
                startDate: $startDate,
                endDate: $endDate,
                dayTripStart: $dayTripStart,
                dayTripEnd: $dayTripEnd
            )

            AttachFieldLabel(text: "모집 마감일", isRequired: true)
            RecruitEditDateRow(
                label: "모집 마감일",
                date: $deadlineDate,
                hint: "여행 날짜보다 앞이어야 해요",
                identifier: "recruitEdit.deadline"
            )

            AttachFieldLabel(text: "인원", isRequired: true)
            RecruitEditParticipantsFields(
                minimum: $minimumParticipants,
                maximum: $maximumParticipants,
                participantCount: room.participantCount
            )

            AttachFieldLabel(text: "참가비")
            RecruitEditNumberRow(
                text: $participationFeeText,
                suffix: "원",
                maxDigits: 7,
                hint: "0원이면 “무료”로 보여요",
                identifier: "recruitEdit.fee"
            )

            RecruitEditCourseAndCancelSections(
                courseTitle: room.courseTitle,
                isCustomCourse: isCustomCourse,
                onEditCourseTitle: { courseTitleEditRoomID = roomID },
                onOpenTripStatus: { tripStatusRoomID = roomID }
            )
    }

    private func tripTypeButton(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .heavy : .semibold))
                .foregroundStyle(isSelected ? MoyeoTheme.forest : MoyeoTheme.text700)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isSelected ? MoyeoTheme.leaf : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? MoyeoTheme.forest : MoyeoTheme.line)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func participantsText(_ room: ServerChatRoomDetail) -> String {
        let minimum = room.minimumParticipants.map(String.init) ?? "-"
        return "최소 \(minimum)명 · 최대 \(room.maxParticipants)명 (지금 \(room.participantCount)명 참여 중)"
    }

    /// 날짜는 「2026.10.24 (토)」 꼴이다 — 기획이 그렇게 쓴다.
    /// 예전에는 서버 값(`2026-10-24`)을 그대로 찍어 요일이 없고 구분자도 달랐다 (18-6, 2026-09-09).
    private func scheduleText(_ room: ServerChatRoomDetail) -> String {
        if isDayTrip {
            let start = (room.dayTripStartTime ?? "").prefix(5)
            let end = (room.dayTripEndTime ?? "").prefix(5)
            return "\(ServerTripMapper.displayDate(room.startDate)) · \(start) – \(end)"
        }
        let end = room.endDate.map { ServerTripMapper.displayDate($0) } ?? ""
        return "\(ServerTripMapper.displayDate(room.startDate)) – \(end)"
    }

    private func load() async {
        loadState = .loading
        guard MoyeoServerSync.isEnabled else {
            loadState = .empty
            return
        }
        guard let detail = try? await ChatRoomAPIClient.shared.detail(roomID: roomID),
              let me = try? await UserProfileAPIClient.shared.myProfile() else {
            loadState = .failed
            return
        }
        // 모집 중인 내 방만 고칠 수 있다 — 아니면 화면을 내지 않는다(죽은 버튼을 두지 않는다).
        guard let myUserID = me.userId, detail.hostId == myUserID, detail.status == "RECRUITING" else {
            loadState = .empty
            return
        }
        // 코스 종류는 별도 엔드포인트다. 실패하면 **고칠 수 있다고 말하지 않는다**(버튼을 그리지 않는다) —
        // 열어 봤더니 빈 화면이더라, 가 IOS-F131 그 자체였다.
        let roomCourse = try? await TravelCourseAPIClient.shared.roomCourse(roomID: roomID)
        isCustomCourse = roomCourse?.course?.type == "CUSTOM"
        room = detail
        title = detail.title
        descriptionText = String((detail.description ?? "").prefix(Self.descriptionLimit))
        isDayTrip = detail.tripType == "DAY_TRIP"
        startDate = RecruitEditDates.date(detail.startDate) ?? Date()
        endDate = detail.endDate.flatMap { RecruitEditDates.date($0) } ?? startDate.addingTimeInterval(86_400)
        deadlineDate = RecruitEditDates.date(detail.recruitmentDeadlineDate) ?? startDate
        dayTripStart = RecruitEditDates.time(detail.dayTripStartTime) ?? RecruitEditDates.time("09:00:00") ?? Date()
        dayTripEnd = RecruitEditDates.time(detail.dayTripEndTime) ?? RecruitEditDates.time("18:00:00") ?? Date()
        minimumParticipants = detail.minimumParticipants ?? 3
        maximumParticipants = detail.maxParticipants
        // 0 원이면 **빈 칸으로 둔다** — 「0」을 채워 두면 그 앞에 숫자가 끼어든다(IOS-F126).
        participationFeeText = (detail.participationFee ?? 0) == 0 ? "" : String(detail.participationFee ?? 0)
        loadState = .ready
    }

    /// 서버와 같은 규칙으로 먼저 잡고, 어디가 틀렸는지 한국어로 말한다.
    /// 400 을 받아 「요청이 올바르지 않습니다」로 넘기면 무엇을 고쳐야 할지 알 수 없다.
    private func validationError(_ room: ServerChatRoomDetail) -> String? {
        if title.trimmingCharacters(in: .whitespaces).isEmpty { return "모집 제목을 적어 주세요." }
        if RecruitEditDates.isoDay(deadlineDate) > RecruitEditDates.isoDay(startDate) {
            return "모집 마감일은 여행 날짜보다 앞이어야 해요."
        }
        if isDayTrip {
            if RecruitEditDates.isoTime(dayTripStart) >= RecruitEditDates.isoTime(dayTripEnd) {
                return "종료 시각은 시작 시각보다 뒤여야 해요."
            }
        } else if RecruitEditDates.isoDay(endDate) <= RecruitEditDates.isoDay(startDate) {
            return "종료 날짜는 여행 시작 날짜보다 뒤여야 해요."
        }
        if minimumParticipants > maximumParticipants { return "최소 인원이 최대 인원보다 많아요." }
        if maximumParticipants < room.participantCount {
            return "이미 \(room.participantCount)명이 참여 중이라 최대 인원을 그보다 적게 줄일 수 없어요."
        }
        return nil
    }

    /// 값이 바뀌면 지난 경고를 지운다 — 고쳤는데도 문구가 남아 있으면 아직 막힌 줄 안다.
    private func clearValidation() {
        if !validationMessage.isEmpty { validationMessage = "" }
    }

    private func save() {
        guard let room else { return }
        if let invalid = validationError(room) {
            validationMessage = invalid
            return
        }
        validationMessage = ""
        let request = ServerUpdateChatRoomRequest(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
            tripType: isDayTrip ? "DAY_TRIP" : "OVERNIGHT",
            minimumParticipants: minimumParticipants,
            maxParticipants: maximumParticipants,
            startDate: RecruitEditDates.isoDay(startDate),
            // 여행 유형에 따라 **반대쪽 값은 반드시 비워 보낸다** — 둘 다 차 있으면 서버가 거절한다.
            endDate: isDayTrip ? nil : RecruitEditDates.isoDay(endDate),
            recruitmentDeadlineDate: RecruitEditDates.isoDay(deadlineDate),
            dayTripStartTime: isDayTrip ? RecruitEditDates.isoTime(dayTripStart) : nil,
            dayTripEndTime: isDayTrip ? RecruitEditDates.isoTime(dayTripEnd) : nil,
            participationFee: Int64(participationFeeText) ?? 0 // 빈 칸은 무료(0원)다
        )
        // JPEG 로 줄여 보낸다 — 서버가 최대 FHD WebP 로 다시 변환한다(BE 회신 §4).
        let thumbnail = thumbnailImage
            .flatMap { $0.jpegData(compressionQuality: 0.9) }
            .map { MoyeoMultipartFile(partName: "thumbnail", fileName: "thumbnail.jpg", mimeType: "image/jpeg", data: $0) }
        sendState.send(fallbackMessage: "모집 정보를 수정하지 못했어요.") {
            try await ChatRoomWriteAPIClient.shared.updateRoom(roomID: roomID, request: request, thumbnail: thumbnail)
        } onSuccess: {
            dismiss()
        }
    }
}

/// 고칠 수 있는 한 줄 입력. 글자 수 표시와 한도 자르기를 함께 둔다.
struct RecruitEditField: View {
    @Binding var text: String
    let limit: Int
    let hint: String
    let isMultiline: Bool
    let identifier: String
    /// 한도를 넘으면 **자르는 대신 알리기만** 한다.
    ///
    /// 서버에서 불러온 값이 화면 한도보다 길 수 있다. 그때 잘라 버리면
    /// **사용자가 손대지도 않은 이름이 잘려 저장된다** (W-124 · AND-111).
    /// 모집 제목은 화면·서버가 모두 100자라 이제 그 어긋남이 없다 (2026-09-14 결정 ②).
    /// 넘친 것을 카운터가 빨갛게 말하고, 저장은 호출부가 막는다.
    var truncatesOverflow = true

    private var isOverflowing: Bool { !truncatesOverflow && text.count > limit }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .trailing, spacing: 0) {
                if isMultiline {
                    TextEditor(text: $text)
                        .font(.subheadline)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 92)
                        .accessibilityIdentifier(identifier)
                } else {
                    TextField("", text: $text)
                        .font(.subheadline)
                        .textFieldStyle(.plain)
                        .frame(height: 22)
                        .accessibilityIdentifier(identifier)
                }
                Text(isOverflowing ? "\(text.count)/\(limit) · \(text.count - limit)자 넘었어요" : "\(text.count)/\(limit)")
                    .font(MoyeoTypography.tinyMeta)
                    .monospacedDigit()
                    .foregroundStyle(isOverflowing ? MoyeoTheme.dangerRed : MoyeoTheme.text400)
            }
            .padding(12)
            .background(MoyeoTheme.card)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onChange(of: text) { _, value in
                if truncatesOverflow, value.count > limit { text = String(value.prefix(limit)) }
            }

            Text(hint)
                .font(MoyeoTypography.tinyMeta)
                .foregroundStyle(MoyeoTheme.text400)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// 지금 값을 보여주기만 하는 줄. 잠긴 것은 이유를 함께 적는다 — 감추면 "왜 없지?" 로 남는다.
struct RecruitEditLockedRow: View {
    let label: String
    let value: String
    let hint: String
    var isLocked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 12.5, weight: .heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                if isLocked {
                    Image(systemName: "lock")
                        .font(.system(size: 13))
                        .foregroundStyle(MoyeoTheme.text400)
                }
            }
            Text(value)
                .font(.subheadline)
                .foregroundStyle(isLocked ? MoyeoTheme.muted : MoyeoTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                .padding(.horizontal, 12)
                .background(isLocked ? MoyeoTheme.subtleBackground : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isLocked ? MoyeoTheme.softLine : MoyeoTheme.line)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(hint)
                .font(MoyeoTypography.tinyMeta)
                .foregroundStyle(MoyeoTheme.text400)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 16)
    }
}

private extension RecruitEditView {
    /// 지금 사진(또는 새로 고른 사진) + 「사진 바꾸기」.
    /// 기획·웹·안드로이드가 같은 배치를 쓴다 — 미리보기 왼쪽, 알약 버튼 오른쪽.
    /// 안내 문구는 두지 않는다 — 안 바꾸면 그대로라는 건 설명할 필요가 없고,
    /// 새로 고른 건 미리보기 위 배지로 보인다.
    var thumbnailRow: some View {
        HStack(spacing: 12) {
            thumbnailPreview
                .frame(width: 104, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MoyeoTheme.line)
                )
                .overlay(alignment: .bottomLeading) {
                    if thumbnailImage != nil {
                        Text("새 사진")
                            .font(MoyeoTypography.font(size: 10, weight: .bold, relativeTo: .caption2))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(MoyeoTheme.leaf, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .padding(6)
                    }
                }

            PhotosPicker(selection: $pickedThumbnail, matching: .images) {
                Label("사진 바꾸기", systemImage: "camera")
                    .font(MoyeoTypography.font(size: 13, weight: .bold, relativeTo: .subheadline))
                    .foregroundStyle(MoyeoTheme.ink)
                    .padding(.horizontal, 18)
                    .frame(height: 42)
                    .background(MoyeoTheme.subtleBackground)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(MoyeoTheme.line))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("recruitEdit.pickThumbnail")

            Spacer(minLength: 0)
        }
        .onChange(of: pickedThumbnail) { _, item in
            Task { await loadThumbnail(item) }
        }
    }

    @ViewBuilder
    var thumbnailPreview: some View {
        if let thumbnailImage {
            Image(uiImage: thumbnailImage)
                .resizable()
                .scaledToFill()
        } else if let url = MoyeoImageURL.resolve(room?.thumbnail) {
            CachedRemoteImage(url: url, fallbackShape: .landscape) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                MoyeoTheme.subtleBackground
            }
        } else {
            // 서버 썸네일이 없으면 공용 플레이스홀더 — 색 타일을 지어내지 않는다.
            MoyeoPlaceholderImageView(shape: .landscape)
        }
    }

    /// 고른 사진을 읽어 온다. 읽지 못하면 **바꾸지 않은 것으로 둔다** — 대체 이미지를 만들지 않는다.
    func loadThumbnail(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        thumbnailImage = image
    }
}
