//
//  AttachMapComposerView.swift
//  MoyeoTrip
//
//  20-2c 만날 위치 보내기. 정본 `ATTACH-COMPOSER-CANON.md` R1·R3.
//
//  20-2b 장소 카드와 **다른 화면**이다 — 저쪽은 이름 있는 관광 콘텐츠, 이쪽은 좌표 한 점이다.
//
//  지도는 **실제 카카오 지도**다 (`MoyeoMapView`). 손으로 그린 지도·마스코트 타일을 두지 않는다
//  (NO-MOCK-CANON R4). 좌표를 모르면 지도를 아예 그리지 않고 CTA 를 잠근다.
//
//  ⚠️ 서버 제약: `POST /chat-rooms/{roomId}/messages/locations` 는 **본문이 없다.**
//  서버가 호스트가 등록한 집합 좌표를 그대로 카드로 만든다. 그래서 이 화면은 기획처럼
//  핀을 끌어 임의 좌표를 고르게 하지 않는다 — 끌 수 있게 해두면 화면과 실제로 가는 값이 달라진다.
//  임의 좌표 전송은 BE 요청 대상이다.
//

import SwiftUI

struct AttachMapComposerView: View {
    let roomID: Int64
    let onSent: () -> Void

    @StateObject private var sendState = AttachComposerSendState()
    @State private var detail: ServerChatRoomDetail?
    @State private var isLoading = true

    private var coordinate: MoyeoMapCoordinate? {
        MoyeoMapCoordinate(latitude: detail?.meetingLatitude, longitude: detail?.meetingLongitude)
    }

    var body: some View {
        AttachComposerFrame(
            title: "만날 위치 보내기",
            hint: "호스트가 등록한 집합 장소를 지도 카드로 보내요.",
            cta: "집합 위치 보내기",
            isCTAEnabled: coordinate != nil && !sendState.isSending,
            identifier: "attachMap",
            onSend: send
        ) {
            if isLoading {
                MoyeoEmptyStateView(message: MoyeoEmptyText.loading, accessibilityIdentifier: "attachMap.loading")
            } else if let coordinate {
                mapCard(coordinate)
                meetingSummary(coordinate)
            } else {
                // 집합 좌표가 없으면 지도를 그리지 않는다 (NO-MOCK-CANON R4)
                MoyeoEmptyStateView(
                    message: "집합 장소가 아직 정해지지 않았어요.",
                    systemImage: "mappin.slash",
                    accessibilityIdentifier: "attachMap.empty"
                )
            }

            AttachNoteBox(lines: [
                "받는 사람은 카드를 눌러 지도 앱으로 길찾기를 열 수 있어요.",
                "집합 장소를 바꾸는 건 아니에요. 집합 장소는 호스트가 모집 정보에서 고쳐요."
            ])
        }
        .task {
            guard MoyeoServerSync.isEnabled else {
                isLoading = false
                return
            }
            detail = try? await ChatRoomAPIClient.shared.detail(roomID: roomID)
            isLoading = false
        }
        .attachComposerFailureAlert(sendState)
    }

    private func mapCard(_ coordinate: MoyeoMapCoordinate) -> some View {
        MoyeoMapView(
            content: MoyeoMapContent(
                center: coordinate,
                level: 16,
                markers: [MoyeoMapMarker(id: "attach-meet", coordinate: coordinate)],
                fitsContent: false
            ),
            isInteractive: false
        ) {
            MoyeoTheme.mapGreen
        }
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MoyeoTheme.softLine))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("집합 장소 지도")
        .accessibilityIdentifier("attachMap.preview")
    }

    /// 좌표와 안내는 서버가 준 값만 적는다 — 주소를 지어내지 않는다.
    private func meetingSummary(_ coordinate: MoyeoMapCoordinate) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MoyeoTheme.forest)
            VStack(alignment: .leading, spacing: 3) {
                if let details = detail?.meetingDetails, !details.isEmpty {
                    Text(details)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MoyeoTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude))
                    .font(MoyeoTypography.tinyMeta)
                    .monospacedDigit()
                    .foregroundStyle(MoyeoTheme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoyeoTheme.subtleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.top, 12)
        .accessibilityIdentifier("attachMap.summary")
    }

    private func send() {
        sendState.send(fallbackMessage: "만날 위치를 공유하지 못했어요.") {
            _ = try await ChatRoomWriteAPIClient.shared.shareMeetingLocation(roomID: roomID)
        } onSuccess: { onSent() }
    }
}
