//
//  AuthNicknameModel.swift
//  MoyeoTrip
//

import Combine
import Foundation
import SwiftUI

struct AuthNicknameCandidate: Equatable, Identifiable {
    let id: String
    let nickname: String
    let adjective: String
    let animal: String
    let color: String
    let description: String

    init(
        id: String,
        nickname: String,
        adjective: String? = nil,
        animal: String? = nil,
        color: String = "MINT",
        description: String = "함께 천천히 경북을 둘러보는 여행자예요"
    ) {
        self.id = id
        self.nickname = nickname
        self.adjective = adjective ?? nickname.split(separator: " ").first.map(String.init) ?? ""
        self.animal = animal ?? nickname.split(separator: " ").dropLast().last.map(String.init) ?? ""
        self.color = color
        self.description = description
    }

    var displayName: String {
        nickname.split(separator: " ").dropLast().joined(separator: " ")
    }

    var number: String {
        nickname.split(separator: " ").last.map(String.init) ?? ""
    }

    var animalEmoji: String {
        Self.animalEmojis[animal] ?? "🐾"
    }

    var colorLabel: String {
        Self.colorLabels[color] ?? color
    }

    private static let animalEmojis = [
        "사슴": "🦌", "거북이": "🐢", "토끼": "🐰", "여우": "🦊", "수달": "🦦",
        "다람쥐": "🐿️", "고양이": "🐱", "강아지": "🐶", "판다": "🐼", "펭귄": "🐧",
        "돌고래": "🐬", "부엉이": "🦉", "참새": "🐦", "알파카": "🦙", "코알라": "🐨",
        "두루미": "🪽", "해달": "🦦", "고슴도치": "🦔", "너구리": "🦝", "기린": "🦒"
    ]

    private static let colorLabels = [
        "RED": "빨강", "ORANGE": "주황", "YELLOW": "노랑", "GREEN": "초록", "BLUE": "파랑",
        "NAVY": "남색", "PURPLE": "보라", "PINK": "분홍", "SKY_BLUE": "하늘", "MINT": "민트"
    ]
}

struct AuthNicknameCandidatesResponse: Equatable {
    let selectionToken: String
    let candidates: [AuthNicknameCandidate]
}

protocol AuthNicknameCandidateProviding {
    // Mirrors POST /api/v1/auth/nickname-candidates, including each candidate's description.
    func fetchCandidates() async throws -> AuthNicknameCandidatesResponse
}

final class MockAuthNicknameCandidateProvider: AuthNicknameCandidateProviding {
    private let batches: [[String]]
    private let delayNanoseconds: UInt64
    private let shouldFail: Bool
    private var nextBatchIndex = 0

    init(
        batches: [[String]]? = nil,
        delayNanoseconds: UInt64? = nil,
        shouldFail: Bool? = nil
    ) {
        self.batches = batches ?? Self.defaultBatches
        let arguments = ProcessInfo.processInfo.arguments
        self.delayNanoseconds = delayNanoseconds ?? (arguments.contains("UITEST_MODE") ? 1_500_000_000 : 550_000_000)
        self.shouldFail = shouldFail ?? arguments.contains("UITEST_NICKNAME_REFRESH_FAIL")
    }

    func fetchCandidates() async throws -> AuthNicknameCandidatesResponse {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        if shouldFail {
            throw AuthNicknameCandidateError.unavailable
        }

        let batchIndex = min(nextBatchIndex, batches.count - 1)
        let nicknames = batches[batchIndex]
        nextBatchIndex += 1

        return AuthNicknameCandidatesResponse(
            selectionToken: "mock-selection-\(batchIndex + 2)",
            candidates: nicknames.enumerated().map { index, nickname in
                AuthNicknameCandidate(
                    id: "batch-\(batchIndex + 2)-\(index)",
                    nickname: nickname,
                    color: Self.mockColors[(batchIndex * 3 + index) % Self.mockColors.count]
                )
            }
        )
    }

    static let defaultBatches = [
        ["포근한 두루미 4186", "느긋한 수달 7351", "용감한 토끼 2640"],
        ["다정한 여우 5814", "반짝이는 고라니 3072", "차분한 부엉이 9465"],
        ["싱그러운 곰 6248", "활기찬 다람쥐 1537", "고요한 학 8094"],
        ["따뜻한 삵 2719", "명랑한 오소리 6843", "든든한 산양 5026"]
    ]

    private static let mockColors = ["RED", "ORANGE", "YELLOW", "GREEN", "BLUE", "NAVY", "PURPLE", "PINK", "SKY_BLUE", "MINT"]
}

@MainActor
final class AuthNicknameViewModel: ObservableObject {
    @Published private(set) var candidates: [AuthNicknameCandidate]
    @Published private(set) var selectionToken: String
    @Published private(set) var refreshCount = 0
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var selectedNickname: String

    private let provider: AuthNicknameCandidateProviding

    init(
        provider: AuthNicknameCandidateProviding,
        initialResponse: AuthNicknameCandidatesResponse? = nil,
        selectedNickname: String = ""
    ) {
        self.provider = provider
        let response = initialResponse ?? AuthNicknameViewModel.initialResponse
        candidates = response.candidates
        selectionToken = response.selectionToken
        self.selectedNickname = selectedNickname
    }

    convenience init(selectedNickname: String = "") {
        self.init(
            provider: MockAuthNicknameCandidateProvider(),
            selectedNickname: selectedNickname
        )
    }

    var canRefresh: Bool {
        !isLoading
    }

    func selectNickname(_ nickname: String) {
        guard !isLoading else { return }
        selectedNickname = nickname
    }

    @discardableResult
    func refreshCandidates() async -> Bool {
        guard canRefresh else { return false }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await provider.fetchCandidates()
            guard response.candidates.count == 3 else {
                throw AuthNicknameCandidateError.invalidCandidateCount
            }
            candidates = response.candidates
            selectionToken = response.selectionToken
            selectedNickname = ""
            refreshCount += 1
            return true
        } catch {
            errorMessage = "새 이름을 불러오지 못했어요. 다시 시도해주세요."
            return false
        }
    }

    static let initialResponse = AuthNicknameCandidatesResponse(
        selectionToken: "mock-selection-1",
        candidates: [
            AuthNicknameCandidate(id: "deer", nickname: "따스한 사슴 3492", color: "RED"),
            AuthNicknameCandidate(id: "turtle", nickname: "잔잔한 거북이 1108", color: "BLUE"),
            AuthNicknameCandidate(id: "raccoon", nickname: "호기심 많은 너구리 9027", color: "MINT")
        ]
    )
}

enum AuthNicknameCandidateError: Error {
    case invalidCandidateCount
    case unavailable
}

extension AuthNicknameCandidate {
    var swatchColor: Color {
        switch color {
        case "RED": Color(hex: "#E65B58")
        case "ORANGE": Color(hex: "#ED8A3D")
        case "YELLOW": Color(hex: "#D6A928")
        case "GREEN": Color(hex: "#3D9B63")
        case "BLUE": Color(hex: "#4B7EDB")
        case "NAVY": Color(hex: "#40547A")
        case "PURPLE": Color(hex: "#8A63B8")
        case "PINK": Color(hex: "#D96F98")
        case "SKY_BLUE": Color(hex: "#58A9D6")
        default: Color(hex: "#55B99A")
        }
    }
}
