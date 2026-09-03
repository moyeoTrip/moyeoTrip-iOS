import SwiftUI

struct TripConfirmedView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let trip: TripRecruitment
  let thread: ChatThread?
  let onSendChatMessage: (ChatThread, ChatMessage) -> Void
  /// `GET /chat-rooms/{roomId}` 가 준 참가자. 아바타 줄의 근거다 — 없으면 줄을 그리지 않는다.
  var participants: [ServerChatRoomDetail.ServerParticipant] = []
  var participantNicknamesByUserID: [Int64: String] = [:]
  @State private var selectedThread: ChatThread?

  var body: some View {
    ZStack(alignment: .top) {
      MoyeoTheme.background
        .ignoresSafeArea()
        .accessibilityElement()
        .accessibilityIdentifier("screen.tripConfirmed")
      TripConfirmedConfetti(
        isStatic: reduceMotion || UITestRuntime.reducesVisualAnimations
      )
      .frame(maxHeight: 330, alignment: .top)
      .allowsHitTesting(false)

      ScrollView {
        VStack(spacing: 0) {
          confirmedHero
          Text("여행이 확정됐어요!")
            .font(MoyeoTypography.font(size: 22, weight: .bold, relativeTo: .title2))
            .foregroundStyle(MoyeoTheme.ink)
            .padding(.top, 18)
          confirmedCopy
            .padding(.top, 8)
          ConfirmedTripCard(
            trip: trip,
            participants: participants,
            participantNicknamesByUserID: participantNicknamesByUserID
          )
            .padding(.top, 20)
          shareCard
            .padding(.top, 14)
          Text("확정 이후에는 경로가 잠겨요. 변경이 필요하면 채팅방 공지로 알려주세요.")
            .font(MoyeoTypography.font(size: 11, relativeTo: .caption2))
            .foregroundStyle(MoyeoTheme.text400)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .padding(.horizontal, 12)
            .padding(.top, 14)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 24)
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      bottomAction
        .zIndex(1)
    }
    .navigationTitle(trip.title)
    .navigationBarTitleDisplayMode(.inline)
    .navigationDestination(item: $selectedThread) { selectedThread in
      TripDayView(thread: selectedThread)
    }
  }

  private var confirmedHero: some View {
    Image("TripConfirmedMascots")
      .resizable()
      .scaledToFill()
      .frame(width: 252, height: 142)
      .scaleEffect(1.14)
      .frame(width: 252, height: 142)
      .clipped()
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      .accessibilityLabel("여행 확정을 함께 축하하는 모여트립 곰, 토끼, 너구리 캐릭터")
      .accessibilityIdentifier("tripConfirmed.hero")
  }

  /// 마감일은 **서버가 준 값**이다. 예전에는 `5월 22일 마감까지` 가 코드에 박혀 있었다.
  /// 마감 표기를 못 받으면 그 구절 없이 인원만 적는다 (NO-MOCK-CANON R1).
  private var confirmedCopy: some View {
    let deadline = trip.recruitmentDeadline.trimmingCharacters(in: .whitespaces)
    let joined = Text("\(trip.confirmedMemberCount)명").foregroundColor(MoyeoTheme.forest)
    return VStack(spacing: 2) {
      if deadline.isEmpty {
        Text("\(joined)이 모였어요.")
      } else {
        Text("\(deadline) 마감까지 \(joined)이 모였어요.")
      }
      Text("이제 함께 떠나기만 하면 돼요.")
    }
    .font(MoyeoTypography.font(size: 13, relativeTo: .subheadline))
    .foregroundStyle(MoyeoTheme.muted)
    .multilineTextAlignment(.center)
    .lineSpacing(4)
  }

  private var shareCard: some View {
    Button {
      // The image export service will attach here when the share contract is available.
    } label: {
      HStack(spacing: 11) {
        Image(systemName: "camera.fill")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(MoyeoTheme.text700)
          .frame(width: 38, height: 38)
          .background(MoyeoTheme.subtleBackground)
          .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        Text("확정 카드를 이미지로 저장해 공유할 수 있어요")
          .font(MoyeoTypography.font(size: 12, relativeTo: .caption))
          .foregroundStyle(MoyeoTheme.text700)
          .multilineTextAlignment(.leading)
        Spacer(minLength: 4)
        Image(systemName: "square.and.arrow.up")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(MoyeoTheme.muted)
      }
      .padding(13)
      .background(MoyeoTheme.card)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(MoyeoTheme.softLine, lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
    .contentShape(Rectangle())
    .accessibilityIdentifier("tripConfirmed.share")
  }

  private var bottomAction: some View {
    Button {
      selectedThread = thread
    } label: {
      Text("채팅방으로 가기")
        .font(MoyeoTypography.font(size: 15, weight: .bold, relativeTo: .headline))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(thread == nil ? MoyeoTheme.text400 : MoyeoTheme.forest)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(.plain)
    .disabled(thread == nil)
    .padding(.horizontal, 20)
    .padding(.top, 10)
    .padding(.bottom, 10)
    .background(MoyeoTheme.card)
    .overlay(alignment: .top) {
      Rectangle().fill(MoyeoTheme.softLine).frame(height: 1)
    }
    .accessibilityIdentifier("tripConfirmed.openChat")
  }
}

private struct ConfirmedTripCard: View {
  let trip: TripRecruitment
  var participants: [ServerChatRoomDetail.ServerParticipant] = []
  var participantNicknamesByUserID: [Int64: String] = [:]

  var body: some View {
    VStack(alignment: .leading, spacing: 11) {
      HStack(spacing: 8) {
        Circle().fill(MoyeoTheme.forest).frame(width: 8, height: 8)
        Text("확정된 여행")
          .font(MoyeoTypography.font(size: 12, weight: .bold, relativeTo: .caption))
          .foregroundStyle(MoyeoTheme.forest)
      }
      confirmedRow(icon: "calendar", text: scheduleText)
      // 집합 표기는 "07:50 청송 시외버스터미널 정문 앞"까지다 (화면기획 20-4 · 15와 같은 값)
      confirmedRow(icon: "mappin.and.ellipse", text: trip.detailMeetupText)
      confirmedRow(icon: "person.2.fill", text: memberText)
      // 15 모집 상세와 같은 아바타 줄이다. 참가자를 못 받으면 그리지 않는다 —
      // 예전에는 사람 없이 `+4` 배지만 남았다 (NO-MOCK-CANON R1).
      if !participants.isEmpty {
        TripDetailParticipantStack(
          participants: participants,
          nicknamesByUserID: participantNicknamesByUserID
        )
        .padding(.top, 3)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(MoyeoTheme.leaf)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(MoyeoTheme.forest.opacity(0.28), lineWidth: 1)
    }
    .accessibilityIdentifier("tripConfirmed.details")
  }

  /// 서버가 준 일정 문구를 그대로 쓴다. 예전에는 특정 시각이 들어 있으면
  /// `5/25(토) 당일치기 · 08:00 – 18:00` 을 지어내 덮어썼다.
  private var scheduleText: String {
    trip.schedule
  }

  /// 최소 인원을 모르면(서버가 0 으로 준다) `최소 …명 충족` 을 붙이지 않는다.
  private var memberText: String {
    trip.minimumParticipants > 0
      ? "\(trip.joined)명 · 최소 \(trip.minimumParticipants)명 충족"
      : "\(trip.joined)명"
  }

  private func confirmedRow(icon: String, text: String) -> some View {
    Label(text, systemImage: icon)
      .font(MoyeoTypography.font(size: 12.5, weight: .bold, relativeTo: .caption))
      .foregroundStyle(MoyeoTheme.ink)
      .lineLimit(2)
  }
}

extension TripRecruitment {
  /// 20-4 확정 인원 — **서버가 준 참가자 수**다.
  /// 예전에는 `max(joined, capacity)` 로 정원을 대신 적어 1명인 방을 8명으로 보여줬다.
  var confirmedMemberCount: Int {
    joined
  }
}

private struct TripConfirmedConfetti: View {
  let isStatic: Bool
  @State private var hasEntered = false

  private let colors = [
    MoyeoTheme.forest, MoyeoTheme.coral, MoyeoTheme.primary300, MoyeoTheme.sunrise
  ]

  /// 조각 하나의 고정된 성질.
  ///
  /// 예전에는 `(index * 37) % 96` 같은 규칙으로 위치를 만들어 **눈에 패턴이 보였고**,
  /// 좌우 흔들림이 없어 제자리에서 회전만 하는 것처럼 보였다
  /// (2026-08-31 사용자 지적: "정해진 패턴으로 원으로 돌기만하네").
  /// 씨앗을 고정한 난수로 **한 번만** 뽑아 둔다 — 매 프레임 뽑으면 조각이 튄다.
  private struct Piece {
    let startX: Double
    let startY: Double
    let fall: Double
    let sway: Double
    let spinTurns: Double
    let size: Double
    let delay: Double

    /// 이 조각 하나를 그린다. 좌표 계산을 여기서 끝내 타입 검사 부담을 줄인다.
    @ViewBuilder
    func view(
      index: Int,
      color: Color,
      canvas: CGSize,
      isStatic: Bool,
      hasEntered: Bool
    ) -> some View {
      let progress: Double = (hasEntered || isStatic) ? 1 : 0
      let swayOffset: Double = sway * sin(progress * 2 * Double.pi * 1.6)
      let x: Double = Double(canvas.width) * startX + swayOffset
      // 정지 캡처는 화면 안에 세운다 — 다 지나간 뒤를 찍으면 아무것도 안 보인다.
      let staticY: Double = Double(canvas.height) * (0.08 + Double(index % 7) * 0.11)
      let movingY: Double = Double(canvas.height) * (startY + fall * progress)
      let y: Double = isStatic ? staticY : movingY
      let shownOpacity: Double = isStatic ? 0.9 : (hasEntered ? 0 : 0.95)

      RoundedRectangle(cornerRadius: 2, style: .continuous)
        .fill(color)
        .frame(width: size, height: size * 0.5)
        .rotationEffect(.degrees(spinTurns * 360 * progress))
        .position(x: CGFloat(x), y: CGFloat(y))
        .opacity(shownOpacity)
        .animation(isStatic ? nil : .linear(duration: 2.2).delay(delay), value: hasEntered)
    }
  }

  private static let pieces: [Piece] = {
    var generator = SeededGenerator(seed: 20_260_831)
    return (0..<26).map { _ in
      Piece(
        startX: Double.random(in: 0...1, using: &generator),
        startY: Double.random(in: -0.5 ... -0.15, using: &generator),
        fall: Double.random(in: 1.25...1.75, using: &generator),
        sway: Double.random(in: -26...26, using: &generator),
        spinTurns: Double.random(in: -1.5...1.5, using: &generator),
        size: Double.random(in: 5...10, using: &generator),
        delay: Double.random(in: 0...0.35, using: &generator)
      )
    }
  }()

  var body: some View {
    GeometryReader { proxy in
      ForEach(Array(Self.pieces.enumerated()), id: \.offset) { index, piece in
        // 식을 쪼개 둔다 — 한 줄에 몰아 쓰면 Swift 타입 검사기가 포기한다.
        piece.view(
          index: index,
          color: colors[index % colors.count],
          canvas: proxy.size,
          isStatic: isStatic,
          hasEntered: hasEntered
        )
      }
    }
    .onAppear { hasEntered = true }
    .accessibilityHidden(true)
  }
}

/// 씨앗을 고정한 난수 — 같은 화면이 매번 같은 모양으로 흩날린다.
/// 실행마다 달라지면 캡처 픽셀 비교가 성립하지 않는다.
private struct SeededGenerator: RandomNumberGenerator {
  private var state: UInt64
  init(seed: UInt64) { state = seed == 0 ? 0x4d59_5df4_d0f3_3173 : seed }
  mutating func next() -> UInt64 {
    state ^= state << 13
    state ^= state >> 7
    state ^= state << 17
    return state
  }
}
