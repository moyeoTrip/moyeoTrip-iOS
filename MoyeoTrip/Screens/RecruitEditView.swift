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
    /// 새 대표 사진. 고르지 않으면 **파트를 보내지 않아** 서버가 지금 사진을 그대로 둔다
    /// (PATCH 규칙 · BE 회신 §4). 비우는 길은 없다.
    @State private var pickedThumbnail: PhotosPickerItem?
    @State private var thumbnailImage: UIImage?
    @StateObject private var sendState = AttachComposerSendState()

    private static let titleLimit = 24
    private static let descriptionLimit = 1000

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
        .attachComposerFailureAlert(sendState)
    }

    private func form(_ room: ServerChatRoomDetail) -> some View {
        AttachComposerFrame(
            title: "모집 내용 수정",
            cta: "수정 저장",
            isCTAEnabled: !title.trimmingCharacters(in: .whitespaces).isEmpty && !sendState.isSending,
            identifier: "recruitEdit",
            onSend: save
        ) {
            // 문구는 네 표면이 **한 문단으로 같게** 쓴다 (기획 기준).
            // 두 줄로 쪼갰더니 iOS 만 불릿 두 개로 보여 4열 비교에서 눈에 걸렸다.
            AttachNoteBox(lines: [
                "모집 중이라 아직 고칠 수 있어요. 여행을 확정하면 더는 고칠 수 없어요 — "
                    + "이미 신청한 분의 약속이 달라지니까요."
            ])

            AttachFieldLabel(text: "모집 제목", isRequired: true)
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
            // 서버가 검증까지 하는 값들 — 지금 값을 읽기 전용으로 보여주고 이유를 적는다.
            RecruitEditLockedRow(
                label: "여행 날짜",
                value: scheduleText(room),
                hint: "모집 마감일보다 뒤여야 해요"
            )
            RecruitEditLockedRow(
                label: "모집 마감일",
                value: ServerTripMapper.displayDate(room.recruitmentDeadlineDate),
                hint: "여행 날짜보다 앞이어야 해요"
            )
            RecruitEditLockedRow(
                label: "인원",
                value: participantsText(room),
                hint: "최대 인원을 지금 참여 중인 인원보다 적게 줄일 수 없어요"
            )
            RecruitEditLockedRow(
                label: "참가비",
                value: "1인 \((room.participationFee ?? 0).formatted(.number.grouping(.automatic)))원",
                hint: "0원이면 “무료”로 보여요"
            )
            RecruitEditLockedRow(
                label: "연결된 코스",
                value: room.courseTitle ?? "연결된 코스 없음",
                hint: "코스는 여기서 못 고쳐요. 경로는 18-1, 이름과 소개는 18-7 에서 고쳐요.",
                isLocked: true
            )

            AttachNoteBox(lines: [
                "저장하면 채팅방에 “호스트가 모집 정보를 수정했어요.”가 남고 참여자에게 알려요."
            ])

            // 방 삭제는 없다 — 취소로 갈음한다 (BE 회신 §4). 있는 길만 안내한다.
            VStack(alignment: .leading, spacing: 0) {
                Text("모집을 그만두려면")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(MoyeoTheme.ink)
                Text(
                    "모집을 취소하면 참여자에게 알림이 가고 채팅방은 읽기 전용으로 남아요. "
                        + "방을 아예 지우는 건 없어요."
                )
                    .font(MoyeoTypography.tinyMeta)
                    .foregroundStyle(MoyeoTheme.text400)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 5)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
            .padding(.top, 22)
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
        room = detail
        title = detail.title
        descriptionText = detail.description ?? ""
        isDayTrip = detail.tripType == "DAY_TRIP"
        loadState = .ready
    }

    private func save() {
        guard let room else { return }
        let request = ServerUpdateChatRoomRequest(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
            tripType: isDayTrip ? "DAY_TRIP" : "OVERNIGHT",
            minimumParticipants: room.minimumParticipants,
            maxParticipants: room.maxParticipants,
            startDate: room.startDate,
            endDate: isDayTrip ? nil : room.endDate,
            recruitmentDeadlineDate: room.recruitmentDeadlineDate,
            dayTripStartTime: isDayTrip ? room.dayTripStartTime : nil,
            dayTripEndTime: isDayTrip ? room.dayTripEndTime : nil,
            participationFee: room.participationFee
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
                Text("\(text.count)/\(limit)")
                    .font(MoyeoTypography.tinyMeta)
                    .monospacedDigit()
                    .foregroundStyle(MoyeoTheme.text400)
            }
            .padding(12)
            .background(MoyeoTheme.card)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onChange(of: text) { _, value in
                if value.count > limit { text = String(value.prefix(limit)) }
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
    /// 기획·웹·안드로이드가 같은 배치를 쓴다 — 92×68 미리보기 왼쪽, 버튼 오른쪽.
    var thumbnailRow: some View {
        HStack(spacing: 10) {
            thumbnailPreview
                .frame(width: 92, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                PhotosPicker(selection: $pickedThumbnail, matching: .images) {
                    Text("사진 바꾸기")
                        .font(MoyeoTypography.font(size: 13, weight: .bold, relativeTo: .subheadline))
                        .foregroundStyle(MoyeoTheme.ink)
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background(MoyeoTheme.subtleBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("recruitEdit.pickThumbnail")

                Text(thumbnailImage == nil ? "바꾸지 않으면 지금 사진이 그대로 남아요" : "저장하면 이 사진으로 바뀌어요")
                    .font(MoyeoTypography.font(size: 11, relativeTo: .caption2))
                    .foregroundStyle(MoyeoTheme.text400)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
