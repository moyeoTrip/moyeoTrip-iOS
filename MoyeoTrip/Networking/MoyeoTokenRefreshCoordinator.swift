//
//  MoyeoTokenRefreshCoordinator.swift
//  MoyeoTrip
//
//  401 재발급 single-flight (QA AUTH-032).
//

import Foundation

/// 401 재발급을 **동시에 여러 번 하지 않게** 직렬화한다 (QA AUTH-032).
///
/// 홈처럼 여러 요청이 한꺼번에 나가는 화면에서는 두 요청이 거의 같은 순간에 401 을 받는다.
/// 각자 `/auth/refresh` 를 부르면 **리프레시 토큰이 이미 회전해** 뒤늦은 쪽이 400 을 받고,
/// 그 섹션만 복구에 실패한다. 갱신이 진행 중이면 새로 시작하지 않고 **그 결과를 기다린다.**
///
/// 메인 액터에 묶어 둔다 — 요청 경로(`MoyeoAPIClient`)가 이미 메인 액터라
/// 「진행 중인지 보고 없으면 시작한다」 사이에 `await` 가 없어 그 자체로 원자적이다.
/// 기다리는 동안은 네트워크 대기라 화면이 멈추지 않는다(기존 요청 경로와 같다).
@MainActor
final class MoyeoTokenRefreshCoordinator {
    /// 갱신 조정자는 **앱에 하나**다 — 세션이 하나뿐이라, 갈래가 나뉘면(일반 API · 프로필 · 제공자 연결)
    /// 각자 갱신을 걸어 다시 경쟁이 생긴다. 실제로 홈 401 과 프로필 401 이 그렇게 부딪혔다.
    static let shared = MoyeoTokenRefreshCoordinator()

    private var inFlight: Task<AuthTokens, Error>?

    /// - Parameters:
    ///   - staleAccessToken: 401 을 받은 요청이 쓰던 액세스 토큰.
    ///   - current: 지금 보관된 세션(키체인).
    ///   - refresh: 실제 재발급 + 보관. **진행 중인 갱신이 없을 때만** 불린다.
    func tokens(
        replacing staleAccessToken: String,
        current: () -> AuthTokens?,
        refresh: @escaping (String) async throws -> AuthTokens
    ) async throws -> AuthTokens {
        // 진행 중인 갱신이 있으면 **새로 시작하지 않고** 그 결과를 쓴다.
        if let inFlight {
            return try await inFlight.value
        }
        // 이미 다른 요청이 갱신을 끝낸 뒤 늦게 401 이 도착한 경우다 —
        // 회전된 리프레시 토큰으로 또 부르면 400 이라, 보관된 새 토큰으로 바로 재시도한다.
        if let stored = current(), stored.accessToken != staleAccessToken {
            return stored
        }
        guard let refreshToken = current()?.refreshToken, !refreshToken.isEmpty else {
            throw MoyeoAPIError.missingSession
        }
        let task = Task { try await refresh(refreshToken) }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }
}
