//
//  FeedTimelineComponents.swift
//  MoyeoTrip
//

import SwiftUI

struct FeedMetricBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(MoyeoTheme.muted)
            Text(value)
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(MoyeoTheme.subtleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct FeedPhotoPreview: View {
    let post: FeedPost
    var height: CGFloat = 166

    var body: some View {
        MoyeoPhotoTile(
            mascot: post.photoMascot,
            mood: post.mood,
            height: height,
            cornerRadius: 0
        )
    }
}

extension FeedPost {
    var displayAuthorName: String {
        authorName
    }

    var feedTitle: String {
        if let title, !title.isEmpty {
            return title
        }

        return caption
    }

    var feedSubtitle: String {
        if let subtitle, !subtitle.isEmpty {
            return subtitle
        }

        return tags.map { "#\($0)" }.joined(separator: " ")
    }

    var detailBodyText: String {
        if let detailBody, !detailBody.isEmpty {
            return detailBody
        }

        return caption
    }
}

struct FeedRouteMap: View {
    let route: [String]
    let mood: CourseMood

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let points = routePoints(in: size)
            let dotSize = max(10, size.height * 0.08)

            ZStack {
                RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous)
                    .fill(routeMapBackground)

                ForEach(0..<4, id: \.self) { index in
                    Rectangle()
                        .fill(routeMapLine)
                        .frame(height: 1)
                        .frame(width: size.width * 0.72)
                        .position(x: size.width * 0.58, y: size.height * (0.22 + CGFloat(index) * 0.17))
                }

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    if points.count > 1 {
                        path.addCurve(
                            to: points[1],
                            control1: CGPoint(x: size.width * 0.30, y: size.height * 0.38),
                            control2: CGPoint(x: size.width * 0.36, y: size.height * 0.62)
                        )
                    }
                    if points.count > 2 {
                        path.addCurve(
                            to: points[2],
                            control1: CGPoint(x: size.width * 0.56, y: size.height * 0.60),
                            control2: CGPoint(x: size.width * 0.62, y: size.height * 0.35)
                        )
                    }
                }
                .stroke(
                    MoyeoTheme.forest,
                    style: StrokeStyle(lineWidth: max(3, size.height * 0.045), lineCap: .round)
                )

                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    Text("\(index + 1)")
                        .font(.system(size: max(7, dotSize * 0.45), weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: dotSize, height: dotSize)
                        .background(Circle().fill(index == 0 ? MoyeoTheme.forest : routeMapDot))
                        .overlay(Circle().stroke(routeMapBackground, lineWidth: max(2, dotSize * 0.24)))
                        .position(point)
                }
            }
        }
    }

    private var routeMapBackground: Color {
        adaptiveColor(light: "#EAF3E6", dark: "#14231A")
    }

    private var routeMapLine: Color {
        adaptiveColor(light: "#D7E1D8", dark: "#2C3C34")
    }

    private var routeMapDot: Color {
        MoyeoTheme.forest
    }

    private func routePoints(in size: CGSize) -> [CGPoint] {
        Array(route.prefix(3).enumerated()).map { index, _ in
            switch index {
            case 0:
                return CGPoint(x: size.width * 0.25, y: size.height * 0.62)
            case 1:
                return CGPoint(x: size.width * 0.50, y: size.height * 0.52)
            default:
                return CGPoint(x: size.width * 0.74, y: size.height * 0.36)
            }
        }
    }
}
