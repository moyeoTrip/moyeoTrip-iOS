//
//  MoyeoServerMaintenance.swift
//  MoyeoTrip
//
//  서버 점검(503 · 50300) 안내 (QA OFF-013). 웹 `auth-api.jsx isMaintenanceResponse` 와 같은 규칙이다.
//

import Foundation

extension Notification.Name {
    /// 서버가 점검 중이라고 답했다 — 루트(ContentView)가 38 점검 안내 화면으로 **교체**한다.
    static let moyeoServerMaintenance = Notification.Name("moyeo.serverMaintenance")
}

/// 점검은 "요청 하나가 실패했다"가 아니라 **서비스 전체가 지금 닫혀 있다**는 뜻이다.
///
/// 예전에는 목록마다 「불러오지 못했어요 / 다시 시도」로 접혀, 만들어 둔 38 점검 안내 화면
/// (`SupportRoute.systemMaintenance`)이 **QA 직접 실행 말고는 어떤 경로에서도 열리지 않았다**
/// (QA OFF-013 — 웹도 같은 결함이었고 같은 규칙으로 풀었다).
///
/// **status 를 먼저 보고 code 는 보조로 본다** — 게이트웨이(Cloudflare)가 가로챈 503 은
/// JSON 본문이 없어 `code` 가 비어 있다.
enum MoyeoServerMaintenance {
    /// 서버가 본문을 줄 때의 점검 업무 코드. 웹 `shared.jsx MOYEO_MAINTENANCE_CODE` 와 같은 값이다.
    nonisolated static let maintenanceCode = 50300

    nonisolated static func isMaintenance(statusCode: Int, code: Int?) -> Bool {
        statusCode == 503 || code == maintenanceCode
    }

    /// 점검 화면으로 옮기라고 루트에 알린다.
    ///
    /// 가입 게이트(`MoyeoSignupGate.announce`)와 같은 관례다 — 네트워킹 계층은 화면 스택을
    /// 직접 만질 수 없어 한 곳에서 알리고 한 곳(루트)에서 받는다.
    static func announce() {
        NotificationCenter.default.post(name: .moyeoServerMaintenance, object: nil)
    }
}
