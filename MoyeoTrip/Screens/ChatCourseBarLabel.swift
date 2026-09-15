//
//  ChatCourseBarLabel.swift
//  MoyeoTrip
//
//  20 채팅방 상단 「여행 경로」 바의 내용. `ChatRoomBody` 타입 본문이 300줄을 넘어 갈라냈다.
//

import SwiftUI

struct ChatCourseBarLabel: View {
  let thread: ChatThread
  let showsEditButton: Bool
  var showsChevron: Bool = false

  var body: some View {
    HStack(spacing: 9) {
      Image(systemName: "map.fill")
      VStack(alignment: .leading, spacing: 2) {
        Text(thread.courseDisplayName)
        Text("방문지 \(thread.routeSummary.count)곳 · \(thread.courseSource.title)")
          .font(.caption2).foregroundStyle(MoyeoTheme.muted).lineLimit(1)
      }
      Spacer()
      if showsEditButton {
        Text("경로 수정")
          .font(.caption2.weight(.heavy))
          .foregroundStyle(MoyeoTheme.brandText)
          .padding(.horizontal, 10)
          .frame(height: 28)
          .overlay(Capsule().stroke(MoyeoTheme.forest.opacity(0.6)))
      } else if showsChevron {
        Image(systemName: "chevron.right")
      }
    }
    .font(.caption.weight(.heavy))
    .foregroundStyle(MoyeoTheme.ink)
    .padding(.horizontal, 16)
    .frame(height: 52)
    .background(MoyeoTheme.card)
  }
}
