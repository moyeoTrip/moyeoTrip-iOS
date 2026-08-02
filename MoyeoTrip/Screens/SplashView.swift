//
//  SplashView.swift
//  MoyeoTrip
//

import SwiftUI

struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme

    private let imageAsset = SplashPolicy.imageAsset

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Image(imageAsset.catalogName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .accessibilityHidden(true)

                splashOverlay
                    .frame(width: proxy.size.width, height: proxy.size.height)

                VStack(spacing: 10) {
                    Text("모여트립 in 경북")
                        .font(.system(size: 36, weight: .black))
                        .foregroundStyle(titleColor)
                    Text("경상북도 특화 반패키지 매칭 플랫폼")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(subtitleColor)
                }
                .frame(width: proxy.size.width)
                .multilineTextAlignment(.center)
                .shadow(
                    color: colorScheme == .dark ? .black.opacity(0.46) : .clear,
                    radius: 18,
                    x: 0,
                    y: 2
                )
                .padding(.top, 156)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(backgroundColor)
        }
        .ignoresSafeArea()
        .transaction { transaction in
            transaction.disablesAnimations = true
        }
        .accessibilityIdentifier("screen.splash")
    }

    private var backgroundColor: Color {
        if colorScheme == .dark {
            return Color(red: 0.03, green: 0.09, blue: 0.07)
        }

        return Color(red: 0.94, green: 0.97, blue: 0.94)
    }

    private var titleColor: Color {
        if colorScheme == .dark {
            return Color(red: 0.91, green: 0.97, blue: 0.93)
        }

        return Color(red: 0.06, green: 0.36, blue: 0.24)
    }

    private var subtitleColor: Color {
        if colorScheme == .dark {
            return Color(red: 0.75, green: 0.91, blue: 0.80)
        }

        return Color(red: 0.06, green: 0.30, blue: 0.21)
    }

    private var splashOverlay: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                stops: [
                    .init(color: Color(red: 0.02, green: 0.05, blue: 0.04).opacity(0.30), location: 0),
                    .init(color: Color(red: 0.02, green: 0.05, blue: 0.04).opacity(0.02), location: 0.42),
                    .init(color: Color(red: 0.02, green: 0.05, blue: 0.04).opacity(0.18), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        return LinearGradient(
            stops: [
                .init(color: Color.white.opacity(0.10), location: 0),
                .init(color: Color.white.opacity(0), location: 0.38)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
