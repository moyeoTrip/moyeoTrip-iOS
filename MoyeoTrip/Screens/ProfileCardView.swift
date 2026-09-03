//
//  ProfileCardView.swift
//  MoyeoTrip
//
//  화면기획 25 · 프로필 카드 (3D 기울기 · 뒤집기) / 25-1 · 카드 뒷면 — changeLog18.
//
//  **카드가 곧 그 유저의 프로필이다.** 별도 프로필 화면을 따로 두지 않기 때문에 카드 안에
//  "프로필 보기" 버튼도 없다(자기 자신을 가리키게 된다). 유저를 눌러 자세히 보는 모든 진입점
//  (도감 27 · 피드 작성자 23 · 멤버 액션 20-1a · 친구 목록 27-2)이 이 화면으로 온다.
//

import SwiftUI

/// 카드가 그릴 대상. 진입점마다 서버가 주는 필드가 달라서, 받은 값만 채우고 없는 칸은 지운다.
enum ProfileCardSubject: Hashable {
  /// 유저 id 를 모르는 진입점. 그릴 근거가 없어 카드 대신 빈 상태를 그린다 (NO-MOCK-CANON R1).
  case unavailable
  /// 내 프로필. `GET /users/me` 응답에는 userID 가 없어 공개 프로필 API 를 부를 수 없다 —
  /// 받은 값(닉네임 · 이미지 · 소개 · 여행 스타일)만 카드에 그린다.
  case me(nickname: String, profileImageURL: URL?, introduction: String?, travelStyles: [String])
  /// 27 도감의 실서버 동행자 — 나와 동행한 횟수 · 내가 남긴 메시지까지 들고 있다
  case serverCompanion(ServerTravelDexCompanion)
  /// 유저 id 만 아는 진입점 (피드 작성자 · 멤버 액션 시트 · 친구 목록)
  case serverUser(ProfileCardUserReference)
}

/// 목록 응답이 주는 최소 정보. 나머지는 공개 프로필 API 로 채운다.
/// 목록 응답에는 `nicknameColor` 가 아직 없어서 색은 공개 프로필을 받은 뒤에 정해진다.
struct ProfileCardUserReference: Hashable {
  let userID: Int64
  let nickname: String
  let profileImageUrl: String?
  let introduction: String?

  init(userID: Int64, nickname: String, profileImageUrl: String? = nil, introduction: String? = nil) {
    self.userID = userID
    self.nickname = nickname
    self.profileImageUrl = profileImageUrl
    self.introduction = introduction
  }
}

struct ProfileCardView: View {
  let subject: ProfileCardSubject

  /// 내 카드인지. 자기에게 친구 신청을 걸 수는 없어 하단 동작을 하나 줄인다.
  private var isMe: Bool {
    if case .me = subject { return true }
    // 남의 카드로 들어왔더라도 대상이 나면 마찬가지다 (피드 작성자가 나인 경우).
    if let id = subject.userID, let mine = MoyeoCurrentUser.id { return id == mine }
    return false
  }

  /// 공개 프로필 — 닉네임 색상 · 소개 · 여행 스타일 · 평균 매너 점수
  @State private var publicProfile: ServerPublicProfile?
  /// 다른 여행자들이 남긴 평가 (뒷면)
  @State private var receivedReviews: [ServerReceivedTravelReview]?

  /// 뒤집힘을 **부호 있는 반회전 수**로 센다. `0` 앞면, `±1` 뒷면, `±2` 다시 앞면.
  /// 부호가 방향이다 — 왼쪽으로 밀면 줄고 오른쪽으로 밀면 는다. `Bool` 이던 동안에는
  /// 어느 쪽으로 밀어도 늘 같은 방향으로 돌았다.
  @State private var flipTurns: Int
  /// 90도에서 면을 바꾼다 — 그 전에 바꾸면 거울상 앞면이 보인다.

  /// 회전·확대. 손가락을 따라가는 동안에는 애니메이션 없이 그대로 갱신한다.
  @State private var rotation = ProfileCardRotation.neutral
  /// 광택 위치. 따라갈 때만 120ms linear 로 흐른다.
  @State private var holoPoint = UnitPoint.center
  /// 카드가 들려 있는 동안의 그림자·후광·광택 세기
  @State private var isLifted = false
  /// 평평한 상태에서 처음 누른 순간을 구분한다. 진입에 짧은 애니메이션을 걸지 않으면
  /// 각도가 튀고, 반대로 따라가는 중에 걸면 손가락을 계속 뒤따라온다 (changeLog18 §2-3-2).
  @State private var hasEntered = false

  /// - Parameter startsFlipped: 25-1 아트보드는 뒷면을 찍으려고 뒤집힌 상태로 연다.
  ///   **실사용 기본값은 앞면이다.**
  init(subject: ProfileCardSubject, startsFlipped: Bool = false) {
    self.subject = subject
    _flipTurns = State(initialValue: startsFlipped ? 1 : 0)
  }

  private var companion: ProfileCardCompanion {
    ProfileCardCompanion(
      subject: subject,
      profile: publicProfile,
      receivedReviews: receivedReviews ?? []
    )
  }

  private var palette: MoyeoUserCardPalette {
    MoyeoUserCardPalette(nicknameColor: companion.nicknameColor)
  }

  var body: some View {
    VStack(spacing: 0) {
      ProfileCardHeader(title: "프로필")

      // 카드는 화면 세로 중앙에 선다 (화면기획 25)
      VStack(spacing: 0) {
        Spacer(minLength: 0)
        if subject.isUnavailable {
          // 누구의 카드인지 모르면 그릴 근거가 없다 — 목 카드를 대신 띄우지 않는다
          MoyeoEmptyStateView(
            message: MoyeoEmptyText.loadFailed,
            systemImage: "person.crop.circle",
            accessibilityIdentifier: "profile.card.empty"
          )
        } else {
          card
        }
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(.horizontal, 20)
      .padding(.top, 4)
      .padding(.bottom, 12)

      if !subject.isUnavailable {
        ProfileCardActionBar(isMe: isMe) {
          // 버튼에는 방향이 없다 — 오른쪽으로 돈다.
          flip(by: 1)
        }
      }
    }
    .background(MoyeoTheme.subtleBackground.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
    .task { await loadServerValues() }
    .accessibilityIdentifier("screen.profile")
  }

  // MARK: 카드

  private var card: some View {
    // 뒤집기는 안쪽 레이어가 맡는다 — 기울기와 한 변환에 합치면 기울기에도 700ms 가 걸려
    // 손가락을 못 따라온다 (changeLog18 §2-4).
    ProfileCardFlip(degrees: Double(flipTurns) * 180) { showsBack in
      faces(showsBack: showsBack)
    }
    .frame(width: ProfileCardMetrics.width)
      .background(glow)
      .overlay {
        // 기울기 좌표는 회전 전 좌표계에서 읽는다 — 회전값이 좌표를 되먹이지 않게 한다.
        GeometryReader { proxy in
          Color.clear
            .contentShape(Rectangle())
            .gesture(cardGesture(size: proxy.size))
        }
      }
      // 바깥 레이어 = 기울기
      .rotation3DEffect(
        .degrees(rotation.degreesX),
        axis: (x: 1, y: 0, z: 0),
        perspective: ProfileCardMetrics.perspective
      )
      .rotation3DEffect(
        .degrees(rotation.degreesY),
        axis: (x: 0, y: 1, z: 0),
        perspective: ProfileCardMetrics.perspective
      )
      .scaleEffect(rotation.scale)
      .accessibilityIdentifier("profile.card")
  }

  /// 앞면이 카드 크기를 정하고, 뒷면은 그 위에 겹친다 — **두 면이 항상 같은 크기다** (웹과 같은 방식).
  /// 한 면씩만 그리면 뒷면이 내용만큼 작아져 뒤집을 때 카드가 줄어들었다.
  private func faces(showsBack: Bool) -> some View {
    ProfileCardFrontFace(
      companion: companion,
      palette: palette,
      holoPoint: holoPoint,
      isLifted: isLifted
    )
    .opacity(showsBack ? 0 : 1)
    .accessibilityHidden(showsBack)
    .overlay {
      if showsBack {
        ProfileCardBackFace(companion: companion, palette: palette, isLifted: isLifted)
          // 컨테이너가 180도 돌아 있으므로 뒷면은 다시 180도 돌려 거울상을 푼다.
          .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
      }
    }
  }

  /// 카드 뒤 후광 — 유저 색이 카드 밖으로 번진다.
  private var glow: some View {
    RoundedRectangle(cornerRadius: ProfileCardMetrics.glowCornerRadius, style: .continuous)
      .fill(palette.glow)
      .padding(-8)
      .blur(radius: 22)
      .opacity(isLifted ? 0.5 : 0.28)
      .allowsHitTesting(false)
  }

  // MARK: 제스처

  /// 기울기와 뒤집기를 한 제스처에서 처리한다. 뒤집기는 손을 뗄 때 가로 이동으로 판정한다.
  private func cardGesture(size: CGSize) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        let point = ProfileCardRotation.unitPoint(for: value.location, in: size)
        if hasEntered {
          // 따라가는 동안에는 withAnimation 을 쓰지 않는다. 걸면 계속 뒤따라오고,
          // 손을 멈춘 뒤에야 남은 보간이 재생되는 것처럼 보인다.
          rotation = ProfileCardRotation.following(point)
          holoPoint = point
        } else {
          hasEntered = true
          withAnimation(ProfileCardMetrics.enterAnimation) {
            rotation = ProfileCardRotation.following(point)
            holoPoint = point
            isLifted = true
          }
        }
      }
      .onEnded { value in
        hasEntered = false
        withAnimation(ProfileCardMetrics.settleAnimation) {
          rotation = .neutral
          holoPoint = .center
          isLifted = false
        }
        if ProfileCardMetrics.isFlipSwipe(value.translation) {
          // 스와이프한 방향으로 돈다 — 왼쪽으로 밀면 왼쪽으로 넘어간다.
          flip(by: value.translation.width < 0 ? -1 : 1)
        }
      }
  }

  /// `direction` 은 `+1`(오른쪽) 또는 `-1`(왼쪽). 스와이프 방향이 그대로 회전 방향이다.
  private func flip(by direction: Int) {
    withAnimation(ProfileCardMetrics.flipAnimation) {
      flipTurns += direction
    }
    // 면 교체는 따로 걸지 않는다 — `ProfileCardFlip` 이 실제 회전값에서 고른다.
  }

  // MARK: 서버 값

  private func loadServerValues() async {
    guard MoyeoServerSync.isEnabled, let userID = subject.userID else { return }
    if publicProfile == nil {
      publicProfile = try? await UserProfileAPIClient.shared.publicProfile(userID: userID)
    }
    if receivedReviews == nil {
      receivedReviews = try? await UserProfileAPIClient.shared.travelReviews(userID: userID)
    }
  }
}

extension ProfileCardSubject {
  /// 라우트 식별용 안정 키. `hashValue` 는 실행마다 값이 달라져 쓸 수 없다.
  var routeKey: String {
    switch self {
    case .unavailable:
      return "unavailable"
    case .me(let nickname, _, _, _):
      return "me.\(nickname)"
    case .serverCompanion(let companion):
      return "companion.\(companion.userId)"
    case .serverUser(let reference):
      return "user.\(reference.userID)"
    }
  }

  /// 서버 공개 프로필을 물어볼 수 있는 유저인지.
  var userID: Int64? {
    switch self {
    case .unavailable:
      return nil
    case .me:
      // 내 카드도 남의 카드와 같은 공개 프로필을 쓴다 — 여행·피드·매너 점수·받은 평가.
      // 여기서 nil 을 주는 동안 내 카드에는 닉네임과 소개만 있었다.
      return MoyeoCurrentUser.id
    case .serverCompanion(let companion):
      return companion.userId
    case .serverUser(let reference):
      return reference.userID
    }
  }

  /// 그릴 근거가 아예 없는 대상인지 — 카드 대신 빈 상태를 그린다.
  var isUnavailable: Bool {
    if case .unavailable = self { return true }
    return false
  }
}

// MARK: - 헤더 · 하단 버튼

/// 25 헤더 — 다른 상세 화면(`CompactDetailHeader`)과 같은 규격(높이 50 · 뒤로 34 · 가운데 제목)이다.
private struct ProfileCardHeader: View {
  @Environment(\.dismiss) private var dismiss
  let title: String

  var body: some View {
    HStack {
      Button {
        dismiss()
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(MoyeoTheme.ink)
          .frame(width: 34, height: 34)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("뒤로")
      .accessibilityIdentifier("profile.back")

      Spacer()

      Text(title)
        .font(.subheadline.weight(.heavy))
        .foregroundStyle(MoyeoTheme.ink)

      Spacer()

      Color.clear
        .frame(width: 34, height: 34)
    }
    .frame(height: 50)
    .padding(.horizontal, 10)
    .background(MoyeoTheme.background)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(MoyeoTheme.softLine)
        .frame(height: 1)
    }
  }
}

/// 카드를 Y축으로 돌리면서 **지금 실제 회전값**으로 어느 면을 그릴지 고른다.
///
/// `Animatable` 을 채택하면 애니메이션 중간값이 `animatableData` 로 들어온다 — 그래서
/// `body` 안의 `degrees` 는 목표값이 아니라 **그 프레임의 각도**다. 면을 시간으로 미루면
/// (예: "700ms 의 절반에 바꾼다") 회전 곡선이 선형이 아닐 때 어긋나, 90도를 지난 뒤에도
/// 앞면이 거울상으로 남는다. SwiftUI 는 뒷면을 잘라 주지 않으므로 그 사이 앞면의
/// 프로필 이미지가 그대로 보였다. 안드로이드가 쓰던 방식(`flipRotation <= 90f`)과 같게 맞췄다.
private struct ProfileCardFlip<Content: View>: View, Animatable {
  var degrees: Double
  @ViewBuilder var content: (Bool) -> Content

  var animatableData: Double {
    get { degrees }
    set { degrees = newValue }
  }

  /// 90도~270도 구간에서는 뒷면이 앞을 향한다. 음수 회전(왼쪽으로 넘김)도 같게 다룬다.
  private var showsBack: Bool {
    var normalized = degrees.truncatingRemainder(dividingBy: 360)
    if normalized < 0 { normalized += 360 }
    return normalized > 90 && normalized < 270
  }

  var body: some View {
    content(showsBack)
      .rotation3DEffect(
        .degrees(degrees),
        axis: (x: 0, y: 1, z: 0),
        perspective: ProfileCardMetrics.perspective
      )
  }
}

/// 하단 `카드 뒤집기` · `친구 신청`.
/// 스와이프로도 뒤집히지만, 뒤집을 수 있다는 걸 알 방법이 필요해 버튼도 둔다 (changeLog18 §2-4).
private struct ProfileCardActionBar: View {
  let isMe: Bool
  let onFlip: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Button(action: onFlip) {
        // 문구를 고정한다 — 누를 때마다 이름이 바뀌면 무엇을 누르는 버튼인지 매번 다시 읽어야 한다.
        // 어느 면인지는 카드가 이미 보여준다.
        Text("카드 뒤집기")
          .font(MoyeoTypography.font(size: 14, weight: .semibold))
          .foregroundStyle(MoyeoTheme.brandText)
          .padding(.horizontal, 20)
          .frame(height: 48)
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("profile.flip")

      // 자기에게 친구 신청을 걸 수는 없다 — 내 카드에서는 그리지 않는다.
      if !isMe {
        // DM 기획이 없다 — 여기서 할 수 있는 행동은 친구 신청뿐이다.
        // 동작은 아직 붙이지 않았다: 성공/실패 안내 문구가 정해지지 않았다.
        // 식별자가 `profile.message` 였다 — 문구와 어긋나 무엇을 잡는지 알 수 없었다.
        Text("친구 신청")
          .font(MoyeoTypography.font(size: 14, weight: .semibold))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 48)
          .background(MoyeoTheme.forest)
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          .accessibilityIdentifier("profile.friendRequest")
      }
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 28)
  }
}

// MARK: - 수치 · 기울기 계산

/// 25 의 고정 수치. 화면기획(`ScreenPublicProfile`)의 px 값을 그대로 pt 로 쓴다.
enum ProfileCardMetrics {
  static let width: CGFloat = 318
  static let cornerRadius: CGFloat = 18
  static let glowCornerRadius: CGFloat = 26
  static let illustrationCornerRadius: CGFloat = 12
  /// 카드 안쪽 정사각형 일러스트의 한 변 (카드 폭 318 − 좌우 여백 12·2)
  static let illustrationSide: CGFloat = width - 24
  /// 화면기획의 CSS `perspective: 900px` 을 카드 폭 기준 상대값으로 옮긴 것 (318 / 900)
  static let perspective: CGFloat = 318.0 / 900.0
  /// 손을 떼면 900ms 로 가라앉는다. 260ms 로는 "띡" 하고 끊겼다 (changeLog18 §2-3).
  static let settleAnimation = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.9)
  /// 평평한 상태에서 누른 자리까지 들어가는 짧은 곡선. 없으면 처음 누를 때 각도가 튄다.
  static let enterAnimation = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.26)
  /// 뒤집기는 700ms (changeLog18 §2-4)
  static let flipAnimation = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.7)
  // 면 교체를 시간으로 미루던 값(`faceSwapDelay`)은 없앴다. 회전 곡선이 아주 빠른
  // ease-out 이라 "절반 시간"이 90도가 아니었고, 90도를 지난 뒤에도 한동안 앞면이
  // 거울상으로 보였다 — 프로필 이미지가 스쳐 보인 원인이다 (사용자가 발견).
  // 지금은 `ProfileCardFlip` 이 **실제 회전값**으로 고른다 (안드로이드와 같은 방식).
  /// 스와이프 뒤집기 최소 가로 이동
  static let flipSwipeDistance: CGFloat = 40

  /// 가로 이동이 세로보다 크고 40pt 이상일 때만 뒤집는다 — 세로 스크롤과 충돌하지 않게.
  static func isFlipSwipe(_ translation: CGSize) -> Bool {
    abs(translation.width) > flipSwipeDistance && abs(translation.width) > abs(translation.height)
  }

  /// CSS `linear-gradient(Ndeg, …)` 의 각도를 SwiftUI 의 시작·끝 `UnitPoint` 로 옮긴다.
  /// CSS 는 0deg 가 위쪽이고 시계 방향으로 커진다.
  static func gradientPoints(cssDegrees: Double) -> (start: UnitPoint, end: UnitPoint) {
    let radians = cssDegrees * .pi / 180
    let dx = sin(radians) / 2
    let dy = -cos(radians) / 2
    return (
      UnitPoint(x: 0.5 - dx, y: 0.5 - dy),
      UnitPoint(x: 0.5 + dx, y: 0.5 + dy)
    )
  }
}

/// 포인터 좌표 → 회전값. 순수 계산만 하므로 단위 테스트로 검증한다.
struct ProfileCardRotation: Equatable {
  var degreesX: Double = 0
  var degreesY: Double = 0
  var scale: Double = 1

  static let neutral = ProfileCardRotation()
  /// 중앙 기준 최대 기울기. 더 키우면 카드 안 글씨가 읽히지 않는다 (changeLog18 §2-3).
  static let maximumDegrees: Double = 10
  static let liftedScale: Double = 1.02

  /// 카드 안의 터치 좌표를 0...1 단위 좌표로 접는다. 카드 밖으로 끌어도 범위를 넘지 않는다.
  static func unitPoint(for location: CGPoint, in size: CGSize) -> UnitPoint {
    guard size.width > 0, size.height > 0 else { return .center }
    return UnitPoint(
      x: min(1, max(0, location.x / size.width)),
      y: min(1, max(0, location.y / size.height))
    )
  }

  /// 화면기획과 같은 식이다: rotateX = (0.5 - y) · 20, rotateY = (x - 0.5) · 20.
  static func following(_ point: UnitPoint) -> ProfileCardRotation {
    ProfileCardRotation(
      degreesX: (0.5 - Double(point.y)) * 2 * maximumDegrees,
      degreesY: (Double(point.x) - 0.5) * 2 * maximumDegrees,
      scale: liftedScale
    )
  }
}
