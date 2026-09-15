//
//  CustomCourseStartView.swift
//  MoyeoTrip
//
//  17-1 코스 직접 만들기로 **등록 코스를 불러와** 들어가는 진입.
//

import SwiftUI

/// 코스 id 를 들고 17-1 로 들어왔을 때, 그 코스의 방문지를 담은 에디터를 연다.
///
/// 왜 필요한가: `CustomCourseEditorView` 는 모집 만들기 플로우가 들고 있는 초안에 묶여 있고,
/// 화면으로 **바로 들어가면**(딥링크·QA·캡처) 초안이 없어 늘 빈 에디터였다. 등록 코스를
/// 출발점으로 고쳐 쓰는 진입이라 17-2(코스 연동)와 다르다 — 여기서 고친 코스는 새 커스텀 코스다.
///
/// 담기는 값은 **서버가 준 방문지**(이름 · 방문 시각 · 일차 · 좌표)뿐이다.
/// 코스 id 가 없거나 조회가 실패하면 빈 에디터를 그대로 둔다 — 지어낸 방문지를 담지 않는다.
struct CustomCourseStartView: View {
    let startingCourseID: Int64?

    @State private var stops: [ItineraryStop] = []
    @State private var courseTitle = ""
    @State private var selectedTagIDs: [Int64] = []
    /// 코스 태그는 서버 필수 값이라 **이 진입에서도 받아 와야 한다.** 예전에는 넘기지 않아
    /// `tags` 가 늘 빈 배열이었고, 그래서 통신이 멀쩡해도 태그 줄이 「불러오지 못했어요」로
    /// 굳고 「이 코스로 계속하기」가 영영 잠겨 있었다 — 실패가 아니라 **조회 자체가 없었다**.
    @State private var tags: [ServerCourseTag] = []

    var body: some View {
        CustomCourseEditorView(
            stops: $stops,
            courseTitle: $courseTitle,
            selectedTagIDs: $selectedTagIDs,
            tags: tags
        )
        .task {
            guard MoyeoServerSync.isEnabled, tags.isEmpty else { return }
            tags = (try? await TravelCourseAPIClient.shared.tags()) ?? []
        }
        .task {
            guard let courseID = startingCourseID, stops.isEmpty else { return }
            guard let detail = try? await TravelCourseAPIClient.shared.courseDetail(courseID: courseID) else { return }
            let itinerary = ServerCourseMapper.course(from: detail).itinerary
            guard !itinerary.isEmpty else { return }
            stops = itinerary
        }
    }
}
