//
//  SupportEditRoutes.swift
//  MoyeoTrip
//
//  「내가 만든 것을 되돌리는」 화면 7종의 라우트 연결.
//
//  2026-09-04 BE 회신으로 API 가 열려 화면을 붙였다
//  (정본 `docs/api/BACKEND_REQUEST_CHANGES_2026-09-04.md`).
//  `SupportScreens.swift` 의 `SupportDestinationView` 가 300줄 제한에 걸려 여기로 나눴다.
//

import SwiftUI

extension SupportDestinationView {
  /// 23-2·23-3·24-6 은 같은 로더를 모드만 바꿔 쓴다 — 피드를 세 번 다르게 읽지 않는다.
  ///
  /// 캡처·딥링크는 `server-feed-1` 처럼 접두사 붙은 id 로도, 순수 숫자로도 들어온다.
  @ViewBuilder
  private func feedEditRoute(_ feedID: String, mode: FeedEditLoaderView.Mode) -> some View {
    if let id = ServerFeedMapper.feedID(fromPostID: feedID) ?? Int64(feedID) {
      FeedEditLoaderView(feedID: id, mode: mode)
    } else {
      MoyeoEmptyStateView(message: "내가 쓴 기록만 수정하거나 지울 수 있어요.")
    }
  }

  /// 피드 계열(23-2·23-3·24-6·23-1a)과 모임 계열(18-6·18-7·20-6)을 나눠 받는다 —
  /// 한 함수에 일곱 갈래를 두면 순환 복잡도 제한(10)을 넘는다.
  @ViewBuilder
  func editRoute(_ route: SupportRoute) -> some View {
    switch route {
    case .feedActions, .feedDelete, .feedEdit, .commentEdit:
      feedEditRoutes(route)
    default:
      roomEditRoutes(route)
    }
  }

  @ViewBuilder
  private func feedEditRoutes(_ route: SupportRoute) -> some View {
    switch route {
    case .feedActions(let feedID):
      feedEditRoute(feedID, mode: .actions)
    case .feedDelete(let feedID):
      feedEditRoute(feedID, mode: .delete)
    case .feedEdit(let feedID):
      feedEditRoute(feedID, mode: .edit)
    case .commentEdit(let feedID):
      if let id = ServerFeedMapper.feedID(fromPostID: feedID) ?? Int64(feedID) {
        CommentEditView(feedID: id)
      } else {
        MoyeoEmptyStateView(message: MoyeoEmptyText.noComments)
      }
    default:
      EmptyView()
    }
  }

  @ViewBuilder
  private func roomEditRoutes(_ route: SupportRoute) -> some View {
    switch route {
    case .recruitEdit(let roomID):
      if let id = ServerTripMapper.roomID(fromThreadID: roomID) ?? Int64(roomID) {
        RecruitEditView(roomID: id)
      } else {
        MoyeoEmptyStateView(message: "모집 중인 내 모임만 수정할 수 있어요.")
      }
    case .courseTitleEdit(let roomID):
      if let id = ServerTripMapper.roomID(fromThreadID: roomID) ?? Int64(roomID) {
        CourseTitleEditView(roomID: id)
      } else {
        MoyeoEmptyStateView(message: "직접 만든 코스만, 여행 확정 전에 고칠 수 있어요.")
      }
    case .messageDelete(let roomID):
      if let id = ServerTripMapper.roomID(fromThreadID: roomID) ?? Int64(roomID) {
        MessageDeleteView(roomID: id)
      } else {
        MoyeoEmptyStateView(message: "내가 보낸 메시지만 지울 수 있어요.")
      }
    default:
      EmptyView()
    }
  }
}
