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
    /// 어느 여행에서 받은 평가인지 · 받은 날짜. 서버가 주지 않으면 nil 이라 줄을 만들지 않는다.
    var tripTitle: String?
    var createdAt: String?
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
  /// 완료한 여행 수 · 공개 피드 수. 공개 프로필에서만 온다.
  var completedTripCount: Int?
  var feedCount: Int?
  var latestTripTitle: String?
  var latestTripDate: String?
  var introduction: String?
  var travelStyles: [String] = []
  var memories: [Memory] = []
  var receivedReviews: [ReceivedReview] = []

  /// 횟수 지표 스트립 — 서버가 준 값만 칸을 만든다. 지어낸 숫자를 채우지 않는다.
  ///
  /// 호스트 횟수는 **기획에 없다** — 서버도 주지 않고 칸도 만들지 않는다(2026-08-26 확정).
  /// 평균 매너 점수도 이 스트립에 넣지 않는다: 단위가 다르고(점 vs 회), 매너만 내려오는
  /// 진입점에서는 한 칸짜리 전체폭 스트립이 남아 어색했다 — 별도 메타 줄로 보여준다.
  var stats: [Stat] {
    var result: [Stat] = []
    if let completedTripCount {
      result.append(Stat(id: "여행", label: "여행", value: "\(completedTripCount)"))
    }
    if let feedCount {
      result.append(Stat(id: "피드", label: "피드", value: "\(feedCount)"))
    }
    return result
  }

  /// 프로필 이미지가 없을 때 쓰는 아바타. **닉네임의 동물을 따른다** (NO-MOCK-CANON R5).
  /// 표는 `MoyeoNicknameAnimal` 하나뿐이다 — 화면마다 따로 만들면 같은 사람이 다른 동물로 보인다.
  static let unknownAnimalMascot = MoyeoNicknameAnimal.unknown

  static func mascotEmoji(forNickname nickname: String) -> String? {
    MoyeoNicknameAnimal.emoji(forNickname: nickname)
  }

  /// "4.8" / "5.0" — 평균값이라 **소수 한 자리**로 통일한다 (안드로이드가 정본).
  static func ratingText(_ rating: Double) -> String {
    String(format: "%.1f", rating)
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

  /// 서버가 주는 작성 시각은 `2026-08-24T21:24:52.128222` 형태다.
  /// 카드 뒷면에는 날짜만 쓰므로 `T` 앞만 잘라 `2026.08.24` 로 만든다. 없으면 nil 이라 줄을 만들지 않는다.
  static func dayText(_ serverDateTime: String?) -> String? {
    guard let serverDateTime, !serverDateTime.isEmpty else { return nil }
    let day = serverDateTime.split(separator: "T").first.map(String.init) ?? serverDateTime
    return dateText(day)
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
    case .unavailable:
      self.init(nickname: "")
    case .me(let nickname, let profileImageURL, let introduction, let travelStyles):
      self.init(
        nickname: nickname,
        mascot: profileImageURL == nil ? Self.mascotEmoji(forNickname: nickname) : nil,
        profileImageURL: profileImageURL,
        introduction: introduction,
        travelStyles: travelStyles
      )
    case .serverCompanion(let companion):
      self.init(companion: companion)
    case .serverUser(let reference):
      self.init(
        nickname: reference.nickname,
        userID: reference.userID,
        profileImageURL: MoyeoImageURL.resolve(reference.profileImageUrl),
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
      // 프로필 이미지가 없으면 닉네임의 동물로 아바타를 정한다(웹·안드로이드와 같은 규칙).
      if profile.profileImageURL == nil, mascot == nil {
        mascot = Self.mascotEmoji(forNickname: nickname)
      }
      profileImageURL = profile.profileImageURL ?? profileImageURL
      introduction = profile.introduction ?? introduction
      mannerRating = profile.mannerRating ?? mannerRating
      completedTripCount = profile.completedTripCount ?? completedTripCount
      feedCount = profile.feedCount ?? feedCount
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
          content: review.content,
          tripTitle: review.tripTitle,
          createdAt: Self.dayText(review.createdAt)
        )
      }
    }
  }
}
