//
//  SearchCourseResults.swift
//  MoyeoTrip
//
//  12-1 검색 결과의 **코스 탭**. 정본 `ATTACH-COMPOSER-CANON.md` R6~R9.
//
//  근거 API: `GET /api/v1/travel-courses/search?keyword=` — 제목에 포함되거나
//  태그명이 일치하는 공개 코스를 준다. 소개글은 검색 대상이 아니다.
//
//  카드는 `TravelCourseInformationResponse` 가 주는 필드만 그린다 (R7).
//  `averageRating` 이 null 이면 별점을 지어내지 않고 `평가 없음` 으로 적는다 (R8).
//

import SwiftUI

/// 12-1 결과 탭 — 코스 / 모집.
enum SearchResultTab: String, CaseIterable, Identifiable {
    case course
    case room

    var id: String { rawValue }

    var label: String {
        switch self {
        case .course: "코스"
        case .room: "모집"
        }
    }
}

struct SearchResultTabBar: View {
    @Binding var selection: SearchResultTab
    let courseCount: Int
    let roomCount: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SearchResultTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 8) {
                        Text("\(tab.label) \(count(for: tab))")
                            .font(MoyeoTypography.tab)
                            .monospacedDigit()
                            .foregroundStyle(selection == tab ? MoyeoTheme.forest : MoyeoTheme.muted)
                        Rectangle()
                            .fill(selection == tab ? MoyeoTheme.forest : .clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 42)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("search.tab.\(tab.id)")
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(MoyeoTheme.softLine).frame(height: 1) }
    }

    private func count(for tab: SearchResultTab) -> Int {
        tab == .course ? courseCount : roomCount
    }
}

/// 12-1 코스 결과 카드. 서버가 준 값만 그린다 (R7).
struct SearchCourseResultRow: View {
    let course: ServerTravelCourse
    /// 카드 본문을 누르면 14 코스 상세로 간다.
    var onOpen: () -> Void = {}

    var body: some View {
        // 기획 원본(`screens-attach.jsx` `ScreenSearchResults`)·안드로이드·웹과 같은 2단 구조다.
        // 오른쪽 칼럼이 제목 / 소요·거리·방문지 / 태그+별점 3줄이고 썸네일 아래에는 아무것도 없다.
        // 태그를 썸네일 밑에 따로 붙이면 카드가 그만큼 높아진다 (iOS 만 그랬다).
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 11) {
                CachedRemoteImage(url: course.thumbnailURL, fallbackShape: .square) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    MoyeoTheme.leaf
                }
                .frame(width: 74, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 0) {
                    Text(course.title)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Text(metaText)
                        .font(MoyeoTypography.tinyMeta)
                        .monospacedDigit()
                        .foregroundStyle(MoyeoTheme.muted)
                        .padding(.top, 5)
                    HStack(spacing: 5) {
                        ForEach(course.tags.prefix(2), id: \.tagId) { tag in
                            tagChip(tag)
                        }
                        Spacer(minLength: 0)
                        rating
                    }
                    .padding(.top, 7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(course.title)
        .accessibilityIdentifier("search.course.\(course.courseId)")
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 태그 칩은 **표시 전용**이다 — "태그로 모임 찾기" 는 없는 기능이다(2026-08-31 사용자 확인).
    private func tagChip(_ tag: ServerCourseTag) -> some View {
        Text(tag.name)
            .font(.caption2.weight(.bold))
            .foregroundStyle(MoyeoTheme.text700)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(MoyeoTheme.subtleBackground)
            .clipShape(Capsule())
    }

    /// 서버가 주는 소요 시간 · 거리 · 방문지 수만 적는다.
    private var metaText: String {
        [
            course.travelTime,
            ServerCourseMapper.distanceText(course.distanceKm),
            "\(course.places.count)곳"
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    }

    /// R8 — 평가가 없으면 별점을 지어내지 않는다.
    @ViewBuilder
    private var rating: some View {
        if let average = course.averageRating {
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MoyeoTheme.sunrise)
                Text(String(format: "%.1f", average))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.text700)
                Text("(\(course.ratingCount))")
                    .font(.caption2)
                    .foregroundStyle(MoyeoTheme.text400)
            }
            .monospacedDigit()
        } else {
            Text("평가 없음")
                .font(.caption2)
                .foregroundStyle(MoyeoTheme.text400)
        }
    }
}
