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
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(MoyeoTheme.ink)
                        .frame(width: 44, height: 44)
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

struct HostApprovedCompanionsRow: View {
    let avatars: [String]
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: -7) {
                ForEach(Array(avatars.prefix(4).enumerated()), id: \.offset) { _, avatar in
                    Text(avatar)
                        .font(.body)
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
