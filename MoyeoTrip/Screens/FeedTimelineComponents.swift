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

    var body: some View {
        if let photoURL = post.photoURL {
            // 실서버 피드 — 서버가 준 첫 번째 사진을 그린다
            CachedRemoteImage(url: photoURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                MoyeoTheme.leaf
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
        } else if post.isServerBacked {
            // 사진이 없는 서버 피드 — 빈 배경만 둔다
            MoyeoTheme.leaf
                .frame(maxWidth: .infinity)
                .frame(height: height)
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
    /// 목데이터 피드는 유저 id 가 없어 화면기획 기준 카드를 그린다(웹 프로토타입과 같다).
    var authorProfileSubject: ProfileCardSubject {
        guard let serverAuthorID else { return .planningMock }
        return .serverUser(
            ProfileCardUserReference(
                userID: serverAuthorID,
                nickname: authorName,
                profileImageUrl: authorAvatarURL?.absoluteString
            )
        )
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

struct FeedRouteMap: View {
    let route: [String]
    let mood: CourseMood

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let points = routePoints(in: size)
            let dotSize = max(10, size.height * 0.08)

            ZStack {
                RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                    .fill(routeMapBackground)

                ForEach(0..<4, id: \.self) { index in
                    Rectangle()
                        .fill(routeMapLine)
                        .frame(height: 1)
                        .frame(width: size.width * 0.72)
                        .position(x: size.width * 0.58, y: size.height * (0.22 + CGFloat(index) * 0.17))
                }

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    if points.count > 1 {
                        path.addCurve(
                            to: points[1],
                            control1: CGPoint(x: size.width * 0.30, y: size.height * 0.38),
                            control2: CGPoint(x: size.width * 0.36, y: size.height * 0.62)
                        )
                    }
                    if points.count > 2 {
                        path.addCurve(
                            to: points[2],
                            control1: CGPoint(x: size.width * 0.56, y: size.height * 0.60),
                            control2: CGPoint(x: size.width * 0.62, y: size.height * 0.35)
                        )
                    }
                }
                .stroke(
                    MoyeoTheme.forest,
                    style: StrokeStyle(lineWidth: max(3, size.height * 0.045), lineCap: .round)
                )

                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    Text("\(index + 1)")
                        .font(.system(size: max(7, dotSize * 0.45), weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: dotSize, height: dotSize)
                        .background(Circle().fill(index == 0 ? MoyeoTheme.forest : routeMapDot))
                        .overlay(Circle().stroke(routeMapBackground, lineWidth: max(2, dotSize * 0.24)))
                        .position(point)
                }
            }
        }
    }

    private var routeMapBackground: Color {
        adaptiveColor(light: "#EAF3E6", dark: "#14231A")
    }

    private var routeMapLine: Color {
        adaptiveColor(light: "#D7E1D8", dark: "#2C3C34")
    }

    private var routeMapDot: Color {
        MoyeoTheme.forest
    }

    private func routePoints(in size: CGSize) -> [CGPoint] {
        Array(route.prefix(3).enumerated()).map { index, _ in
            switch index {
            case 0:
                return CGPoint(x: size.width * 0.25, y: size.height * 0.62)
            case 1:
                return CGPoint(x: size.width * 0.50, y: size.height * 0.52)
            default:
                return CGPoint(x: size.width * 0.74, y: size.height * 0.36)
            }
        }
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

            ForEach(MockData.courses.prefix(3)) { course in
                NavigationLink(value: course) {
                    HStack(spacing: 12) {
                        MoyeoPhotoTile(mascot: course.mascot, mood: course.mood, height: 62, cornerRadius: 10)
                            .frame(width: 62)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(course.title)
                                .font(.subheadline.weight(.heavy))
                                .foregroundStyle(MoyeoTheme.ink)
                                .lineLimit(1)
                            Text("\(course.region) · \(course.duration) \(course.distance)")
                                .font(.caption)
                                .foregroundStyle(MoyeoTheme.muted)
                            Text("어제 저장됨")
                                .font(.caption2)
                                .foregroundStyle(MoyeoTheme.text400)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(MoyeoTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(MoyeoTheme.softLine))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.offline.saved.\(course.id)")
            }

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
