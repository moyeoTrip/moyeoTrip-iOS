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
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                    .lineLimit(1)
                Text(participantText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.muted)
            }
            Spacer(minLength: 8)
            HostManagePill(status)
        }
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
                Text("여행 경로 · \(count)곳")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(MoyeoTheme.muted)
                    .lineLimit(1)
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
            VStack(alignment: .leading, spacing: 2) {
                Text("승인된 동행자 \(count)명")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                Text("집결지와 준비물은 채팅방에서 확인해요.")
                    .font(.caption)
                    .foregroundStyle(MoyeoTheme.muted)
            }
            Spacer()
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
