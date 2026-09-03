//
//  UITestInitialState.swift
//  MoyeoTrip
//

import SwiftUI

// 캡처 라우트 카탈로그를 한 파일에 모아 두기 때문에 길이 제한을 끈다.
// swiftlint:disable file_length

// Direct-launch routing intentionally centralizes the visual-regression catalog.
// swiftlint:disable type_body_length
struct UITestInitialState {
  var selectedTab: MoyeoTab
  var homePath = NavigationPath()
  var explorePath = NavigationPath()
  var meetingsPath = NavigationPath()
  var myPath = NavigationPath()
  var feedPostID: String?
  var feedStartsWriting = false
  /// 24-1~24-5 단계별 캡처용 시작 단계 (1...5)
  var feedWriteInitialStep = 1
  /// 24-1~24-5 가 기록 대상으로 삼을 방 (`feedwrite1:101`). 지정이 없으면 가장 최근 여행이다.
  var feedWriteRoomID: Int64?
  var exploreStartsInMap = false
  var meetingsInitialSegment: MeetingSegment = .ongoing

  init(arguments: [String]) {
    selectedTab = MoyeoTab.uiTestInitialTab(from: arguments) ?? .home

    guard let screen = UITestScreenRequest(arguments: arguments) else {
      return
    }

    _ =
      applyMyRoute(screen)
      || applyMeetingRoute(screen)
      || applyContentRoute(screen)
      || applyFeedRoute(screen)
      || applySupportRoute(screen)
      || applyExploreRoute(screen)
  }

  private mutating func applyMyRoute(_ screen: UITestScreenRequest) -> Bool {
    // changeLog18 — 25 프로필 카드. 화면기획의 기준 목데이터는 27 도감의 '우직한 곰 7821'이다.
    if screen.matches("profile", "public-profile", "publicprofile") {
      selectedTab = .my
      myPath.append(MyRoute.profile(Self.profileSubject(screen.identifier), startsFlipped: false))
      return true
    }
    // changeLog18 — 25-1 카드 뒷면. 뒤집힌 상태로 여는 캡처 전용 라우트다(실사용 기본값은 앞면).
    if screen.matches("profile-back", "profileback", "public-profile-back", "publicprofileback") {
      selectedTab = .my
      myPath.append(MyRoute.profile(Self.profileSubject(screen.identifier), startsFlipped: true))
      return true
    }
    if screen.matches("profile-edit", "profileedit", "edit-profile", "editprofile") {
      selectedTab = .my
      myPath.append(MyRoute.profileEdit)
      return true
    }
    if screen.matches("profile-taste-edit", "profiletasteedit") {
      selectedTab = .my
      myPath.append(MyRoute.profileTasteEdit)
      return true
    }
    if screen.matches("my-feed", "myfeed") {
      selectedTab = .my
      myPath.append(MyRoute.myFeed)
      return true
    }
    if screen.matches("settings") {
      selectedTab = .my
      myPath.append(MyRoute.settings)
      return true
    }
    if screen.matches("friend-dex", "frienddex") {
      selectedTab = .my
      myPath.append(MyRoute.friendDex)
      return true
    }
    if screen.matches("customer-center", "customercenter", "customer") {
      selectedTab = .my
      myPath.append(MyRoute.customerCenter)
      return true
    }
    return false
  }

  private mutating func applyMeetingRoute(_ screen: UITestScreenRequest) -> Bool {
    if screen.matches("chat-list") {
      selectedTab = .meetings
      meetingsInitialSegment = .ongoing
      return true
    }
    if screen.matches("chat-list-applied") {
      selectedTab = .meetings
      meetingsInitialSegment = .applied
      return true
    }
    // 21 은 실제 방의 실제 메시지로 카드를 그린다 — 캡처는 특수 메시지가 있는 방을 넘긴다.
    if screen.matches("special-messages", "specialmessages") {
      selectedTab = .meetings
      meetingsPath.append(
        MeetingsRoute.specialMessages(screen.identifier.flatMap(MoyeoRoomIDText.roomID(from:))))
      return true
    }
    if screen.matches("chat", "chat-room", "chatroom") {
      selectedTab = .meetings
      appendChat(screen.identifier)
      return true
    }
    return false
  }

  private mutating func applyContentRoute(_ screen: UITestScreenRequest) -> Bool {
    if screen.matches("course", "course-detail", "coursedetail") {
      selectedTab = .home
      appendCourse(screen.identifier)
      return true
    }
    if screen.matches("trip", "trip-detail", "recruitment", "recruitment-detail") {
      selectedTab = .home
      appendTrip(screen.identifier)
      return true
    }
    return false
  }

  private mutating func applyFeedRoute(_ screen: UITestScreenRequest) -> Bool {
    if screen.matches("feed-detail", "feeddetail", "feed-post", "feedpost") {
      selectedTab = .feed
      feedPostID = screen.identifier
      return true
    }
    if screen.matches("feed-write", "feedwrite", "write-feed", "writefeed") {
      selectedTab = .feed
      feedStartsWriting = true
      feedWriteRoomID = screen.identifier.flatMap(Int64.init)
      return true
    }
    for step in 1...5 where screen.matches("feed-write-\(step)", "feedwrite\(step)") {
      selectedTab = .feed
      feedStartsWriting = true
      feedWriteInitialStep = step
      // `feedwrite1:101` — 웹·안드로이드 캡처와 같은 방을 기록 대상으로 쓴다.
      feedWriteRoomID = screen.identifier.flatMap(Int64.init)
      return true
    }
    return false
  }

  // Direct-launch aliases intentionally cover design-spec filenames used by visual regression tests.
  // swiftlint:disable function_body_length cyclomatic_complexity
  private mutating func applySupportRoute(_ screen: UITestScreenRequest) -> Bool {
    if screen.matches("onb-1", "onboarding-1") {
      selectedTab = .home
      homePath.append(SupportRoute.authPreview(.onboarding1))
      return true
    }
    if screen.matches("onb-2", "onboarding-2") {
      selectedTab = .home
      homePath.append(SupportRoute.authPreview(.onboarding2))
      return true
    }
    if screen.matches("onb-3", "onboarding-3") {
      selectedTab = .home
      homePath.append(SupportRoute.authPreview(.onboarding3))
      return true
    }
    if screen.matches("login") {
      selectedTab = .home
      homePath.append(SupportRoute.authPreview(.login))
      return true
    }
    if screen.matches("email-auth") {
      selectedTab = .home
      homePath.append(SupportRoute.authPreview(.emailLogin))
      return true
    }
    if screen.matches("nickname") {
      selectedTab = .home
      homePath.append(SupportRoute.authPreview(.nickname))
      return true
    }
    if screen.matches("profile-basic", "profilebasic") {
      selectedTab = .home
      homePath.append(SupportRoute.authPreview(.profileBasic))
      return true
    }
    if screen.matches("profile-taste", "profiletaste", "prof-4") {
      selectedTab = .home
      homePath.append(SupportRoute.authPreview(.profileTaste))
      return true
    }
    if screen.matches("profile-image", "profileimage") {
      selectedTab = .home
      homePath.append(SupportRoute.authPreview(.profileImage))
      return true
    }
    if screen.matches("terms") {
      selectedTab = .home
      // 캡처 전용 화면을 두지 않는다 — 실제 가입 플로우의 약관 단계를 그대로 연다.
      homePath.append(SupportRoute.authPreview(.profileTerms))
      return true
    }
    if screen.matches("auth", "signup") {
      selectedTab = .home
      homePath.append(SupportRoute.authFlow)
      return true
    }
    if screen.matches("notifications", "notification") {
      selectedTab = .home
      homePath.append(SupportRoute.notifications)
      return true
    }
    // 16 은 **신청할 수 있는 모집**을 봐야 한다. 캡처가 그 방 id 를 넘기고,
    // 화면이 `GET /chat-rooms/{roomId}` 로 직접 조회한다 — 세션의 모집 목록에서 찾지 않는다.
    if screen.matches("apply") {
      selectedTab = .home
      homePath.append(SupportRoute.applicationSheet(screen.identifier ?? ""))
      return true
    }
    if screen.matches("create", "create-recruitment", "createrecruitment") {
      selectedTab = .home
      // 코스는 플로우 1단계에서 서버 코스 중에 고른다 — 지정이 없으면 빈 값으로 연다
      homePath.append(SupportRoute.createRecruitment(screen.identifier ?? ""))
      return true
    }
    if screen.matches("host", "host-manage", "hostmanage") {
      selectedTab = .home
      homePath.append(SupportRoute.hostManage(screen.identifier ?? ""))
      return true
    }
    if screen.matches("custom-course", "customcourse") {
      selectedTab = .home
      homePath.append(SupportRoute.customCourse)
      return true
    }
    if screen.matches("create-schedule", "createschedule") {
      selectedTab = .home
      homePath.append(SupportRoute.createSchedule)
      return true
    }
    if screen.matches("create-meet", "create-meeting", "createmeet") {
      selectedTab = .home
      homePath.append(SupportRoute.createMeeting)
      return true
    }
    if screen.matches("create-detail", "createdetail") {
      selectedTab = .home
      homePath.append(SupportRoute.createDetail)
      return true
    }
    // 17-4 는 폼 기본값(최대 5), 17-4a/17-4b 는 최대 인원을 타깃으로 받아 멘트 구간을 바꾼다.
    // `create-people:4` → "말 트기 좋은 작은 그룹이에요", `create-people:10` → 친목 경고.
    // 멘트 판정은 화면(RecruitmentPeopleView)이 하고, 여기서는 시작 인원만 넘긴다.
    if screen.matches("create-people", "createpeople") {
      selectedTab = .home
      homePath.append(SupportRoute.createPeople(screen.identifier.flatMap(Int.init)))
      return true
    }
    // 17-6 은 직접 만든 코스, 17-7 은 등록 코스 차용이다.
    // 한 라우트로 묶으면 두 아트보드에 같은 화면이 찍힌다.
    if screen.matches("create-summary-linked", "createsummarylinked") {
      selectedTab = .home
      homePath.append(SupportRoute.createSummary)
      return true
    }
    if screen.matches("create-summary", "createsummary", "create-summary-custom", "createsummarycustom") {
      selectedTab = .home
      homePath.append(SupportRoute.createSummaryCustom)
      return true
    }
    if screen.matches("place-search", "placesearch") {
      selectedTab = .home
      homePath.append(SupportRoute.placeSearch)
      return true
    }
    if screen.matches("place-detail", "placedetail") {
      selectedTab = .home
      homePath.append(SupportRoute.placeDetail(screen.identifier ?? "CT2299341"))
      return true
    }
    if screen.matches("terms-detail", "terms-service") {
      selectedTab = .home
      homePath.append(SupportRoute.signupLegalDocument(.service))
      return true
    }
    if screen.matches("terms-privacy") {
      selectedTab = .home
      homePath.append(SupportRoute.signupLegalDocument(.privacy))
      return true
    }
    if screen.matches("terms-location") {
      selectedTab = .home
      homePath.append(SupportRoute.signupLegalDocument(.location))
      return true
    }
    if screen.matches("terms-marketing") {
      selectedTab = .home
      homePath.append(SupportRoute.signupLegalDocument(.marketing))
      return true
    }
    if screen.matches("terms-settings") {
      selectedTab = .home
      homePath.append(SupportRoute.legalDocument(.service))
      return true
    }
    if screen.matches("course-edit", "courseedit", "course-edit-custom") {
      selectedTab = .home
      homePath.append(SupportRoute.courseEdit(screen.identifier ?? "", .editable))
      return true
    }
    if screen.matches("course-edit-linked", "courseeditlinked") {
      selectedTab = .home
      homePath.append(
        SupportRoute.courseEdit(screen.identifier ?? "", .linkedLocked))
      return true
    }
    if screen.matches("course-edit-locked", "courseeditlocked") {
      selectedTab = .home
      homePath.append(
        SupportRoute.courseEdit(screen.identifier ?? "", .tripConfirmed))
      return true
    }
    if screen.matches("notice-history", "noticehistory") {
      selectedTab = .home
      // 캡처는 실제 서버 방 id(`server-chat-101`)를 identifier 로 넘긴다.
      // 아래 기본값은 identifier 없이 직접 열었을 때만 쓰는 진입 경로다 — 데이터를 바꾸지 않는다.
      homePath.append(
        SupportRoute.noticeHistory(screen.identifier ?? "chat-cheongsong-juwangsan"))
      return true
    }
    if screen.matches("trip-confirmed", "tripconfirmed") {
      selectedTab = .home
      let tripID = screen.identifier ?? "trip-cheongsong-juwangsan"
      homePath.append(SupportRoute.tripConfirmed(tripID))
      return true
    }
    return applyChangelogRoute(screen)
  }
  // swiftlint:enable function_body_length cyclomatic_complexity

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  private mutating func applyChangelogRoute(_ screen: UITestScreenRequest) -> Bool {
    if screen.matches("chat-menu", "chatmenu") {
      selectedTab = .home
      homePath.append(SupportRoute.chatMenu(screen.identifier ?? "chat-cheongsong-juwangsan"))
      return true
    }
    // changeLog14 — 20-1a 멤버 액션 · 20-1b 내보내기 사유 입력. 둘 다 20-1 위에 뜬 시트다.
    if screen.matches("member-actions", "memberactions") {
      selectedTab = .home
      homePath.append(
        SupportRoute.chatMenuMemberActions(screen.identifier ?? "chat-cheongsong-juwangsan"))
      return true
    }
    if screen.matches("member-remove", "memberremove") {
      selectedTab = .home
      homePath.append(
        SupportRoute.chatMenuMemberRemove(screen.identifier ?? "chat-cheongsong-juwangsan"))
      return true
    }
    if screen.matches("chat-attach", "chatattach") {
      selectedTab = .home
      homePath.append(SupportRoute.chatAttach(screen.identifier ?? "chat-cheongsong-juwangsan"))
      return true
    }
    // 20-2a~20-2f 첨부 작성 6종 (`attach-photo` … `attach-notice`).
    // 라우트가 없어 여섯 자리 모두 **홈 화면**이 찍히고 있었다 — 픽셀·로딩 감사는 둘 다 통과했다.
    // 캡처는 대상 방을 `server-chat-22` 형식으로 준다 (`LIVE_ROUTE_TARGETS`).
    for kind in ChatAttachmentMenuView.AttachmentKind.allCases
    where screen.matches("attach-\(kind.captureRouteName)", "attach\(kind.captureRouteName)") {
      selectedTab = .home
      homePath.append(
        SupportRoute.attachComposer(screen.identifier ?? "chat-cheongsong-juwangsan", kind))
      return true
    }
    if screen.matches("friends") {
      selectedTab = .home
      homePath.append(SupportRoute.friends)
      return true
    }
    if screen.matches("trip-message", "tripmessage") {
      selectedTab = .home
      homePath.append(SupportRoute.tripMessage)
      return true
    }
    // 아트보드 `report` 는 **피드 신고 시트**로 남는다 (정본 `REPORT-CANON.md` §1) —
    // 서버가 받는 신고는 피드뿐이다. 그래서 캡처도 **피드 컨텍스트**로 열어야 한다.
    // 대상 id 는 23 상세·23-1 댓글과 같은 `server-feed-{feedId}` 형식이다.
    // 방 id(`22` 같은 옛 타깃)를 받으면 피드로 못 읽으므로 대표 피드로 떨어진다 —
    // 그때도 채팅방 신고 시트를 열지 않는다(그런 화면은 이제 없다).
    if screen.matches("report") {
      selectedTab = .home
      let postID = screen.identifier.flatMap { identifier in
        ServerFeedMapper.feedID(fromPostID: identifier) == nil ? nil : identifier
      }
      homePath.append(SupportRoute.report(postID ?? "\(ServerFeedMapper.serverFeedIDPrefix)1"))
      return true
    }
    if screen.matches("states") {
      selectedTab = .home
      homePath.append(SupportRoute.componentStates)
      return true
    }
    if screen.matches("leave") {
      selectedTab = .home
      homePath.append(
        SupportRoute.leaveConfirmation(screen.identifier ?? "chat-cheongsong-juwangsan"))
      return true
    }
    if screen.matches("blocked", "blocked-users", "blockedusers") {
      selectedTab = .home
      homePath.append(SupportRoute.blockedUsers)
      return true
    }
    if screen.matches("course-publish", "coursepublish") {
      selectedTab = .home
      homePath.append(SupportRoute.coursePublish)
      return true
    }
    if screen.matches("trip-day", "tripday") {
      selectedTab = .home
      homePath.append(SupportRoute.tripDay(screen.identifier ?? "chat-cheongsong-juwangsan"))
      return true
    }
    if screen.matches("notif-detail", "notification-detail", "notificationdetail") {
      selectedTab = .home
      homePath.append(SupportRoute.notificationDetail)
      return true
    }
    // changeLog14 — 13-1 내보내기 안내 (강퇴 사유)
    if screen.matches("removal-reason", "removalreason") {
      selectedTab = .home
      homePath.append(SupportRoute.removalReason)
      return true
    }
    if screen.matches("account-delete", "accountdelete") {
      selectedTab = .home
      homePath.append(SupportRoute.accountDelete)
      return true
    }
    if screen.matches("system-maintenance", "systemmaintenance") {
      selectedTab = .home
      homePath.append(SupportRoute.systemMaintenance)
      return true
    }
    if screen.matches("system-error", "systemerror", "error-500") {
      selectedTab = .home
      homePath.append(SupportRoute.systemError)
      return true
    }
    // changeLog17 — 29-4 오픈소스 라이선스 목록 · 29-4a 라이선스 전문
    if screen.matches("oss-licenses", "osslicenses") {
      selectedTab = .home
      homePath.append(SupportRoute.ossLicenses)
      return true
    }
    if screen.matches("oss-license-detail", "osslicensedetail") {
      selectedTab = .home
      // 화면기획 29-4a의 기준 항목은 목록 첫 항목(Firebase iOS SDK)이다
      homePath.append(
        SupportRoute.ossLicenseDetail(
          screen.identifier ?? OSSLicenseCatalog.items.first?.name ?? ""))
      return true
    }
    // ── 2026-08-30 네 번째 묶음 (정본 `ATTACH-COMPOSER-CANON.md` §6) ──
    // 08-H 비밀번호 재설정은 실제 가입 플로우의 단계를 그대로 연다 — 캡처 전용 화면을 두지 않는다.
    if screen.matches("password-reset", "passwordreset") {
      selectedTab = .home
      homePath.append(SupportRoute.authPreview(.passwordReset))
      return true
    }
    // 29-5 계정 연결 — 설정의 `로그인 방식 › 관리` 가 여는 화면과 같은 것이다.
    if screen.matches("account-providers", "accountproviders") {
      selectedTab = .home
      homePath.append(SupportRoute.accountProviders)
      return true
    }
    if screen.matches("room-notif", "roomnotif", "room-notification") {
      selectedTab = .home
      homePath.append(
        SupportRoute.roomNotification(screen.identifier ?? "chat-cheongsong-juwangsan"))
      return true
    }
    if screen.matches("notice-edit", "noticeedit") {
      selectedTab = .home
      homePath.append(SupportRoute.noticeEdit(screen.identifier ?? ""))
      return true
    }
    if screen.matches("favorite-rooms", "favoriterooms") {
      selectedTab = .home
      homePath.append(SupportRoute.favoriteRooms)
      return true
    }
    if screen.matches("kick-history", "kickhistory") {
      selectedTab = .home
      homePath.append(SupportRoute.kickHistory)
      return true
    }
    if screen.matches("course-rating", "courserating") {
      selectedTab = .home
      homePath.append(SupportRoute.courseRating(screen.identifier ?? ""))
      return true
    }
    if screen.matches("trip-status", "tripstatus") {
      selectedTab = .home
      homePath.append(SupportRoute.tripStatus(screen.identifier ?? ""))
      return true
    }
    if screen.matches("meeting-edit", "meetingedit") {
      selectedTab = .home
      homePath.append(SupportRoute.meetingEdit(screen.identifier ?? ""))
      return true
    }
    // 19-2 신청 취소 확인 · 29-1a 차단 해제 확인 · 27-2a 친구 정리는 이전 화면 위에 뜬 시트다.
    // 캡처도 그 화면을 깔고 시트를 연 상태로 시작한다 (20-1a·20-1b 와 같은 방식).
    // 19-2 는 세그먼트만 바꾸면 **신청이 0건일 때 아무 화면도 아닌 빈 목록**이 찍힌다 —
    // 취소할 신청이 있으면 시트를, 없으면 제목이 있는 빈 상태를 그리는 화면으로 들어간다.
    if screen.matches("apply-cancel", "applycancel") {
      selectedTab = .meetings
      meetingsInitialSegment = .applied
      meetingsPath.append(
        MeetingsRoute.applyCancel(
          screen.identifier.flatMap { ServerTripMapper.roomID(fromThreadID: $0) ?? Int64($0) }))
      return true
    }
    if screen.matches("unblock-confirm", "unblockconfirm") {
      selectedTab = .home
      homePath.append(SupportRoute.unblockConfirm)
      return true
    }
    if screen.matches("friend-manage", "friendmanage") {
      selectedTab = .home
      homePath.append(SupportRoute.friendManage)
      return true
    }
    // 31-1 참가자 나가기 — 새 화면이 아니라 31 을 역할로 가른 것이다.
    // 역할은 서버 멤버 목록의 `me && host` 가 정한다 — 캡처 인자로 바꾸지 않는다.
    if screen.matches("leave-member", "leavemember") {
      selectedTab = .home
      homePath.append(
        SupportRoute.leaveConfirmation(screen.identifier ?? "chat-cheongsong-juwangsan"))
      return true
    }
    if screen.matches("feed-comments", "feedcomments") {
      selectedTab = .home
      // 기본 게시물은 다른 플랫폼과 같은 대표 피드(댓글 18)다
      homePath.append(SupportRoute.feedComments(screen.identifier ?? "feed-01"))
      return true
    }
    return false
  }

  private mutating func applyExploreRoute(_ screen: UITestScreenRequest) -> Bool {
    // 12-1 검색 결과는 별도 화면이 아니라 SearchView 안의 결과 탭이다.
    // 라우트가 없어서 캡처가 **홈 화면을 찍고 있었다** — 이동조차 안 했다.
    // `search` 보다 먼저 봐야 한다 (`search-results` 도 `search` 로 매칭된다).
    if screen.matches("search-results", "searchresults") {
      selectedTab = .explore
      explorePath.append(SupportRoute.search)
      return true
    }
    if screen.matches("search") {
      selectedTab = .explore
      explorePath.append(SupportRoute.search)
      return true
    }
    if screen.matches("explore-map", "exploremap", "map") {
      selectedTab = .explore
      exploreStartsInMap = true
      return true
    }
    return false
  }

  /// 코스 상세를 서버 코스 id 로 연다. 화면은 상세 API 로 스스로 채운다 —
  /// id 를 안 주면 열 코스가 없으므로 아무 데도 가지 않는다 (NO-MOCK-CANON R2).
  private mutating func appendCourse(_ id: String?) {
    guard let courseID = id.flatMap(Int64.init) else { return }
    homePath.append(ServerCourseMapper.stubCourse(serverCourseID: courseID))
  }

  /// 모집 상세를 서버 roomId 로 연다. 나머지 값은 상세 API 가 채운다.
  private mutating func appendTrip(_ id: String?) {
    guard let roomID = id.flatMap(Int64.init) else { return }
    homePath.append(ServerTripMapper.placeholderTrip(roomID: roomID))
  }

  /// 캡처 라우트가 `profile:62` 처럼 대상 유저를 지정하면 그 유저로 연다.
  /// 지정이 없으면 그릴 근거가 없다 — 카드 대신 빈 상태를 그린다 (NO-MOCK-CANON R2).
  private static func profileSubject(_ identifier: String?) -> ProfileCardSubject {
    guard let userID = identifier.flatMap(Int64.init) else { return .unavailable }
    // 닉네임 등 나머지는 공개 프로필 API 로 채워진다 — 여기서는 id 만 넘긴다.
    return .serverUser(ProfileCardUserReference(userID: userID, nickname: ""))
  }

  private mutating func appendChat(_ id: String?) {
    guard let roomID = id.flatMap(Int64.init) else { return }
    meetingsPath.append(ServerTripMapper.stubThread(serverRoomID: roomID))
  }
}
// swiftlint:enable type_body_length

private struct UITestScreenRequest {
  let name: String
  let identifier: String?

  init?(arguments: [String]) {
    guard
      let rawValue =
        arguments
        .first(where: { $0.hasPrefix("UITEST_SCREEN=") })?
        .replacingOccurrences(of: "UITEST_SCREEN=", with: "")
    else {
      return nil
    }

    let parts = rawValue.split(separator: ":", maxSplits: 1).map(String.init)
    name = (parts.first ?? "")
      .replacingOccurrences(of: "_", with: "-")
      .lowercased()
    identifier = parts.count > 1 && !parts[1].isEmpty ? parts[1] : nil
  }

  func matches(_ values: String...) -> Bool {
    values.contains(name)
  }
}
