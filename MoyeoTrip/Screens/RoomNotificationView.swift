//
//  RoomNotificationView.swift
//  MoyeoTrip
//
//  20-1c 이 모임 알림. 정본 `ATTACH-COMPOSER-CANON.md` §6-1.
//
//  20-1 사이드 메뉴의 `알림 설정 · 이 모임의 알림만 끄기` 에서 온다.
//  다른 플랫폼에서는 이 자리가 **전역 방해금지 화면(29-2)** 으로 가고 있었다 —
//  "이 모임만" 이라고 써놓고 계정 전체 설정을 열면, 방 하나 끄려던 사람이 모든 알림을 끈다.
//
//  근거: `GET/PUT /api/v1/notifications/settings/chat-rooms/{roomId}` → `{"roomId":101,"enabled":true}`
//

import SwiftUI
import UserNotifications

struct RoomNotificationView: View {
    let roomID: Int64
    /// 머리말에 쓸 모임 이름. 진입점이 아는 값이라 다시 부르지 않는다.
    var roomTitle: String = ""
    /// 동행자 수·출발일 한 줄. 진입점이 모르면 그 줄을 그리지 않는다.
    var roomSubtitle: String = ""

    /// 진입점이 이름을 모를 때 서버에서 받아 온 모임 이름 · 일정 한 줄.
    /// 캡처처럼 방 id 만 들고 들어오면 이쪽이 채워진다.
    @State private var loadedTitle = ""
    @State private var loadedSubtitle = ""

    @State private var isEnabled = true
    /// 서버가 마지막으로 확인해 준 값. nil 이면 아직 모르는 상태라 토글이 서버를 부르지 않는다.
    @State private var serverEnabled: Bool?
    @State private var loadState: TripCompanionsState = .loading
    @State private var route: SupportRoute?
    /// OS 알림 권한이 꺼져 있는지. 꺼져 있으면 이 모임 알림을 켜 두어도 기기에는 오지 않는다 —
    /// 서버 값만 보여 주면 「켜 뒀는데 왜 안 와요」가 된다 (TC NOTIF-016,
    /// `OS-NOTIFICATION-BLOCK-CANON.md`). 문구·자리는 29-2 와 같은 것을 쓴다.
    @State private var isSystemNotificationDenied = false
    /// 저장이 거절됐을 때 그 자리에 적는 말. 토글만 되돌리면 사용자는 **자기가 잘못 눌렀다고 여긴다**.
    @State private var saveFailure: String?
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !displayTitle.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayTitle)
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(MoyeoTheme.ink)
                        if !displaySubtitle.isEmpty {
                            Text(displaySubtitle)
                                .font(MoyeoTypography.tinyMeta)
                                .foregroundStyle(MoyeoTheme.muted)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MoyeoTheme.card)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(MoyeoTheme.softLine))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                // 토글 **위**에 놓는다 — 누르기 전에 읽혀야 한다 (정본 「문구·자리」).
                // OS 가 막고 있지 않으면 이 줄은 아예 그리지 않는다.
                if isSystemNotificationDenied {
                    MoyeoSystemNotificationDeniedNotice { openNotificationSettings() }
                        .padding(.top, 14)
                }

                toggleSection

                AttachNoteBox(lines: [
                    "꺼도 채팅은 그대로 쌓여요. 들어가면 다 볼 수 있어요.",
                    "앱 전체 알림과 방해 금지 시간대는 설정에서 따로 정해요."
                ])

                Button {
                    route = .notificationDetail
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bell")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MoyeoTheme.text700)
                        Text("앱 전체 알림 설정")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MoyeoTheme.ink)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MoyeoTheme.text400)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(MoyeoTheme.card)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.softLine))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
                .accessibilityIdentifier("roomNotification.appSettings")
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .navigationTitle("이 모임 알림")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $route) { SupportDestinationView(route: $0) }
        .task { await load() }
        .task { await refreshSystemNotificationState() }
        .onChange(of: scenePhase) { _, phase in
            // iOS 설정에서 권한을 바꾸고 돌아오면 즉시 반영한다.
            guard phase == .active else { return }
            Task { await refreshSystemNotificationState() }
        }
        .accessibilityIdentifier("screen.roomNotification")
    }

    /// OS 알림 권한이 꺼져 있는지 확인한다. `denied` 일 때만 안내를 띄운다 —
    /// `notDetermined` 는 아직 물어보지 않은 것이라 「막혔다」고 말하면 거짓말이 된다 (29-2 와 같은 판정).
    private func refreshSystemNotificationState() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isSystemNotificationDenied = settings.authorizationStatus == .denied
    }

    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    /// 진입점이 아는 이름이 우선이고, 없으면 서버에서 받은 값을 쓴다.
    private var displayTitle: String {
        roomTitle.isEmpty ? loadedTitle : roomTitle
    }

    private var displaySubtitle: String {
        roomTitle.isEmpty ? loadedSubtitle : roomSubtitle
    }

    /// 서버 값을 모르는 동안에는 토글을 그리지 않는다 — 켜진 것처럼 보여 놓고
    /// 실제로는 꺼져 있을 수 있다 (NO-MOCK-CANON R1).
    @ViewBuilder
    private var toggleSection: some View {
        switch loadState {
        case .loading:
            MoyeoEmptyStateView(
                message: MoyeoEmptyText.loading,
                accessibilityIdentifier: "roomNotification.state"
            )
        case .failed:
            MoyeoEmptyStateView(
                message: MoyeoEmptyText.loadFailed,
                onRetry: { Task { await reload() } },
                accessibilityIdentifier: "roomNotification.state"
            )
        default:
            AttachToggleRow(
                label: "이 모임 알림 받기",
                desc: isEnabled
                    ? "새 메시지와 공지 알림을 받아요."
                    : "이 모임의 알림만 꺼져요. 다른 모임과 앱 전체 알림은 그대로예요.",
                isOn: $isEnabled,
                identifier: "roomNotification.toggle"
            )
            .padding(.top, 8)
            .onChange(of: isEnabled) { _, enabled in push(enabled) }

            if let saveFailure {
                Text(saveFailure)
                    .font(.caption)
                    .foregroundStyle(MoyeoTheme.coral)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                    .accessibilityIdentifier("roomNotification.saveFailure")
            }
        }
    }

    private func load() async {
        guard loadState == .loading, serverEnabled == nil else { return }
        await reload()
    }

    private func reload() async {
        loadState = .loading
        guard MoyeoServerSync.isEnabled else {
            loadState = .empty
            return
        }
        guard
            let setting = try? await ChatRoomWriteAPIClient.shared.notificationSetting(roomID: roomID)
        else {
            loadState = .failed
            return
        }
        serverEnabled = setting.enabled
        isEnabled = setting.enabled
        loadState = .ready
        await loadRoomHeader()
    }

    /// 웹 · 안드로이드처럼 어떤 모임의 설정인지 위에 적는다.
    /// 진입점(20-1 사이드 메뉴)은 이름을 알지만, 방 id 만 들고 들어오는 경로에서는
    /// `GET /chat-rooms/{roomId}` 로 직접 받는다 — 못 받으면 그 카드를 그리지 않는다 (R1).
    private func loadRoomHeader() async {
        guard roomTitle.isEmpty, loadedTitle.isEmpty else { return }
        guard let detail = try? await ChatRoomAPIClient.shared.detail(roomID: roomID) else { return }
        loadedTitle = detail.title
        loadedSubtitle = ServerTripMapper.scheduleSummaryText(detail)
    }

    /// 서버가 거절하면 토글을 서버 값으로 되돌리고 **왜 되돌렸는지 말한다**.
    ///
    /// 예전에는 `try?` 로 삼키고 `isEnabled = current` 만 했다 — 눌렀는데 스위치가 혼자 되돌아오고
    /// 아무 말이 없어서, 사용자는 자기가 잘못 눌렀거나 앱이 고장 난 줄 알았다 (TC NOTIF-015).
    /// 문구는 클라가 갖는다 — 서버 문장을 그대로 띄우지 않는다 (결정 ⑩).
    private func push(_ enabled: Bool) {
        guard
            MoyeoServerSync.isEnabled,
            let current = serverEnabled,
            current != enabled
        else {
            return
        }
        saveFailure = nil
        Task {
            let setting: ServerChatRoomNotificationSetting
            do {
                setting = try await ChatRoomWriteAPIClient.shared.updateNotificationSetting(
                    roomID: roomID, enabled: enabled
                )
            } catch {
                isEnabled = current
                saveFailure = "알림 설정을 바꾸지 못했어요. 잠시 후 다시 시도해주세요."
                return
            }
            serverEnabled = setting.enabled
            isEnabled = setting.enabled
        }
    }
}
