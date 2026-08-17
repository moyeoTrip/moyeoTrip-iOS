//
//  MoyeoComponents.swift
//  MoyeoTrip
//

import SwiftUI

enum QAScrollState {
    case middle
    case bottom

    static var requested: QAScrollState? {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("UITEST_MODE") else { return nil }

        if arguments.contains("UITEST_SCROLL=bottom") {
            return .bottom
        }
        if arguments.contains("UITEST_SCROLL=middle") {
            return .middle
        }
        return nil
    }

    func targetID(middle: String, bottom: String) -> String {
        switch self {
        case .middle:
            return middle
        case .bottom:
            return bottom
        }
    }

    var anchor: UnitPoint {
        switch self {
        case .middle:
            return .center
        case .bottom:
            return .bottom
        }
    }

    var qaSpacerHeight: CGFloat {
        320
    }
}

struct MoyeoHeader: View {
    let title: String
    var rightSystemImage: String?
    var rightAccessibilityLabel: String = "더보기"
    var isRightActionEnabled = true
    var rightDisabledHint: String?
    var showsBottomBorder = false
    var action: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(MoyeoTypography.screenTitle)
                .foregroundStyle(MoyeoTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer()

            if let rightSystemImage {
                Button(action: action) {
                    Image(systemName: rightSystemImage)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(MoyeoTheme.ink)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .disabled(!isRightActionEnabled)
                .opacity(isRightActionEnabled ? 1 : 0.42)
                .accessibilityLabel(rightAccessibilityLabel)
                .accessibilityHint(isRightActionEnabled ? "" : (rightDisabledHint ?? "현재 사용할 수 없어요"))
            } else {
                Color.clear
                    .frame(width: 34, height: 34)
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 18)
        .background(MoyeoTheme.background)
        .overlay(alignment: .bottom) {
            if showsBottomBorder {
                Rectangle()
                    .fill(MoyeoTheme.softLine)
                    .frame(height: 1)
            }
        }
    }
}

struct SectionTitle: View {
    let title: String
    var actionTitle: String?

    var body: some View {
        HStack {
            Text(title)
                .font(MoyeoTypography.sectionTitle)
                .foregroundStyle(MoyeoTheme.ink)
            Spacer()
            if let actionTitle {
                Text(actionTitle)
                    .font(MoyeoTypography.cardMeta)
                    .foregroundStyle(MoyeoTheme.muted)
            }
        }
        .padding(.horizontal, 20)
    }
}

struct Pill: View {
    let text: String
    var tint: Color = MoyeoTheme.forest

    var body: some View {
        Text(text)
            .font(MoyeoTypography.chip)
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct MetricChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.bold())
            Text(text)
                .font(MoyeoTypography.cardMeta)
                .lineLimit(1)
        }
        .foregroundStyle(MoyeoTheme.muted)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(MoyeoTheme.background)
        .clipShape(Capsule())
    }
}

struct MascotAvatar: View {
    let mascot: String
    var size: CGFloat = 42
    var background: Color = MoyeoTheme.leaf

    var body: some View {
        Text(mascot)
            .font(.system(size: size * 0.48))
            .frame(width: size, height: size)
            .background(background)
            .clipShape(Circle())
    }
}

struct MoyeoPhotoTile: View {
    let mascot: String
    var mood: CourseMood = .forest
    var label: String?
    var height: CGFloat = 82
    var cornerRadius: CGFloat = 10
    var overlay = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { proxy in
                let size = proxy.size

                LinearGradient(
                    colors: mood.landscapeSkyColors,
                    startPoint: .top,
                    endPoint: .bottom
                )

                Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height * 0.48))
                    path.addLine(to: CGPoint(x: size.width * 0.20, y: size.height * 0.30))
                    path.addLine(to: CGPoint(x: size.width * 0.38, y: size.height * 0.46))
                    path.addLine(to: CGPoint(x: size.width * 0.55, y: size.height * 0.25))
                    path.addLine(to: CGPoint(x: size.width * 0.80, y: size.height * 0.50))
                    path.addLine(to: CGPoint(x: size.width, y: size.height * 0.34))
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.addLine(to: CGPoint(x: 0, y: size.height))
                    path.closeSubpath()
                }
                .fill(mood.landscapeBackMountain)

                Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height * 0.68))
                    path.addCurve(
                        to: CGPoint(x: size.width, y: size.height * 0.58),
                        control1: CGPoint(x: size.width * 0.30, y: size.height * 0.46),
                        control2: CGPoint(x: size.width * 0.66, y: size.height * 0.76)
                    )
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.addLine(to: CGPoint(x: 0, y: size.height))
                    path.closeSubpath()
                }
                .fill(mood.landscapeFrontMountain)

                Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height * 0.82))
                    path.addCurve(
                        to: CGPoint(x: size.width, y: size.height * 0.74),
                        control1: CGPoint(x: size.width * 0.28, y: size.height * 0.72),
                        control2: CGPoint(x: size.width * 0.64, y: size.height * 0.90)
                    )
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.addLine(to: CGPoint(x: 0, y: size.height))
                    path.closeSubpath()
                }
                .fill(mood.landscapeGround)
            }

            if let label {
                Text(label)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(MoyeoTheme.forest)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(7)
            }

            if overlay {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.34)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct ParticipantStack: View {
    let participants: [Participant]
    var limit: Int = 4
    var size: CGFloat = 30

    var body: some View {
        HStack(spacing: -8) {
            ForEach(Array(participants.prefix(limit))) { participant in
                MascotAvatar(mascot: participant.avatar, size: size, background: MoyeoTheme.background)
                    .overlay(Circle().stroke(MoyeoTheme.card, lineWidth: 2))
            }
            if participants.count > limit {
                Text("+\(participants.count - limit)")
                    .font(.caption2.bold())
                    .foregroundStyle(MoyeoTheme.forest)
                    .frame(width: size, height: size)
                    .background(MoyeoTheme.leaf)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(MoyeoTheme.card, lineWidth: 2))
            }
        }
    }
}

struct PrimaryActionButton: View {
    let title: String
    let systemImage: String
    var tint: Color = MoyeoTheme.forest
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
                    .fontWeight(.bold)
            }
            .font(.subheadline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MoyeoTheme.muted)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.caption.weight(.semibold))
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(MoyeoTheme.muted.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 38)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(MoyeoTheme.line, lineWidth: 1)
        }
    }
}

struct ProgressBar: View {
    let value: Double
    var tint: Color = MoyeoTheme.forest
    var marker: Double?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(MoyeoTheme.line)
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * min(max(value, 0), 1))
                if let marker {
                    Capsule()
                        .fill(MoyeoTheme.ink.opacity(0.72))
                        .frame(width: 3, height: 12)
                        .offset(x: proxy.size.width * min(max(marker, 0), 1) - 1.5)
                }
            }
        }
        .frame(height: 5)
    }
}
