//
//  MeetingInfoEditView.swift
//  MoyeoTrip
//
//  18-5 집합 정보 수정 (호스트). 정본 `ATTACH-COMPOSER-CANON.md` §6-1.
//
//  모집을 연 뒤 집합 장소·시간을 고칠 길이 없었다. 18 모집 관리에서 고칠 수 있는 건
//  여행 경로뿐이고, 17-3 집합 장소 지정은 모집 **만들기** 단계라 이미 만든 모집에는 못 쓴다.
//
//  근거: `PUT /api/v1/chat-rooms/{roomId}/meeting-info`
//        `{ meetingLatitude, meetingLongitude, meetingDetails, meetingDateTime }`
//  현재 값은 `GET /api/v1/chat-rooms/{roomId}` 가 준다. 좌표가 없으면 지도를 그리지 않는다
//  (NO-MOCK-CANON R4) — 손으로 그린 지도를 대신 두지 않는다.
//
//  **방문지 수정은 여기에 없다.** 코스 편집 API 가 없어 집합 정보만 고친다 (NO-MOCK-CANON §4).
//

import SwiftUI

struct MeetingInfoEditView: View {
    let roomID: Int64

    @Environment(\.dismiss) private var dismiss
    @State private var detail: ServerChatRoomDetail?
    @State private var loadState: TripCompanionsState = .loading
    @State private var coordinate: MoyeoMapCoordinate?
    @State private var meetingDetails = ""
    @State private var meetingDate = Date()
    @StateObject private var sendState = AttachComposerSendState()

    var body: some View {
        AttachComposerFrame(
            title: "집합 정보 수정",
            cta: "집합 정보 저장",
            isCTAEnabled: loadState == .ready && !sendState.isSending,
            identifier: "meetingEdit",
            onSend: save
        ) {
            switch loadState {
            case .loading:
                MoyeoEmptyStateView(
                    message: MoyeoEmptyText.loading,
                    accessibilityIdentifier: "meetingEdit.state"
                )
            case .failed:
                MoyeoEmptyStateView(
                    message: MoyeoEmptyText.loadFailed,
                    onRetry: { Task { await reload() } },
                    accessibilityIdentifier: "meetingEdit.state"
                )
            case .empty:
                MoyeoEmptyStateView(
                    message: MoyeoEmptyText.noRecruitments,
                    accessibilityIdentifier: "meetingEdit.state"
                )
            case .ready:
                editor
            }
        }
        .task { await load() }
        .attachComposerFailureAlert(sendState)
    }

    @ViewBuilder
    private var editor: some View {
        if let coordinate {
            MoyeoMapView(
                content: MoyeoMapContent(center: coordinate, level: 16, fitsContent: false),
                draggablePin: true,
                onPinMove: { moved in self.coordinate = moved },
                fallback: { MoyeoTheme.mapGreen }
            )
            .frame(height: 168)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(MoyeoTheme.softLine))
            .accessibilityLabel("집합 장소 지도")
            .accessibilityIdentifier("meetingEdit.map")

            Text(String(format: "좌표 (자동 저장)   %.6f, %.6f", coordinate.latitude, coordinate.longitude))
                .font(MoyeoTypography.tinyMeta)
                .monospacedDigit()
                .foregroundStyle(MoyeoTheme.text400)
                .padding(.top, 8)
        }

        AttachFieldLabel(text: "안내 문구").padding(.top, 18)
        AttachTextField(
            placeholder: "만나는 위치를 자세히 남겨주세요 (예: 터미널 정문 앞)",
            text: $meetingDetails,
            identifier: "meetingEdit.details"
        )

        AttachFieldLabel(text: "집합 일시").padding(.top, 18)
        DatePicker(
            "집합 일시",
            selection: $meetingDate,
            displayedComponents: [.date, .hourAndMinute]
        )
        .labelsHidden()
        .datePickerStyle(.compact)
        // 앱은 한국어 기준이다 (29 설정 · 언어). 시스템 로케일이 영어면 `Sep 20, 2026` 으로 찍혀
        // 세 플랫폼 표기가 갈린다.
        .environment(\.locale, Locale(identifier: "ko_KR"))
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("meetingEdit.dateTime")

        AttachNoteBox(lines: [
            "고치면 동행자 모두에게 알림이 가요.",
            "고정 공지에 적어둔 집합 안내는 따로 고쳐주세요."
        ])
    }

    private func load() async {
        guard loadState == .loading, detail == nil else { return }
        await reload()
    }

    private func reload() async {
        loadState = .loading
        guard MoyeoServerSync.isEnabled else {
            loadState = .empty
            return
        }
        guard let loaded = try? await ChatRoomAPIClient.shared.detail(roomID: roomID) else {
            loadState = .failed
            return
        }
        detail = loaded
        coordinate = MoyeoMapCoordinate(
            latitude: loaded.meetingLatitude,
            longitude: loaded.meetingLongitude
        )
        meetingDetails = loaded.meetingDetails ?? ""
        meetingDate = MeetingDateTimeFormat.date(from: loaded.meetingDateTime) ?? Date()
        loadState = .ready
    }

    private func save() {
        let request = ServerUpdateMeetingInfoRequest(
            meetingLatitude: coordinate?.latitude,
            meetingLongitude: coordinate?.longitude,
            meetingDetails: meetingDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : meetingDetails.trimmingCharacters(in: .whitespacesAndNewlines),
            meetingDateTime: MeetingDateTimeFormat.string(from: meetingDate)
        )
        sendState.send(fallbackMessage: "집합 정보를 저장하지 못했어요.") {
            try await ChatRoomWriteAPIClient.shared.updateMeetingInfo(roomID: roomID, request: request)
        } onSuccess: {
            dismiss()
        }
    }
}

/// 서버 `meetingDateTime` 은 `yyyy-MM-dd'T'HH:mm:ss` 다 (타임존 없는 로컬 시각).
enum MeetingDateTimeFormat {
    nonisolated static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    nonisolated static func date(from text: String) -> Date? {
        formatter.date(from: text)
    }

    nonisolated static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}
