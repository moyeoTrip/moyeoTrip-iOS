//
//  SupportComponents.swift
//  MoyeoTrip
//

import SwiftUI

struct SupportList<Content: View>: View {
    let title: String
    let content: Content
    @Environment(\.dismiss) private var dismiss

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(MoyeoTheme.ink)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로")

                Spacer()

                Text(title)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)

                Spacer()

                Color.clear.frame(width: 40, height: 40)
            }
            .frame(height: 56)
            .padding(.horizontal, 8)
            .background(MoyeoTheme.background)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(MoyeoTheme.softLine)
                    .frame(height: 1)
            }

            ScrollView {
                LazyVStack(spacing: 16) {
                    content
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 48)
            }
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct SupportCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .moyeoCard()
    }
}

struct SupportCourseSummary: View {
    let course: TravelCourse
    var compact = false

    var body: some View {
        HStack(spacing: 14) {
            MoyeoPhotoTile(mascot: course.mascot, mood: course.mood, height: compact ? 64 : 82, cornerRadius: 12)
                .frame(width: compact ? 64 : 82)
            VStack(alignment: .leading, spacing: 6) {
                Text(course.title)
                    .font((compact ? Font.subheadline : Font.headline).weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                    .lineLimit(2)
                Text("\(course.region) · \(course.duration) · \(course.distance)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.muted)
                if !compact {
                    Text(course.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(MoyeoTheme.muted)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SupportField: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(MoyeoTheme.forest)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MoyeoTheme.muted)
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MoyeoTheme.ink)
            }
        }
    }
}

struct SupportEditableField: View {
    let title: String
    @Binding var text: String
    var helperText: String?
    var keyboardType: UIKeyboardType = .default
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(MoyeoTheme.muted)
            TextField(title, text: $text)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MoyeoTheme.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .padding(.horizontal, 13)
                .frame(height: 46)
                .background(MoyeoTheme.subtleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(MoyeoTheme.softLine, lineWidth: 1)
                }
                .accessibilityIdentifier(identifier)
            if let helperText {
                Text(helperText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.text400)
            }
        }
    }
}

struct SupportIconBubble: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(MoyeoTheme.forest)
            .frame(width: 42, height: 42)
            .background(MoyeoTheme.leaf)
            .clipShape(Circle())
    }
}
