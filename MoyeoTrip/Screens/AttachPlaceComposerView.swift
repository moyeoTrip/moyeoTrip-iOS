//
//  AttachPlaceComposerView.swift
//  MoyeoTrip
//
//  20-2b 장소 카드 보내기. 정본 `ATTACH-COMPOSER-CANON.md` R1·R2·R3.
//
//  17-1a 방문지 검색과 **같은 목록**(`GET /api/v1/tourism-contents`)을 쓰되,
//  코스에 담는 게 아니라 카드 한 장을 방에 보낸다.
//  20-2c 지도와 **다른 화면**이다 — 저쪽은 이름 없는 좌표 한 점이다 (R3).
//
//  목록은 서버 응답만 그린다. 못 받으면 번들 예시 장소로 되돌리지 않는다 (NO-MOCK-CANON R1).
//

import Combine
import SwiftUI

@MainActor
private final class AttachPlaceSearchModel: ObservableObject {
    @Published private(set) var places: [TourismPlace] = []
    @Published private(set) var totalElements: Int?
    @Published private(set) var isLoading = false
    @Published private(set) var didFail = false

    private let service = TourismAPIClient()
    private var loadedKeyword: String?

    func load(keyword: String) async {
        let normalized = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard loadedKeyword != normalized else { return }
        if loadedKeyword != nil {
            try? await Task.sleep(nanoseconds: TourismPlaceSearchModel.searchDebounceNanoseconds)
            guard !Task.isCancelled else { return }
        }
        loadedKeyword = normalized
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await service.places(keyword: normalized, contentTypeID: nil)
            places = page.places
            totalElements = page.totalElements
            didFail = false
        } catch {
            // 실패는 실패로 남긴다 — 예시 장소로 채우면 없는 장소를 보내게 된다
            places = []
            totalElements = nil
            didFail = true
        }
    }
}

struct AttachPlaceComposerView: View {
    let roomID: Int64
    let onSent: () -> Void

    @StateObject private var model = AttachPlaceSearchModel()
    @StateObject private var sendState = AttachComposerSendState()
    @State private var query = ""
    @State private var selectedPlaceID: String?

    private var selectedPlace: TourismPlace? {
        model.places.first { $0.id == selectedPlaceID }
    }

    var body: some View {
        AttachComposerFrame(
            title: "장소 카드 보내기",
            hint: "관광 정보에서 찾은 장소를 카드로 보내요.",
            cta: "이 장소 보내기",
            isCTAEnabled: selectedPlace != nil && !sendState.isSending,
            identifier: "attachPlace",
            onSend: send
        ) {
            searchField
            resultsSection
            if let selectedPlace {
                AttachFieldLabel(text: "이렇게 보내져요")
                    .padding(.top, 18)
                previewCard(selectedPlace)
            }
        }
        .task(id: query) {
            await model.load(keyword: query)
        }
        .attachComposerFailureAlert(sendState)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(MoyeoTheme.muted)
            TextField("장소 이름이나 지역을 검색하세요", text: $query)
                .font(.subheadline)
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(MoyeoTheme.text400)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(MoyeoTheme.subtleBackground)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.softLine))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier("attachPlace.query")
    }

    @ViewBuilder
    private var resultsSection: some View {
        if model.isLoading {
            MoyeoEmptyStateView(message: MoyeoEmptyText.loading, accessibilityIdentifier: "attachPlace.loading")
        } else if model.didFail {
            MoyeoEmptyStateView(
                message: MoyeoEmptyText.loadFailed,
                onRetry: { query += " " },
                accessibilityIdentifier: "attachPlace.failed"
            )
        } else if model.places.isEmpty {
            MoyeoEmptyStateView(
                message: MoyeoEmptyText.noSearchResults,
                accessibilityIdentifier: "attachPlace.empty"
            )
        } else {
            Text("\(model.totalElements ?? model.places.count)곳을 찾았어요")
                .font(MoyeoTypography.tinyMeta)
                .foregroundStyle(MoyeoTheme.muted)
                .monospacedDigit()
                .padding(.top, 12)
                .padding(.bottom, 8)
            VStack(spacing: 8) {
                ForEach(model.places.prefix(30)) { place in
                    resultRow(place)
                }
            }
        }
    }

    private func resultRow(_ place: TourismPlace) -> some View {
        let isPicked = place.id == selectedPlaceID
        return Button {
            selectedPlaceID = place.id
        } label: {
            HStack(spacing: 11) {
                CachedRemoteImage(url: place.thumbnailURL, fallbackShape: .square) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    MoyeoTheme.leaf
                }
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(place.title)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.ink)
                        .lineLimit(1)
                    Text(metaText(place))
                        .font(MoyeoTypography.tinyMeta)
                        .foregroundStyle(MoyeoTheme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if isPicked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(MoyeoTheme.forest)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isPicked ? MoyeoTheme.leaf : MoyeoTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(isPicked ? MoyeoTheme.forest : MoyeoTheme.softLine)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("attachPlace.result.\(place.id)")
    }

    /// 서버가 준 값만 이어 붙인다 — 분류만 있고 주소가 없으면 분류만 남는다.
    private func metaText(_ place: TourismPlace) -> String {
        [place.type.rawValue, place.address ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    /// R2 — 21 특수 메시지의 장소 카드와 같은 생김새.
    private func previewCard(_ place: TourismPlace) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            CachedRemoteImage(url: place.thumbnailURL, fallbackShape: .landscape) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                MoyeoTheme.leaf
            }
            .frame(height: 112)
            .frame(maxWidth: .infinity)
            .clipped()
            VStack(alignment: .leading, spacing: 4) {
                Text(place.title)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                Text(metaText(place))
                    .font(MoyeoTypography.tinyMeta)
                    .foregroundStyle(MoyeoTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .background(MoyeoTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MoyeoTheme.softLine))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityIdentifier("attachPlace.preview")
    }

    private func send() {
        guard let contentID = selectedPlaceID.flatMap(Int64.init) else {
            sendState.failureMessage = "이 장소는 카드로 보낼 수 없어요."
            return
        }
        sendState.send(fallbackMessage: "장소를 공유하지 못했어요.") {
            _ = try await ChatRoomWriteAPIClient.shared.shareTourismContent(roomID: roomID, contentID: contentID)
        } onSuccess: { onSent() }
    }
}
