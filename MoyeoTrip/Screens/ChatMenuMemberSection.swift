//
//  ChatMenuMemberSection.swift
//  MoyeoTrip
//
//  20-1 채팅방 사이드 메뉴의 「동행자」 구역. `ChatMenuBody` 타입 본문이 300줄을 넘어 갈라냈다.
//

import SwiftUI

/// 동행자 목록. 멤버 행의 ⋯ 가 20-1a 멤버 액션 시트를 연다.
struct ChatMenuMemberSection: View {
    let members: [ChangelogPerson]
    let capacityText: String
    /// 내보내기 안내는 호스트에게만 보인다 (IOS-F116).
    let isCurrentUserHost: Bool
    let onMemberMore: (ChangelogPerson) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text("동행자 \(members.count)")
              .font(MoyeoTypography.cardTitle)
            Spacer()
            // 서버 값을 아직 못 받았으면 비어 있다 — 그 자리에 가짜 숫자를 넣지 않는다 (IOS-F68).
            if !capacityText.isEmpty {
              Text(capacityText)
                .font(MoyeoTypography.cardMeta)
                .foregroundStyle(MoyeoTheme.muted)
            }
          }
          ForEach(members) { member in
            HStack(spacing: 11) {
              if let profileImageURL = member.profileImageURL {
                CachedRemoteImage(url: profileImageURL) { image in
                  image
                    .resizable()
                    .scaledToFill()
                } placeholder: {
                  MoyeoTheme.leaf
                }
                .frame(width: 38, height: 38)
                .clipShape(Circle())
              } else {
                MascotAvatar(mascot: member.mascot, size: 38, background: MoyeoTheme.leaf)
              }
              VStack(alignment: .leading, spacing: 2) {
                Text(member.name).font(.subheadline.weight(.bold))
                Text(member.detail)
                  .font(.caption2)
                  .foregroundStyle(MoyeoTheme.muted)
              }
              Spacer()
              if !member.role.isEmpty {
                Text(member.role)
                  .font(.caption2.weight(.bold))
                  .foregroundStyle(MoyeoTheme.forest)
                  .padding(.horizontal, 9)
                  .frame(height: 26)
                  .background(MoyeoTheme.leaf)
                  .clipShape(Capsule())
              }
              // ⋯ 는 **나를 뺀 모두**에게 둔다. 예전에는 역할 배지가 있으면 ⋯ 를 그리지
              // 않아, 호스트+나 둘뿐인 방에서는 멤버 액션 시트(프로필 카드·친구 요청·차단)에
              // 닿을 길이 아예 없었다 (IOS-F53).
              if !member.isMe {
                Button {
                  onMemberMore(member)
                } label: {
                  Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
                    .foregroundStyle(MoyeoTheme.muted)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(member.name) 더보기")
                .accessibilityIdentifier("chatMenu.member.more.\(member.name)")
              }
            }
            .frame(minHeight: 54)
          }
          // 내보내기 안내는 **호스트에게만** 보인다. 예전에는 어떤 조건에도 걸리지 않아
          // 참가자에게도 「내보내기를 할 수 있어요」라고 적혔다 (IOS-F116).
          if isCurrentUserHost {
            Text("호스트는 멤버 우측 더보기에서 내보내기를 할 수 있어요. 사유 입력은 필수이고, 내보낸 자리는 대기 순서대로 자동으로 채워져요.")
              .font(.caption2)
              .foregroundStyle(MoyeoTheme.text400)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.top, 4)
          }
        }
        .padding(18)
    }
}
