// swiftlint:disable file_length
import SwiftUI
import UserNotifications

struct ChangelogPerson: Identifiable {
  let mascot: String
  let name: String
  let detail: String
  let role: String
  /// 서버 동행자의 프로필 이미지 — 서버 모임일 때만 채워진다
  var profileImageURL: URL?
  /// 서버 동행자의 userId — 20-1b 내보내기(`DELETE .../members/{memberId}`)에 쓴다. 목데이터면 nil.
  var serverUserID: Int64?
  /// 이 사람이 나인지. 나에게는 프로필 카드·친구 요청·차단이 말이 되지 않아 ⋯ 를 두지 않는다.
  var isMe: Bool = false

  var id: String { name }
}

enum FriendManagementSegment: String, CaseIterable, Identifiable {
  case mine = "내 친구"
  case received = "받은 신청"
  case sent = "보낸 신청"

  var id: String { rawValue }
}

struct ChatSideMenuView: View {
  let thread: ChatThread
  @State private var route: SupportRoute?
  @State private var showsLeaveConfirmation: Bool
  /// 20-1 「모집 신고」 시트. **접수 API 가 생겼다** —
  /// `POST /api/v1/chat-rooms/{roomId}/reports` (2026-09-14 실서버 확인).
  /// 예전에는 `ReportUnsupportedDialog`("아직 받지 못해요")로 끝났다.
  @State private var showsRoomReportSheet = false
  /// 20-1a 멤버 신고 시트의 대상. 차단과 **분리**한다 (정본 §2·§3).
  @State private var reportMemberTarget: ChangelogPerson?
  /// changeLog14 — 멤버 ⋯ 가 여는 멤버 시트(20-1a 액션 → 20-1b 사유 입력)의 요청
  @State private var memberSheet: MemberSheetRequest?
  /// 참여 중인 서버 방의 읽기 응답 — 403이거나 미로그인이면 nil로 남고 목데이터가 유지된다 (20-1)
  @State private var serverContent: ServerChatRoomContent?
  /// 완료 여행의 동행자 평가 정보. `409 40915`(아직 여행 전)면 매너 표기 없이 멤버 목록만 쓴다.
  @State private var serverCompanions: [ServerTripCompanion] = []
  /// 나가기·내보내기가 서버에서 거절됐을 때의 이유. 성공은 화면 변화로 보이므로 알리지 않는다.
  @State private var actionMessage: String?
  /// 차단 확인 대상. 차단은 되돌릴 수 없어 **확인을 거친 뒤에만** 보낸다.
  @State private var blockTarget: ChangelogPerson?
  @Environment(\.dismiss) private var dismiss

  init(
    thread: ChatThread,
    startsWithLeaveConfirmation: Bool = false,
    startsWithMemberActions: Bool = false,
    startsWithMemberRemoval: Bool = false
  ) {
    self.thread = thread
    _showsLeaveConfirmation = State(initialValue: startsWithLeaveConfirmation)
    // 직접 실행 캡처(member-actions / member-remove)는 기획과 같은 대상(너구리)으로
    // 해당 단계의 시트를 연 채 시작한다.
    let initialStage: MemberSheetStage? =
      startsWithMemberRemoval ? .reason : (startsWithMemberActions ? .actions : nil)
    _memberSheet = State(
      initialValue: initialStage.flatMap { stage in
        ChatMenuBody.defaultMembers.last.map {
          MemberSheetRequest(member: $0, initialStage: stage)
        }
      })
  }

  var body: some View {
    ChatMenuBody(
      thread: thread,
      serverContent: serverContent,
      serverCompanions: serverCompanions,
      onOpenRoute: { route = $0 },
      onLeave: { showsLeaveConfirmation = true },
      onMemberMore: { memberSheet = MemberSheetRequest(member: $0, initialStage: .actions) },
      onReportRoom: { showsRoomReportSheet = true }
    )
    .task {
      guard MoyeoServerSync.isEnabled, let roomID = thread.serverRoomID, serverContent == nil else { return }
      serverContent = await ChatRoomContentAPIClient.shared.content(roomID: roomID)
      // 완료 여행 전용 API 다. `409 40915` 는 오류가 아니라 "아직 여행 전"이라 조용히 넘긴다.
      if case .companions(let companions) = await ChatRoomWriteAPIClient.shared.companions(roomID: roomID) {
        serverCompanions = companions
      }
    }
    .navigationTitle("모임 정보")
    .navigationBarTitleDisplayMode(.inline)
    .navigationDestination(item: $route) { route in
      // 서버 모임은 목데이터 스레드로 되돌아가지 않도록 이 스레드를 그대로 넘긴다
      if thread.isServerBacked, case .noticeHistory = route {
        NoticeHistoryView(thread: thread)
      } else if case .roomNotification = route, let roomID = thread.serverRoomID {
        // 20-1c — 머리말에 쓸 이름·일정은 이미 이 화면이 갖고 있다. 다시 부르지 않는다.
        RoomNotificationView(
          roomID: roomID,
          roomTitle: displayThreadTitle,
          roomSubtitle: displayThreadSchedule
        )
      } else {
        SupportDestinationView(route: route)
      }
    }
    // changeLog14 — 경고 팝업은 화면기획의 좌측 정렬 카드다. 시스템 알림창은 그 모양이 아니라
    // 31 모임 종료 경고와 같은 팝업(LeaveConfirmationDialog)을 이전 화면 위에 얹는다.
    .overlay {
      if showsLeaveConfirmation {
        // 31-1 — 호스트와 참가자는 결과가 전혀 다르다. 역할로 문구를 가른다 (정본 §6-5).
        LeaveConfirmationDialog(
          role: leaveRole,
          approvedCount: serverContent?.memberList.participantCount,
          onCancel: { showsLeaveConfirmation = false },
          onConfirm: leaveRoom
        )
      }
    }
    // 신고는 누른 자리에서 받는다 — 화면을 옮기지 않는다 (정본 §3).
    .overlay {
      if showsRoomReportSheet, let roomID = thread.serverRoomID {
        MoyeoReportSheet(
          target: .chatRoom(roomID: roomID),
          previewText: displayThreadTitle
        ) {
          showsRoomReportSheet = false
        }
      }
    }
    .overlay {
      if let target = reportMemberTarget,
        let roomID = thread.serverRoomID,
        let memberID = target.serverUserID {
        MoyeoReportSheet(
          target: .member(roomID: roomID, memberID: memberID),
          previewText: target.name
        ) {
          reportMemberTarget = nil
        }
      }
    }
    .alert(
      "모임 정보",
      isPresented: Binding<Bool>(
        get: { actionMessage != nil },
        set: { if !$0 { actionMessage = nil } }
      )
    ) {
      Button("확인", role: .cancel) { actionMessage = nil }
    } message: {
      Text(actionMessage ?? "")
    }
    // 시스템 시트는 부분 높이에서 화면 바닥에 붙지 않고 떠 보인다 —
    // 화면기획(20-1a·20-1b)처럼 바닥에 붙는 커스텀 바텀시트 오버레이로 그린다.
    .overlay {
      if let request = memberSheet {
        // 커스텀 바텀시트라 UIKit 이 모달로 쳐 주지 않는다 — 스크린리더가 시트 밖
        // (뒤 채팅방)까지 계속 읽었다. 직접 모달이라고 알려 준다 (TC ENV-007).
        ZStack(alignment: .bottom) {
          MoyeoTheme.overlayScrim
            .ignoresSafeArea()
            .onTapGesture { memberSheet = nil }
          MemberSheetFlow(
            member: request.member,
            initialStage: request.initialStage,
            isCurrentUserHost: isCurrentUserHost,
            onClose: { memberSheet = nil },
            onBlock: { member in
              memberSheet = nil
              confirmBlock(member: member)
            },
            onReport: { member in
              memberSheet = nil
              reportMemberTarget = member
            },
            onSendFriendRequest: { member in
              memberSheet = nil
              sendFriendRequest(to: member)
            },
            onRemove: { member, reason in
              memberSheet = nil
              kick(member: member, reason: reason)
            },
            onOpenProfile: { member in
              memberSheet = nil
              route = .publicProfile(profileSubject(for: member))
            }
          )
        }
        .accessibilityAddTraits(.isModal)
      }
    }
    .alert(
      "\(blockTarget?.name ?? "")님을 차단할까요?",
      isPresented: Binding(get: { blockTarget != nil }, set: { if !$0 { blockTarget = nil } })
    ) {
      Button("차단하기", role: .destructive) {
        if let target = blockTarget { block(member: target) }
        blockTarget = nil
      }
      Button("취소", role: .cancel) { blockTarget = nil }
    } message: {
      Text("차단하면 이 유저가 만들었거나 참여한 모집이 홈·탐색에서 모두 숨겨지고, 주고받은 친구 신청도 취소돼요.")
    }
    .accessibilityIdentifier("screen.chatMenu")
  }

  /// 내가 이 방의 호스트인가. **서버 멤버 목록의 `me && host` 로만 판정한다** —
  /// 못 받았으면 호스트가 아니라고 본다(참가자에게 호스트 전용 동작을 여는 편보다 낫다).
  /// 예전에는 판정 없이 「내보내기」를 모두에게 열어 두고 서버 403 으로만 막았다 (IOS-F20·F105).
  private var isCurrentUserHost: Bool {
    guard let members = serverContent?.memberList.members else { return thread.isCurrentUserHost }
    return members.contains { $0.me && $0.host }
  }

  /// 20-1c 머리말 — 서버 상세를 받았으면 그 값이 우선이다.
  private var displayThreadTitle: String {
    guard let serverContent else { return thread.tripTitle }
    return ServerTripMapper.chatThread(thread, applying: serverContent).tripTitle
  }

  private var displayThreadSchedule: String {
    guard let serverContent else { return thread.scheduleSummary }
    return ServerTripMapper.chatThread(thread, applying: serverContent).scheduleSummary
  }

  /// 31-1 — 서버 멤버 목록의 `me && host` 로만 판정한다. 못 받았으면 역할을 모르므로
  /// 기존과 같은 호스트 문구를 쓴다 (문구를 지어내지 않는다).
  private var leaveRole: LeaveConfirmationRole {
    guard let members = serverContent?.memberList.members, members.contains(where: \.me) else {
      return .host
    }
    return members.contains { $0.me && $0.host } ? .host : .member
  }

  /// 20-1 채팅방 나가기 → `DELETE /chat-rooms/{id}/members/me`.
  /// **서버 상태를 되돌릴 수 없다** — 31 확인 팝업에서 "모임 종료"를 누른 뒤에만 호출한다.
  /// 목데이터 스레드(캡처·미로그인)에서는 서버를 부르지 않고 팝업만 닫는다.
  private func leaveRoom() {
    showsLeaveConfirmation = false
    guard MoyeoServerSync.isEnabled, let roomID = thread.serverRoomID else { return }
    Task {
      do {
        _ = try await ChatRoomWriteAPIClient.shared.leaveRoom(roomID: roomID)
        // 성공하면 이 방의 사이드 메뉴를 닫는다 — 안내 팝업을 겹쳐 띄우지 않는다(기획에 없다)
        dismiss()
      } catch {
        actionMessage = error.moyeoUserMessage(fallback: "모임에서 나오지 못했어요.")
      }
    }
  }

  /// 20-1b 내보내기 → `DELETE /chat-rooms/{id}/members/{memberId}` (사유 필수).
  /// 서버 동행자가 아니면(목데이터·userId 없음) 시트만 닫는다.
  /// changeLog18 — 멤버 응답에는 닉네임 색이 없다. 색은 카드가 공개 프로필을 받은 뒤에 정해진다.
  /// 유저 id 를 모르는 멤버는 카드에 그릴 근거가 없다.
  private func profileSubject(for member: ChangelogPerson) -> ProfileCardSubject {
    guard let userID = member.serverUserID else { return .unavailable }
    return .serverUser(ProfileCardUserReference(userID: userID, nickname: member.name))
  }

  /// 20-1a 차단 → `POST /users/me/blocks/{userId}`.
  ///
  /// 신고와 **분리한다** — 신고 접수 API 가 없는 대상(멤버·채팅방)이라도 차단은 실제로 된다
  /// (정본 §3). 안드로이드 `MemberActionsSheet.onBlock` 과 같은 동작·같은 성공 문구를 쓴다:
  /// 차단 뒤 멤버 목록을 다시 읽는다. 유저 id 를 모르는 멤버(목데이터)는 보낼 대상이 없다.
  /// 차단은 **되돌릴 수 없고** 보낸 친구 신청까지 취소된다 — 확인 없이 보내지 않는다
  /// (안드로이드 교차 발견 2026-09-13). 23-1 댓글 차단은 이미 확인 단계를 거친다.
  private func confirmBlock(member: ChangelogPerson) {
    blockTarget = member
  }

  private func block(member: ChangelogPerson) {
    guard MoyeoServerSync.isEnabled, let userID = member.serverUserID else { return }
    Task {
      do {
        try await SocialAPIClient.shared.block(userID: userID)
        actionMessage = "\(member.name)님을 차단했어요."
        if let roomID = thread.serverRoomID {
          serverContent = await ChatRoomContentAPIClient.shared.content(roomID: roomID)
        }
      } catch {
        actionMessage = error.moyeoUserMessage(fallback: "차단하지 못했어요. 잠시 후 다시 시도해주세요.")
      }
    }
  }

  /// 20-1a 친구 요청 → `POST /users/me/friend-requests/{userId}`.
  ///
  /// 행이 **빈 클로저**로 남아 눌러도 아무 일이 없었다. 감사가 `Button` 모양만 보다가 놓쳤고
  /// iOS 담당이 손으로 찾아 보고했다. 성공 문구는 안드로이드 멤버 액션과 같은 것을 쓴다.
  private func sendFriendRequest(to member: ChangelogPerson) {
    // 보낼 대상을 모르면 **조용히 끝내지 않는다.** 예전에는 여기서 그냥 `return` 해서
    // 버튼을 눌러도 아무 문구가 없었다 (TC SOCIAL-014). 25 프로필 카드는 같은 조건에서
    // 버튼을 비활성으로 두는데, 이 시트는 행을 항상 그리므로 이유를 말해 준다.
    guard MoyeoServerSync.isEnabled, let userID = member.serverUserID else {
      actionMessage = "이 멤버의 정보를 아직 못 받아서 친구 신청을 보낼 수 없어요. 잠시 후 다시 시도해주세요."
      return
    }
    Task {
      do {
        try await SocialAPIClient.shared.sendFriendRequest(userID: userID)
        actionMessage = "\(member.name)님에게 친구 신청을 보냈어요."
      } catch {
        // 25 프로필 카드와 **같은 부품**으로 문구를 만든다 — 예전에는 이 화면만
        // `errorDescription` 을 써서 통신 실패 문구가 두 화면에서 달랐다.
        actionMessage = error.moyeoUserMessage(fallback: "친구 요청을 보내지 못했어요.")
      }
    }
  }

  private func kick(member: ChangelogPerson, reason: String) {
    guard
      MoyeoServerSync.isEnabled,
      let roomID = thread.serverRoomID,
      let memberID = member.serverUserID
    else {
      return
    }
    Task {
      do {
        try await ChatRoomWriteAPIClient.shared.kickMember(
          roomID: roomID, memberID: memberID, reason: reason
        )
        // 성공은 동행자 목록에서 사라지는 것으로 보인다 — 기획에 없는 안내 팝업을 만들지 않는다
        serverContent = await ChatRoomContentAPIClient.shared.content(roomID: roomID)
      } catch {
        actionMessage = error.moyeoUserMessage(fallback: "내보내지 못했어요.")
      }
    }
  }
}

/// changeLog14 — 20-1 채팅방 사이드 메뉴 본문. 오버레이(20-1a · 20-1b · 31)의 배경이
/// 빈 딤이 아니라 실제 이 화면과 같은 코드를 쓰도록 화면 껍데기와 분리했다.
struct ChatMenuBody: View {
  let thread: ChatThread
  /// 참여 중인 서버 방의 읽기 응답 — nil이면 목데이터를 유지한다
  var serverContent: ServerChatRoomContent?
  /// 완료 여행에서만 오는 동행자 평가 정보. 매너 점수의 유일한 출처다(멤버 목록에는 없다).
  var serverCompanions: [ServerTripCompanion] = []
  var onOpenRoute: (SupportRoute) -> Void = { _ in }
  var onLeave: () -> Void = {}
  var onMemberMore: (ChangelogPerson) -> Void = { _ in }
  /// 「모집 신고」 — 20-1 위에 신고 시트를 얹는다. 실제로 접수된다.
  var onReportRoom: () -> Void = {}
  @State private var notificationsEnabled = true
  /// 서버가 마지막으로 확인해 준 방별 알림 설정. nil 이면 아직 서버 값을 모르는 상태다
  /// (캡처·미로그인·목데이터 스레드는 계속 nil 이라 토글이 서버를 부르지 않는다).
  @State private var serverNotificationEnabled: Bool?
  /// OS 알림 권한이 꺼져 있는지. 꺼져 있으면 아래 스위치를 켜 두어도 기기에는 알림이 오지 않는다 —
  /// 서버 값만 보여 주면 「켜 뒀는데 왜 안 와요」가 된다 (TC NOTIF-016, `OS-NOTIFICATION-BLOCK-CANON.md`).
  /// 문구·자리는 29-2 와 같은 것(`MoyeoSystemNotificationDeniedNotice`, 스위치 **위**)을 쓴다.
  @State private var isRoomNotificationSystemDenied = false
  @Environment(\.openURL) private var openURLForNotificationSettings

  /// 서버 멤버 목록을 못 받았을 때의 자리. 목 멤버를 채우지 않는다 (NO-MOCK-CANON R1).
  static let defaultMembers: [ChangelogPerson] = []

  /// 18 모집 관리로 가는 줄을 띄울지. **서버 멤버 목록의 `me && host` 로만 판정한다** —
  /// 못 받았으면 띄우지 않는다(참가자에게 호스트 전용 화면을 보여주는 편보다 낫다).
  private var isServerHost: Bool {
    guard let members = serverContent?.memberList.members else { return false }
    return members.contains { $0.me && $0.host }
  }

  /// 서버 동행자 목록. 멤버 목록에는 매너 점수가 없어 완료 여행의 `companions` 응답에서만 채운다 —
  /// 그 값도 null 이면 매너 표기를 빼고 그린다(값을 지어내지 않는다).
  private var members: [ChangelogPerson] {
    guard let serverContent else { return Self.defaultMembers }
    let mannerRatingsByUserID = Dictionary(
      serverCompanions.map { ($0.userId, $0.mannerRating) },
      uniquingKeysWith: { first, _ in first }
    )
    return serverContent.memberList.members.map { member in
      ChangelogPerson(
        mascot: "",
        name: member.nickname,
        detail: ServerTripMapper.memberDetailText(
          completedTripCount: member.completedTripCount,
          mannerRating: mannerRatingsByUserID[member.userId] ?? nil
        ),
        role: member.host ? "호스트" : (member.me ? "나" : ""),
        profileImageURL: member.profileImageURL,
        serverUserID: member.userId,
        isMe: member.me
      )
    }
  }

  private var displayThread: ChatThread {
    guard let serverContent else { return thread }
    return ServerTripMapper.chatThread(thread, applying: serverContent)
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 6) {
          Text(displayThread.tripTitle)
            .font(MoyeoTypography.cardTitle)
            .foregroundStyle(MoyeoTheme.ink)
          if !displayThread.courseDisplayName.isEmpty {
            Label(displayThread.courseDisplayName, systemImage: "map.fill")
              .font(.caption.weight(.heavy))
              .foregroundStyle(MoyeoTheme.text700)
          }
          // 서버가 준 일정·집합 정보만 보여준다. 못 받았으면 **아무것도 그리지 않는다** —
          // 예전에는 `5/25(토) …`·`07:50 청송 …` 이라는 고정 글자를 대신 넣었다
          // (NO-MOCK-CANON R1 위반 · 실제로 없는 방의 정보를 말하는 셈이다).
          if !displayThread.scheduleSummary.isEmpty {
            Text(displayThread.scheduleSummary)
          }
          if !displayThread.meetupSummary.isEmpty {
            Text(displayThread.meetupSummary)
          }
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
              sideConditionPill(displayThread.priceDisplayText, icon: "wonsign.circle")
              sideConditionPill(deadlinePillText, icon: "clock")
              sideConditionPill(displayThread.ageRangeDisplayText, icon: "person.2")
              sideConditionPill(displayThread.genderDisplayText, icon: "person.crop.circle")
            }
          }
          // 두 버튼에 **동작이 없었다** — `{}` 라 눌러도 아무 일이 없었다 (20-1, 2026-09-09).
          // 모집 상세는 15, 여행 경로는 18-3 코스 경로로 간다. 방 id 를 모르면 갈 곳이 없어 숨긴다.
          if let serverRoomID = displayThread.serverRoomID {
            HStack(spacing: 8) {
              changelogSecondaryButton("모집 상세") {
                onOpenRoute(.tripDetail("\(ServerTripMapper.serverTripIDPrefix)\(serverRoomID)"))
              }
              changelogSecondaryButton("여행 경로") {
                // 잠금 여부는 **방의 실제 상태**가 정한다. 예전에는 `.tripConfirmed` 를 박아 넣어,
                // 모집중인 내 커스텀 코스 방도 「여행이 확정돼 경로가 잠겼어요」로 열렸다.
                onOpenRoute(.courseEdit(
                  "\(ServerTripMapper.serverTripIDPrefix)\(serverRoomID)",
                  displayThread.routeEditState
                ))
              }
            }
            .padding(.top, 6)
          }
        }
        .font(MoyeoTypography.cardMeta)
        .foregroundStyle(MoyeoTheme.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)

        sectionDivider

        ChatMenuMemberSection(
          members: members,
          capacityText: memberCapacityText,
          isCurrentUserHost: isServerHost,
          onMemberMore: onMemberMore
        )

        sectionDivider
        // 18 모집 관리 — **호스트만.** `SupportRoute.hostManage` 를 넣는 곳이 앱 전체에서
        // `UITestInitialState` 하나뿐이라, 호스트가 **신청 승인·여행 확정·집합 정보 수정**을
        // 하나도 할 수 없었다(QA HOST-001). 웹 W-05 · 안드와 같은 구멍이라 같은 자리에 둔다.
        if isServerHost, let serverRoomID = displayThread.serverRoomID {
          menuButton("모집 관리", subtitle: "신청 승인 · 여행 확정 · 집합 정보 수정", icon: "person.2.badge.gearshape") {
            onOpenRoute(.hostManage("\(ServerTripMapper.serverTripIDPrefix)\(serverRoomID)"))
          }
        }
        menuButton("공지", subtitle: noticeSubtitle, icon: "note.text") {
          onOpenRoute(.noticeHistory(thread.id))
        }
        menuButton("공유된 항목", subtitle: sharedItemsSubtitle, icon: "photo.on.rectangle") {
          onOpenRoute(.specialMessages(thread.id))
        }
        // 스위치 **위**에 놓는다 — 누르기 전에 읽혀야 한다.
        // OS 가 막고 있지 않으면 이 줄은 아예 그리지 않는다 (정본 「문구·자리」).
        if isRoomNotificationSystemDenied {
          MoyeoSystemNotificationDeniedNotice {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            openURLForNotificationSettings(url)
          }
          .padding(.horizontal, 18)
          .padding(.bottom, 4)
        }
        HStack(spacing: 12) {
          // 20-1c — 행을 누르면 이 모임 전용 알림 화면으로 간다. 예전에는 갈 곳이 없어
          // 토글 하나가 전부였다 (기획 20-1 `Row … onClick={nav.go('room-notif')}`).
          Button {
            onOpenRoute(.roomNotification(thread.id))
          } label: {
            HStack(spacing: 12) {
              Image(systemName: "bell")
              VStack(alignment: .leading, spacing: 2) {
                Text("알림 설정").font(.subheadline.weight(.bold))
                Text("이 모임의 알림만 끄기").font(.caption2).foregroundStyle(MoyeoTheme.muted)
              }
              Spacer(minLength: 0)
            }
            .foregroundStyle(MoyeoTheme.ink)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("chatMenu.roomNotification")
          Toggle("", isOn: $notificationsEnabled)
            .labelsHidden()
            .tint(MoyeoTheme.forest)
            .accessibilityIdentifier("chatMenu.notificationToggle")
            .onChange(of: notificationsEnabled) { _, enabled in
              updateNotificationSetting(enabled)
            }
        }
        .frame(minHeight: 56)
        .padding(.horizontal, 18)
        // 모집 신고는 **실제로 접수된다** — `POST /chat-rooms/{roomId}/reports`.
        // 사유 목록은 모집 전용(`GET /chat-rooms/report-reasons`)이라 멤버·피드와 다르다.
        // 멤버 한 사람을 신고하려면 20-1a 멤버 액션의 「신고하기」를 쓴다.
        // 차단은 신고와 분리해 20-1a 에서 한다(대상이 확실한 자리).
        menuButton("모집 신고", subtitle: "이 모집이 부적절하면 알려주세요", icon: "flag") {
          onReportRoom()
        }
        sectionDivider
        // 호스트에게 「대기 중인 다음 신청자가 자동으로 합류해요」라고 말하면 안 된다 —
        // 호스트가 나가면 합류가 아니라 **모임이 끝난다**. 확인 팝업은 이미 역할을 갈라
        // 말하는데(「호스트가 나가면 이 모임은 종료돼요」) 그 앞의 이 줄만 참가자 기준이라
        // 서로 반대되는 말을 했다. 웹·안드로이드는 이미 갈라 말한다 —
        // **라벨은 양쪽 모두 「채팅방 나가기」로 두고 보조 문구만 가른다.**
        menuButton(
          "채팅방 나가기",
          subtitle: isServerHost
            ? "호스트가 나가면 이 모임은 종료돼요"
            : "나가면 대기 중인 다음 신청자가 자동으로 합류해요",
          icon: "rectangle.portrait.and.arrow.right",
          isDanger: true
        ) {
          onLeave()
        }
      }
      .padding(.bottom, 28)
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .task {
      // `denied` 일 때만 안내를 띄운다 — `notDetermined` 는 아직 물어보지 않은 것이라
      // 「막혔다」고 말하면 거짓말이 된다 (29-2 와 같은 판정).
      let settings = await UNUserNotificationCenter.current().notificationSettings()
      isRoomNotificationSystemDenied = settings.authorizationStatus == .denied
    }
    .task {
      // 20-1 "이 모임의 알림만 끄기" — 서버가 방별 설정을 갖고 있다.
      // 캡처·미로그인·목데이터 스레드는 그대로 켜진 상태(기획 기준값)로 남는다.
      guard
        MoyeoServerSync.isEnabled,
        let roomID = thread.serverRoomID,
        serverNotificationEnabled == nil,
        let setting = try? await ChatRoomWriteAPIClient.shared.notificationSetting(roomID: roomID)
      else {
        return
      }
      serverNotificationEnabled = setting.enabled
      notificationsEnabled = setting.enabled
    }
  }

  /// 토글 조작을 서버에 반영한다. 서버가 거절하면 토글을 서버 값으로 되돌린다.
  /// 서버 값을 화면에 반영하느라 일어난 변화에는 다시 PUT 하지 않는다.
  private func updateNotificationSetting(_ enabled: Bool) {
    guard
      MoyeoServerSync.isEnabled,
      let roomID = thread.serverRoomID,
      let current = serverNotificationEnabled,
      current != enabled
    else {
      return
    }
    Task {
      guard
        let setting = try? await ChatRoomWriteAPIClient.shared.updateNotificationSetting(
          roomID: roomID, enabled: enabled
        )
      else {
        notificationsEnabled = current
        return
      }
      serverNotificationEnabled = setting.enabled
      notificationsEnabled = setting.enabled
    }
  }

  private var sectionDivider: some View {
    Rectangle().fill(MoyeoTheme.subtleBackground).frame(height: 8)
  }

  /// 서버 모임은 마감 정보를 못 받았으면 칩을 감춘다
  private var deadlinePillText: String {
    if !displayThread.recruitmentDeadline.isEmpty {
      return "마감 \(displayThread.recruitmentDeadline)"
    }
    return serverContent == nil ? "마감 확인" : ""
  }

  // 아래 세 줄은 **서버가 준 수만** 적는다. 예전에는 응답을 받기 전에
  // 「최대 5명 · 대기 1명」·「고정 2개 · 전체 4개」·「사진 12 · 장소 4 · 투표 2」라는
  // 그럴듯한 가짜 숫자가 떴다가 진짜 값으로 바뀌었다 — 잠깐이라도 보인 값은 본 값이다
  // (IOS-F68, NO-MOCK-CANON R1). 모르는 동안에는 **빈 문자열**이라 줄이 그려지지 않는다.

  private var memberCapacityText: String {
    guard let memberList = serverContent?.memberList else { return "" }
    return "최대 \(memberList.maxParticipants)명 · 대기 \(memberList.waitlistCount)명"
  }

  private var noticeSubtitle: String {
    guard let history = serverContent?.noticeHistory else { return "" }
    return "고정 \(history.pinnedNotices.count)개 · 전체 \(history.allNotices.count)개"
  }

  /// 공유된 항목 — 서버 메시지 유형으로 센다
  private var sharedItemsSubtitle: String {
    guard let serverContent else { return "" }
    let messages = serverContent.messages
    let photos = messages.filter { $0.type == "IMAGE" }.count
    let places = messages.filter { $0.type == "LOCATION" || $0.type == "TOURISM_CONTENT" }.count
    let polls = messages.filter { $0.type == "POLL" }.count
    return "사진 \(photos) · 장소 \(places) · 투표 \(polls)"
  }

  @ViewBuilder
  private func sideConditionPill(_ title: String, icon: String) -> some View {
    if !title.isEmpty {
      Label(title, systemImage: icon)
        .font(.caption2.weight(.heavy))
        .foregroundStyle(MoyeoTheme.text700)
        .padding(.horizontal, 9)
        .frame(height: 26)
        .background(MoyeoTheme.subtleBackground)
        .overlay(Capsule().stroke(MoyeoTheme.softLine))
        .clipShape(Capsule())
    }
  }

  private func menuButton(
    _ title: String,
    subtitle: String,
    icon: String,
    isDanger: Bool = false,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: icon).frame(width: 22)
        VStack(alignment: .leading, spacing: 2) {
          Text(title).font(.subheadline.weight(.bold))
          // 부제가 비면 줄째로 그리지 않는다 — 아직 모르는 값을 지어내지 않기 때문이다.
          if !subtitle.isEmpty {
            Text(subtitle).font(.caption2).foregroundStyle(
              isDanger ? MoyeoTheme.coral.opacity(0.75) : MoyeoTheme.muted)
          }
        }
        Spacer()
        Image(systemName: "chevron.right").font(.caption.bold())
      }
      .foregroundStyle(isDanger ? MoyeoTheme.coral : MoyeoTheme.ink)
      .frame(minHeight: 56)
      .padding(.horizontal, 18)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("chatMenu.\(title)")
  }
}

/// changeLog14 — 멤버 시트의 단계. ⋯ 는 액션 시트(20-1a)가 먼저고,
/// 내보내기를 고르면 사유 입력(20-1b)으로 전환된다.
enum MemberSheetStage {
  case actions
  case reason
}

private struct MemberSheetRequest: Identifiable {
  let member: ChangelogPerson
  let initialStage: MemberSheetStage

  var id: String { member.id }
}

/// 20-1a 멤버 액션 → 20-1b 사유 입력을 한 시트 안에서 전환한다.
/// 시트를 닫았다 다시 열면 액션 단계부터 시작한다.
/// 화면 바닥에 붙는 커스텀 바텀시트 — 시스템 시트는 부분 높이에서 떠 보인다.
private struct MemberSheetFlow: View {
  let member: ChangelogPerson
  let onClose: () -> Void
  /// 차단 확정. 대상이 확실한 자리에서만 보낸다 (정본 §3) — 서버 배선은 ChatSideMenuView가 한다.
  let onBlock: (ChangelogPerson) -> Void
  /// 20-1a 멤버 신고 → `POST /chat-rooms/{roomId}/members/{memberId}/reports`.
  /// 차단과 **다른 동작**이다 — 하나를 눌렀다고 다른 하나가 일어나지 않는다.
  let onReport: (ChangelogPerson) -> Void
  /// 20-1a 친구 요청 → `POST /users/me/friend-requests/{userId}`.
  /// 빈 클로저로 남아 있어 **눌러도 아무 일이 없었다** — 감사가 `Button` 모양만 보다가 놓쳤다.
  let onSendFriendRequest: (ChangelogPerson) -> Void
  /// 사유를 채운 내보내기 확정. 서버 배선은 20-1을 소유한 ChatSideMenuView가 한다.
  let onRemove: (ChangelogPerson, String) -> Void
  /// changeLog18 — 25 프로필 카드로의 이동도 20-1을 소유한 화면이 한다.
  let onOpenProfile: (ChangelogPerson) -> Void
  /// 내보내기 행을 그릴지. 호스트가 아니면 그리지 않는다 (기획 20-1a, IOS-F20).
  let isCurrentUserHost: Bool
  @State private var stage: MemberSheetStage

  init(
    member: ChangelogPerson,
    initialStage: MemberSheetStage,
    isCurrentUserHost: Bool = false,
    onClose: @escaping () -> Void = {},
    onBlock: @escaping (ChangelogPerson) -> Void = { _ in },
    onReport: @escaping (ChangelogPerson) -> Void = { _ in },
    onSendFriendRequest: @escaping (ChangelogPerson) -> Void = { _ in },
    onRemove: @escaping (ChangelogPerson, String) -> Void = { _, _ in },
    onOpenProfile: @escaping (ChangelogPerson) -> Void = { _ in }
  ) {
    self.member = member
    self.isCurrentUserHost = isCurrentUserHost
    self.onClose = onClose
    self.onBlock = onBlock
    self.onReport = onReport
    self.onSendFriendRequest = onSendFriendRequest
    self.onRemove = onRemove
    self.onOpenProfile = onOpenProfile
    _stage = State(initialValue: initialStage)
  }

  var body: some View {
    VStack(spacing: 0) {
      Capsule()
        .fill(MoyeoTheme.line)
        .frame(width: 40, height: 5)
        .padding(.top, 10)
      switch stage {
      case .actions:
        MemberActionsSheet(
          member: member,
          isCurrentUserHost: isCurrentUserHost,
          onBlock: { onBlock(member) },
          onReport: { onReport(member) },
          onSendFriendRequest: { onSendFriendRequest(member) },
          onRemove: { stage = .reason },
          onClose: onClose,
          onOpenProfile: { onOpenProfile(member) }
        )
      case .reason:
        MemberRemoveSheet(
          member: member,
          onClose: onClose,
          onSubmit: { onRemove(member, $0) }
        )
        .frame(maxHeight: 560)
      }
    }
    // changeLog14 — 시트 표면은 카드 표면(`card`)이다. `background`는 다크에서
    // 화면 배경과 같은 값이라 시트 경계가 사라진다. 라이트에서는 두 값이 같다.
    .moyeoBottomSheetSurface()
    .transition(.move(edge: .bottom))
  }
}

/// 20-1a 멤버 액션 시트 (changeLog14) — 멤버 요약 + 친구 요청 + 내보내기(호스트 전용).
private struct MemberActionsSheet: View {
  let member: ChangelogPerson
  /// 내보내기 행은 **호스트에게만** 그린다. 예전에는 모두에게 보이고 서버 403 으로만
  /// 막혀, 참가자가 사유까지 적고 나서야 실패했다 (IOS-F20·F105).
  let isCurrentUserHost: Bool
  /// 차단(`POST /users/me/blocks/{userId}`). 20-1 을 소유한 화면이 서버를 부르고 멤버 목록을 다시 읽는다.
  let onBlock: () -> Void
  /// 신고(`POST /chat-rooms/{roomId}/members/{memberId}/reports`). 차단과 분리돼 있다.
  let onReport: () -> Void
  /// 20-1a 친구 요청 → `POST /users/me/friend-requests/{userId}`.
  let onSendFriendRequest: () -> Void
  let onRemove: () -> Void
  let onClose: () -> Void
  /// changeLog18 — 멤버를 25 프로필 카드로 보낸다
  let onOpenProfile: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 12) {
        MascotAvatar(mascot: member.mascot, size: 44, background: MoyeoTheme.leaf)
        VStack(alignment: .leading, spacing: 3) {
          Text(member.name)
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(MoyeoTheme.ink)
          Text(member.detail)
            .font(.caption)
            .foregroundStyle(MoyeoTheme.muted)
        }
        Spacer(minLength: 0)
      }
      .padding(.bottom, 14)

      Divider().overlay(MoyeoTheme.softLine)

      // changeLog18 — 맨 위에 프로필 카드 진입을 둔다
      actionRow(
        title: "프로필 카드 보기",
        icon: "person.crop.rectangle",
        tint: MoyeoTheme.ink,
        identifier: "member-actions-profile",
        action: onOpenProfile
      )

      Divider().overlay(MoyeoTheme.softLine)

      actionRow(
        title: "친구 요청하기",
        icon: "person.crop.circle",
        tint: MoyeoTheme.ink,
        identifier: "member-actions-friend",
        action: onSendFriendRequest
      )

      Divider().overlay(MoyeoTheme.softLine)

      // 차단은 신고와 분리한다 — **대상이 확실한 이 자리**에서 바로 보낸다
      // (정본 §3, 안드로이드 `MemberActionsSheet` 의 `onBlock` 이 정본이다).
      // iOS 에는 이 경로가 없어 신고 시트가 차단의 유일한 진입점이었다.
      // 신고는 차단과 **따로** 둔다 — 예전에는 이 자리에 신고 행이 아예 없어서
      // (접수 API 가 없던 시절에 지웠다) 멤버 한 사람을 신고할 길이 없었다.
      actionRow(
        title: "신고하기",
        icon: "flag",
        tint: MoyeoTheme.dangerRed,
        identifier: "member-actions-report",
        action: onReport
      )

      Divider().overlay(MoyeoTheme.softLine)

      actionRow(
        title: "차단하기",
        icon: "hand.raised",
        tint: MoyeoTheme.dangerRed,
        identifier: "member-actions-block",
        action: onBlock
      )

      if isCurrentUserHost {
        Divider().overlay(MoyeoTheme.softLine)

        // danger 톤 — 이 행만 호스트에게 보인다 (기획 20-1a)
        actionRow(
          title: "내보내기",
          icon: "exclamationmark.triangle",
          tint: MoyeoTheme.coral,
          identifier: "member-actions-remove",
          action: onRemove
        )

        Text("내보내기는 호스트에게만 보여요.")
          .font(.caption2)
          .foregroundStyle(MoyeoTheme.text400)
          .padding(.top, 4)
          .padding(.bottom, 16)
      } else {
        Color.clear.frame(height: 12)
      }

      Button {
        onClose()
      } label: {
        Text("닫기")
          .font(.subheadline.weight(.heavy))
          .foregroundStyle(MoyeoTheme.brandText)
          .frame(maxWidth: .infinity)
          .frame(height: MoyeoTheme.ctaHeight)
          .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .stroke(MoyeoTheme.forest, lineWidth: 1)
          }
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("member-actions-close")
    }
    .padding(20)
    .padding(.top, 6)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityIdentifier("member-actions-sheet")
  }

  private func actionRow(
    title: String,
    icon: String,
    tint: Color,
    identifier: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.system(size: 17, weight: .semibold))
          .frame(width: 24)
        Text(title)
          .font(.subheadline.weight(.bold))
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .font(.caption.weight(.heavy))
          .foregroundStyle(MoyeoTheme.text400)
      }
      .foregroundStyle(tint)
      .frame(minHeight: 54)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(identifier)
  }
}

/// 20-1b 멤버 내보내기 (changeLog14) — 호스트가 사유(10자 이상)를 입력해야 내보낼 수 있다.
/// 이 사유가 그대로 상대의 13-1 내보내기 안내에 보인다.
private struct MemberRemoveSheet: View {
  let member: ChangelogPerson
  let onClose: () -> Void
  var onSubmit: (String) -> Void = { _ in }
  @State private var reason = ""

  private let policies = [
    "내보내면 이 모임에 다시 신청할 수 없어요.",
    // changeLog14 — 강퇴는 접근을 끊는 것이지 기록을 지우는 것이 아니다
    "내보내는 즉시 채팅방에서 제외돼요. 이미 남긴 대화는 채팅방에 그대로 남아요.",
    "사유는 상대에게 알림으로 전달돼요."
  ]

  /// changeLog12 진입 상태 원칙 — 사유 10자 미만이면 내보내기 비활성
  private var canSubmit: Bool {
    reason.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Text("멤버 내보내기")
          .font(.title3.weight(.heavy))
          .foregroundStyle(MoyeoTheme.ink)
        Text("내보낸 자리는 대기 큐에서 자동으로 채워져요.")
          .font(.footnote)
          .foregroundStyle(MoyeoTheme.muted)
          .padding(.top, 6)

        HStack(spacing: 12) {
          MascotAvatar(mascot: member.mascot, size: 44, background: MoyeoTheme.leaf)
          VStack(alignment: .leading, spacing: 3) {
            Text(member.name)
              .font(.subheadline.weight(.heavy))
              .foregroundStyle(MoyeoTheme.ink)
            Text(member.detail)
              .font(.caption)
              .foregroundStyle(MoyeoTheme.muted)
          }
          Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoyeoTheme.subtleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.top, 16)

        HStack(spacing: 3) {
          Text("내보내는 사유")
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(MoyeoTheme.ink)
          Text("*")
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(MoyeoTheme.coral)
        }
        .padding(.top, 18)

        VStack(alignment: .leading, spacing: 0) {
          ZStack(alignment: .topLeading) {
            if reason.isEmpty {
              Text("사유를 남겨주세요. 상대에게 알림으로 그대로 전달돼요. (10자 이상)")
                .font(.subheadline)
                .foregroundStyle(MoyeoTheme.text400)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .padding(.leading, 5)
            }
            TextEditor(text: $reason)
              .font(.subheadline)
              .foregroundStyle(MoyeoTheme.ink)
              .scrollContentBackground(.hidden)
              .frame(minHeight: 96)
              .onChange(of: reason) { _, value in
                if value.count > 200 { reason = String(value.prefix(200)) }
              }
              .accessibilityIdentifier("member-remove-reason")
          }
          Text("\(reason.count)/200")
            .font(.caption2.weight(.bold))
            .foregroundStyle(MoyeoTheme.text400)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(10)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(MoyeoTheme.line, lineWidth: 1)
        }
        .padding(.top, 10)

        VStack(alignment: .leading, spacing: 8) {
          ForEach(policies, id: \.self) { line in
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
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoyeoTheme.subtleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.top, 16)
      }
      .padding(.horizontal, 20)
      .padding(.top, 22)
    }
    .safeAreaInset(edge: .bottom) {
      HStack(spacing: 8) {
        Button("취소") { onClose() }
          .font(.subheadline.weight(.heavy))
          .foregroundStyle(MoyeoTheme.ink)
          .frame(width: 96, height: 50)
          .accessibilityIdentifier("member-remove-cancel")
        // 비활성 CTA는 회색 채움 (계정 탈퇴와 같은 관례) — 활성화되면 danger 톤
        Button {
          onSubmit(reason.trimmingCharacters(in: .whitespacesAndNewlines))
          onClose()
        } label: {
          Text("내보내기")
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(canSubmit ? .white : MoyeoTheme.muted)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(canSubmit ? MoyeoTheme.coral : MoyeoTheme.subtleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .accessibilityIdentifier("member-remove-submit")
      }
      .padding(.horizontal, 20)
      .padding(.top, 8)
      .padding(.bottom, 12)
      .background(MoyeoTheme.card)
    }
    // 시트 표면은 카드 표면이다 — 다크에서 화면 배경과 같은 값이면 경계가 사라진다.
    // 크기·딤은 감싸는 MemberSheetFlow 가 한 곳에서 정한다.
    .background(MoyeoTheme.card)
    .accessibilityIdentifier("member-remove-sheet")
  }
}

struct ChatAttachmentMenuView: View {
  /// 서버 모임에서 열렸으면 이 방으로 실제 카드를 보낸다. 목데이터 스레드·캡처면 nil 이다.
  var serverRoomID: Int64?
  /// 공지(`메모`)는 **호스트만** 올릴 수 있다. 예전에는 참가자에게도 타일이 열려
  /// 공지를 다 쓰고 나서야 서버 403 을 받았다 (IOS-F73·F105).
  ///
  /// 부모가 아는 값이 있으면 받아 쓰되, **이 화면이 직접 서버에 확인한다.** 부모가 넘겨주는
  /// 값에만 기대면, 부모가 아직 멤버 목록을 못 읽은 순간에 열린 시트가 호스트에게도
  /// 공지 타일을 감춘다 (2026-09-13 기기 확인에서 실제로 그랬다).
  var isCurrentUserHost: Bool = false
  @State private var resolvedHost: Bool?
  /// 공유가 끝나면 채팅방이 메시지를 다시 읽도록 알린다.
  var onShared: () -> Void = {}
  @Environment(\.dismiss) private var dismiss
  @Environment(\.moyeoIsOffline) private var isOffline
  @State private var opensSpecialMessages = false
  /// 20-2 타일에서 연 작성 화면 (20-2a~20-2f)
  @State private var composerKind: AttachmentKind?
  /// 작성 화면이 실제로 보냈는지. 작성 화면이 닫힐 때 이 시트도 함께 닫는다.
  @State private var didShare = false

  /// 화면기획 20-2 첨부 6종. 순서·문구는 기획 그대로다.
  enum AttachmentKind: String, CaseIterable, Identifiable, Hashable {
    case photo, place, map, poll, settlement, memo

    var id: String { rawValue }

    /// 캡처 라우트 이름 (`attach-photo` … `attach-notice`).
    /// 공지만 화면기획 번호(20-2f)와 타일 이름(`메모`)이 갈린다 — 라우트는 기획을 따른다.
    var captureRouteName: String {
      self == .memo ? "notice" : rawValue
    }

    var icon: String {
      switch self {
      case .photo: "camera.fill"
      case .place: "mappin.and.ellipse"
      case .map: "map.fill"
      case .poll: "chart.bar.xaxis"
      case .settlement: "creditcard.fill"
      case .memo: "note.text"
      }
    }

    var title: String {
      switch self {
      case .photo: "사진"
      case .place: "장소"
      case .map: "지도"
      case .poll: "투표"
      case .settlement: "정산"
      case .memo: "메모"
      }
    }

    var detail: String {
      switch self {
      case .photo: "최대 20MB · 1장씩 전송"
      case .place: "관광 정보에서 찾기"
      case .map: "만날 위치 핀 공유"
      case .poll: "2~5개 · 익명 기본"
      case .settlement: "메모용 · 송금 아님"
      case .memo: "상단 고정 공지 (호스트)"
      }
    }
  }

  /// 서버 확인이 끝났으면 그 값, 아직이면 부모가 준 값.
  private var isHost: Bool { resolvedHost ?? isCurrentUserHost }

  /// 참가자에게는 공지 타일을 그리지 않는다 — 나머지 다섯은 누구나 올릴 수 있다.
  private var items: [AttachmentKind] {
    isHost ? AttachmentKind.allCases : AttachmentKind.allCases.filter { $0 != .memo }
  }

  var body: some View {
    // 시트는 화면 바닥에 붙는다. 가운데 떠 있으면 바텀시트로 읽히지 않는다.
    VStack(alignment: .leading, spacing: 0) {
      // 시트 위 빈 자리를 누르면 닫힌다. 예전에는 하단 「닫기」 버튼 하나뿐이라
      // 딤을 눌러도·아래로 쓸어내려도 닫히지 않았다 (TC ATTACH-007).
      // 같은 파일의 멤버 시트는 이미 딤 탭으로 닫힌다(`onTapGesture { memberSheet = nil }`).
      Color.clear
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .accessibilityHidden(true)
      sheet
        // 바텀시트를 아래로 쓸어내려도 닫힌다 — iOS 사용자가 먼저 시도하는 동작이다.
        .gesture(
          DragGesture(minimumDistance: 24)
            .onEnded { value in
              guard value.translation.height > 60 else { return }
              dismiss()
            }
        )
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    // changeLog14 — 바텀시트 뒤에는 채팅 버블 실루엣이 아니라 실제 채팅방 본문을 깐다.
    // 빈 딤을 쓰면 라이트 모드에서 흰 화면으로 비어 보인다.
    .background(ChatRoomOverlayBackdrop())
    .toolbar(.hidden, for: .navigationBar)
    .navigationDestination(isPresented: $opensSpecialMessages) {
      SpecialMessageCardsView(roomID: serverRoomID)
    }
    // 20-2 타일 → 20-2a~20-2f 작성 화면. 정본 ATTACH-COMPOSER-CANON.md R1.
    .navigationDestination(item: $composerKind) { kind in
      if let serverRoomID {
        // 작성 화면은 성공하면 **스스로 닫는다**(IOS-F71). 그때 이 시트도 같이 닫아
        // 사용자가 채팅방으로 돌아오게 한다 — 여기서 바로 `dismiss()` 를 부르면
        // 위에 쌓인 작성 화면 때문에 먹힌다.
        AttachComposerDestination(kind: kind, roomID: serverRoomID) {
          onShared()
          didShare = true
        }
      }
    }
    .onChange(of: composerKind) { _, kind in
      guard kind == nil, didShare else { return }
      dismiss()
    }
    .task {
      guard resolvedHost == nil, MoyeoServerSync.isEnabled, let serverRoomID else { return }
      guard let members = try? await ChatRoomContentAPIClient.shared.members(roomID: serverRoomID)
      else { return }
      resolvedHost = members.members.contains { $0.me && $0.host }
    }
    .accessibilityIdentifier("screen.chatAttach")
  }

  private var sheet: some View {
    VStack(alignment: .leading, spacing: 0) {
      Capsule()
        .fill(MoyeoTheme.softLine)
        .frame(width: 36, height: 4)
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
      Text("무엇을 공유할까요?")
        .font(MoyeoTypography.sectionTitle)
        .padding(.top, 18)
      Text(isOffline ? "연결되면 첨부 메뉴를 사용할 수 있어요." : "일반 메시지와 달리 카드로 크게 보여요.")
        .font(MoyeoTypography.cardMeta)
        .foregroundStyle(MoyeoTheme.muted)
        .padding(.top, 4)
      LazyVGrid(
        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10
      ) {
        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
          Button {
            selectAttachment(item)
          } label: {
            VStack(spacing: 6) {
              Image(systemName: item.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isOffline ? MoyeoTheme.text400 : MoyeoTheme.forest)
                .frame(width: 44, height: 44)
                .background(MoyeoTheme.leaf)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
              Text(item.title).font(.caption.weight(.bold)).foregroundStyle(MoyeoTheme.ink)
              Text(item.detail)
                .font(.system(size: 9.5))
                .foregroundStyle(MoyeoTheme.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 106)
            .background(MoyeoTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(MoyeoTheme.softLine))
          }
          .buttonStyle(.plain)
          .disabled(isOffline)
          .accessibilityIdentifier("chatAttach.item.\(index)")
        }
      }
      .padding(.top, 16)
      // 「닫기」는 글자만이다 — 기획·웹·안드로이드 셋 다 배경 없는 ghost 버튼이다.
      // 회색 판을 깔면 iOS 만 시트 안에 버튼이 하나 더 있는 것처럼 보였다 (20-2).
      Button { dismiss() } label: {
        Text("닫기")
          .font(.subheadline.weight(.bold))
          .foregroundStyle(MoyeoTheme.ink)
          .frame(maxWidth: .infinity, minHeight: 48)
      }
      .buttonStyle(.plain)
      .padding(.top, 16)
      .accessibilityIdentifier("chatAttach.close")
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 28)
    .padding(.top, 2)
    .frame(maxWidth: .infinity)
    // 아래쪽 두 모서리는 **직각**이다 — 시트가 화면 바닥에 붙어 있으니 둥글릴 이유가 없다.
    // 예전에는 네 모서리를 다 24 로 둥글려 iOS 만 시트가 떠 있는 것처럼 보였다
    // (기획 `borderRadius: '24px 24px 0 0'` · 웹·안드로이드도 위만 둥글다, 20-2 사용자 지적).
    .background(
      MoyeoTheme.card
        .clipShape(
          UnevenRoundedRectangle(
            topLeadingRadius: 24,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 24,
            style: .continuous
          )
        )
        .ignoresSafeArea(edges: .bottom)
    )
  }

  /// 20-2 타일 선택 → 20-2a~20-2f 작성 화면 (정본 ATTACH-COMPOSER-CANON.md).
  /// 서버 방이 아니면(목데이터 스레드·캡처) 보낼 곳이 없어 기존처럼 21 특수 메시지 견본으로 간다.
  private func selectAttachment(_ kind: AttachmentKind) {
    guard serverRoomID != nil, MoyeoServerSync.isEnabled else {
      opensSpecialMessages = true
      return
    }
    composerKind = kind
  }
}

struct FriendsManagementView: View {
  /// 캡처 진입(27-2a)은 친구 정리 시트를 연 채로 시작한다.
  var startsWithFriendManage = false
  @State private var segment: FriendManagementSegment = .mine
  /// 실서버 친구 데이터 — 친구 API가 성공했을 때만 채워진다 (nil = 아직 못 받음)
  @State private var serverFriends: ServerFriendList?
  @State private var serverReceived: ServerFriendRequestList?
  @State private var serverSent: ServerFriendRequestList?
  @State private var resolvedRequestIDs = Set<Int64>()
  /// 수락·거절·취소 실패를 적는 자리. 예전에는 `catch { }` 로 사라졌다 (IOS-F52).
  @State private var requestActionMessage: String?
  /// changeLog18 — 친구를 눌러 여는 25 프로필 카드
  @State private var profileRoute: SupportRoute?
  /// 27-2a 친구 정리 시트. `내 친구` 행의 ⋯ 가 연다 — 지금까지 그 자리에 아무 동작이 없었다.
  @State private var manageFriend: ServerFriend?
  // 「닉네임으로 찾기」 검색창은 **없다** (BE-05 · 2026-09-14 결정 B안).
  // 서버에 사용자 검색 API 를 만들지 않기로 했다 — 친구는 도감에서만 신청한다.
  // 예전 검색창은 **이미 친구인 목록만** 좁혀서 모르는 사람을 아무리 쳐도 늘 0건이었다.
  // 동작하는 것처럼 보이는데 결과가 없는 것이 제일 나쁜 상태라 들어냈고,
  // 대신 친구를 어떻게 만드는지 안내 한 줄을 목록 위에 둔다.

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        ForEach(FriendManagementSegment.allCases) { item in
          Button {
            segment = item
          } label: {
            VStack(spacing: 8) {
              Text("\(item.rawValue) \(count(for: item))")
                .font(MoyeoTypography.tab)
                .foregroundStyle(segment == item ? MoyeoTheme.forest : MoyeoTheme.muted)
              Rectangle().fill(segment == item ? MoyeoTheme.forest : .clear).frame(height: 2)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("friends.segment.\(item.id)")
        }
      }
      // 검색창을 들어낸 자리 — 친구를 어떻게 만드는지 한 줄로 알려 준다.
      // 이 안내가 없으면 사용자는 친구를 늘릴 길을 아예 찾지 못한다.
      Text("함께 여행한 사람은 친구 도감에서 신청할 수 있어요.")
        .font(.caption)
        .foregroundStyle(MoyeoTheme.muted)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .accessibilityIdentifier("friends.howToAdd")
      ScrollView {
        VStack(spacing: 0) {
          if segment == .received {
            Text("거절해도 상대방에게는 알려지지 않아요.")
              .font(.caption)
              .foregroundStyle(MoyeoTheme.muted)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 10)
          }
          if let requestActionMessage {
            Text(requestActionMessage)
              .font(.caption.weight(.semibold))
              .foregroundStyle(MoyeoTheme.dangerRed)
              .fixedSize(horizontal: false, vertical: true)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 10)
              .accessibilityIdentifier("friends.actionError")
          }
          // 27-2 는 서버 친구 목록이 전부다 — 못 받으면 빈 상태만 남는다 (NO-MOCK-CANON R1)
          serverRows
          HStack(alignment: .top, spacing: 9) {
            Image(systemName: "bookmark.fill")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(MoyeoTheme.onLeaf)
            VStack(alignment: .leading, spacing: 6) {
              Text("함께 여행한 친구는 친구가 아니어도 도감에 남아요. 친구 신청은 피드를 구독하고 싶을 때만 하면 돼요.")
                .font(.caption)
                .foregroundStyle(MoyeoTheme.onLeaf)
                .fixedSize(horizontal: false, vertical: true)
              Text("도감 열어보기 →")
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.onLeaf)
            }
            Spacer(minLength: 0)
          }
          .padding(13)
          .background(MoyeoTheme.leaf)
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.forest.opacity(0.35)))
          .accessibilityIdentifier("friends.dexNotice")
            .padding(.top, 16)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 28)
      }
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .navigationTitle("친구 관리")
    .navigationBarTitleDisplayMode(.inline)
    .navigationDestination(item: $profileRoute) { route in
      SupportDestinationView(route: route)
    }
    // 27-2a — 시스템 시트는 바닥에 붙지 않는다. 20-1a 와 같은 커스텀 바텀시트로 그린다.
    .overlay {
      if let friend = manageFriend {
        FriendManageSheet(
          friend: friend,
          onOpenProfile: {
            manageFriend = nil
            profileRoute = .publicProfile(subject(for: friend.user))
          },
          onRemoved: {
            manageFriend = nil
            Task { await refreshServerFriends() }
          },
          onClose: { manageFriend = nil }
        )
      }
    }
    .task {
      await loadServerFriends()
      if startsWithFriendManage { manageFriend = serverFriends?.friends.first }
    }
    .accessibilityIdentifier("screen.friends")
  }

  /// 친구 목록 응답에는 닉네임 색이 없다 — 색은 카드가 공개 프로필을 받은 뒤에 정해진다.
  private func subject(for user: ServerFriendUser) -> ProfileCardSubject {
    .serverUser(
      ProfileCardUserReference(
        userID: user.userId,
        nickname: user.nickname,
        profileImageUrl: user.profileImageUrl,
        introduction: user.introduction
      )
    )
  }

  /// 탭의 개수는 서버 응답만 센다 — 못 받았으면 0 이다.
  /// 이 화면에서 방금 처리한 건은 **빼고** 센다. 서버를 다시 읽기 전까지의 짧은 사이에도
  /// 숫자와 목록이 어긋나면 안 된다 (IOS-F11).
  private func count(for segment: FriendManagementSegment) -> Int {
    switch segment {
    case .mine:
      return serverFriends?.totalCount ?? 0
    case .received:
      return (serverReceived?.requests ?? []).count { !resolvedRequestIDs.contains($0.requestId) }
    case .sent:
      return (serverSent?.requests ?? []).count { !resolvedRequestIDs.contains($0.requestId) }
    }
  }

  // MARK: - 실서버 친구 관리

  private func loadServerFriends() async {
    guard MoyeoServerSync.isEnabled, serverFriends == nil else { return }
    guard let friends = try? await SocialAPIClient.shared.friends() else { return }
    serverReceived = try? await SocialAPIClient.shared.receivedFriendRequests()
    serverSent = try? await SocialAPIClient.shared.sentFriendRequests()
    serverFriends = friends
  }

  /// 27-2a 친구를 끊은 뒤 목록을 서버에서 다시 읽는다 — 화면에서 지워 넣지 않는다.
  private func refreshServerFriends() async {
    guard MoyeoServerSync.isEnabled else { return }
    guard let friends = try? await SocialAPIClient.shared.friends() else { return }
    serverFriends = friends
  }

  @ViewBuilder
  private var serverRows: some View {
    switch segment {
    case .mine:
      let friends = serverFriends?.friends ?? []
      if !friends.isEmpty {
        ForEach(friends) { friend in
          ServerFriendRow(
            user: friend.user,
            detail: friend.lastActive.map { "\($0) 접속" } ?? "",
            onOpenProfile: { profileRoute = .publicProfile(subject(for: friend.user)) },
            trailing: {
              // 27-2a — ⋯ 가 친구 정리 시트를 연다 (예전에는 눌러도 아무 일이 없었다)
              Button {
                manageFriend = friend
              } label: {
                Image(systemName: "ellipsis")
                  .font(.system(size: 15, weight: .bold))
                  .foregroundStyle(MoyeoTheme.muted)
                  .frame(width: 44, height: 44)
                  .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .accessibilityLabel("\(friend.user.nickname) 더보기")
              .accessibilityIdentifier("friends.manage.\(friend.user.userId)")
            }
          )
        }
      } else {
        serverEmptyRow("아직 친구가 없어요")
      }
    case .received:
      let requests = (serverReceived?.requests ?? []).filter { !resolvedRequestIDs.contains($0.requestId) }
      if requests.isEmpty {
        serverEmptyRow("받은 친구 신청이 없어요")
      } else {
        ForEach(requests) { request in
          ServerFriendRow(
            user: request.user,
            detail: requestedAtText(request.requestedAt),
            onOpenProfile: { profileRoute = .publicProfile(subject(for: request.user)) },
            trailing: {
              HStack(spacing: 8) {
                Button("거절") {
                  resolveRequest(request.requestId, accept: false)
                }
                .buttonStyle(.bordered).controlSize(.small)
                Button("수락") {
                  resolveRequest(request.requestId, accept: true)
                }
                .buttonStyle(.borderedProminent).controlSize(.small).tint(MoyeoTheme.forest)
              }
            }
          )
        }
      }
    case .sent:
      let requests = (serverSent?.requests ?? []).filter { !resolvedRequestIDs.contains($0.requestId) }
      if requests.isEmpty {
        serverEmptyRow("보낸 친구 신청이 없어요")
      } else {
        ForEach(requests) { request in
          ServerFriendRow(
            user: request.user,
            detail: requestedAtText(request.requestedAt),
            onOpenProfile: { profileRoute = .publicProfile(subject(for: request.user)) },
            trailing: {
              // 「요청 중」은 상태이지 동작이 아니었다 — 보낸 신청을 **취소할 길**을 준다.
              Button("취소") { cancelSentRequest(request.requestId) }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier("friends.sent.cancel.\(request.requestId)")
            }
          )
        }
      }
    }
  }

  /// 받은 신청을 수락·거절한다.
  ///
  /// 예전에는 `catch { }` 가 **비어 있어** 실패가 조용히 사라졌다 — 누른 사람은 처리된 줄
  /// 알았다 (IOS-F52). 그리고 성공해도 `resolvedRequestIDs` 로 행만 감춰서, 탭의 숫자는
  /// `serverReceived?.requests.count` 그대로라 「받은 신청 1」이 계속 남았다 (IOS-F11).
  private func resolveRequest(_ requestID: Int64, accept: Bool) {
    Task {
      do {
        if accept {
          try await SocialAPIClient.shared.acceptFriendRequest(requestID: requestID)
        } else {
          try await SocialAPIClient.shared.rejectFriendRequest(requestID: requestID)
        }
      } catch {
        requestActionMessage = error.moyeoUserMessage(
          fallback: accept ? "수락하지 못했어요. 잠시 후 다시 시도해주세요." : "거절하지 못했어요. 잠시 후 다시 시도해주세요."
        )
        return
      }
      requestActionMessage = nil
      resolvedRequestIDs.insert(requestID)
      // 행만 감추지 않고 **서버에서 다시 읽는다** — 탭 숫자가 같이 맞아야 한다.
      await reloadServerFriends()
    }
  }

  /// 보낸 신청 취소 — `DELETE /users/me/friend-requests/{requestId}`.
  /// API 는 오래 있었는데 호출부가 0곳이라 「요청 중」 배지만 떠 있었다 (IOS-F51).
  private func cancelSentRequest(_ requestID: Int64) {
    Task {
      do {
        try await SocialAPIClient.shared.cancelFriendRequest(requestID: requestID)
      } catch {
        requestActionMessage = error.moyeoUserMessage(
          fallback: "신청을 취소하지 못했어요. 잠시 후 다시 시도해주세요."
        )
        return
      }
      requestActionMessage = nil
      resolvedRequestIDs.insert(requestID)
      await reloadServerFriends()
    }
  }

  /// 친구·받은·보낸을 **한꺼번에** 다시 읽는다. 셋이 서로 옮겨 다니는 값이라 따로 읽으면 어긋난다.
  private func reloadServerFriends() async {
    guard MoyeoServerSync.isEnabled else { return }
    if let friends = try? await SocialAPIClient.shared.friends() { serverFriends = friends }
    if let received = try? await SocialAPIClient.shared.receivedFriendRequests() {
      serverReceived = received
    }
    if let sent = try? await SocialAPIClient.shared.sentFriendRequests() { serverSent = sent }
    resolvedRequestIDs.removeAll()
  }

  /// "2026-09-01T12:00:00" → "2026.09.01 신청"
  private func requestedAtText(_ requestedAt: String) -> String {
    guard let datePart = requestedAt.split(separator: "T").first else { return requestedAt }
    return "\(datePart.replacingOccurrences(of: "-", with: ".")) 신청"
  }

  private func serverEmptyRow(_ message: String) -> some View {
    Text(message)
      .font(.caption)
      .foregroundStyle(MoyeoTheme.muted)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 18)
  }
}

/// 실서버 친구/신청 한 행 — 서버가 준 값(닉네임·프로필 이미지·소개)만 그린다
private struct ServerFriendRow<Trailing: View>: View {
  let user: ServerFriendUser
  let detail: String
  /// changeLog18 — 친구를 누르면 25 프로필 카드로 간다
  var onOpenProfile: (() -> Void)?
  @ViewBuilder var trailing: () -> Trailing

  var body: some View {
    HStack(spacing: 12) {
      HStack(spacing: 12) {
        CachedRemoteImage(url: user.profileImageURL) { image in
          image
            .resizable()
            .scaledToFill()
        } placeholder: {
          MoyeoTheme.leaf
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        VStack(alignment: .leading, spacing: 3) {
          Text(user.nickname).font(.subheadline.weight(.bold))
          if !detail.isEmpty {
            Text(detail).font(.caption2).foregroundStyle(MoyeoTheme.muted)
          } else if let introduction = user.introduction, !introduction.isEmpty {
            Text(introduction).font(.caption2).foregroundStyle(MoyeoTheme.muted).lineLimit(1)
          }
        }
      }
      .contentShape(Rectangle())
      .onTapGesture {
        onOpenProfile?()
      }
      Spacer()
      trailing()
    }
    .frame(minHeight: 68)
  }
}

/// 27-1 저장 한 건. 서버로 보낼 값만 담는다.
struct TripCompanionReviewDraft {
  let userID: Int64
  let score: Int
  let review: String?
}

/// 27-1 동행자 목록의 상태. 목록이 없을 때 무엇을 그릴지 정한다 —
/// 상태 없이 목록만 그리면 "동행자가 없는 것"과 "못 불러온 것"을 구분할 수 없다(웹과 같은 판단).
enum TripCompanionsState {
  case loading
  case ready
  case empty
  case failed
}

struct TripMessageView: View {
  @Environment(\.dismiss) private var dismiss
  /// 동행자는 **서버 응답에서만** 온다 — 예시 동행자에게 한 줄을 남기게 하지 않는다 (NO-MOCK R1).
  /// 근거는 `GET /api/v1/chat-rooms/{roomId}/companions` (완료된 여행 전용).
  @State private var companions: [ServerTripCompanion] = []
  @State private var companionsState: TripCompanionsState = .loading
  @State private var draftByUserID: [Int64: String] = [:]
  /// 27-1 매너 점수(별 1~5). `ReviewTravelCompanionRequest.mannerScore` 는 **필수**인데
  /// 이 입력이 한 픽셀도 없어서 앱 곳곳의 `매너 4.7` 을 만드는 사람이 아무도 없었다 (정본 §6-2).
  @State private var scoreByUserID: [Int64: Int] = [:]
  @State private var route: SupportRoute?
  /// 평가 대상 모임. 27-4 코스 평가도 같은 방을 쓴다.
  @State private var endedRoomID: Int64?
  @State private var showsCourseRating = false
  @State private var isSaving = false
  @State private var failureMessage: String?
  private let presets = ["덕분에 즐거웠어요", "사진 고마워요!", "다음에도 잘 부탁드려요"]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("함께 걸어준 친구들,\n어떠셨어요?")
          .font(MoyeoTypography.screenTitle)
          .foregroundStyle(MoyeoTheme.ink)
        Text("매너 점수는 다음 모임의 호스트가 보고, 한 줄 메시지는 상대방의 도감 카드 뒷면에 적혀요.")
          .font(.subheadline)
          .foregroundStyle(MoyeoTheme.muted)
          .fixedSize(horizontal: false, vertical: true)
        if companionsState == .ready {
          ForEach(companions) { companion in messageCard(companion) }
        } else {
          companionsPlaceholder
        }
        infoCard("메시지를 남기면 서로의 도감 카드가 완성돼요. 가끔 도감을 펼쳐 보면 그날의 여행이 다시 떠올라요.")
        // 27-4 코스 평가 — 14 코스 상세가 보여주는 평점을 만드는 **유일한** 자리다.
        // 여기서 권하지 않으면 아무도 평가하지 않아 평점이 영원히 비어 있다 (정본 §6-4).
        actionCard("다녀온 코스는 어떠셨어요? 코스 평가하기", icon: "star.fill") {
          showsCourseRating = true
        }
        // 예전에는 `{}` — **눌러도 아무 일이 없었다**. 27-1 에서 피드 글쓰기를 권하는
        // 유일한 자리인데 갈 곳이 없었다 (죽은 버튼 감사 2026-09-09).
        actionCard("피드에 오늘의 여행 기록 남기기", icon: "doc.text.image") {
          route = .feedWrite
        }
        actionCard("다녀온 코스를 다른 여행자에게 공개하기", icon: "map.fill") {
          route = .coursePublish
        }
      }
      .padding(18)
      .padding(.bottom, 12)
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .navigationTitle("여행 마무리")
    .navigationBarTitleDisplayMode(.inline)
    .safeAreaInset(edge: .bottom) {
      HStack(spacing: 8) {
        Button("나중에") { dismiss() }
          .font(.subheadline.weight(.bold))
          .foregroundStyle(MoyeoTheme.ink)
          .frame(width: 84, height: 50)
          .accessibilityIdentifier("tripMessage.later")
        Button {
          saveReviews()
        } label: {
          Text("메시지 남기고 도감 보기")
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: MoyeoTheme.ctaHeight)
            .background(MoyeoTheme.forest)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
        .accessibilityIdentifier("tripMessage.saveAndOpenDex")
      }
      .padding(.horizontal, 18)
      .padding(.top, 8)
      .padding(.bottom, 12)
      .background(MoyeoTheme.card)
      .overlay(alignment: .top) { Rectangle().fill(MoyeoTheme.softLine).frame(height: 1) }
    }
    .navigationDestination(item: $route) { SupportDestinationView(route: $0) }
    .navigationDestination(isPresented: $showsCourseRating) {
      CourseRatingView(roomID: endedRoomID)
    }
    .alert(
      "여행 마무리",
      isPresented: Binding(
        get: { failureMessage != nil },
        set: { if !$0 { failureMessage = nil } }
      )
    ) {
      Button("확인", role: .cancel) { failureMessage = nil }
    } message: {
      Text(failureMessage ?? "")
    }
    .task { await loadCompanions() }
    .accessibilityIdentifier("screen.tripMessage")
  }

  /// 27-1 저장 → `PUT /chat-rooms/{id}/companions/{userId}/review`.
  /// `mannerScore` 는 서버 필수값이라 **별점을 매긴 동행자만** 보낸다 —
  /// 안 매긴 사람에게 기본 점수를 지어내 보내지 않는다.
  private func saveReviews() {
    guard MoyeoServerSync.isEnabled, let roomID = endedRoomID else {
      dismiss()
      return
    }
    let reviews: [TripCompanionReviewDraft] = companions.compactMap { companion in
      guard let score = scoreByUserID[companion.userId], score > 0 else { return nil }
      let draft = (draftByUserID[companion.userId] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      return TripCompanionReviewDraft(
        userID: companion.userId, score: score, review: draft.isEmpty ? nil : draft
      )
    }
    // 점수 없이 **한 줄만** 써 둔 사람이 있으면 조용히 버리지 않는다.
    // 서버는 `mannerScore` 를 필수(1~5)로 받아 점수 없는 평가를 아예 받지 못하는데,
    // 예전에는 그런 사람을 그냥 걸러 내고 화면만 도감으로 넘어가서 **쓴 글이 사라졌다**
    // (TC AFTER-005). 무엇이 빠졌는지 말하고 그 자리에 머문다.
    let writtenWithoutScore = companions.filter { companion in
      let draft = (draftByUserID[companion.userId] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      let score = scoreByUserID[companion.userId] ?? 0
      return !draft.isEmpty && score <= 0
    }
    if !writtenWithoutScore.isEmpty {
      let names = writtenWithoutScore.map(\.nickname).joined(separator: ", ")
      failureMessage = "\(names)님에게 남길 한 줄이 있는데 매너 점수를 아직 안 매겼어요. "
        + "점수를 매겨야 함께 저장돼요."
      return
    }
    guard !reviews.isEmpty else {
      dismiss()
      return
    }
    guard !isSaving else { return }
    isSaving = true
    Task {
      var failed = false
      for review in reviews {
        do {
          _ = try await ChatRoomWriteAPIClient.shared.reviewCompanion(
            roomID: roomID,
            companionUserID: review.userID,
            mannerScore: review.score,
            oneLineReview: review.review
          )
        } catch {
          failed = true
          failureMessage = error.moyeoUserMessage(fallback: "평가를 남기지 못했어요.")
        }
      }
      isSaving = false
      if !failed { dismiss() }
    }
  }

  /// 완료된 여행이 없거나 동행자가 없으면 안드로이드와 **글자 그대로 같은** 문구를 남긴다.
  /// 로딩·실패 문구는 §2 정본을 그대로 쓴다 — 새 문구를 만들지 않는다.
  @ViewBuilder
  private var companionsPlaceholder: some View {
    switch companionsState {
    case .loading:
      MoyeoEmptyStateView(
        message: MoyeoEmptyText.loading,
        accessibilityIdentifier: "tripMessage.companionsState"
      )
    case .failed:
      MoyeoEmptyStateView(
        message: MoyeoEmptyText.loadFailed,
        onRetry: { Task { await reloadCompanions() } },
        accessibilityIdentifier: "tripMessage.companionsState"
      )
    default:
      MoyeoEmptyStateView(
        message: "아직 함께 여행한 친구가 없어요.",
        accessibilityIdentifier: "tripMessage.companionsState"
      )
    }
  }

  /// 서버가 준 한 줄(`oneLineReview`)이 기준이다. 남긴 적이 없으면 빈 입력으로 시작한다.
  private func loadCompanions() async {
    guard companionsState == .loading else { return }
    await reloadCompanions()
  }

  private func reloadCompanions() async {
    companionsState = .loading
    guard MoyeoServerSync.isEnabled else {
      companionsState = .empty
      return
    }
    // 27-1 은 다녀온 여행의 화면이다 — 안드로이드와 같이 가장 최근에 끝난 모임을 기준으로 삼는다.
    guard let rooms = try? await ChatRoomAPIClient.shared.myRooms() else {
      companionsState = .failed
      return
    }
    // 끝난 여행이 없으면 동행자도 없다 — 실패가 아니라 빈 상태다.
    //
    // **불발(CANCELLED)된 방도 `ended` 다.** 그런 방에 `companions` 를 부르면 서버가
    // `409 40915`("아직 완료되지 않은 여행입니다")를 주고, 화면은 실제로 다녀온 여행이
    // 있는데도 빈 상태로 떨어진다 — 실서버에서 확인했다(방 41). 확정된 여행을 먼저 고른다.
    guard let endedRoom = ServerTripMapper.latestCompletedRoom(in: rooms) else {
      companionsState = .empty
      return
    }
    endedRoomID = endedRoom.roomId
    switch await ChatRoomWriteAPIClient.shared.companions(roomID: endedRoom.roomId) {
    case .companions(let list):
      companions = list
      draftByUserID = Dictionary(
        list.map { ($0.userId, $0.oneLineReview ?? "") },
        uniquingKeysWith: { _, latest in latest }
      )
      // 내가 이미 남긴 점수(`mannerScore`)로 시작한다 — 남들이 준 평균(`mannerRating`)이 아니다.
      // 미평가면 0(아직 안 매김)이고, 기본 점수를 채워 넣지 않는다.
      scoreByUserID = Dictionary(
        list.map { ($0.userId, $0.mannerScore ?? 0) },
        uniquingKeysWith: { _, latest in latest }
      )
      companionsState = list.isEmpty ? .empty : .ready
    // `409 40915` 는 오류가 아니라 "아직 여행 전"이다 — 동행자가 없는 것으로 그린다.
    case .notCompleted:
      companionsState = .empty
    case .unavailable:
      companionsState = .failed
    }
  }

  private func messageCard(_ companion: ServerTripCompanion) -> some View {
    let draft = draftByUserID[companion.userId] ?? ""
    let score = scoreByUserID[companion.userId] ?? 0
    let done = companion.reviewed && draft == (companion.oneLineReview ?? "")
    return VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        CompanionAvatar(companion: companion)
        VStack(alignment: .leading, spacing: 2) {
          Text(companion.nickname).font(.subheadline.weight(.bold))
          Text(companion.reviewed ? "메시지를 남겼어요" : "아직 안 남겼어요")
            .font(.caption2).foregroundStyle(MoyeoTheme.muted)
        }
        Spacer()
        if done { Image(systemName: "checkmark.circle.fill").foregroundStyle(MoyeoTheme.forest) }
      }
      // 매너 점수 — `ReviewTravelCompanionRequest.mannerScore` (1~5, 필수).
      // 서버가 정수만 받으므로 반 개짜리 별을 두지 않는다.
      // ENV-009 — 별 하나의 누를 넓이가 44x44 로 넓어져 라벨·안내와 한 줄에 못 선다.
      // 별 그림 크기는 그대로(19pt) 두고 줄만 둘로 나눈다.
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 8) {
          Text("매너 점수")
            .font(.caption.weight(.heavy))
            .foregroundStyle(MoyeoTheme.text700)
          Spacer(minLength: 0)
          Text(score > 0 ? "\(score)점" : "눌러서 매겨요")
            .font(MoyeoTypography.tinyMeta)
            .monospacedDigit()
            .foregroundStyle(MoyeoTheme.text400)
        }
        MoyeoStarRatingInput(
          score: Binding(
            get: { scoreByUserID[companion.userId] ?? 0 },
            set: { scoreByUserID[companion.userId] = $0 }
          ),
          size: 19,
          spacing: 2,
          identifier: "tripMessage.manner.\(companion.userId)"
        )
      }
      TextField(
        "한 줄 메시지를 남겨주세요 (최대 40자)",
        text: Binding(
          get: { draftByUserID[companion.userId] ?? "" },
          set: { draftByUserID[companion.userId] = String($0.prefix(40)) }
        )
      )
      .padding(12).frame(minHeight: 46).background(MoyeoTheme.subtleBackground).clipShape(
        RoundedRectangle(cornerRadius: 10))
      // 40자에서 **입력이 그냥 멈췄다** — 세는 곳이 없어 왜 안 써지는지 알 수 없었다 (IOS-F82).
      // 평소에 숫자가 떠 있으면 시끄러우니 채팅 입력칸과 같이 한도에 가까울 때만 띄운다.
      if draft.count >= 30 {
        Text(verbatim: "\(draft.count)/40")
          .font(MoyeoTypography.tinyMeta)
          .monospacedDigit()
          .foregroundStyle(draft.count >= 40 ? MoyeoTheme.warningText : MoyeoTheme.text400)
          .frame(maxWidth: .infinity, alignment: .trailing)
          .accessibilityIdentifier("tripMessage.counter.\(companion.userId)")
      }
      if draft.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack {
            ForEach(presets, id: \.self) { preset in
              Button(preset) { draftByUserID[companion.userId] = preset }
                .buttonStyle(.bordered).controlSize(.small)
            }
          }
        }
      }
    }
    .padding(14)
    .background(done ? MoyeoTheme.leaf : MoyeoTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .overlay(
      RoundedRectangle(cornerRadius: 14).stroke(
        done ? MoyeoTheme.forest.opacity(0.3) : MoyeoTheme.softLine))
  }
}

/// 동행자 아바타. 서버 프로필 이미지가 있으면 그것을, 없으면 닉네임에서 계산한 동물 이모지를 쓴다.
/// 표는 `MoyeoNicknameAnimal` 하나뿐이다 — 화면마다 고정 이모지를 두면 같은 사람이 다르게 보인다 (NO-MOCK R5).
private struct CompanionAvatar: View {
  let companion: ServerTripCompanion

  var body: some View {
    if let url = companion.profileImageURL {
      CachedRemoteImage(url: url) { image in
        image.resizable().scaledToFill()
      } placeholder: {
        MoyeoTheme.leaf
      }
      .frame(width: 40, height: 40)
      .clipShape(Circle())
    } else {
      MascotAvatar(
        mascot: MoyeoNicknameAnimal.emoji(forNickname: companion.nickname) ?? MoyeoNicknameAnimal.unknown,
        size: 40,
        background: MoyeoTheme.leaf
      )
    }
  }
}

struct BlockedUsersView: View {
  /// 캡처 진입(29-1a)은 확인 시트를 연 채로 시작한다 — 20-1a 와 같은 방식이다.
  var startsWithUnblockConfirmation = false
  /// 실서버 차단 목록 — 서버가 준 것만 그린다. nil 은 아직 못 받았다는 뜻이지 빈 목록이 아니다.
  @State private var serverBlocked: [ServerBlockedUser]?
  /// 조회가 실패했는지. 실패를 빈 목록으로 보이면 "차단한 사람이 없다"는 거짓말이 된다.
  @State private var loadFailed = false
  /// 29-1a 차단 해제 확인. 확인을 지나기 전에는 서버를 부르지 않는다.
  @State private var unblockCandidate: ServerBlockedUser?
  @State private var isUnblocking = false
  /// 차단 해제가 실패한 까닭. 있으면 확인 시트를 닫지 않고 그 자리에 적는다.
  @State private var unblockFailure: String?

  var body: some View {
    ScrollView {
      VStack(spacing: 10) {
        infoCard("차단하면 그 사람이 만들었거나 참여한 모집이 홈·탐색·코스 상세에서 모두 숨겨져요. 상대방에게는 알려지지 않아요.")
        if let serverBlocked {
          // 실서버 차단 목록 — 서버가 준 사용자만 그린다
          if serverBlocked.isEmpty {
            Text("차단한 사용자가 없어요.")
              .font(.caption)
              .foregroundStyle(MoyeoTheme.muted)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 18)
              .accessibilityIdentifier("blockedUsers.server.empty")
          } else {
            ForEach(serverBlocked) { user in
              serverBlockedRow(user)
            }
          }
        } else if loadFailed {
          // 목록을 못 받았을 때 빈 상태를 그리면 "차단한 사람이 없다"로 읽힌다. 실패는 실패라고 말한다.
          VStack(alignment: .leading, spacing: 10) {
            Text("차단 목록을 불러오지 못했어요.")
              .font(.caption)
              .foregroundStyle(MoyeoTheme.muted)
            Button {
              Task { await loadBlockedUsers() }
            } label: {
              Text("다시 시도")
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(MoyeoTheme.line))
            }
            .buttonStyle(.plain)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 18)
          .accessibilityIdentifier("blockedUsers.server.failed")
        } else {
          Text("차단 목록을 불러오는 중이에요.")
            .font(.caption)
            .foregroundStyle(MoyeoTheme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 18)
            .accessibilityIdentifier("blockedUsers.server.loading")
        }
        Text("차단을 해제하면 서로의 모집·피드를 다시 볼 수 있어요. 해제 전에 한 번 더 확인해요.")
          .font(.caption).foregroundStyle(MoyeoTheme.text400).frame(
            maxWidth: .infinity, alignment: .leading)
      }.padding(18)
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .navigationTitle("차단한 사용자")
    .navigationBarTitleDisplayMode(.inline)
    // 29-1a — 19-2 신청 취소와 같은 골격의 확인 시트다 (기획 `ConfirmSheet`).
    .overlay {
      if let user = unblockCandidate {
        MoyeoConfirmSheet(
          title: "차단을 풀까요?",
          subject: user.nickname,
          lines: [
            "차단을 풀면 이 사람이 올린 모집과 피드가 다시 보여요.",
            "이 사람도 회원님의 모집과 피드를 볼 수 있어요.",
            "언제든 다시 차단할 수 있어요."
          ],
          cancelTitle: "그대로 둘게요",
          confirmTitle: "차단 해제",
          isBusy: isUnblocking,
          failureMessage: unblockFailure,
          identifier: "unblockConfirm",
          onCancel: {
            unblockCandidate = nil
            unblockFailure = nil
          },
          onConfirm: { unblock(user) }
        )
      }
    }
    .task {
      guard serverBlocked == nil, !loadFailed else { return }
      await loadBlockedUsers()
      if startsWithUnblockConfirmation { unblockCandidate = serverBlocked?.first }
    }
    .accessibilityIdentifier("screen.blockedUsers")
  }

  /// 차단 목록 조회. 실패를 삼키지 않는다 — 예전에는 `try?` 로 nil 을 받고
  /// 지어낸 두 사람(「말많은 너구리 7791」 등)을 그렸다. 목데이터 금지 규칙 위반이었다.
  private func loadBlockedUsers() async {
    guard MoyeoServerSync.isEnabled else {
      loadFailed = true
      return
    }
    loadFailed = false
    do {
      serverBlocked = try await SocialAPIClient.shared.blockedUsers()
    } catch {
      loadFailed = true
    }
  }

  /// 차단 해제 — 확인 시트를 지나온 뒤에만 온다.
  ///
  /// 예전에는 `try?` 로 삼키고 **성공이든 실패든 시트를 닫았다** — 줄이 그대로 남아 있어도
  /// 사용자는 풀린 줄 안다. 실패하면 닫지 않고 그 자리에서 말한다 (TC SOCIAL-010 계열).
  /// 형제 화면인 `FriendManageSheet.remove()` 는 처음부터 이렇게 하고 있었다.
  private func unblock(_ user: ServerBlockedUser) {
    guard !isUnblocking else { return }
    isUnblocking = true
    unblockFailure = nil
    Task {
      do {
        try await SocialAPIClient.shared.unblock(userID: user.userId)
      } catch {
        isUnblocking = false
        unblockFailure = error.moyeoUserMessage(
          fallback: "차단을 풀지 못했어요. 잠시 후 다시 시도해주세요.")
        return
      }
      // 해제는 성공했다. 목록 재조회가 실패하면 nil 로 두지 말고 실패 상태를 그린다.
      await loadBlockedUsers()
      isUnblocking = false
      unblockCandidate = nil
    }
  }

  private func serverBlockedRow(_ user: ServerBlockedUser) -> some View {
    HStack(spacing: 12) {
      CachedRemoteImage(url: user.profileImageURL) { image in
        image
          .resizable()
          .scaledToFill()
      } placeholder: {
        MoyeoTheme.subtleBackground
      }
      .frame(width: 42, height: 42)
      .clipShape(Circle())
      VStack(alignment: .leading, spacing: 3) {
        Text(user.nickname).font(.subheadline.weight(.bold))
        Text(blockedAtText(user.blockedAt)).font(.caption2).foregroundStyle(MoyeoTheme.muted)
      }
      Spacer()
      // 29-1a — 차단 해제는 상대에게 내 모집·피드가 다시 보이게 되는 일이다. 한 번 더 묻는다.
      Button {
        unblockCandidate = user
      } label: {
        Text("차단 해제")
          .font(.caption.weight(.heavy))
          .foregroundStyle(MoyeoTheme.ink)
          .padding(.horizontal, 12)
          .frame(height: 34)
          .overlay(RoundedRectangle(cornerRadius: 10).stroke(MoyeoTheme.line))
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("blockedUsers.server.unblock.\(user.userId)")
    }.frame(minHeight: 64)
  }

  /// "2026-09-01T12:00:00" → "2026.09.01 차단"
  private func blockedAtText(_ blockedAt: String) -> String {
    guard let datePart = blockedAt.split(separator: "T").first else { return blockedAt }
    return "\(datePart.replacingOccurrences(of: "-", with: ".")) 차단"
  }
}

struct CoursePublishView: View {
  /// 공개할 코스. 넘겨받지 않으면 화면이 직접 **가장 최근에 끝난 내 모임의 코스**를 받아온다
  /// (`GET /chat-rooms/my` → `GET /travel-courses/chat-rooms/{roomId}`) — 안드로이드
  /// `CoursePublishScreen` 과 같은 근거다. 다녀온 여행이 없으면 빈 상태이고 CTA 는 잠긴다.
  var course: TravelCourse?
  /// 위 경로로 받아온 코스. `course` 가 nil 일 때만 쓴다.
  @State private var loadedCourse: TravelCourse?
  /// 코스를 찾는 중인지·없는지·실패했는지. 셋을 한 화면에서 갈라 그린다 (IOS-F84).
  @State private var loadState: TripCompanionsState = .loading
  /// 다녀온 여행은 있는데 **공개할 자격이 있는 코스가 없을 때** 보여줄 이유.
  /// 자격은 서버가 방마다 주는 `coursePublicationAvailable` 이다 (TC AFTER-020).
  @State private var notPublishableReason: String?
  @Environment(\.dismiss) private var dismiss
  @State private var showsConfirmation = false
  @State private var showsFinalConfirmation = false
  @State private var showsNickname = true
  @State private var isPublished = false
  /// 작성자 닉네임 — "OO 님이 다녀온 코스" 줄의 근거다.
  @State private var myProfile: ServerMyProfile?
  /// 공개할 서버 코스 id. 이게 없으면 서버에 보낼 대상이 없다.
  @State private var publishableCourseID: Int64?
  @State private var isPublishing = false
  @State private var publishFailureMessage: String?
  /// 공개할 제목·소개. 서버가 **둘 다 필수**로 받는다
  /// (`PublishTravelCourseRequest` — title `@Size(max = 100)`, description `@Size(max = 500)`).
  /// 예전에는 테두리만 두른 정적 `Text` 였다. 되돌릴 수 없는 화면인데 고칠 길이 없었고,
  /// 소개가 비면 `publish()` 가 **코스 이름을 소개 자리에 넣어** 올렸다.
  @State private var draftTitle = ""
  @State private var draftDescription = ""
  /// 코스를 읽은 뒤 한 번만 채운다 — 매번 채우면 사용자가 고친 값을 덮어쓴다.
  @State private var didPrefill = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Text(isPublished ? "코스를 공개했어요" : "이번 여행 코스,\n다른 여행자에게도 열어둘까요?")
          .font(MoyeoTypography.font(size: 17, weight: .heavy, relativeTo: .headline))
          .lineSpacing(4)
        Text(
          isPublished
            ? "이제 탐색과 코스 목록에서 여행자 코스로 만날 수 있어요." : "공개하면 탐색과 코스 목록에 올라가고, 다른 사람이 이 코스로 모집을 열 수 있어요."
        )
        .font(MoyeoTypography.font(size: 12, relativeTo: .caption))
        .foregroundStyle(MoyeoTheme.muted)
        .lineSpacing(3)
        .padding(.top, 8)

        Text("공개하면 이렇게 보여요")
          .font(MoyeoTypography.font(size: 12, weight: .heavy, relativeTo: .caption))
          .foregroundStyle(MoyeoTheme.muted)
          .padding(.top, 18)
          .padding(.bottom, 8)
          .accessibilityIdentifier("coursePublish.previewTitle")
        if let publishableCourse {
          CoursePublishPreview(
            course: publishableCourse,
            authorNickname: authorNickname,
            draftTitle: draftTitle,
            authorProfileImageUrl: myProfile?.profileImageUrl
          )
        } else {
          switch loadState {
          case .loading:
            // 아직 찾는 중이다 — **없다고 단정하지 않는다.**
            MoyeoEmptyStateView(
              message: MoyeoEmptyText.loading,
              accessibilityIdentifier: "coursePublish.preview.loading"
            )
          case .failed:
            // 실패와 0건을 나눠 말하고 다시 시도할 길을 준다 (안드로이드와 같은 방식).
            MoyeoEmptyStateView(
              message: "다녀온 여행을 불러오지 못했어요.",
              onRetry: { Task { await loadPublishableCourse() } },
              accessibilityIdentifier: "coursePublish.preview.failed"
            )
          case .empty, .ready:
            // 다녀온 여행이 없으면 공개할 코스가 없다 — 지어낸 코스를 미리보기로 세우지 않는다.
            // 문구는 안드로이드 `course-publish-empty` 와 글자 그대로 같다.
            // **다녀왔지만 자격이 없는 경우는 다르게 말한다** — 예전에는 이 구분이 없어
            // 남의 코스로 떠난 방까지 공개 흐름이 열리고 마지막에 403 으로 거절됐다 (TC AFTER-020).
            MoyeoEmptyStateView(
              message: notPublishableReason ?? "아직 다녀온 여행 기록이 없어요.",
              accessibilityIdentifier: notPublishableReason == nil
                ? "coursePublish.preview.empty"
                : "coursePublish.preview.notEligible"
            )
          }
        }

        if !isPublished, publishableCourse != nil {
          publishInput(
            "코스 이름",
            text: $draftTitle,
            limit: Self.titleLimit,
            hint: "\(Self.titleLimit)자까지 · 공개 코스 목록에 이 이름이 보여요",
            identifier: "coursePublish.title"
          )
          .padding(.top, 18)
          // 소개도 **필수**다. 비었다고 칸을 감추면 공개 자체가 불가능해진다
          // (웹 `ScreenCoursePublish` 와 같은 규칙).
          publishInput(
            "한 줄 소개",
            text: $draftDescription,
            limit: Self.descriptionLimit,
            hint: "다녀온 사람만 쓸 수 있는 한 줄이 코스의 값어치예요. \(Self.descriptionLimit)자까지",
            identifier: "coursePublish.description",
            isMultiline: true
          )
          .padding(.top, 16)
        }

        if !isPublished {
          MoyeoCheckRow(
            title: "내 닉네임을 함께 보여주기",
            subtitle: "끄면 익명 여행자 코스로 올라가요.",
            isOn: $showsNickname,
            accessibilityIdentifier: "coursePublish.showsNickname"
          )
          .padding(13)
          .background(MoyeoTheme.card)
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.softLine))
          .padding(.top, 16)

          warningCard(
            "한 번 공개한 코스는 다시 내릴 수 없어요. 다른 여행자가 이 코스로 모집을 열거나 찜해둘 수 있기 때문이에요."
          )
          .padding(.top, 16)
          .accessibilityIdentifier("coursePublish.irreversibleWarning")
          Text("공개는 지난 여행에서 언제든 다시 열 수 있어요.")
            .font(MoyeoTypography.font(size: 11.5, relativeTo: .caption))
            .foregroundStyle(MoyeoTheme.muted)
            .padding(.top, 14)
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 10)
      .padding(.bottom, 88)
    }
    .safeAreaInset(edge: .bottom) {
      if !isPublished {
        // 다른 화면(17-4 · 17-6 · 20-2f)과 **같은 하단 CTA 컴포넌트**를 쓴다 —
        // 예전에는 이 화면만 작은 캡슐 두 개였다.
        // 공개할 코스가 없으면 누를 수 없다 (안드로이드 `course-publish-start` 와 같은 조건)
        CreationFooter(
          backTitle: "지금은 안 할래요",
          nextTitle: "코스 공개하기",
          back: { dismiss() },
          next: { showsConfirmation = true },
          isNextEnabled: canPublish,
          nextIdentifier: "coursePublish.start"
        )
      }
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .navigationTitle("코스 공개")
    .navigationBarTitleDisplayMode(.inline)
    .alert("한 번 공개하면 다시 내릴 수 없어요", isPresented: $showsConfirmation) {
      Button("취소", role: .cancel) {}
      Button("내용 확인") { showsFinalConfirmation = true }
    } message: {
      Text("코스명 · 경로 · 한 줄 소개가 공개돼요. 채팅 내용과 사진은 공개되지 않아요.")
    }
    .confirmationDialog(
      "정말 이 코스를 공개할까요?", isPresented: $showsFinalConfirmation, titleVisibility: .visible
    ) {
      Button("공개할게요") { publish() }
      Button("취소", role: .cancel) {}
    } message: {
      Text("공개한 코스는 비공개로 되돌릴 수 없습니다.")
    }
    .alert(
      "코스 공개",
      isPresented: Binding(
        get: { publishFailureMessage != nil },
        set: { if !$0 { publishFailureMessage = nil } }
      )
    ) {
      Button("확인", role: .cancel) { publishFailureMessage = nil }
    } message: {
      Text(publishFailureMessage ?? "")
    }
    .task {
      // 넘겨받은 코스가 있으면 서버 동기화가 꺼져 있어도 입력칸은 채워 둔다.
      defer { prefillDraftsIfNeeded() }
      guard MoyeoServerSync.isEnabled else { return }
      if myProfile == nil {
        myProfile = try? await UserProfileAPIClient.shared.myProfile()
      }
      await loadPublishableCourse()
    }
    .accessibilityIdentifier("screen.coursePublish")
  }

  /// 27-3 공개 → `POST /travel-courses/{courseId}/publication`. **되돌릴 수 없다** —
  /// 두 단계 확인(안내 → 최종 확인)을 지나온 뒤에만 온다.
  ///
  /// 예전에는 이 자리에서 `isPublished = true` 만 했다. 서버는 아무것도 모르는데 화면만
  /// "코스를 공개했어요" 라고 말하고 있었다 — 목데이터와 같은 부류의 거짓말이다.
  private func publish() {
    guard let courseID = publishableCourseID, canPublish, !isPublishing else {
      publishFailureMessage = "공개할 코스를 찾지 못했어요."
      return
    }
    // 코스 이름을 소개 자리에 대신 넣지 않는다 — 사용자가 쓴 적 없는 한 줄이
    // 「다녀온 사람이 쓴 소개」로 공개되고, 공개는 되돌릴 수 없다.
    let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    let description = draftDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    isPublishing = true
    Task {
      do {
        _ = try await TravelCourseAPIClient.shared.publishCourse(
          courseID: courseID,
          title: title,
          description: description,
          showsCreatorNickname: showsNickname
        )
        isPublished = true
      } catch {
        publishFailureMessage =
          error.moyeoUserMessage(fallback: "코스를 공개하지 못했어요.")
      }
      isPublishing = false
    }
  }

  /// 공개 CTA 를 열 조건. 서버가 제목·소개를 **둘 다 필수**로 받으므로 하나라도 비면 잠근다.
  private var canPublish: Bool {
    publishableCourse != nil
      && !draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !draftDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  /// 서버 코스의 제목·소개를 입력칸의 첫 값으로 옮긴다. 못 읽었으면 비워 둔다(지어내지 않는다).
  private func prefillDraftsIfNeeded() {
    guard !didPrefill, let course = publishableCourse else { return }
    didPrefill = true
    draftTitle = String(course.title.prefix(Self.titleLimit))
    draftDescription = String(course.subtitle.prefix(Self.descriptionLimit))
  }

  /// 미리보기에 쓸 코스 — 넘겨받은 것이 우선이고, 없으면 서버에서 받아온 것을 쓴다.
  private var publishableCourse: TravelCourse? {
    course ?? loadedCourse
  }

  /// 다녀온 모임(`ended`)의 코스를 하나 가져온다. 목데이터로 대신 채우지 않는다 (NO-MOCK-CANON R1).
  /// 공개할 코스를 찾는다. 호출이 **두 번 이어져** 그동안 화면이 빈 상태였다 —
  /// 「아직 다녀온 여행 기록이 없어요」가 뜨고 CTA 가 잠겨, 기록이 있는 사람도 없다고 읽었다.
  /// 이제 로딩·빈 상태·실패를 갈라 그린다 (IOS-F84).
  private func loadPublishableCourse() async {
    guard course == nil, loadedCourse == nil else { return }
    loadState = .loading
    guard let rooms = try? await ChatRoomAPIClient.shared.myRooms() else {
        loadState = .failed
        return
    }
    // 불발(CANCELLED)된 방도 `ended` 다 — 공개할 코스는 확정돼 끝난 여행의 것이다.
    // **서버 자격을 먼저 본다** — 남이 만든 코스로 떠난 방은 공개할 수 없다 (TC AFTER-020).
    guard let lastTrip = ServerTripMapper.latestPublishableRoom(in: rooms) else {
        notPublishableReason = ServerTripMapper.hasCompletedButNotPublishableRoom(in: rooms)
            // 자격이 없는 이유는 둘이다 — **내가 만든 코스가 아니거나, 이미 공개한 코스거나.**
            // 서버가 주는 것은 `coursePublicationAvailable` 하나뿐이라 둘을 가릴 수 없다.
            // 예전 문구는 호스트 자격만 말해서, 이미 공개한 코스의 호스트에게 거짓말이 됐다.
            ? "다녀온 여행은 있지만 지금 공개할 수 있는 코스가 없어요. 내가 직접 만든 코스 중 아직 공개하지 않은 코스만 공개할 수 있어요."
            : nil
        loadState = .empty
        return
    }
    notPublishableReason = nil
    guard let roomCourse = try? await TravelCourseAPIClient.shared.roomCourse(roomID: lastTrip.roomId),
      let serverCourse = roomCourse.course
    else {
      loadState = .failed
      return
    }
    loadedCourse = ServerCourseMapper.course(from: serverCourse)
    publishableCourseID = serverCourse.courseId
    loadState = .ready
  }

  /// 공개 카드에 붙는 작성자. 끄면(익명) · 서버 닉네임을 모르면 nil 이다.
  private var authorNickname: String? {
    guard showsNickname, let nickname = myProfile?.nickname, !nickname.isEmpty else { return nil }
    return nickname
  }

  /// 라벨에 `*` 를 찍는 **진짜 입력칸**. 글자수 세기·자르기는 다른 수정 화면과 같은
  /// `RecruitEditField` 를 그대로 쓴다.
  private func publishInput(
    _ title: String,
    text: Binding<String>,
    limit: Int,
    hint: String,
    identifier: String,
    isMultiline: Bool = false
  ) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: 4) {
        Text(title)
        Text("*").foregroundStyle(MoyeoTheme.coral)
      }
      .font(MoyeoTypography.font(size: 12, weight: .heavy, relativeTo: .caption))
      .foregroundStyle(MoyeoTheme.muted)
      RecruitEditField(
        text: text,
        limit: limit,
        hint: hint,
        isMultiline: isMultiline,
        identifier: identifier
      )
    }
  }

  /// 이름은 **100자**까지다 — 서버 `PublishTravelCourseRequest.title` 의 `@Size(max = 100)`,
  /// 그리고 코스를 만드는 `CustomCourseIdentityFields.titleLimit` 과 같은 값이다.
  ///
  /// 예전에는 24 였다. 그 때문에 100자까지 적을 수 있는 만들기 화면에서 지은 이름이
  /// **이 화면을 열기만 해도 `prefix(24)` 로 말없이 잘렸다** (IOS-F150).
  /// 짧게 맞추는 쪽으로 고치면 이미 서버에 있는 긴 이름이 여전히 잘리므로,
  /// 서버 한도로 올려 세 화면(만들기·공개·18-7)을 한 값으로 맞췄다.
  private static let titleLimit = 100
  private static let descriptionLimit = 500
}

/// 20-5 여행 당일 채팅방 — 여행 시작일에만 상단에 진행 위젯이 붙은 20 이다.
///
/// ⚠️ 예전 이 화면은 **전부 손으로 쓴 값**이었다: "여행 중 · 5명 · 오늘 08:00 출발",
/// 방문지 4곳(청송터미널·주왕산·주산지·달기약수탕), 대화 두 줄("엉뚱한 토끼 1457"),
/// 그리고 도착 예정 카드("주산지 주차장 · 14:00 도착 예정 · 차로 22분").
/// 화면기획 20-5 의 견본 대화를 그대로 옮겨 그린 것인데, 저 값은 서버에 없다.
/// 방을 못 찾아 빈 상태가 찍히는 동안 이 목데이터가 가려져 있었을 뿐이다.
///
/// 진행 위젯은 `GET /chat-rooms/{roomId}/roadmap/current` 만이 근거다 —
/// `active` 가 false 거나 방문지가 없으면 서버가 진행 상황을 주지 않는 것이므로
/// 빈 상태를 그린다 (웹 `ScreenTripDay` 와 같은 규칙 · NO-MOCK-CANON R1).
/// 대화는 채팅방(20)과 **같은 말풍선·카드**로 그린다.
///
/// "차로 22분" 처럼 어떤 API 도 주지 않는 값은 아예 그리지 않는다 (R3).
struct TripDayView: View {
  let thread: ChatThread
  @State private var draft = ""
  @State private var content: ServerChatRoomContent?
  @State private var didLoad = false
  @State private var route: SupportRoute?
  /// 상단 돋보기 — 지금까지 눌러도 아무 일이 없었다. 이미 받아둔 이 방의 메시지를 좁힌다
  /// (대화 검색 API 는 없다 — 서버를 다시 부르지 않는다).
  @State private var showsSearch = false
  @State private var searchQuery = ""

  private var roadmap: ServerCurrentRoadmap? {
    guard let roadmap = content?.roadmap, roadmap.active, !roadmap.places.isEmpty else {
      return nil
    }
    return roadmap
  }

  private var messages: [ChatMessage] {
    guard let content else { return [] }
    let currentUserID = content.currentUserID
    return content.messages.map { ServerTripMapper.chatMessage(from: $0, currentUserID: currentUserID) }
  }

  /// 메시지 응답에는 프로필 이미지가 없다 — 동행자 목록의 닉네임으로 붙인다 (20 과 같다)
  private var avatarURLsByNickname: [String: URL] {
    guard let content else { return [:] }
    var result: [String: URL] = [:]
    for member in content.memberList.members {
      if let url = member.profileImageURL {
        result[member.nickname] = url
      }
    }
    return result
  }

  var body: some View {
    Group {
      if let roadmap {
        loadedBody(roadmap)
      } else if didLoad {
        // **이 방은 있다.** 없는 것은 「오늘의 진행 상황」이다 — 여행 당일이 아니거나
        // 서버가 아직 로드맵을 열지 않은 것이다. 예전에는 「참여 중인 채팅방이 없어요」라고 해서,
        // 방금 확정한 방을 눈앞에 두고 방이 없다고 말했다 (안드 AND-120 교차).
        MoyeoEmptyStateView(
          message: "아직 여행 당일이 아니에요. 출발일이 되면 오늘의 일정이 여기 나와요.",
          accessibilityIdentifier: "tripDay.state"
        )
      } else {
        MoyeoEmptyStateView(message: MoyeoEmptyText.loading)
      }
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .navigationTitle(content?.detail?.title ?? thread.tripTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        Button {
          showsSearch.toggle()
          if !showsSearch { searchQuery = "" }
        } label: {
          Image(systemName: showsSearch ? "xmark" : "magnifyingglass")
        }
        .accessibilityLabel("대화 검색")
        .accessibilityIdentifier("tripDay.search")
        Button {
          route = .chatMenu(thread.id)
        } label: {
          Image(systemName: "line.3.horizontal")
        }.accessibilityLabel("모임 정보")
      }
    }
    .navigationDestination(item: $route) { SupportDestinationView(route: $0) }
    .accessibilityIdentifier("screen.tripDay")
    .task { await load() }
  }

  @ViewBuilder
  private func loadedBody(_ roadmap: ServerCurrentRoadmap) -> some View {
    VStack(spacing: 0) {
      Text(statusLine(roadmap))
        .font(MoyeoTypography.font(size: 12, weight: .semibold, relativeTo: .caption))
        .foregroundStyle(MoyeoTheme.muted)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(MoyeoTheme.softLine).frame(height: 1) }

      tripProgress(roadmap)

      if showsSearch {
        LabelledSearchField(text: $searchQuery, prompt: "대화 내용 검색")
          .padding(.horizontal, 18)
          .padding(.vertical, 10)
          .accessibilityIdentifier("tripDay.searchField")
      }

      ScrollView {
        VStack(spacing: 14) {
          let visible = visibleMessages
          if visible.isEmpty, isSearching {
            MoyeoEmptyStateView(
              message: MoyeoEmptyText.noSearchResults,
              systemImage: "magnifyingglass",
              accessibilityIdentifier: "tripDay.search.empty"
            )
          } else {
            ForEach(visible) { message in
              MessageBubble(
                message: message,
                avatarURL: avatarURLsByNickname[message.senderName]
              )
            }
          }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
      }

      composer
    }
  }

  /// 검색창이 열려 있고 실제로 뭔가 적혀 있을 때만 검색 중이다.
  private var isSearching: Bool {
    showsSearch && !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
  }

  /// 검색 중이면 본문·보낸 사람으로 좁힌 메시지, 아니면 받은 메시지 전부.
  private var visibleMessages: [ChatMessage] {
    let keyword = searchQuery.trimmingCharacters(in: .whitespaces)
    guard isSearching else { return messages }
    return messages.filter {
      $0.body.localizedCaseInsensitiveContains(keyword)
        || $0.senderName.localizedCaseInsensitiveContains(keyword)
    }
  }

  private var composer: some View {
    HStack(spacing: 8) {
      Button {
        route = .chatAttach(thread.id)
      } label: {
        Image(systemName: "plus").frame(width: 44, height: 44)
      }
      // ENV-006: 라벨이 없으면 VoiceOver 가 심볼 이름(「plus」)을 그대로 읽는다.
      .buttonStyle(.plain).accessibilityLabel("첨부 메뉴 열기")
      TextField("메시지 입력", text: $draft).padding(.horizontal, 12).frame(minHeight: 44).background(
        MoyeoTheme.subtleBackground
      ).clipShape(Capsule())
      Button {
        Task { await send() }
      } label: {
        Image(systemName: "paperplane.fill").foregroundStyle(.white).frame(width: 44, height: 44)
          .background(MoyeoTheme.forest).clipShape(Circle())
      }
      // ENV-006: 라벨이 없으면 VoiceOver 가 영어 시스템 문구(「Send」)로 읽는다.
      .buttonStyle(.plain).accessibilityLabel("메시지 보내기")
      .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
    }.padding(12).background(MoyeoTheme.card)
  }

  /// "여행 중 · 5명 · 1/2일차" — 인원은 방 상세, 일차는 로드맵이 준다.
  /// 예전의 "오늘 08:00 출발" 은 어떤 응답에도 없는 값이었다.
  private func statusLine(_ roadmap: ServerCurrentRoadmap) -> String {
    var parts = ["여행 중"]
    if let participantCount = content?.detail?.participantCount {
      parts.append("\(participantCount)명")
    }
    if let dayNumber = roadmap.dayNumber {
      parts.append("\(dayNumber)/\(roadmap.totalDays)일차")
    }
    return parts.joined(separator: " · ")
  }

  /// 서버는 방문지별 progress(COMPLETED / CURRENT / UPCOMING)를 준다 —
  /// 완료 개수(+ 진행 중 1)가 곧 현재 단계다 (웹과 같은 셈).
  private func currentStep(_ roadmap: ServerCurrentRoadmap) -> Int {
    let completed = roadmap.places.filter(\.isCompleted).count
    let inProgress = roadmap.places.contains(where: \.isCurrent) ? 1 : 0
    return max(1, completed + inProgress)
  }

  private func tripProgress(_ roadmap: ServerCurrentRoadmap) -> some View {
    let step = currentStep(roadmap)
    let places = roadmap.places
    let currentTitle = places.indices.contains(step - 1) ? places[step - 1].title : ""
    return VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: "mappin.and.ellipse")
          .font(.caption)
          .foregroundStyle(MoyeoTheme.forest)
        Text("현재 방문지 \(step)/\(places.count) · \(currentTitle)")
          .font(MoyeoTypography.font(size: 12.5, weight: .heavy, relativeTo: .caption))
          .foregroundStyle(MoyeoTheme.forest)
        Spacer()
        // 「코스 전체 →」는 **눌리는 링크**다. 예전에는 그냥 `Text` 라 링크처럼 보이는데
        // 눌러도 아무 일이 없었고, 여행 당일 화면에서 코스 전체를 볼 길이 없었다
        // (TC CHAT-041 · HOST-034 와 같은 부류의 죽은 UI).
        // 목적지는 모임 정보 → 「여행 경로」와 같은 화면이다.
        Button {
          route = .courseEdit(thread.id, thread.routeEditState)
        } label: {
          Text("코스 전체 →")
            .font(MoyeoTypography.font(size: 11, weight: .bold, relativeTo: .caption2))
            .foregroundStyle(MoyeoTheme.forest)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tripDay.openFullCourse")
      }
      HStack(spacing: 0) {
        ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
          if index > 0 {
            dayLine(done: index < step)
          }
          dayStep(place.title, index + 1, done: index < step)
        }
      }
      if let next = roadmap.nextPlace {
        HStack(spacing: 6) {
          Image(systemName: "clock")
            .font(.caption)
            .foregroundStyle(MoyeoTheme.forest)
          Text("다음 일정 · ")
          Text(nextScheduleText(next)).fontWeight(.heavy)
        }
        .font(MoyeoTypography.font(size: 11.5, relativeTo: .caption))
        .foregroundStyle(MoyeoTheme.forest)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(MoyeoTheme.leaf)
    .overlay(alignment: .bottom) { Rectangle().fill(MoyeoTheme.softLine).frame(height: 1) }
    .accessibilityIdentifier("tripDay.progress")
  }

  private func nextScheduleText(_ place: ServerRoadmapPlace) -> String {
    guard let scheduledAt = place.scheduledAt,
      let time = ServerTripMapper.shortTime(String(scheduledAt.split(separator: "T").last ?? ""))
    else {
      return place.title
    }
    return "\(time) \(place.title)"
  }

  private func dayStep(_ title: String, _ number: Int, done: Bool) -> some View {
    VStack(spacing: 5) {
      Group {
        if done {
          Image(systemName: "checkmark")
        } else {
          Text("\(number)")
        }
      }
      .font(MoyeoTypography.font(size: 9, weight: .heavy, relativeTo: .caption2))
      .foregroundStyle(done ? .white : MoyeoTheme.forest)
      .frame(width: 24, height: 24).background(
        done ? MoyeoTheme.forest : Color.clear
      ).clipShape(Circle())
      .overlay(Circle().stroke(done ? MoyeoTheme.forest : MoyeoTheme.softLine, lineWidth: 1.5))
      Text(title)
        .font(MoyeoTypography.font(size: 9.5, weight: .semibold, relativeTo: .caption2))
        .foregroundStyle(done ? MoyeoTheme.forest : MoyeoTheme.muted)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
    .frame(width: 62)
  }

  private func dayLine(done: Bool) -> some View {
    Rectangle().fill(done ? MoyeoTheme.forest : MoyeoTheme.softLine).frame(maxWidth: .infinity)
      .frame(height: 2).offset(y: -9)
  }

  private func load() async {
    guard !didLoad else { return }
    guard MoyeoServerSync.isEnabled, let roomID = thread.serverRoomID else {
      didLoad = true
      return
    }
    content = await ChatRoomContentAPIClient.shared.content(roomID: roomID)
    didLoad = true
  }

  /// 20 과 같은 엔드포인트로 실제로 보낸다 — 화면 안에서만 늘어나는 가짜 말풍선을 만들지 않는다.
  private func send() async {
    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let roomID = thread.serverRoomID else { return }
    draft = ""
    guard
      let sent = try? await ChatRoomWriteAPIClient.shared.sendMessage(
        roomID: roomID, content: trimmed)
    else { return }
    content?.messages.append(sent)
  }
}

struct NotificationDetailView: View {
  /// 29-2 는 **실서버 설정**을 그린다 — `GET /notifications/settings` + `GET /users/me/profile`.
  /// 예전에는 화면 안의 `@State` 기본값(모든 메시지 · 방해금지 켜짐 · 22:30~07:00)만 그렸다.
  /// 그래서 (가) 웹·안드로이드는 서버값을 읽어 꺼져 있는데 iOS 만 켜진 채로 찍혔고,
  /// (나) **바꿔도 서버에 저장되지 않아 그 시간에 푸시가 그대로 왔다** (사용자 지적 2026-09-09).
  /// 방해금지는 서버가 발송을 막는 기능이라 저장이 안 되면 기능 자체가 없는 것과 같다.
  @State private var mode = "모든 메시지"
  @State private var quietHours = false
  @State private var quietDays: Set<String> = []
  @State private var quietStart = "22:30"
  @State private var quietEnd = "07:00"
  /// 지금 고르고 있는 칸. 예전에는 시작·종료가 **정적 `Text`** 라 손댈 수가 없는데
  /// 그 값을 그대로 서버에 저장해서, 고른 적 없는 22:30~07:00 이 「내가 정한 방해금지」로
  /// 남아 있었다. 탭하면 시각 피커가 뜨게 고쳤다.
  @State private var editingQuietHour: QuietHourEdit?
  /// 저장 PUT 은 프로필의 다른 알림 스위치까지 **함께** 보내야 한다(부분 갱신이 없다).
  @State private var profile: ServerMyProfile?
  @State private var didLoad = false
  /// 설정 조회가 실패했는지. 실패를 화면 기본값으로 덮어 그리지 않는다 (NO-MOCK-CANON R1).
  @State private var loadFailed = false
  /// 저장이 막히거나 실패한 이유. 비면 그 줄을 그리지 않는다.
  @State private var saveErrorMessage: String?
  private let modes = ["모든 메시지", "멘션·답글만", "받지 않기"]
  private let weekdays = ["월", "화", "수", "목", "금", "토", "일"]
  /// OS 알림 권한이 꺼져 있는지. 꺼져 있으면 이 화면의 스위치를 아무리 켜도
  /// 기기에 알림이 오지 않는다 — 서버 값만 보여 주면 「켜 뒀는데 왜 안 와요」가 된다
  /// (TC NOTIF-016). 화면에 들어올 때마다 다시 읽는다(설정에서 바꾸고 돌아올 수 있다).
  @State private var isSystemNotificationDenied = false
  @Environment(\.openURL) private var openURL
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        if isSystemNotificationDenied {
          MoyeoSystemNotificationDeniedNotice { openNotificationSettings() }
        }
        if loadFailed {
          // 못 받은 설정을 「내 설정」처럼 그리지 않는다 (NO-MOCK-CANON R1 · §2 실패 문구).
          MoyeoEmptyStateView(
            message: MoyeoEmptyText.loadFailed,
            onRetry: { Task { await load() } },
            accessibilityIdentifier: "notificationDetail.server.failed"
          )
        }
        // 제목 줄을 두지 않는다 — 기획·웹·안드로이드는 설명 문구로 바로 시작한다.
        // iOS 만 「알림 범위」 라는 머리글이 하나 더 있어 4열에서 이 화면만 한 줄 길었다.
        VStack(alignment: .leading, spacing: 8) {
          Text("모임이 여러 개면 알림이 금방 쌓여요. 받고 싶은 만큼만 켜두세요.")
            .font(.caption)
            .foregroundStyle(MoyeoTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
          ForEach(modes, id: \.self) { item in
            ChangelogRadioOption(
              title: item,
              detail: modeDetail(for: item),
              isSelected: mode == item
            ) {
              mode = item
              save()
            }
          }
        }
        quietHoursCard
      }.padding(18).padding(.bottom, 28)
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .navigationTitle("채팅 알림")
    .navigationBarTitleDisplayMode(.inline)
    .accessibilityIdentifier("screen.notificationDetail")
    .task { await load() }
    .task { await refreshSystemNotificationState() }
    .onChange(of: scenePhase) { _, phase in
      // iOS 설정에서 권한을 바꾸고 돌아오면 즉시 반영한다.
      guard phase == .active else { return }
      Task { await refreshSystemNotificationState() }
    }
    .sheet(item: $editingQuietHour) { field in
      // 서버(`doNotDisturbStartTime`·`doNotDisturbEndTime`)도 화면도 `HH:mm` 을 쓴다.
      QuietHourTimeSheet(title: field.sheetTitle, initial: field == .start ? quietStart : quietEnd) { picked in
        if field == .start { quietStart = picked } else { quietEnd = picked }
        save()
      }
    }
  }

  /// 카드 밖 머리글을 두지 않는다 — 카드 첫 줄이 이미 「방해금지 시간대」다(같은 말을 두 번 썼다).
  private var quietHoursCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      // 체크박스가 아니라 **토글**이다 — 기획·웹·안드로이드 셋 다 토글이고,
      // 「지금 켜져 있는 상태」를 말하는 스위치라 체크박스(고르는 것)와 뜻이 다르다.
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Text("방해금지 시간대")
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(MoyeoTheme.ink)
          Text("이 시간엔 소리·진동 없이 조용히 쌓여요")
            .font(.caption)
            .foregroundStyle(MoyeoTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Toggle("", isOn: $quietHours)
          .labelsHidden()
          .tint(MoyeoTheme.leaf)
          .accessibilityIdentifier("notificationDetail.quietHours")
          .accessibilityLabel("방해금지 시간대")
          .onChange(of: quietHours) { _, _ in save() }
      }
      if quietHours {
        HStack(spacing: 10) {
          quietHourField(label: "시작", value: quietStart, identifier: "notificationDetail.quietStart") {
            editingQuietHour = .start
          }
          quietHourField(label: "종료", value: quietEnd, identifier: "notificationDetail.quietEnd") {
            editingQuietHour = .end
          }
        }
        if let saveErrorMessage {
          Text(saveErrorMessage)
            .font(MoyeoTypography.tinyMeta)
            .foregroundStyle(MoyeoTheme.dangerRed)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("notificationDetail.saveError")
        }
        VStack(alignment: .leading, spacing: 6) {
          Text("요일").font(.caption.weight(.heavy)).foregroundStyle(MoyeoTheme.ink)
          HStack(spacing: 6) {
            ForEach(weekdays, id: \.self) { day in
              weekdayChip(day)
            }
          }
        }
        Text("집합 30분 전 알림처럼 여행 당일 안내는 방해금지 시간에도 전달돼요.")
          .font(.caption2).foregroundStyle(MoyeoTheme.muted)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(14)
    .background(MoyeoTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.softLine))
  }

  private func weekdayChip(_ day: String) -> some View {
    let on = quietDays.contains(day)
    return Button {
      if on { quietDays.remove(day) } else { quietDays.insert(day) }
      save()
    } label: {
      Text(day)
        .font(.caption.weight(.heavy))
        .foregroundStyle(on ? MoyeoTheme.onLeaf : MoyeoTheme.muted)
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .background(on ? MoyeoTheme.leaf : MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
          RoundedRectangle(cornerRadius: 10)
            .stroke(on ? MoyeoTheme.forest : MoyeoTheme.line))
    }
    .buttonStyle(.plain)
  }

  private func modeDetail(for mode: String) -> String {
    switch mode {
    case "모든 메시지": "모임의 모든 대화를 알려드려요"
    case "멘션·답글만": "나를 부르거나 내 메시지에 답할 때만"
    default: "앱을 열었을 때만 확인해요"
    }
  }

  /// 설정을 못 받으면 **화면 안의 기본값**(모든 메시지 · 22:30~07:00)이 그대로 그려져,
  /// 사용자는 서버가 확인해 준 내 설정으로 읽는다 — 실패를 확정값으로 그리는 것은
  /// 목데이터와 같다 (NO-MOCK-CANON R1). 실패는 실패라고 말하고 다시 시도를 준다.
  private func load() async {
    guard !didLoad else { return }
    loadFailed = false
    guard
      let settings = try? await NotificationAPIClient.shared.settings(),
      let loadedProfile = try? await UserProfileAPIClient.shared.myProfile()
    else {
      loadFailed = true
      return
    }
    profile = loadedProfile
    mode = Self.modeText(for: loadedProfile.chatNotificationMode)
    quietHours = settings.doNotDisturbEnabled
    if let start = settings.doNotDisturbStartTime { quietStart = String(start.prefix(5)) }
    if let end = settings.doNotDisturbEndTime { quietEnd = String(end.prefix(5)) }
    quietDays = Set(settings.doNotDisturbDays.compactMap(Self.koreanDay))
    // 저장은 불러온 뒤에만 한다 — 기본값으로 서버를 덮어쓰면 사용자 설정이 사라진다.
    didLoad = true
  }

  /// OS 알림 권한이 꺼져 있는지 확인한다. `denied` 일 때만 안내를 띄운다 —
  /// `notDetermined` 는 아직 물어보지 않은 것이라 「막혔다」고 말하면 거짓말이 된다.
  private func refreshSystemNotificationState() async {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    isSystemNotificationDenied = settings.authorizationStatus == .denied
  }

  private func openNotificationSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    openURL(url)
  }

  /// 방해금지를 켜면 서버 `NotificationSetting` 이 **시작≠종료 · 시각 둘 다 있음 · 요일 1개 이상**을
  /// `require()` 로 강제한다. 하나만 어긋나도 **요청 전체가 실패**해서, 같이 보낸 알림 모드·요일까지
  /// 저장되지 않는다. 보내기 전에 같은 규칙으로 막고 이유를 말한다 (안드 AND-107 과 같은 결함).
  private var quietHoursError: String? {
    guard quietHours else { return nil }
    if quietStart.isEmpty || quietEnd.isEmpty { return "방해금지 시작·종료 시각을 정해 주세요." }
    if quietStart == quietEnd { return "시작과 종료 시각이 같으면 안 돼요." }
    if quietDays.isEmpty { return "방해금지를 적용할 요일을 하나 이상 골라 주세요." }
    return nil
  }

  private func save() {
    guard didLoad, let profile else { return }
    if let invalid = quietHoursError {
      saveErrorMessage = invalid
      return
    }
    saveErrorMessage = nil
    // `compactMap(Self.apiDay)` 처럼 함수 참조로 넘기면 main-actor 격리가 벗겨져 경고가 난다.
    let days = quietDays.compactMap { Self.apiDay($0) }.sorted()
    let update = ServerNotificationSettingsUpdate(
      chatNotificationMode: Self.modeCode(for: mode),
      recruitmentDeadlineEnabled: profile.recruitmentDeadlineEnabled,
      socialActivityEnabled: profile.socialActivityEnabled,
      marketingEnabled: profile.marketingEnabled,
      doNotDisturbEnabled: quietHours,
      doNotDisturbStartTime: quietHours ? quietStart : nil,
      doNotDisturbEndTime: quietHours ? quietEnd : nil,
      doNotDisturbDays: days
    )
    // 실패를 `try?` 로 삼키면 **화면만 바뀌고 서버에는 안 저장된 채** 아무도 모른다.
    Task {
      do {
        _ = try await NotificationAPIClient.shared.updateSettings(update)
        saveErrorMessage = nil
      } catch {
        saveErrorMessage = error.moyeoUserMessage(fallback: "알림 설정을 저장하지 못했어요. 잠시 후 다시 시도해주세요.")
      }
    }
  }

  private static let dayPairs = [
    ("MONDAY", "월"), ("TUESDAY", "화"), ("WEDNESDAY", "수"), ("THURSDAY", "목"),
    ("FRIDAY", "금"), ("SATURDAY", "토"), ("SUNDAY", "일")
  ]

  private static func koreanDay(_ code: String) -> String? {
    dayPairs.first { $0.0 == code.uppercased() }?.1
  }

  private static func apiDay(_ korean: String) -> String? {
    dayPairs.first { $0.1 == korean }?.0
  }

  private static func modeText(for code: String?) -> String {
    switch code {
    case "MENTIONS_AND_REPLIES": "멘션·답글만"
    case "NONE": "받지 않기"
    default: "모든 메시지"
    }
  }

  private static func modeCode(for text: String) -> String {
    switch text {
    case "멘션·답글만": "MENTIONS_AND_REPLIES"
    case "받지 않기": "NONE"
    default: "ALL"
    }
  }
}

struct AccountDeleteView: View {
  let onDeleted: () -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var reason = ""
  @State private var acknowledgesDeletion = false
  @State private var showsFinalConfirmation = false
  @State private var isDeleting = false
  @State private var errorMessage: String?
  /// 참여 중인 여행 경고의 근거는 `GET /api/v1/chat-rooms/my` 다 — 웹·안드로이드와 같은 조회.
  /// 서버에서 받은 방만 담는다. 못 받았거나 하나도 없으면 **카드를 그리지 않는다** (NO-MOCK R1).
  @State private var joinedTrips: [AccountDeleteJoinedTrip] = []
  // 화면기획과 같은 사유·삭제범위
  /// 탈퇴 사유는 **서버가 준다** — `GET /users/me/withdrawal-reasons` (신고 사유와 같은 방식).
  /// 예전에는 다섯 문장을 여기에 하드코딩해 두고 고른 값을 어디에도 보내지 않았다 (TC SET-039).
  @State private var serverReasons: [ServerWithdrawalReason] = []
  /// 고른 사유의 서버 코드(`TRAVEL_LESS_OFTEN` 등). 못 받았으면 비어 있다.
  @State private var reasonCode: String?
  /// 「기타」를 골랐을 때의 자유 입력. 서버 제한은 200자다.
  @State private var reasonDetail = ""
  private let deletionScope = [
    "피드·도감·친구·여행 기록이 모두 삭제돼요",
    "내가 공개한 여행자 코스는 남지만 닉네임은 지워져요",
    "30일 안에 다시 로그인하면 계정을 되살릴 수 있어요",
    "30일이 지나면 완전히 삭제되고 되돌릴 수 없어요"
  ]

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
        joinedTripsCard

        VStack(alignment: .leading, spacing: 4) {
          Text("떠나는 이유를 알려주세요").font(.subheadline.weight(.heavy)).foregroundStyle(MoyeoTheme.ink)
          Text("서비스를 고치는 데만 쓰여요. (필수)").font(.caption).foregroundStyle(MoyeoTheme.muted)
        }
        VStack(spacing: 8) {
          ForEach(serverReasons) { item in
            ChangelogRadioOption(title: item.displayName, isSelected: reasonCode == item.reason) {
              reasonCode = item.reason
              reason = item.displayName
              // 「기타」가 아니면 자유 입력은 서버가 무시하므로 함께 지운다.
              if !item.acceptsDetail { reasonDetail = "" }
            }
            .accessibilityIdentifier("accountDelete.reason.\(item.reason)")
          }
          if serverReasons.isEmpty {
            // 못 받았으면 **문구를 지어내지 않는다** — 사유는 선택이라 탈퇴 자체는 막지 않는다.
            Text("탈퇴 사유를 불러오지 못했어요. 사유 없이도 탈퇴할 수 있어요.")
              .font(.caption)
              .foregroundStyle(MoyeoTheme.muted)
              .frame(maxWidth: .infinity, alignment: .leading)
              .accessibilityIdentifier("accountDelete.reasons.failed")
          }
        }
        // 「기타」를 고른 경우에만 자유 입력을 받는다. 서버도 그때만 `reasonDetail` 을 저장한다.
        if selectedReasonAcceptsDetail {
          VStack(alignment: .leading, spacing: 6) {
            TextField("어떤 점이 아쉬웠는지 알려주세요 (선택)", text: Binding(
              get: { reasonDetail },
              set: { reasonDetail = String($0.prefix(Self.reasonDetailLimit)) }
            ), axis: .vertical)
              .font(.subheadline)
              .lineLimit(2...4)
              .padding(10)
              .background(MoyeoTheme.subtleBackground)
              .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
              .accessibilityIdentifier("accountDelete.reasonDetail")
            Text("\(reasonDetail.count) / \(Self.reasonDetailLimit)")
              .font(.caption2)
              .foregroundStyle(MoyeoTheme.text400)
              .monospacedDigit()
              .frame(maxWidth: .infinity, alignment: .trailing)
          }
        }
        // 삭제 범위는 화면기획과 같은 4줄
        VStack(alignment: .leading, spacing: 8) {
          Text("탈퇴하면 이렇게 돼요").font(.subheadline.weight(.heavy)).foregroundStyle(MoyeoTheme.ink)
          ForEach(deletionScope, id: \.self) { line in
            HStack(alignment: .top, spacing: 8) {
              Circle().fill(MoyeoTheme.text400).frame(width: 4, height: 4).padding(.top, 7)
              Text(line)
                .font(.caption)
                .foregroundStyle(MoyeoTheme.text700)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          MoyeoCheckRow(
            title: "삭제 범위와 30일 대기 정책을 확인했어요",
            tint: MoyeoTheme.coral,
            isOn: $acknowledgesDeletion,
            accessibilityIdentifier: "accountDelete.acknowledge"
          )
          .id("accountDelete.captureBottom")
          if isDeleting { ProgressView("탈퇴 요청을 처리하고 있어요").frame(maxWidth: .infinity) }
        }.padding(18).padding(.bottom, 12)
      }
      .background(MoyeoTheme.background.ignoresSafeArea())
      .navigationTitle("계정 탈퇴")
      .navigationBarTitleDisplayMode(.inline)
      .task { await loadJoinedTrips() }
      .task { await loadReasons() }
      .onAppear {
        guard UITestScrollDriver.requestedPage > 1 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
          proxy.scrollTo("accountDelete.captureBottom", anchor: .bottom)
        }
      }
      .safeAreaInset(edge: .bottom) {
      // 화면기획은 돌아가기 / 탈퇴하기 두 버튼을 하단에 고정한다
      HStack(spacing: 8) {
        Button("돌아가기") { dismiss() }
          .font(.subheadline.weight(.heavy))
          .foregroundStyle(MoyeoTheme.ink)
          .frame(width: 96, height: 50)
          .accessibilityIdentifier("accountDelete.back")
        // 비활성 CTA는 화면기획·웹·안드로이드처럼 회색 채움으로 (붉은 버튼을 흐리게만 두면 눌릴 것처럼 보인다)
        let canDelete = !reason.isEmpty && acknowledgesDeletion && !isDeleting
        Button {
          showsFinalConfirmation = true
        } label: {
          Text("탈퇴하기")
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(canDelete ? .white : MoyeoTheme.muted)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(canDelete ? MoyeoTheme.coral : MoyeoTheme.subtleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canDelete)
        .accessibilityIdentifier("accountDelete.submit")
      }
      .padding(.horizontal, 18)
      .padding(.top, 8)
      .padding(.bottom, 12)
      .background(MoyeoTheme.card)
      .overlay(alignment: .top) { Rectangle().fill(MoyeoTheme.softLine).frame(height: 1) }
      }
      .alert("30일 후 계정이 삭제돼요", isPresented: $showsFinalConfirmation) {
      Button("취소", role: .cancel) {}
      Button("탈퇴 요청", role: .destructive) { deleteAccount() }
    } message: {
      Text("지금 요청하면 로그아웃되고 30일 동안 복구할 수 있어요. 계속할까요?")
    }
    .alert(
      "탈퇴 요청을 완료하지 못했어요",
      isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    ) {
      Button("확인", role: .cancel) {}
    } message: {
      Text(errorMessage ?? "")
    }
      .accessibilityIdentifier("screen.accountDelete")
    }
  }

  /// 참여 중인 여행 경고 — 어떤 여행을 먼저 정리해야 하는지 이 화면에서 알아야 한다 (화면기획).
  ///
  /// 목록이 비면 카드를 통째로 숨긴다. 무조건 그리면 `참여 중인 여행이 0개 있어요` 가 나온다 —
  /// 안드로이드에 남아 있다고 보고된 함정이라 iOS 는 조건을 실제로 건다.
  @ViewBuilder
  private var joinedTripsCard: some View {
    if !joinedTrips.isEmpty {
      VStack(alignment: .leading, spacing: 10) {
        Label("참여 중인 여행이 \(joinedTrips.count)개 있어요", systemImage: "person.2.fill")
          .font(.subheadline.weight(.heavy))
          .foregroundStyle(MoyeoTheme.warningText)
        Text("탈퇴하면 동행자들에게 갑자기 빈자리가 생겨요. 나가기 처리를 먼저 해주세요.")
          .font(.caption)
          .foregroundStyle(MoyeoTheme.warningText)
          .fixedSize(horizontal: false, vertical: true)
        ForEach(joinedTrips) { trip in
          // 「나가기 처리를 먼저 해주세요」라고 해 놓고 **「관리 →」가 `Text` 였다** —
          // 가라는 곳으로 가는 길이 없었다 (IOS-F65). 방을 열어 주면 거기서 나갈 수 있다.
          NavigationLink(value: ServerTripMapper.stubThread(serverRoomID: trip.id)) {
            HStack(spacing: 8) {
              Image(systemName: "calendar")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MoyeoTheme.warningText)
              Text(trip.label)
                .font(.caption.weight(.bold))
                .foregroundStyle(MoyeoTheme.ink)
              Spacer(minLength: 0)
              Text("관리 →")
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.warningText)
            }
            .padding(11)
            .frame(minHeight: 44)
            .background(MoyeoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("accountDelete.joinedTrip.\(trip.id)")
        }
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(MoyeoTheme.warningBackground)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .accessibilityIdentifier("accountDelete.joinedTrips")
    }
  }

  /// 종료된 방은 정리할 대상이 아니라 목록에서 뺀다 (웹·안드로이드와 같은 필터).
  /// 실패하면 가진 것(=없음)을 그대로 둔다 — 지어낸 여행으로 채우지 않는다.
  private func loadJoinedTrips() async {
    guard MoyeoServerSync.isEnabled, joinedTrips.isEmpty else { return }
    guard let rooms = try? await ChatRoomAPIClient.shared.myRooms() else { return }
    joinedTrips = rooms.filter { !$0.ended }.map(AccountDeleteJoinedTrip.init(room:))
  }

  /// 서버 제한과 같은 값 (`WithdrawRequest.reasonDetail` 은 `@Size(max = 200)`).
  private static let reasonDetailLimit = 200

  private var selectedReasonAcceptsDetail: Bool {
    serverReasons.first { $0.reason == reasonCode }?.acceptsDetail ?? false
  }

  /// 사유 목록을 받아 온다. 못 받아도 탈퇴는 막지 않는다 — 서버에서 사유는 선택이다.
  private func loadReasons() async {
    guard MoyeoServerSync.isEnabled, serverReasons.isEmpty else { return }
    guard let list = try? await WithdrawalReasonAPIClient.shared.reasons() else { return }
    serverReasons = list
  }

  private func deleteAccount() {
    isDeleting = true
    Task {
      do {
        // 고른 사유를 **함께 보낸다**. 안 골랐으면 본문 없이 보낸다.
        let trimmedDetail = reasonDetail.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = reasonCode.map { code in
          ServerWithdrawRequest(
            reason: code,
            reasonDetail: selectedReasonAcceptsDetail && !trimmedDetail.isEmpty ? trimmedDetail : nil
          )
        }
        try await AuthAccountService().withdraw(reason: body)
        onDeleted()
      } catch { errorMessage = error.moyeoUserMessage(fallback: "잠시 후 다시 시도해주세요.") }
      isDeleting = false
    }
  }
}

/// 29-3 경고 카드의 한 줄. `GET /api/v1/chat-rooms/my` 응답에서만 만든다.
struct AccountDeleteJoinedTrip: Identifiable, Hashable {
  let id: Int64
  let label: String

  /// D-day 는 서버가 줄 때만 붙인다 — 안드로이드 `recruitmentDDayText`·웹과 같은 규칙이고,
  /// 값이 없거나 음수면 제목만 남긴다(지어내지 않는다).
  nonisolated init(room: ServerMyChatRoom) {
    id = room.roomId
    if let dDay = room.recruitmentDDay, dDay >= 0 {
      label = "\(room.title) · D-\(dDay)"
    } else {
      label = room.title
    }
  }
}

enum SystemNoticeMode { case maintenance, error }

struct SystemNoticeView: View {
  let mode: SystemNoticeMode
  /// 서버가 준 오류 코드·발생 시각. **없으면 아래 줄을 아예 그리지 않는다.**
  ///
  /// 예전에는 오류 화면 하단에 `ERR-500 · 2026-08-17 14:22` 를 **박아 뒀다** — 코드도 날짜도
  /// 서버가 준 적이 없는 값이라, 언제 난 오류든 늘 같은 8월 날짜를 보여 주고 있었다.
  /// 웹이 같은 줄을 이미 이 규칙으로 고쳤다(`screens-additions3.jsx` — 값이 없으면 `null`).
  var errorCode: String?
  var occurredAt: String?
  @Environment(\.dismiss) private var dismiss
  @State private var retryCount = 0

  /// 38 점검 화면의 재확인은 **이 화면을 떠나는 것**이다 (QA OFF-014, 웹 `ScreenSystemNotice` 와 같다).
  /// 화면을 벗어나면 앞 화면이 다시 서버를 부르고, 아직 점검 중이면 503 이 다시 이 화면을 연다.
  /// 예전에는 `retryCount` 만 올리고 아무 데서도 읽지 않아 **눌러도 아무 일이 없었다.**
  private func recheck() {
    retryCount += 1
    dismiss()
  }

  /// 점검은 언제나 참인 안내를 쓰고(재확인을 실제로 돈다), 오류는 **서버가 준 값이 있을 때만** 적는다.
  private var footnoteText: String? {
    if mode == .maintenance { return "10분마다 자동으로 다시 확인해요" }
    let parts = [errorCode, occurredAt].compactMap { $0?.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  var body: some View {
    VStack(spacing: 18) {
      Spacer()
      Image(systemName: mode == .maintenance ? "gearshape.fill" : "arrow.clockwise")
        .font(.system(size: 38, weight: .semibold))
        .foregroundStyle(mode == .maintenance ? MoyeoTheme.warningText : MoyeoTheme.coral)
        .frame(width: 92, height: 92)
        .background(mode == .maintenance ? MoyeoTheme.warningBackground : MoyeoTheme.coral.opacity(0.14))
        .clipShape(Circle())
      Text(mode == .maintenance ? "잠시 점검 중이에요" : "무언가 살짝\n잘못됐어요")
        .font(MoyeoTypography.screenTitle).multilineTextAlignment(.center)
      Text(
        mode == .maintenance
          ? "더 안정적인 서비스를 위해 정비하고 있어요."
          : "잠시 후 다시 시도해주세요. 계속 이러면 문의해주세요."
      )
      .font(.subheadline).foregroundStyle(MoyeoTheme.muted).multilineTextAlignment(.center)
      .lineSpacing(4)
      if mode == .maintenance {
        // 점검 중 제약을 목록으로 알려준다 (화면기획).
        //
        // 예전에는 여기에 **「예상 종료 · 오늘 오전 4:00」을 박아 뒀다.** 서버가 알려준 적이 없는
        // 시각이라, 점검이 언제 끝나는지 우리가 지어내 말하고 있었다. 이 화면은 QA 직접 실행으로만
        // 열려 눈에 띄지 않았는데, 503 배선(OFF-013)이 붙어 **실제 사용자에게 보이게 됐다.**
        // 웹은 같은 줄을 이미 지웠다 — `endsAt` 이 있을 때만 그리고 **없으면 아예 안 그린다**
        // (`screens-additions3.jsx:742`, QA W-94). iOS 도 같은 규칙을 따른다.
        // 서버가 종료 시각을 주기 시작하면 그때 `endsAt` 을 받아 첫 줄로 넣으면 된다.
        VStack(alignment: .leading, spacing: 6) {
          ForEach(["점검 중에는 모집·채팅이 열리지 않아요"], id: \.self) { line in
            HStack(alignment: .top, spacing: 8) {
              Circle().fill(MoyeoTheme.text400).frame(width: 4, height: 4).padding(.top, 7)
              Text(line)
                .font(.caption)
                .foregroundStyle(MoyeoTheme.text700)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(MoyeoTheme.subtleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.softLine))
      }
      Spacer()
      VStack(spacing: 8) {
        Button {
          recheck()
        } label: {
          Text(mode == .maintenance ? "지금 확인" : "새로고침")
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: MoyeoTheme.ctaHeight)
            .background(MoyeoTheme.forest)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        if mode == .error {
          // 34 오류 화면의 「돌아가기」 — 새로고침이 안 되면 앞 화면으로 물러나는 유일한 길이다.
          Button {
            dismiss()
          } label: {
            Text("돌아가기")
              .font(.subheadline.weight(.heavy))
              .foregroundStyle(MoyeoTheme.ink)
              .frame(maxWidth: .infinity)
              .frame(height: 50)
              .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
          }
          .buttonStyle(.plain)
        }
        if let footnote = footnoteText {
          Text(footnote)
            .font(.caption2).foregroundStyle(MoyeoTheme.text400).monospacedDigit()
        }
      }
      .padding(.bottom, 20)
    }
    .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(MoyeoTheme.background.ignoresSafeArea())
    .task {
      // 「10분마다 자동으로 다시 확인해요」를 실제로 지킨다 — 예전에는 세던 값을 아무도 읽지 않아
      // 안내만 있고 재확인은 없었다.
      guard mode == .maintenance else { return }
      try? await Task.sleep(nanoseconds: 600_000_000_000)
      guard !Task.isCancelled else { return }
      recheck()
    }
    .accessibilityIdentifier(
      mode == .maintenance ? "screen.systemMaintenance" : "screen.systemError")
  }
}

/// 보조 진입 버튼. 화면기획은 아이콘 없이 초록 외곽선 + 초록 글자다.
/// `icon` 은 호출부 호환을 위해 남겨두지만 그리지 않는다.
private func changelogSecondaryButton(_ title: String, icon: String = "", action: @escaping () -> Void)
  -> some View {
  Button(action: action) {
    Text(title)
      .font(.subheadline.weight(.heavy))
      .foregroundStyle(MoyeoTheme.brandText)
      .frame(maxWidth: .infinity)
      .frame(height: 46)
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.forest))
  }
  .buttonStyle(.plain)
}

/// 선택 항목은 한 덩어리로 붙이지 않고, 눌릴 영역을 분명히 한 카드로 분리한다.
/// 알림 범위·탈퇴 사유·신고 사유가 같은 상호작용 규칙을 공유한다.
/// 라디오 한 줄. 30-2 신고 시트(`ReportScreens.swift`)도 같은 줄을 쓴다 —
/// 사유 목록만 다른 모양으로 그리면 같은 선택 UI 가 화면마다 달라진다.
struct ChangelogRadioOption: View {
  let title: String
  let detail: String?
  let isSelected: Bool
  let action: () -> Void

  init(
    title: String,
    detail: String? = nil,
    isSelected: Bool,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.detail = detail
    self.isSelected = isSelected
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(isSelected ? MoyeoTheme.forest : MoyeoTheme.text400)
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.subheadline.weight(isSelected ? .heavy : .semibold))
            .foregroundStyle(isSelected ? MoyeoTheme.forest : MoyeoTheme.ink)
          if let detail {
            Text(detail)
              .font(.caption2)
              .foregroundStyle(MoyeoTheme.muted)
          }
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 14)
      .frame(maxWidth: .infinity, minHeight: detail == nil ? 48 : 64, alignment: .leading)
      .background(isSelected ? MoyeoTheme.selectionSurface : MoyeoTheme.card)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(isSelected ? MoyeoTheme.forest : MoyeoTheme.line, lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
  }
}

private func infoCard(_ text: String) -> some View {
  Label {
    Text(text).fixedSize(horizontal: false, vertical: true)
  } icon: {
    Image(systemName: "bookmark.fill")
  }
  .font(.caption).foregroundStyle(MoyeoTheme.forest).padding(13).frame(
    maxWidth: .infinity, alignment: .leading
  )
  .background(MoyeoTheme.leaf).clipShape(RoundedRectangle(cornerRadius: 12))
}

private func warningCard(_ text: String) -> some View {
  Label {
    Text(text).fixedSize(horizontal: false, vertical: true)
  } icon: {
    Image(systemName: "exclamationmark.lock.fill")
  }
  .font(.caption).foregroundStyle(MoyeoTheme.coral).padding(13).frame(
    maxWidth: .infinity, alignment: .leading
  )
  .background(MoyeoTheme.coral.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 12))
}

private func actionCard(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
  Button(action: action) {
    HStack(spacing: 11) {
      Image(systemName: icon).frame(width: 38, height: 38).background(MoyeoTheme.leaf).clipShape(
        RoundedRectangle(cornerRadius: 10))
      Text(title).font(.subheadline.weight(.bold))
      Spacer()
      Image(systemName: "chevron.right")
    }
    .foregroundStyle(MoyeoTheme.ink).padding(13).frame(minHeight: 64).background(MoyeoTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: 12)).overlay(
      RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.softLine))
  }.buttonStyle(.plain)
}

private func changelogField(_ title: String, value: String) -> some View {
  VStack(alignment: .leading, spacing: 7) {
    Text(title).font(.caption.weight(.bold)).foregroundStyle(MoyeoTheme.muted)
    Text(value).font(.subheadline.weight(.semibold)).padding(13).frame(
      maxWidth: .infinity, minHeight: 48, alignment: .leading
    ).background(MoyeoTheme.card).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(
      RoundedRectangle(cornerRadius: 10).stroke(MoyeoTheme.softLine))
  }
}

/// 방해금지 시각 한 칸. **누를 수 있는 칸**이다 — 테두리만 그린 정적 `Text` 였을 때는
/// 화면이 고를 수 있는 것처럼 보이면서 실제로는 기본값만 서버로 보냈다.
private func quietHourField(
  label: String, value: String, identifier: String, action: @escaping () -> Void
) -> some View {
  VStack(alignment: .leading, spacing: 6) {
    Text(label).font(.caption.weight(.heavy)).foregroundStyle(MoyeoTheme.ink)
    Button(action: action) {
      HStack(spacing: 6) {
        Text(value)
          .font(.subheadline.weight(.bold))
          .foregroundStyle(MoyeoTheme.ink)
        Spacer(minLength: 0)
        Image(systemName: "clock")
          .font(.caption)
          .foregroundStyle(MoyeoTheme.muted)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 13)
      .frame(height: 48)
      .background(MoyeoTheme.subtleBackground)
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.softLine))
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(identifier)
    .accessibilityLabel("\(label) 시각 \(value)")
  }
}

/// `sheet(item:)` 에 넘길 식별자 — 시작·종료 중 어느 칸을 고치는 중인지.
private enum QuietHourEdit: String, Identifiable {
  case start
  case end

  var id: String { rawValue }
  var sheetTitle: String { self == .start ? "방해금지 시작" : "방해금지 종료" }
}

/// 방해금지 시각 고르기. 서버·화면 모두 `HH:mm` 을 쓴다.
/// (29-1 `ItineraryTimeSheet` 와 같은 꼴이지만 그쪽은 `private` 이라 재사용이 안 된다.)
private struct QuietHourTimeSheet: View {
  let title: String
  let initial: String
  let onPick: (String) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var picked = Date()

  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        DatePicker(title, selection: $picked, displayedComponents: .hourAndMinute)
          .datePickerStyle(.wheel)
          .labelsHidden()
          .environment(\.locale, Locale(identifier: "ko_KR"))
          .accessibilityIdentifier("notificationDetail.timeSheet.picker")
        Spacer()
      }
      .padding(20)
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("취소") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("확인") {
            onPick(Self.text(from: picked))
            dismiss()
          }
          .accessibilityIdentifier("notificationDetail.timeSheet.confirm")
        }
      }
    }
    .presentationDetents([.height(320)])
    .onAppear { picked = Self.date(from: initial) ?? Date() }
  }

  private static func formatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "HH:mm"
    return formatter
  }

  static func date(from text: String) -> Date? { formatter().date(from: String(text.prefix(5))) }

  static func text(from date: Date) -> String { formatter().string(from: date) }
}

private func settingsCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content)
  -> some View {
  VStack(alignment: .leading, spacing: 6) {
    Text(title).font(.caption.weight(.bold)).foregroundStyle(MoyeoTheme.muted)
    VStack(alignment: .leading, spacing: 10) { content() }.padding(14).background(MoyeoTheme.card).clipShape(
      RoundedRectangle(cornerRadius: 12)
    ).overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.softLine))
  }
}
