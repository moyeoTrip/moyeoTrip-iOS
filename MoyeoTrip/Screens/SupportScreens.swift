// swiftlint:disable file_length
import SwiftUI

enum SupportRoute: Hashable, Identifiable {
  case authFlow
  case authPreview(AuthDirectScreen)
  case authTerms
  case applicationSheet
  case leaveConfirmation(String)
  case notifications
  case createRecruitment(String)
  case hostManage(String)
  case search
  case customCourse
  case createSchedule
  case createMeeting
  case createPeople
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
  case specialMessages
  case friends
  case tripMessage
  case report
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

  var id: String {
    switch self {
    case .authFlow:
      return "authFlow"
    case .authPreview(let screen):
      return "authPreview.\(screen.rawValue)"
    case .authTerms:
      return "authTerms"
    case .applicationSheet:
      return "applicationSheet"
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
    case .createPeople:
      return "createPeople"
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
    case .specialMessages: return "specialMessages"
    case .friends: return "friends"
    case .tripMessage: return "tripMessage"
    case .report: return "report"
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
    feedPosts: Binding<[FeedPost]> = .constant(MockData.feedPosts),
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
    case .authTerms:
      AuthTermsDirectLaunchView()
    case .applicationSheet:
      ApplicationSheetDirectLaunchView()
    // changeLog14 — 31 경고 팝업은 20-1 채팅방 사이드 메뉴 위에 뜬 것으로 그린다.
    // 직접 진입(UITEST `leave`)도 그 화면을 깔고 팝업을 연 상태로 시작한다.
    case .leaveConfirmation(let threadID):
      ChatSideMenuView(thread: resolvedThread(threadID), startsWithLeaveConfirmation: true)
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
    case .hostManage(let tripID):
      let trip =
        tripContext.trips.first { $0.id == tripID } ?? MockData.trip(for: tripID)
        ?? MockData.trips[0]
      HostManageView(
        trip: trip,
        thread: tripContext.chatThreadProvider(trip),
        onSendChatMessage: tripContext.onSendChatMessage,
        onApproveApplicant: tripContext.onApproveHostApplicant,
        onRejectApplicant: tripContext.onRejectHostApplicant,
        onSetRecruitmentClosed: tripContext.onSetRecruitmentClosed
      )
    case .search:
      SearchView(tripContext: tripContext)
    case .customCourse:
      CustomCourseEditorView()
    case .createSchedule:
      RecruitmentSchedulePreviewView()
    case .createMeeting:
      RecruitmentMeetingPreviewView()
    case .createPeople:
      RecruitmentPeoplePreviewView()
    case .createDetail:
      RecruitmentDetailPreviewView()
    case .createSummary:
      RecruitmentSummaryPreviewView(source: .linked)
    case .createSummaryCustom:
      RecruitmentSummaryPreviewView(source: .custom)
    case .placeSearch:
      PlaceSearchView()
    case .placeDetail(let placeID):
      PlaceDetailView(
        place: TourismPlaceCatalog.places.first { $0.id == placeID }
          ?? TourismPlaceCatalog.places[2]
      )
    case .courseEdit(let tripID, let state):
      CourseRouteEditView(
        trip: tripContext.trips.first { $0.id == tripID } ?? MockData.trips[0],
        state: state,
        onSaved: tripContext.onUpdateRoute
      )
    case .noticeHistory(let threadID):
      NoticeHistoryView(
        thread: tripContext.chatThreads.first { $0.id == threadID }
          ?? MockData.chatThreads[0],
        onCreate: tripContext.onCreateNotice
      )
    case .tripConfirmed(let tripID):
      let trip =
        tripContext.trips.first { $0.id == tripID }
        ?? MockData.trip(for: tripID)
        ?? MockData.trips[0]
      TripConfirmedView(
        trip: trip,
        thread: tripContext.chatThreadProvider(trip),
        onSendChatMessage: tripContext.onSendChatMessage
      )
    case .chatMenu(let threadID):
      ChatSideMenuView(thread: resolvedThread(threadID))
    // changeLog14 — 20-1a · 20-1b 는 20-1 위에 뜬 시트다. 직접 진입도 같은 구조로 연다.
    case .chatMenuMemberActions(let threadID):
      ChatSideMenuView(thread: resolvedThread(threadID), startsWithMemberActions: true)
    case .chatMenuMemberRemove(let threadID):
      ChatSideMenuView(thread: resolvedThread(threadID), startsWithMemberRemoval: true)
    case .chatAttach:
      ChatAttachmentMenuView()
    case .specialMessages:
      SpecialMessageCardsView()
    case .friends:
      FriendsManagementView()
    case .tripMessage:
      TripMessageView()
    case .report:
      ReportView()
    case .blockedUsers:
      BlockedUsersView()
    case .coursePublish:
      CoursePublishView()
    case .tripDay(let threadID):
      TripDayView(thread: resolvedThread(threadID))
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
      FeedCommentsView(post: MockData.feedPost(for: postID, in: feedPosts) ?? feedPosts[0])
    case .legalDocument(let document):
      LegalDocumentDetailView(kind: document, entry: .settings)
    case .signupLegalDocument(let document):
      LegalDocumentDetailView(kind: document, entry: .signup)
    }
  }

  private func resolvedThread(_ id: String) -> ChatThread {
    tripContext.chatThreads.first { $0.id == id }
      ?? MockData.chatThread(for: id)
      ?? MockData.chatThreads[0]
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

  // changeLog14 — 알림 목데이터는 13 기획 목록이 모든 플랫폼의 기준이다.
  // 오늘 5건 + 어제 3건, 안읽음 4. 이 목록에 없는 행을 추가로 두지 않는다.
  private let items = [
    SupportNotification(
      title: "주왕산 & 주산지 여행이 확정됐어요 🎉",
      time: "방금 전",
      icon: "checkmark.seal.fill",
      target: .trip("trip-cheongsong-juwangsan"),
      isUnread: true
    ),
    SupportNotification(
      title: "경주 단풍·야경 모임이 만들어졌어요 ✨",
      time: "10분 전",
      icon: "person.2.fill",
      target: .trip("trip-gyeongju-night"),
      isUnread: true
    ),
    SupportNotification(
      title: "우직한 곰 7821님이 **메시지**를 보냈어요",
      time: "1시간 전",
      icon: "bubble.left.fill",
      target: .unwired,
      isUnread: true,
      tint: MoyeoTheme.coral,
      bubble: MoyeoTheme.coral.opacity(0.14)
    ),
    SupportNotification(
      title: "여행 잘 마치셨죠? 함께 걸은 친구에게 **한 줄** 남겨볼까요?",
      time: "2시간 전",
      icon: "doc.text.fill",
      target: .unwired
    ),
    SupportNotification(
      title: "마감 **D-1** · 현재 4/8명이에요",
      time: "3시간 전",
      icon: "clock.fill",
      target: .trip("trip-cheongsong-juwangsan"),
      tint: MoyeoTheme.sunrise,
      bubble: MoyeoTheme.sunrise.opacity(0.16)
    ),
    SupportNotification(
      title: "엉뚱한 토끼 1457님이 **친구 요청**을 보냈어요",
      time: "어제 오후 4시",
      icon: "person.crop.circle.badge.plus",
      target: .friends,
      group: "어제",
      isUnread: true,
      tint: MoyeoTheme.river,
      bubble: MoyeoTheme.river.opacity(0.13),
      showsFriendActions: true
    ),
    // changeLog14 — 강퇴 통보는 알림 센터의 한 행이다. 안읽음 수(4)는 바꾸지 않는다.
    SupportNotification(
      title: "**감포 바다 일출 모임**에서 내보내졌어요 · 사유 확인",
      time: "어제 오후 6시",
      icon: "exclamationmark.triangle.fill",
      target: .removalReason,
      group: "어제",
      tint: MoyeoTheme.coral,
      bubble: MoyeoTheme.coral.opacity(0.14)
    ),
    SupportNotification(
      title: "**3명**이 내 피드에 좋아요를 눌렀어요",
      time: "어제 오전 11시",
      icon: "heart.fill",
      target: .post("feed-01"),
      group: "어제",
      tint: MoyeoTheme.blossom,
      bubble: MoyeoTheme.blossom.opacity(0.16)
    )
  ]

  private var unreadCount: Int {
    items.filter { $0.isUnread && !readAll }.count
  }

  private var visibleItems: [SupportNotification] {
    guard showsUnreadOnly else { return items }
    return items.filter { $0.isUnread && !readAll }
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
      trailingAction: { readAll = true },
      content: {
      // 화면기획·웹과 같은 전체 / 안읽음 필터
      HStack(spacing: 8) {
        NotificationFilterChip(title: "전체", isSelected: !showsUnreadOnly) { showsUnreadOnly = false }
        NotificationFilterChip(title: "안읽음 \(unreadCount)", isSelected: showsUnreadOnly) { showsUnreadOnly = true }
        Spacer(minLength: 0)
      }

      ForEach(groupedItems, id: \.group) { section in
        Text(section.group)
          .font(.caption.weight(.semibold))
          .foregroundStyle(MoyeoTheme.muted)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.top, 8)
          .padding(.bottom, 1)
          .accessibilityIdentifier("notifications.group.\(section.group)")

        ForEach(section.items) { item in
        VStack(spacing: 0) {
          Button {
            open(item.target)
          } label: {
            HStack(alignment: .top, spacing: 11) {
              SupportIconBubble(systemImage: item.icon, tint: item.tint, bubble: item.bubble)
              VStack(alignment: .leading, spacing: 4) {
                titleText(for: item)
                  .foregroundStyle(MoyeoTheme.ink)
                  .fixedSize(horizontal: false, vertical: true)
                // 상대 시간은 보조 정보다 — 기획·웹·안드로이드와 같은 회색이다
                Text(item.time)
                  .font(.caption.weight(.bold))
                  .foregroundStyle(MoyeoTheme.muted)
                if item.showsFriendActions {
                  friendActionButtons
                    .padding(.top, 2)
                }
              }
              Spacer()
              Image(systemName: "chevron.right")
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.text400)
            }
            // 화면기획·웹·안드로이드와 같은 행 밀도. 8행이 한 화면에 담겨야 한다.
            .padding(.vertical, 10)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          Divider().overlay(MoyeoTheme.softLine)
          }
        }
      }
    })
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

  /// 친구 요청 행의 거절/수락 (13 기획). 목데이터라 동작은 두지 않는다.
  private var friendActionButtons: some View {
    HStack(spacing: 8) {
      Button {} label: {
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
      .accessibilityIdentifier("notifications.friend.reject")
      Button {} label: {
        Text("수락")
          .font(.footnote.weight(.bold))
          .foregroundStyle(.white)
          .padding(.horizontal, 14)
          .frame(height: 34)
          .background(MoyeoTheme.forest)
          .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("notifications.friend.accept")
    }
  }

  private func open(_ target: SupportNotificationTarget) {
    switch target {
    case .trip(let tripID):
      selectedTrip = tripContext.trips.first { $0.id == tripID } ?? MockData.trip(for: tripID)
    case .post(let postID):
      selectedPost = MockData.feedPost(for: postID, in: feedPosts)
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

private struct CreateRecruitmentView: View {
  let courseID: String
  let onCreated: (TripRecruitment, ChatThread) -> Void
  let onSendChatMessage: (ChatThread, ChatMessage) -> Void
  let onApproveApplicant: (TripRecruitment, Participant) -> Void
  let onRejectApplicant: (TripRecruitment, Participant) -> Void
  let onSetRecruitmentClosed: (TripRecruitment, Bool) -> Void
  @State private var createdTrip: TripRecruitment?
  @State private var createdThread: ChatThread?
  @State private var selectedThread: ChatThread?
  @State private var selectedHostContext: HostManageContext?
  @State private var scheduleDate = ""
  @State private var scheduleTime = ""
  @State private var meetingPoint = ""
  @State private var capacityText = "5"
  @State private var recruitmentNote = ""

  private var course: TravelCourse {
    MockData.course(for: courseID) ?? MockData.courses[0]
  }

  private var defaultSchedule: String {
    MockData.trips.first { $0.courseID == course.id }?.schedule ?? "2026.06.06 (토) 08:00"
  }

  private var defaultScheduleDate: String {
    let parts = defaultSchedule.split(separator: " ").map(String.init)
    guard parts.count >= 2 else { return defaultSchedule }
    return parts.prefix(2).joined(separator: " ")
  }

  private var defaultScheduleTime: String {
    let parts = defaultSchedule.split(separator: " ").map(String.init)
    guard parts.count > 2 else { return "08:00 - 18:00" }
    return parts.dropFirst(2).joined(separator: " ")
  }

  private var defaultMeetingPoint: String {
    MockData.trips.first { $0.courseID == course.id }?.meetupPoint ?? "\(course.region) 대표 터미널"
  }

  private var capacity: Int {
    let parsed = Int(capacityText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 5
    return min(max(parsed, 3), 12)
  }

  var body: some View {
    SupportList(title: "모집 만들기") {
      SupportCourseSummary(course: course)

      SupportCard {
        VStack(alignment: .leading, spacing: 16) {
          Text("모집 정보")
            .font(.headline.weight(.heavy))
            .foregroundStyle(MoyeoTheme.ink)
          SupportEditableField(
            title: "일정",
            text: $scheduleDate,
            identifier: "createRecruitment.date"
          )
          SupportEditableField(
            title: "시간",
            text: $scheduleTime,
            identifier: "createRecruitment.time"
          )
          SupportEditableField(
            title: "모이는 곳",
            text: $meetingPoint,
            identifier: "createRecruitment.place"
          )
          SupportEditableField(
            title: "모집 정원",
            text: Binding(
              get: { capacityText },
              set: { capacityText = String($0.filter(\.isNumber).prefix(2)) }
            ),
            helperText: "최소 3명, 최대 12명",
            keyboardType: .numberPad,
            identifier: "createRecruitment.capacity"
          )
          SupportField(
            title: "참가비", value: course.duration == "2박 3일" ? "1인 189,000원" : "1인 42,000원")
        }
      }

      SupportCard {
        VStack(alignment: .leading, spacing: 12) {
          Text("소개글")
            .font(.headline.weight(.heavy))
            .foregroundStyle(MoyeoTheme.ink)
          TextField("함께 갈 사람들에게 보여줄 안내", text: $recruitmentNote, axis: .vertical)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(MoyeoTheme.ink)
            .lineLimit(3...5)
            .padding(14)
            .background(MoyeoTheme.subtleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onChange(of: recruitmentNote) { _, value in
              if value.count > 160 {
                recruitmentNote = String(value.prefix(160))
              }
            }
            .accessibilityIdentifier("createRecruitment.note")
          HStack {
            Text("\(recruitmentNote.count)/160자")
            Spacer()
            Text("\(safeScheduleDate) · \(safeMeetingPoint) · 1/\(capacity)명 모집")
          }
          .font(.caption.weight(.semibold))
          .foregroundStyle(MoyeoTheme.muted)
        }
      }

      if let createdTrip {
        SupportCard {
          VStack(alignment: .leading, spacing: 12) {
            Label("모집이 준비됐어요", systemImage: "checkmark.seal.fill")
              .font(.headline.weight(.heavy))
              .foregroundStyle(MoyeoTheme.forest)
            Text("\(createdTrip.title) 채팅방에서 참여자와 준비물을 나눌 수 있어요.")
              .font(.subheadline)
              .foregroundStyle(MoyeoTheme.muted)
              .fixedSize(horizontal: false, vertical: true)
            Button {
              if let createdThread {
                selectedHostContext = HostManageContext(trip: createdTrip, thread: createdThread)
              }
            } label: {
              Label("모집 관리", systemImage: "person.2.badge.gearshape.fill")
                .font(.subheadline.weight(.heavy))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(MoyeoTheme.forest)
            .accessibilityIdentifier("createRecruitment.openManage")

            Button {
              selectedThread = createdThread
            } label: {
              Label("채팅방 미리보기", systemImage: "bubble.left.and.bubble.right.fill")
                .font(.subheadline.weight(.heavy))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(MoyeoTheme.forest)
          }
        }
      }

      if createdTrip == nil {
        Button {
          createRecruitment()
        } label: {
          Label("모집 만들기", systemImage: "person.3.fill")
            .font(.subheadline.weight(.heavy))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.borderedProminent)
        .tint(MoyeoTheme.forest)
      }
    }
    .navigationDestination(item: $selectedThread) { thread in
      ChatRoomView(thread: thread) { message in
        onSendChatMessage(thread, message)
      }
    }
    .navigationDestination(item: $selectedHostContext) { context in
      HostManageView(
        trip: context.trip,
        thread: context.thread,
        onSendChatMessage: onSendChatMessage,
        onApproveApplicant: onApproveApplicant,
        onRejectApplicant: onRejectApplicant,
        onSetRecruitmentClosed: onSetRecruitmentClosed
      )
    }
    .onAppear(perform: initializeFieldsIfNeeded)
    .accessibilityIdentifier("screen.createRecruitment.\(courseID)")
  }

  private func createRecruitment() {
    guard createdTrip == nil else { return }

    let tripID = "session-trip-\(course.id)-\(UUID().uuidString)"
    let threadID = "session-chat-\(tripID)"
    let participants = Array(MockData.participants.prefix(1))
    let trip = TripRecruitment(
      id: tripID,
      courseID: course.id,
      title: course.title,
      region: course.region,
      coverMascot: course.mascot,
      hostName: "다정한 곰 1001",
      hostAvatar: "🐻",
      schedule: "\(safeScheduleDate) \(safeScheduleTime)",
      meetupPoint: safeMeetingPoint,
      price: course.duration == "2박 3일" ? "1인 189,000원" : "1인 42,000원",
      capacity: capacity,
      joined: 1,
      minimumParticipants: 3,
      status: .open,
      summary: safeRecruitmentNote,
      vibe: "새로 만든 모임이라 동행자와 속도를 맞춰 천천히 준비해요.",
      tags: course.tags,
      route: course.stops,
      participants: participants
    )
    let thread = ChatThread(
      id: threadID,
      tripTitle: trip.title,
      region: trip.region,
      mascot: trip.coverMascot,
      lastMessage: "모집이 막 만들어졌어요. 함께 갈 사람을 기다려요.",
      updatedAt: "방금",
      unreadCount: 0,
      statusSummary: "\(trip.joined)/\(trip.capacity)명 · 모집중",
      statusDetail: "최소 \(trip.minimumParticipants)명까지 \(trip.needsMoreParticipants)명 남았어요.",
      members: participants,
      messages: [
        ChatMessage(
          id: "\(threadID)-welcome",
          senderName: "모여트립",
          avatar: "🐻",
          body: "모집이 막 만들어졌어요. 함께 갈 사람을 기다려요.",
          time: "방금",
          isMine: false
        ),
        ChatMessage(
          id: "\(threadID)-note",
          senderName: "다정한 곰 1001",
          avatar: "🐻",
          body: safeRecruitmentNote,
          time: "방금",
          isMine: true
        )
      ],
      isReadOnly: false
    )

    createdTrip = trip
    createdThread = thread
    onCreated(trip, thread)
  }

  private var safeScheduleDate: String {
    scheduleDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? defaultScheduleDate
      : scheduleDate.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var safeScheduleTime: String {
    scheduleTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? defaultScheduleTime
      : scheduleTime.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var safeMeetingPoint: String {
    meetingPoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? defaultMeetingPoint
      : meetingPoint.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var safeRecruitmentNote: String {
    let trimmed = recruitmentNote.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? course.subtitle : String(trimmed.prefix(160))
  }

  private func initializeFieldsIfNeeded() {
    guard scheduleDate.isEmpty, scheduleTime.isEmpty, meetingPoint.isEmpty, recruitmentNote.isEmpty
    else { return }
    scheduleDate = defaultScheduleDate
    scheduleTime = defaultScheduleTime
    meetingPoint = defaultMeetingPoint
    capacityText = "5"
    recruitmentNote = course.subtitle
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
struct LeaveConfirmationDialog: View {
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

        Text("호스트가 나가면\n이 모임은 종료돼요")
          .font(.title3.weight(.heavy))
          .foregroundStyle(MoyeoTheme.ink)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 16)

        Text("승인된 4명에게 알림이 가고, 채팅방은 14일 동안 읽기 전용으로 유지된 후 사라져요.")
          .font(.subheadline)
          .foregroundStyle(MoyeoTheme.muted)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 10)

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
            Text("모임 종료")
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
    .accessibilityIdentifier("screen.hostLeaveConfirmation")
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
  @Environment(\.dismiss) private var dismiss

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
        Text("감포 바다 일출 모임에서\n내보내졌어요")
          .font(.title3.weight(.heavy))
          .foregroundStyle(MoyeoTheme.ink)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 18)
        Text("2026.08.22 (토) 오후 6:02 · 호스트 결정")
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
        Text("“모임 컨셉과 맞지 않는 대화가 반복되어, 남은 멤버들을 위해 함께하기 어렵다고 판단했어요.”")
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
