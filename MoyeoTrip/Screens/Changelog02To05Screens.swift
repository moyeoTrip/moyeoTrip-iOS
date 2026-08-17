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
          Text("5/25(토) 당일치기 · 08:00 – 18:00")
          Text("07:50 청송 시외버스터미널 정문 앞 집합")
          HStack(spacing: 8) {
            changelogSecondaryButton("모집 상세", icon: "doc.text") {}
            changelogSecondaryButton("여행 경로", icon: "map") {}
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
            Text("동행자 (members.count)")
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
        ) {}
      }
      .padding(.bottom, 28)
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .navigationTitle("모임 정보")
    .navigationBarTitleDisplayMode(.inline)
    .navigationDestination(item: $route) { SupportDestinationView(route: $0) }
    .accessibilityIdentifier("screen.chatMenu")
  }

  private var sectionDivider: some View {
    Rectangle().fill(MoyeoTheme.subtleBackground).frame(height: 8)
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
      Button("닫기") { dismiss() }
        .font(.subheadline.weight(.bold))
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(MoyeoTheme.subtleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 16)
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 28)
    .background(MoyeoTheme.card.ignoresSafeArea())
    .navigationDestination(isPresented: $opensSpecialMessages) { SpecialMessageCardsView() }
    .accessibilityIdentifier("screen.chatAttach")
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
          infoCard("함께 여행한 친구는 친구가 아니어도 도감에 남아요. 친구 신청은 피드를 구독하고 싶을 때만 하면 돼요.")
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
      .padding(.bottom, 28)
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .navigationTitle("여행 마무리")
    .navigationBarTitleDisplayMode(.inline)
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
        Button("메시지 남기기") {
          let value = draftByName[mate.1, default: ""].trimmingCharacters(
            in: .whitespacesAndNewlines)
          if !value.isEmpty { messages[mate.1] = value }
        }
        .buttonStyle(.borderedProminent).tint(MoyeoTheme.forest).frame(minHeight: 44)
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
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("신고 사유를 알려주세요").font(MoyeoTypography.sectionTitle)
        Label("해당 메시지 · “계좌로 먼저 보내주시면…”", systemImage: "bubble.left")
          .font(.caption).padding(12).frame(maxWidth: .infinity, alignment: .leading)
          .background(MoyeoTheme.subtleBackground).clipShape(RoundedRectangle(cornerRadius: 10))
        ForEach(reasons, id: \.self) { item in
          Button {
            reason = item
          } label: {
            HStack {
              Image(systemName: reason == item ? "checkmark.circle.fill" : "circle")
              Text(item).font(.subheadline.weight(reason == item ? .bold : .regular))
              Spacer()
            }
            .foregroundStyle(reason == item ? MoyeoTheme.forest : MoyeoTheme.ink)
            .padding(.horizontal, 13).frame(minHeight: 46)
            .background(reason == item ? MoyeoTheme.leaf : MoyeoTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(
              RoundedRectangle(cornerRadius: 11).stroke(
                reason == item ? MoyeoTheme.forest : MoyeoTheme.softLine))
          }.buttonStyle(.plain)
        }
        Toggle("이 유저를 차단할게요", isOn: $blocksUser)
          .font(.subheadline.weight(.bold)).tint(MoyeoTheme.forest).frame(minHeight: 48)
        if blocksUser {
          Text("차단하면 이 유저가 만들었거나 참여한 모집이 홈·탐색에서 모두 숨겨져요.")
            .font(.caption).foregroundStyle(MoyeoTheme.muted)
        }
        HStack(spacing: 8) {
          Button("취소") { dismiss() }.buttonStyle(.bordered).frame(
            maxWidth: .infinity, minHeight: 48)
          Button("신고하기") { dismiss() }.buttonStyle(.borderedProminent).tint(MoyeoTheme.coral).frame(
            maxWidth: .infinity, minHeight: 48)
        }
        Text("24시간 이내에 검토해 드릴게요.").font(.caption2).foregroundStyle(MoyeoTheme.text400).frame(
          maxWidth: .infinity)
      }
      .padding(20)
    }
    .background(MoyeoTheme.card.ignoresSafeArea())
    .navigationTitle("신고")
    .navigationBarTitleDisplayMode(.inline)
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
            Button("차단 해제") { blocked.removeAll { $0.name == user.name } }.buttonStyle(.bordered)
              .controlSize(.small)
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
          Toggle(isOn: $showsNickname) {
            VStack(alignment: .leading, spacing: 3) {
              Text("내 닉네임을 함께 보여주기")
                .font(MoyeoTypography.font(size: 13, weight: .bold, relativeTo: .subheadline))
              Text("끄면 익명 여행자 코스로 올라가요.")
                .font(MoyeoTypography.font(size: 11, relativeTo: .caption2))
                .foregroundStyle(MoyeoTheme.muted)
            }
          }
          .tint(MoyeoTheme.forest)
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
  @State private var sharesLocation = true
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
      locationSharing

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

  private var locationSharing: some View {
    HStack(spacing: 10) {
      Image(systemName: "map")
        .font(.caption)
        .foregroundStyle(sharesLocation ? MoyeoTheme.forest : MoyeoTheme.muted)
      VStack(alignment: .leading, spacing: 2) {
        Text(sharesLocation ? "3명이 위치를 공유 중이에요" : "위치 공유 꺼짐")
          .font(MoyeoTypography.font(size: 12, weight: .bold, relativeTo: .caption))
        Text("여행이 끝나면 자동으로 꺼져요")
          .font(MoyeoTypography.font(size: 10.5, relativeTo: .caption2))
          .foregroundStyle(MoyeoTheme.muted)
      }
      Spacer()
      Toggle("위치 공유", isOn: $sharesLocation)
        .labelsHidden()
        .tint(MoyeoTheme.forest)
        .accessibilityIdentifier("tripDay.locationSharing")
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(MoyeoTheme.card)
    .overlay(alignment: .bottom) { Rectangle().fill(MoyeoTheme.softLine).frame(height: 1) }
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
  @State private var mutedTrips = Set(["포항·영덕 동해 드라이브"])
  private let modes = ["모든 메시지", "멘션·답글만", "받지 않기"]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        settingsCard("알림 범위") {
          ForEach(modes, id: \.self) { item in
            Button {
              mode = item
            } label: {
              HStack {
                Text(item)
                Spacer()
                Image(systemName: mode == item ? "checkmark.circle.fill" : "circle")
              }
              .foregroundStyle(mode == item ? MoyeoTheme.forest : MoyeoTheme.ink).frame(
                minHeight: 48)
            }.buttonStyle(.plain)
          }
        }
        settingsCard("방해금지 시간대") {
          Toggle("22:30부터 07:00까지", isOn: $quietHours).tint(MoyeoTheme.forest).frame(minHeight: 52)
          Text("월 · 화 · 수 · 목 · 금 · 토 · 일").font(.caption).foregroundStyle(MoyeoTheme.muted)
        }
        settingsCard("모임별 알림") {
          ForEach(["주왕산 & 주산지 힐링 트레킹", "안동 하회마을 하루여행", "포항·영덕 동해 드라이브"], id: \.self) { title in
            Toggle(
              title,
              isOn: Binding(
                get: { !mutedTrips.contains(title) },
                set: { enabled in
                  if enabled { mutedTrips.remove(title) } else { mutedTrips.insert(title) }
                })
            )
            .font(.subheadline.weight(.semibold)).tint(MoyeoTheme.forest).frame(minHeight: 52)
          }
        }
        infoCard("방해금지 중에도 여행 당일 일정 변경과 안전 관련 알림은 받을 수 있어요.")
      }.padding(18).padding(.bottom, 28)
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .navigationTitle("알림 세부 설정")
    .navigationBarTitleDisplayMode(.inline)
    .accessibilityIdentifier("screen.notificationDetail")
  }
}

struct AccountDeleteView: View {
  let onDeleted: () -> Void
  @State private var reason = ""
  @State private var acknowledgesDeletion = false
  @State private var showsFinalConfirmation = false
  @State private var isDeleting = false
  @State private var errorMessage: String?
  private let reasons = ["원하는 여행을 찾기 어려워요", "알림이 너무 많아요", "개인정보가 걱정돼요", "잠시 쉬고 싶어요", "기타"]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text("탈퇴 전에 확인해주세요").font(MoyeoTypography.screenTitle)
        warningCard("참여 중인 여행이 있다면 먼저 취소하거나 호스트 권한을 넘겨야 해요.")
        settingsCard("떠나는 이유") {
          ForEach(reasons, id: \.self) { item in
            Button {
              reason = item
            } label: {
              HStack {
                Image(systemName: reason == item ? "checkmark.circle.fill" : "circle")
                Text(item)
                Spacer()
              }
              .foregroundStyle(reason == item ? MoyeoTheme.forest : MoyeoTheme.ink).frame(
                minHeight: 46)
            }.buttonStyle(.plain)
          }
        }
        VStack(alignment: .leading, spacing: 9) {
          Label("30일 동안 탈퇴 대기 상태가 돼요", systemImage: "clock.arrow.circlepath")
          Label("30일 안에 다시 로그인하면 계정을 되살릴 수 있어요", systemImage: "arrow.uturn.backward.circle")
          Label("30일 뒤 프로필·도감·로그인 연결 정보가 삭제돼요", systemImage: "trash")
          Label("이미 공개한 코스와 작성한 신고 기록은 정책에 따라 남을 수 있어요", systemImage: "doc.text")
        }
        .font(.subheadline).foregroundStyle(MoyeoTheme.text700).padding(14).background(
          MoyeoTheme.card
        ).clipShape(RoundedRectangle(cornerRadius: 12))
        Toggle("삭제 범위와 30일 대기 정책을 확인했어요", isOn: $acknowledgesDeletion)
          .font(.subheadline.weight(.bold)).tint(MoyeoTheme.coral).frame(minHeight: 50)
        Button {
          showsFinalConfirmation = true
        } label: {
          Text("계정 탈퇴 요청").frame(maxWidth: .infinity, minHeight: 50)
        }.buttonStyle(.borderedProminent).tint(MoyeoTheme.coral).disabled(
          reason.isEmpty || !acknowledgesDeletion || isDeleting)
        if isDeleting { ProgressView("탈퇴 요청을 처리하고 있어요").frame(maxWidth: .infinity) }
      }.padding(18).padding(.bottom, 30)
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .navigationTitle("계정 탈퇴")
    .navigationBarTitleDisplayMode(.inline)
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
      Image(
        systemName: mode == .maintenance
          ? "wrench.and.screwdriver.fill" : "exclamationmark.triangle.fill"
      )
      .font(.system(size: 42, weight: .semibold)).foregroundStyle(
        mode == .maintenance ? MoyeoTheme.forest : MoyeoTheme.coral
      )
      .frame(width: 80, height: 80).background(
        mode == .maintenance ? MoyeoTheme.leaf : MoyeoTheme.coral.opacity(0.12)
      ).clipShape(Circle())
      Text(mode == .maintenance ? "더 나은 여행을 위해\n잠시 정비하고 있어요" : "페이지를 불러오지 못했어요")
        .font(MoyeoTypography.screenTitle).multilineTextAlignment(.center)
      Text(
        mode == .maintenance
          ? "예상 종료 시각은 오늘 오전 04:30이에요.\n10분마다 자동으로 다시 확인할게요." : "잠시 뒤 새로고침하거나 이전 화면으로 돌아가주세요."
      )
      .font(.subheadline).foregroundStyle(MoyeoTheme.muted).multilineTextAlignment(.center)
      .lineSpacing(4)
      if mode == .error {
        Button("새로고침") { retryCount += 1 }.buttonStyle(.borderedProminent).tint(MoyeoTheme.forest)
          .frame(minWidth: 180, minHeight: 48)
        Button("돌아가기") {}.buttonStyle(.bordered).frame(minWidth: 180, minHeight: 48)
      } else {
        Text("자동 확인 \(retryCount + 1)회째").font(.caption).foregroundStyle(MoyeoTheme.text400)
      }
      Spacer()
      Text(mode == .maintenance ? "공지사항에서 점검 소식을 확인할 수 있어요." : "오류 코드 · MT-500-01")
        .font(.caption2).foregroundStyle(MoyeoTheme.text400).padding(.bottom, 20)
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
      mascot: "🐻", name: "숲속여행자", badge: "작성자", body: "사진 속 월정교 야경이 정말 예쁘네요!", time: "방금"),
    ChangelogComment(
      mascot: "🦌", name: "따스한 사슴 3492", badge: "함께 간 친구", body: "그날 바람까지 생각나요. 다음에도 같이 가요.",
      time: "12분 전"),
    ChangelogComment(
      mascot: "🐰", name: "달빛 토끼 6142", badge: "", body: "저도 이 코스로 걸어보고 싶어요.", time: "1시간 전")
  ]

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(comments) { item in
            commentRow(item)
          }
          ForEach(submitted, id: \.self) { item in
            commentRow(ChangelogComment(mascot: "🦌", name: "나", badge: "", body: item, time: "방금"))
          }
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
            .background(MoyeoTheme.river).clipShape(Circle())
        }.buttonStyle(.plain).disabled(
          comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }.padding(12).background(MoyeoTheme.card)
    }
    .background(MoyeoTheme.background.ignoresSafeArea())
    .navigationTitle("댓글 \(post.commentCount + submitted.count)개")
    .navigationBarTitleDisplayMode(.inline)
    .navigationDestination(item: $route) { SupportDestinationView(route: $0) }
    .accessibilityIdentifier("screen.feedComments")
  }

  private func commentRow(_ item: ChangelogComment) -> some View {
    HStack(alignment: .top, spacing: 11) {
      MascotAvatar(mascot: item.mascot, size: 38, background: MoyeoTheme.leaf)
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
        HStack(spacing: 18) {
          Button("답글") {}
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

private func changelogSecondaryButton(_ title: String, icon: String, action: @escaping () -> Void)
  -> some View {
  Button(action: action) {
    Label(title, systemImage: icon).font(.caption.weight(.bold)).frame(
      maxWidth: .infinity, minHeight: 42)
  }
  .buttonStyle(.bordered).tint(MoyeoTheme.forest)
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

private func settingsCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content)
  -> some View {
  VStack(alignment: .leading, spacing: 6) {
    Text(title).font(.caption.weight(.bold)).foregroundStyle(MoyeoTheme.muted)
    VStack(spacing: 0) { content() }.padding(.horizontal, 14).background(MoyeoTheme.card).clipShape(
      RoundedRectangle(cornerRadius: 12)
    ).overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.softLine))
  }
}
