import SwiftUI

struct HostManageNavigationBar: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Text("모집 관리")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)

            HStack {
                Button {
                    dismiss()
                } label: {
                    // NAV-017 · ENV-009 — 44x44 틀은 있었지만 `contentShape` 가 없어
                    // 실제로는 화살표 그림(9x14pt)에만 반응했다. 그림 크기는 그대로 둔다.
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(MoyeoTheme.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로")
                Spacer()
            }
        }
        .frame(height: 56)
        .overlay(alignment: .bottom) {
            Rectangle().fill(MoyeoTheme.line).frame(height: 1)
        }
    }
}

struct HostManageTripSummary: View {
    let title: String
    let participantText: String
    let status: String

    var body: some View {
        // 화면기획 18 — 제목 아래에 "4 / 8명 · D-3" 순으로 배지를 잇는다
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(MoyeoTypography.cardTitle)
                .foregroundStyle(MoyeoTheme.ink)
                .lineLimit(1)
            HStack(spacing: 8) {
                Text(participantText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.muted)
                Text("·")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.text400)
                HostManagePill(status)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HostManageRouteRow: View {
    let count: Int
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "map.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MoyeoTheme.primary300)
                .frame(width: 40, height: 40)
                .background(MoyeoTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("여행 경로 · 방문지 \(count)곳")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(MoyeoTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(MoyeoTheme.text400)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 66)
        .background(MoyeoTheme.leaf)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// 18 모집 관리에서 다음 화면으로 가는 줄 — 18-4 여행 확정 / 18-5 집합 정보 수정.
/// 서버 모임이 아니면(목데이터·미로그인) 열 방이 없어 잠근다.
struct HostManageLinkRow: View {
    let title: String
    let detail: String
    let icon: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isEnabled ? MoyeoTheme.forest : MoyeoTheme.text400)
                    .frame(width: 40, height: 40)
                    .background(MoyeoTheme.subtleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.ink)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.muted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MoyeoTheme.text400)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MoyeoTheme.card)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.softLine))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

/// 방 id 하나만 넘겨 여는 화면(18-1 · 18-2 · 20-1c)의 `navigationDestination(item:)` 값.
/// `Int64` 는 `Identifiable` 이 아니라 그대로 넘길 수 없다.
struct RoomIDRoute: Identifiable, Hashable {
    let roomID: Int64
    /// 같은 방이라도 화면이 다르면 다른 목적지다.
    var kind: String = ""

    var id: String { "\(kind).\(roomID)" }
}

struct HostManageEmptyState<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(MoyeoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(MoyeoTheme.line, lineWidth: 1)
            }
    }
}

/// 18 접힌 대기자·거절 기록 한 줄. 누르면 그 사람의 25 프로필 카드를 연다.
///
/// 예전에는 `chevron.right` 만 그려 눌릴 것처럼 보였는데 아무 동작이 없었다.
/// 열 프로필이 없으면(서버 신청자가 아니라 `serverUserID` 가 없을 때) 화살표도 그리지 않는다 —
/// 눌릴 것처럼 보이면서 안 눌리는 것이 원래 결함이었다.
struct HostCompactApplicantRow: View {
    let applicant: HostApplicant
    let detail: String
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) {
                row
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(applicant.name) 프로필 열기")
        } else {
            row
        }
    }

    private var row: some View {
        HStack(spacing: 12) {
            Text(applicant.avatar)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(MoyeoTheme.leaf)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(applicant.name)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(MoyeoTheme.muted)
            }
            Spacer()
            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MoyeoTheme.text400)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 70)
        .contentShape(Rectangle())
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MoyeoTheme.line, lineWidth: 1)
        }
    }
}

/// 18 승인된 동행자 줄의 아바타 한 칸. 서버 모임은 **프로필 사진**을, 목데이터 스레드는
/// 마스코트 이모지를 그린다. 둘 다 없으면 잎 색 원만 남긴다(없는 값을 지어내지 않는다).
struct HostCompanionAvatar: Hashable {
    var imageURL: URL?
    var emoji: String

    init(imageURL: URL? = nil, emoji: String = "") {
        self.imageURL = imageURL
        self.emoji = emoji
    }
}

extension HostCompanionAvatar {
    /// 승인된 동행자 아바타 묶음.
    ///
    /// 서버 모임은 멤버 목록의 **프로필 사진**을 쓰고, 목데이터 스레드는 마스코트 이모지를 쓴다.
    /// 서버 멤버를 아직 못 받았으면 사진 없이 인원 수만큼 빈 원을 둔다 — 예전에는 서버 모임이
    /// **항상** 빈 문자열이라 사진이 있어도 빈 원만 그렸다(사용자 지적 2026-09-12).
    static func approved(
        usesServer: Bool,
        serverMembers: [ServerChatRoomMember],
        fallbackCount: Int,
        mockEmojis: [String]
    ) -> [HostCompanionAvatar] {
        guard usesServer else { return mockEmojis.map { HostCompanionAvatar(emoji: $0) } }
        guard !serverMembers.isEmpty else {
            return Array(repeating: HostCompanionAvatar(), count: fallbackCount)
        }
        // 호스트를 앞에 둔다 — 기획 18 의 아바타 무리도 호스트가 먼저다.
        return serverMembers
            .sorted { lhs, rhs in lhs.host && !rhs.host }
            .map { HostCompanionAvatar(imageURL: $0.profileImageURL) }
    }
}

struct HostApprovedCompanionsRow: View {
    let avatars: [HostCompanionAvatar]
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: -7) {
                ForEach(Array(avatars.prefix(4).enumerated()), id: \.offset) { _, avatar in
                    Group {
                        // 예전에는 이 줄이 **이모지 문자열만** 받았다. 서버 모임은 마스코트를 주지 않아
                        // 빈 문자열을 넣었고, 그래서 **빈 원 네 개**만 그려졌다 — 서버가 주는
                        // `profileImageUrl` 은 20-1 모임 정보에서 멀쩡히 쓰고 있었는데 여기만 안 썼다
                        // (사용자 지적 2026-09-12).
                        if let url = avatar.imageURL {
                            CachedRemoteImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                MoyeoTheme.leaf
                            }
                        } else if !avatar.emoji.isEmpty {
                            Text(avatar.emoji).font(.body)
                        } else {
                            MoyeoTheme.leaf
                        }
                    }
                    .frame(width: 34, height: 34)
                    .background(MoyeoTheme.leaf)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(MoyeoTheme.card, lineWidth: 2))
                }
            }
            Spacer()
            // 화면기획 18 — 아바타 무리 + "본인 외 3명"
            Text("본인 외 \(max(count - 1, 0))명")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MoyeoTheme.muted)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 72)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MoyeoTheme.line, lineWidth: 1)
        }
    }
}

/// 화면기획 18 모집 관리의 신청자. 서버 신청(`GET .../applications`)과
/// 캡처용 목데이터가 같은 형태를 쓴다 — 파일 길이 규칙 때문에 이 파일에 둔다.
extension HostApplicant {
    /// 접힌 대기자·거절 기록 행을 눌렀을 때 열 25 프로필 카드.
    /// 서버 신청자가 아니면 열 사람이 없다 — 그때는 nil 이라 행이 화살표도 그리지 않는다.
    var profileCardRoute: SupportRoute? {
        guard let serverUserID else { return nil }
        return .publicProfile(
            .serverUser(
                ProfileCardUserReference(
                    userID: serverUserID,
                    nickname: name,
                    profileImageUrl: profileImageURL?.absoluteString
                )
            )
        )
    }
}

struct HostApplicant: Identifiable, Hashable {
    let id: String
    let name: String
    let avatar: String
    /// 화면기획 18 — 나이·성별·매너·여행 횟수 요약 (예: "31세 · 남성 · 매너 4.9 · 여행 8회")
    let meta: String
    let note: String
    /// 실서버 신청 식별자 — 승인(`.../approve`)·거절(`DELETE .../{id}`)에 쓴다. 목데이터면 nil.
    var serverApplicationID: Int64?
    var serverUserID: Int64?
    var profileImageURL: URL?

    var participant: Participant {
        Participant(id: id, name: name, avatar: avatar)
    }

    /// 서버 신청 목록을 못 받았을 때의 자리. 목 신청자를 채우지 않는다 (NO-MOCK-CANON R1).
    static let noPending: [HostApplicant] = []
    static let noApproved: [HostApplicant] = []
}

/// 18 모집 관리의 호스트 동작 묶음 — 18-4 여행 확정 / 18-5 집합 정보 수정 / 18-6 모집 내용 수정.
///
/// 앞의 둘은 **나란한 버튼**이다(기획·웹이 그렇다). 셋째는 폭이 달라 아래 줄에 따로 둔다.
/// 세 화면 모두 **모집 중일 때만** 의미가 있다 — 확정 뒤에는 서버가 거절한다.
/// 18-6 은 화면이 완성돼 있는데도 `SupportRoute.recruitEdit` 를 부르는 곳이 UI 테스트 코드
/// 하나뿐이라 **앱에서 갈 길이 없었다**(웹 W-05 · 안드와 같은 구멍 · QA 2026-09-12).
struct HostManageHostActions: View {
    let isRecruitmentClosed: Bool
    /// 서버가 말하는 지금 상태가 `RECRUITING` 인지. 확정·불발이 끝난 방에서는 세 화면 모두
    /// 서버가 400 으로 거절한다 — 눌리는 채로 두면 눌러 봐야 알 수 있다 (IOS-F127).
    var isRecruiting = true
    let hasServerRoom: Bool
    let onTripStatus: () -> Void
    let onMeetingEdit: () -> Void
    let onRecruitEdit: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                actionButton("여행 확정하기", identifier: "hostManage.tripStatus", action: onTripStatus)
                actionButton("집합 정보 수정", identifier: "hostManage.meetingEdit", action: onMeetingEdit)
            }
            if !isRecruitmentClosed {
                actionButton("모집 내용 수정", identifier: "hostManage.recruitEdit", action: onRecruitEdit)
            }
            if !isRecruiting {
                // 왜 잠겼는지 적는다. 「모집 취소됨」 배지만으로는 버튼이 회색인 이유를 알 수 없다.
                Text("모집이 끝난 방이라 확정·집합 정보·모집 내용은 더는 고칠 수 없어요.")
                    .font(MoyeoTypography.tinyMeta)
                    .foregroundStyle(MoyeoTheme.text400)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("hostManage.actionsLockedReason")
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
    }

    private func actionButton(
        _ title: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        // 잠긴 버튼은 **잠긴 것처럼 보여야 한다** — 초록 테두리 그대로 두면 눌러 봐야 안다.
        let isEnabled = hasServerRoom && isRecruiting
        return Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(isEnabled ? MoyeoTheme.brandText : MoyeoTheme.text400)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isEnabled ? MoyeoTheme.forest : MoyeoTheme.line)
                )
        }
        .buttonStyle(.plain)
        .disabled(!hasServerRoom || !isRecruiting)
        .accessibilityIdentifier(identifier)
    }
}
