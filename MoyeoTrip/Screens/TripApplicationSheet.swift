//
//  TripApplicationSheet.swift
//  MoyeoTrip
//

import SwiftUI

/// 16 「내 소개 카드」의 아바타.
///
/// `GET /users/me/profile` 이 `profileImageUrl` 을 주면 **그 사진**을 그린다.
/// 예전에는 URL 이 있어도 무조건 닉네임에서 동물 이모지를 뽑아서, 프로필 사진을 올린
/// 계정도 이모지로 보였다. 닉네임 동물은 URL 이 **없을 때만** 쓰는 대체 표시다
/// (NO-MOCK-CANON R5 — 15 동행자 아바타 · 20-1 멤버 목록이 이미 이 규칙이다).
private struct ApplicationIntroAvatar: View {
    let profile: ServerMyProfile

    private var mascot: String {
        MoyeoNicknameAnimal.emoji(forNickname: profile.nickname) ?? MoyeoNicknameAnimal.unknown
    }

    var body: some View {
        if let url = MoyeoImageURL.resolve(profile.profileImageUrl) {
            CachedRemoteImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                MascotAvatar(mascot: mascot, size: 52, background: MoyeoTheme.leaf)
            }
            .frame(width: 52, height: 52)
            .clipShape(Circle())
        } else {
            MascotAvatar(mascot: mascot, size: 52, background: MoyeoTheme.leaf)
        }
    }
}

struct ApplicationSheet: View {
    let trip: TripRecruitment
    let onDismiss: () -> Void
    var onSubmitted: () -> Void = {}
    let onSubmit: () -> Void
    /// 실서버 모임이면 신청을 서버에 보낸다 — 목데이터 모임은 기존 동작 그대로
    var serverSubmitHandler: ((String) async throws -> ServerJoinResult)?
    @State private var memo = ""
    @State private var didSubmit = false
    @State private var isSubmitting = false
    @State private var submitErrorMessage: String?
    @State private var serverResult: ServerJoinResult?
    /// 16 "내 소개 카드"에 그릴 내 프로필 — 서버가 준 값만 쓴다 (NO-MOCK-CANON R1)
    @State private var myProfile: ServerMyProfile?

    private var validationMessage: String? {
        ApplicationNotePolicy.validationMessage(for: memo)
    }

    private var completionTitle: String {
        switch serverResult {
        case .pendingApproval:
            return "참가 신청을 보냈어요"
        case .waitlisted:
            return "대기열에 등록됐어요"
        default:
            return "모집에 참여됐어요"
        }
    }

    private var completionSubtitle: String {
        switch serverResult {
        case .pendingApproval:
            return "호스트가 승인하면 채팅방이 열려요. 결과는 알림으로 알려드려요."
        case .waitlisted:
            return "자리가 나면 순서대로 자동 합류돼요."
        default:
            return "이제 모임 채팅에서 인사하고 집결 정보를 확인해요."
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = max(proxy.safeAreaInsets.bottom, 18)
            ZStack(alignment: .bottom) {
                Color.black
                    .ignoresSafeArea()

                TripDetailHeroImage(trip: trip)
                    .frame(width: proxy.size.width, height: 330)
                    .clipped()
                    .overlay(.black.opacity(0.44))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)
                    .accessibilityHidden(true)

                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 18)
                .padding(.top, max(proxy.safeAreaInsets.top + 12, 52))

                // 화면기획처럼 시트 높이는 콘텐츠에 맞춘다 — 내부 스크롤 없이
                // 내 소개 카드까지 온전히 보이고 신청하기 버튼이 그 아래 온다.
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 18) {
                        sheetHeader
                        if didSubmit {
                            completionCard
                        } else {
                            applicationMessage
                            introCard
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                    Group {
                        if didSubmit {
                            openChatButton
                        } else {
                            submitButton
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, bottomInset)
                }
                .background(MoyeoTheme.card)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 24,
                        topTrailingRadius: 24,
                        style: .continuous
                    )
                )
            }
        }
        .task {
            guard MoyeoServerSync.isEnabled, myProfile == nil else { return }
            myProfile = try? await UserProfileAPIClient.shared.myProfile()
        }
    }

    private var completionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(MoyeoTheme.forest)
                VStack(alignment: .leading, spacing: 4) {
                    Text(completionTitle)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.ink)
                    Text(completionSubtitle)
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.muted)
                }
            }

            Text(memo)
                .font(.subheadline)
                .foregroundStyle(MoyeoTheme.text700)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MoyeoTheme.subtleBackground)
                .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
        }
        .padding(16)
        .background(MoyeoTheme.leaf)
        .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
    }

    private var sheetHeader: some View {
        HStack {
            Text("함께 가기 신청")
                .font(.title3.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(MoyeoTheme.muted)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("닫기")
        }
    }

    private var applicationMessage: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("한마디를 남겨주세요!")
                .font(.headline)
                .foregroundStyle(MoyeoTheme.ink)

            // 화면기획 16 — 진입 상태에 에러 문구·별도 카운터 행은 없다.
            // 플레이스홀더가 두 줄 안내를 담고, 카운터는 박스 내부 우하단에 둔다.
            ZStack(alignment: .topLeading) {
                if memo.isEmpty {
                    Text("간단한 인사나 기대하는 마음을\n남겨주세요 😊 (10자 이상 200자 이하)")
                        .font(.subheadline)
                        .foregroundStyle(MoyeoTheme.text400)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)
                }
                TextField("", text: $memo, axis: .vertical)
                    .font(.subheadline)
                    .foregroundStyle(MoyeoTheme.ink)
                    .lineLimit(3...6)
                    .onChange(of: memo) { _, newValue in
                        if newValue.count > ApplicationNotePolicy.maximumLength {
                            memo = String(newValue.prefix(ApplicationNotePolicy.maximumLength))
                        }
                    }
            }
            .padding(12)
            .padding(.bottom, 16)
            .frame(minHeight: 112, alignment: .topLeading)
            .background(MoyeoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                    .stroke(MoyeoTheme.softLine, lineWidth: 1)
            }
            .overlay(alignment: .bottomTrailing) {
                Text("\(memo.count)/\(ApplicationNotePolicy.maximumLength)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(MoyeoTheme.text400)
                    .padding(.trailing, 12)
                    .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private var introCard: some View {
        if let myProfile {
            introCardBody(myProfile)
        }
    }

    private func introCardBody(_ profile: ServerMyProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("내 소개 카드")
                .font(.headline)
                .foregroundStyle(MoyeoTheme.ink)

            HStack(spacing: 12) {
                ApplicationIntroAvatar(profile: profile)
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.nickname)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.ink)
                    // 자기소개는 서버 값이다 — 없으면 그 줄을 만들지 않는다
                    if let introduction = profile.introduction, !introduction.isEmpty {
                        Text(introduction)
                            .font(.caption)
                            .foregroundStyle(MoyeoTheme.text700)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(14)
            .background(MoyeoTheme.subtleBackground)
            .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                    .stroke(MoyeoTheme.softLine, lineWidth: 1)
            }
        }
    }

    private var submitButton: some View {
        VStack(spacing: 8) {
            if let submitErrorMessage {
                Text(submitErrorMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.coral)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("application.sheet.error")
            }
            Button {
                guard validationMessage == nil, !isSubmitting else { return }
                if let serverSubmitHandler {
                    submitErrorMessage = nil
                    isSubmitting = true
                    Task {
                        do {
                            serverResult = try await serverSubmitHandler(memo)
                            onSubmitted()
                            withAnimation(.snappy(duration: 0.24)) {
                                didSubmit = true
                            }
                        } catch {
                            submitErrorMessage = (error as? LocalizedError)?.errorDescription
                                ?? "신청을 보내지 못했어요. 잠시 후 다시 시도해주세요."
                        }
                        isSubmitting = false
                    }
                } else {
                    onSubmitted()
                    withAnimation(.snappy(duration: 0.24)) {
                        didSubmit = true
                    }
                }
            } label: {
                Text(isSubmitting ? "신청 보내는 중…" : "신청하기")
                    .fontWeight(.bold)
                    .font(.subheadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(MoyeoTheme.forest.opacity(isSubmitting ? 0.6 : 1))
                .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("application.sheet.submit")
        }
    }

    private var openChatButton: some View {
        Button {
            onSubmit()
        } label: {
            HStack(spacing: 8) {
                if serverResult == nil || serverResult == .joined {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                }
                Text(serverResult == nil || serverResult == .joined ? "모임 채팅으로 이동" : "확인")
                    .fontWeight(.bold)
            }
            .font(.subheadline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(MoyeoTheme.forest)
            .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("application.sheet.openChat")
    }
}
