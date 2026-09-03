//
//  ReportScreens.swift
//  MoyeoTrip
//
//  신고 두 갈래 (정본 `docs/alignment/REPORT-CANON.md`).
//
//  * 피드 신고 → 실제 접수한다. 30-2 시트([ReportView]).
//  * 멤버·채팅방·댓글 신고 → 접수 API 가 없다. 누른 자리에서 [ReportUnsupportedDialog] 로 안내한다.
//
//  한 화면에 두 결과를 섞지 않는다 — "접수되지 않는 경로에서 접수된 것처럼 보이게 하지 않는다"(정본 §4).
//

import SwiftUI

/// 접수 API 가 없는 신고를 **누른 자리에서** 안내한다 (정본 §3).
///
/// 화면을 옮기지 않는다 — 문의 버튼은 29 설정 안에 있어서 거기로 보내면 하려던 일에서 멀어진다.
/// 문구·버튼은 네 표면(기획 `ReportUnsupportedDialog` · 웹 · 안드로이드 · iOS)이 **글자까지 같은 것**을 쓴다.
struct ReportUnsupportedDialog: View {
  var onClose: () -> Void = {}
  @Environment(\.openURL) private var openURL

  var body: some View {
    ZStack {
      MoyeoTheme.overlayScrim
        .ignoresSafeArea()
        .onTapGesture { onClose() }

      VStack(alignment: .leading, spacing: 0) {
        Text("신고를 접수하지 못해요")
          .font(.headline.weight(.heavy))
          .foregroundStyle(MoyeoTheme.ink)
          .fixedSize(horizontal: false, vertical: true)

        Text("멤버·채팅방 신고는 아직 앱에서 받지 못해요. GitHub 이슈나 이메일로 알려주시면 확인할게요.")
          .font(.subheadline)
          .foregroundStyle(MoyeoTheme.muted)
          .lineSpacing(4)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 8)

        VStack(spacing: 8) {
          contactButton(
            title: MoyeoContact.issuesLabel,
            url: MoyeoContact.issuesURL,
            identifier: "reportUnsupported.issues"
          )
          contactButton(
            title: MoyeoContact.emailLabel,
            url: MoyeoContact.mailtoURL,
            identifier: "reportUnsupported.email"
          )
          Button(action: onClose) {
            Text("닫기")
              .font(.subheadline.weight(.bold))
              .foregroundStyle(MoyeoTheme.muted)
              .frame(maxWidth: .infinity)
              .frame(height: 44)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("reportUnsupported.close")
        }
        .padding(.top, 16)
      }
      .padding(20)
      .frame(maxWidth: 330)
      .background(MoyeoTheme.card)
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 18).stroke(MoyeoTheme.line))
      .shadow(color: Color.black.opacity(0.28), radius: 24, y: 10)
    }
    .accessibilityIdentifier("screen.reportUnsupported")
  }

  private func contactButton(title: String, url: URL, identifier: String) -> some View {
    Button {
      openURL(url)
    } label: {
      Text(title)
        .font(.subheadline.weight(.bold))
        .foregroundStyle(MoyeoTheme.ink)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoyeoTheme.line))
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(identifier)
  }
}

/// 30-2 신고 시트. **피드 전용이다** (정본 §1) —
/// 서버가 실제로 받는 신고는 `POST /api/v1/feeds/{feedId}/reports` 하나뿐이다.
///
/// 사유는 `GET /api/v1/feeds/report-reasons` 가 코드와 표시 문구를 함께 준다.
/// **클라이언트가 사유를 갖지 않는다** — 예전에는 여기에 6종을 박아 뒀고 그 문구가
/// 서버 `displayName` 과 달랐다(`스팸 · 도박` 같은 없는 이름을 보여주고 있었다).
/// 목록을 못 받으면 사유를 지어내지 않고 로딩·오류 상태를 그린다 (NO-MOCK-CANON R1).
/// 30-2 시트 뒤에 깔리는 화면. 피드를 아직 못 받았으면 배경색만 둔다 — 채팅방을 깔지 않는다.
///
/// `ReportView` 안의 계산 프로퍼티로 두면 SwiftLint `type_body_length`(300줄)를 넘는다.
private struct ReportBackdrop: View {
  let feed: ServerFeed?

  var body: some View {
    if let feed {
      FeedDetailView(post: ServerFeedMapper.post(from: feed))
        .allowsHitTesting(false)
    } else {
      MoyeoTheme.background
    }
  }
}

struct ReportView: View {
  /// 사유 목록 요청 상태. `loaded` 가 아니면 사유 줄을 그리지 않는다.
  private enum ReasonsState {
    case loading
    case loaded([ServerFeedReportReason])
    case failed
  }

  /// 제출 뒤 시트에 남는 안내. 붉은 오류와 중복 신고 안내를 섞지 않는다 (정본 §2).
  private enum SubmitNotice {
    /// `409 40917` — 이미 신고한 피드. 오류가 아니다.
    case duplicate
    /// 신고는 204 로 접수됐는데 차단만 실패한 경우. 신고를 되돌리지 않는다 (정본 §2).
    case blockFailed(String)
    case failed(String)
  }

  /// `details` 상한. 서버가 `size must be between 0 and 300` 으로 거절한다 (실서버 확인).
  private static let detailsLimit = 300

  /// 신고 대상 피드.
  let feedID: Int64
  /// 시트 상단 미리보기. 없으면 서버 피드를 받아 채운다.
  var previewText: String?
  /// 차단 대상 = 피드 작성자. 끝까지 모르면 차단 줄을 두지 않는다(누구를 차단하는지 못 적는다).
  var authorUserID: Int64?
  var authorNickname: String?

  @Environment(\.dismiss) private var dismiss
  @State private var reasonsState: ReasonsState = .loading
  @State private var selectedReason: String?
  @State private var details = ""
  @State private var blocksUser = true
  @State private var isSubmitting = false
  @State private var notice: SubmitNotice?
  /// 서버 피드로 채운 미리보기·작성자. 진입점이 값을 주면 부르지 않는다.
  @State private var loadedFeed: ServerFeed?

  init(
    feedID: Int64,
    previewText: String? = nil,
    authorUserID: Int64? = nil,
    authorNickname: String? = nil
  ) {
    self.feedID = feedID
    self.previewText = previewText
    self.authorUserID = authorUserID
    self.authorNickname = authorNickname
  }

  /// 23 피드 상세에서 그대로 넘긴다 — 화면이 이미 가진 값을 다시 부르지 않는다.
  init?(post: FeedPost) {
    guard let feedID = post.serverFeedID else { return nil }
    self.init(
      feedID: feedID,
      previewText: post.feedTitle.isEmpty ? post.caption : post.feedTitle,
      authorUserID: post.serverAuthorID,
      authorNickname: post.displayAuthorName.isEmpty ? nil : post.displayAuthorName
    )
  }

  private var blockTargetUserID: Int64? {
    authorUserID ?? loadedFeed?.author.userId
  }

  private var blockTargetNickname: String? {
    if let authorNickname, !authorNickname.isEmpty { return authorNickname }
    return loadedFeed?.author.nickname
  }

  private var displayPreview: String? {
    if let previewText, !previewText.isEmpty { return previewText }
    guard let loadedFeed else { return nil }
    return loadedFeed.trip.courseTitle.isEmpty ? loadedFeed.content : loadedFeed.trip.courseTitle
  }

  private var canSubmit: Bool {
    selectedReason != nil && !isSubmitting
  }

  var body: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 0)
      sheet
    }
    // 예전 문구는 "24시간 이내에 검토해 드릴게요."·"신고 3건이 모이면 자동 비공개" 였다.
    // 서버 정책 문구를 구현이 단정하지 않는다 (정본 §4).
    // 시트가 뜨는 자리는 **23 피드 상세**다 — 그 화면을 깔아야 "위에 떠 있다"로 읽힌다
    // (changeLog14 "오버레이 배경 일괄": 빈 딤은 캡처에서 깨진 화면처럼 보인다).
    // 예전엔 채팅방을 깔고 있었다 — 시트가 채팅방 신고였던 시절의 잔재다.
    // 안드로이드도 `FeedDetailScreen` 을 깐다.
    .background(ReportBackdrop(feed: loadedFeed))
    .toolbar(.hidden, for: .navigationBar)
    .accessibilityIdentifier("screen.report")
    .task { await load() }
  }

  private var sheet: some View {
    VStack(alignment: .leading, spacing: 10) {
      Capsule()
        .fill(MoyeoTheme.softLine)
        .frame(width: 36, height: 4)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
      Text("신고 사유를 알려주세요")
        .font(MoyeoTypography.sectionTitle)
      previewRow
      reasonList
      if case .loaded = reasonsState {
        detailsEditor
        blockRow
      }
      actionRow
      noticeRow
    }
    .padding(.horizontal, 20)
    .padding(.top, 12)
    .padding(.bottom, 28)
    .background(MoyeoTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
  }

  @ViewBuilder
  private var previewRow: some View {
    if let displayPreview {
      Label(displayPreview, systemImage: "photo.on.rectangle")
        .font(.caption)
        .lineLimit(1)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .background(MoyeoTheme.subtleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
  }

  @ViewBuilder
  private var reasonList: some View {
    switch reasonsState {
    case .loading:
      Text(MoyeoEmptyText.loading)
        .font(.subheadline)
        .foregroundStyle(MoyeoTheme.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 18)
        .accessibilityIdentifier("report.reasons.loading")
    case .failed:
      VStack(alignment: .leading, spacing: 8) {
        Text(MoyeoEmptyText.loadFailed)
          .font(.subheadline)
          .foregroundStyle(MoyeoTheme.muted)
        Button(MoyeoEmptyText.retry) {
          reasonsState = .loading
          Task { await loadReasons() }
        }
        .font(.subheadline.weight(.heavy))
        .foregroundStyle(MoyeoTheme.brandText)
        .accessibilityIdentifier("report.reasons.retry")
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 14)
      .accessibilityIdentifier("report.reasons.failed")
    case .loaded(let reasons):
      ForEach(reasons) { item in
        ChangelogRadioOption(title: item.displayName, isSelected: selectedReason == item.reason) {
          selectedReason = item.reason
        }
      }
    }
  }

  /// 상세 입력 — 서버 `details` 는 선택이고 최대 300자다. 기타를 골랐을 때 특히 필요하다.
  private var detailsEditor: some View {
    VStack(alignment: .leading, spacing: 0) {
      ZStack(alignment: .topLeading) {
        if details.isEmpty {
          Text("어떤 점이 문제인지 알려주세요 (선택)")
            .font(.subheadline)
            .foregroundStyle(MoyeoTheme.text400)
            .padding(.top, 8)
            .padding(.leading, 5)
        }
        TextEditor(text: $details)
          .font(.subheadline)
          .foregroundStyle(MoyeoTheme.ink)
          .scrollContentBackground(.hidden)
          .frame(minHeight: 72)
          .onChange(of: details) { _, value in
            if value.count > Self.detailsLimit {
              details = String(value.prefix(Self.detailsLimit))
            }
          }
          .accessibilityIdentifier("report.details")
      }
      // 간격까지 네 표면이 같다 — 기획·웹·안드로이드가 `0 / 300` 이다.
      Text("\(details.count) / \(Self.detailsLimit)")
        .font(.caption2.weight(.bold))
        .foregroundStyle(MoyeoTheme.text400)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding(10)
    .background(MoyeoTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(MoyeoTheme.line, lineWidth: 1)
    }
  }

  /// 차단은 신고와 **따로** 보낸다 — `POST /users/me/blocks/{작성자 userId}` (정본 §2).
  /// 작성자를 모르면 줄을 두지 않는다: 누구를 차단하는지 적을 수 없다.
  @ViewBuilder
  private var blockRow: some View {
    if blockTargetUserID != nil {
      MoyeoCheckRow(
        title: "이 유저를 차단할게요",
        isOn: $blocksUser,
        accessibilityIdentifier: "report.blockUser"
      )
      if blocksUser {
        Text("차단하면 이 유저가 만들었거나 참여한 모집이 홈·탐색에서 모두 숨겨져요.")
          .font(.caption2)
          .foregroundStyle(MoyeoTheme.muted)
      }
    }
  }

  // 취소는 좁은 중립 글자, 신고하기는 넓은 채움 — 둘을 같은 너비로 두면 위계가 사라진다 (화면기획)
  private var actionRow: some View {
    HStack(spacing: 8) {
      Button("취소") { dismiss() }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(MoyeoTheme.ink)
        .frame(width: 62, height: 48)
        .accessibilityIdentifier("report.cancel")
      Button(action: submit) {
        Text(isSubmitting ? "접수 중..." : "신고하기")
          .font(.subheadline.weight(.heavy))
          .foregroundStyle(canSubmit ? .white : MoyeoTheme.muted)
          .frame(maxWidth: .infinity)
          .frame(height: 48)
          .background(canSubmit ? MoyeoTheme.dangerRed : MoyeoTheme.subtleBackground)
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      }
      .buttonStyle(.plain)
      .disabled(!canSubmit)
      .accessibilityIdentifier("report.submit")
    }
  }

  @ViewBuilder
  private var noticeRow: some View {
    switch notice {
    case .none:
      EmptyView()
    case .duplicate:
      // `409 40917` 은 오류가 아니다 — 붉게 띄우지 않고 안내로 적는다 (정본 §2).
      Text("이미 신고한 피드예요")
        .font(.caption)
        .foregroundStyle(MoyeoTheme.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .accessibilityIdentifier("report.duplicate")
    case .blockFailed(let message):
      VStack(alignment: .leading, spacing: 4) {
        Text("신고는 접수했어요. 차단은 반영되지 않았어요.")
          .font(.caption)
          .foregroundStyle(MoyeoTheme.muted)
        Text(message)
          .font(.caption)
          .foregroundStyle(MoyeoTheme.dangerRed)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 8)
      .accessibilityIdentifier("report.blockFailed")
    case .failed(let message):
      Text(message)
        .font(.caption)
        .foregroundStyle(MoyeoTheme.dangerRed)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .accessibilityIdentifier("report.error")
    }
  }

  private func load() async {
    await loadReasons()
    // 진입점이 미리보기·작성자를 안 줬을 때만 피드를 받는다 (캡처·딥링크 경로).
    let needsFeed = previewText == nil || authorUserID == nil
    if needsFeed, loadedFeed == nil, MoyeoServerSync.isEnabled {
      loadedFeed = try? await FeedAPIClient.shared.feed(id: feedID)
    }
  }

  private func loadReasons() async {
    guard MoyeoServerSync.isEnabled else {
      reasonsState = .failed
      return
    }
    do {
      let reasons = try await FeedAPIClient.shared.reportReasons()
      reasonsState = reasons.isEmpty ? .failed : .loaded(reasons)
      // 첫 사유를 미리 고른다 — 웹·안드로이드와 같다. 고르지 않은 상태로 두면
      // 「신고하기」가 비활성으로 찍히고, 같은 아트보드가 표면마다 다르게 보인다.
      // 사유 코드를 클라가 갖지 않으려고 **서버 목록의 첫 항목**을 쓴다.
      if selectedReason == nil { selectedReason = reasons.first?.reason }
    } catch {
      reasonsState = .failed
    }
  }

  private func submit() {
    guard let reason = selectedReason, !isSubmitting else { return }
    isSubmitting = true
    notice = nil
    Task {
      do {
        try await FeedAPIClient.shared.report(feedID: feedID, reason: reason, details: details)
      } catch {
        isSubmitting = false
        notice = Self.notice(for: error)
        return
      }
      // 신고는 접수됐다. 차단은 별개 요청이라 실패해도 신고를 되돌리지 않는다 (정본 §2).
      guard blocksUser, let userID = blockTargetUserID else {
        isSubmitting = false
        dismiss()
        return
      }
      do {
        try await SocialAPIClient.shared.block(userID: userID)
        isSubmitting = false
        dismiss()
      } catch {
        isSubmitting = false
        notice = .blockFailed(
          (error as? LocalizedError)?.errorDescription ?? "차단하지 못했어요."
        )
      }
    }
  }

  /// `409 40917` = 이미 신고한 피드. 나머지는 서버 문구를 그대로 보여준다.
  private static func notice(for error: Error) -> SubmitNotice {
    if let apiError = error as? MoyeoAPIError,
      case .server(let statusCode, let code, _) = apiError,
      statusCode == 409 || code == MoyeoServerErrorCode.feedAlreadyReported {
      return .duplicate
    }
    return .failed((error as? LocalizedError)?.errorDescription ?? "신고를 접수하지 못했어요.")
  }
}
