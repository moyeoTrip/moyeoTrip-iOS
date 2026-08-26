//
//  MoyeoAPIClient.swift
//  MoyeoTrip
//
//  실서버 연동 공통 클라이언트 — AuthAPIClient(인증)·TourismAPIClient(보호 API) 선례를 따른다.
//  화면들은 저장된 세션이 있을 때만 이 클라이언트를 타고, 실패하면 기존 목데이터를 유지한다.
//

import Foundation

/// 실서버 연동 게이트.
/// UITEST 캡처 라우트는 절대 네트워크를 타지 않는다 — 목데이터 화면이 그대로 기준이다.
enum MoyeoServerSync {
    static var isEnabled: Bool {
        guard !UITestRuntime.isEnabled else { return false }
        return ((try? KeychainAuthSessionStore().load()) ?? nil) != nil
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
            return "서버에 연결하지 못했어요. 네트워크 상태를 확인해주세요."
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

    /// `multipart/form-data` 전송. JSON 파트는 `Content-Type: application/json` 을 달아 보낸다.
    /// `POST /chat-rooms` 가 `request` 파트를 그렇게 요구한다.
    func sendMultipart<Body: Encodable, Response: Decodable>(
        _ path: String,
        method: String,
        jsonPartName: String,
        jsonPart: Body
    ) async throws -> Response {
        let boundary = "moyeo.\(UUID().uuidString)"
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(jsonPartName)\"\r\n".utf8))
        body.append(Data("Content-Type: application/json\r\n\r\n".utf8))
        body.append(try encoder.encode(jsonPart))
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

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
        } catch MoyeoAPIError.server(let statusCode, _, _) where statusCode == 401 {
            let refreshed: AuthSignupResponse
            do {
                refreshed = try await authClient.refreshSession(refreshToken: loaded.refreshToken)
            } catch {
                throw MoyeoAPIError.missingSession
            }
            try? sessionStore.save(refreshed.tokens)
            return try await perform(call, accessToken: refreshed.tokens.accessToken)
        }
    }

    private func perform(_ call: Call, accessToken: String) async throws -> Data {
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
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

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
            throw MoyeoAPIError.server(
                statusCode: httpResponse.statusCode,
                code: backendError?.code,
                message: backendError?.errorMessage ?? "요청을 완료하지 못했어요. 잠시 후 다시 시도해주세요."
            )
        }
        return data
    }
}
