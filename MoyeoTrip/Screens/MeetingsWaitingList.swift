//
//  MeetingsWaitingList.swift
//  MoyeoTrip
//
//  17 모임 › 신청중 목록. `MeetingsView.swift` 가 500줄을 넘어 갈라냈다.
//

import SwiftUI

struct ServerWaitingTripList: View {
  let rooms: [ServerWaitingRoom]
  /// 19-2 참가 신청 취소 확인을 **화면 바닥**에 띄우기 위해 요청만 위로 올린다.
  /// 이 목록은 스크롤 안에 있어서 여기서 시트를 그리면 목록 영역에 갇힌다.
  let onRequestCancel: (ServerWaitingRoom) -> Void
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
        CachedRemoteImage(url: MoyeoImageURL.resolve(room.thumbnail), fallbackShape: .square) { image in
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
              onRequestCancel(room)
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
