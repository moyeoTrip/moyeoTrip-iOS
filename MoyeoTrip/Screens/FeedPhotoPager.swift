//
//  FeedPhotoPager.swift
//  23 피드 상세의 사진 영역 — changeLog20 §7-13.
//
//  예전에는 상세가 **목록용 미리보기**(`FeedPhotoPreview`, 앞 2장만)를 그대로 쓰면서
//  `"1/4"` 라는 **고정 문자열** 배지를 얹었다. 사진이 4장이어도 2장만 보이는데 배지는
//  페이저가 있는 것처럼 말했고, 나머지 2장은 볼 방법이 아예 없었다 (사용자가 발견).
//
//  여기서는 전체를 좌우로 넘기고, 배지가 **지금 몇 번째인지**를 가리킨다.
//  사진을 누르면 전체화면으로 크게 본다.
//

import SwiftUI

/// 상세의 사진 영역. 사진이 없으면 아무것도 그리지 않는다.
struct FeedPhotoPager: View {
  let photoURLs: [URL]
  var height: CGFloat = 168

  @State private var index = 0
  @State private var viewerIndex: FeedPhotoIndex?

  var body: some View {
    if photoURLs.isEmpty {
      EmptyView()
    } else {
      ZStack(alignment: .topTrailing) {
        // 한 장뿐이면 페이저를 두지 않는다 — 넘길 것이 없는데 페이저를 두면
        // 좌우로 밀리는 여백이 생긴다.
        if photoURLs.count == 1 {
          FeedPhotoCell(url: photoURLs[0], height: height)
            .onTapGesture { viewerIndex = FeedPhotoIndex(value: 0) }
        } else {
          TabView(selection: $index) {
            ForEach(Array(photoURLs.enumerated()), id: \.offset) { offset, url in
              FeedPhotoCell(url: url, height: height)
                .onTapGesture { viewerIndex = FeedPhotoIndex(value: offset) }
                .tag(offset)
            }
          }
          .tabViewStyle(.page(indexDisplayMode: .never))
          .frame(height: height)
        }

        if photoURLs.count > 1 {
          // 배지는 **지금 위치**를 가리킨다. 고정 `1/n` 이면 넘겨도 그대로여서
          // 넘어간 것인지 알 수 없다.
          Text("\(index + 1)/\(photoURLs.count)")
            .font(.caption2.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.black.opacity(0.55))
            .clipShape(Capsule())
            .padding(8)
            .accessibilityIdentifier("feed.detail.photoCount")
        }
      }
      .frame(height: height)
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
      .accessibilityIdentifier("feed.detail.photos")
      .fullScreenCover(item: $viewerIndex) { start in
        FeedPhotoViewer(photoURLs: photoURLs, startIndex: start.value)
      }
    }
  }
}

/// 사진 한 칸 — 상세 페이저와 목록 카드 페이저가 **같은 칸**을 쓴다 (결정 ⑪).
///
/// `Color.clear` 로 칸 크기를 정하고 이미지는 `overlay` 로 얹는다 —
/// `scaledToFill()` 한 이미지에 직접 `frame` 을 걸면 고유 폭이 부모로 새어나가
/// **카드 전체가 화면보다 넓어진다** (`FeedPhotoPreview` 주석과 같은 이유).
struct FeedPhotoCell: View {
  let url: URL
  let height: CGFloat

  var body: some View {
    Color.clear
      .frame(maxWidth: .infinity)
      .frame(height: height)
      .overlay {
        CachedRemoteImage(url: url, fallbackShape: .landscape) { image in
          image
            .resizable()
            .scaledToFill()
        } placeholder: {
          MoyeoTheme.leaf
        }
      }
      .clipped()
      .contentShape(Rectangle())
  }
}

/// 목록 카드(22 피드 목록 · 26 내 피드 목록)의 사진 영역 — 결정 ⑪.
///
/// 예전에는 목록이 **첫 장 한 장**(또는 앞 2장)만 그려서, 서버가 여러 장을 줘도
/// 상세로 들어가기 전에는 나머지를 볼 수 없었다. 상세(`FeedPhotoPager`)와 **같은 규칙**을
/// 쓴다 — 좌우로 넘기고, 배지가 지금 몇 번째인지 가리킨다. 배지 모양도 상세와 같다.
///
/// 목록에서는 사진을 눌러도 **상세로 간다** — 전체화면 뷰어는 상세의 몫이다.
/// 그래서 이 뷰는 카드의 `Button` **바깥**에 놓고 탭을 `onTap` 으로 직접 받는다
/// (`Button` 안에 `TabView(.page)` 를 넣으면 탭이 먹히지 않는다).
struct FeedCardPhotoPager: View {
  let photoURLs: [URL]
  var height: CGFloat = 166
  /// 캡처·테스트 식별자 접두사 (`feed.post.<id>` · `my.feedPost.<id>`).
  let identifierPrefix: String
  /// 카드를 누른 것과 같은 동작.
  var onTap: () -> Void = {}

  @State private var index = 0

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      TabView(selection: $index) {
        ForEach(Array(photoURLs.enumerated()), id: \.offset) { offset, url in
          FeedPhotoCell(url: url, height: height)
            .onTapGesture(perform: onTap)
            .tag(offset)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .frame(height: height)

      // 배지는 **오른쪽 아래**에 둔다 (정본 결정 ⑪). 모양은 상세 배지 그대로다.
      Text("\(index + 1)/\(photoURLs.count)")
        .font(.caption2.weight(.heavy))
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.black.opacity(0.55))
        .clipShape(Capsule())
        .padding(8)
        .allowsHitTesting(false)
        .accessibilityIdentifier("\(identifierPrefix).photoCount")
    }
    .frame(height: height)
    .accessibilityIdentifier("\(identifierPrefix).photos")
  }
}

/// 사진을 전체화면으로 본다. 좌우로 넘기고, 두 손가락으로 확대한다.
private struct FeedPhotoViewer: View {
  let photoURLs: [URL]
  let startIndex: Int

  @Environment(\.dismiss) private var dismiss
  @State private var index: Int
  @State private var scale: CGFloat = 1

  init(photoURLs: [URL], startIndex: Int) {
    self.photoURLs = photoURLs
    self.startIndex = startIndex
    _index = State(initialValue: startIndex)
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      TabView(selection: $index) {
        ForEach(Array(photoURLs.enumerated()), id: \.offset) { offset, url in
          CachedRemoteImage(url: url, fallbackShape: .landscape) { image in
            image
              .resizable()
              .scaledToFit()
          } placeholder: {
            Color.black
          }
          .scaleEffect(offset == index ? scale : 1)
          // 확대한 채로 다음 장으로 넘어가면 그 장도 확대돼 보인다 — 넘길 때 되돌린다.
          .gesture(
            MagnificationGesture()
              .onChanged { value in scale = min(max(value, 1), 4) }
              .onEnded { _ in if scale < 1.05 { withAnimation(.easeOut(duration: 0.18)) { scale = 1 } } }
          )
          .onTapGesture(count: 2) {
            withAnimation(.easeOut(duration: 0.2)) { scale = scale > 1.05 ? 1 : 2.5 }
          }
          .tag(offset)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .onChange(of: index) { _, _ in scale = 1 }

      VStack {
        HStack {
          Spacer()
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 15, weight: .bold))
              .foregroundStyle(.white)
              .frame(width: 44, height: 44)
              .background(.black.opacity(0.45))
              .clipShape(Circle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("닫기")
          .accessibilityIdentifier("feed.photoViewer.close")
        }
        .padding(.horizontal, 12)
        Spacer()
        if photoURLs.count > 1 {
          Text("\(index + 1)/\(photoURLs.count)")
            .font(.caption.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.45))
            .clipShape(Capsule())
            .padding(.bottom, 24)
        }
      }
    }
    .accessibilityIdentifier("screen.feedPhotoViewer")
  }
}

/// `fullScreenCover(item:)` 에 넘길 사진 번호. `Int` 에 전역으로 `Identifiable` 을
/// 붙이면 표준 타입을 오염시키므로 이 화면 안에서만 쓰는 래퍼를 둔다.
private struct FeedPhotoIndex: Identifiable {
  let value: Int
  var id: Int { value }
}
