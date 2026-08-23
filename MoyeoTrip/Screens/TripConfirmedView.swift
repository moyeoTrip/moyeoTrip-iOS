import SwiftUI

struct TripConfirmedView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let trip: TripRecruitment
  let thread: ChatThread?
  let onSendChatMessage: (ChatThread, ChatMessage) -> Void
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
          ConfirmedTripCard(trip: trip)
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

  private var confirmedCopy: some View {
    VStack(spacing: 2) {
      Text(
        "5월 22일 마감까지 \(Text("\(trip.confirmedMemberCount)명").foregroundColor(MoyeoTheme.forest))이 모였어요."
      )
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
      confirmedRow(
        icon: "person.2.fill",
        text: "\(max(trip.joined, trip.minimumParticipants))명 · 최소 \(trip.minimumParticipants)명 충족"
      )
      HStack(spacing: -7) {
        ForEach(Array(trip.confirmedRoster.prefix(4).enumerated()), id: \.offset) { _, member in
          MascotAvatar(mascot: member.avatar, size: 30, background: MoyeoTheme.card)
            .overlay(Circle().stroke(MoyeoTheme.card, lineWidth: 2))
        }
        if trip.confirmedMemberCount > 4 {
          Text("+\(trip.confirmedMemberCount - 4)")
            .font(MoyeoTypography.font(size: 11, weight: .bold, relativeTo: .caption2))
            .foregroundStyle(MoyeoTheme.text700)
            .frame(width: 30, height: 30)
            .background(MoyeoTheme.softLine)
            .clipShape(Circle())
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.top, 3)
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

  private var scheduleText: String {
    if trip.schedule.contains("08:00") {
      return "5/25(토) 당일치기 · 08:00 – 18:00"
    }
    return trip.schedule
  }

  private func confirmedRow(icon: String, text: String) -> some View {
    Label(text, systemImage: icon)
      .font(MoyeoTypography.font(size: 12.5, weight: .bold, relativeTo: .caption))
      .foregroundStyle(MoyeoTheme.ink)
      .lineLimit(2)
  }
}

extension TripRecruitment {
  /// 화면기획 20-4 — 확정 시점에는 정원이 채워진 상태로 보여준다("5명이 모였어요").
  /// 카드의 "3명 · 최소 3명 충족"은 최소 인원 충족 표기라 기획과 같은 값을 유지한다.
  var confirmedMemberCount: Int {
    max(joined, capacity)
  }

  /// 확정 멤버 아바타. 목데이터의 참여자가 부족하면 공통 참여자 목록에서 채운다.
  var confirmedRoster: [Participant] {
    var roster = participants
    for member in MockData.participants where roster.count < confirmedMemberCount {
      if !roster.contains(where: { $0.id == member.id }) {
        roster.append(member)
      }
    }
    return Array(roster.prefix(confirmedMemberCount))
  }
}

private struct TripConfirmedConfetti: View {
  let isStatic: Bool
  @State private var hasEntered = false

  private let colors = [
    MoyeoTheme.forest, MoyeoTheme.coral, MoyeoTheme.primary300, MoyeoTheme.sunrise
  ]

  var body: some View {
    GeometryReader { proxy in
      ForEach(0..<18, id: \.self) { index in
        RoundedRectangle(cornerRadius: 2, style: .continuous)
          .fill(colors[index % colors.count])
          .frame(width: pieceSize(index), height: pieceSize(index) * 0.5)
          .rotationEffect(.degrees(hasEntered || isStatic ? Double((index * 47) % 180 + 220) : 0))
          .position(
            x: proxy.size.width * CGFloat((index * 37) % 96) / 100,
            y: isStatic
              ? staticY(index, height: proxy.size.height)
              : animatedY(index, height: proxy.size.height)
          )
          .opacity(isStatic || hasEntered ? 0.9 : 0)
          .animation(
            isStatic ? nil : .easeOut(duration: 1.15).delay(Double(index % 6) * 0.054),
            value: hasEntered
          )
      }
    }
    .onAppear {
      hasEntered = true
    }
    .accessibilityHidden(true)
  }

  private func pieceSize(_ index: Int) -> CGFloat {
    CGFloat(6 + (index % 3) * 3)
  }

  private func staticY(_ index: Int, height: CGFloat) -> CGFloat {
    height * CGFloat(6 + ((index * 53) % 34)) / 100
  }

  private func animatedY(_ index: Int, height: CGFloat) -> CGFloat {
    hasEntered ? staticY(index, height: height) : -18
  }
}
