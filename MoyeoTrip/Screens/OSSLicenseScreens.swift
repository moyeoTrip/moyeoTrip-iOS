import SwiftUI

/// 29-4 오픈소스 라이선스 (changeLog17). 데이터는 번들에 내장돼 있어 로그인·네트워크와 무관하다.
struct OSSLicensesView: View {
    private let items: [OSSLicenseItem]

    init(items: [OSSLicenseItem] = OSSLicenseCatalog.items) {
        self.items = items
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                summaryBox

                HStack {
                    Text("사용 중인 오픈소스")
                        .font(MoyeoTypography.font(size: 13, weight: .heavy, relativeTo: .footnote))
                        .foregroundStyle(MoyeoTheme.ink)
                    Spacer()
                    Text("\(items.count)개")
                        .font(MoyeoTypography.font(size: 11.5, relativeTo: .caption2))
                        .foregroundStyle(MoyeoTheme.muted)
                        .monospacedDigit()
                        .accessibilityIdentifier("ossLicenses.count")
                }
                .padding(.top, 22)
                .padding(.bottom, 6)

                licenseCardList

                footnote
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 28)
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .navigationTitle("오픈소스 라이선스")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("screen.ossLicenses")
    }

    private var summaryBox: some View {
        Text(
            """
            모여트립은 아래 오픈소스 소프트웨어의 도움을 받아 만들었어요. 항목을 누르면 라이선스 전문을 볼 수 있어요. \
            항목 구성은 플랫폼(iOS · Android · 웹)에 따라 달라요.
            """
        )
        .font(MoyeoTypography.font(size: 12.5, relativeTo: .footnote))
        .foregroundStyle(MoyeoTheme.text700)
        .lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoyeoTheme.subtleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MoyeoTheme.softLine, lineWidth: 1)
        }
    }

    private var licenseCardList: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                // 값 기반 라우팅은 이 화면이 이미 라우트 목적지 안에 있어 등록이 겹친다 — 목적지를 직접 준다
                NavigationLink {
                    OSSLicenseDetailView(item: item)
                } label: {
                    OSSLicenseRow(item: item, showsTopDivider: index > 0)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("ossLicenses.item.\(item.name)")
            }
        }
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MoyeoTheme.softLine, lineWidth: 1)
        }
    }

    /// 오픈소스가 아닌 자체 배포 SDK가 섞여 있다는 사실을 감추지 않는다
    private var footnote: some View {
        Text(
            """
            오픈소스 라이선스가 아닌 자체 배포 SDK는 해당 사업자의 약관을 따라요. \
            새 라이브러리를 추가하면 이 목록도 함께 갱신돼요.
            """
        )
        .font(MoyeoTypography.font(size: 11.5, relativeTo: .caption2))
        .foregroundStyle(MoyeoTheme.muted)
        .lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 16)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MoyeoTheme.softLine)
                .frame(height: 1)
        }
        .padding(.top, 20)
    }
}

private struct OSSLicenseRow: View {
    let item: OSSLicenseItem
    let showsTopDivider: Bool

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(MoyeoTypography.font(size: 13.5, weight: .heavy, relativeTo: .footnote))
                    .foregroundStyle(MoyeoTheme.ink)
                Text("\(item.version) · \(item.license)")
                    .font(MoyeoTypography.font(size: 11.5, relativeTo: .caption2))
                    .foregroundStyle(MoyeoTheme.muted)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MoyeoTheme.text400)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 62)
        .contentShape(Rectangle())
        .overlay(alignment: .top) {
            if showsTopDivider {
                Rectangle()
                    .fill(MoyeoTheme.softLine)
                    .frame(height: 1)
            }
        }
    }
}

/// 29-4a 라이선스 전문 (changeLog17). 전문이 없는 자체 배포 SDK는 이름과 원문 URL만 보여준다.
struct OSSLicenseDetailView: View {
    let item: OSSLicenseItem

    private var licenseText: String? {
        OSSLicenseCatalog.licenseText(for: item)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(item.name)
                    .font(MoyeoTypography.font(size: 17, weight: .heavy, relativeTo: .headline))
                    .foregroundStyle(MoyeoTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 7) {
                    versionBadge
                    licenseBadge
                }
                .padding(.top, 9)

                Text("원문 확인 · \(item.url)")
                    .font(MoyeoTypography.font(size: 11.5, relativeTo: .caption2))
                    .foregroundStyle(MoyeoTheme.muted)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
                    .accessibilityIdentifier("ossLicenseDetail.url")

                licenseBody
                    .padding(.top, 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 28)
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .navigationTitle("라이선스 전문")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("screen.ossLicenseDetail")
    }

    private var versionBadge: some View {
        Text(item.version)
            .font(MoyeoTypography.font(size: 11, weight: .heavy, relativeTo: .caption2))
            .foregroundStyle(MoyeoTheme.text700)
            .monospacedDigit()
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(MoyeoTheme.subtleBackground)
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(MoyeoTheme.softLine, lineWidth: 1)
            }
    }

    private var licenseBadge: some View {
        Text(item.license)
            .font(MoyeoTypography.font(size: 11, weight: .heavy, relativeTo: .caption2))
            .foregroundStyle(MoyeoTheme.onLeaf)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(MoyeoTheme.leaf)
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(MoyeoTheme.primary100, lineWidth: 1)
            }
    }

    private var hasLicenseBody: Bool {
        licenseText != nil || !(item.note ?? "").isEmpty
    }

    @ViewBuilder
    private var licenseBody: some View {
        if hasLicenseBody {
            licenseBodyBox
        }
    }

    private var licenseBodyBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let licenseText {
                Text(licenseText)
                    .font(MoyeoTypography.font(size: 11.5, relativeTo: .caption2))
                    .foregroundStyle(MoyeoTheme.text700)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("ossLicenseDetail.text")
            }
            // 전문이 없는 자체 배포 SDK — 라이선스 이름과 원문 URL만 두고 전문을 지어내지 않는다
            if let note = item.note, !note.isEmpty {
                Text(note)
                    .font(MoyeoTypography.font(size: 11.5, relativeTo: .caption2))
                    .foregroundStyle(MoyeoTheme.muted)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("ossLicenseDetail.note")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(MoyeoTheme.subtleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MoyeoTheme.line, lineWidth: 1)
        }
    }
}
