//
//  MoyeoAPIClient.swift
//  MoyeoTrip
//
//  실서버 연동 공통 클라이언트 — AuthAPIClient(인증)·TourismAPIClient(보호 API) 선례를 따른다.
//  화면들은 저장된 세션이 있을 때만 이 클라이언트를 타고, 실패하면 기존 목데이터를 유지한다.
//

import Foundation

/// 실서버 연동 게이트.
///
/// UITEST 캡처 라우트는 기본적으로 네트워크를 타지 않는다 — 목데이터 화면이 4열 대조의 기준이다.
/// **예외는 라이브 캡처(`UITEST_LIVE_DATA`)뿐이다.** 그때는 캡처 라우팅·강제 테마는 그대로 두고
/// 데이터 차단만 푼다. 안드로이드의 `moyeo_live_data` 와 같은 취급이다.
enum MoyeoServerSync {
    static var isEnabled: Bool {
        guard allowsNetwork else { return false }
        return ((try? KeychainAuthSessionStore().load()) ?? nil) != nil
    }

    /// 세션이 없어도 부를 수 있는 **공개 엔드포인트**용 게이트.
    ///
    /// 약관(`/api/v1/terms/**`)은 서버가 공개로 열어뒀고, 가입 중에는 아직 서비스 토큰이 없다.
    /// 세션을 요구하면 약관 화면이 비어 가입 자체가 막힌다.
    static var allowsPublicEndpoints: Bool { allowsNetwork }

    private static var allowsNetwork: Bool {
        !UITestRuntime.isEnabled || UITestRuntime.usesLiveData
    }
}

/// 서버가 오류 본문을 주지 않았을 때 상태 코드로 고르는 문구.
///
/// **429 와 403 은 사용자가 해야 할 일이 정반대다** — 429 는 기다리면 되고,
/// 403 은 다시 눌러도 달라지지 않는다. 예전에는 둘 다
/// 「요청을 완료하지 못했어요. 잠시 후 다시 시도해주세요.」 하나였다:
/// 403 을 받은 사람에게 **소용없는 재시도를 권하고 있었다** (웹 교차 발견 2026-09-14).
///
/// **서버가 한국어 까닭을 주면 그것이 우선이다** — 여기 문구로 덮지 않는다.
/// 503·404 등 나머지는 전부 가르지 않고 지금 문구 그대로 둔다.
enum MoyeoAPIStatusMessage {
    static let forbidden = "이 작업을 할 권한이 없어요. 다시 시도해도 달라지지 않아요."
    static let tooManyRequests = "요청이 너무 잦아요. 잠시 뒤 다시 시도해 주세요."
    static let generic = "요청을 완료하지 못했어요. 잠시 후 다시 시도해주세요."

    static func fallback(for statusCode: Int) -> String {
        switch statusCode {
        case 403: return forbidden
        case 429: return tooManyRequests
        default: return generic
        }
    }

    /// 서버가 준 까닭이 아니라 **앱이 붙인 기본 문구**인가.
    ///
    /// 화면이 자기 맥락에 맞는 더 좋은 문구를 갖고 있을 때(예: 「이 채팅방을 더 이상 볼 수 없어요.」)
    /// 일반 문구를 덮어쓸지 판단하는 데 쓴다.
    static func isGenerated(_ message: String) -> Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return [forbidden, tooManyRequests, generic].contains(trimmed)
    }
}

enum MoyeoAPIError: LocalizedError, Equatable {
    case missingSession
    case transport(String)
    case invalidResponse
    /// `code` 는 서버 오류 본문의 업무 코드(예: 40301 미참가 · 40405 방 없음 · 40915 아직 완료되지 않은 여행).
    /// 상태 코드만으로는 같은 409·403 안에서 서로 다른 안내를 가려낼 수 없다.
    case server(statusCode: Int, code: Int?, message: String)

    var errorDescription: String? {
        switch self {
        case .missingSession:
            return "로그인 정보가 없어요. 다시 로그인해주세요."
        case .transport:
            // 통신 실패 문구는 앱에 **하나**다 — 웹·안드와 같은 문장을 쓴다
            // (`MoyeoUserFacingError.network`). 예전에는 이 자리와 `AuthClientError` 가
            // 「서버에 연결하지 못했어요…」를, 화면 공통 경로가 다른 문장을 써서
            // 같은 상황에 두 가지 말이 나왔다.
            return MoyeoUserFacingError.network
        case .invalidResponse:
            return "서버 응답을 이해하지 못했어요. 잠시 후 다시 시도해주세요."
        case .server(_, _, let message):
            return message
        }
    }

    /// 서버가 준 업무 코드. 오류 본문이 없으면 nil 이다.
    var serverCode: Int? {
        guard case .server(_, let code, _) = self else { return nil }
        return code
    }

    /// 가입이 아직 끝나지 않아 막힌 것이면 되돌아갈 단계 (정본 R1).
    /// 화면은 이 오류를 "요청 실패"로 그리지 않는다 — 루트가 이미 가입 흐름으로 옮긴다.
    var signupGateStep: MoyeoSignupGate.Step? {
        guard case .server(let statusCode, let code, _) = self else { return nil }
        return MoyeoSignupGate.step(statusCode: statusCode, code: code)
    }
}

/// 서버가 쓰는 업무 오류 코드 중 화면 분기가 필요한 것들 (2026-08-25 BE 계약 정리).
enum MoyeoServerErrorCode {
    /// 해당 채팅방에 참여 중이 아님 (403)
    nonisolated static let notParticipating = 40301
    /// 채팅방이 없음 (404)
    nonisolated static let chatRoomNotFound = 40405
    /// 완료 여행 전용 API 를 아직 끝나지 않은 여행에 부른 경우 (409).
    /// 권한 오류가 아니다 — 화면은 오류로 그리지 말고 해당 섹션을 숨긴다.
    nonisolated static let tripNotCompleted = 40915
    /// 같은 피드를 이미 신고했다 (409). **오류가 아니다** — 30-2 는 붉은 오류가 아니라
    /// "이미 신고한 피드예요." 안내로 그린다 (정본 `REPORT-CANON.md` §2, 실서버 확인).
    nonisolated static let feedAlreadyReported = 40917

    // MARK: 신고 오류 (2026-09-14 실서버 `ErrorCode.kt` 확인)
    //
    // 대상마다 코드가 다르다 — 상태 코드만 보면 "본인 것"과 "없는 것"을 구분하지 못해
    // 전부 같은 붉은 토스트가 됐다. 화면은 아래 코드로 갈라 각각 다른 한국어를 적는다.

    /// 본인이 쓴 피드는 신고할 수 없음 (400).
    ///
    /// 30-2 는 보통 자기 피드에 `...` 를 두지 않아 닿지 않지만, 서버가 작성자 id 를 주지 않는
    /// 경로(`serverAuthorID == nil`)에서는 버튼이 남아 실제로 닿는다 — 문구를 정본에 맞춰 둔다.
    nonisolated static let feedReportSelf = 40039
    /// 본인이 개설한 모집은 신고할 수 없음 (400)
    nonisolated static let roomReportSelf = 40044
    /// 자기 자신은 신고할 수 없음 (400)
    nonisolated static let memberReportSelf = 40045
    /// 본인이 작성한 댓글은 신고할 수 없음 (400)
    nonisolated static let commentReportSelf = 40046
    /// 이미 신고한 모집 (409). 오류가 아니라 안내다.
    nonisolated static let roomAlreadyReported = 40920
    /// 이미 신고한 사용자 (409). 오류가 아니라 안내다.
    nonisolated static let memberAlreadyReported = 40921
    /// 이미 신고한 댓글 (409). 오류가 아니라 안내다.
    nonisolated static let commentAlreadyReported = 40922

    // MARK: 동시 변경 · 확정 조건 (BE-30 · BE-31)

    /// 내가 읽은 뒤 남이 먼저 공지를 고쳤다 (409). **오류가 아니라 다시 보라는 안내다** —
    /// 화면은 최신 내용을 입력칸에 올려 두고 덮어쓰기를 시도하지 않는다 (TC NOTICE-021).
    nonisolated static let noticeUpdateConflict = 40923
    /// 참가자 수가 `minimumParticipants` 에 못 미쳐 확정할 수 없다 (409).
    /// 화면은 CTA 를 미리 잠그지만, 잠금 이후 누가 나가면 여기로 온다 (TC HOST-012·013).
    nonisolated static let minimumParticipantsNotMet = 40924
    /// 피드 댓글을 찾을 수 없음 (404)
    nonisolated static let feedCommentNotFound = 40422
    /// 이 피드는 현재 사용자에게 공개되지 않음 (403)
    nonisolated static let feedNotVisible = 40306
    // 가입 게이트 코드(40902 · 40918 · 40919)는 `MoyeoSignupGate` 에 모아 뒀다.
}

/// `multipart/form-data` 파일 파트 하나. 사진 공유(20-2)·모집 썸네일이 쓴다.
struct MoyeoMultipartFile {
    let partName: String
    let fileName: String
    let mimeType: String
    let data: Data
}

/// Bearer 토큰 + 401 자동 재발급을 처리하는 공통 요청기.
/// 도메인별 APIClient(ChatRoom·TravelCourse·Terms·Notification·UserProfile·Social·Feed)가 이 위에 얹힌다.
final class MoyeoAPIClient: @unchecked Sendable {
    static let shared = MoyeoAPIClient()

    private let configuration: AuthAPIConfiguration
    private let session: URLSession
    private let sessionStore: AuthSessionStoring
    private let authClient: AuthAPIClient
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        configuration: AuthAPIConfiguration = .current,
        session: URLSession = .shared,
        sessionStore: AuthSessionStoring = KeychainAuthSessionStore()
    ) {
        self.configuration = configuration
        self.session = session
        self.sessionStore = sessionStore
        authClient = AuthAPIClient(configuration: configuration, session: session)
    }

    // MARK: - 공개 API

    func get<Response: Decodable>(
        _ path: String,
        query: [URLQueryItem] = []
    ) async throws -> Response {
        let data = try await request(path: path, method: "GET", query: query, bodyData: nil)
        return try decode(data)
    }

    /// **인증 없이** 호출하는 GET.
    ///
    /// 약관(`/api/v1/terms/**`)처럼 서버가 공개로 열어둔 엔드포인트에 쓴다.
    /// 가입 중에는 아직 서비스 토큰이 없다 — 세션을 요구하면 약관 화면이
    /// "로그인 정보가 없어요"로 막혀 가입 자체가 불가능해진다.
    func getPublic<Response: Decodable>(
        _ path: String,
        query: [URLQueryItem] = []
    ) async throws -> Response {
        let call = Call(path: path, method: "GET", query: query, bodyData: nil, contentType: "application/json")
        let data = try await perform(call, accessToken: nil)
        return try decode(data)
    }

    func send<Body: Encodable, Response: Decodable>(
        _ path: String,
        method: String,
        body: Body
    ) async throws -> Response {
        let bodyData = try encoder.encode(body)
        let data = try await request(path: path, method: method, query: [], bodyData: bodyData)
        return try decode(data)
    }

    func send<Response: Decodable>(
        _ path: String,
        method: String
    ) async throws -> Response {
        let data = try await request(path: path, method: method, query: [], bodyData: nil)
        return try decode(data)
    }

    func sendVoid(_ path: String, method: String) async throws {
        _ = try await request(path: path, method: method, query: [], bodyData: nil)
    }

    func sendVoid<Body: Encodable>(_ path: String, method: String, body: Body) async throws {
        let bodyData = try encoder.encode(body)
        _ = try await request(path: path, method: method, query: [], bodyData: bodyData)
    }

    /// 본문을 돌려주지 않는 `multipart/form-data` 전송.
    ///
    /// `PATCH /chat-rooms/{roomId}` 는 **204 No Content** 다. 빈 본문을 굳이 디코딩하면
    /// 저장은 됐는데 화면에는 「서버 응답을 이해하지 못했어요」가 뜬다 — 그러면 사용자가
    /// 다시 눌러 시스템 메시지가 겹쳐 쌓인다 (IOS-F112, 2026-09-12).
    func sendMultipartVoid<Body: Encodable>(
        _ path: String,
        method: String,
        jsonPartName: String,
        jsonPart: Body,
        file: MoyeoMultipartFile? = nil
    ) async throws {
        let (body, contentType) = try multipartBody(jsonPartName: jsonPartName, jsonPart: jsonPart, file: file)
        _ = try await request(path: path, method: method, query: [], bodyData: body, contentType: contentType)
    }

    /// JSON 파트 + 선택 파일 하나짜리 본문을 만든다. 보내고 받는 쪽과 만드는 쪽을 나눠
    /// 응답을 읽는 판(`sendMultipart`)과 읽지 않는 판(`sendMultipartVoid`)이 같은 본문을 쓰게 한다.
    private func multipartBody<Body: Encodable>(
        jsonPartName: String,
        jsonPart: Body,
        file: MoyeoMultipartFile?
    ) throws -> (Data, String) {
        let boundary = "moyeo.\(UUID().uuidString)"
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(jsonPartName)\"\r\n".utf8))
        body.append(Data("Content-Type: application/json\r\n\r\n".utf8))
        body.append(try encoder.encode(jsonPart))
        if let file {
            body.append(Data("\r\n--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(file.partName)\"; filename=\"\(file.fileName)\"\r\n".utf8))
            body.append(Data("Content-Type: \(file.mimeType)\r\n\r\n".utf8))
            body.append(file.data)
        }
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return (body, "multipart/form-data; boundary=\(boundary)")
    }

    /// `multipart/form-data` 전송. JSON 파트는 `Content-Type: application/json` 을 달아 보낸다.
    /// `POST /chat-rooms` 가 `request` 파트를 그렇게 요구하고, 2026-08-26 부터 `thumbnail`
    /// 파일 파트도 **필수**다(없으면 400 `40041`). 그래서 `file` 은 선택 인자가 아니라 사실상 항상 넣는다.
    func sendMultipart<Body: Encodable, Response: Decodable>(
        _ path: String,
        method: String,
        jsonPartName: String,
        jsonPart: Body,
        file: MoyeoMultipartFile? = nil
    ) async throws -> Response {
        let (body, contentType) = try multipartBody(jsonPartName: jsonPartName, jsonPart: jsonPart, file: file)
        let data = try await request(
            path: path,
            method: method,
            query: [],
            bodyData: body,
            contentType: contentType
        )
        return try decode(data)
    }

    /// JSON 파트 하나 + **파일 여러 개**를 `multipart/form-data` 로 보낸다.
    /// `POST /feeds` 가 `request`(JSON) 와 `images`(1~10장)를 요구한다.
    func sendMultipart<Body: Encodable, Response: Decodable>(
        _ path: String,
        method: String,
        jsonPartName: String,
        jsonPart: Body,
        files: [MoyeoMultipartFile]
    ) async throws -> Response {
        let boundary = "moyeo.\(UUID().uuidString)"
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(jsonPartName)\"\r\n".utf8))
        body.append(Data("Content-Type: application/json\r\n\r\n".utf8))
        body.append(try encoder.encode(jsonPart))
        body.append(Data("\r\n".utf8))
        for file in files {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data(
                "Content-Disposition: form-data; name=\"\(file.partName)\"; filename=\"\(file.fileName)\"\r\n".utf8
            ))
            body.append(Data("Content-Type: \(file.mimeType)\r\n\r\n".utf8))
            body.append(file.data)
            body.append(Data("\r\n".utf8))
        }
        body.append(Data("--\(boundary)--\r\n".utf8))

        let data = try await request(
            path: path,
            method: method,
            query: [],
            bodyData: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
        return try decode(data)
    }

    /// 파일 한 개(+선택 텍스트 파트)를 `multipart/form-data` 로 보낸다.
    /// `POST /chat-rooms/{id}/messages/images` 가 `image` 파일 파트와 선택 `caption` 텍스트 파트를 요구한다.
    func sendMultipart<Response: Decodable>(
        _ path: String,
        method: String,
        file: MoyeoMultipartFile,
        textParts: [String: String] = [:]
    ) async throws -> Response {
        let boundary = "moyeo.\(UUID().uuidString)"
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data(
            "Content-Disposition: form-data; name=\"\(file.partName)\"; filename=\"\(file.fileName)\"\r\n".utf8
        ))
        body.append(Data("Content-Type: \(file.mimeType)\r\n\r\n".utf8))
        body.append(file.data)
        body.append(Data("\r\n".utf8))
        // 텍스트 파트는 서버가 문자열로 받는다 — 순서를 고정해 재현 가능한 본문을 만든다.
        for name in textParts.keys.sorted() {
            guard let value = textParts[name] else { continue }
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n".utf8))
            body.append(Data("Content-Type: text/plain; charset=utf-8\r\n\r\n".utf8))
            body.append(Data(value.utf8))
            body.append(Data("\r\n".utf8))
        }
        body.append(Data("--\(boundary)--\r\n".utf8))

        let data = try await request(
            path: path,
            method: method,
            query: [],
            bodyData: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
        return try decode(data)
    }

    // MARK: - 내부

    private func decode<Response: Decodable>(_ data: Data) throws -> Response {
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw MoyeoAPIError.invalidResponse
        }
    }

    /// 요청 한 건의 구성. `perform` 인자 수를 늘리지 않기 위해 한 값으로 묶는다.
    private struct Call {
        let path: String
        let method: String
        var query: [URLQueryItem] = []
        var bodyData: Data?
        var contentType = "application/json"
    }

    /// 401이면 refresh 토큰으로 세션을 재발급한 뒤 한 번 더 시도한다 (AuthProviderLinkService 선례).
    ///
    /// 재발급은 **401 에서만** 한다(정본 R1). 가입 게이트(409 `40902`·`40918`)는 토큰 문제가 아니라
    /// 가입 단계 문제라 재발급해도 서버는 같은 409 를 준다 — 여기로 새면 무한 재시도가 된다.
    /// 그 두 코드는 `perform` 이 루트에 알리고 그대로 호출자에게 던진다.
    private func request(
        path: String,
        method: String,
        query: [URLQueryItem],
        bodyData: Data?,
        contentType: String = "application/json"
    ) async throws -> Data {
        guard let loaded = (try? sessionStore.load()) ?? nil else {
            throw MoyeoAPIError.missingSession
        }

        let call = Call(
            path: path, method: method, query: query,
            bodyData: bodyData, contentType: contentType
        )
        do {
            return try await perform(call, accessToken: loaded.accessToken)
        } catch MoyeoAPIError.server(let statusCode, let code, let message) where statusCode == 401 {
            // 갱신 토큰이 없는 세션(캡처 세션)은 갱신할 수 없다 — 401 을 그대로 올린다.
            // 빈 refreshToken 으로 `/auth/refresh` 를 부르면 400 이 돌아와 원인이 가려진다.
            guard !loaded.refreshToken.isEmpty else {
                throw MoyeoAPIError.server(statusCode: statusCode, code: code, message: message)
            }
            // 재발급은 **동시에 한 번만** 나간다 (AUTH-032). 이미 진행 중이면 그 결과를 기다렸다가
            // 새 토큰으로 재시도한다. 실패했을 때의 처리(`missingSession` → 로그아웃)는 그대로다.
            let refreshedTokens: AuthTokens
            do {
                refreshedTokens = try await MoyeoTokenRefreshCoordinator.shared.tokens(
                    replacing: loaded.accessToken,
                    current: { [sessionStore] in (try? sessionStore.load()) ?? nil },
                    refresh: { [authClient, sessionStore] refreshToken in
                        let refreshed = try await authClient.refreshSession(refreshToken: refreshToken)
                        try? sessionStore.save(refreshed.tokens)
                        return refreshed.tokens
                    }
                )
            } catch {
                throw MoyeoAPIError.missingSession
            }
            return try await perform(call, accessToken: refreshedTokens.accessToken)
        }
    }

    /// `accessToken` 이 `nil` 이면 Authorization 헤더를 붙이지 않는다(공개 엔드포인트).
    private func perform(_ call: Call, accessToken: String?) async throws -> Data {
        var url = configuration.baseURL.appending(path: call.path)
        if !call.query.isEmpty {
            url.append(queryItems: call.query)
        }

        var request = URLRequest(url: url)
        request.httpMethod = call.method
        request.httpBody = call.bodyData
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if call.bodyData != nil {
            request.setValue(call.contentType, forHTTPHeaderField: "Content-Type")
        }
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw MoyeoAPIError.transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MoyeoAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let backendError = try? decoder.decode(AuthBackendErrorResponse.self, from: data)
            // 가입 미완료로 막힌 것이면 재시도 대신 해당 가입 단계로 되돌린다 (정본 R1).
            if let step = MoyeoSignupGate.step(statusCode: httpResponse.statusCode, code: backendError?.code) {
                MoyeoSignupGate.announce(step)
            }
            // 서버 점검(503 · 50300)이면 섹션별 실패로 접지 않고 38 점검 안내 화면으로 옮긴다 (OFF-013).
            // 웹과 같은 규칙이다 — 게이트웨이가 가로챈 503 은 본문이 없어 status 를 먼저 본다.
            if MoyeoServerMaintenance.isMaintenance(
                statusCode: httpResponse.statusCode,
                code: backendError?.code
            ) {
                MoyeoServerMaintenance.announce()
            }
            // 서버가 준 한국어 까닭이 **언제나 우선**이다. 본문이 없을 때만 상태 코드로 고른다 —
            // 이 자리가 상태 코드와 무관하게 한국어 기본 문구를 붙이고 있었고,
            // 그 문구가 한국어라서 `MoyeoUserFacingError` 의 「서버 문구는 그대로 쓴다」 분기를
            // 그대로 통과했다. **화면 쪽만 고쳤다면 예전 문구가 그대로 나왔을 자리다.**
            let serverReason = backendError?.errorMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            throw MoyeoAPIError.server(
                statusCode: httpResponse.statusCode,
                code: backendError?.code,
                message: serverReason?.isEmpty == false
                    ? serverReason!
                    : MoyeoAPIStatusMessage.fallback(for: httpResponse.statusCode)
            )
        }
        return data
    }
}
