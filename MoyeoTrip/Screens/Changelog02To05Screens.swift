// swiftlint:disable file_length
import SwiftUI

private struct ChangelogPerson: Identifiable {
  let mascot: String
  let name: String
  let detail: String
  let role: String

  var id: String { name }
}

private struct ChangelogComment: Identifiable {
  let mascot: String
  let name: String
  let badge: String
  let body: String
  let time: String
  var likes: Int = 0
  /// 대댓글. 댓글 구조가 검수되려면 답글까지 보여야 한다.
  var replies: [ChangelogComment] = []

  var id: String { "\(name).\(body)" }
}

enum FriendManagementSegment: String, CaseIterable, Identifiable {
  case mine = "내 친구"
  case received = "받은 신청"
  case sent = "보낸 신청"

  var id: String { rawValue }
}

struct ChatSideMenuView: View {
  let thread: ChatThread
  @State private var notificationsEnabled = true
  @State private var route: SupportRoute?
  @State private var showsLeaveConfirmation: Bool

  init(thread: ChatThread, startsWithLeaveConfirmation: Bool = false) {
    self.thread = thread
    _showsLeaveConfirmation = State(initialValue: startsWithLeaveConfirmation)
  }

  private let members = [
    ChangelogPerson(mascot: "🐻", name: "숲속여행자", detail: "매너 4.8 · 여행 8회", role: "호스트"),
    ChangelogPerson(mascot: "🦌", name: "따스한 사슴 3492", detail: "매너 4.8 · 여행 8회", role: "나"),
    ChangelogPerson(mascot: "🐰", name: "엉뚱한 토끼 1457", detail: "매너 4.8 · 여행 8회", role: ""),
    ChangelogPerson(mascot: "🐢", name: "잔잔한 거북이 9032", detail: "매너 4.8 · 여행 8회", role: ""),
    ChangelogPerson(mascot: "🦝", name: "호기심 많은 너구리 9027", detail: "매너 4.8 · 여행 8회", role: "")
  ]

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 6) {
          Text(thread.tripTitle)
            .font(MoyeoTypography.cardTitle)
            .foregroundStyle(MoyeoTheme.ink)
          Label(thread.courseDisplayName, systemImage: "map.fill")
            .font(.caption.weight(.heavy))
            .foregroundStyle(MoyeoTheme.text700)
          Text("5/25(토) 당일치기 · 08:00 – 18:00")
          Text("07:50 청송 시외버스터미널 정문 앞 집합")
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
              sideConditionPill(thread.priceDisplayText, icon: "wonsign.circle")
              sideConditionPill(
                thread.recruitmentDeadline.isEmpty ? "마감 확인" : "마감 \(thread.recruitmentDeadline)",
                icon: "clock"
              )
              sideConditionPill(thread.ageRangeDisplayText, icon: "person.2")
              sideConditionPill(thread.genderDisplayText, icon: "person.crop.circle")
            }
          }
          HStack(spacing: 8) {
            changelogSecondaryButton("모집 상세") {}
            changelogSecondaryButton("여행 경로") {}
          }
          .padding(.top, 6)
        }
        .font(MoyeoTypography.cardMeta)
        .foregroundStyle(MoyeoTheme.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)

        sectionDivider

        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text("동행자 \(members.count)")
              .font(MoyeoTypography.cardTitle)
            Spacer()
            Text("최대 5명 · 대기 1명")
              .font(MoyeoTypography.cardMeta)
              .foregroundStyle(MoyeoTheme.muted)
          }
          ForEach(members) { member in
            HStack(spacing: 11) {
              MascotAvatar(mascot: member.mascot, size: 38, background: MoyeoTheme.leaf)
              VStack(alignment: .leading, spacing: 2) {
                Text(member.name).font(.subheadline.weight(.bold))
                Text(member.detail)
                  .font(.caption2)
                  .foregroundStyle(MoyeoTheme.muted)
              }
              Spacer()
              if !member.role.isEmpty {
                Text(member.role)
                  .font(.caption2.weight(.bold))
                  .foregroundStyle(MoyeoTheme.forest)
                  .padding(.horizontal, 9)
                  .frame(height: 26)
                  .background(MoyeoTheme.leaf)
                  .clipShape(Capsule())
              } else {
                Image(systemName: "ellipsis")
                  .frame(width: 44, height: 44)
                  .foregroundStyle(MoyeoTheme.muted)
              }
            }
            .frame(minHeight: 54)
          }
          Text("호스트는 멤버 우측 더보기에서 내보내기를 할 수 있어요. 내보낸 자리는 대기 순서대로 자동으로 채워져요.")
            .font(.caption2)
            .foregroundStyle(MoyeoTheme.text400)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
        }
        .padding(18)

        sectionDivider
        menuButton("공지", subtitle: "고정 2개 · 전체 4개", icon: "note.text") {
          route = .noticeHistory(thread.id)
        }
        menuButton("공유된 항목", subtitle: "사진 12 · 장소 4 · 투표 2", icon: "photo.on.rectangle") {
          route = .specialMessages
        }
        HStack(spacing: 12) {
          Image(systemName: "bell")
          VStack(alignment: .leading, spacing: 2) {
            Text("알림 설정").font(.subheadline.weight(.bold))
            Text("이 모임의 알림만 끄기").font(.caption2).foregroundStyle(MoyeoTheme.muted)
          }
          Spacer()
          Toggle("", isOn: $notificationsEnabled)
            .labelsHidden()
            .tint(MoyeoTheme.forest)
        }
        .frame(minHeight: 56)
        .padding(.horizontal, 18)
        menuButton("신고 · 차단", subtitle: "부적절한 대화나 멤버를 신고해요", icon: "flag") {
          route = .report
        }
        sectionDivider
        menuButton(
          "채팅방 나가기",
          subtitle: "나가면 대기 중인 다음 신청자가 자동으로 합류해요",
          icon: "rectangle.portrait.and.arrow.right",
          isDanger: true
        ) {
          showsLeaveConfirmation = true
        }
      }
      .padding(.bottom, 28)
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .navigationTitle("모임 정보")
    .navigationBarTitleDisplayMode(.inline)
    .navigationDestination(item: $route) { SupportDestinationView(route: $0) }
    .alert("채팅방에서 나갈까요?", isPresented: $showsLeaveConfirmation) {
      Button("취소", role: .cancel) {}
      Button("나가기", role: .destructive) {}
    } message: {
      Text("나가면 대기 중인 다음 신청자가 자동으로 합류하고, 이 채팅 기록에는 다시 들어올 수 없어요.")
    }
    .accessibilityIdentifier("screen.chatMenu")
  }

  private var sectionDivider: some View {
    Rectangle().fill(MoyeoTheme.subtleBackground).frame(height: 8)
  }

  private func sideConditionPill(_ title: String, icon: String) -> some View {
    Label(title, systemImage: icon)
      .font(.caption2.weight(.heavy))
      .foregroundStyle(MoyeoTheme.text700)
      .padding(.horizontal, 9)
      .frame(height: 26)
      .background(MoyeoTheme.subtleBackground)
      .overlay(Capsule().stroke(MoyeoTheme.softLine))
      .clipShape(Capsule())
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
          Text(subtitle).font(.caption2).foregroundStyle(
            isDanger ? MoyeoTheme.coral.opacity(0.75) : MoyeoTheme.muted)
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

struct ChatAttachmentMenuView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.moyeoIsOffline) private var isOffline
  @Environment(\.colorScheme) private var colorScheme
  @State private var opensSpecialMessages = false

  private let items = [
    ChangelogPerson(mascot: "camera.fill", name: "사진", detail: "최대 20MB · 1장씩 전송", role: ""),
    ChangelogPerson(mascot: "mappin.and.ellipse", name: "장소", detail: "TourAPI 장소 카드", role: ""),
    ChangelogPerson(mascot: "map.fill", name: "지도", detail: "만날 위치 핀 공유", role: ""),
    ChangelogPerson(mascot: "chart.bar.xaxis", name: "투표", detail: "2~5개 · 익명 기본", role: ""),
    ChangelogPerson(mascot: "creditcard.fill", name: "정산", detail: "메모용 · 송금 아님", role: ""),
    ChangelogPerson(mascot: "note.text", name: "메모", detail: "상단 고정 공지 (호스트)", role: "")
  ]

  var body: some View {
    // 시트는 화면 바닥에 붙는다. 가운데 떠 있으면 바텀시트로 읽히지 않는다.
    VStack(alignment: .leading, spacing: 0) {
      Spacer(minLength: 0)
      sheet
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    // 바텀시트 뒤의 대화 화면은 항상 읽을 수 없을 만큼만 어둡게 남겨 둔다.
    // 투명한 네비게이션 배경을 그대로 쓰면 라이트 모드에서 흰 화면으로 비어 보인다.
    .background(
      MoyeoTheme.ink
        .opacity(colorScheme == .dark ? 0.56 : 0.40)
        .ignoresSafeArea()
    )
    .navigationDestination(isPresented: $opensSpecialMessages) { SpecialMessageCardsView() }
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
            opensSpecialMessages = true
          } label: {
            VStack(spacing: 6) {
              Image(systemName: item.mascot)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isOffline ? MoyeoTheme.text400 : MoyeoTheme.forest)
                .frame(width: 44, height: 44)
                .background(MoyeoTheme.leaf)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
              Text(item.name).font(.caption.weight(.bold)).foregroundStyle(MoyeoTheme.ink)
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
      Button { dismiss() } label: {
        Text("닫기")
          .font(.subheadline.weight(.bold))
          .foregroundStyle(MoyeoTheme.ink)
          .frame(maxWidth: .infinity, minHeight: 48)
          .background(MoyeoTheme.subtleBackground)
          .clipShape(RoundedRectangle(cornerRadius: 12))
      }
      .buttonStyle(.plain)
      .padding(.top, 16)
      .accessibilityIdentifier("chatAttach.close")
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 28)
    .padding(.top, 2)
    .frame(maxWidth: .infinity)
    .background(
      MoyeoTheme.card
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .ignoresSafeArea(edges: .bottom)
    )
  }
}

struct FriendsManagementView: View {
  @State private var segment: FriendManagementSegment = .mine
  @State private var rejected = Set<String>()
  @State private var accepted = Set<String>()

  private let mine = [
    ChangelogPerson(mascot: "🐻", name: "우직한 곰 7821", detail: "함께 여행 3회 · 어제 접속", role: ""),
    ChangelogPerson(mascot: "🐰", name: "엉뚱한 토끼 1457", detail: "함께 여행 1회 · 3일 전 접속", role: ""),
    ChangelogPerson(mascot: "🐢", name: "잔잔한 거북이 9032", detail: "함께 여행 2회 · 오늘 접속", role: "")
  ]
  private let received = [
    ChangelogPerson(mascot: "🦝", name: "호기심 많은 너구리 9027", detail: "포항·영덕 드라이브에서 만났어요", role: ""),
    ChangelogPerson(mascot: "🕊️", name: "고요한 두루미 1130", detail: "경주 단풍·야경에서 만났어요", role: "")
  ]
  private let sent = [
    ChangelogPerson(mascot: "🦌", name: "따스한 사슴 3492", detail: "어제 신청 · 수락 대기 중", role: "")
  ]

  private var items: [ChangelogPerson] {
    switch segment {
    case .mine: mine
    case .received: received
    case .sent: sent
    }
  }

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
      ScrollView {
        VStack(spacing: 0) {
          if segment == .received {
            Text("거절해도 상대방에게는 알려지지 않아요.")
              .font(.caption)
              .foregroundStyle(MoyeoTheme.muted)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 10)
          }
          ForEach(items) { item in
            if !rejected.contains(item.name) {
              friendRow(item)
            }
          }
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
    .toolbar {
      Button {
      } label: {
        Image(systemName: "magnifyingglass")
      }.accessibilityLabel("친구 검색")
    }
    .accessibilityIdentifier("screen.friends")
  }

  private func friendRow(_ item: ChangelogPerson) -> some View {
    HStack(spacing: 12) {
      MascotAvatar(mascot: item.mascot, size: 44, background: MoyeoTheme.leaf)
      VStack(alignment: .leading, spacing: 3) {
        Text(item.name).font(.subheadline.weight(.bold))
        Text(item.detail).font(.caption2).foregroundStyle(MoyeoTheme.muted)
      }
      Spacer()
      if segment == .received {
        Button("거절") { rejected.insert(item.name) }.buttonStyle(.bordered).controlSize(.small)
        Button(accepted.contains(item.name) ? "수락됨" : "수락") { accepted.insert(item.name) }
          .buttonStyle(.borderedProminent).controlSize(.small).tint(MoyeoTheme.forest)
          .disabled(accepted.contains(item.name))
      } else if segment == .sent {
        Text("요청 중").font(.caption.weight(.bold)).foregroundStyle(MoyeoTheme.muted)
          .padding(.horizontal, 10).frame(height: 30).background(MoyeoTheme.subtleBackground)
          .clipShape(Capsule())
      } else {
        Image(systemName: "ellipsis").frame(width: 44, height: 44).foregroundStyle(MoyeoTheme.muted)
      }
    }
    .frame(minHeight: 68)
  }

  private func count(for segment: FriendManagementSegment) -> Int {
    switch segment {
    case .mine: mine.count
    case .received: received.count
    case .sent: sent.count
    }
  }
}

struct TripMessageView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var messages = ["우직한 곰 7821": "핑크뮬리 사진 잘 찍어주셔서 고마워요!"]
  @State private var draftByName: [String: String] = [:]
  @State private var route: SupportRoute?
  private let mates = [("🐻", "우직한 곰 7821"), ("🐰", "엉뚱한 토끼 1457"), ("🐢", "잔잔한 거북이 9032")]
  private let presets = ["덕분에 즐거웠어요", "사진 고마워요!", "다음에도 잘 부탁드려요"]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("함께 걸어준 친구들에게\n한 줄 남겨볼까요?")
          .font(MoyeoTypography.screenTitle)
          .foregroundStyle(MoyeoTheme.ink)
        Text("남긴 메시지는 상대방의 도감 카드 뒷면에 적혀요. 안 남겨도 카드는 그대로 모여요.")
          .font(.subheadline)
          .foregroundStyle(MoyeoTheme.muted)
        ForEach(mates, id: \.1) { mate in messageCard(mate) }
        infoCard("메시지를 남기면 서로의 도감 카드가 완성돼요. 가끔 도감을 펼쳐 보면 그날의 여행이 다시 떠올라요.")
        actionCard("피드에 오늘의 여행 기록 남기기", icon: "doc.text.image") {}
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
          // 입력해 둔 한 줄을 모두 저장하고 도감으로 넘어간다
          for (name, draft) in draftByName {
            let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { messages[name] = value }
          }
          dismiss()
        } label: {
          Text("메시지 남기고 도감 보기")
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(MoyeoTheme.forest)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tripMessage.saveAndOpenDex")
      }
      .padding(.horizontal, 18)
      .padding(.top, 8)
      .padding(.bottom, 12)
      .background(MoyeoTheme.card)
      .overlay(alignment: .top) { Rectangle().fill(MoyeoTheme.softLine).frame(height: 1) }
    }
    .navigationDestination(item: $route) { SupportDestinationView(route: $0) }
    .accessibilityIdentifier("screen.tripMessage")
  }

  private func messageCard(_ mate: (String, String)) -> some View {
    let done = messages[mate.1] != nil
    return VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        MascotAvatar(mascot: mate.0, size: 40, background: MoyeoTheme.leaf)
        VStack(alignment: .leading, spacing: 2) {
          Text(mate.1).font(.subheadline.weight(.bold))
          Text(done ? "메시지를 남겼어요" : "아직 안 남겼어요").font(.caption2).foregroundStyle(MoyeoTheme.muted)
        }
        Spacer()
        if done { Image(systemName: "checkmark.circle.fill").foregroundStyle(MoyeoTheme.forest) }
      }
      if done {
        Text(messages[mate.1] ?? "").font(.subheadline).padding(12).frame(
          maxWidth: .infinity, alignment: .leading
        )
        .background(MoyeoTheme.background).clipShape(RoundedRectangle(cornerRadius: 10))
      } else {
        TextField(
          "한 줄 메시지를 남겨주세요 (최대 40자)",
          text: Binding(
            get: { draftByName[mate.1] ?? "" },
            set: { draftByName[mate.1] = String($0.prefix(40)) }
          )
        )
        .padding(12).frame(minHeight: 46).background(MoyeoTheme.subtleBackground).clipShape(
          RoundedRectangle(cornerRadius: 10))
        ScrollView(.horizontal, showsIndicators: false) {
          HStack {
            ForEach(presets, id: \.self) { preset in
              Button(preset) { draftByName[mate.1] = preset }.buttonStyle(.bordered).controlSize(
                .small)
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

struct ReportView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var reason = "성희롱 · 불쾌한 언행"
  @State private var blocksUser = true
  private let reasons = ["스팸 · 도박", "성희롱 · 불쾌한 언행", "돈거래 유도", "허위 정보", "부적절한 내용", "기타"]

  var body: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 0)
      VStack(alignment: .leading, spacing: 10) {
        Capsule()
          .fill(MoyeoTheme.softLine)
          .frame(width: 36, height: 4)
          .frame(maxWidth: .infinity)
          .padding(.bottom, 4)
        Text("신고 사유를 알려주세요")
          .font(MoyeoTypography.sectionTitle)
        Label("해당 메시지 · “계좌로 먼저 보내주시면…”", systemImage: "bubble.left")
          .font(.caption)
          .padding(.horizontal, 12)
          .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
          .background(MoyeoTheme.subtleBackground)
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        ForEach(reasons, id: \.self) { item in
          ChangelogRadioOption(title: item, isSelected: reason == item) {
            reason = item
          }
        }
        MoyeoCheckRow(
          title: "이 유저를 차단할게요",
          isOn: $blocksUser,
          accessibilityIdentifier: "report.blockUser"
        )
        if blocksUser {
          Text("차단하면 이 유저가 만들었거나 참여한 모집이 홈·탐색에서 모두 숨겨져요.")
            .font(.caption2)
            .foregroundStyle(MoyeoTheme.muted)
        }
        // 취소는 좁은 중립 글자, 신고하기는 넓은 채움 — 둘을 같은 너비로 두면 위계가 사라진다 (화면기획)
        HStack(spacing: 8) {
          Button("취소") { dismiss() }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(MoyeoTheme.ink)
            .frame(width: 62, height: 48)
            .accessibilityIdentifier("report.cancel")
          Button { dismiss() } label: {
            Text("신고하기")
              .font(.subheadline.weight(.heavy))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .frame(height: 48)
              .background(MoyeoTheme.coral)
              .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("report.submit")
        }
        Text("24시간 이내에 검토해 드릴게요.")
          .font(.caption2)
          .foregroundStyle(MoyeoTheme.text400)
          .frame(maxWidth: .infinity)
          .padding(.top, 1)
      }
      .padding(.horizontal, 20)
      .padding(.top, 12)
      .padding(.bottom, 28)
      .background(MoyeoTheme.card)
      .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    .background(MoyeoTheme.ink.opacity(0.56).ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
    .accessibilityIdentifier("screen.report")
  }
}

struct BlockedUsersView: View {
  @State private var blocked = [
    ChangelogPerson(
      mascot: "🦝", name: "말많은 너구리 7791", detail: "2026.07.28 차단 · 채팅방에서 신고와 함께 차단", role: ""),
    ChangelogPerson(
      mascot: "🕊️", name: "청아한 두루미 2024", detail: "2026.06.02 차단 · 프로필에서 차단", role: "")
  ]

  var body: some View {
    ScrollView {
      VStack(spacing: 10) {
        infoCard("차단하면 그 사람이 만들었거나 참여한 모집이 홈·탐색·코스 상세에서 모두 숨겨져요. 상대방에게는 알려지지 않아요.")
        ForEach(blocked) { user in
          HStack(spacing: 12) {
            MascotAvatar(mascot: user.mascot, size: 42, background: MoyeoTheme.subtleBackground)
            VStack(alignment: .leading, spacing: 3) {
              Text(user.name).font(.subheadline.weight(.bold))
              Text(user.detail).font(.caption2).foregroundStyle(MoyeoTheme.muted)
            }
            Spacer()
            Button {
              blocked.removeAll { $0.name == user.name }
            } label: {
              Text("차단 해제")
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(MoyeoTheme.line))
            }
            .buttonStyle(.plain)
          }.frame(minHeight: 64)
        }
        Text("차단을 해제하면 서로의 모집·피드를 다시 볼 수 있어요. 해제 전에 한 번 더 확인해요.")
          .font(.caption).foregroundStyle(MoyeoTheme.text400).frame(
            maxWidth: .infinity, alignment: .leading)
      }.padding(18)
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .navigationTitle("차단한 사용자")
    .navigationBarTitleDisplayMode(.inline)
    .accessibilityIdentifier("screen.blockedUsers")
  }
}

struct CoursePublishView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var showsConfirmation = false
  @State private var showsFinalConfirmation = false
  @State private var showsNickname = true
  @State private var isPublished = false

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
        publishPreview

        if !isPublished {
          publishField(
            "코스 이름", icon: "note.text", value: "주왕산 & 주산지 힐링 트레킹", required: true
          )
          .padding(.top, 18)
          publishField(
            "한 줄 소개",
            icon: "sparkles",
            value: "기암절벽과 주산지 물안개를 천천히 걷는 코스",
            caption: "다녀온 사람만 쓸 수 있는 한 줄이 코스의 값어치예요."
          )
          .padding(.top, 16)
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
        HStack(spacing: 8) {
          Button("지금은 안 할래요") { dismiss() }.buttonStyle(.bordered).frame(
            maxWidth: .infinity, minHeight: 50)
          Button("코스 공개하기") { showsConfirmation = true }.buttonStyle(.borderedProminent).tint(
            MoyeoTheme.forest
          ).frame(maxWidth: .infinity, minHeight: 50)
        }.padding(12).background(MoyeoTheme.card)
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
      Button("공개할게요") { isPublished = true }
      Button("취소", role: .cancel) {}
    } message: {
      Text("공개한 코스는 비공개로 되돌릴 수 없습니다.")
    }
    .accessibilityIdentifier("screen.coursePublish")
  }

  private var publishPreview: some View {
    VStack(alignment: .leading, spacing: 0) {
      ZStack(alignment: .bottomLeading) {
        MoyeoPhotoTile(mascot: "🌲", mood: .forest, height: 132, cornerRadius: 0)
        Label("여행자 코스", systemImage: "person.fill")
          .font(MoyeoTypography.font(size: 11, weight: .heavy, relativeTo: .caption2))
          .foregroundStyle(MoyeoTheme.forest)
          .padding(.horizontal, 10)
          .frame(height: 26)
          .background(MoyeoTheme.elevatedCard.opacity(0.94))
          .clipShape(Capsule())
          .padding(12)
      }
      VStack(alignment: .leading, spacing: 0) {
        Text("주왕산 & 주산지 힐링 트레킹")
          .font(MoyeoTypography.font(size: 14, weight: .heavy, relativeTo: .subheadline))
        Text("청송 · 당일 6.2km · 방문지 4")
          .font(MoyeoTypography.font(size: 11.5, relativeTo: .caption))
          .foregroundStyle(MoyeoTheme.muted)
          .padding(.top, 5)
        HStack(spacing: 7) {
          MascotAvatar(mascot: "🐻", size: 22, background: MoyeoTheme.leaf)
          Text(showsNickname ? "숲속여행자 님이 다녀온 코스" : "익명 여행자가 다녀온 코스")
            .font(MoyeoTypography.font(size: 11.5, weight: .semibold, relativeTo: .caption))
            .foregroundStyle(MoyeoTheme.text700)
        }
        .padding(.top, 10)
      }
      .padding(14)
    }
    .background(MoyeoTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .overlay(RoundedRectangle(cornerRadius: 16).stroke(MoyeoTheme.softLine))
  }

  private func publishField(
    _ title: String,
    icon: String,
    value: String,
    required: Bool = false,
    caption: String? = nil
  ) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: 4) {
        Text(title)
        if required { Text("*").foregroundStyle(MoyeoTheme.coral) }
      }
      .font(MoyeoTypography.font(size: 12, weight: .heavy, relativeTo: .caption))
      .foregroundStyle(MoyeoTheme.muted)
      HStack(spacing: 9) {
        Image(systemName: icon)
          .font(.caption)
          .foregroundStyle(MoyeoTheme.forest)
        Text(value)
          .font(MoyeoTypography.font(size: 12.5, weight: .semibold, relativeTo: .subheadline))
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 13)
      .frame(minHeight: 46)
      .background(MoyeoTheme.card)
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .overlay(RoundedRectangle(cornerRadius: 10).stroke(MoyeoTheme.softLine))
      if let caption {
        Text(caption)
          .font(MoyeoTypography.font(size: 10.5, relativeTo: .caption2))
          .foregroundStyle(MoyeoTheme.muted)
      }
    }
  }
}

struct TripDayView: View {
  let thread: ChatThread
  @State private var draft = ""
  @State private var messages: [ChatMessage]
  @State private var route: SupportRoute?

  init(thread: ChatThread) {
    self.thread = thread
    _messages = State(initialValue: thread.messages)
  }

  var body: some View {
    VStack(spacing: 0) {
      Text("여행 중 · 5명 · 오늘 08:00 출발")
        .font(MoyeoTypography.font(size: 12, weight: .semibold, relativeTo: .caption))
        .foregroundStyle(MoyeoTheme.muted)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(MoyeoTheme.softLine).frame(height: 1) }

      tripProgress

      ScrollView {
        VStack(spacing: 14) {
          Text("오늘 여행이 시작됐어요 🎒")
            .font(MoyeoTypography.font(size: 12, weight: .heavy, relativeTo: .caption))
            .foregroundStyle(MoyeoTheme.forest)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(MoyeoTheme.leaf)
            .clipShape(RoundedRectangle(cornerRadius: 8))
          MessageBubble(
            message: ChatMessage(
              id: "trip-day-arrival",
              senderName: "엉뚱한 토끼 1457",
              avatar: "🐰",
              body: "주왕산 3폭포 도착! 생각보다 사람 적어요 👍",
              time: "방금",
              isMine: false
            ),
            isPending: false
          )
          TripDayLocationCard()
            .padding(.leading, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
          MessageBubble(
            message: ChatMessage(
              id: "trip-day-mine",
              senderName: "나",
              avatar: "🦌",
              body: "저는 주차장에서 기다릴게요~",
              time: "방금",
              isMine: true
            ),
            isPending: false
          )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
      }
      HStack(spacing: 8) {
        Button {
          route = .chatAttach(thread.id)
        } label: {
          Image(systemName: "plus").frame(width: 44, height: 44)
        }.buttonStyle(.plain)
        TextField("메시지 입력", text: $draft).padding(.horizontal, 12).frame(minHeight: 44).background(
          MoyeoTheme.subtleBackground
        ).clipShape(Capsule())
        Button {
          send()
        } label: {
          Image(systemName: "paperplane.fill").foregroundStyle(.white).frame(width: 44, height: 44)
            .background(MoyeoTheme.forest).clipShape(Circle())
        }.buttonStyle(.plain).disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
      }.padding(12).background(MoyeoTheme.card)
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .navigationTitle(thread.tripTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        Button {} label: { Image(systemName: "magnifyingglass") }
          .accessibilityLabel("대화 검색")
        Button {
          route = .chatMenu(thread.id)
        } label: {
          Image(systemName: "line.3.horizontal")
        }.accessibilityLabel("모임 정보")
      }
    }
    .navigationDestination(item: $route) { SupportDestinationView(route: $0) }
    .accessibilityIdentifier("screen.tripDay")
  }

  private func send() {
    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    messages.append(
      ChatMessage(
        id: UUID().uuidString, senderName: "나", avatar: "🦌", body: trimmed, time: "방금", isMine: true
      ))
    draft = ""
  }

  private var tripProgress: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: "mappin.and.ellipse")
          .font(.caption)
          .foregroundStyle(MoyeoTheme.forest)
        Text("현재 방문지 2/4 · 주왕산")
          .font(MoyeoTypography.font(size: 12.5, weight: .heavy, relativeTo: .caption))
          .foregroundStyle(MoyeoTheme.forest)
        Spacer()
        Text("코스 전체 →")
          .font(MoyeoTypography.font(size: 11, weight: .bold, relativeTo: .caption2))
          .foregroundStyle(MoyeoTheme.forest)
      }
      HStack(spacing: 0) {
        dayStep("청송터미널", 1, done: true)
        dayLine(done: true)
        dayStep("주왕산", 2, done: true)
        dayLine(done: false)
        dayStep("주산지", 3, done: false)
        dayLine(done: false)
        dayStep("달기약수탕", 4, done: false)
      }
      HStack(spacing: 6) {
        Image(systemName: "clock")
          .font(.caption)
          .foregroundStyle(MoyeoTheme.forest)
        Text("다음 일정 · ")
        Text("14:00 주산지").fontWeight(.heavy)
        Text("왕버들 산책로")
      }
      .font(MoyeoTypography.font(size: 11.5, relativeTo: .caption))
      .foregroundStyle(MoyeoTheme.forest)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(MoyeoTheme.leaf)
    .overlay(alignment: .bottom) { Rectangle().fill(MoyeoTheme.softLine).frame(height: 1) }
    .accessibilityIdentifier("tripDay.progress")
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
}

private struct TripDayLocationCard: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      GeometryReader { proxy in
        ZStack {
          MoyeoTheme.leaf
          Path { path in
            path.move(to: CGPoint(x: 0, y: proxy.size.height * 0.72))
            path.addCurve(
              to: CGPoint(x: proxy.size.width, y: proxy.size.height * 0.28),
              control1: CGPoint(x: proxy.size.width * 0.30, y: proxy.size.height * 0.54),
              control2: CGPoint(x: proxy.size.width * 0.68, y: proxy.size.height * 0.46)
            )
          }
          .stroke(MoyeoTheme.forest, style: StrokeStyle(lineWidth: 4, lineCap: .round))
          Image(systemName: "mappin.circle.fill")
            .foregroundStyle(MoyeoTheme.coral)
            .position(x: proxy.size.width * 0.68, y: proxy.size.height * 0.42)
        }
      }
      .frame(height: 92)
      VStack(alignment: .leading, spacing: 3) {
        Text("주산지 주차장")
          .font(MoyeoTypography.font(size: 12.5, weight: .heavy, relativeTo: .caption))
        Text("14:00 도착 예정 · 차로 22분")
          .font(MoyeoTypography.font(size: 11, relativeTo: .caption2))
          .foregroundStyle(MoyeoTheme.muted)
        Text("길 찾기 →")
          .font(MoyeoTypography.font(size: 11, weight: .bold, relativeTo: .caption2))
          .foregroundStyle(MoyeoTheme.forest)
          .padding(.top, 5)
      }
      .padding(11)
    }
    .frame(maxWidth: 268)
    .background(MoyeoTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .overlay(RoundedRectangle(cornerRadius: 14).stroke(MoyeoTheme.softLine))
    .accessibilityIdentifier("tripDay.locationCard")
  }
}

struct NotificationDetailView: View {
  @State private var mode = "모든 메시지"
  @State private var quietHours = true
  @State private var quietDays = Set(["월", "화", "수", "목", "금"])
  private let modes = ["모든 메시지", "멘션·답글만", "받지 않기"]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 8) {
          Text("알림 범위")
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(MoyeoTheme.ink)
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
            }
          }
        }
        settingsCard("방해금지 시간대") {
          MoyeoCheckRow(
            title: "방해금지 시간대",
            subtitle: "이 시간엔 소리·진동 없이 조용히 쌓여요",
            isOn: $quietHours,
            accessibilityIdentifier: "notificationDetail.quietHours"
          )
          if quietHours {
            HStack(spacing: 10) {
              quietHourField(label: "시작", value: "22:30")
              quietHourField(label: "종료", value: "07:00")
            }
            VStack(alignment: .leading, spacing: 6) {
              Text("요일").font(.caption.weight(.heavy)).foregroundStyle(MoyeoTheme.ink)
              HStack(spacing: 6) {
                ForEach(["월", "화", "수", "목", "금", "토", "일"], id: \.self) { day in
                  let on = quietDays.contains(day)
                  Button {
                    if on { quietDays.remove(day) } else { quietDays.insert(day) }
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
              }
            }
            Text("집합 30분 전 알림처럼 여행 당일 안내는 방해금지 시간에도 전달돼요.")
              .font(.caption2).foregroundStyle(MoyeoTheme.muted)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        infoCard("방해금지 중에도 여행 당일 일정 변경과 안전 관련 알림은 받을 수 있어요.")
      }.padding(18).padding(.bottom, 28)
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .navigationTitle("채팅 알림")
    .navigationBarTitleDisplayMode(.inline)
    .accessibilityIdentifier("screen.notificationDetail")
  }

  private func modeDetail(for mode: String) -> String {
    switch mode {
    case "모든 메시지": "모임의 모든 대화를 알려드려요"
    case "멘션·답글만": "나를 부르거나 내 메시지에 답할 때만"
    default: "앱을 열었을 때만 확인해요"
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
  // 화면기획과 같은 사유·삭제범위·참여 목록
  private let reasons = ["여행을 자주 가지 않게 됐어요", "마음에 드는 모집이 없어요", "불쾌한 경험이 있었어요", "알림이 너무 많아요", "기타"]
  private let joinedTrips = ["주왕산 & 주산지 힐링 트레킹 · D-2", "포항·영덕 동해 드라이브 · D-9"]
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
        // 참여 중인 여행을 목록으로 보여준다 — 어떤 여행을 정리해야 하는지 이 화면에서 알아야 한다 (화면기획)
        VStack(alignment: .leading, spacing: 10) {
          Label("참여 중인 여행이 \(joinedTrips.count)개 있어요", systemImage: "person.2.fill")
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(MoyeoTheme.warningText)
          Text("탈퇴하면 동행자들에게 갑자기 빈자리가 생겨요. 나가기 처리를 먼저 해주세요.")
            .font(.caption)
            .foregroundStyle(MoyeoTheme.warningText)
            .fixedSize(horizontal: false, vertical: true)
          ForEach(joinedTrips, id: \.self) { trip in
            HStack(spacing: 8) {
              Image(systemName: "calendar")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MoyeoTheme.warningText)
              Text(trip)
                .font(.caption.weight(.bold))
                .foregroundStyle(MoyeoTheme.ink)
              Spacer(minLength: 0)
              Text("관리 →")
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.warningText)
            }
            .padding(11)
            .background(MoyeoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
          }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoyeoTheme.warningBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityIdentifier("accountDelete.joinedTrips")

        VStack(alignment: .leading, spacing: 4) {
          Text("떠나는 이유를 알려주세요").font(.subheadline.weight(.heavy)).foregroundStyle(MoyeoTheme.ink)
          Text("서비스를 고치는 데만 쓰여요. (필수)").font(.caption).foregroundStyle(MoyeoTheme.muted)
        }
        VStack(spacing: 8) {
          ForEach(reasons, id: \.self) { item in
            ChangelogRadioOption(title: item, isSelected: reason == item) {
              reason = item
            }
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

  private func deleteAccount() {
    isDeleting = true
    Task {
      do {
        try await AuthAccountService().withdraw()
        onDeleted()
      } catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? "잠시 후 다시 시도해주세요." }
      isDeleting = false
    }
  }
}

enum SystemNoticeMode { case maintenance, error }

struct SystemNoticeView: View {
  let mode: SystemNoticeMode
  @State private var retryCount = 0

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
        // 점검 중 제약을 목록으로 알려준다 (화면기획)
        VStack(alignment: .leading, spacing: 6) {
          ForEach(["예상 종료 · 오늘 오전 4:00", "점검 중에는 모집·채팅이 열리지 않아요"], id: \.self) { line in
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
          retryCount += 1
        } label: {
          Text(mode == .maintenance ? "지금 확인" : "새로고침")
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(MoyeoTheme.forest)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        if mode == .error {
          Button {} label: {
            Text("돌아가기")
              .font(.subheadline.weight(.heavy))
              .foregroundStyle(MoyeoTheme.ink)
              .frame(maxWidth: .infinity)
              .frame(height: 50)
              .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
          }
          .buttonStyle(.plain)
        }
        Text(mode == .maintenance ? "10분마다 자동으로 다시 확인해요" : "ERR-500 · 2026-08-17 14:22")
          .font(.caption2).foregroundStyle(MoyeoTheme.text400).monospacedDigit()
      }
      .padding(.bottom, 20)
    }
    .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(MoyeoTheme.background.ignoresSafeArea())
    .task {
      guard mode == .maintenance else { return }
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 600_000_000_000)
        guard !Task.isCancelled else { return }
        retryCount += 1
      }
    }
    .accessibilityIdentifier(
      mode == .maintenance ? "screen.systemMaintenance" : "screen.systemError")
  }
}

struct FeedCommentsView: View {
  let post: FeedPost
  @State private var comment = ""
  @State private var submitted: [String] = []
  @State private var route: SupportRoute?

  private let comments = [
    ChangelogComment(
      mascot: "🐰", name: "엉뚱한 토끼 1457", badge: "함께 간 친구",
      body: "이날 진짜 좋았어요! 주산지 물안개 사진 저도 올릴게요 📷", time: "2시간 전", likes: 4,
      replies: [
        ChangelogComment(
          mascot: "🐻", name: "숲속여행자", badge: "작성자",
          body: "토끼님 사진이 훨씬 잘 나왔어요 ㅎㅎ", time: "1시간 전")
      ]),
    ChangelogComment(
      mascot: "🐢", name: "잔잔한 거북이 9032", badge: "함께 간 친구",
      body: "달기약수탕 백숙 진짜 맛있었죠", time: "3시간 전", likes: 2),
    ChangelogComment(
      mascot: "🕊", name: "고요한 두루미 1130", badge: "",
      body: "이 코스 저도 가보고 싶네요. 당일치기로 충분할까요?", time: "5시간 전", likes: 1,
      replies: [
        ChangelogComment(
          mascot: "🐻", name: "숲속여행자", badge: "작성자",
          body: "네 08시 출발이면 여유로워요!", time: "4시간 전")
      ])
  ]

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(comments) { item in
            commentRow(item)
            // 대댓글은 들여쓰기로 부모와의 관계를 보여준다
            ForEach(item.replies) { reply in
              commentRow(reply, compact: true)
                .padding(.leading, 32)
            }
          }
          ForEach(submitted, id: \.self) { item in
            commentRow(ChangelogComment(mascot: "🦌", name: "나", badge: "", body: item, time: "방금"))
          }
          Text("함께 간 친구의 댓글이 먼저 보여요")
            .font(.caption2)
            .foregroundStyle(MoyeoTheme.text400)
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
        }.padding(.horizontal, 18)
      }
      HStack(spacing: 8) {
        TextField("댓글을 입력하세요...", text: $comment, axis: .vertical).lineLimit(1...4).padding(
          .horizontal, 13
        ).frame(minHeight: 44).background(MoyeoTheme.subtleBackground).clipShape(Capsule())
        Button {
          submit()
        } label: {
          Image(systemName: "paperplane.fill").foregroundStyle(.white).frame(width: 44, height: 44)
            .background(MoyeoTheme.forest).clipShape(Circle())
        }.buttonStyle(.plain).disabled(
          comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }.padding(12).background(MoyeoTheme.card)
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .navigationTitle("댓글 \(post.commentCount + submitted.count)")
    .navigationBarTitleDisplayMode(.inline)
    .navigationDestination(item: $route) { SupportDestinationView(route: $0) }
    .accessibilityIdentifier("screen.feedComments")
  }

  private func commentRow(_ item: ChangelogComment, compact: Bool = false) -> some View {
    HStack(alignment: .top, spacing: 11) {
      MascotAvatar(mascot: item.mascot, size: compact ? 30 : 38, background: MoyeoTheme.leaf)
      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 6) {
          Text(item.name).font(.subheadline.weight(.bold))
          if !item.badge.isEmpty {
            Text(item.badge).font(.system(size: 9.5, weight: .bold)).foregroundStyle(
              MoyeoTheme.forest
            )
            .padding(.horizontal, 7).frame(height: 21).background(MoyeoTheme.leaf).clipShape(
              Capsule())
          }
          Spacer()
          Text(item.time).font(.caption2).foregroundStyle(MoyeoTheme.text400)
        }
        Text(item.body).font(.subheadline).foregroundStyle(MoyeoTheme.ink)
        HStack(spacing: 14) {
          HStack(spacing: 4) {
            Image(systemName: "heart").font(.system(size: 12, weight: .semibold))
            if item.likes > 0 { Text("\(item.likes)") }
          }
          Button("답글 달기") {}
          Button("신고") { route = .report }
        }.font(.caption.weight(.bold)).foregroundStyle(MoyeoTheme.muted).frame(minHeight: 30)
      }
    }.padding(.vertical, 12).overlay(alignment: .bottom) {
      Rectangle().fill(MoyeoTheme.softLine).frame(height: 1)
    }
  }

  private func submit() {
    let value = comment.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return }
    submitted.append(value)
    comment = ""
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
private struct ChangelogRadioOption: View {
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

private func quietHourField(label: String, value: String) -> some View {
  VStack(alignment: .leading, spacing: 6) {
    Text(label).font(.caption.weight(.heavy)).foregroundStyle(MoyeoTheme.ink)
    Text(value)
      .font(.subheadline.weight(.bold))
      .foregroundStyle(MoyeoTheme.ink)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 13)
      .frame(height: 48)
      .background(MoyeoTheme.subtleBackground)
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.softLine))
  }
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
