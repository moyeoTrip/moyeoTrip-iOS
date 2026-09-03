//
//  ChatSpecialMessageCards.swift
//  MoyeoTrip
//
//  20 · 21 공용 — 특수 메시지 카드.
//
//  21 「특수 메시지 6종」은 채팅방(20)과 **같은 카드**를 그려야 한다. 두 화면이 다르게
//  생기면 그게 결함이다. 그래서 카드를 두 화면 밖(이 파일)에 두고 함께 쓴다.
//
//  ⚠️ 예전 21 은 카드를 손으로 그린 목데이터("동궁과 월지" · "우직한 곰 7821님이 결제했어요")로
//  채우고 있었다. 6종 전부 API 가 있다 — 읽기는 `GET /chat-rooms/{roomId}/messages` 하나로
//  끝나고 응답의 `type` 으로 종류를 가른다 (웹 `SpecialMessageCard` 와 같은 규칙):
//
//    TOURISM_CONTENT   POST /chat-rooms/{roomId}/messages/tourism-contents  { contentId }
//    LOCATION          POST /chat-rooms/{roomId}/messages/locations         (본문 없음 · 방의 집합 좌표)
//    POLL              POST /chat-rooms/{roomId}/messages/polls             { question, options[], anonymous }
//    SETTLEMENT_MEMO   POST /chat-rooms/{roomId}/messages/settlement-memos  { memo }
//    IMAGE             POST /chat-rooms/{roomId}/messages/images            (multipart)
//    SYSTEM            서버가 만든다 (개설 · 참여 · 공지 등록 · 여행 확정 등)
//
//  서버가 그 방에 주지 않은 종류는 **카드를 그리지 않는다** — 예시로 채우지 않는다
//  (`docs/alignment/NO-MOCK-CANON.md` R1 · R3).

import SwiftUI

// MARK: - 종류 판정

extension ServerChatMessage {
  /// 일반 말풍선이 아니라 **카드 표면**으로 그려야 하는 메시지인지.
  var isSpecialCard: Bool {
    imageURL != nil || tourismContent != nil || location != nil || poll != nil
      || type == "SETTLEMENT_MEMO"
  }
}

/// 21 이 견본으로 뽑는 6종. 순서는 화면기획 21 의 카드 순서다.
enum ChatSpecialMessageKind: String, CaseIterable {
  case tourismContent = "TOURISM_CONTENT"
  case location = "LOCATION"
  case poll = "POLL"
  case settlementMemo = "SETTLEMENT_MEMO"
  case image = "IMAGE"
  case system = "SYSTEM"

  var label: String {
    switch self {
    case .tourismContent: return "장소"
    case .location: return "지도 · 만남"
    case .poll: return "투표"
    case .settlementMemo: return "정산 메모"
    case .image: return "사진"
    case .system: return "시스템"
    }
  }
}

// MARK: - 카드

/// 특수 메시지 한 건. `onVote` 가 없으면 투표 선택지는 눌러도 아무 일이 없다 —
/// 카드 모양은 같게 둔다 (웹과 같은 규칙).
struct ChatSpecialMessageCard: View {
  let message: ServerChatMessage
  var isVoting = false
  var onVote: ((ServerChatPollOption) -> Void)?

  var body: some View {
    if let imageURL = message.imageURL {
      photo(imageURL)
    } else if let place = message.tourismContent {
      tourismCard(place)
    } else if let spot = message.location {
      locationCard(spot)
    } else if let poll = message.poll {
      pollCard(poll)
    } else if message.type == "SETTLEMENT_MEMO" {
      settlementCard
    } else {
      Text(message.content)
        .font(.subheadline)
        .foregroundStyle(MoyeoTheme.ink)
    }
  }

  // MARK: 사진

  @ViewBuilder
  private func photo(_ url: URL) -> some View {
    CachedRemoteImage(url: url) { image in
      image
        .resizable()
        .scaledToFill()
    } placeholder: {
      MoyeoTheme.leaf
    }
    .frame(height: 150)
    .frame(maxWidth: .infinity)
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .accessibilityIdentifier("chat.card.image")
  }

  // MARK: 장소 (관광 콘텐츠 공유)

  @ViewBuilder
  private func tourismCard(_ place: ServerSharedTourismContent) -> some View {
    let thumbnailURL = MoyeoImageURL.resolve(place.thumbnail)
    VStack(alignment: .leading, spacing: 7) {
      cardLabel("장소", systemImage: "mappin.circle", tint: MoyeoTheme.forest)
      Text(place.title)
        .font(.caption.weight(.heavy))
        .foregroundStyle(MoyeoTheme.ink)
      if let address = place.address, !address.isEmpty {
        Text(address)
          .font(.caption2)
          .foregroundStyle(MoyeoTheme.muted)
          .fixedSize(horizontal: false, vertical: true)
      }
      // 썸네일이 없으면 자리만 비운다 — 내장 "이미지 없음" 그림을 공유된 사진처럼 두지 않는다.
      if let thumbnailURL {
        CachedRemoteImage(url: thumbnailURL) { image in
          image
            .resizable()
            .scaledToFill()
        } placeholder: {
          MoyeoTheme.leaf
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      }
    }
    .accessibilityIdentifier("chat.card.tourism")
  }

  // MARK: 지도 · 만남 (만날 위치 공유)

  @ViewBuilder
  private func locationCard(_ spot: ServerSharedLocation) -> some View {
    let coordinate = MoyeoMapCoordinate(latitude: spot.latitude, longitude: spot.longitude)
    let name = spot.name?.isEmpty == false ? spot.name! : message.content
    VStack(alignment: .leading, spacing: 7) {
      cardLabel("만날 위치", systemImage: "map", tint: MoyeoTheme.coral)
      // 좌표가 있을 때만 **실지도**를 그린다. 손으로 그린 경로선·핀은 두지 않는다 (R4).
      MoyeoMapView(
        content: MoyeoMapContent(
          center: coordinate,
          // 네이티브 zoomLevel 은 웹 level 과 **방향이 반대**다. 웹 카드의 `level: 4` 를
          // 그대로 옮기면 한반도 전체가 찍힌다 — 한 지점 확대는 18-5 · 20-2b 와 같이 16 이다.
          level: 16,
          markers: [MoyeoMapMarker(id: "chat-location-\(message.messageId)", coordinate: coordinate)],
          fitsContent: false
        ),
        isInteractive: false,
        fallback: { MoyeoTheme.mapGreen }
      )
      .frame(height: 110)
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      if !name.isEmpty {
        Text(name)
          .font(.caption.weight(.heavy))
          .foregroundStyle(MoyeoTheme.ink)
      }
      // 좌표는 지도를 그리는 입력값이지 사용자에게 보일 값이 아니다 — 기획에도 없고,
      // 위에 실제 지도가 있어 중복이다. 예전에는 `36.41080, 129.05750` 이 그대로 보였다.
    }
    .accessibilityIdentifier("chat.card.location")
  }

  // MARK: 투표

  @ViewBuilder
  private func pollCard(_ poll: ServerChatPoll) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      cardLabel("투표", systemImage: "chart.bar", tint: MoyeoTheme.forest)
      Text(poll.question)
        .font(.caption.weight(.heavy))
        .foregroundStyle(MoyeoTheme.ink)
        .fixedSize(horizontal: false, vertical: true)
      VStack(spacing: 6) {
        ForEach(poll.options) { option in
          pollOptionRow(poll: poll, option: option)
        }
      }
      .padding(.top, 2)
      Text(pollFooter(poll))
        .font(.caption2)
        .foregroundStyle(MoyeoTheme.muted)
        .monospacedDigit()
    }
    .accessibilityIdentifier("chat.card.poll")
  }

  private func pollFooter(_ poll: ServerChatPoll) -> String {
    poll.anonymous ? "\(poll.totalVoteCount)명 참여 · 익명" : "\(poll.totalVoteCount)명 참여"
  }

  @ViewBuilder
  private func pollOptionRow(poll: ServerChatPoll, option: ServerChatPollOption) -> some View {
    let ratio = pollRatio(poll: poll, option: option)
    Button {
      onVote?(option)
    } label: {
      HStack(spacing: 8) {
        Text(option.text)
          .font(.caption.weight(option.votedByMe ? .heavy : .semibold))
          .foregroundStyle(MoyeoTheme.ink)
          .frame(maxWidth: .infinity, alignment: .leading)
        Text("\(option.voteCount)")
          .font(.caption2.weight(.heavy))
          .foregroundStyle(MoyeoTheme.muted)
          .monospacedDigit()
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(alignment: .leading) {
        GeometryReader { proxy in
          MoyeoTheme.leaf
            .frame(width: proxy.size.width * ratio)
        }
      }
      .background(option.votedByMe ? MoyeoTheme.leaf.opacity(0.35) : MoyeoTheme.card)
      .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
          .stroke(option.votedByMe ? MoyeoTheme.forest : MoyeoTheme.softLine, lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
    .disabled(isVoting || onVote == nil)
    .accessibilityIdentifier("chat.card.poll.option.\(option.optionId)")
  }

  private func pollRatio(poll: ServerChatPoll, option: ServerChatPollOption) -> CGFloat {
    guard poll.totalVoteCount > 0 else { return 0 }
    return CGFloat(option.voteCount) / CGFloat(poll.totalVoteCount)
  }

  // MARK: 정산 메모

  private var settlementCard: some View {
    VStack(alignment: .leading, spacing: 6) {
      // 송금 기능이 아니다 — 메모라는 것을 카드가 직접 말한다.
      cardLabel("정산 메모 · 송금 아님", systemImage: "creditcard", tint: MoyeoTheme.muted)
      Text(message.content)
        .font(.caption)
        .foregroundStyle(MoyeoTheme.ink)
        .fixedSize(horizontal: false, vertical: true)
    }
    .accessibilityIdentifier("chat.card.settlement")
  }

  // MARK: 공용

  private func cardLabel(_ title: String, systemImage: String, tint: Color) -> some View {
    Label(title, systemImage: systemImage)
      .font(.caption2.weight(.heavy))
      .foregroundStyle(tint)
  }
}

// MARK: - 카드 표면

extension View {
  /// 특수 메시지 카드의 표면. 일반 말풍선보다 넓고, 내 카드도 초록 말풍선에 넣지 않는다 —
  /// 넣으면 카드 안의 지도·투표 바가 읽히지 않는다.
  func chatSpecialCardSurface() -> some View {
    frame(maxWidth: .infinity, alignment: .leading)
      .padding(13)
      .background(MoyeoTheme.card)
      .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
          .stroke(MoyeoTheme.softLine, lineWidth: 1)
      }
  }
}

// MARK: - 시스템 메시지

/// SYSTEM 메시지(개설 · 참여 · 공지 등록 · 여행 확정 등)는 서버가 만든다.
/// 웹 · 안드로이드처럼 **중앙정렬** 알림 줄이다.
struct ChatSystemMessageNote: View {
  let content: String

  var body: some View {
    Text(content)
      .font(.caption.weight(.heavy))
      .foregroundStyle(MoyeoTheme.forest)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .background(MoyeoTheme.leaf)
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      .frame(maxWidth: .infinity, alignment: .center)
      .accessibilityIdentifier("chat.card.system")
  }
}
