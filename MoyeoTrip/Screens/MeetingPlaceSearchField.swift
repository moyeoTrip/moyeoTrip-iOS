//
//  MeetingPlaceSearchField.swift
//  MoyeoTrip
//
//  17-3 집합 장소 검색. 검색해 고른 장소의 **이름·주소·좌표**를 그대로 화면에 돌려준다.
//
//  예전에는 17-3 의 검색칸이 글자만 받고 아무 데도 쓰이지 않아, 집합 장소를 정하는 길이
//  「지도를 끌어 핀을 맞추기」뿐이었다. 안드로이드 QA 3회차 AND-112 가 같은 화면에서
//  「고른 장소로 지도가 안 움직인다」고 적은 그 자리다.
//
//  목록은 20-2b 장소 카드와 **같은 서버 목록**(`GET /api/v1/tourism-contents`)이다.
//  못 받으면 예시 장소로 되돌리지 않고 실패를 실패로 그린다 (NO-MOCK-CANON R1).
//

import Combine
import SwiftUI

@MainActor
private final class MeetingPlaceSearchModel: ObservableObject {
    @Published private(set) var places: [TourismPlace] = []
    @Published private(set) var isLoading = false
    @Published private(set) var didFail = false

    private let service = TourismAPIClient()
    private var loadedKeyword: String?

    func load(keyword: String) async {
        let normalized = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard loadedKeyword != normalized else { return }
        // 검색어를 지우면 목록도 지운다 — 지도 위에 지난 결과가 남지 않게 한다.
        guard !normalized.isEmpty else {
            loadedKeyword = normalized
            places = []
            didFail = false
            return
        }
        if loadedKeyword != nil {
            try? await Task.sleep(nanoseconds: TourismPlaceSearchModel.searchDebounceNanoseconds)
            guard !Task.isCancelled else { return }
        }
        loadedKeyword = normalized
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await service.places(keyword: normalized, contentTypeID: nil)
            // 좌표가 없는 콘텐츠는 고를 수 없다 — 골라도 지도를 옮기지 못하고
            // 집합 좌표로 저장할 값도 없다.
            places = page.places.filter { $0.latitude != nil && $0.longitude != nil }
            didFail = false
        } catch {
            places = []
            didFail = true
        }
    }
}

/// 지도 위에 얹는 집합 장소 검색칸. 결과를 고르면 `onSelect` 로 그 장소를 넘긴다.
struct MeetingPlaceSearchField: View {
    let onSelect: (TourismPlace) -> Void

    @StateObject private var model = MeetingPlaceSearchModel()
    @State private var query = ""

    var body: some View {
        VStack(spacing: 8) {
            LabelledSearchField(text: $query, prompt: "장소 검색")
                .accessibilityIdentifier("createMeeting.placeQuery")
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                results
            }
        }
        .task(id: query) {
            await model.load(keyword: query)
        }
    }

    @ViewBuilder
    private var results: some View {
        if model.isLoading {
            resultCard {
                Text(MoyeoEmptyText.loading)
                    .font(.caption)
                    .foregroundStyle(MoyeoTheme.muted)
                    .padding(12)
            }
        } else if model.didFail {
            resultCard {
                Text(MoyeoEmptyText.loadFailed)
                    .font(.caption)
                    .foregroundStyle(MoyeoTheme.muted)
                    .padding(12)
            }
        } else if model.places.isEmpty {
            resultCard {
                Text(MoyeoEmptyText.noSearchResults)
                    .font(.caption)
                    .foregroundStyle(MoyeoTheme.muted)
                    .padding(12)
            }
        } else {
            resultCard {
                // 지도를 다 덮지 않도록 앞쪽 몇 곳만 띄운다. 더 좁히려면 검색어를 고친다.
                VStack(spacing: 0) {
                    ForEach(model.places.prefix(5)) { place in
                        resultRow(place)
                    }
                }
            }
        }
    }

    private func resultRow(_ place: TourismPlace) -> some View {
        Button {
            onSelect(place)
            // 고른 뒤에는 목록을 닫는다 — 지도가 그 자리로 옮겨 간 것을 바로 봐야 한다.
            query = ""
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(place.title)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                    .lineLimit(1)
                // 주소는 서버가 주지 않을 수 있다 — 없으면 그 줄을 그리지 않는다.
                if let address = place.address, !address.isEmpty {
                    Text(address)
                        .font(.caption2)
                        .foregroundStyle(MoyeoTheme.muted)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("createMeeting.placeResult.\(place.id)")
    }

    private func resultCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MoyeoTheme.card)
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(MoyeoTheme.line))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .accessibilityIdentifier("createMeeting.placeResults")
    }
}
