//
//  ProfileCardCompanion.swift
//  MoyeoTrip
//
//  화면기획 25 프로필 카드가 그리는 값 — changeLog18.
//

import SwiftUI

// MARK: - 카드가 그리는 값

/// 25 카드 한 장이 그리는 값.
///
/// 진입점마다 서버가 주는 필드가 다르다 — 도감은 나와 동행한 횟수·내가 남긴 메시지까지 주고,
/// 피드 작성자는 닉네임과 이미지뿐이다. **받은 값만 채우고 없는 칸은 지운다.**
struct ProfileCardCompanion: Hashable {
  struct Memory: Hashable, Identifiable {
    let id: String
    let tripTitle: String
    let tripDate: String
    let oneLineReview: String?
  }

  struct ReceivedReview: Hashable, Identifiable {
    let id: String
    let reviewerNickname: String
    let reviewerNicknameColor: String?
    let content: String
  }

  struct Stat: Hashable, Identifiable {
    let id: String
    let label: String
    let value: String
  }

  var nickname: String
  var nicknameColor: String?
  var userID: Int64?
  /// 27 도감의 동물 아바타. 실서버 응답에는 동물 종류가 없어 nil 이다.
  var mascot: String?
  var profileImageURL: URL?
  /// 나와 함께 간 횟수. 도감에서 들어왔을 때만 안다.
  var tripCount: Int?
  var mannerRating: Double?
  var latestTripTitle: String?
  var latestTripDate: String?
  var introduction: String?
  var travelStyles: [String] = []
  var memories: [Memory] = []
  var receivedReviews: [ReceivedReview] = []

  /// 횟수 지표 스트립. `여행` · `호스트` · `피드` 는 어떤 응답에도 없어 지금은 항상 비어 있다 —
  /// 숫자를 지어내지 않는다 (changeLog18 §4). 응답에 생기면 여기에 채운다.
  ///
  /// 평균 매너 점수는 이 스트립에 넣지 않는다. 단위가 다르고(점 vs 회), 매너만 내려오는
  /// 진입점에서는 한 칸짜리 전체폭 스트립이 남아 어색했다 — 별도 메타 줄로 보여준다.
  var stats: [Stat] { [] }

  /// "4.8" / "5"
  static func ratingText(_ rating: Double) -> String {
    String(format: "%g", rating)
  }

  /// "경주 단풍·야경 모임 · 2026.08.23". 제목이 없으면 줄을 만들지 않는다.
  var latestTripText: String? {
    guard let latestTripTitle, !latestTripTitle.isEmpty else { return nil }
    guard let latestTripDate, !latestTripDate.isEmpty else { return latestTripTitle }
    return "\(latestTripTitle) · \(latestTripDate)"
  }

  /// 서버의 "2026-08-23" → 화면기획 표기 "2026.08.23".
  static func dateText(_ serverDate: String) -> String {
    serverDate.replacingOccurrences(of: "-", with: ".")
  }
}

extension ProfileCardCompanion {
  /// 진입점이 준 값 + 공개 프로필 + 받은 평가를 합친다.
  init(
    subject: ProfileCardSubject,
    profile: ServerPublicProfile?,
    receivedReviews reviews: [ServerReceivedTravelReview]
  ) {
    switch subject {
    case .planningMock:
      self = .planningMock
    case .mockFriend(let friendID):
      self = Self.mock(friendID: friendID) ?? .planningMock
    case .serverCompanion(let companion):
      self.init(companion: companion)
    case .serverUser(let reference):
      self.init(
        nickname: reference.nickname,
        userID: reference.userID,
        profileImageURL: reference.profileImageUrl.flatMap(URL.init(string:)),
        introduction: reference.introduction
      )
    }
    applyServerValues(profile: profile, reviews: reviews)
  }

  /// 27 도감 응답 한 건. 나와 동행한 횟수 · 최근 동행 · 내가 남긴 메시지가 여기서 온다.
  private init(companion: ServerTravelDexCompanion) {
    let title = companion.latestTripTitle
    self.init(
      nickname: companion.nickname,
      userID: companion.userId,
      profileImageURL: companion.profileImageURL,
      tripCount: companion.tripCount,
      mannerRating: companion.mannerRating,
      latestTripTitle: title.isEmpty ? nil : title,
      latestTripDate: Self.dateText(companion.latestTripDate),
      memories: companion.memories.enumerated().map { index, memory in
        Memory(
          id: "\(memory.chatRoomId).\(index)",
          tripTitle: memory.tripTitle,
          tripDate: Self.dateText(memory.tripDate),
          oneLineReview: memory.oneLineReview
        )
      }
    )
  }

  /// 공개 프로필·받은 평가가 도착하면 그 값으로 덮는다. 실패하면 해당 칸만 비어 있게 남는다.
  private mutating func applyServerValues(
    profile: ServerPublicProfile?,
    reviews: [ServerReceivedTravelReview]
  ) {
    if let profile {
      // 목록 응답에는 닉네임 색이 없다 — 색은 공개 프로필에서만 온다.
      nicknameColor = profile.nicknameColor ?? nicknameColor
      if let serverNickname = profile.nickname, !serverNickname.isEmpty {
        nickname = serverNickname
      }
      profileImageURL = profile.profileImageURL ?? profileImageURL
      introduction = profile.introduction ?? introduction
      mannerRating = profile.mannerRating ?? mannerRating
      if !profile.travelStyleLabels.isEmpty {
        travelStyles = profile.travelStyleLabels
      }
    }
    if !reviews.isEmpty {
      receivedReviews = reviews.enumerated().map { index, review in
        ReceivedReview(
          id: "\(review.reviewerId).\(index)",
          reviewerNickname: review.reviewerNickname,
          reviewerNicknameColor: review.reviewerNicknameColor,
          content: review.content
        )
      }
    }
  }

  /// 화면기획 25 의 기준 목데이터 — 27 도감의 '우직한 곰 7821' 을 눌러 들어온 상태.
  /// 캡처 라우트(`UITEST_SCREEN=profile` · `profile-back`)가 이 값을 그린다.
  ///
  /// 화면기획 목데이터에는 `여행 12 · 호스트 3 · 피드 21` 이 있지만 서버가 주지 않는 값이라
  /// 앱은 그 칸을 만들지 않는다 — 기획 캡처와 그 칸에서 달라지는 것은 정상이다 (changeLog18 §4).
  static let planningMock = ProfileCardCompanion(
    nickname: "우직한 곰 7821",
    nicknameColor: MoyeoUserColor.orange.rawValue,
    mascot: "🐻",
    tripCount: 2,
    mannerRating: 4.8,
    latestTripTitle: "경주 단풍·야경 모임",
    latestTripDate: "2026.08.23",
    introduction: "사진 찍는 걸 좋아해요. 천천히 걷는 여행을 좋아합니다.",
    travelStyles: ["사진", "자연"],
    memories: [
      Memory(
        id: "profile-card-mock.1",
        tripTitle: "경주 단풍·야경 모임",
        tripDate: "2026.08.23",
        oneLineReview: "사진 정말 잘 찍어주셨어요!"
      ),
      Memory(
        id: "profile-card-mock.2",
        tripTitle: "주왕산 힐링 트레킹",
        tripDate: "2026.06.14",
        oneLineReview: nil
      )
    ],
    receivedReviews: [
      ReceivedReview(
        id: "profile-card-mock-review.1",
        reviewerNickname: "고요한 두루미 1130",
        reviewerNicknameColor: MoyeoUserColor.skyBlue.rawValue,
        content: "약속 시간을 정확히 지키고 사진도 많이 남겨주셨어요."
      ),
      ReceivedReview(
        id: "profile-card-mock-review.2",
        reviewerNickname: "잔잔한 거북이 9032",
        reviewerNicknameColor: MoyeoUserColor.mint.rawValue,
        content: "걷는 속도를 계속 맞춰줘서 편했습니다."
      )
    ]
  )

  /// 목데이터 도감(로그인 전 · 캡처)에서 그릴 카드.
  static func mock(friendID: String) -> ProfileCardCompanion? {
    guard let friend = MockData.dogamFriends.first(where: { $0.id == friendID }) else { return nil }
    if friend.nickname == planningMock.nickname {
      return planningMock
    }
    // 나머지 목데이터 친구는 27 도감이 들고 있는 값(닉네임 · 동물 · 동행 횟수)까지만 그린다.
    // 최근 동행 제목 · 매너 점수 · 소개 · 여행 스타일 · 평가는 목데이터에 없어 칸을 만들지 않는다.
    return ProfileCardCompanion(
      nickname: friend.nickname,
      mascot: friend.avatar,
      tripCount: friend.metCount
    )
  }
}
