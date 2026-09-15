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
    /// 사진과 함께 보내는 한 줄. 서버가 `caption` 파트로 받는다(선택) — 웹·기획에는 있는데
    /// 앱 둘에만 입력이 없어서 같은 화면이 플랫폼마다 달랐다 (2026-09-09 전수 확인).
    @State private var caption = ""

    /// 20MB 를 넘으면 보내지 않는다 — 기획 문구("최대 20MB · 1장씩 전송")와 같은 한도다.
    private var isOversize: Bool {
        (photoData?.count ?? 0) > ServerChatShareLimits.maximumPhotoBytes
    }

    /// 한 줄 설명이 한도를 넘었는지. 안드로이드와 같이 **자르지 않고** 넘쳤다는 것만 보여주고
    /// 보내기를 막는다 — 사용자가 쓴 글을 말없이 지우지 않는다 (TC ATTACH-016).
    private var isCaptionOverLimit: Bool {
        caption.count > ServerChatShareLimits.maximumPhotoCaptionLength
    }

    private var canSend: Bool {
        photoData != nil && !isOversize && !isCaptionOverLimit && !sendState.isSending
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
            // 아직 고르지 않았으면 **고르는 자리 자체가 점선 박스**다 (기획·웹·안드로이드와 같은 구조).
            // 예전에는 빈 상태 안내 + 아래에 작은 초록 테두리 버튼이어서 iOS 만 생김새가 달랐다.
            if photoData == nil {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    VStack(spacing: 6) {
                        Image(systemName: "camera")
                            .font(.system(size: 26))
                            .foregroundStyle(MoyeoTheme.forest)
                        Text("사진 고르기")
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(MoyeoTheme.ink)
                        Text("기기에 저장된 사진에서 1장을 골라주세요.")
                            .font(MoyeoTypography.tinyMeta)
                            .foregroundStyle(MoyeoTheme.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 188)
                    .background(MoyeoTheme.subtleBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(MoyeoTheme.line, style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("attachPhoto.pick")
            } else {
                preview
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Text("다른 사진 고르기")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.forest)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
                .accessibilityIdentifier("attachPhoto.pick")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("같이 보낼 한 줄 (선택)")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                TextField("사진 설명을 적어주세요", text: $caption)
                    .textFieldStyle(.plain)
                    .font(MoyeoTypography.cardBody)
                    .padding(.horizontal, 13)
                    .frame(height: 46)
                    .background(MoyeoTheme.card)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("attachPhoto.caption")
                if !caption.isEmpty {
                    Text(
                        isCaptionOverLimit
                            ? "\(caption.count)/\(ServerChatShareLimits.maximumPhotoCaptionLength) · "
                                + "\(caption.count - ServerChatShareLimits.maximumPhotoCaptionLength)자 넘었어요"
                            : "\(caption.count)/\(ServerChatShareLimits.maximumPhotoCaptionLength)"
                    )
                    .font(MoyeoTypography.tinyMeta)
                    .foregroundStyle(isCaptionOverLimit ? MoyeoTheme.warningText : MoyeoTheme.muted)
                    .monospacedDigit()
                    .accessibilityIdentifier("attachPhoto.captionCount")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)

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
        .attachComposerFailureAlert(sendState, dismissesOnSuccess: true)
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
        }
        // 아직 고르지 않은 상태는 위의 **점선 고르기 박스**가 대신한다 —
        // 빈 상태 안내를 따로 두면 「고를 자리」가 두 군데로 보인다.
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
            _ = try await ChatRoomWriteAPIClient.shared.shareImage(
                roomID: roomID,
                imageData: photoData,
                caption: caption.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } onSuccess: { onSent() }
    }
}
