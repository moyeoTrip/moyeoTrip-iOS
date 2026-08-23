//
//  OverlayBackdrops.swift
//  MoyeoTrip
//
//  changeLog14 — 오버레이 배경 일괄.
//  오버레이(바텀시트·경고 팝업)는 이전 화면 위에 뜬 것으로 그린다. 딤만 남기고 배경을
//  비우지 않는다 — 시트/팝업 뒤에 실제로 그 화면에서 열렸을 이전 화면 본문을 그대로 깔고
//  그 위에 스크림을 얹는다. 배경은 실루엣 대신 화면과 같은 코드(`ChatRoomBody` 등)를 쓴다.
//

import SwiftUI

/// 이전 화면 본문 + 스크림. 배경이므로 입력을 받지 않고 접근성 트리에서도 숨긴다.
struct OverlayBackdrop<Content: View>: View {
  let title: String
  var trailingIcons: [String] = []
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(spacing: 0) {
      OverlayBackdropHeader(title: title, trailingIcons: trailingIcons)
      content()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    // 배경 색만 안전 영역을 넘어간다. 본문까지 넘기면 헤더가 상태 바 밑으로 잘린다.
    .background(MoyeoTheme.background.ignoresSafeArea())
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    // 딤은 두 테마에서 같은 어두운 톤이다. `ink`는 다크에서 밝은 색으로 뒤집혀
    // 화면을 오히려 밝게 덮는다(회색 빈 화면으로 보였던 원인).
    .overlay(MoyeoTheme.overlayScrim.ignoresSafeArea())
  }
}

/// 오버레이가 네비게이션 바를 숨긴 채 뜨기 때문에, 배경에도 이전 화면의 헤더가 있어야
/// "이전 화면 위에 뜬 것"으로 읽힌다.
private struct OverlayBackdropHeader: View {
  let title: String
  let trailingIcons: [String]

  var body: some View {
    HStack(spacing: 2) {
      Image(systemName: "chevron.left")
        .frame(width: 34, height: 34)
      Spacer(minLength: 4)
      Text(title)
        .font(.subheadline.weight(.heavy))
        .lineLimit(1)
      Spacer(minLength: 4)
      if trailingIcons.isEmpty {
        Color.clear.frame(width: 34, height: 34)
      } else {
        ForEach(trailingIcons, id: \.self) { icon in
          Image(systemName: icon).frame(width: 30, height: 34)
        }
      }
    }
    .font(.system(size: 15, weight: .bold))
    .foregroundStyle(MoyeoTheme.ink)
    .padding(.horizontal, 10)
    .frame(height: 44)
    .background(MoyeoTheme.background)
  }
}

/// 20-2 첨부 메뉴 · 32 신고 시트 뒤에 깔리는 실제 채팅방(20) 본문.
struct ChatRoomOverlayBackdrop: View {
  var threadID: String = "chat-cheongsong-juwangsan"

  private var thread: ChatThread {
    MockData.chatThread(for: threadID) ?? MockData.chatThreads[0]
  }

  var body: some View {
    OverlayBackdrop(
      title: thread.tripTitle,
      trailingIcons: ["magnifyingglass", "line.3.horizontal"]
    ) {
      ChatRoomBody(thread: thread)
    }
  }
}
