//
//  MeetingsView.swift
//  MoyeoTrip
//

// 실서버 신청중(my-waiting) 목록이 더해져 길어졌다 — 기존 화면 파일들과 같은 예외를 둔다.
// swiftlint:disable file_length
import SwiftUI

enum MeetingSegment: String, CaseIterable, Hashable {
  case ongoing = "진행중"
  case applied = "신청중"
  case confirmed = "확정"
  case ended = "종료"
}

struct MeetingsView: View {
  @Binding var chatThreads: [ChatThread]
  var tripContext = TripInteractionContext()
  @State private var segment: MeetingSegment
  /// 실서버 신청중 목록 — 로그인 세션이 있고 my-waiting API가 성공했을 때만 채워진다 (nil = 목데이터)
  @State private var serverWaiting: [ServerWaitingRoom]?
  /// 실서버 내 모임 목록 — chat-rooms/my 가 성공했을 때만 채워진다 (nil = 목데이터)
  @State private var serverRooms: [ServerMyChatRoom]?

  init(
    chatThreads: Binding<[ChatThread]>,
    tripContext: TripInteractionContext = TripInteractionContext(),
    initialSegment: MeetingSegment = .ongoing
  ) {
    _chatThreads = chatThreads
    self.tripContext = tripContext
    _segment = State(initialValue: initialSegment)
  }

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

      MeetingSegmentTabs(
        selectedSegment: $segment,
        threads: chatThreads,
        appliedCountOverride: serverWaiting?.count,
        serverCounts: serverSegmentCounts
      )
      .padding(.horizontal, 18)
      .padding(.bottom, 8)

      ScrollView {
        if segment == .applied {
          if let serverWaiting {
            // 실서버 신청중 목록 — 서버가 준 대기 방만 그린다
            ServerWaitingTripList(rooms: serverWaiting) { roomID in
              await cancelServerApplication(roomID: roomID)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 132)
          } else {
            AppliedTripList(trips: appliedTrips, context: tripContext)
              .padding(.horizontal, 18)
              .padding(.bottom, 132)
          }
        } else if serverRooms != nil {
          // 실서버 내 모임 목록 — chat-rooms/my 가 준 방만 그린다
          ServerMeetingList(threads: serverThreads(for: segment), segment: segment)
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
    .task {
      guard MoyeoServerSync.isEnabled, serverWaiting == nil else { return }
      serverWaiting = try? await ChatRoomAPIClient.shared.myWaitingRooms()
    }
    .task {
      guard MoyeoServerSync.isEnabled, serverRooms == nil else { return }
      serverRooms = try? await ChatRoomAPIClient.shared.myRooms()
    }
    .accessibilityIdentifier("screen.meetings")
  }

  /// 세그먼트별 서버 방 목록 — 서버 상태(status·ended)로만 나눈다
  private func serverThreads(for segment: MeetingSegment) -> [ChatThread] {
    guard let serverRooms else { return [] }
    let rooms: [ServerMyChatRoom]
    switch segment {
    case .ongoing:
      rooms = serverRooms.filter { !$0.ended }
    case .applied:
      rooms = []
    case .confirmed:
      rooms = serverRooms.filter { !$0.ended && $0.status == "CONFIRMED" }
    case .ended:
      rooms = serverRooms.filter(\.ended)
    }
    return rooms.map(ServerTripMapper.chatThread(from:))
  }

  private var serverSegmentCounts: [MeetingSegment: Int]? {
    guard serverRooms != nil else { return nil }
    return [
      .ongoing: serverThreads(for: .ongoing).count,
      .confirmed: serverThreads(for: .confirmed).count,
      .ended: serverThreads(for: .ended).count
    ]
  }

  private func cancelServerApplication(roomID: Int64) async {
    do {
      try await ChatRoomAPIClient.shared.cancelApplication(roomID: roomID)
      serverWaiting?.removeAll { $0.roomId == roomID }
    } catch {
      // 취소 실패 시 목록을 유지한다 — 다음 진입에서 서버 상태로 다시 맞춰진다
    }
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
  /// 실서버 신청중 개수 — 서버 데이터가 있으면 목데이터 개수 대신 쓴다
  var appliedCountOverride: Int?
  /// 실서버 내 모임 개수 — chat-rooms/my 가 성공했을 때만 채워진다
  var serverCounts: [MeetingSegment: Int]?

  var body: some View {
    HStack(spacing: 0) {
      ForEach(MeetingSegment.allCases, id: \.self) { item in
        let count = item == .applied
          ? (appliedCountOverride ?? threads.count(for: item))
          : (serverCounts?[item] ?? threads.count(for: item))

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
          .frame(height: 48)
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
    LazyVStack(alignment: .leading, spacing: 0) {
      ForEach(Array(trips.enumerated()), id: \.element.id) { index, trip in
        let waiting = index == 0
        let tint = waiting ? MoyeoTheme.warningBackground : MoyeoTheme.leaf
        let tintText = waiting ? MoyeoTheme.warningText : MoyeoTheme.onLeaf

        VStack(alignment: .leading, spacing: 0) {
          if index == 0 || index == 1 {
            AppliedSectionHeader(title: waiting ? "호스트 승인을 기다리는 중" : "대기열에 있는 모임")
          }

          HStack(alignment: .top, spacing: 12) {
            if let course = MockData.course(for: trip.courseID) {
              MoyeoPhotoTile(
                mascot: course.mascot,
                mood: course.mood,
                height: 56,
                cornerRadius: 16
              )
              .frame(width: 56)
            }

            VStack(alignment: .leading, spacing: 0) {
              HStack(spacing: 6) {
                Text(trip.title)
                  .font(MoyeoTypography.font(size: 14, weight: .bold, relativeTo: .headline))
                  .foregroundStyle(MoyeoTheme.ink)
                  .lineLimit(1)
                Text(waiting ? "승인 대기" : "대기열 \(index + 1)번")
                  .font(MoyeoTypography.font(size: 11, weight: .bold, relativeTo: .caption))
                  .foregroundStyle(tintText)
                  .padding(.horizontal, 9)
                  .frame(height: 22)
                  .background(tint)
                  .clipShape(Capsule())
              }

              Text(trip.schedule)
                .font(MoyeoTypography.font(size: 12, relativeTo: .caption))
                .foregroundStyle(MoyeoTheme.text400)
                .padding(.top, 4)
              Text(trip.meetupPoint)
                .font(MoyeoTypography.font(size: 12, relativeTo: .caption))
                .foregroundStyle(MoyeoTheme.text400)
                .padding(.top, 2)

              Text(
                waiting
                  ? "호스트가 확인하면 참여 여부가 정해져요. 보통 24시간 이내에 응답해요."
                  : "정원이 차서 대기 중이에요. 자리가 나면 순서대로 자동 합류돼요."
              )
              .font(MoyeoTypography.font(size: 12, relativeTo: .caption))
              .foregroundStyle(tintText)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.horizontal, 11)
              .padding(.vertical, 9)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(tint)
              .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
              .padding(.top, 8)

              HStack(spacing: 8) {
                Button {
                  context.onCancelApplication(trip)
                } label: {
                  AppliedTripActionLabel(title: "신청 취소")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("meeting.applied.cancel.\(trip.id)")

                NavigationLink(value: trip) {
                  AppliedTripActionLabel(title: "모집 상세")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("meeting.applied.detail.\(trip.id)")
              }
              .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
          Rectangle()
            .fill(MoyeoTheme.softLine)
            .frame(height: 1)
        }
        .accessibilityIdentifier("meeting.applied.\(trip.id)")
      }

      Text("신청 상태에서는 아직 채팅방에 들어갈 수 없어요. 승인되거나 자리가 나면 알림으로 알려드릴게요.")
        .font(.caption2)
        .foregroundStyle(MoyeoTheme.text400)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 4)
        .accessibilityIdentifier("meeting.applied.footnote")
    }
  }
}

/// 실서버 내 모임 목록 (19) — chat-rooms/my 가 준 방만 그린다
private struct ServerMeetingList: View {
  let threads: [ChatThread]
  let segment: MeetingSegment

  var body: some View {
    if threads.isEmpty {
      VStack(spacing: 6) {
        Text(emptyTitle)
          .font(.subheadline.weight(.heavy))
          .foregroundStyle(MoyeoTheme.ink)
        Text("탐색에서 마음에 드는 모임을 찾아보세요.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(MoyeoTheme.muted)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 44)
      .accessibilityIdentifier("meeting.server.empty.\(segment.rawValue)")
    } else {
      ChatListView(threads: threads)
    }
  }

  private var emptyTitle: String {
    switch segment {
    case .confirmed:
      return "확정된 여행이 없어요"
    case .ended:
      return "종료된 여행이 없어요"
    default:
      return "진행 중인 모임이 없어요"
    }
  }
}

/// 실서버 신청중 목록 — 승인 대기(PENDING)와 대기열(WAITLISTED)을 서버 상태로 그린다
private struct ServerWaitingTripList: View {
  let rooms: [ServerWaitingRoom]
  let onCancel: (Int64) async -> Void
  @State private var selectedTrip: TripRecruitment?

  var body: some View {
    LazyVStack(alignment: .leading, spacing: 0) {
      if rooms.isEmpty {
        VStack(spacing: 6) {
          Text("신청 중인 모임이 없어요")
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(MoyeoTheme.ink)
          Text("탐색에서 마음에 드는 모임에 함께 가기를 신청해보세요.")
            .font(.caption.weight(.semibold))
            .foregroundStyle(MoyeoTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .accessibilityIdentifier("meeting.applied.server.empty")
      } else {
        ForEach(rooms) { room in
          serverWaitingRow(room)
        }

        Text("신청 상태에서는 아직 채팅방에 들어갈 수 없어요. 승인되거나 자리가 나면 알림으로 알려드릴게요.")
          .font(.caption2)
          .foregroundStyle(MoyeoTheme.text400)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 4)
      }
    }
    .navigationDestination(item: $selectedTrip) { trip in
      TripDetailView(trip: trip)
    }
  }

  private func serverWaitingRow(_ room: ServerWaitingRoom) -> some View {
    let waiting = room.applicationStatus == "PENDING"
    let tint = waiting ? MoyeoTheme.warningBackground : MoyeoTheme.leaf
    let tintText = waiting ? MoyeoTheme.warningText : MoyeoTheme.onLeaf

    return VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top, spacing: 12) {
        CachedRemoteImage(url: room.thumbnail.flatMap(URL.init(string:))) { image in
          image
            .resizable()
            .scaledToFill()
        } placeholder: {
          MoyeoTheme.leaf
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

        VStack(alignment: .leading, spacing: 0) {
          HStack(spacing: 6) {
            Text(room.title)
              .font(MoyeoTypography.font(size: 14, weight: .bold, relativeTo: .headline))
              .foregroundStyle(MoyeoTheme.ink)
              .lineLimit(1)
            Text(statusBadgeText(room))
              .font(MoyeoTypography.font(size: 11, weight: .bold, relativeTo: .caption))
              .foregroundStyle(tintText)
              .padding(.horizontal, 9)
              .frame(height: 22)
              .background(tint)
              .clipShape(Capsule())
          }

          Text(ServerTripMapper.scheduleText(startDate: room.startDate, endDate: room.endDate))
            .font(MoyeoTypography.font(size: 12, relativeTo: .caption))
            .foregroundStyle(MoyeoTheme.text400)
            .padding(.top, 4)
          if let meetingDetails = room.meetingDetails, !meetingDetails.isEmpty {
            Text(meetingDetails)
              .font(MoyeoTypography.font(size: 12, relativeTo: .caption))
              .foregroundStyle(MoyeoTheme.text400)
              .padding(.top, 2)
          }

          Text(
            waiting
              ? "호스트가 확인하면 참여 여부가 정해져요."
              : "정원이 차서 대기 중이에요. 자리가 나면 순서대로 자동 합류돼요."
          )
          .font(MoyeoTypography.font(size: 12, relativeTo: .caption))
          .foregroundStyle(tintText)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, 11)
          .padding(.vertical, 9)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(tint)
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
          .padding(.top, 8)

          HStack(spacing: 8) {
            Button {
              Task { await onCancel(room.roomId) }
            } label: {
              AppliedTripActionLabel(title: "신청 취소")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("meeting.applied.server.cancel.\(room.roomId)")

            Button {
              selectedTrip = ServerTripMapper.placeholderTrip(roomID: room.roomId, title: room.title)
            } label: {
              AppliedTripActionLabel(title: "모집 상세")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("meeting.applied.server.detail.\(room.roomId)")
          }
          .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(.vertical, 16)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(MoyeoTheme.softLine)
        .frame(height: 1)
    }
    .accessibilityIdentifier("meeting.applied.server.\(room.roomId)")
  }

  private func statusBadgeText(_ room: ServerWaitingRoom) -> String {
    switch room.applicationStatus {
    case "PENDING":
      return "승인 대기"
    case "WAITLISTED":
      if let position = room.waitlistPosition {
        return "대기열 \(position)번"
      }
      return "대기열"
    case "REJECTED":
      return "거절됨"
    default:
      return room.applicationStatus
    }
  }
}

/// 신청중 탭의 섹션 머리말
private struct AppliedSectionHeader: View {
  let title: String

  var body: some View {
    Text(title)
      .font(.caption.weight(.bold))
      .foregroundStyle(MoyeoTheme.muted)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 6)
  }
}

private struct AppliedTripActionLabel: View {
  let title: String

  var body: some View {
    Text(title)
      .font(MoyeoTypography.font(size: 12, weight: .semibold, relativeTo: .caption))
      .foregroundStyle(MoyeoTheme.text700)
      .padding(.horizontal, 12)
      .frame(height: 34)
      .background(.clear)
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .stroke(MoyeoTheme.softLine, lineWidth: 1)
      }
      .contentShape(Rectangle())
  }
}
