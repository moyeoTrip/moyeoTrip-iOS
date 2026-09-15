//
//  CourseDetailComponents.swift
//  MoyeoTrip
//
//  14 코스 상세의 아래쪽 구성요소. `CourseDetailView.swift` 가 500줄을 넘어 갈라냈다.
//

import MapKit
import SwiftUI

/// 14 코스 미리보기 — 방문지 좌표를 실제 카카오 지도에 순번 마커 + 경로선으로 그린다.
/// 좌표가 없는 방문지가 하나라도 있으면 그리지 않는다 (NO-MOCK-CANON R4).
struct CourseRouteMap: View {
    let stops: [ItineraryStop]

    private var routeMarkers: [MoyeoMapMarker] {
        stops.compactMap { stop in
            guard let coordinate = MoyeoMapCoordinate(latitude: stop.latitude, longitude: stop.longitude) else {
                return nil
            }
            return MoyeoMapMarker(id: stop.id, coordinate: coordinate, order: stop.order)
        }
    }

    var body: some View {
        let markers = routeMarkers
        if markers.count == stops.count, let first = markers.first {
            MoyeoMapView(
                content: MoyeoMapContent(
                    center: first.coordinate,
                    level: 11,
                    markers: markers,
                    polyline: markers.map(\.coordinate)
                ),
                isInteractive: false,
                fallback: { MoyeoMapUnavailableView(message: "지도를 불러오지 못했어요. 아래 방문지 목록으로 코스를 볼 수 있어요.") }
            )
            .frame(height: 146)
            .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("코스 경로 지도, 방문지 \(stops.count)곳")
            .accessibilityIdentifier("course.route.preview")
        }
    }
}

struct CourseDetailBottomBar: View {
    let onCreateRecruitment: () -> Void
    let onOpenRecruitments: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onCreateRecruitment) {
                Text("이 코스로 모집 만들기")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.forest)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(MoyeoTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                            .stroke(MoyeoTheme.forest, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            Button(action: onOpenRecruitments) {
                Text("모집 중인 모임 보기")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(MoyeoTheme.forest)
                    .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("course.detail.recruitments")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(MoyeoTheme.card)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MoyeoTheme.softLine)
                .frame(height: 1)
        }
    }
}

struct DetailPanel<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    // 섹션을 카드로 감싸지 않는다 — 화면기획은 제목과 내용만 배경 위에 둔다
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(MoyeoTypography.font(size: 15, weight: .bold, relativeTo: .headline))
                .foregroundStyle(MoyeoTheme.ink)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }
}

/// 14 방문지 한 줄 — 순번 · 이름 · `N일차 · HH:mm`.
///
/// 기획·웹·안드로이드가 같은 모양이다. 서버가 안 준 값(시각 등)은 **그 자리를 비운다**.
struct CourseStopRow: View {
    let stop: ItineraryStop
    /// 방문지 상세로 가는 길. `contentId` 가 없는 방문지에는 **넘기지 않는다** —
    /// 갈 곳이 없는데 누르는 모양을 주면 그게 죽은 UI 다.
    var onSelect: ((String) -> Void)?

    /// 서버 `contentId`. 빈 문자열은 없는 것과 같다.
    private var placeID: String? {
        guard let id = stop.placeID?.trimmingCharacters(in: .whitespaces), !id.isEmpty else { return nil }
        return id
    }

    var body: some View {
        if let onSelect, let placeID {
            // 코스 상세가 `placeID` 를 **매핑해 두고 쓰지 않아**, 방문지를 눌러도
            // 장소 상세로 갈 수 없었다 (웹 교차 발견 2026-09-14).
            Button { onSelect(placeID) } label: {
                row(isActionable: true)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("course.stop.\(placeID)")
        } else {
            row(isActionable: false)
        }
    }

    private func row(isActionable: Bool) -> some View {
        HStack(spacing: 12) {
            Text("\(stop.order)")
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.forest)
                .frame(width: 26, height: 26)
                .background(MoyeoTheme.leaf)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(stop.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MoyeoTheme.ink)
                    .lineLimit(1)
                let meta = [stop.day > 0 ? "\(stop.day)일차" : nil, stop.time.isEmpty ? nil : stop.time]
                    .compactMap { $0 }
                    .joined(separator: " · ")
                if !meta.isEmpty {
                    Text(meta)
                        .font(MoyeoTypography.tinyMeta)
                        .foregroundStyle(MoyeoTheme.muted)
                }
            }
            Spacer(minLength: 0)
            if isActionable {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(MoyeoTheme.text400)
            }
        }
        .padding(.vertical, 4)
        .frame(minHeight: isActionable ? 44 : 0)
        .contentShape(Rectangle())
    }
}
