//
//  MeetingsView.swift
//  MoyeoTrip
//

import SwiftUI

private enum MeetingSegment: String, CaseIterable, Hashable {
  case ongoing = "진행중"
  case applied = "신청"
  case confirmed = "확정"
  case ended = "종료"
}

struct MeetingsView: View {
  @Binding var chatThreads: [ChatThread]
  var tripContext = TripInteractionContext()
  @State private var segment: MeetingSegment = .ongoing

  var body: some View {
    VStack(spacing: 0) {
      MoyeoHeader(
        title: "모임",
        showsBottomBorder: false
      )

      NavigationLink(value: MeetingsRoute.specialMessages) {
        SpecialMessagesEntry()
          .padding(.horizontal, 18)
          .padding(.bottom, 6)
      }
      .buttonStyle(.plain)

      MeetingSegmentTabs(selectedSegment: $segment, threads: chatThreads)
        .padding(.horizontal, 18)
        .padding(.bottom, 8)

      ScrollView {
        if segment == .applied {
          AppliedTripList(trips: appliedTrips, context: tripContext)
            .padding(.horizontal, 18)
            .padding(.bottom, 132)
        } else {
          ChatListView(threads: threads)
            .padding(.horizontal, 18)
            .padding(.top, 0)
            .padding(.bottom, 132)
        }
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .navigationDestination(for: TripRecruitment.self) { trip in
      TripDetailView(
        trip: trip,
        isApplied: tripContext.isApplied(trip),
        threadProvider: tripContext.chatThreadProvider,
        onApplied: tripContext.onApplyTrip,
        onSendChatMessage: tripContext.onSendChatMessage
      )
    }
    .navigationDestination(for: ChatThread.self) { thread in
      if thread.id == "chat-pohang-drive" {
        TripDayView(thread: thread)
      } else {
        ChatRoomView(thread: thread) { message in
          updateThreadPreview(threadID: thread.id, message: message)
        }
      }
    }
    .navigationDestination(for: MeetingsRoute.self) { route in
      switch route {
      case .specialMessages:
        SpecialMessageCardsView()
      }
    }
    .accessibilityIdentifier("screen.meetings")
  }

  private var threads: [ChatThread] {
    switch segment {
    case .ongoing:
      return chatThreads.filter { !$0.isReadOnly }
    case .applied:
      return []
    case .confirmed:
      return chatThreads.filter { !$0.isReadOnly && $0.statusSummary.contains("확정") }
    case .ended:
      return chatThreads.filter(\.isReadOnly)
    }
  }

  private var appliedTrips: [TripRecruitment] {
    let actual = tripContext.trips.filter(tripContext.isApplied)
    return actual.isEmpty ? Array(tripContext.trips.prefix(2)) : actual
  }

  private func updateThreadPreview(threadID: String, message: ChatMessage) {
    guard let index = chatThreads.firstIndex(where: { $0.id == threadID }) else { return }
    chatThreads[index] = chatThreads[index].withAppendedMessage(message)
  }
}

private struct SpecialMessagesEntry: View {
  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "sparkles")
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(MoyeoTheme.forest)
        .frame(width: 34, height: 34)
        .background(MoyeoTheme.leaf)
        .clipShape(Circle())
      VStack(alignment: .leading, spacing: 3) {
        Text("친구 도감 메시지")
          .font(MoyeoTypography.cardTitle)
          .foregroundStyle(MoyeoTheme.ink)
        Text("여행 뒤 남는 특별 메시지를 모아봐요.")
          .font(MoyeoTypography.cardMeta)
          .foregroundStyle(MoyeoTheme.muted)
      }
      Spacer()
      Image(systemName: "chevron.right")
        .font(.caption.weight(.heavy))
        .foregroundStyle(MoyeoTheme.text400)
    }
    .padding(.vertical, 9)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(MoyeoTheme.softLine)
        .frame(height: 1)
    }
  }
}

private struct MeetingSegmentTabs: View {
  @Binding var selectedSegment: MeetingSegment
  let threads: [ChatThread]

  var body: some View {
    HStack(spacing: 0) {
      ForEach(MeetingSegment.allCases, id: \.self) { item in
        let count = threads.count(for: item)

        Button {
          selectedSegment = item
        } label: {
          VStack(spacing: 7) {
            HStack(spacing: 5) {
              Text(item.rawValue)
              Text("\(count)")
            }
            .font(MoyeoTypography.tab)
            .foregroundStyle(selectedSegment == item ? MoyeoTheme.forest : MoyeoTheme.muted)

            Rectangle()
              .fill(selectedSegment == item ? MoyeoTheme.forest : .clear)
              .frame(height: 2)
          }
          .frame(maxWidth: .infinity)
          .frame(height: 36)
          .contentShape(Rectangle())
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("\(item.rawValue), \(count)")
          .accessibilityIdentifier("meetings.segment.\(item.rawValue)")
        }
        .buttonStyle(.plain)
      }
    }
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(MoyeoTheme.softLine)
        .frame(height: 1)
    }
  }
}

extension [ChatThread] {
  fileprivate func count(for segment: MeetingSegment) -> Int {
    switch segment {
    case .ongoing:
      return filter { !$0.isReadOnly }.count
    case .applied:
      return 2
    case .confirmed:
      return filter { !$0.isReadOnly && $0.statusSummary.contains("확정") }.count
    case .ended:
      return filter(\.isReadOnly).count
    }
  }
}

private struct AppliedTripList: View {
  let trips: [TripRecruitment]
  let context: TripInteractionContext

  var body: some View {
    LazyVStack(spacing: 10) {
      ForEach(Array(trips.enumerated()), id: \.element.id) { index, trip in
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            Pill(
              text: index == 0 ? "승인 대기" : "대기 \(index + 2)번",
              tint: index == 0 ? MoyeoTheme.sunrise : MoyeoTheme.river)
            Spacer()
            Text(trip.region).font(.caption.weight(.bold)).foregroundStyle(MoyeoTheme.muted)
          }
          Text(trip.title).font(MoyeoTypography.cardTitle).foregroundStyle(MoyeoTheme.ink)
          Text("승인 전에는 채팅방에 들어갈 수 없어요.")
            .font(.caption).foregroundStyle(MoyeoTheme.muted)
          HStack(spacing: 10) {
            NavigationLink(value: trip) {
              AppliedTripActionLabel(title: "상세 보기")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("meeting.applied.detail.\(trip.id)")

            Button {
              context.onCancelApplication(trip)
            } label: {
              AppliedTripActionLabel(title: "신청 취소")
            }
              .buttonStyle(.bordered)
              .tint(MoyeoTheme.coral)
              .accessibilityIdentifier("meeting.applied.cancel.\(trip.id)")
          }
        }
        .padding(15)
        .background(MoyeoTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(MoyeoTheme.softLine))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .accessibilityIdentifier("meeting.applied.\(trip.id)")
      }
    }
  }
}

private struct AppliedTripActionLabel: View {
  let title: String

  var body: some View {
    Text(title)
      .font(MoyeoTypography.tab)
      .frame(maxWidth: .infinity)
      .frame(height: 42)
      .contentShape(Rectangle())
  }
}
