// swiftlint:disable file_length
import SwiftUI

enum SupportRoute: Hashable, Identifiable {
  case authFlow
  case authPreview(AuthDirectScreen)
  /// 16 신청 시트. 값은 신청할 모집의 roomId — 없으면 세션이 아는 첫 모집을 쓴다.
  /// 예전에는 값을 아예 받지 않아 직접 진입(캡처)에서 세션이 빈 채로 "모집이 없어요"가 찍혔다.
  case applicationSheet(String)
  case leaveConfirmation(String)
  case notifications
  case createRecruitment(String)
  case hostManage(String)
  case search
  case customCourse
  case createSchedule
  case createMeeting
  /// 17-4 · 17-4a · 17-4b — 3단계 인원. 값은 **최대 인원**이고, nil 이면 폼 기본값(5)이다.
  /// 인원수별 멘트 3단계(4명 이하 · 5~8명 · 9명 이상)를 아트보드로 나눠 찍기 위한 통로다.
  case createPeople(Int?)
  case createDetail
  case createSummary
  case createSummaryCustom
  case placeSearch
  case placeDetail(String)
  case courseEdit(String, RouteEditState)
  case noticeHistory(String)
  case tripConfirmed(String)
  case chatMenu(String)
  /// changeLog14 — 20-1a 멤버 액션 시트를 연 20-1 사이드 메뉴
  case chatMenuMemberActions(String)
  /// changeLog14 — 20-1b 내보내기 사유 입력 시트를 연 20-1 사이드 메뉴
  case chatMenuMemberRemove(String)
  case chatAttach(String)
  /// 20-2a~20-2f 첨부 작성 6종. 값은 방 id(`server-chat-22` 또는 방 번호)와 타일 종류다.
  /// 20-2 시트에서 눌러 오는 것과 같은 화면이다 — 캡처 전용 화면을 따로 두지 않는다.
  case attachComposer(String, ChatAttachmentMenuView.AttachmentKind)
  /// 21 특수 메시지 카드 6종. 값은 카드를 뽑아 올 방의 roomId 다 —
  /// 이 화면은 **카드 렌더링 견본**이라 실제 방의 실제 메시지로 그린다 (NO-MOCK-CANON R1).
  case specialMessages(String)
  case friends
  case tripMessage
  /// 30-2 피드 신고 시트. **피드 전용이다** (정본 `REPORT-CANON.md` §1) —
  /// 값은 23 상세와 같은 게시물 id(`server-feed-{feedId}`)다.
  /// 멤버·채팅방 신고는 접수 API 가 없어 이 라우트로 오지 않는다 — 누른 자리에서
  /// `ReportUnsupportedDialog` 로 안내한다.
  case report(String)
  case blockedUsers
  case coursePublish
  case tripDay(String)
  case notificationDetail
  case removalReason
  case accountDelete
  case componentStates
  case systemMaintenance
  case systemError
  case feedComments(String)
  case legalDocument(LegalDocumentKind)
  case signupLegalDocument(LegalDocumentKind)
  /// changeLog17 — 29-4 오픈소스 라이선스 목록
  case ossLicenses
  /// changeLog17 — 29-4a 라이선스 전문. 값은 `oss-licenses-ios.json` 의 `name` 이다.
  case ossLicenseDetail(String)
  /// changeLog18 — 25 프로필 카드. 마이 탭 밖(피드 작성자 23 · 멤버 액션 20-1a · 친구 목록 27-2)에서
  /// 같은 화면으로 오기 위한 통로다. 화면은 `MyRoute.profile` 과 같은 `ProfileCardView` 하나뿐이다.
  case publicProfile(ProfileCardSubject)
  /// 20-1c 이 모임 알림 (`GET/PUT /notifications/settings/chat-rooms/{roomId}`)
  case roomNotification(String)
  /// 26-1 찜한 모집 (`GET /chat-rooms/my/favorites`)
  case favoriteRooms
  /// 13-2 내 강퇴 이력 (`GET /chat-rooms/my-kick-histories`)
  case kickHistory
  /// 27-4 코스 평가. 값은 roomId — 없으면 가장 최근에 끝난 내 모임을 쓴다.
  case courseRating(String)
  /// 18-4 여행 확정 / 불발 (호스트). 값은 roomId.
  case tripStatus(String)
  /// 18-5 집합 정보 수정 (호스트). 값은 roomId.
  case meetingEdit(String)
  /// 29-5 계정 연결 (로그인 방식). `GET/POST /auth/providers`
  case accountProviders
  /// 20-3a 공지 수정 · 삭제. 값은 roomId — 화면이 그 방의 공지를 받아 첫 공지를 연다.
  case noticeEdit(String)
  /// 29-1a 차단 해제 확인 시트를 연 29-1
  case unblockConfirm
  /// 27-2a 친구 정리 시트를 연 27-2
  case friendManage

  var id: String {
    switch self {
    case .authFlow:
      return "authFlow"
    case .authPreview(let screen):
      return "authPreview.\(screen.rawValue)"
    case .applicationSheet(let roomID):
      return "applicationSheet.\(roomID)"
    case .leaveConfirmation(let threadID):
      return "leaveConfirmation.\(threadID)"
    case .notifications:
      return "notifications"
    case .createRecruitment(let courseID):
      return "createRecruitment.\(courseID)"
    case .hostManage(let tripID):
      return "hostManage.\(tripID)"
    case .search:
      return "search"
    case .customCourse:
      return "customCourse"
    case .createSchedule:
      return "createSchedule"
    case .createMeeting:
      return "createMeeting"
    case .createPeople(let capacity):
      return "createPeople.\(capacity.map(String.init) ?? "default")"
    case .createDetail:
      return "createDetail"
    case .createSummary:
      return "createSummary"
    case .createSummaryCustom:
      return "createSummaryCustom"
    case .placeSearch:
      return "placeSearch"
    case .placeDetail(let placeID):
      return "placeDetail.\(placeID)"
    case .courseEdit(let tripID, let state):
      return "courseEdit.\(tripID).\(state.rawValue)"
    case .noticeHistory(let threadID):
      return "noticeHistory.\(threadID)"
    case .tripConfirmed(let tripID):
      return "tripConfirmed.\(tripID)"
    case .chatMenu(let threadID): return "chatMenu.\(threadID)"
    case .chatMenuMemberActions(let threadID): return "chatMenuMemberActions.\(threadID)"
    case .chatMenuMemberRemove(let threadID): return "chatMenuMemberRemove.\(threadID)"
    case .chatAttach(let threadID): return "chatAttach.\(threadID)"
    case .attachComposer(let threadID, let kind):
      return "attachComposer.\(threadID).\(kind.rawValue)"
    case .specialMessages(let roomID): return "specialMessages.\(roomID)"
    case .friends: return "friends"
    case .tripMessage: return "tripMessage"
    case .report(let postID): return "report.\(postID)"
    case .blockedUsers: return "blockedUsers"
    case .coursePublish: return "coursePublish"
    case .tripDay(let threadID): return "tripDay.\(threadID)"
    case .notificationDetail: return "notificationDetail"
    case .removalReason: return "removalReason"
    case .accountDelete: return "accountDelete"
    case .componentStates: return "componentStates"
    case .systemMaintenance: return "systemMaintenance"
    case .systemError: return "systemError"
    case .feedComments(let postID): return "feedComments.\(postID)"
    case .legalDocument(let document): return "legalDocument.\(document.rawValue)"
    case .signupLegalDocument(let document): return "signupLegalDocument.\(document.rawValue)"
    case .ossLicenses: return "ossLicenses"
    case .ossLicenseDetail(let name): return "ossLicenseDetail.\(name)"
    case .publicProfile(let subject): return "publicProfile.\(subject.routeKey)"
    case .roomNotification(let threadID): return "roomNotification.\(threadID)"
    case .favoriteRooms: return "favoriteRooms"
    case .kickHistory: return "kickHistory"
    case .courseRating(let roomID): return "courseRating.\(roomID)"
    case .tripStatus(let roomID): return "tripStatus.\(roomID)"
    case .meetingEdit(let roomID): return "meetingEdit.\(roomID)"
    case .accountProviders: return "accountProviders"
    case .noticeEdit(let roomID): return "noticeEdit.\(roomID)"
    case .unblockConfirm: return "unblockConfirm"
    case .friendManage: return "friendManage"
    }
  }
}

struct SupportDestinationView: View {
  let route: SupportRoute
  var tripContext = TripInteractionContext()
  var onAuthCompleted: () -> Void = {}
  @Binding var feedPosts: [FeedPost]

  init(
    route: SupportRoute, tripContext: TripInteractionContext = TripInteractionContext(),
    feedPosts: Binding<[FeedPost]> = .constant([]),
    onAuthCompleted: @escaping () -> Void = {}
  ) {
    self.route = route
    self.tripContext = tripContext
    self.onAuthCompleted = onAuthCompleted
    _feedPosts = feedPosts
  }

  var body: some View {
    switch route {
    case .authFlow:
      AuthFlowView(onComplete: onAuthCompleted)
    case .authPreview(let screen):
      AuthFlowView(directScreen: screen, onComplete: onAuthCompleted)
    // 16 신청 시트는 실제 모집 상세 위에 열린 실제 시트다.
    //
    // 방 id 를 받으면 15 상세(`appendTrip`)와 **같은 방식**으로 껍데기를 넘겨
    // 화면이 스스로 상세 API 로 채우게 한다. 예전에는 세션의 모집 목록 첫 건만 봐서
    // 직접 진입(캡처 · 딥링크)에서는 목록이 비어 있어 늘 빈 상태가 찍혔다.
    // 여기서 로딩 자리표시를 먼저 그리면 시트가 상세보다 먼저 떠서 **홈 목록 위에** 얹힌다.
    case .applicationSheet(let roomID):
      if let trip = applicationSubject(roomID) {
        TripDetailView(
          trip: trip,
          onSendChatMessage: tripContext.onSendChatMessage,
          startsWithApplicationSheet: true
        )
      } else {
        MoyeoEmptyStateView(message: MoyeoEmptyText.noRecruitments)
      }
    // changeLog14 — 31 경고 팝업은 20-1 채팅방 사이드 메뉴 위에 뜬 것으로 그린다.
    // 직접 진입(UITEST `leave`)도 그 화면을 깔고 팝업을 연 상태로 시작한다.
    case .leaveConfirmation(let threadID):
      if let thread = resolvedThread(threadID) {
        ChatSideMenuView(thread: thread, startsWithLeaveConfirmation: true)
      } else {
        MoyeoEmptyStateView(message: MoyeoEmptyText.noChatRooms)
      }
    case .notifications:
      NotificationCenterView(tripContext: tripContext, feedPosts: $feedPosts)
    case .createRecruitment(let courseID):
      RecruitmentCreationFlowView(
        courseID: courseID,
        onCreated: tripContext.onCreateRecruitment,
        onSendChatMessage: tripContext.onSendChatMessage,
        onApproveApplicant: tripContext.onApproveHostApplicant,
        onRejectApplicant: tripContext.onRejectHostApplicant,
        onSetRecruitmentClosed: tripContext.onSetRecruitmentClosed
      )
    // 18 모집 관리(호스트). 세션이 아는 모임이 아니면 방 id 로 서버 상세를 받아 그린다 —
    // 예전에는 메모리의 모집 목록만 뒤져서 직접 진입에서 늘 빈 상태였다.
    case .hostManage(let tripID):
      ServerTripDestination(tripID: tripID, tripContext: tripContext) { trip in
        HostManageView(
          trip: trip,
          thread: tripContext.chatThreadProvider(trip),
          onSendChatMessage: tripContext.onSendChatMessage,
          onApproveApplicant: tripContext.onApproveHostApplicant,
          onRejectApplicant: tripContext.onRejectHostApplicant,
          onSetRecruitmentClosed: tripContext.onSetRecruitmentClosed
        )
      }
    case .search:
      SearchView(tripContext: tripContext)
    case .customCourse:
      CustomCourseEditorView()
    // 17-2~17-7 은 별도 화면이 아니라 실제 모집 만들기 플로우의 단계다.
    // 캡처 전용 래퍼를 두지 않고 실제 플로우를 해당 단계로 열어 찍는다.
    case .createSchedule:
      recruitmentFlow(step: 2)
    case .createMeeting:
      recruitmentFlow(step: 2, atMeetingPoint: true)
    case .createPeople(let capacity):
      recruitmentFlow(step: 3, capacity: capacity)
    case .createDetail:
      recruitmentFlow(step: 4)
    case .createSummary:
      recruitmentFlow(step: 5, source: .linked)
    case .createSummaryCustom:
      recruitmentFlow(step: 5, source: .custom)
    case .placeSearch:
      PlaceSearchView()
    case .placeDetail(let placeID):
      // 번들 목록에 없는 ID 는 **서버 콘텐츠 ID** 다 — 빈 장소로 열어 상세 API 가 채우게 한다.
      // 엉뚱한 목 장소로 떨어뜨리면 그 장소의 목 ID 로 서버를 불러 상세가 항상 실패한다.
      PlaceDetailView(
        place: TourismPlaceCatalog.places.first { $0.id == placeID }
          ?? TourismPlace.pending(id: placeID)
      )
    // 18-1 · 18-2 · 18-3 코스 수정. 18 과 같은 방식으로 방 id 를 직접 조회한다.
    case .courseEdit(let tripID, let state):
      ServerTripDestination(tripID: tripID, tripContext: tripContext) { trip in
        CourseRouteEditView(
          trip: trip,
          state: state,
          onSaved: tripContext.onUpdateRoute
        )
      }
    case .noticeHistory(let threadID):
      // 서버 모임 id 로 들어오면 화면이 직접 서버에서 공지를 받는다.
      if let thread = resolvedThread(threadID) {
        NoticeHistoryView(thread: thread, onCreate: tripContext.onCreateNotice)
      } else {
        MoyeoEmptyStateView(message: MoyeoEmptyText.noNotices)
      }
    case .tripConfirmed(let tripID):
      // 20-4 는 **확정된 방**을 봐야 한다. 세션이 아는 모임이 없으면(직접 진입 · 캡처)
      // 방 id 로 서버 상세를 받아 그린다 — 예전에는 메모리의 모집 목록만 뒤져 빈 화면이 됐다.
      TripConfirmedDestination(
        tripID: tripID,
        serverRoomID: resolvedRoomID(tripID),
        tripContext: tripContext
      )
    case .chatMenu(let threadID):
      chatSideMenu(threadID)
    // changeLog14 — 20-1a · 20-1b 는 20-1 위에 뜬 시트다. 직접 진입도 같은 구조로 연다.
    case .chatMenuMemberActions(let threadID):
      chatSideMenu(threadID, startsWithMemberActions: true)
    case .chatMenuMemberRemove(let threadID):
      chatSideMenu(threadID, startsWithMemberRemoval: true)
    case .chatAttach(let threadID):
      // 서버 모임에서 열린 20-2는 그 방으로 실제 카드를 보낸다.
      ChatAttachmentMenuView(serverRoomID: resolvedThread(threadID)?.serverRoomID)
    // 20-2a~20-2f — 20-2 타일이 여는 것과 같은 작성 화면이다.
    // 방을 못 찾으면 보낼 곳이 없다 — 지어내지 않고 빈 상태를 그린다 (NO-MOCK-CANON R2).
    case .attachComposer(let threadID, let kind):
      if let roomID = resolvedRoomID(threadID) {
        AttachComposerDestination(kind: kind, roomID: roomID, onSent: {})
      } else {
        MoyeoEmptyStateView(message: MoyeoEmptyText.noChatRooms)
      }
    case .specialMessages(let roomID):
      SpecialMessageCardsView(roomID: resolvedRoomID(roomID))
    case .friends:
      FriendsManagementView()
    case .tripMessage:
      TripMessageView()
    case .report(let postID):
      // 30-2 는 피드 전용이다. 신고할 피드를 못 찾으면 보낼 대상이 없다 —
      // 사유·대상을 지어내지 않고 빈 상태를 그린다 (NO-MOCK-CANON R1).
      if let post = feedPosts.first(where: { $0.id == postID }), let view = ReportView(post: post) {
        view
      } else if let feedID = ServerFeedMapper.feedID(fromPostID: postID) {
        // 피드 목록을 거치지 않고 바로 들어오면(캡처·딥링크) 시트가 피드를 직접 받는다.
        ReportView(feedID: feedID)
      } else {
        MoyeoEmptyStateView(message: MoyeoEmptyText.noFeeds)
      }
    case .blockedUsers:
      BlockedUsersView()
    case .publicProfile(let subject):
      ProfileCardView(subject: subject)
    case .coursePublish:
      CoursePublishView()
    case .tripDay(let threadID):
      if let thread = resolvedThread(threadID) {
        TripDayView(thread: thread)
      } else {
        MoyeoEmptyStateView(message: MoyeoEmptyText.noChatRooms)
      }
    case .notificationDetail:
      NotificationDetailView()
    case .removalReason:
      RemovalReasonView()
    case .accountDelete:
      AccountDeleteView(onDeleted: onAuthCompleted)
    case .componentStates:
      ComponentStatesPreview()
    case .systemMaintenance:
      SystemNoticeView(mode: .maintenance)
    case .systemError:
      SystemNoticeView(mode: .error)
    case .feedComments(let postID):
      // 피드 목록을 거치지 않고 바로 들어오면 `feedPosts` 가 비어 있다 —
      // 그때는 서버 피드 id 로 최소 게시물을 만들어 화면이 직접 댓글을 받게 한다.
      if let post = feedPosts.first(where: { $0.id == postID })
        ?? ServerFeedMapper.feedID(fromPostID: postID).map(ServerFeedMapper.stubPost(serverFeedID:))
        ?? feedPosts.first {
        FeedCommentsView(post: post)
      } else {
        MoyeoEmptyStateView(message: MoyeoEmptyText.noComments)
      }
    case .legalDocument(let document):
      LegalDocumentDetailView(kind: document, entry: .settings)
    case .signupLegalDocument(let document):
      LegalDocumentDetailView(kind: document, entry: .signup)
    case .ossLicenses:
      OSSLicensesView()
    case .ossLicenseDetail(let name):
      // 캡처 기본값은 목록 첫 항목이다. 항목이 없으면 목록 화면으로 떨어진다.
      if let item = OSSLicenseCatalog.item(named: name) ?? OSSLicenseCatalog.items.first {
        OSSLicenseDetailView(item: item)
      } else {
        OSSLicensesView()
      }
    case .roomNotification(let threadID):
      // 20-1c 는 방별 설정 화면이다 — 방을 모르면 열 것이 없다.
      if let thread = resolvedThread(threadID), let roomID = thread.serverRoomID {
        RoomNotificationView(
          roomID: roomID,
          roomTitle: thread.tripTitle,
          roomSubtitle: thread.scheduleSummary
        )
      } else {
        MoyeoEmptyStateView(message: MoyeoEmptyText.noChatRooms)
      }
    case .favoriteRooms:
      FavoriteRoomsView(tripContext: tripContext)
    case .kickHistory:
      KickHistoryView()
    case .courseRating(let roomID):
      CourseRatingView(roomID: Int64(roomID))
    case .tripStatus(let roomID):
      if let id = Int64(roomID) {
        TripStatusView(roomID: id)
      } else {
        MoyeoEmptyStateView(message: MoyeoEmptyText.noRecruitments)
      }
    case .meetingEdit(let roomID):
      if let id = Int64(roomID) {
        MeetingInfoEditView(roomID: id)
      } else {
        MoyeoEmptyStateView(message: MoyeoEmptyText.noRecruitments)
      }
    case .accountProviders:
      AccountProvidersRoute()
    case .noticeEdit(let roomID):
      // 캡처는 방 id 만 준다 — 화면이 그 방의 공지를 받아 첫 공지를 연다.
      if let id = ServerTripMapper.roomID(fromThreadID: roomID) ?? Int64(roomID) {
        NoticeEditLoaderView(roomID: id)
      } else {
        MoyeoEmptyStateView(message: MoyeoEmptyText.noNotices)
      }
    case .unblockConfirm:
      BlockedUsersView(startsWithUnblockConfirmation: true)
    case .friendManage:
      FriendsManagementView(startsWithFriendManage: true)
    }
  }

  /// 실제 모집 만들기 플로우를 지정 단계로 연다.
  /// 코스는 진입부(탐색)와 같은 방식으로 고른다 — 캡처만의 별도 코스를 만들지 않는다.
  private func recruitmentFlow(
    step: Int,
    atMeetingPoint: Bool = false,
    source: CourseSource? = nil,
    capacity: Int? = nil
  ) -> some View {
    RecruitmentCreationFlowView(
      courseID: defaultCourseID,
      initialStep: step,
      startsAtMeetingPoint: atMeetingPoint,
      initialSource: source,
      initialCapacity: capacity,
      onCreated: tripContext.onCreateRecruitment,
      onSendChatMessage: tripContext.onSendChatMessage,
      onApproveApplicant: tripContext.onApproveHostApplicant,
      onRejectApplicant: tripContext.onRejectHostApplicant,
      onSetRecruitmentClosed: tripContext.onSetRecruitmentClosed
    )
  }

  /// 모집 만들기는 코스를 고르는 단계부터 시작한다 — 기본 코스를 지어내지 않는다.
  private var defaultCourseID: String {
    ""
  }

  private var defaultTrip: TripRecruitment? {
    tripContext.trips.first
  }

  /// 16 이 신청 시트를 열 모집. 방 id 를 받았으면 그 방이고(세션이 아는 모임이면 그것을 쓴다),
  /// 없으면 목록에서 눌러 들어온 흐름이므로 세션의 첫 모집이다.
  private func applicationSubject(_ roomID: String) -> TripRecruitment? {
    if let known = tripContext.trips.first(where: { $0.id == roomID }) { return known }
    if let id = MoyeoRoomIDText.roomID(from: roomID) {
      return ServerTripMapper.placeholderTrip(roomID: id)
    }
    return defaultTrip
  }

  /// 방 번호만 필요한 화면용. `server-chat-22` · `server-room-22` · `22` 세 형식을 모두 받는다.
  private func resolvedRoomID(_ id: String) -> Int64? {
    resolvedThread(id)?.serverRoomID ?? MoyeoRoomIDText.roomID(from: id)
  }

  /// 세션이 아는 방이면 그것을, 아니면 **방 id 만 실은 껍데기**를 준다 —
  /// 화면이 스스로 그 방의 서버 응답을 받아 채운다.
  ///
  /// 예전에는 `server-chat-` 접두사가 붙은 id 만 껍데기로 만들어서, 캡처가 순수 숫자를
  /// 넘기는 31 · 20-5 는 nil 로 떨어져 실제로 참여 중인 방인데도 빈 상태가 찍혔다.
  private func resolvedThread(_ id: String) -> ChatThread? {
    tripContext.chatThreads.first { $0.id == id }
      ?? MoyeoRoomIDText.roomID(from: id).map(ServerTripMapper.stubThread(serverRoomID:))
  }

  @ViewBuilder
  private func chatSideMenu(
    _ threadID: String,
    startsWithMemberActions: Bool = false,
    startsWithMemberRemoval: Bool = false
  ) -> some View {
    if let thread = resolvedThread(threadID) {
      ChatSideMenuView(
        thread: thread,
        startsWithMemberActions: startsWithMemberActions,
        startsWithMemberRemoval: startsWithMemberRemoval
      )
    } else {
      MoyeoEmptyStateView(message: MoyeoEmptyText.noChatRooms)
    }
  }
}

/// 방 id 만 아는 진입(캡처 · 딥링크 · 알림)에서 모집 모델을 세우는 공용 통로.
///
/// 16 신청 시트 · 18 모집 관리 · 18-1~18-3 코스 수정이 모두 `tripContext.trips` 안에서
/// 모임을 찾다가 실패해 빈 상태를 그렸다. 그 목록은 **탐색 탭이 채우는 것**이라
/// 화면을 직접 열면 늘 비어 있고, `GET /chat-rooms/search` 는 이미 참여 중인 방을
/// 아예 제외하므로 내가 호스트인 방은 거기서 절대 나오지 않는다.
///
/// 그래서 세션이 아는 모임이면 그대로 쓰고, 아니면 `GET /chat-rooms/{roomId}` 로 받아 온다.
/// 서버가 방을 주지 않으면 지어내지 않고 빈 상태를 그린다 (NO-MOCK-CANON R1).
private struct ServerTripDestination<Content: View>: View {
  let tripID: String
  var tripContext: TripInteractionContext
  /// 방 id 가 없는 진입에서만 쓰는 세션 기본값 (16 은 목록에서 눌러 들어오기도 한다)
  var fallback: TripRecruitment?
  @ViewBuilder var content: (TripRecruitment) -> Content

  @State private var loadedTrip: TripRecruitment?
  @State private var didLoad = false

  private var trip: TripRecruitment? {
    tripContext.trips.first { $0.id == tripID } ?? loadedTrip ?? fallback
  }

  var body: some View {
    Group {
      if let trip {
        content(trip)
      } else if didLoad {
        MoyeoEmptyStateView(message: MoyeoEmptyText.noRecruitments)
      } else {
        MoyeoEmptyStateView(message: MoyeoEmptyText.loading)
      }
    }
    .task { await load() }
  }

  private func load() async {
    guard !didLoad, tripContext.trips.first(where: { $0.id == tripID }) == nil else { return }
    guard MoyeoServerSync.isEnabled, let roomID = MoyeoRoomIDText.roomID(from: tripID) else {
      didLoad = true
      return
    }
    let course = (try? await TravelCourseAPIClient.shared.roomCourse(roomID: roomID))?.course
    if let detail = try? await ChatRoomAPIClient.shared.detail(roomID: roomID) {
      loadedTrip = ServerTripMapper.trip(from: detail, course: course)
    }
    didLoad = true
  }
}

/// 20-4 여행 확정 모먼트의 진입 해석.
///
/// 세션이 아는 모임이면 그대로 쓰고, 방 id 만 아는 진입(캡처 · 딥링크)에서는
/// `GET /chat-rooms/{roomId}` 로 받아 온다. **확정된 방**이라야 볼 화면이므로
/// 모집 목록에서 찾지 않는다. 서버가 방을 주지 않으면 지어내지 않고 빈 상태를 그린다 (R1).
private struct TripConfirmedDestination: View {
  let tripID: String
  let serverRoomID: Int64?
  var tripContext: TripInteractionContext

  @State private var loadedTrip: TripRecruitment?
  @State private var participants: [ServerChatRoomDetail.ServerParticipant] = []
  @State private var nicknamesByUserID: [Int64: String] = [:]
  @State private var didLoad = false

  private var trip: TripRecruitment? {
    tripContext.trips.first { $0.id == tripID } ?? loadedTrip
  }

  var body: some View {
    Group {
      if let trip {
        TripConfirmedView(
          trip: trip,
          thread: tripContext.chatThreadProvider(trip),
          onSendChatMessage: tripContext.onSendChatMessage,
          participants: participants,
          participantNicknamesByUserID: nicknamesByUserID
        )
      } else if didLoad {
        MoyeoEmptyStateView(message: MoyeoEmptyText.noRecruitments)
      } else {
        MoyeoEmptyStateView(message: MoyeoEmptyText.loading)
      }
    }
    .task { await load() }
  }

  private func load() async {
    guard trip == nil, !didLoad else { return }
    guard MoyeoServerSync.isEnabled, let serverRoomID else {
      didLoad = true
      return
    }
    let course = (try? await TravelCourseAPIClient.shared.roomCourse(roomID: serverRoomID))?.course
    if let detail = try? await ChatRoomAPIClient.shared.detail(roomID: serverRoomID) {
      loadedTrip = ServerTripMapper.trip(from: detail, course: course)
      participants = detail.participants
      // 닉네임은 상세 응답에 없다 — 멤버 목록이 열리면 사람별 동물 이모지를 쓴다 (R5).
      if let members = try? await ChatRoomContentAPIClient.shared.members(roomID: serverRoomID) {
        nicknamesByUserID = Dictionary(
          members.members.map { ($0.userId, $0.nickname) },
          uniquingKeysWith: { first, _ in first }
        )
      }
    }
    didLoad = true
  }
}

private struct NotificationCenterView: View {
  var tripContext = TripInteractionContext()
  @Binding var feedPosts: [FeedPost]
  @State private var selectedTrip: TripRecruitment?
  @State private var selectedPost: FeedPost?
  @State private var showsUnreadOnly = false
  @State private var readAll = false
  @State private var showsRemovalReason = false
  @State private var showsFriends = false
  /// 실서버 알림 — 로그인 세션이 있고 목록 API가 성공했을 때만 채워진다 (nil = 목데이터)
  @State private var serverNotifications: [ServerNotification]?
  @State private var serverUnreadCount = 0
  @State private var serverReadIDs = Set<Int64>()
  @State private var serverKickHistory: ServerKickHistory?

  private let items = supportNotificationMockItems

  private var unreadCount: Int {
    if serverNotifications != nil {
      return serverUnreadCount
    }
    return items.filter { $0.isUnread && !readAll }.count
  }

  private var visibleItems: [SupportNotification] {
    guard showsUnreadOnly else { return items }
    return items.filter { $0.isUnread && !readAll }
  }

  private func isServerUnread(_ notification: ServerNotification) -> Bool {
    !notification.read && !serverReadIDs.contains(notification.notificationId) && !readAll
  }

  private var visibleServerItems: [ServerNotification] {
    guard let serverNotifications else { return [] }
    guard showsUnreadOnly else { return serverNotifications }
    return serverNotifications.filter(isServerUnread)
  }

  /// 서버 알림을 화면기획 13처럼 오늘/어제/이전으로 묶는다
  private var groupedServerItems: [(group: String, items: [ServerNotification])] {
    var order: [String] = []
    var buckets: [String: [ServerNotification]] = [:]
    for item in visibleServerItems {
      let group = ServerNotificationPresentation.groupTitle(for: item.createdAt)
      if buckets[group] == nil { order.append(group) }
      buckets[group, default: []].append(item)
    }
    return order.map { ($0, buckets[$0] ?? []) }
  }

  private var groupedItems: [(group: String, items: [SupportNotification])] {
    var order: [String] = []
    var buckets: [String: [SupportNotification]] = [:]
    for item in visibleItems {
      if buckets[item.group] == nil { order.append(item.group) }
      buckets[item.group, default: []].append(item)
    }
    return order.map { ($0, buckets[$0] ?? []) }
  }

  var body: some View {
    // 알림은 항목마다 카드를 두지 않고 테이블처럼 한 줄씩 수직으로 쌓는다 (화면기획 기준).
    // 카드가 겹치면 목록을 훑을 때 어디까지 읽었는지 잡히지 않는다.
    SupportList(
      title: "알림",
      spacing: 0,
      trailingTitle: "모두 읽음",
      trailingAction: { markAllRead() },
      content: {
      // 화면기획·웹과 같은 전체 / 안읽음 필터
      HStack(spacing: 8) {
        NotificationFilterChip(title: "전체", isSelected: !showsUnreadOnly) { showsUnreadOnly = false }
        NotificationFilterChip(title: "안읽음 \(unreadCount)", isSelected: showsUnreadOnly) { showsUnreadOnly = true }
        Spacer(minLength: 0)
      }

      if serverNotifications != nil {
        // 실서버 알림 목록 — 서버가 준 알림만 그린다
        if visibleServerItems.isEmpty {
          MoyeoEmptyStateView(
            message: MoyeoEmptyText.noNotifications,
            systemImage: "bell",
            accessibilityIdentifier: "notifications.server.empty"
          )
        } else {
          ForEach(groupedServerItems, id: \.group) { section in
            Text(section.group)
              .font(.caption.weight(.semibold))
              .foregroundStyle(MoyeoTheme.muted)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.top, 8)
              .padding(.bottom, 1)

            ForEach(section.items) { item in
              serverNotificationRow(item)
            }
          }
        }
      } else {
        // 서버 알림을 못 받았다 — 목 알림을 채우지 않고 §2 빈 상태를 그린다
        MoyeoEmptyStateView(
          message: MoyeoEmptyText.noNotifications,
          systemImage: "bell",
          accessibilityIdentifier: "notifications.empty"
        )
      }
    })
    .task {
      await loadServerNotifications()
    }
    .navigationDestination(item: $serverKickHistory) { history in
      RemovalReasonView(serverHistory: history)
    }
    .navigationDestination(item: $selectedTrip) { trip in
      TripDetailView(
        trip: trip,
        isApplied: tripContext.isApplied(trip),
        threadProvider: tripContext.chatThreadProvider,
        onApplied: tripContext.onApplyTrip,
        onSendChatMessage: tripContext.onSendChatMessage
      )
    }
    .navigationDestination(item: $selectedPost) { post in
      FeedDetailView(post: post) {
        incrementCommentCount(for: post.id)
      }
    }
    .navigationDestination(isPresented: $showsRemovalReason) {
      RemovalReasonView()
    }
    .navigationDestination(isPresented: $showsFriends) {
      FriendsManagementView()
    }
  }

  /// 기획 13 목록은 문장 일부만 굵다 — `**…**` 마크다운이 있으면 그 부분만 굵게,
  /// 없으면 기존처럼 제목 전체를 굵게 그린다.
  private func titleText(for item: SupportNotification) -> Text {
    if item.title.contains("**"), let attributed = try? AttributedString(markdown: item.title) {
      return Text(attributed).font(.subheadline)
    }
    return Text(item.title).font(.subheadline.weight(.heavy))
  }

  // MARK: - 실서버 알림

  private func loadServerNotifications() async {
    guard MoyeoServerSync.isEnabled, serverNotifications == nil else { return }
    guard let page = try? await NotificationAPIClient.shared.notifications(size: 50) else { return }
    serverNotifications = page.notifications
    serverUnreadCount = Int(page.unreadCount)
  }

  private func markAllRead() {
    readAll = true
    guard serverNotifications != nil else { return }
    serverUnreadCount = 0
    Task {
      try? await NotificationAPIClient.shared.markAllRead()
    }
  }

  private func serverNotificationRow(_ item: ServerNotification) -> some View {
    ServerNotificationRow(item: item, isUnread: isServerUnread(item)) {
      openServerNotification(item)
    }
  }

  private func openServerNotification(_ item: ServerNotification) {
    if isServerUnread(item) {
      serverReadIDs.insert(item.notificationId)
      serverUnreadCount = max(serverUnreadCount - 1, 0)
      Task {
        try? await NotificationAPIClient.shared.markRead(notificationID: item.notificationId)
      }
    }

    switch item.type {
    case "CHAT_ROOM_KICKED":
      Task {
        serverKickHistory = try? await NotificationAPIClient.shared.kickHistory(
          notificationID: item.notificationId
        )
      }
    case "FRIEND_REQUEST", "FRIEND_ACCEPTED":
      showsFriends = true
    default:
      if let roomID = item.chatRoomId {
        selectedTrip = ServerTripMapper.placeholderTrip(roomID: roomID)
      }
    }
  }

  private func open(_ target: SupportNotificationTarget) {
    switch target {
    case .trip(let tripID):
      selectedTrip = tripContext.trips.first { $0.id == tripID }
    case .post(let postID):
      selectedPost = feedPosts.first { $0.id == postID }
    case .friends:
      showsFriends = true
    case .removalReason:
      showsRemovalReason = true
    case .unwired:
      break
    }
  }

  private func incrementCommentCount(for postID: String) {
    guard let index = feedPosts.firstIndex(where: { $0.id == postID }) else { return }
    feedPosts[index].commentCount += 1
  }
}

private struct ComponentStatesPreview: View {
    var body: some View {
        ScrollView {
            // 화면기획은 상태마다 생김새가 다르다 — 빈 상태·에러에는 행동 버튼, 로딩은 스켈레톤,
            // 오프라인은 경고 색 배너. 네 장을 같은 모양으로 그리면 상태를 구분할 수 없다.
            VStack(spacing: 14) {
                Text("화면 상태")
                    .font(.title2.weight(.heavy))
                    .frame(maxWidth: .infinity, alignment: .leading)

                StatePreviewCard(
                    icon: "person.2.fill",
                    iconBackground: MoyeoTheme.leaf,
                    iconTint: MoyeoTheme.forest,
                    label: "EMPTY",
                    title: "아직 참여한 모임이 없어요",
                    detail: "첫 모임을 열어보세요",
                    actionTitle: "+ 만들기",
                    actionIsPrimary: true
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("LOADING (Skeleton)")
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.muted)
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(MoyeoTheme.softLine)
                            .frame(width: 56, height: 56)
                        VStack(alignment: .leading, spacing: 8) {
                            SkeletonBar(widthRatio: 0.7, height: 12)
                            SkeletonBar(widthRatio: 0.5, height: 10)
                            SkeletonBar(widthRatio: 0.85, height: 10)
                        }
                        .padding(.top, 6)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MoyeoTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(MoyeoTheme.softLine, lineWidth: 1)
                }

                StatePreviewCard(
                    icon: "exclamationmark.triangle.fill",
                    iconBackground: MoyeoTheme.coral.opacity(0.18),
                    iconTint: MoyeoTheme.coral,
                    label: "ERROR",
                    title: "문제가 생겼어요",
                    detail: "잠시 후 다시 시도해주세요 E-503",
                    actionTitle: "새로고침",
                    actionIsPrimary: false
                )

                HStack(spacing: 12) {
                    Text("OFFLINE")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MoyeoTheme.warningText)
                    Text("인터넷에 연결되어 있지 않아요")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MoyeoTheme.warningText)
                    Spacer(minLength: 0)
                    Text("재시도")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(MoyeoTheme.warningText)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(MoyeoTheme.warningBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(20)
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("screen.componentStates")
    }
}

private struct SkeletonBar: View {
    let widthRatio: CGFloat
    let height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(MoyeoTheme.softLine)
                .frame(width: proxy.size.width * widthRatio, height: height)
        }
        .frame(height: height)
    }
}

private struct StatePreviewCard: View {
    let icon: String
    let iconBackground: Color
    let iconTint: Color
    let label: String
    let title: String
    let detail: String
    let actionTitle: String
    let actionIsPrimary: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(iconTint)
                .frame(width: 60, height: 60)
                .background(iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(MoyeoTheme.muted)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(MoyeoTheme.muted)
            }
            Spacer(minLength: 0)
            Text(actionTitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(actionIsPrimary ? .white : MoyeoTheme.ink)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(actionIsPrimary ? MoyeoTheme.forest : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(actionIsPrimary ? Color.clear : MoyeoTheme.line, lineWidth: 1)
                }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MoyeoTheme.softLine, lineWidth: 1)
        }
    }
}

/// 31 모임 종료 경고 팝업 (changeLog14).
/// 오버레이는 이전 화면 위에 뜬 것으로 그린다 — 이 팝업은 스스로 배경을 그리지 않고
/// 20-1 채팅방 사이드 메뉴 위에 딤과 함께 얹힌다.
/// 31 나가기 확인의 역할. 호스트와 참가자는 **결과가 전혀 다르다** —
/// 문구를 호스트 기준으로 고정해 두면 참가자가 보고 자기가 모임을 없애는 것으로 읽는다
/// (정본 `ATTACH-COMPOSER-CANON.md` §6-5).
enum LeaveConfirmationRole {
  case host
  case member

  var title: String {
    switch self {
    case .host: "호스트가 나가면\n이 모임은 종료돼요"
    case .member: "이 모임에서 나갈까요?"
    }
  }

  var confirmTitle: String {
    switch self {
    case .host: "모임 종료"
    case .member: "나가기"
    }
  }
}

struct LeaveConfirmationDialog: View {
  /// 역할을 모르면(미로그인·목데이터 스레드) 기존과 같이 호스트 문구를 쓴다.
  var role: LeaveConfirmationRole = .host
  /// 호스트 문구의 "승인된 N명" — 서버가 준 인원일 때만 적는다.
  var approvedCount: Int?
  var onCancel: () -> Void = {}
  var onConfirm: () -> Void = {}

  var body: some View {
    ZStack {
      MoyeoTheme.overlayScrim.ignoresSafeArea()

      // 화면기획의 경고 팝업은 좌측 정렬이고, 두 버튼은 같은 너비의 꼭지점 둥근 사각형이다.
      // 가운데 정렬 + 알약 버튼 + 플랫폼 강조색(파랑) 취소는 다른 플랫폼과 어긋난다.
      VStack(alignment: .leading, spacing: 0) {
        // 위험 경고는 danger red다 — coral(accent)은 D-day 배지 같은 강조에만 쓴다
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(MoyeoTheme.dangerRed)
          .frame(width: 48, height: 48)
          .background(MoyeoTheme.dangerRed.opacity(0.16))
          .clipShape(Circle())

        Text(role.title)
          .font(.title3.weight(.heavy))
          .foregroundStyle(MoyeoTheme.ink)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 16)

        Text(bodyText)
          .font(.subheadline)
          .foregroundStyle(MoyeoTheme.muted)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 10)

        if role == .host {
          // 이유 입력은 본문에서 한 줄 띄워 별개 입력으로 읽히게 한다
          VStack(alignment: .leading, spacing: 6) {
            Text("나가는 이유 (필수)")
              .font(.caption)
              .foregroundStyle(MoyeoTheme.muted)
            Text("일정 변동으로 어렵게 됐어요...")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(MoyeoTheme.ink)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(12)
          .background(MoyeoTheme.subtleBackground)
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
          .padding(.top, 20)
        }

        HStack(spacing: 8) {
          Button(action: onCancel) {
            Text("취소")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(MoyeoTheme.ink)
              .frame(maxWidth: .infinity)
              .frame(height: 44)
              .overlay(RoundedRectangle(cornerRadius: 10).stroke(MoyeoTheme.line))
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("leave.cancel")
          Button(action: onConfirm) {
            Text(role.confirmTitle)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .frame(height: 44)
              .background(MoyeoTheme.dangerRed)
              .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("leave.confirm")
        }
        .padding(.top, 20)
      }
      .padding(24)
      .frame(maxWidth: 330)
      // 팝업 표면도 카드 표면이다 — 다크에서 `background`는 화면 배경과 같은 값이다
      .background(MoyeoTheme.card)
      .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 20).stroke(MoyeoTheme.line))
      .shadow(color: Color.black.opacity(0.28), radius: 24, y: 10)
    }
    .accessibilityIdentifier(
      role == .host ? "screen.hostLeaveConfirmation" : "screen.memberLeaveConfirmation"
    )
  }

  /// 읽기 전용 보존 기간 문구는 세 플랫폼이 글자 그대로 같다 (정본 §4-1 문구 통일 표).
  private var bodyText: String {
    switch role {
    case .host:
      // 인원수를 문구에 박지 않는다 — 값이 없을 때 문장이 갈리고, 세 플랫폼이 서로 달라진다.
      return "승인된 동행자 모두에게 알림이 가고, 채팅방은 14일 동안 읽기 전용으로 유지된 후 사라져요."
    case .member:
      return "내 자리가 비면서 대기 중인 다음 신청자가 자동으로 합류해요. 다시 신청하면 맨 뒤부터예요."
    }
  }
}

/// 알림 목록 상단의 전체 / 안읽음 필터 칩
private struct NotificationFilterChip: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.footnote.weight(.bold))
        .foregroundStyle(isSelected ? .white : MoyeoTheme.muted)
        .padding(.horizontal, 13)
        .frame(height: 32)
        .background(isSelected ? MoyeoTheme.forest : MoyeoTheme.card)
        .clipShape(Capsule())
        .overlay {
          Capsule().stroke(isSelected ? Color.clear : MoyeoTheme.softLine, lineWidth: 1)
        }
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("notifications.filter.\(title)")
  }
}

private struct SupportNotification: Identifiable {
  let id = UUID()
  /// 기획 13 목록은 문장 일부만 굵다 — `**굵게**` 마크다운을 지원한다.
  let title: String
  let time: String
  let icon: String
  let target: SupportNotificationTarget
  /// 화면기획처럼 오늘/어제로 묶어서 보여준다
  var group: String = "오늘"
  var isUnread: Bool = false
  /// 기획 13은 알림 유형마다 아이콘 색이 다르다 (친구=파랑 · 강퇴=danger · 좋아요=분홍 …)
  var tint: Color = MoyeoTheme.forest
  var bubble: Color = MoyeoTheme.leaf
  /// 친구 요청 행에만 있는 거절/수락 버튼 (13 기획)
  var showsFriendActions = false
}

/// 실서버 알림 한 행 — 서버가 내려준 내용·시각만 그린다
private struct ServerNotificationRow: View {
  let item: ServerNotification
  let isUnread: Bool
  let onOpen: () -> Void

  var body: some View {
    let style = ServerNotificationPresentation.style(for: item.type)

    VStack(spacing: 0) {
      Button(action: onOpen) {
        HStack(alignment: .top, spacing: 11) {
          SupportIconBubble(systemImage: style.icon, tint: style.tint, bubble: style.bubble)
          VStack(alignment: .leading, spacing: 4) {
            Text(item.content)
              .font(isUnread ? .subheadline.weight(.heavy) : .subheadline)
              .foregroundStyle(MoyeoTheme.ink)
              .fixedSize(horizontal: false, vertical: true)
            Text(ServerNotificationPresentation.timeText(for: item.createdAt))
              .font(.caption.weight(.bold))
              .foregroundStyle(MoyeoTheme.muted)
            if item.type == "FRIEND_REQUEST" {
              ServerFriendActionButtons(requestID: item.referenceId)
                .padding(.top, 2)
            }
          }
          Spacer()
          Image(systemName: "chevron.right")
            .font(.caption.weight(.heavy))
            .foregroundStyle(MoyeoTheme.text400)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("notifications.server.\(item.notificationId)")
      Divider().overlay(MoyeoTheme.softLine)
    }
  }
}

/// 서버 친구 요청 알림의 거절/수락 (수락·거절 API 실호출)
private struct ServerFriendActionButtons: View {
  let requestID: Int64
  @State private var resolution: String?

  var body: some View {
    HStack(spacing: 8) {
      if let resolution {
        Text(resolution)
          .font(.footnote.weight(.bold))
          .foregroundStyle(MoyeoTheme.muted)
          .padding(.horizontal, 14)
          .frame(height: 34)
          .background(MoyeoTheme.subtleBackground)
          .clipShape(Capsule())
      } else {
        Button {
          Task {
            try? await SocialAPIClient.shared.rejectFriendRequest(requestID: requestID)
            resolution = "거절함"
          }
        } label: {
          Text("거절")
            .font(.footnote.weight(.bold))
            .foregroundStyle(MoyeoTheme.ink)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(MoyeoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
              RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(MoyeoTheme.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        Button {
          Task {
            try? await SocialAPIClient.shared.acceptFriendRequest(requestID: requestID)
            resolution = "수락함"
          }
        } label: {
          Text("수락")
            .font(.footnote.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(MoyeoTheme.forest)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
      }
    }
  }
}

/// 실서버 알림의 유형별 아이콘·색과 시간 표기 (기획 13의 유형별 색 규칙을 따른다)
enum ServerNotificationPresentation {
  struct Style {
    let icon: String
    let tint: Color
    let bubble: Color
  }

  static func style(for type: String) -> Style {
    switch type {
    case "CHAT_ROOM_CREATED":
      return Style(icon: "person.2.fill", tint: MoyeoTheme.forest, bubble: MoyeoTheme.leaf)
    case "CHAT_ROOM_KICKED":
      return Style(
        icon: "exclamationmark.triangle.fill",
        tint: MoyeoTheme.coral,
        bubble: MoyeoTheme.coral.opacity(0.14)
      )
    case "CHAT_MESSAGE_RECEIVED":
      return Style(
        icon: "bubble.left.fill", tint: MoyeoTheme.coral, bubble: MoyeoTheme.coral.opacity(0.14))
    case "TRAVEL_COURSE_UPDATED":
      return Style(icon: "arrow.triangle.2.circlepath", tint: MoyeoTheme.forest, bubble: MoyeoTheme.leaf)
    case "MEETING_INFO_UPDATED":
      return Style(
        icon: "mappin.and.ellipse", tint: MoyeoTheme.river, bubble: MoyeoTheme.river.opacity(0.13))
    case "RECRUITMENT_DEADLINE":
      return Style(
        icon: "clock.fill", tint: MoyeoTheme.sunrise, bubble: MoyeoTheme.sunrise.opacity(0.16))
    case "FRIEND_REQUEST":
      return Style(
        icon: "person.crop.circle.badge.plus",
        tint: MoyeoTheme.river,
        bubble: MoyeoTheme.river.opacity(0.13)
      )
    case "FRIEND_ACCEPTED":
      return Style(
        icon: "person.2.fill", tint: MoyeoTheme.river, bubble: MoyeoTheme.river.opacity(0.13))
    case "FEED_LIKE":
      return Style(
        icon: "heart.fill", tint: MoyeoTheme.blossom, bubble: MoyeoTheme.blossom.opacity(0.16))
    default:
      return Style(icon: "bell.fill", tint: MoyeoTheme.forest, bubble: MoyeoTheme.leaf)
    }
  }

  static func date(from createdAt: String) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    if let date = formatter.date(from: createdAt) { return date }
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
    return formatter.date(from: createdAt)
  }

  static func groupTitle(for createdAt: String) -> String {
    guard let date = date(from: createdAt) else { return "이전" }
    if Calendar.current.isDateInToday(date) { return "오늘" }
    if Calendar.current.isDateInYesterday(date) { return "어제" }
    return "이전"
  }

  static func timeText(for createdAt: String) -> String {
    guard let date = date(from: createdAt) else { return createdAt }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    if Calendar.current.isDateInToday(date) {
      formatter.dateFormat = "a h:mm"
    } else if Calendar.current.isDateInYesterday(date) {
      formatter.dateFormat = "'어제' a h:mm"
    } else {
      formatter.dateFormat = "M월 d일 a h:mm"
    }
    return formatter.string(from: date)
  }
}

/// 13 알림은 서버 목록이 전부다 — 목 알림을 채우지 않는다 (NO-MOCK-CANON R1).
private let supportNotificationMockItems: [SupportNotification] = []

private enum SupportNotificationTarget {
  case trip(String)
  case post(String)
  /// 친구 요청 알림 → 친구 관리 화면
  case friends
  /// changeLog14 — 강퇴 알림 탭 시 내보내기 안내(13-1)로 이동
  case removalReason
  /// 기획에 탭 목적지가 정해지지 않은 행 — 목데이터 카탈로그라 이동 없이 둔다
  case unwired
}

/// 13-1 내보내기 안내 (changeLog14) — 강퇴 알림에서만 진입한다.
/// 채팅방은 이미 사라진 뒤라 채팅 쪽에는 어떤 안내도 두지 않고,
/// 이의 제기(고객센터) 경로도 화면기획에 없으므로 하단 동작은 `확인` 하나다.
private struct RemovalReasonView: View {
  /// 실서버 강퇴 이력 — 알림 13-1에서 서버 알림으로 진입하면 채워진다
  var serverHistory: ServerKickHistory?
  @Environment(\.dismiss) private var dismiss

  private var titleText: String {
    guard let serverHistory else { return "감포 바다 일출 모임에서\n내보내졌어요" }
    return "\(serverHistory.roomTitle)에서\n내보내졌어요"
  }

  private var metaText: String {
    guard let serverHistory else { return "2026.08.22 (토) 오후 6:02 · 호스트 결정" }
    guard let date = ServerNotificationPresentation.date(from: serverHistory.kickedAt) else {
      return serverHistory.kickedAt
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "yyyy.MM.dd (E) a h:mm"
    return "\(formatter.string(from: date)) · 호스트 결정"
  }

  private var reasonText: String {
    guard let serverHistory else {
      return "“모임 컨셉과 맞지 않는 대화가 반복되어, 남은 멤버들을 위해 함께하기 어렵다고 판단했어요.”"
    }
    return "“\(serverHistory.reason)”"
  }

  private let aftermath = [
    "이 모임에는 다시 신청할 수 없어요.",
    "채팅방이 내 목록에서 사라져요. 이미 남긴 대화는 모임 채팅방에 그대로 남아요.",
    "다른 모임을 찾고 신청하는 데에는 아무 영향이 없어요."
  ]

  var body: some View {
    SupportList(title: "내보내기 안내", spacing: 16) {
      // 상단 요약 — danger 틴트 원 + 두 줄 제목 + 일시·주체
      VStack(spacing: 0) {
        Image(systemName: "exclamationmark.triangle")
          .font(.system(size: 26, weight: .bold))
          .foregroundStyle(MoyeoTheme.coral)
          .frame(width: 64, height: 64)
          .background(MoyeoTheme.coral.opacity(0.14))
          .clipShape(Circle())
        Text(titleText)
          .font(.title3.weight(.heavy))
          .foregroundStyle(MoyeoTheme.ink)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 18)
        Text(metaText)
          .font(.caption.weight(.semibold))
          .foregroundStyle(MoyeoTheme.muted)
          .padding(.top, 8)
      }
      .frame(maxWidth: .infinity)
      .padding(.top, 20)
      .padding(.bottom, 6)

      // 사유는 호스트가 남긴 서술 하나만 보여준다 — 정형 카테고리 태그는 두지 않는다 (changeLog14)
      VStack(alignment: .leading, spacing: 12) {
        Text("호스트가 남긴 사유")
          .font(.subheadline.weight(.heavy))
          .foregroundStyle(MoyeoTheme.ink)
        Text(reasonText)
          .font(.subheadline)
          .foregroundStyle(MoyeoTheme.text700)
          .fixedSize(horizontal: false, vertical: true)
          .padding(12)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(MoyeoTheme.subtleBackground)
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(MoyeoTheme.card)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(MoyeoTheme.line, lineWidth: 1)
      }
      .accessibilityIdentifier("removal-reason.hostReason")

      // 이후 정책 3가지 고지 (changeLog14)
      VStack(alignment: .leading, spacing: 10) {
        Text("내보내진 뒤에는")
          .font(.subheadline.weight(.heavy))
          .foregroundStyle(MoyeoTheme.ink)
        ForEach(aftermath, id: \.self) { line in
          HStack(alignment: .top, spacing: 8) {
            Circle()
              .fill(MoyeoTheme.text400)
              .frame(width: 4, height: 4)
              .padding(.top, 7)
            Text(line)
              .font(.footnote)
              .foregroundStyle(MoyeoTheme.text700)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(MoyeoTheme.card)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(MoyeoTheme.line, lineWidth: 1)
      }
      .accessibilityIdentifier("removal-reason.aftermath")
    }
    .safeAreaInset(edge: .bottom) {
      Button {
        dismiss()
      } label: {
        Text("확인")
          .font(.subheadline.weight(.heavy))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 52)
          .background(MoyeoTheme.forest)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("removal-reason-confirm")
      .padding(.horizontal, 18)
      .padding(.top, 8)
      .padding(.bottom, 12)
      .background(MoyeoTheme.background)
    }
    .accessibilityIdentifier("removal-reason-screen")
  }
}

/// 29-5 계정 연결 캡처 라우트의 소유자.
///
/// `ProviderManagementView.service` 는 `@ObservedObject` 다. 여기서 `.current` 를 그대로 넘기면
/// **본문이 다시 그려질 때마다 서비스가 새로 만들어져** `GET /auth/providers` 응답이 매번 버려진다
/// (`isLoading = true` 가 곧바로 재생성을 부르는 되먹임이라 `연결됨` 이 영영 뜨지 않는다).
/// 설정 시트 쪽과 같이 소유자가 `@StateObject` 로 한 번만 만들어 붙든다.
private struct AccountProvidersRoute: View {
  @StateObject private var service = AuthProviderLinkService()

  var body: some View {
    ProviderManagementView(service: service, isPresentedAsSheet: false)
  }
}
