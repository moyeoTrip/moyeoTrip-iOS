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
        MoyeoNicknameAnimal.emoji(forAnimal: animal)
    }

    var colorLabel: String {
        Self.colorLabels[color] ?? color
    }

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

/// 서버 후보를 아직 못 받은 상태. 지어낸 후보를 끼워 넣으면 사용자가 고를 수 없는 이름이 뜬다.
struct AuthNicknameUnavailableProvider: AuthNicknameCandidateProviding {
    func fetchCandidates() async throws -> AuthNicknameCandidatesResponse {
        throw AuthNicknameCandidateError.unavailable
    }
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
            provider: AuthNicknameUnavailableProvider(),
            selectedNickname: selectedNickname
        )
    }

    var canRefresh: Bool {
        !isLoading
    }

    /// 새 가입 흐름이 시작될 때 서버가 준 첫 후보 묶음을 받아 적는다.
    ///
    /// 화면(`AuthNicknameView`)이 이 객체를 다시 만들지 않고 계속 쓰기 때문에
    /// 「다음 → 뒤로」로 돌아와도 마지막 후보 묶음과 그에 딸린 `selectionToken` 이 남는다.
    /// 재추천으로 무효화된 첫 토큰이 되살아나면 마지막 가입 요청이 서버에서 거절된다 (IOS-F57).
    func adopt(_ response: AuthNicknameCandidatesResponse) {
        guard !isLoading else { return }
        candidates = response.candidates
        selectionToken = response.selectionToken
        selectedNickname = ""
        errorMessage = nil
        refreshCount = 0
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

    /// 서버 후보가 오기 전의 자리. 비어 있어야 화면이 스켈레톤(로딩)을 그린다 (NO-MOCK-CANON R1).
    static let initialResponse = AuthNicknameCandidatesResponse(selectionToken: "", candidates: [])
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
