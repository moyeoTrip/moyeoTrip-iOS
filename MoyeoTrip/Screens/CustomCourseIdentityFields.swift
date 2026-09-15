//
//  CustomCourseIdentityFields.swift
//  MoyeoTrip
//
//  17-1a 코스 직접 만들기 — 코스 이름 입력과 코스 태그 칩.
//
//  서버 계약(직접 확인): `moyeoTrip-BACKEND` 의
//  `CreateCustomCourseRequest.title` 은 `@NotBlank @Size(max = 100)`,
//  `ChatRoomService.createCustomCourse` 는 `tagIds` 로 태그를 하나도 못 찾으면
//  `TRAVEL_COURSE_TAG_NOT_FOUND` 로 거절한다 — 둘 다 **필수**다.
//
//  iOS 코스 에디터에는 둘 다 입력할 곳이 없어서, 커스텀 코스로 만든 모집이 서버에
//  전혀 생성되지 않았다 (IOS-F124). 웹 `custom-course-title` · `custom-course-tag-{id}` 와
//  안드 `CustomCourseScreen` 이 같은 계약을 쓴다.
//
//  `CustomCourseEditorView` 본문이 타입 길이 제한에 걸려 이 두 조각만 파일을 나눴다.
//

import SwiftUI

/// 코스 이름 한 줄 입력. 서버 상한과 같은 100자에서 자른다 —
/// 더 받아 두면 저장 순간에 400 이 나고 왜 막혔는지 알 수 없다.
struct CustomCourseTitleField: View {
    @Binding var title: String

    /// 서버 `@Size(max = 100)` 과 같은 값이다.
    static let titleLimit = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("코스 이름 *")
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)
            TextField("예: 주왕산 단풍길 하루 코스", text: $title)
                .font(.subheadline)
                .textFieldStyle(.plain)
                .padding(.horizontal, 13)
                .frame(height: 46)
                .background(MoyeoTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(MoyeoTheme.line))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .accessibilityIdentifier("customCourse.title")
                .onChange(of: title) { _, value in
                    if value.count > Self.titleLimit { title = String(value.prefix(Self.titleLimit)) }
                }
            Text("\(title.count)/\(Self.titleLimit)")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(MoyeoTheme.text400)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

/// 코스 태그 칩. 고른 것은 채워진 칩, 안 고른 것은 외곽선 칩이다 —
/// 11 탐색·13 검색 결과의 태그 칩과 같은 모양(반지름 999)을 쓴다.
struct CustomCourseTagPicker: View {
    let tags: [ServerCourseTag]
    @Binding var selectedTagIDs: [Int64]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("코스 태그 * (1개 이상)")
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)
            if tags.isEmpty {
                // 태그를 못 받으면 **지어내지 않는다** — 고를 수 없다는 사실을 그대로 알린다(웹과 같다).
                Text("태그를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.")
                    .font(.caption)
                    .foregroundStyle(MoyeoTheme.muted)
                    .accessibilityIdentifier("customCourse.tagsUnavailable")
            } else {
                // 칩 줄바꿈은 이미 있는 `MoyeoChipFlowLayout` 을 그대로 쓴다(11 여행 취향 칩과 같은 배치).
                MoyeoChipFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                    ForEach(tags, id: \.tagId) { tag in
                        chip(tag)
                    }
                }
            }
        }
    }

    private func chip(_ tag: ServerCourseTag) -> some View {
        let isSelected = selectedTagIDs.contains(tag.tagId)
        return Button {
            if let index = selectedTagIDs.firstIndex(of: tag.tagId) {
                selectedTagIDs.remove(at: index)
            } else {
                selectedTagIDs.append(tag.tagId)
            }
        } label: {
            Text(tag.name)
                .font(.caption.weight(.heavy))
                .foregroundStyle(isSelected ? Color.white : MoyeoTheme.brandText)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(isSelected ? MoyeoTheme.forest : Color.clear)
                .overlay(Capsule().stroke(isSelected ? Color.clear : MoyeoTheme.line))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("customCourse.tag.\(tag.tagId)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
