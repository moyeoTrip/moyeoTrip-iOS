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
    case server(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingSession:
            return "로그인 정보가 없어요. 다시 로그인해주세요."
        case .transport:
            return "서버에 연결하지 못했어요. 네트워크 상태를 확인해주세요."
        case .invalidResponse:
            return "서버 응답을 이해하지 못했어요. 잠시 후 다시 시도해주세요."
        case .server(_, let message):
            return message
        }
    }
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

    // MARK: - 내부

    private func decode<Response: Decodable>(_ data: Data) throws -> Response {
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw MoyeoAPIError.invalidResponse
        }
    }

    /// 401이면 refresh 토큰으로 세션을 재발급한 뒤 한 번 더 시도한다 (AuthProviderLinkService 선례).
    private func request(
        path: String,
        method: String,
        query: [URLQueryItem],
        bodyData: Data?
    ) async throws -> Data {
        guard let loaded = (try? sessionStore.load()) ?? nil else {
            throw MoyeoAPIError.missingSession
        }

        do {
            return try await perform(
                path: path, method: method, query: query,
                bodyData: bodyData, accessToken: loaded.accessToken
            )
        } catch MoyeoAPIError.server(let statusCode, _) where statusCode == 401 {
            let refreshed: AuthSignupResponse
            do {
                refreshed = try await authClient.refreshSession(refreshToken: loaded.refreshToken)
            } catch {
                throw MoyeoAPIError.missingSession
            }
            try? sessionStore.save(refreshed.tokens)
            return try await perform(
                path: path, method: method, query: query,
                bodyData: bodyData, accessToken: refreshed.tokens.accessToken
            )
        }
    }

    private func perform(
        path: String,
        method: String,
        query: [URLQueryItem],
        bodyData: Data?,
        accessToken: String
    ) async throws -> Data {
        var url = configuration.baseURL.appending(path: path)
        if !query.isEmpty {
            url.append(queryItems: query)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = bodyData
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if bodyData != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
                message: backendError?.errorMessage ?? "요청을 완료하지 못했어요. 잠시 후 다시 시도해주세요."
            )
        }
        return data
    }
}
