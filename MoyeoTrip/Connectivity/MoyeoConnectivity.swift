import Combine
import Foundation
import Network
import SwiftUI

enum MoyeoConnectionStatus: Equatable {
    case checking
    case online
    case offline
}

@MainActor
final class MoyeoConnectivity: ObservableObject {
    @Published private(set) var status: MoyeoConnectionStatus
    @Published private(set) var recoveryToken: UUID?

    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "kr.hanchae.MoyeoTrip.connectivity")
    private let forcedStatus: MoyeoConnectionStatus?
    private let defaults: UserDefaults

    private static let cacheKey = "moyeo.hasCachedContent"

    init(arguments: [String] = ProcessInfo.processInfo.arguments, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if arguments.contains("UITEST_OFFLINE_EMPTY")
            || arguments.contains("UITEST_OFFLINE_CACHED")
            || arguments.contains("UITEST_OFFLINE_CHAT") {
            forcedStatus = .offline
            status = .offline
        } else {
            forcedStatus = nil
            status = .checking
        }

        startMonitoring()
    }

    deinit {
        monitor?.cancel()
    }

    var isOffline: Bool {
        status == .offline
    }

    var hasCachedContent: Bool {
        if ProcessInfo.processInfo.arguments.contains("UITEST_OFFLINE_EMPTY") {
            return false
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_OFFLINE_CACHED")
            || ProcessInfo.processInfo.arguments.contains("UITEST_OFFLINE_CHAT") {
            return true
        }
        return defaults.bool(forKey: Self.cacheKey)
    }

    func markCacheAvailable() {
        guard status == .online else { return }
        defaults.set(true, forKey: Self.cacheKey)
    }

    func retry() {
        guard forcedStatus == nil else { return }
        status = .checking
        monitor?.cancel()
        startMonitoring()
    }

    private func startMonitoring() {
        let nextMonitor = NWPathMonitor()
        nextMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self, forcedStatus == nil else { return }
                updateStatus(path.status == .satisfied ? .online : .offline)
            }
        }
        monitor = nextMonitor
        nextMonitor.start(queue: queue)
    }

    private func updateStatus(_ newStatus: MoyeoConnectionStatus) {
        let wasOffline = status == .offline
        status = newStatus
        if wasOffline, newStatus == .online {
            recoveryToken = UUID()
        }
    }
}

private struct MoyeoOfflineEnvironmentKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var moyeoIsOffline: Bool {
        get { self[MoyeoOfflineEnvironmentKey.self] }
        set { self[MoyeoOfflineEnvironmentKey.self] = newValue }
    }
}

struct MoyeoOfflineBanner: View {
    let cachedContentAvailable: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(MoyeoTheme.warningText)
                .frame(width: 6, height: 6)
            Text(cachedContentAvailable
                 ? "연결이 끊겼어요 · 저장된 내용만 보여드려요"
                 : "인터넷에 연결되어 있지 않아요")
                .font(MoyeoTypography.font(size: 12, weight: .bold, relativeTo: .caption))
                .foregroundStyle(MoyeoTheme.warningText)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
        .background(MoyeoTheme.warningBackground)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("offline.banner")
    }
}

struct OfflineEmptyView: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            MoyeoOfflineBanner(cachedContentAvailable: false)

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(MoyeoTheme.subtleBackground)
                        .frame(width: 108, height: 108)
                    Image(systemName: "safari")
                        .font(.system(size: 46, weight: .regular))
                        .foregroundStyle(MoyeoTheme.text400)
                    Capsule()
                        .fill(MoyeoTheme.text400)
                        .frame(width: 76, height: 3)
                        .rotationEffect(.degrees(-45))
                }

                Text("연결 상태를\n확인해주세요")
                    .font(MoyeoTypography.font(size: 21, weight: .bold, relativeTo: .title2))
                    .foregroundStyle(MoyeoTheme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, 22)

                Text("와이파이나 데이터가 켜져 있는지 확인해주세요.\n연결되면 자동으로 다시 불러올게요.")
                    .font(MoyeoTypography.font(size: 13, relativeTo: .subheadline))
                    .foregroundStyle(MoyeoTheme.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 10)

                OfflineAvailableContentCard()
                    .padding(.top, 22)

                Spacer()

                Button("다시 시도", action: onRetry)
                    .font(MoyeoTypography.font(size: 15, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(MoyeoTheme.forest)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityIdentifier("offline.retry")

                Text("연결되면 이 화면은 저절로 닫혀요")
                    .font(MoyeoTypography.font(size: 11, relativeTo: .caption2))
                    .foregroundStyle(MoyeoTheme.text400)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 28)
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .accessibilityIdentifier("screen.offline.empty")
    }
}

private struct OfflineAvailableContentCard: View {
    private let rows = [
        ("bookmark.fill", "저장해둔 코스와 지난 여행 기록"),
        ("person.2.fill", "이미 받아둔 채팅 내용"),
        ("bubble.left.fill", "보낸 메시지는 연결되면 자동으로 전송돼요")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("지금도 볼 수 있는 것")
                .font(MoyeoTypography.font(size: 12, weight: .bold, relativeTo: .caption))
                .foregroundStyle(MoyeoTheme.text700)
            ForEach(rows, id: \.1) { row in
                Label(row.1, systemImage: row.0)
                    .font(MoyeoTypography.font(size: 12, relativeTo: .caption))
                    .foregroundStyle(MoyeoTheme.text700)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoyeoTheme.subtleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MoyeoTheme.softLine, lineWidth: 1)
        }
    }
}
