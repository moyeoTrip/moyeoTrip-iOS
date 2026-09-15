//
//  RecruitmentThumbnailPicker.swift
//  MoyeoTrip
//
//  17-6 모집 만들기 요약(5/5)의 대표 사진 고르기.
//
//  서버 계약(직접 확인): `ChatRoomController.kt` 의 `@RequestPart("thumbnail")` 에 `required = false`
//  가 없어 **필수**고, `ChatRoomService.validateRequiredThumbnail` 이 빈 파일이면 400 `40041` 이다.
//  즉 파트를 빼면 방이 만들어지지 않는다.
//
//  예전에는 이 단계가 아예 없어서, 사진을 안 고르면 앱이 내장 「이미지 없음」 일러스트를
//  대신 올렸다. 그 결과 목록에 **회색 자리표시자가 진짜 사진인 양** 걸렸고, 정말로 사진이 없는
//  방과 구분할 수 없었다. 자리표시자를 올리느니 고르게 하고, 안 고르면 잠근다.
//
//  배치는 18-6 모집 내용 수정(`RecruitEditView.thumbnailRow`)과 같다 — 92×68 미리보기 + 버튼.
//

import PhotosUI
import SwiftUI

struct RecruitmentThumbnailPicker: View {
    @Binding var image: UIImage?
    @State private var picked: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("대표 사진 *")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)
            HStack(spacing: 10) {
                preview
                    .frame(width: 92, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    PhotosPicker(selection: $picked, matching: .images) {
                        Text(image == nil ? "사진 고르기" : "사진 바꾸기")
                            .font(MoyeoTypography.font(size: 13, weight: .bold, relativeTo: .subheadline))
                            .foregroundStyle(MoyeoTheme.ink)
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background(MoyeoTheme.subtleBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("createSummary.pickThumbnail")

                    Text(image == nil ? "모집 목록과 상세에 이 사진이 보여요" : "목록에 이 사진이 보여요")
                        .font(MoyeoTypography.font(size: 11, relativeTo: .caption2))
                        .foregroundStyle(MoyeoTheme.text400)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .onChange(of: picked) { _, item in
            Task { await load(item) }
        }
    }

    /// 고르기 전에는 **빈 점선 자리**다. 여기에 내장 일러스트를 그리면 그것이 올라갈 사진인 줄 안다.
    @ViewBuilder
    private var preview: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(MoyeoTheme.line)
                .overlay {
                    Image(systemName: "camera")
                        .font(.system(size: 18))
                        .foregroundStyle(MoyeoTheme.text400)
                }
                .accessibilityIdentifier("createSummary.thumbnailEmpty")
        }
    }

    /// 고른 사진을 읽어 온다. 읽지 못하면 **고르지 않은 것으로 둔다** — 대체 이미지를 만들지 않는다.
    private func load(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let loaded = UIImage(data: data) else { return }
        image = loaded
    }
}
