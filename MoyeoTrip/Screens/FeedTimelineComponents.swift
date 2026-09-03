//
//  FeedTimelineComponents.swift
//  MoyeoTrip
//

import SwiftUI

struct FeedMetricBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(MoyeoTheme.muted)
            Text(value)
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(MoyeoTheme.subtleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct FeedPhotoPreview: View {
    let post: FeedPost
    var height: CGFloat = 166

    /// 사진 한 칸.
    ///
    /// **이미지에 직접 `frame` 을 걸면 안 된다.** `scaledToFill()` 한 이미지는 고유 크기가
    /// 원본 크기라서, `frame(maxWidth: .infinity)` 를 붙여도 부모가 그 고유 폭을 이상적 크기로
    /// 삼아 **카드 전체가 화면보다 넓어진다.** 실제로 iOS 발견 탭에서 사진 2장짜리 피드의
    /// 닉네임·제목까지 좌우가 잘렸다(사용자가 발견).
    ///
    /// `Color.clear` 는 폭·높이를 스스로 주장하지 않으므로 칸 크기를 이것으로 정하고,
    /// 이미지는 `overlay` 로 얹어 레이아웃에 영향을 주지 못하게 한 뒤 `clipped()` 로 자른다.
    @ViewBuilder
    private func photoCell(url: URL?, shape: MoyeoPlaceholderImage.Shape) -> some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                CachedRemoteImage(url: url, fallbackShape: shape) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    MoyeoTheme.leaf
                }
            }
            .clipped()
    }

    var body: some View {
        if post.photoURLs.count > 1 {
            // 웹 · 안드로이드와 같이 앞의 2장을 2px 간격으로 나란히 그린다.
            HStack(spacing: 2) {
                ForEach(post.photoURLs.prefix(2), id: \.self) { url in
                    photoCell(url: url, shape: .square)
                }
            }
        } else if let photoURL = post.photoURL {
            // 실서버 피드 — 서버가 준 첫 번째 사진을 그린다
            photoCell(url: photoURL, shape: .landscape)
        } else if post.isServerBacked {
            // 사진이 없는 서버 피드는 **사진 자리를 아예 두지 않는다** — 웹 · 안드로이드가 그렇다.
            // 예전에는 공용 플레이스홀더(16:9)로 채워 없는 사진이 있는 것처럼 보였다 (R1).
            EmptyView()
        } else {
            MoyeoPhotoTile(
                mascot: post.photoMascot,
                mood: post.mood,
                height: height,
                cornerRadius: 0
            )
        }
    }
}

/// 피드 작성자 아바타 — 서버 피드는 프로필 이미지 URL, 목데이터 피드는 이모지 마스코트
struct FeedAuthorAvatar: View {
    let post: FeedPost
    var size: CGFloat = 34

    var body: some View {
        if let avatarURL = post.authorAvatarURL {
            CachedRemoteImage(url: avatarURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                MoyeoTheme.leaf
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            MascotAvatar(mascot: post.authorAvatar, size: size, background: MoyeoTheme.leaf)
        }
    }
}

extension FeedPost {
    var displayAuthorName: String {
        authorName
    }

    /// changeLog18 — 작성자 아바타·닉네임을 누르면 열리는 25 프로필 카드 대상.
    /// 유저 id 를 모르는 피드는 카드에 그릴 근거가 없다.
    var authorProfileSubject: ProfileCardSubject {
        guard let serverAuthorID else { return .unavailable }
        return .serverUser(
            ProfileCardUserReference(
                userID: serverAuthorID,
                nickname: authorName,
                profileImageUrl: authorAvatarURL?.absoluteString
            )
        )
    }

    /// 사진 자리를 그릴지 — 서버 피드는 실제 사진이 있을 때만이다.
    var hasFeedPhoto: Bool {
        !isServerBacked || photoURL != nil || !photoURLs.isEmpty
    }

    var feedTitle: String {
        if let title, !title.isEmpty {
            return title
        }

        return caption
    }

    /// 부제는 "장소 · #해시태그" 한 줄이다 (4개 플랫폼 공통, docs/alignment/MOCKDATA-CANON.md).
    /// 별도의 태그 칩 줄은 두지 않는다 — 같은 내용을 두 줄로 반복하게 된다.
    var feedSubtitle: String {
        let hashtags: String
        if let subtitle, !subtitle.isEmpty {
            hashtags = subtitle
        } else {
            hashtags = tags.filter { $0 != region }.map { "#\($0)" }.joined(separator: " ")
        }
        return hashtags.isEmpty ? region : "\(region) · \(hashtags)"
    }

    var detailBodyText: String {
        if let detailBody, !detailBody.isEmpty {
            return detailBody
        }

        return caption
    }
}

/// 오프라인 홈의 "저장해둔 코스" 구간.
///
/// 실시간 추천과 인기 순위는 네트워크 없이 만들 수 없으므로, 오프라인에서는
/// 이미 받아둔 코스만 보여주고 연결이 필요한 동작은 자리 표시로 알린다 (화면기획).
struct OfflineSavedCourseSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("저장해둔 코스")
                    .font(MoyeoTypography.sectionTitle)
                    .foregroundStyle(MoyeoTheme.ink)
                Text("오프라인에서도 열려요")
                    .font(MoyeoTypography.chip)
                    .foregroundStyle(MoyeoTheme.muted)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(MoyeoTheme.subtleBackground)
                    .clipShape(Capsule())
                Spacer(minLength: 0)
            }

            // 오프라인에 저장해둔 코스를 읽는 캐시가 아직 없다 — 목록을 지어내지 않고 빈 상태를 그린다
            MoyeoEmptyStateView(
                message: "저장해둔 코스가 없어요.",
                systemImage: "square.and.arrow.down",
                accessibilityIdentifier: "home.offline.saved.empty"
            )

            VStack(alignment: .leading, spacing: 10) {
                Label("모집 신청 · 새 모집 만들기", systemImage: "person.2.fill")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                Text("연결된 뒤에 할 수 있어요. 지금 누르면 저장해뒀다가 연결되면 이어서 진행해요.")
                    .font(.caption)
                    .foregroundStyle(MoyeoTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Text("연결되면 신청할 수 있어요")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MoyeoTheme.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(MoyeoTheme.subtleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(16)
            .background(MoyeoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(MoyeoTheme.softLine))
            .accessibilityIdentifier("home.offline.recruitmentPlaceholder")
        }
        .padding(.horizontal, 18)
    }
}
