//
//  HostApplicantCard.swift
//  MoyeoTrip
//
//  18 모집 관리의 승인 대기 카드. `HostManageView` 가 500줄을 넘어 갈라냈다 (SwiftLint file_length).
//

import SwiftUI

struct HostApplicantCard: View {
    let applicant: HostApplicant
    let primaryLabel: String
    let secondaryLabel: String
    let onPrimary: () -> Void
    let onSecondary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HostApplicantHeader(applicant: applicant)
            // 신청 한마디는 인용 블록으로 (화면기획). 신청자가 안 남겼으면 빈 인용을 그리지 않는다.
            if !applicant.note.isEmpty {
                Text("\u{201C}\(applicant.note)\u{201D}")
                    .font(.caption)
                    .foregroundStyle(MoyeoTheme.muted)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                    .background(MoyeoTheme.subtleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            HStack(spacing: 10) {
                Button(action: onSecondary) {
                    Text(secondaryLabel)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(MoyeoTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(MoyeoTheme.line))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(applicant.name) \(secondaryLabel)")
                .accessibilityIdentifier("hostApplicant.\(applicant.id).reject")

                Button(action: onPrimary) {
                    Text(primaryLabel)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(MoyeoTheme.forest)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(applicant.name) \(primaryLabel)")
                .accessibilityIdentifier("hostApplicant.\(applicant.id).approve")
            }
        }
        .padding(16)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MoyeoTheme.line, lineWidth: 1)
        }
    }
}

private struct HostApplicantHeader: View {
    let applicant: HostApplicant

    var body: some View {
        HStack(spacing: 12) {
            // 서버 신청자는 프로필 이미지를 준다. 없으면 leaf 원만 남기고 마스코트를 지어내지 않는다.
            if let profileImageURL = applicant.profileImageURL {
                CachedRemoteImage(url: profileImageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    MoyeoTheme.leaf
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                Text(applicant.avatar)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(MoyeoTheme.leaf)
                    .clipShape(Circle())
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(applicant.name)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                Text(applicant.meta)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.muted)
            }
            Spacer()
            // 화면기획 18 — 대기 카드 우상단 더보기
            Image(systemName: "ellipsis")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MoyeoTheme.text400)
        }
    }
}

struct HostManagePill: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    /// 마감 배지(D-3)는 화면기획처럼 코랄 톤으로 구분한다
    private var isDeadline: Bool { text.hasPrefix("D-") }

    var body: some View {
        Text(text)
            .font(.caption.weight(.heavy))
            .foregroundStyle(isDeadline ? MoyeoTheme.coral : MoyeoTheme.forest)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(isDeadline ? MoyeoTheme.coral.opacity(0.14) : MoyeoTheme.leaf)
            .clipShape(Capsule())
    }
}
