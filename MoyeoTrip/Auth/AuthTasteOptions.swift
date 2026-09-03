//
//  AuthTasteOptions.swift
//  MoyeoTrip
//
//  06-1 취향 단계의 후보 목록. `docs/alignment/SIGNUP-GATE-CANON.md` R4.
//

import Combine
import Foundation

/// 취향 칩 하나. 화면은 `label` 을 그리고, 서버로는 `id` 를 보낸다.
///
/// 라벨로 주고받으면 `경주` 와 `경주시` 처럼 표기가 조금만 달라도 선택이 통째로 유실된다.
struct TravelTasteOption: Identifiable, Hashable {
    let id: Int64
    let label: String
}

/// 06-1 여행 스타일·관심 지역 후보를 **서버에서 받아온다**.
///
/// 여기 하드코딩 표(스타일 12 · 지역 24)가 있었다. "가입 전에는 토큰이 없어
/// `GET /users/me/profile/options` 를 부를 수 없다"는 이유였는데,
/// **2026-08-30 서버 회신·실측으로 이 API 가 토큰 없이 200 인 것이 확인됐다.**
/// 그래서 거울 표를 지웠다 — 서버가 시드를 바꾸면 화면도 따라 바뀌는 게 원래 의도였다.
///
/// 못 받으면 칩을 하나도 그리지 않고 다시 시도를 띄운다. 고를 수 없는 후보를 지어내지 않는다
/// (NO-MOCK-CANON R1). 여기 없는 id 를 보내면 서버가 `40015`(스타일)·`40014`(지역) 로 가입을 막는다.
@MainActor
final class AuthTasteOptionsModel: ObservableObject {
    @Published private(set) var travelStyles: [TravelTasteOption] = []
    @Published private(set) var interestedRegions: [TravelTasteOption] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadFailed = false

    private let client: UserProfileAPIClient

    /// 기본값을 인자에 두면 호출부(비격리 컨텍스트)에서 `.shared` 를 읽게 되어 경고가 난다.
    init(client: UserProfileAPIClient? = nil) {
        self.client = client ?? .shared
    }

    var isEmpty: Bool {
        travelStyles.isEmpty && interestedRegions.isEmpty
    }

    func load() async {
        guard !isLoading else { return }
        // 서버가 공개로 열어 둔 엔드포인트다 — 가입 중(세션 없음)에도 부를 수 있어야 한다.
        guard MoyeoServerSync.allowsPublicEndpoints else { return }
        isLoading = true
        loadFailed = false
        defer { isLoading = false }
        do {
            let options = try await client.profileOptions()
            travelStyles = options.travelStyles.map { TravelTasteOption(id: $0.id, label: $0.label) }
            // 관심 지역의 라벨 키는 `signguName` 이다 (실응답 기준).
            interestedRegions = options.interestedRegions.map {
                TravelTasteOption(id: $0.id, label: $0.signguName)
            }
        } catch {
            travelStyles = []
            interestedRegions = []
            loadFailed = true
        }
    }
}
