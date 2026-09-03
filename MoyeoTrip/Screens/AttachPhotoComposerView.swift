//
//  AttachPhotoComposerView.swift
//  MoyeoTrip
//
//  20-2a 사진 보내기. 정본 `ATTACH-COMPOSER-CANON.md` R1·R2.
//
//  기획의 "최근 사진" 격자는 웹 프로토타입의 그림이다. iOS 는 사진 라이브러리를
//  통째로 읽는 대신 시스템 사진 선택기를 쓴다 — 전체 접근 권한을 요구하지 않고도
//  같은 결과(1장 고르기)를 낸다. 고른 사진을 **크게 먼저** 보여주는 R2 는 그대로다.
//

import PhotosUI
import SwiftUI

struct AttachPhotoComposerView: View {
    let roomID: Int64
    let onSent: () -> Void

    @StateObject private var sendState = AttachComposerSendState()
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var pickedImage: Image?
    @State private var pixelSizeText = ""

    /// 20MB 를 넘으면 보내지 않는다 — 기획 문구("최대 20MB · 1장씩 전송")와 같은 한도다.
    private var isOversize: Bool {
        (photoData?.count ?? 0) > ServerChatShareLimits.maximumPhotoBytes
    }

    private var canSend: Bool {
        photoData != nil && !isOversize && !sendState.isSending
    }

    var body: some View {
        AttachComposerFrame(
            title: "사진 보내기",
            hint: "한 번에 1장씩 보내요. 20MB 까지 올릴 수 있어요.",
            cta: "이 사진 보내기",
            isCTAEnabled: canSend,
            identifier: "attachPhoto",
            onSend: send
        ) {
            preview
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(
                    photoData == nil ? "사진 고르기" : "다른 사진 고르기",
                    systemImage: "photo.on.rectangle"
                )
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(MoyeoTheme.forest)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.forest))
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .accessibilityIdentifier("attachPhoto.pick")

            if isOversize {
                Text("사진은 최대 20MB까지 보낼 수 있어요.")
                    .font(MoyeoTypography.tinyMeta)
                    .foregroundStyle(MoyeoTheme.warningText)
                    .padding(.top, 10)
                    .accessibilityIdentifier("attachPhoto.oversize")
            }

            AttachNoteBox(lines: [
                "보낸 사진은 채팅방 사이드 메뉴의 공유 항목에 모여요.",
                "20MB 를 넘으면 보내기 전에 알려드려요."
            ])
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            loadPhoto(item)
        }
        .attachComposerFailureAlert(sendState)
    }

    /// R2 — 고른 사진을 크게 먼저. 아직 고르지 않았으면 자리를 지어내지 않는다.
    @ViewBuilder
    private var preview: some View {
        if let pickedImage {
            pickedImage
                .resizable()
                .scaledToFill()
                .frame(height: 188)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .bottomTrailing) {
                    Text(sizeBadgeText)
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Capsule())
                        .padding(10)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(MoyeoTheme.softLine))
                .accessibilityIdentifier("attachPhoto.preview")
        } else {
            MoyeoEmptyStateView(
                message: "보낼 사진을 골라주세요.",
                systemImage: "photo",
                accessibilityIdentifier: "attachPhoto.preview.empty"
            )
        }
    }

    /// 파일 크기와 픽셀 크기 — 둘 다 고른 사진에서 실제로 읽은 값이다.
    private var sizeBadgeText: String {
        guard let photoData else { return "" }
        let megabytes = Double(photoData.count) / (1024 * 1024)
        let size = String(format: "%.1fMB", megabytes)
        return pixelSizeText.isEmpty ? size : "\(size) · \(pixelSizeText)"
    }

    private func loadPhoto(_ item: PhotosPickerItem) {
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                sendState.failureMessage = "사진을 읽지 못했어요."
                return
            }
            photoData = data
            if let uiImage = UIImage(data: data) {
                pickedImage = Image(uiImage: uiImage)
                let width = Int(uiImage.size.width * uiImage.scale)
                let height = Int(uiImage.size.height * uiImage.scale)
                pixelSizeText = "\(width)×\(height)"
            } else {
                pickedImage = nil
                pixelSizeText = ""
            }
        }
    }

    private func send() {
        guard let photoData else { return }
        sendState.send(fallbackMessage: "사진을 공유하지 못했어요.") {
            _ = try await ChatRoomWriteAPIClient.shared.shareImage(roomID: roomID, imageData: photoData)
        } onSuccess: { onSent() }
    }
}
