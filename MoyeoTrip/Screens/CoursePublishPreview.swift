//
//  CoursePublishPreview.swift
//  MoyeoTrip
//
//  27-3 「공개하면 이렇게 보여요」 미리보기 카드.
//  `CoursePublishView` 타입 본문이 300줄을 넘어 갈라냈다.
//

import SwiftUI

/// 공개 뒤 탐색·코스 목록에 어떻게 보일지 그대로 보여 주는 카드.
struct CoursePublishPreview: View {
    let course: TravelCourse
    /// 공개 카드에 붙는 작성자. 익명이거나 닉네임을 모르면 nil 이다.
    let authorNickname: String?
    /// 지금 입력칸에 적혀 있는 이름. 미리보기는 **공개될 값**을 보여야 한다.
    let draftTitle: String
    /// 작성자 프로필 이미지 주소. 없으면 닉네임 마스코트로 떨어진다 (R5).
    let authorProfileImageUrl: String?

    var body: some View {
      VStack(alignment: .leading, spacing: 0) {
        ZStack(alignment: .bottomLeading) {
          CachedRemoteImage(url: course.thumbnailURL, fallbackShape: .landscape) { image in
            image
              .resizable()
              .scaledToFill()
          } placeholder: {
            MoyeoTheme.leaf
          }
          .frame(height: 132)
          .clipped()
          Label("여행자 코스", systemImage: "person.fill")
            .font(MoyeoTypography.font(size: 11, weight: .heavy, relativeTo: .caption2))
            .foregroundStyle(MoyeoTheme.forest)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(MoyeoTheme.elevatedCard.opacity(0.94))
            .clipShape(Capsule())
            .padding(12)
        }
        VStack(alignment: .leading, spacing: 0) {
          // 미리보기는 **지금 입력한 이름**을 보여준다 — 공개되는 값과 달라 보이면 안 된다.
          Text(draftTitle.isEmpty ? course.title : draftTitle)
            .font(MoyeoTypography.font(size: 14, weight: .heavy, relativeTo: .subheadline))
          Text("\(course.duration) · \(course.distance) · 방문지 \(course.stops.count)")
            .font(MoyeoTypography.font(size: 11.5, relativeTo: .caption))
            .foregroundStyle(MoyeoTheme.muted)
            .padding(.top, 5)
          HStack(spacing: 7) {
            // 14 코스 상세와 같은 자리다 — 내 프로필 이미지가 있으면 반드시 이미지를 그린다.
            // 없을 때만 닉네임에서 계산한 마스코트로 떨어진다 (R5).
            // 닉네임을 감췄거나 모르면 익명 문구만 남는다.
            if let authorNickname {
              if let avatarURL = MoyeoImageURL.resolve(authorProfileImageUrl) {
                CachedRemoteImage(url: avatarURL) { image in
                  image
                    .resizable()
                    .scaledToFill()
                } placeholder: {
                  MoyeoTheme.leaf
                }
                .frame(width: 22, height: 22)
                .clipShape(Circle())
              } else {
                MascotAvatar(
                  mascot: MoyeoNicknameAnimal.emoji(forNickname: authorNickname)
                    ?? MoyeoNicknameAnimal.unknown,
                  size: 22,
                  background: MoyeoTheme.leaf
                )
              }
            }
            Text(authorNickname.map { "\($0) 님이 다녀온 코스" } ?? "익명 여행자가 다녀온 코스")
              .font(MoyeoTypography.font(size: 11.5, weight: .semibold, relativeTo: .caption))
              .foregroundStyle(MoyeoTheme.text700)
          }
          .padding(.top, 10)
        }
        .padding(14)
      }
      .background(MoyeoTheme.card)
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .overlay(RoundedRectangle(cornerRadius: 16).stroke(MoyeoTheme.softLine))
    }
}
