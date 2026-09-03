//
//  MoyeoEmptyState.swift
//  MoyeoTrip
//

import SwiftUI

/// 빈 상태 문구 정본 — `docs/alignment/NO-MOCK-CANON.md` §2.
///
/// 세 플랫폼이 **글자 그대로 같은 문자열**을 쓴다. 화면마다 비슷한 문구를 새로 만들면
/// 같은 자리에서 플랫폼끼리 말이 갈린다.
enum MoyeoEmptyText {
    static let signedOutExplore = "로그인하면 모집 중인 모임을 볼 수 있어요."
    static let signedOutSearch = "로그인하면 모임을 검색할 수 있어요."
    static let noRecruitments = "지금 모집 중인 모임이 없어요."
    static let noSearchResults = "검색 결과가 없어요"
    static let noRecentSearches = "최근 검색어가 없어요."
    static let noNotices = "아직 등록된 공지가 없어요."
    static let noComments = "아직 댓글이 없어요."
    static let noFeeds = "아직 올라온 피드가 없어요."
    /// 26-1 내 피드가 0건일 때. 남의 피드가 없는 것(`noFeeds`)과 다른 상황이라 따로 둔다 —
    /// 여기서는 **내가** 쓰면 채워지므로 무엇을 하면 되는지까지 알려준다.
    static let noMyFeeds = "아직 쓴 피드가 없어요.\n다녀온 여행을 피드로 남겨보세요."
    /// 25-1 카드 뒷면에 함께한 여행도 받은 평가도 없을 때. 뒷면이 통째로 비어 있었다.
    static let noCompanionHistory = "아직 함께한 여행과 평가가 없어요.\n함께 여행하면 기록과 한줄평이 여기 쌓여요."
    /// 25-1 「다른 여행자들이 남긴 평가」가 0건일 때. 제목만 남고 아래가 비어 휑했다 —
    /// 무엇을 하면 채워지는지까지 적는다.
    static let noReceivedReviews = "아직 받은 한줄평이 없어요.\n함께 여행하면 서로 한줄평을 남길 수 있어요."
    static let noChatRooms = "참여 중인 모임이 없어요."
    /// 방은 찾았지만 그릴 메시지가 0건일 때 (20 채팅방 · 21 카드 견본).
    /// 웹 · 안드로이드가 쓰던 문구를 iOS 도 그대로 쓴다.
    static let noChatMessages = "아직 대화가 없어요."
    /// 19-2 취소할 참가 신청이 0건일 때. 웹(`ScreenApplyCancel`)이 쓰던 문구를 정본으로 맞췄다.
    static let noApplications = "신청한 모임이 없어요."
    static let noNotifications = "새 알림이 없어요."
    /// 13-2 내 강퇴 이력이 0건일 때. 웹에만 있던 문구를 세 플랫폼 정본으로 맞췄다.
    static let noKickHistories = "내보내진 모임이 없어요."
    static let loading = "불러오는 중이에요…"
    static let loadFailed = "불러오지 못했어요."
    static let retry = "다시 시도"
}

/// §2 빈 상태 · 로딩 · 오류를 한 모양으로 그린다.
///
/// 목데이터를 지우면서 생긴 자리는 모두 이 뷰가 채운다 — 화면마다 다른 카드를 만들면
/// 같은 "비었음"이 화면마다 달라 보인다.
struct MoyeoEmptyStateView: View {
    let message: String
    var systemImage: String?
    /// 실패 상태에서만 준다 — §2 는 실패에만 다시 시도 버튼을 둔다.
    var onRetry: (() -> Void)?
    var accessibilityIdentifier: String?

    var body: some View {
        VStack(spacing: 9) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(MoyeoTheme.forest)
            }
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MoyeoTheme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let onRetry {
                Button(action: onRetry) {
                    Text(MoyeoEmptyText.retry)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background(MoyeoTheme.forest)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 34)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier ?? "empty.state")
    }
}
