//
//  MockData.swift
//  MoyeoTrip
//

// swiftlint:disable file_length

import Foundation

enum MockData {}

extension MockData {
    static let currentWeatherCondition: WeatherCondition = .sunny

    static let participants: [Participant] = [
        Participant(id: "user-01", name: "다정한 곰 1001", avatar: "🐻"),
        Participant(id: "user-02", name: "숲속 사슴 2417", avatar: "🦌"),
        Participant(id: "user-03", name: "잔잔한 거북이 9032", avatar: "🐢"),
        Participant(id: "user-04", name: "고요한 두루미 1130", avatar: "🪽"),
        Participant(id: "user-05", name: "느긋한 토끼 7821", avatar: "🐰"),
        Participant(id: "user-06", name: "따뜻한 곰 2401", avatar: "🐻")
    ]

    static let courses: [TravelCourse] = [
        TravelCourse(
            id: "course-cheongsong-juwangsan",
            title: "주왕산 & 주산지 힐링 트레킹",
            region: "청송",
            subtitle: "기암절벽과 맑은 주산지 풍경을 함께 즐기는 숲길 코스예요.",
            duration: "2시간",
            distance: "6.2km",
            mascot: "🌲",
            mood: .forest,
            tags: ["자연", "히든명소", "추천"],
            stops: ["주왕산국립공원", "용연폭포", "주산지"],
            publishingInfo: CoursePublishingInfo(
                travelerName: "숲속여행자",
                travelerAvatar: "🐻",
                publishedAt: "2026.05.25 여행 후 공개",
                tripCount: 3
            )
        ),
        TravelCourse(
            id: "course-andong-hahoe",
            title: "안동 하회마을 하루 코스",
            region: "안동",
            subtitle: "한옥 골목과 낙동강 물길, 로컬 찻집을 느긋하게 잇는 하루 코스예요.",
            duration: "4시간",
            distance: "8.1km",
            mascot: "🏡",
            mood: .sunrise,
            tags: ["역사", "문화", "한옥"],
            stops: ["하회마을", "부용대", "월영교", "로컬 찻집"]
        ),
        TravelCourse(
            id: "course-ulleung-island",
            title: "울릉도 2박 3일 섬 여행",
            region: "울릉",
            subtitle: "바다 전망과 짧은 트레킹, 섬마을 산책을 묶은 여유로운 일정이에요.",
            duration: "2박 3일",
            distance: "12.4km",
            mascot: "🌊",
            mood: .river,
            tags: ["자연", "힐링", "섬여행"],
            stops: ["도동항", "행남해안산책로", "나리분지", "관음도"]
        ),
        TravelCourse(
            id: "course-gyeongju-history",
            title: "경주 감성 힐링 코스",
            region: "경주",
            subtitle: "첨성대와 월정교, 동궁과 월지 야경까지 이어지는 경주 감성 코스예요.",
            duration: "5시간",
            distance: "7.3km",
            mascot: "🌙",
            mood: .coral,
            tags: ["역사", "야경", "감성"],
            stops: ["첨성대", "월정교", "황리단길", "동궁과 월지"]
        ),
        TravelCourse(
            id: "course-pohang-drive",
            title: "포항·영덕 동해 드라이브",
            region: "포항",
            subtitle: "해안 도로와 바다 전망 카페, 시장 먹거리를 가볍게 잇는 코스예요.",
            duration: "4시간",
            distance: "9.1km",
            mascot: "🌉",
            mood: .river,
            tags: ["바다", "드라이브", "브런치"],
            stops: ["영일대해수욕장", "스페이스워크", "오션뷰 브런치", "죽도시장"]
        ),
        TravelCourse(
            id: "course-mungyeong-saejae",
            title: "문경 새재 단풍 트레킹",
            region: "문경",
            subtitle: "완만한 고갯길과 단풍 숲길을 천천히 걷는 가을 산책 코스예요.",
            duration: "2시간",
            distance: "5.6km",
            mascot: "🍁",
            mood: .blossom,
            tags: ["자연", "단풍", "트레킹"],
            stops: ["문경새재 1관문", "조령원터", "오픈세트장", "새재길 쉼터"]
        ),
        TravelCourse(
            id: "course-yeongju-buseoksa",
            title: "영주 부석사 눈꽃 산책",
            region: "영주",
            subtitle: "부석사의 겨울 능선과 짧은 산책길을 안전하게 둘러보는 코스예요.",
            duration: "3시간",
            distance: "4.2km",
            mascot: "❄️",
            mood: .sunrise,
            tags: ["역사", "눈", "사찰"],
            stops: ["부석사 일주문", "무량수전", "소수서원", "풍기 카페"]
        ),
        TravelCourse(
            id: "course-andong-dosan",
            title: "안동 도산서원 그늘 코스",
            region: "안동",
            subtitle: "더운 날에도 쉬어가기 좋은 서원과 강변 그늘을 중심으로 걸어요.",
            duration: "2시간",
            distance: "3.8km",
            mascot: "🌿",
            mood: .forest,
            tags: ["역사", "그늘", "짧은동선"],
            stops: ["도산서원", "낙동강 전망대", "서원 숲길", "전통찻집"]
        )
    ]

    static let trips: [TripRecruitment] = [
        TripRecruitment(
            id: "trip-cheongsong-juwangsan",
            courseID: "course-cheongsong-juwangsan",
            title: "30대끼리 느긋하게 힐링 여행가요~",
            region: "청송",
            coverMascot: "🌲",
            // 호스트 이름은 4개 플랫폼 공통 기준값이다 (docs/alignment/MOCKDATA-CANON.md)
            hostName: "숲속여행자",
            hostAvatar: "🐻",
            schedule: "2026.05.25 (토) 08:00",
            meetupPoint: "청송 시외버스터미널",
            price: "1인 45,000원",
            capacity: 5,
            joined: 2,
            minimumParticipants: 3,
            status: .open,
            summary: "주왕산 숲길을 천천히 걷고 주산지 물그림자까지 둘러보는 당일 모임이에요.",
            vibe: "초보도 따라오기 쉬운 속도, 쉬는 시간을 넉넉히 두는 조용한 분위기",
            tags: ["자연", "트레킹", "초보가능"],
            route: ["청송 시외버스터미널", "주왕산 국립공원", "주산지", "달기약수탕"],
            participants: Array(participants.prefix(2)),
            // 화면기획 15 — 대표 모집은 호스트가 직접 만든 코스다
            courseSource: .custom,
            // 화면기획 18-x 여행 경로 — 방문지 4곳과 행별 부제(집합 장소 · 대전사 ~ 제3폭포 …)
            itinerary: [
                ItineraryStop(
                    id: "trip-cheongsong-stop-1", day: 1, order: 1, time: "09:00",
                    name: "청송 시외버스터미널", memo: "집합 장소"),
                ItineraryStop(
                    id: "trip-cheongsong-stop-2", day: 1, order: 2, time: "10:30",
                    name: "주왕산 국립공원", memo: "대전사 ~ 제3폭포"),
                ItineraryStop(
                    id: "trip-cheongsong-stop-3", day: 1, order: 3, time: "14:00",
                    name: "주산지", memo: "왕버들 산책로"),
                ItineraryStop(
                    id: "trip-cheongsong-stop-4", day: 1, order: 4, time: "16:30",
                    name: "달기약수탕", memo: "늦은 점심")
            ],
            scheduleDetails: TripScheduleDetails(
                kind: .dayTrip,
                startDate: "2026.05.25 (토)",
                startTime: "08:00",
                endTime: "18:00"
            ),
            // 화면기획 15 일정 카드 — 집합 시간 · 정문 앞 · 좌표 · 길 찾기
            meetingDetails: MeetingPointDetails(
                name: "청송 시외버스터미널",
                address: "경북 청송군 청송읍 금월로 231",
                detail: "정문 앞",
                latitude: 36.435612,
                longitude: 129.057214,
                meetingTime: "07:50"
            ),
            recruitmentDeadline: "D-3 · 5/22(금)",
            genderRestriction: "제한 없음",
            routeEditState: .editable
        ),
        TripRecruitment(
            id: "trip-andong-hahoe",
            courseID: "course-andong-hahoe",
            title: "안동 하회마을 하루여행",
            region: "안동",
            coverMascot: "🏡",
            hostName: "잔잔한 거북이 9032",
            hostAvatar: "🐢",
            schedule: "2026.06.09 (화) 10:00",
            meetupPoint: "안동터미널 대합실",
            price: "1인 22,000원",
            capacity: 6,
            joined: 3,
            minimumParticipants: 3,
            status: .confirmed,
            summary: "하회마을 골목과 부용대 전망, 월영교 산책을 한 번에 둘러보는 역사 코스예요.",
            vibe: "한옥과 이야기를 좋아하는 사람끼리 천천히 대화하는 소규모 모임",
            tags: ["역사", "문화", "찻집"],
            route: ["안동터미널", "하회마을", "부용대", "월영교", "로컬 찻집"],
            participants: Array(participants.prefix(3))
        ),
        TripRecruitment(
            id: "trip-gyeongju-night",
            courseID: "course-gyeongju-history",
            title: "경주 단풍·야경 1박 2일",
            region: "경주",
            coverMascot: "🌙",
            hostName: "고요한 두루미 1130",
            hostAvatar: "🪽",
            schedule: "2026.06.05 (금) 14:00",
            meetupPoint: "경주역 2번 출구",
            price: "1인 64,000원",
            capacity: 8,
            joined: 4,
            minimumParticipants: 3,
            status: .open,
            summary: "첨성대와 월정교, 동궁과 월지 야경을 단풍 시즌에 맞춰 천천히 둘러봐요.",
            vibe: "사진을 좋아하지만 이동은 느긋하게, 저녁 이후 야경 시간을 충분히 남겨요",
            tags: ["야경", "단풍", "1박2일"],
            route: ["경주역", "첨성대", "황리단길", "월정교", "동궁과 월지"],
            participants: Array(participants.prefix(5)),
            // 화면기획 18 모집 관리 — 호스트 직접 코스 · 방문지 4곳 · 확정 전(D-3)까지 수정 가능
            courseSource: .custom,
            itinerary: [
                ItineraryStop(
                    id: "trip-gyeongju-stop-1", day: 1, order: 1, time: "14:00",
                    name: "경주역", memo: "집합 장소"),
                ItineraryStop(
                    id: "trip-gyeongju-stop-2", day: 1, order: 2, time: "15:00",
                    name: "첨성대", memo: "단풍 산책"),
                ItineraryStop(
                    id: "trip-gyeongju-stop-3", day: 1, order: 3, time: "17:00",
                    name: "월정교", memo: "노을 사진"),
                ItineraryStop(
                    id: "trip-gyeongju-stop-4", day: 1, order: 4, time: "19:00",
                    name: "동궁과 월지", memo: "야경 관람")
            ],
            recruitmentDeadline: "D-3",
            routeEditState: .editable
        ),
        TripRecruitment(
            id: "trip-pohang-drive",
            courseID: "course-pohang-drive",
            title: "포항·영덕 동해 드라이브",
            region: "포항",
            coverMascot: "🌉",
            hostName: "우직한 곰 7821",
            hostAvatar: "🐻",
            schedule: "2026.06.15 (월) 09:30",
            meetupPoint: "포항역 광장",
            price: "1인 35,000원",
            capacity: 6,
            joined: 6,
            minimumParticipants: 3,
            status: .confirmed,
            summary: "바다 전망 카페와 스페이스워크, 죽도시장 먹거리를 하루에 잇는 코스예요.",
            vibe: "이동은 차분하게, 해안 사진과 로컬 먹거리를 넉넉히 즐기는 분위기",
            tags: ["바다", "드라이브", "시장"],
            route: ["포항역", "영일대해수욕장", "스페이스워크", "죽도시장"],
            participants: Array(participants.prefix(6))
        ),
        TripRecruitment(
            id: "trip-ulleung-island",
            courseID: "course-ulleung-island",
            title: "울릉도 2박 3일 섬 여행",
            region: "울릉",
            coverMascot: "🌊",
            hostName: "잔잔한 거북이 9032",
            hostAvatar: "🐢",
            schedule: "2026.07.12 (일) 09:00",
            meetupPoint: "포항여객선터미널",
            price: "1인 86,000원",
            capacity: 5,
            joined: 3,
            minimumParticipants: 3,
            status: .confirmed,
            summary: "도동항에서 행남해안산책로, 나리분지까지 천천히 이어 보는 섬 여행이에요.",
            vibe: "이동 시간을 넉넉히 잡고 날씨에 맞춰 실내 대체 동선도 함께 챙겨요",
            tags: ["섬여행", "해안산책", "힐링"],
            route: ["포항여객선터미널", "도동항", "행남해안산책로", "나리분지", "관음도"],
            participants: Array(participants.prefix(3))
        ),
        TripRecruitment(
            id: "trip-mungyeong-saejae",
            courseID: "course-mungyeong-saejae",
            title: "문경 새재 단풍 트레킹",
            region: "문경",
            coverMascot: "🍁",
            hostName: "달빛 토끼 6142",
            hostAvatar: "🐰",
            schedule: "2026.10.31 (토) 08:30",
            meetupPoint: "문경새재 제1주차장",
            price: "1인 28,000원",
            capacity: 5,
            joined: 2,
            minimumParticipants: 3,
            status: .open,
            summary: "문경새재의 완만한 숲길을 따라 단풍과 옛길 풍경을 천천히 걸어요.",
            vibe: "대화보다 풍경을 즐기는 조용한 속도, 쉬는 시간을 자주 가져요",
            tags: ["단풍", "트레킹", "숲길"],
            route: ["제1관문", "조령원터", "오픈세트장", "새재길 쉼터"],
            participants: Array(participants.prefix(2))
        ),
        TripRecruitment(
            id: "trip-yeongju-buseoksa",
            courseID: "course-yeongju-buseoksa",
            title: "영주 부석사 눈꽃 산책",
            region: "영주",
            coverMascot: "❄️",
            hostName: "느긋한 토끼 7821",
            hostAvatar: "🐰",
            schedule: "2026.12.14 (월) 10:00",
            meetupPoint: "영주역 대합실",
            price: "1인 31,000원",
            capacity: 5,
            joined: 4,
            minimumParticipants: 3,
            status: .almostFull,
            summary: "부석사와 소수서원 주변의 짧은 겨울 동선을 안전하게 둘러보는 모임이에요.",
            vibe: "눈길 이동을 줄이고 따뜻한 실내 휴식 시간을 넉넉히 잡아요",
            tags: ["눈", "사찰", "짧은동선"],
            route: ["영주역", "부석사", "소수서원", "풍기 카페"],
            participants: Array(participants.prefix(4))
        ),
        TripRecruitment(
            id: "trip-andong-dosan",
            courseID: "course-andong-dosan",
            title: "안동 도산서원 그늘 코스",
            region: "안동",
            coverMascot: "🌿",
            hostName: "초록 여우 5824",
            hostAvatar: "🦊",
            schedule: "2026.07.07 (화) 10:30",
            meetupPoint: "도산서원 주차장",
            price: "1인 19,000원",
            capacity: 4,
            joined: 2,
            minimumParticipants: 3,
            status: .open,
            summary: "도산서원과 낙동강 전망대, 서원 숲길을 더운 날에도 짧게 걷는 코스예요.",
            vibe: "그늘과 휴식 지점을 먼저 확인하며 천천히 움직이는 가벼운 모임",
            tags: ["역사", "그늘", "짧은동선"],
            route: ["도산서원 주차장", "도산서원", "낙동강 전망대", "전통찻집"],
            participants: Array(participants.prefix(2))
        )
    ]

    static let spots: [ExploreSpot] = [
        ExploreSpot(
            id: "spot-juwangsan",
            name: "주왕산국립공원",
            region: "청송",
            category: "자연",
            address: "경북 청송군 주왕산면 공원길",
            summary: "기암절벽과 폭포, 완만한 숲길이 이어지는 청송 대표 트레킹 명소",
            mapHint: "청송 북동쪽 숲길",
            mascot: "🌲",
            tags: ["트레킹", "폭포", "주산지"],
            linkedTripID: "trip-cheongsong-juwangsan"
        ),
        ExploreSpot(
            id: "spot-hahoe",
            name: "하회마을",
            region: "안동",
            category: "역사",
            address: "경북 안동시 풍천면 하회리",
            summary: "기와와 초가가 함께 남아 있는 경북 대표 한옥 마을",
            mapHint: "낙동강 곡선 안쪽",
            mascot: "🏡",
            tags: ["한옥", "유네스코", "산책"],
            linkedTripID: "trip-andong-hahoe"
        ),
        ExploreSpot(
            id: "spot-ulleung",
            name: "울릉도",
            region: "울릉",
            category: "자연",
            address: "경북 울릉군 울릉읍",
            summary: "해안 산책로와 섬마을 풍경이 선명한 2박 3일 여행지",
            mapHint: "동해 한가운데 섬 코스",
            mascot: "🌊",
            tags: ["섬여행", "해안산책", "힐링"],
            linkedTripID: "trip-ulleung-island"
        ),
        ExploreSpot(
            id: "spot-gyeongju",
            name: "첨성대",
            region: "경주",
            category: "역사",
            address: "경북 경주시 인왕동",
            summary: "월정교와 동궁과 월지 야경으로 이어지는 경주 감성 산책 시작점",
            mapHint: "경주 중심 역사 지구",
            mascot: "🌙",
            tags: ["야경", "역사", "산책"],
            linkedTripID: "trip-gyeongju-night"
        ),
        ExploreSpot(
            id: "spot-pohang",
            name: "포항 스페이스워크",
            region: "포항",
            category: "바다",
            address: "경북 포항시 북구 두호동",
            summary: "해안 전망과 도시 풍경이 함께 보이는 포항 대표 산책 명소",
            mapHint: "영일대해수욕장 근처",
            mascot: "🌉",
            tags: ["바다", "사진", "드라이브"],
            linkedTripID: "trip-pohang-drive"
        ),
        ExploreSpot(
            id: "spot-mungyeong",
            name: "문경새재",
            region: "문경",
            category: "자연",
            address: "경북 문경시 문경읍 새재로",
            summary: "고갯길과 숲길이 완만하게 이어지는 단풍 산책지",
            mapHint: "문경 북쪽 숲길",
            mascot: "🍁",
            tags: ["단풍", "트레킹", "숲길"],
            linkedTripID: "trip-mungyeong-saejae"
        ),
        ExploreSpot(
            id: "spot-buseoksa",
            name: "부석사",
            region: "영주",
            category: "역사",
            address: "경북 영주시 부석면 부석사로",
            summary: "겨울 능선과 사찰 풍경이 차분한 영주 대표 역사 명소",
            mapHint: "영주 북동쪽 산길",
            mascot: "❄️",
            tags: ["사찰", "눈", "짧은동선"],
            linkedTripID: "trip-yeongju-buseoksa"
        )
    ]

    static let chatThreads: [ChatThread] = [
        ChatThread(
            id: "chat-gyeongju-night",
            tripTitle: "경주 단풍·야경",
            region: "경주",
            mascot: "🌙",
            lastMessage: "우직한 곰: 내일 오후 2시 만나요",
            updatedAt: "3:42",
            unreadCount: 3,
            statusSummary: "4/8명 · 마감 D-3",
            statusDetail: "비 예보가 있어 실내 동선부터 다시 확인하고 있어요.",
            members: Array(participants.prefix(4)),
            messages: [
                ChatMessage(
                    id: "g1",
                    senderName: "우직한 곰 7821",
                    avatar: "🐻",
                    body: "신청 감사합니다. 내일 오후 2시 만나요.",
                    time: "3:22",
                    isMine: false
                ),
                ChatMessage(
                    id: "g2",
                    senderName: "다정한 곰 1001",
                    avatar: "🐻",
                    body: "좋아요. 신경주역으로 가면 될까요?",
                    time: "3:28",
                    isMine: true
                )
            ],
            isReadOnly: false
        ),
        ChatThread(
            id: "chat-pohang-drive",
            tripTitle: "포항·영덕 동해 드라이브",
            region: "포항",
            mascot: "🌊",
            lastMessage: "잔잔한 거북이: 오늘 사진 올릴게요",
            updatedAt: "1:20",
            unreadCount: 0,
            statusSummary: "6/6명 · 확정",
            statusDetail: "출발 확정 · 신청 대기 0명",
            members: Array(participants.prefix(6)),
            messages: [
                ChatMessage(
                    id: "p1",
                    senderName: "따스한 사슴 3492",
                    avatar: "🦌",
                    body: "확정 인원 기준으로 식당 예약해둘게요.",
                    time: "어제",
                    isMine: false
                ),
                ChatMessage(
                    id: "p2",
                    senderName: "다정한 곰 1001",
                    avatar: "🐻",
                    body: "운전 동선은 공유해주시면 확인할게요.",
                    time: "어제",
                    isMine: true
                )
            ],
            isReadOnly: false
        ),
        ChatThread(
            id: "chat-ulleung-island",
            tripTitle: "울릉도 2박 3일 섬 여행",
            region: "울릉",
            mascot: "🌊",
            lastMessage: "잔잔한 거북이: 배편 시간 다시 확인했어요",
            updatedAt: "방금",
            unreadCount: 0,
            statusSummary: "3/5명 · 확정",
            statusDetail: "날씨에 따라 해안 산책 순서를 조정할 예정이에요.",
            members: Array(participants.prefix(3)),
            messages: [
                ChatMessage(
                    id: "u1",
                    senderName: "잔잔한 거북이 9032",
                    avatar: "🐢",
                    body: "배편 시간 다시 확인했어요. 멀미약도 챙기면 좋아요.",
                    time: "방금",
                    isMine: false
                ),
                ChatMessage(
                    id: "u2",
                    senderName: "다정한 곰 1001",
                    avatar: "🐻",
                    body: "좋아요. 날씨가 바뀌면 실내 동선 먼저 볼게요.",
                    time: "방금",
                    isMine: true
                )
            ],
            isReadOnly: false
        ),
        ChatThread(
            id: "chat-andong-hahoe",
            tripTitle: "안동 하회마을 한옥체험",
            region: "안동",
            mascot: "🏡",
            lastMessage: "고요한 두루미: 내일 출발이에요!",
            updatedAt: "어제",
            unreadCount: 1,
            statusSummary: "3/6명 · 확정",
            statusDetail: "출발 확정 · 신청 대기 0명",
            members: Array(participants.prefix(3)),
            messages: [
                ChatMessage(
                    id: "a1",
                    senderName: "초록 여우 5824",
                    avatar: "🦊",
                    body: "한옥 체크인 시간은 오후 4시예요.",
                    time: "월",
                    isMine: false
                ),
                ChatMessage(
                    id: "a2",
                    senderName: "다정한 곰 1001",
                    avatar: "🐻",
                    body: "그 전에 하회마을을 먼저 보면 좋겠어요.",
                    time: "월",
                    isMine: true
                )
            ],
            isReadOnly: false
        ),
        ChatThread(
            id: "chat-andong-dosan",
            tripTitle: "안동 도산서원 그늘 코스",
            region: "안동",
            mascot: "🌿",
            lastMessage: "초록 여우: 그늘 길 위주로 천천히 걸어요",
            updatedAt: "어제",
            unreadCount: 0,
            statusSummary: "2/4명 · 모집중",
            statusDetail: "최소 3명까지 한 분만 더 모이면 출발 가능해요.",
            members: Array(participants.prefix(2)),
            messages: [
                ChatMessage(
                    id: "d1",
                    senderName: "초록 여우 5824",
                    avatar: "🦊",
                    body: "더운 시간은 피하고 그늘 길 위주로 천천히 걸어요.",
                    time: "어제",
                    isMine: false
                ),
                ChatMessage(
                    id: "d2",
                    senderName: "다정한 곰 1001",
                    avatar: "🐻",
                    body: "전통찻집 쉬는 시간이 있으면 좋겠어요.",
                    time: "어제",
                    isMine: true
                )
            ],
            isReadOnly: false
        ),
        ChatThread(
            id: "chat-mungyeong-fall",
            tripTitle: "문경 새재 단풍 트레킹",
            region: "문경",
            mascot: "🪽",
            lastMessage: "시스템: 모집이 마감 임박합니다",
            updatedAt: "월",
            unreadCount: 0,
            statusSummary: "2/5명 · 마감 D-1",
            statusDetail: "최소 3명까지 한 분만 더 모이면 출발 가능해요.",
            members: Array(participants.prefix(2)),
            messages: [
                ChatMessage(
                    id: "m1",
                    senderName: "고요한 두루미 1130",
                    avatar: "🪽",
                    body: "최소 3명까지 한 분만 더 모이면 출발 가능해요.",
                    time: "일",
                    isMine: false
                ),
                ChatMessage(
                    id: "m2",
                    senderName: "다정한 곰 1001",
                    avatar: "🐻",
                    body: "일정 확정되면 알려주세요.",
                    time: "일",
                    isMine: true
                )
            ],
            isReadOnly: false
        ),
        ChatThread(
            id: "chat-cheongsong-juwangsan",
            tripTitle: "30대끼리 느긋하게 힐링 여행가요~",
            region: "청송",
            mascot: "🌲",
            lastMessage: "숲속여행자: 저도 함께하게 되어 반갑습니다~",
            updatedAt: "09:32",
            unreadCount: 0,
            statusSummary: "2/5명 · 마감 D-3",
            statusDetail: "1명만 더 모이면 출발 확정",
            members: Array(participants.prefix(2)),
            // 화면기획 20 — 시스템 필 2개 + 인사 버블 3개 + 경로 수정 카드
            messages: [
                ChatMessage(
                    id: "j0-join",
                    senderName: "시스템",
                    avatar: "🌲",
                    body: "모여트립이님이 모임에 참여했어요.",
                    time: "",
                    isMine: false,
                    kind: .system
                ),
                ChatMessage(
                    id: "j0-open",
                    senderName: "시스템",
                    avatar: "🌲",
                    body: "숲속여행자님이 모임을 개설했어요.",
                    time: "",
                    isMine: false,
                    kind: .system
                ),
                ChatMessage(
                    id: "j1",
                    senderName: "숲속여행자",
                    avatar: "🐻",
                    body: "안녕하세요! 좋은 하루 보내세요 😊",
                    time: "09:30",
                    isMine: false
                ),
                ChatMessage(
                    id: "j2",
                    senderName: "다정한 곰 1001",
                    avatar: "🐻",
                    body: "안녕하세요! 잘 부탁드려요!",
                    time: "09:31",
                    isMine: true
                ),
                ChatMessage(
                    id: "j3",
                    senderName: "숲속여행자",
                    avatar: "🐻",
                    body: "저도 함께하게 되어 반갑습니다~",
                    time: "09:32",
                    isMine: false
                ),
                ChatMessage(
                    id: "j4-route",
                    senderName: "시스템",
                    avatar: "🌲",
                    body: "3번째 방문지가 **주산지 → 달기약수탕**으로 바뀌었어요. 여행 확정(5/22) 전까지는 경로가 바뀔 수 있어요.",
                    time: "",
                    isMine: false,
                    kind: .routeChanged
                )
            ],
            isReadOnly: false,
            tripID: "trip-cheongsong-juwangsan",
            routeSummary: [
                ItineraryStop(
                    id: "trip-cheongsong-stop-1", day: 1, order: 1, time: "09:00",
                    name: "청송 시외버스터미널", memo: "집합 장소"),
                ItineraryStop(
                    id: "trip-cheongsong-stop-2", day: 1, order: 2, time: "10:30",
                    name: "주왕산 국립공원", memo: "대전사 ~ 제3폭포"),
                ItineraryStop(
                    id: "trip-cheongsong-stop-3", day: 1, order: 3, time: "14:00",
                    name: "주산지", memo: "왕버들 산책로"),
                ItineraryStop(
                    id: "trip-cheongsong-stop-4", day: 1, order: 4, time: "16:30",
                    name: "달기약수탕", memo: "늦은 점심")
            ],
            courseSource: .custom,
            courseName: "주왕산 & 주산지 힐링 트레킹",
            price: "1인 45,000원",
            recruitmentDeadline: "D-3",
            ageRange: "25~35세",
            genderRestriction: "성별 무관",
            scheduleSummary: "5/25(토) 08:00–18:00 · 당일치기"
        ),
        ChatThread(
            id: "chat-yeongju-buseoksa",
            tripTitle: "영주 부석사 눈꽃 산책",
            region: "영주",
            mascot: "❄️",
            lastMessage: "느긋한 토끼: 눈길이라 이동 시간을 조금 더 잡을게요",
            updatedAt: "어제",
            unreadCount: 0,
            statusSummary: "4/5명 · 마감 D-2",
            statusDetail: "눈길 이동을 줄이고 따뜻한 실내 휴식 시간을 넉넉히 잡아요.",
            members: Array(participants.prefix(4)),
            messages: [
                ChatMessage(
                    id: "y1",
                    senderName: "느긋한 토끼 7821",
                    avatar: "🐰",
                    body: "눈길이라 이동 시간을 조금 더 잡을게요.",
                    time: "어제",
                    isMine: false
                ),
                ChatMessage(
                    id: "y2",
                    senderName: "다정한 곰 1001",
                    avatar: "🐻",
                    body: "좋아요. 따뜻한 카페도 같이 보면 좋겠어요.",
                    time: "어제",
                    isMine: true
                )
            ],
            isReadOnly: false
        ),
        ChatThread(
            id: "chat-ended-andong-spring",
            tripTitle: "안동 봄날 고택 산책",
            region: "안동",
            mascot: "🌿",
            lastMessage: "시스템: 여행 기록이 피드에 저장됐어요",
            updatedAt: "4월",
            unreadCount: 0,
            statusSummary: "5/5명 · 종료",
            statusDetail: "여행이 종료되어 읽기 전용으로 보관돼요.",
            members: Array(participants.prefix(5)),
            messages: [
                ChatMessage(
                    id: "ea1",
                    senderName: "초록 여우 5824",
                    avatar: "🦊",
                    body: "고택 골목 사진 정리해서 피드에 올렸어요.",
                    time: "4월",
                    isMine: false
                )
            ],
            isReadOnly: true,
            closureReason: "여행이 종료됐어요",
            archiveNotice: "채팅은 14일 동안 읽기 전용으로 보관되고 이후 친구 도감 기록만 남아요.",
            archiveStatus: "보관 D-14"
        ),
        ChatThread(
            id: "chat-ended-ulleung",
            tripTitle: "울릉도 2박 3일 섬 여행",
            region: "울릉",
            mascot: "🌊",
            lastMessage: "시스템: 도감 친구 3명이 추가됐어요",
            updatedAt: "3월",
            unreadCount: 0,
            statusSummary: "5/5명 · 종료",
            statusDetail: "여행이 종료되어 읽기 전용으로 보관돼요.",
            members: Array(participants.prefix(5)),
            messages: [
                ChatMessage(
                    id: "eu1",
                    senderName: "고요한 두루미 1130",
                    avatar: "🪽",
                    body: "다음에는 관음도 일몰도 같이 봐요.",
                    time: "3월",
                    isMine: false
                )
            ],
            isReadOnly: true,
            closureReason: "호스트가 모임을 종료했어요",
            archiveNotice: "채팅은 14일 동안 읽기 전용으로 보관되고 이후 친구 도감 기록만 남아요.",
            archiveStatus: "보관 D-13"
        )
    ]

    static let feedPosts: [FeedPost] = [
        FeedPost(
            id: "feed-01",
            authorName: "숲속여행자",
            authorAvatar: "🐻",
            region: "청송",
            createdAt: "2시간 전",
            photoMascot: "🗺️",
            caption: "주왕산 & 주산지 힐링 트레킹 경로가 한눈에 남아서 다음 사람에게도 추천하기 좋았어요.",
            tags: ["경로지도", "주왕산", "청송"],
            route: ["주왕산", "용연폭포", "주산지"],
            visibility: .friendsOnly,
            likeCount: 128,
            commentCount: 18,
            mood: .forest,
            title: "주왕산 & 주산지 힐링 트레킹",
            // 부제는 "장소 · #해시태그" 한 줄로 조립된다 (지역은 feedSubtitle 이 앞에 붙인다)
            subtitle: "#주왕산 #주산지 #숲길",
            detailBody: "정말 아름다운 코스였어요! 함께해주신 분들 감사해요 😊"
        ),
        FeedPost(
            id: "feed-02",
            authorName: "토끼여행자",
            authorAvatar: "🐰",
            region: "안동",
            createdAt: "5시간 전",
            photoMascot: "🏡",
            caption: "안동 하회마을, 잊지 못할 하루. 부용대에서 내려다본 강 물길이 가장 오래 남아요.",
            tags: ["하회마을", "경로지도", "안동"],
            route: ["하회마을", "부용대", "월영교"],
            visibility: .friendsOnly,
            likeCount: 128,
            commentCount: 18,
            mood: .sunrise,
            title: "안동 하회마을, 잊지 못할 하루",
            subtitle: "#한옥산책 #가을여행",
            detailBody: "고택 골목을 천천히 걷고 부용대에서 내려다본 마을 풍경이 오래 남았어요."
        ),
        FeedPost(
            id: "feed-03",
            authorName: "고요한 두루미 1130",
            authorAvatar: "🪽",
            region: "경주",
            createdAt: "어제",
            photoMascot: "🌙",
            caption: "경주 역사 감성 여행은 월정교에서 동궁과 월지로 이어지는 밤 동선이 제일 좋았어요.",
            tags: ["경주", "야경", "월정교"],
            route: ["첨성대", "월정교", "동궁과 월지"],
            visibility: .publicAll,
            likeCount: 56,
            commentCount: 12,
            mood: .coral,
            title: "경주 역사 감성 여행",
            subtitle: "#야경 #월정교",
            detailBody: "월정교에서 동궁과 월지로 이어지는 밤 동선이 제일 좋았어요."
        ),
        FeedPost(
            id: "feed-04",
            authorName: "달빛 토끼 6142",
            authorAvatar: "🐰",
            region: "포항",
            createdAt: "2일 전",
            photoMascot: "🌉",
            caption: "스페이스워크에서 바다를 보고 죽도시장에서 함께 나눈 간식까지 알찼던 하루였어요.",
            tags: ["포항", "바다", "드라이브"],
            route: ["영일대", "스페이스워크", "죽도시장"],
            visibility: .friendsOnly,
            likeCount: 73,
            commentCount: 9,
            mood: .river,
            title: "포항 바다와 시장을 한 번에",
            subtitle: "#바다 #드라이브",
            detailBody: "스페이스워크에서 바다를 보고 죽도시장 간식까지 알찼던 하루였어요."
        ),
        FeedPost(
            id: "feed-05",
            authorName: "초록 여우 5824",
            authorAvatar: "🦊",
            region: "문경",
            createdAt: "3일 전",
            photoMascot: "🍁",
            caption: "문경새재 길은 급하지 않게 걸을수록 단풍 사이 작은 풍경이 더 잘 보여요.",
            tags: ["문경", "단풍", "숲길"],
            route: ["제1관문", "조령원터", "새재길"],
            visibility: .publicAll,
            likeCount: 64,
            commentCount: 7,
            mood: .blossom,
            title: "문경새재 길은 천천히 걸을수록 좋아요",
            subtitle: "#단풍 #숲길",
            detailBody: "급하지 않게 걸을수록 단풍 사이 작은 풍경이 더 잘 보여요."
        ),
        FeedPost(
            id: "feed-06",
            authorName: "느긋한 토끼 7821",
            authorAvatar: "🐰",
            region: "영주",
            createdAt: "지난주",
            photoMascot: "❄️",
            caption: "부석사는 짧게 걸어도 겨울 공기와 풍경이 충분해서 무리하지 않는 코스로 좋았어요.",
            tags: ["영주", "부석사", "눈"],
            route: ["부석사", "소수서원", "풍기 카페"],
            visibility: .privateOnly,
            likeCount: 31,
            commentCount: 4,
            mood: .sunrise,
            title: "부석사 눈꽃은 짧게 걸어도 좋아요",
            subtitle: "#부석사 #눈"
        ),
        FeedPost(
            id: "feed-07",
            authorName: "잔잔한 거북이 9032",
            authorAvatar: "🐢",
            region: "울릉",
            createdAt: "2주 전",
            photoMascot: "🌊",
            caption: "울릉도는 하루를 비워 천천히 움직일수록 섬의 속도가 더 잘 느껴졌어요.",
            tags: ["울릉", "섬여행", "해안산책"],
            route: ["도동항", "행남해안산책로", "나리분지"],
            visibility: .friendsOnly,
            likeCount: 89,
            commentCount: 16,
            mood: .river,
            title: "울릉도는 천천히 움직여야 보여요",
            subtitle: "#섬여행 #해안산책"
        )
    ]

    // 화면기획 25 공개 프로필 · 26 마이 — 내 계정 표시 이름은 "모여트립이"다
    static let profile = ProfileSummary(
        name: "모여트립이",
        handle: "@moyeo_trip",
        avatar: "🐻",
        profileImageURL: nil,
        region: "경북 구미",
        badges: ["여행 12", "매너 4.7", "경북 친구"],
        joinedTrips: 12,
        hostedTrips: 3,
        feedCount: 21,
        points: 2840,
        favoriteRegions: ["청송", "안동", "경주", "울릉"]
    )

    static let dogamFriends: [DogamFriend] = [
        DogamFriend(id: "dogam-01", nickname: "따스한 사슴 3492", avatar: "🦌", lastMetAt: "2일 전", metCount: 2),
        DogamFriend(id: "dogam-02", nickname: "우직한 곰 7821", avatar: "🐻", lastMetAt: "2일 전", metCount: 2),
        DogamFriend(id: "dogam-03", nickname: "잔잔한 거북이 9032", avatar: "🐢", lastMetAt: "2일 전", metCount: 1),
        DogamFriend(id: "dogam-04", nickname: "고요한 두루미 1130", avatar: "🪽", lastMetAt: "3주 전", metCount: 1),
        DogamFriend(id: "dogam-05", nickname: "엉뚱한 토끼 4821", avatar: "🐰", lastMetAt: "3주 전", metCount: 1),
        DogamFriend(id: "dogam-06", nickname: "호기심 너구리 2035", avatar: "🦝", lastMetAt: "6주 전", metCount: 1),
        DogamFriend(id: "dogam-07", nickname: "나른한 사슴 7158", avatar: "🦌", lastMetAt: "8주 전", metCount: 1),
        DogamFriend(id: "dogam-08", nickname: "느긋한 곰 2401", avatar: "🐻", lastMetAt: "8주 전", metCount: 2),
        DogamFriend(id: "dogam-09", nickname: "평온한 거북이 9032", avatar: "🐢", lastMetAt: "12주 전", metCount: 2),
        DogamFriend(id: "dogam-10", nickname: "청아한 두루미 6810", avatar: "🪽", lastMetAt: "14주 전", metCount: 1),
        DogamFriend(id: "dogam-11", nickname: "깡총 토끼 6142", avatar: "🐰", lastMetAt: "14주 전", metCount: 1),
        DogamFriend(id: "dogam-12", nickname: "말많은 너구리 3904", avatar: "🦝", lastMetAt: "20주 전", metCount: 1)
    ]

    static func trip(for id: String?) -> TripRecruitment? {
        guard let id else { return nil }
        let canonicalID = canonicalTripID(id)
        return trips.first { $0.id == canonicalID }
            ?? trip(forCourseID: id)
    }

    static func course(forSpotID spotID: String) -> TravelCourse? {
        switch spotID {
        case "spot-juwangsan":
            return course(for: "course-cheongsong-juwangsan")
        case "spot-hahoe":
            return course(for: "course-andong-hahoe")
        case "spot-ulleung":
            return course(for: "course-ulleung-island")
        case "spot-gyeongju":
            return course(for: "course-gyeongju-history")
        case "spot-pohang":
            return course(for: "course-pohang-drive")
        case "spot-mungyeong":
            return course(for: "course-mungyeong-saejae")
        case "spot-buseoksa":
            return course(for: "course-yeongju-buseoksa")
        default:
            return nil
        }
    }

    static func trip(forCourseID courseID: String) -> TripRecruitment? {
        let canonicalID = canonicalCourseID(courseID)
        return trips.first { $0.courseID == canonicalID }
    }

    static func chatThread(forTripID tripID: String) -> ChatThread? {
        guard let trip = trip(for: tripID) else { return nil }

        switch trip.id {
        case "trip-cheongsong-juwangsan":
            return chatThread(for: "chat-cheongsong-juwangsan")
        case "trip-andong-hahoe":
            return chatThread(for: "chat-andong-hahoe")
        case "trip-gyeongju-night":
            return chatThread(for: "chat-gyeongju-night")
        case "trip-pohang-drive":
            return chatThread(for: "chat-pohang-drive")
        case "trip-ulleung-island":
            return chatThread(for: "chat-ulleung-island")
        case "trip-mungyeong-saejae":
            return chatThread(for: "chat-mungyeong-fall")
        case "trip-yeongju-buseoksa":
            return chatThread(for: "chat-yeongju-buseoksa")
        case "trip-andong-dosan":
            return chatThread(for: "chat-andong-dosan")
        default:
            return nil
        }
    }

    static func course(for id: String) -> TravelCourse? {
        let canonicalID = canonicalCourseID(id)
        return courses.first { $0.id == canonicalID }
    }

    static func chatThread(for id: String?) -> ChatThread? {
        guard let id else { return nil }
        let canonicalID = canonicalChatThreadID(id)
        return chatThreads.first { $0.id == canonicalID }
    }

    static func feedPost(for id: String?) -> FeedPost? {
        feedPost(for: id, in: feedPosts)
    }

    static func feedPost(for id: String?, in posts: [FeedPost]) -> FeedPost? {
        guard let id else { return nil }
        let canonicalID = canonicalFeedPostID(id)
        return posts.first { $0.id == canonicalID }
    }

    private static func canonicalCourseID(_ id: String) -> String {
        let unprefixed = id.hasPrefix("course-") ? String(id.dropFirst("course-".count)) : id

        switch unprefixed {
        case "cheongsong-juwangsan":
            return "course-cheongsong-juwangsan"
        case "andong-hahoe":
            return "course-andong-hahoe"
        case "ulleung-island":
            return "course-ulleung-island"
        case "gyeongju-history", "gyeongju-healing":
            return "course-gyeongju-history"
        case "pohang-drive", "pohang-sea":
            return "course-pohang-drive"
        case "mungyeong-saejae":
            return "course-mungyeong-saejae"
        case "yeongju-buseoksa":
            return "course-yeongju-buseoksa"
        case "andong-dosan":
            return "course-andong-dosan"
        default:
            return id
        }
    }

    private static func canonicalTripID(_ id: String) -> String {
        switch id {
        case "trip-gyeongju-history":
            return "trip-gyeongju-night"
        default:
            return id
        }
    }

    private static func canonicalChatThreadID(_ id: String) -> String {
        switch id {
        case "chat-gyeongju-fall":
            return "chat-gyeongju-night"
        case "chat-juwangsan":
            return "chat-cheongsong-juwangsan"
        case "chat-andong-hanok":
            return "chat-andong-hahoe"
        default:
            return id
        }
    }

    private static func canonicalFeedPostID(_ id: String) -> String {
        let prefix = "feed-"
        guard id.hasPrefix(prefix) else { return id }

        let suffix = String(id.dropFirst(prefix.count))
        guard suffix.count == 1, let number = Int(suffix), (1...9).contains(number) else {
            return id
        }

        return String(format: "feed-%02d", number)
    }
}
