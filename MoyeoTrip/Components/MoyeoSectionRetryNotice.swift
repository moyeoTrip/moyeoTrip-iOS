//
//  MoyeoSectionRetryNotice.swift
//  MoyeoTrip
//
//  한 섹션의 조회가 **실패**했을 때 쓰는 안내 + 다시 시도.
//
//  정본 `NO-MOCK-CANON.md` R1 은 네 상태를 갈라 놓으라고 적는다 —
//  실데이터 / 빈 상태 / 로딩 / **오류 + 다시 시도**. 그런데 iOS 는 실패해도 목록이
//  비어 있을 뿐이라 「아직 없어요」로 보였고, 다시 받아 볼 길도 없었다
//  (TC HOME-014·HOME-015·HOME-016).
//

import SwiftUI

struct MoyeoSectionRetryNotice: View {
    let message: String
    /// 접근성 식별자 접두사. `<identifier>.failed` · `<identifier>.retry` 가 만들어진다.
    let identifier: String
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(MoyeoTheme.warningText)
            Text(message)
                .font(MoyeoTypography.cardMeta)
                .foregroundStyle(MoyeoTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("다시 시도", action: onRetry)
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.brandText)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("\(identifier).retry")
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoyeoTheme.warningBackground)
        .clipShape(RoundedRectangle(cornerRadius: MoyeoTheme.cardRadius, style: .continuous))
        .accessibilityIdentifier("\(identifier).failed")
    }
}
