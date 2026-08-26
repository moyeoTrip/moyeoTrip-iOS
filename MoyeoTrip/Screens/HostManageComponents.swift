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

struct HostCompactApplicantRow: View {
    let applicant: HostApplicant
    let detail: String

    var body: some View {
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
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(MoyeoTheme.text400)
        }
        .padding(.horizontal, 16)
        .frame(height: 70)
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

    // 화면기획 18 모집 관리의 승인 대기 2명
    static let mockPending = [
        HostApplicant(
            id: "applicant-bear",
            name: "우직한 곰 7821",
            avatar: "🐻",
            meta: "31세 · 남성 · 매너 4.9 · 여행 8회",
            note: "단풍 보러 가요. 사진 좋아해서 풍경 잘 담아드릴 수 있어요!"
        ),
        HostApplicant(
            id: "applicant-raccoon",
            name: "호기심 많은 너구리 9027",
            avatar: "🦝",
            meta: "26세 · 여성 · 매너 4.7",
            note: "야경 사진 찍는 걸 좋아해요. 잘 부탁드려요!"
        )
    ]

    // 화면기획 18 — 본인 외 3명 (아바타 무리)
    static let mockApproved = [
        HostApplicant(id: "approved-deer", name: "숲속 사슴 2417", avatar: "🦌", meta: "매너 4.8 · 여행 8회", note: "기존 참여자"),
        HostApplicant(id: "approved-turtle", name: "잔잔한 거북이 9032", avatar: "🐢", meta: "매너 4.8 · 여행 8회", note: "기존 참여자"),
        HostApplicant(id: "approved-rabbit", name: "느긋한 토끼 7821", avatar: "🐰", meta: "매너 4.8 · 여행 8회", note: "기존 참여자")
    ]
}
