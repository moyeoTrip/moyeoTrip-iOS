//
//  TripApplicationSheet.swift
//  MoyeoTrip
//

import SwiftUI

struct ApplicationSheet: View {
    let trip: TripRecruitment
    let onDismiss: () -> Void
    var onSubmitted: () -> Void = {}
    let onSubmit: () -> Void
    @State private var memo = ""
    @State private var didSubmit = false

    private var validationMessage: String? {
        ApplicationNotePolicy.validationMessage(for: memo)
    }

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = max(proxy.safeAreaInsets.bottom, 18)
            ZStack(alignment: .bottom) {
                Color.black
                    .ignoresSafeArea()

                Image(trip.heroImageAssetName)
                    .resizable()
                    .scaledToFill()
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
    }

    private var completionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(MoyeoTheme.forest)
                VStack(alignment: .leading, spacing: 4) {
                    Text("모집에 참여됐어요")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.ink)
                    Text("이제 모임 채팅에서 인사하고 집결 정보를 확인해요.")
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

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("내 소개 카드")
                .font(.headline)
                .foregroundStyle(MoyeoTheme.ink)

            HStack(spacing: 12) {
                MascotAvatar(mascot: "🐻", size: 52, background: MoyeoTheme.leaf)
                VStack(alignment: .leading, spacing: 4) {
                    Text("모여트립이")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.ink)
                    Text("자연 속에서 힐링하는 걸 좋아해요!\n사진 찍는 것도 좋아합니다")
                        .font(.caption)
                        .foregroundStyle(MoyeoTheme.text700)
                        .fixedSize(horizontal: false, vertical: true)
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
        Button {
            guard validationMessage == nil else { return }
            onSubmitted()
            withAnimation(.snappy(duration: 0.24)) {
                didSubmit = true
            }
        } label: {
            Text("신청하기")
                .fontWeight(.bold)
                .font(.subheadline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(MoyeoTheme.forest)
            .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("application.sheet.submit")
    }

    private var openChatButton: some View {
        Button {
            onSubmit()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                Text("모임 채팅으로 이동")
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

struct ApplicationSheetDirectLaunchView: View {
    private let trip = MockData.trip(for: "trip-cheongsong-juwangsan") ?? MockData.trips[0]

    var body: some View {
        ApplicationSheet(trip: trip, onDismiss: {}, onSubmit: {})
            .accessibilityIdentifier("screen.applicationSheet")
    }
}
