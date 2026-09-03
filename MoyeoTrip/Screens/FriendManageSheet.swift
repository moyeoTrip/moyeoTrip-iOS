//
//  FriendManageSheet.swift
//  MoyeoTrip
//
//  27-2a 친구 정리 (친구 끊기). 정본 `ATTACH-COMPOSER-CANON.md` §6-5.
//
//  27-2 친구 관리 `내 친구` 행 우측의 ⋯ 에서 온다. 지금까지 그 자리에 아무 동작이 없었다.
//
//  근거: `DELETE /api/v1/users/me/friends/{friendUserId}`
//  경로 변수는 **상대 사용자 ID** 다 — friendshipId 가 아니다 (서버 `FriendController`).
//
//  친구를 끊는 것은 되돌리기 어렵다 — 반드시 한 번 더 묻는다.
//

import SwiftUI

struct FriendManageSheet: View {
    let friend: ServerFriend
    let onOpenProfile: () -> Void
    let onRemoved: () -> Void
    let onClose: () -> Void

    @State private var showsRemoveConfirmation = false
    @State private var isRemoving = false
    @State private var failureMessage: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            MoyeoTheme.overlayScrim
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
            sheet
        }
        .overlay {
            if showsRemoveConfirmation {
                MoyeoConfirmSheet(
                    title: "친구를 끊을까요?",
                    subject: friend.user.nickname,
                    lines: [
                        "친구를 끊으면 서로의 도감 카드에서도 빠져요. 다시 친구가 되면 카드도 돌아와요.",
                        "상대에게는 알리지 않아요."
                    ],
                    cancelTitle: "그대로 둘게요",
                    confirmTitle: "친구 끊기",
                    isDanger: true,
                    isBusy: isRemoving,
                    identifier: "friendRemove",
                    onCancel: { showsRemoveConfirmation = false },
                    onConfirm: { showsRemoveConfirmation = false; remove() }
                )
            }
        }
        .alert(
            "친구 정리",
            isPresented: Binding(
                get: { failureMessage != nil },
                set: { if !$0 { failureMessage = nil } }
            )
        ) {
            Button("확인", role: .cancel) { failureMessage = nil }
        } message: {
            Text(failureMessage ?? "")
        }
        .accessibilityIdentifier("screen.friendManage")
    }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(MoyeoTheme.line)
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 14)

            HStack(spacing: 11) {
                CachedRemoteImage(url: friend.user.profileImageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    MoyeoTheme.leaf
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.user.nickname)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MoyeoTheme.ink)
                    // 서버가 주는 값(마지막 접속)만 적는다 — 동행 횟수는 친구 응답에 없다.
                    if let lastActive = friend.lastActive, !lastActive.isEmpty {
                        Text("\(lastActive) 접속")
                            .font(MoyeoTypography.tinyMeta)
                            .foregroundStyle(MoyeoTheme.muted)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.bottom, 12)

            Rectangle().fill(MoyeoTheme.softLine).frame(height: 1)

            Button(action: onOpenProfile) {
                HStack(spacing: 11) {
                    Image(systemName: "person.text.rectangle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(MoyeoTheme.text700)
                    Text("프로필 카드 보기")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MoyeoTheme.ink)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MoyeoTheme.text400)
                }
                .frame(height: 54)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("friendManage.profile")

            Rectangle().fill(MoyeoTheme.softLine).frame(height: 1)

            Button {
                showsRemoveConfirmation = true
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: "person.badge.minus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(MoyeoTheme.dangerRed)
                    Text("친구 끊기")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MoyeoTheme.dangerRed)
                    Spacer(minLength: 0)
                }
                .frame(height: 54)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isRemoving)
            .accessibilityIdentifier("friendManage.remove")

            Text("친구를 끊으면 서로의 도감 카드에서도 빠져요. 다시 친구가 되면 카드도 돌아와요.")
                .font(MoyeoTypography.tinyMeta)
                .foregroundStyle(MoyeoTheme.text400)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 14)

            Button(action: onClose) {
                Text("닫기")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("friendManage.close")
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .moyeoBottomSheetSurface()
    }

    /// 친구 끊기 — 확인 시트를 지나온 뒤에만 온다.
    private func remove() {
        guard !isRemoving else { return }
        isRemoving = true
        Task {
            do {
                try await SocialAPIClient.shared.removeFriend(friendUserID: friend.user.userId)
                isRemoving = false
                onRemoved()
            } catch {
                isRemoving = false
                failureMessage = (error as? LocalizedError)?.errorDescription ?? "친구를 끊지 못했어요."
            }
        }
    }
}
