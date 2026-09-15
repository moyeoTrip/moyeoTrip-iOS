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
///
/// **`.me` 분기는 없다.** 내 카드도 `serverUser` 로 들어간다(`MyView.myProfileSubject`) —
/// 별도 분기가 공개 프로필을 합치지 않아 내 카드에만 매너 점수·여행·피드가 빠졌었다.
enum ProfileCardSubject: Hashable {
  /// 유저 id 를 모르는 진입점. 그릴 근거가 없어 카드 대신 빈 상태를 그린다 (NO-MOCK-CANON R1).
  case unavailable
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
  /// 진입점이 이미 알고 있으면 넘긴다 — **카드 색이 한 박자 늦게 바뀌지 않게** 한다.
  /// 색은 공개 프로필에서만 오므로, 모르는 채 열면 기본색으로 그렸다가 응답이 온 뒤 바뀐다.
  /// 마이 화면은 `GET users/me/profile` 로 이미 색을 갖고 있다.
  let nicknameColor: String?

  init(
    userID: Int64,
    nickname: String,
    profileImageUrl: String? = nil,
    introduction: String? = nil,
    nicknameColor: String? = nil
  ) {
    self.userID = userID
    self.nickname = nickname
    self.profileImageUrl = profileImageUrl
    self.introduction = introduction
    self.nicknameColor = nicknameColor
  }
}

struct ProfileCardView: View {
  let subject: ProfileCardSubject

  /// 내 카드인지. 자기에게 친구 신청을 걸 수는 없어 하단 동작을 하나 줄인다.
  private var isMe: Bool {
    // 대상 userId 가 나면 내 카드다 — 마이에서 열든 피드 작성자를 눌러 열든 같다.
    if let id = subject.userID, let mine = MoyeoCurrentUser.id { return id == mine }
    return false
  }

  /// 공개 프로필 — 닉네임 색상 · 소개 · 여행 스타일 · 평균 매너 점수
  @State private var publicProfile: ServerPublicProfile?
  /// 다른 여행자들이 남긴 평가 (뒷면)
  @State private var receivedReviews: [ServerReceivedTravelReview]?
  /// 나와의 동행 정보 — 「N회 동행」 배지 · 「최근 동행」 줄 · 뒷면의 내가 남긴 한 줄 메시지.
  ///
  /// 도감(27)에서 들어오면 `.serverCompanion` 으로 이미 들고 오지만, **유저 id 만 아는
  /// 진입점**(피드 작성자 · 멤버 · 캡처 라우트)에서는 그 값이 없어 세 칸이 통째로 사라졌다 —
  /// 같은 화면이 들어온 길에 따라 달라 보였다 (25, 사용자 지적 2026-09-09).
  /// `GET /users/me/travel-dex` 에 그 값이 다 있으니 찾아서 채운다.
  @State private var dexCompanion: ServerTravelDexCompanion?
  /// 친구 신청 결과. 예전에는 이 줄이 `Text` 라 **눌러도 아무 일이 없었다** (IOS-F21·F49).
  @State private var friendRequestMessage: String?
  @State private var didSendFriendRequest = false
  @State private var isSendingFriendRequest = false

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
    // 도감에서 들어왔으면 그 값이 이미 대상 안에 있다. 아니면 찾아 둔 도감 항목으로 바꿔 끼운다.
    let resolvedSubject: ProfileCardSubject = {
      if case .serverUser = subject, let dexCompanion {
        return .serverCompanion(dexCompanion)
      }
      return subject
    }()
    return ProfileCardCompanion(
      subject: resolvedSubject,
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
        ProfileCardActionBar(
          isMe: isMe,
          friendRequestTitle: didSendFriendRequest ? "친구 신청 보냄" : "친구 신청",
          isFriendRequestEnabled: subject.userID != nil && !isSendingFriendRequest && !didSendFriendRequest,
          resultMessage: friendRequestMessage,
          onFlip: {
            // 버튼에는 방향이 없다 — 오른쪽으로 돈다.
            flip(by: 1)
          },
          onSendFriendRequest: sendFriendRequest
        )
      }
    }
    .background(MoyeoTheme.subtleBackground.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
    .task { await loadServerValues() }
    .accessibilityIdentifier("screen.profile")
  }

  /// 25 에서 할 수 있는 유일한 동작 — `POST /users/me/friend-requests/{userId}`.
  /// 20-1a 멤버 시트가 쓰는 것과 같은 엔드포인트다.
  private func sendFriendRequest() {
    guard let userID = subject.userID, !isSendingFriendRequest, !didSendFriendRequest else { return }
    isSendingFriendRequest = true
    Task {
      defer { isSendingFriendRequest = false }
      do {
        try await SocialAPIClient.shared.sendFriendRequest(userID: userID)
        didSendFriendRequest = true
        friendRequestMessage = "친구 신청을 보냈어요. 상대가 수락하면 친구 목록에 들어와요."
      } catch {
        friendRequestMessage = error.moyeoUserMessage(
          fallback: "친구 신청을 보내지 못했어요. 잠시 후 다시 시도해주세요."
        )
      }
    }
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
    // 도감에서 들어온 경우에는 이미 값이 있어 부르지 않는다.
    if case .serverUser = subject, dexCompanion == nil {
      let dex = try? await SocialAPIClient.shared.travelDex()
      // 도감에 없으면 나와 동행한 적이 없는 사람이다 — 그 칸은 비워 둔다(지어내지 않는다).
      dexCompanion = dex?.companions.first { $0.userId == userID }
    }
  }
}

extension ProfileCardSubject {
  /// 라우트 식별용 안정 키. `hashValue` 는 실행마다 값이 달라져 쓸 수 없다.
  var routeKey: String {
    switch self {
    case .unavailable:
      return "unavailable"
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
          // ENV-009 — 화살표 그림 크기는 그대로 두고 누를 넓이만 44x44 로 넓힌다
        Image(systemName: "chevron.left")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(MoyeoTheme.ink)
          .frame(width: 44, height: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("뒤로")
      .accessibilityIdentifier("profile.back")

      Spacer()

      Text(title)
        .font(.subheadline.weight(.heavy))
        .foregroundStyle(MoyeoTheme.ink)

      Spacer()

      // ENV-009 — 뒤로 버튼과 같은 44 로 맞춰 제목 가운데 정렬을 유지한다
      Color.clear
        .frame(width: 44, height: 44)
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
  let friendRequestTitle: String
  let isFriendRequestEnabled: Bool
  /// 신청 결과 한 줄. 성공도 실패도 여기에 적는다 — 눌렀는데 화면이 그대로면 고장으로 보인다.
  let resultMessage: String?
  let onFlip: () -> Void
  let onSendFriendRequest: () -> Void

  var body: some View {
    VStack(spacing: 8) {
      if let resultMessage {
        Text(resultMessage)
          .font(MoyeoTypography.tinyMeta)
          .foregroundStyle(MoyeoTheme.muted)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity)
          .accessibilityIdentifier("profile.friendRequest.result")
      }
      HStack(spacing: 10) {
        Button(action: onFlip) {
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
          // 예전에는 이 줄이 `Button` 이 아니라 **`Text`** 였다. 초록 알약으로 보이는데
          // 눌러도 아무 일이 없었고, 감사가 「핸들러가 있나」만 봐서 놓쳤다 (IOS-F21·F49).
          Button(action: onSendFriendRequest) {
            Text(friendRequestTitle)
              .font(MoyeoTypography.font(size: 14, weight: .semibold))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .frame(height: 48)
              .background(isFriendRequestEnabled ? MoyeoTheme.forest : MoyeoTheme.text400)
              .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          }
          .buttonStyle(.plain)
          .disabled(!isFriendRequestEnabled)
          .accessibilityIdentifier("profile.friendRequest")
        }
      }
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 28)
  }
}
