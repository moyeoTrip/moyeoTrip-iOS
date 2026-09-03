//
//  MoyeoNicknameAnimal.swift
//  MoyeoTrip
//

import Foundation

/// 닉네임 → 동물 이모지. **앱 전체에서 이 표 하나만 쓴다** (NO-MOCK-CANON R5).
///
/// 정본은 안드로이드 `ui/components/MoyeoNicknameAnimal.kt` 의 20종 표 + `🐾` 폴백이고,
/// 웹 `MoyeoApi.avatarForNickname` 과 여기가 같은 표·같은 폴백을 쓴다.
/// 화면마다 표를 따로 만들면 같은 사람이 화면마다 다른 동물로 보인다.
/// 순수 조회라 액터 격리가 필요 없다. 프로젝트 기본 격리(MainActor)를 그대로 두면
/// 뷰 밖에서 부를 때마다 격리 경고가 난다 — 상태가 없으니 `nonisolated` 가 맞다.
nonisolated enum MoyeoNicknameAnimal {
    /// 서버가 주는 20종은 세 플랫폼이 모두 덮는다 (실서버 표본 135회, 2026-08-29).
    /// 서버가 동물을 새로 추가하면 발자국으로 떨어진다 — 빈 판만 남기면 화면이 깨진 것처럼 보인다.
    static let unknown = "🐾"

    private static let emojis: [String: String] = [
        "사슴": "🦌", "거북이": "🐢", "토끼": "🐰", "여우": "🦊", "수달": "🦦", "다람쥐": "🐿️",
        "고양이": "🐱", "강아지": "🐶", "판다": "🐼", "펭귄": "🐧", "돌고래": "🐬", "부엉이": "🦉",
        "참새": "🐦", "알파카": "🦙", "코알라": "🐨", "두루미": "🪽", "해달": "🦦",
        "고슴도치": "🦔", "너구리": "🦝", "기린": "🦒", "곰": "🐻"
    ]

    /// 서버 닉네임은 "형용사 동물 숫자" 형식이다. 끝이 숫자면 그 앞이 동물, 아니면 마지막 낱말이 동물이다.
    /// 닉네임 자체가 비면 그릴 아바타가 없다는 뜻이라 nil 이다.
    static func emoji(forNickname nickname: String) -> String? {
        let words = nickname.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return nil }
        let last = words[words.count - 1]
        let animal = Int(last) != nil && words.count >= 2 ? words[words.count - 2] : last
        return emojis[animal] ?? unknown
    }

    /// 동물 낱말만 알 때 (가입 흐름의 이름 후보는 동물을 따로 준다).
    static func emoji(forAnimal animal: String) -> String {
        emojis[animal] ?? unknown
    }
}
