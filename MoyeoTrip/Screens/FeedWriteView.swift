//
//  FeedWriteView.swift
//  MoyeoTrip
//

// swiftlint:disable file_length

import PhotosUI
import SwiftUI

/// 24-1 후보 한 건 — **내가 다녀온 여행**(방)과 그 방에 붙은 코스다.
///
/// 근거는 세 API 뿐이다 (2026-09-02 실서버 확인 · 웹 `useFeedWriteTrip()` · 안드로이드와 같은 규칙):
///   `GET /chat-rooms/my`                      → 내 모임 (ended·status 포함)
///   `GET /travel-courses/chat-rooms/{roomId}` → 그 방의 코스 (제목·소요시간·거리·방문지 좌표)
///   `GET /chat-rooms/{roomId}/companions`     → 함께 간 멤버 (완료 여행만 200)
struct FeedWriteTripCandidate: Identifiable {
    let room: ServerMyChatRoom
    /// 방의 일정 정보(tripType·startDate). 코스를 못 읽으면 nil 이고 부제에서 그만큼 빠진다.
    let roomCourse: ServerRoomCourse?
    let course: TravelCourse?

    var id: Int64 { room.roomId }
}

struct FeedWriteView: View {
    @Environment(\.dismiss) private var dismiss
    /// 24-1~24-5 단계별 캡처를 위해 시작 단계를 지정할 수 있다.
    var initialStep: Int = 1
    /// 캡처가 특정 방을 기록 대상으로 지정한다(`feedwrite1:101`). 지정이 없으면 가장 최근 여행을 고른다.
    var requestedRoomID: Int64?
    var onPublish: (FeedPost) -> Void = { _ in }

    // 제목·본문은 사용자가 쓰는 값이다. 미리 채워 두면 남의 여행기가 내 글처럼 보인다.
    @State private var title = ""
    @State private var memo = ""
    @State private var currentStep = 1
    @State private var isPublished = false
    /// 올리는 중 — 두 번 눌러 두 번 올라가지 않게 막는다.
    @State private var isPublishing = false
    /// 올리다 실패한 이유. 조용히 실패하면 올라간 것으로 착각한다.
    @State private var publishError: String?
    @State private var selectedVisibility: FeedVisibility = .friendsOnly
    /// 기록할 코스 후보 — **내가 다녀온 여행**(`ended && status == "CONFIRMED"`)만이다.
    /// 예전에는 `GET /travel-courses/public` 을 후보로 써서 내가 가지도 않은 남의 코스
    /// (`27-3 검증 코스`)가 「어떤 여행을 기록할까요?」의 후보로 떴다.
    /// 취소된 방(`CANCELLED`)은 끝난 것이지 다녀온 것이 아니다 — 후보가 아니다.
    @State private var trips: [FeedWriteTripCandidate] = []
    /// 다녀온 여행 후보 조회가 **실패**했는지. 빈 목록과 갈라야 한다.
    @State private var tripsLoadFailed = false
    @State private var selectedRoomID: Int64?
    /// 고른 방의 동행자. **아직 못 받았으면 nil** 이고 멤버 카드를 그리지 않는다 —
    /// 빈 배열(`(0)`)은 "혼자 다녀왔다"는 사실이지 "못 받았다"가 아니다 (NO-MOCK R1).
    @State private var companions: [ServerTripCompanion]?

    /// 24-2 사진 — **사용자가 고른 것만** 그린다.
    /// 예전에는 `[.sunrise, .forest, .coral]` 색 타일 3장을 미리 채워 두었다 (목데이터 · NO-MOCK R1).
    @State private var pickedPhotoItems: [PhotosPickerItem] = []
    @State private var pickedPhotos: [UIImage] = []
    private let stepCount = 5
    /// 서버에는 제목 필드가 없다 — 제목은 **본문 첫 줄**로 올려 보낸다 (BE 요청 §8-7).
    private static let titleLimit = 60
    private static let bodyLimit = 500

    /// 실제로 서버에 나가는 본문. 카운터도 입력 제한도 **이 길이**를 기준으로 삼는다 —
    /// 제목 60 + 본문 500 을 따로 세면 합이 562자가 되어 서버(`content` 500자)가 거절한다.
    /// 사용자에게는 「500자 안」으로 보이는데 게시가 실패하던 자리다 (2026-09-10).
    private var composedContent: String {
        Self.contentWithTitle(title.trimmingCharacters(in: .whitespacesAndNewlines), memo)
    }

    /// 제목이 차지한 만큼 줄어드는 본문 상한 (`제목` + 빈 줄 + `내용`).
    private var memoLimit: Int {
        let head = title.trimmingCharacters(in: .whitespacesAndNewlines).count
        return max(0, Self.bodyLimit - (head > 0 ? head + 2 : 0))
    }

    /// 고른 여행. 후보가 없으면 nil 이고 관련 섹션은 그리지 않는다.
    private var selectedTrip: FeedWriteTripCandidate? {
        trips.first { $0.id == selectedRoomID } ?? trips.first
    }

    /// 고른 여행의 코스. 서버 코스를 못 받았으면 nil 이고 관련 섹션은 그리지 않는다.
    private var course: TravelCourse? {
        selectedTrip?.course
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            progressBar

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    stepIntro
                    stepContent
                }
                // 폭을 **끝까지 늘린다**. `ScrollView` 는 내용 폭이 좁으면 가로로 가운데 놓는다 —
                // 그래서 카드가 안쪽으로 들어가고 좌우 여백이 서로 달라졌다
                // (24-4 iOS 만 좌 69pt · 우 94pt, 안드로이드는 20/20, 사용자 지적 2026-09-09).
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomCTA
        }
        .background(MoyeoTheme.background.ignoresSafeArea())
        .onAppear { currentStep = min(max(initialStep, 1), stepCount) }
        .task {
            await loadTrips()
        }
        .task(id: selectedRoomID) {
            await loadCompanions()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .accessibilityIdentifier("screen.feedWrite.step\(currentStep)")
    }
}

// MARK: - 서버 로딩 (24-1~24-5 가 같은 데이터 한 벌을 쓴다)

private extension FeedWriteView {
    /// 후보 = `GET /chat-rooms/my` 중 `ended && status == "CONFIRMED"` 인 것만.
    /// 정렬 = 종료일(없으면 시작일) 내림차순 — 가장 최근에 다녀온 여행이 먼저다.
    func loadTrips() async {
        guard MoyeoServerSync.isEnabled, trips.isEmpty else { return }
        tripsLoadFailed = false
        guard let rooms = try? await ChatRoomAPIClient.shared.myRooms() else {
            // 조회 실패를 **빈 목록으로 그리지 않는다** — 다녀온 여행이 있어도
            // 「아직 다녀온 여행 기록이 없어요.」로 읽혀 글을 못 쓰는 까닭을 알 수 없었다.
            tripsLoadFailed = true
            return
        }

        let completed = rooms.filter {
            $0.ended && $0.status == ServerMyChatRoomFilter.confirmed.rawValue
        }
        // 같은 날짜끼리는 서버가 준 순서를 지킨다 — 정렬이 흔들리면 첫 후보가 캡처마다 달라진다.
        let ordered = completed.enumerated().sorted { lhs, rhs in
            let left = lhs.element.endDate ?? lhs.element.startDate
            let right = rhs.element.endDate ?? rhs.element.startDate
            if left != right { return left > right }
            return lhs.offset < rhs.offset
        }.map(\.element)

        // 방마다 코스를 **동시에** 받는다. 순차로 돌렸을 때는 완료된 여행 수에 비례해
        // 첫 화면이 늦어졌고, 그 사이 화면은 "아직 다녀온 여행 기록이 없어요" 를 보여줬다
        // (캡처가 그 빈 화면을 찍어서 드러났다). 순서는 `ordered` 를 그대로 지킨다.
        let courses = await withTaskGroup(of: (Int, ServerRoomCourse?).self) { group in
            for (index, room) in ordered.enumerated() {
                group.addTask {
                    (index, try? await TravelCourseAPIClient.shared.roomCourse(roomID: room.roomId))
                }
            }
            var result: [Int: ServerRoomCourse?] = [:]
            for await (index, roomCourse) in group { result[index] = roomCourse }
            return result
        }
        let loaded: [FeedWriteTripCandidate] = ordered.enumerated().map { index, room in
            let roomCourse = courses[index] ?? nil
            return FeedWriteTripCandidate(
                room: room,
                roomCourse: roomCourse,
                course: roomCourse?.course.map(ServerCourseMapper.course(from:))
            )
        }

        // 지정된 방(캡처)이 다녀온 여행이면 그것을, 아니면 가장 최근 것을 연다.
        // 고른 방을 맨 앞에 둔다 — 뒤에 묻히면 가로 목록 밖으로 밀려 "아무것도 안 골랐다"로 보인다(웹과 같다).
        let picked = requestedRoomID.flatMap { id in loaded.first { $0.id == id } } ?? loaded.first
        if let picked {
            trips = [picked] + loaded.filter { $0.id != picked.id }
        } else {
            trips = loaded
        }
        selectedRoomID = picked?.id
    }

    /// 고른 방의 동행자. 완료 여행 전용 API 라 미완료 방은 `409 40915` 다 —
    /// 그때는 nil 로 두고 멤버 카드를 그리지 않는다. 사람을 지어내지 않는다.
    func loadCompanions() async {
        guard MoyeoServerSync.isEnabled, let roomID = selectedRoomID else {
            companions = nil
            return
        }
        switch await ChatRoomWriteAPIClient.shared.companions(roomID: roomID) {
        case .companions(let list):
            companions = list
        case .notCompleted, .unavailable:
            companions = nil
        }
    }
}

private extension FeedWriteView {
    var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MoyeoTheme.ink)
                    .frame(width: 40, height: 44)
            }
            .buttonStyle(.plain)
            // ENV-006: 라벨이 없으면 VoiceOver 가 영어 시스템 문구(「Close」)로 읽는다.
            .accessibilityLabel("닫기")

            Spacer()

            Text("피드 글쓰기")
                .font(.headline.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)

            Spacer()

            Button {
                publishAndDismiss()
            } label: {
                Text(isPublished ? "게시됨" : (isPublishing ? "올리는 중" : "게시"))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(currentStep >= stepCount ? MoyeoTheme.forest : MoyeoTheme.muted)
                    .frame(width: 40, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(currentStep < stepCount || isPublished || isPublishing)
            .accessibilityIdentifier("feed.write.publish")
        }
        .padding(.horizontal, 12)
        .frame(height: 58)
        .background(MoyeoTheme.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MoyeoTheme.softLine)
                .frame(height: 1)
        }
    }

    var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(1...stepCount, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep ? MoyeoTheme.forest : MoyeoTheme.softLine)
                    .frame(height: 5)
                    .opacity(index <= currentStep ? 1 : 0.85)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(MoyeoTheme.background)
    }

    var stepIntro: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(stepLabel)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(MoyeoTheme.muted)
            Text(stepTitle)
                .font(.title3.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)
            Text(stepHelper)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MoyeoTheme.muted)
        }
    }

    @ViewBuilder
    var stepContent: some View {
        switch currentStep {
        case 1:
            // 화면기획 24-1은 코스 후보 · 경로 · 함께 간 멤버 세 블록이다.
            // 코스/지역/공개 요약 행(24-4·24-5의 메타 카드)은 여기서 되풀이하지 않는다.
            // 함께 간 멤버는 `GET /chat-rooms/{roomId}/companions` 가 근거다 — 200 을 준다
            // (2026-09-02 실서버 확인). 0명이면 `(0)` 이 사실이다(방 101 은 혼자 다녀왔다).
            courseSelector
            routeCard
            membersCard
        case 2:
            photoGrid
            routeCard
        case 3:
            memoCard
            photoGrid
        case 4:
            visibilityCard
            metaCard
        default:
            memoCard
            photoGrid
            routeCard
            metaCard
        }
    }

    /// **입력은 두 칸이다** — 라벨과 구분선을 둔다.
    /// 예전에는 제목과 본문이 라벨 없이 붙어 있어 무엇을 쓰는 칸인지 알 수 없었다
    /// (사용자 지적 「제목과 내용 입력 뷰가 둘 다 있어야 하고 잘 구분되게」, 2026-09-09).
    var memoCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("제목")
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.muted)
            TextField("이번 여행을 한마디로", text: $title)
                .font(.headline.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)
                .textInputAutocapitalization(.never)
                .frame(height: 40)
                .onChange(of: title) { _, value in
                    if value.count > Self.titleLimit { title = String(value.prefix(Self.titleLimit)) }
                    // 제목이 길어지면 본문 상한이 줄어든다 — 넘친 만큼 본문도 함께 줄인다.
                    if memo.count > memoLimit { memo = String(memo.prefix(memoLimit)) }
                }
                .accessibilityIdentifier("feedWrite.title")

            Rectangle()
                .fill(MoyeoTheme.softLine)
                .frame(height: 1)
                .padding(.vertical, 6)

            Text("내용")
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.muted)
            TextEditor(text: $memo)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MoyeoTheme.text700)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 84)
                .overlay(alignment: .topLeading) {
                    if memo.isEmpty {
                        Text("여행 어땠는지 한 줄 남겨주세요.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MoyeoTheme.text400)
                            .padding(.horizontal, 5)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityIdentifier("feedWrite.memo")
                .onChange(of: memo) { _, value in
                    if value.count > memoLimit { memo = String(value.prefix(memoLimit)) }
                }

            Text("\(composedContent.count) / \(Self.bodyLimit.formatted(.number))")
                .font(.caption2.weight(.bold))
                .foregroundStyle(MoyeoTheme.text400)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(MoyeoTheme.subtleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    var photoGrid: some View {
        LazyVGrid(columns: photoColumns, spacing: 8) {
            ForEach(Array(pickedPhotos.enumerated()), id: \.offset) { index, image in
                // 결정 ⑪ — 「대표 사진」은 피드에 없는 개념이다. 서버 `FeedImage` 에는
                // `sequence` 뿐이라 대표 플래그도 썸네일 컬럼도 없다. 타일을 눌러 대표를
                // 고르는 동작도, 「대표」 배지도 두지 않는다 — **고른 순서가 곧 순서**다.
                FeedWritePhotoTile(
                    image: image,
                    accessibilityIndex: index + 1,
                    // 한 장씩 뺄 길이 **없었다** — 잘못 고르면 사진 고르기를 처음부터 다시 해야 했다 (IOS-F86).
                    onRemove: { removePhoto(at: index) }
                )
            }

            // 고른 사진이 없으면 이 타일만 남는다 — 색 타일로 자리를 채우지 않는다.
            PhotosPicker(
                selection: $pickedPhotoItems,
                maxSelectionCount: 10,
                matching: .images
            ) {
                FeedWriteAddPhotoTile()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("feed.write.addPhoto")
        }
        .onChange(of: pickedPhotoItems) { _, items in
            Task { await loadPickedPhotos(items) }
        }
    }

    /// 고른 사진을 읽어 온다. 읽지 못한 항목은 자리만 비운다 — 대체 타일을 만들지 않는다.
    func loadPickedPhotos(_ items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        pickedPhotos = images
    }

    /// 사진 한 장을 뺀다. 남은 사진의 순서는 고른 순서 그대로다 (결정 ⑪).
    func removePhoto(at index: Int) {
        guard pickedPhotos.indices.contains(index) else { return }
        pickedPhotos.remove(at: index)
        // `pickedPhotoItems` 도 같이 줄여야 `onChange` 가 다시 돌 때 뺀 장이 되살아나지 않는다.
        if pickedPhotoItems.indices.contains(index) {
            pickedPhotoItems.remove(at: index)
        }
    }

    var courseSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("기록할 코스")
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)

            if trips.isEmpty, tripsLoadFailed {
                MoyeoEmptyStateView(
                    message: MoyeoEmptyText.loadFailed,
                    onRetry: { Task { await loadTrips() } },
                    accessibilityIdentifier: "feed.write.course.failed"
                )
            } else if trips.isEmpty {
                // 문구는 웹·안드로이드와 글자 그대로 같아야 한다 — 후보는 "공개 코스"가 아니라
                // "내가 다녀온 여행"이다.
                MoyeoEmptyStateView(
                    message: "아직 다녀온 여행 기록이 없어요.",
                    accessibilityIdentifier: "feed.write.course.empty"
                )
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(trips) { candidate in
                            tripOption(candidate)
                        }
                    }
                    .padding(.trailing, 4)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    func tripOption(_ candidate: FeedWriteTripCandidate) -> some View {
        let isSelected = candidate.id == selectedTrip?.id
        // 코스 썸네일이 없으면 방 썸네일이다 — 둘 다 없으면 자리표시자를 그린다.
        let thumbnailURL = candidate.course?.thumbnailURL ?? candidate.room.thumbnailURL

        return Button {
            selectedRoomID = candidate.id
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                CachedRemoteImage(url: thumbnailURL, fallbackShape: .landscape) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    MoyeoTheme.leaf
                }
                .frame(height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(candidate.course?.title ?? candidate.room.title)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)

                Text(tripSubtitle(candidate))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.muted)
                    .lineLimit(1)

                Text(isSelected ? "선택됨" : "이 코스로 기록")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(isSelected ? .white : MoyeoTheme.forest)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(isSelected ? MoyeoTheme.forest : MoyeoTheme.leaf)
                    .clipShape(Capsule())
            }
            .padding(10)
            .frame(width: 168, alignment: .leading)
            .background(isSelected ? MoyeoTheme.leaf : MoyeoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? MoyeoTheme.forest : MoyeoTheme.softLine, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("feed.write.trip.\(candidate.id)")
    }

    /// `2026.08.28 · 당일치기` — 같은 코스로 떠난 여행 둘을 구분하는 줄이다(웹과 같은 조합).
    /// 서버가 안 준 값은 자리를 비운다.
    func tripSubtitle(_ candidate: FeedWriteTripCandidate) -> String {
        let startDate = candidate.roomCourse?.room.startDate ?? candidate.room.startDate
        let dateText = startDate.isEmpty
            ? nil
            : startDate.replacingOccurrences(of: "-", with: ".")
        let typeText = candidate.roomCourse.map {
            $0.room.tripType == "DAY_TRIP" ? TripScheduleKind.dayTrip.rawValue : "숙박"
        }
        return [dateText, typeText].compactMap { $0 }.joined(separator: " · ")
    }

    /// 24-1 함께 간 멤버 — `GET /chat-rooms/{roomId}/companions` 가 유일한 근거다.
    /// 0명이면 제목의 `(0)` 이 곧 사실이다(방 101 은 61 이 혼자 다녀왔다) — 예시 멤버를 채우지 않는다.
    /// 서버 응답에 "나"는 없어서 기획의 `(나)` 칩은 그리지 않는다.
    @ViewBuilder
    var membersCard: some View {
        if let companions {
            VStack(alignment: .leading, spacing: 10) {
                Text("함께 간 멤버 (\(companions.count))")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)

                if !companions.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(companions) { companion in
                                FeedWriteCompanionChip(companion: companion)
                            }
                        }
                        .padding(.trailing, 4)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MoyeoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(MoyeoTheme.softLine, lineWidth: 1)
            }
            .accessibilityIdentifier("feed.write.members")
        }
    }

    /// 좌표가 있는 방문지만 지도에 올린다. **2곳 미만이면 카드를 그리지 않는다**(정본 R4) —
    /// 좌표 문자열은 화면에 적지 않는다(기획에 없고 사용자에게 의미가 없다).
    var routeStops: [ItineraryStop] {
        (course?.itinerary ?? []).filter {
            MoyeoMapCoordinate(latitude: $0.latitude, longitude: $0.longitude) != nil
        }
    }

    @ViewBuilder
    var routeCard: some View {
        let stops = routeStops
        if let course, stops.count >= 2 {
            VStack(alignment: .leading, spacing: 10) {
                Text("경로 (자동)")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)

                FeedWriteRoutePreview(stops: stops)
                    .frame(height: 118)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(MoyeoTheme.brandText)
                    Text("방문지 \(stops.count)곳 · \(course.distance)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(MoyeoTheme.muted)
                }
            }
            .padding(12)
            .background(MoyeoTheme.subtleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    var metaCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let course {
                FeedWriteMetaRow(icon: "map.fill", title: "코스", value: course.title)
                FeedWriteMetaRow(
                    icon: "location.fill",
                    title: "일정",
                    value: "\(course.duration) · \(course.distance)")
            }
            FeedWriteMetaRow(icon: "eye.fill", title: "공개", value: "\(selectedVisibility.rawValue) · 경로지도 포함")

            // 함께한 멤버 수는 `GET /chat-rooms/{roomId}/companions` 응답이 근거다 —
            // 못 받았으면 줄을 두지 않는다. 사람을 지어내지 않는다.
            if let companions {
                FeedWriteMetaRow(
                    icon: "person.2.fill",
                    title: "멤버",
                    value: "함께한 멤버 \(companions.count)명"
                )
            }

            HStack(spacing: 8) {
                ForEach(metaTags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(MoyeoTheme.forest)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(MoyeoTheme.leaf)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MoyeoTheme.softLine, lineWidth: 1)
        }
    }

    var visibilityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("공개 범위")
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)

            HStack(spacing: 8) {
                ForEach(FeedVisibility.allCases, id: \.self) { visibility in
                    Button {
                        selectedVisibility = visibility
                    } label: {
                        Text(visibility.rawValue)
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(selectedVisibility == visibility ? .white : MoyeoTheme.forest)
                            .padding(.horizontal, 11)
                            .frame(height: 34)
                            .background(selectedVisibility == visibility ? MoyeoTheme.forest : MoyeoTheme.leaf)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("feed.write.visibility.\(visibility.accessibilityKey)")
                }
            }

            Text(selectedVisibility.helperText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MoyeoTheme.muted)
        }
        .padding(14)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MoyeoTheme.softLine, lineWidth: 1)
        }
    }

    var bottomCTA: some View {
        VStack(spacing: 8) {
            // 실패 문구는 **누르는 버튼 바로 위**에 둔다. 예전에는 스크롤 본문 끝에 있어
            // 게시가 실패해도 화면에 아무 변화가 없어 보였다 (IOS-F87).
            if let publishError {
                Text(publishError)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.coral)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .accessibilityIdentifier("feedWrite.publishError")
            }
            ctaRow
        }
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(MoyeoTheme.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MoyeoTheme.softLine)
                .frame(height: 1)
        }
    }

    private var ctaRow: some View {
        HStack(spacing: 14) {
            Button {
                currentStep = max(1, currentStep - 1)
            } label: {
                Text("이전")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                    .frame(width: 56, height: 50)
            }
            .buttonStyle(.plain)

            Button {
                if currentStep >= stepCount {
                    publishAndDismiss()
                } else {
                    currentStep = min(stepCount, currentStep + 1)
                }
            } label: {
                Text(nextTitle)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: MoyeoTheme.ctaHeight)
                    .background(MoyeoTheme.forest)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isPublishing || isPublished)
            .accessibilityIdentifier(currentStep >= stepCount ? "feed.write.complete" : "feed.write.next")
        }
        .padding(.horizontal, 20)
    }

    var nextTitle: String {
        if currentStep >= stepCount {
            return "게시하기"
        }
        return "다음 (\(currentStep + 1)/\(stepCount))"
    }

    var stepLabel: String {
        switch currentStep {
        case 1:
            return "STEP 1 · 코스 확인"
        case 2:
            return "STEP 2 · 사진 선택"
        case 3:
            return "STEP 3 · 사진 & 메모"
        case 4:
            return "STEP 4 · 공개 설정"
        default:
            return isPublished ? "STEP 5 · 게시 완료" : "STEP 5 · 최종 확인"
        }
    }

    var stepTitle: String {
        switch currentStep {
        case 1:
            return "어떤 여행을 기록할까요?"
        case 2:
            return "사진을 골라요"
        case 3:
            return "여행 어땠어요?"
        case 4:
            return "누구에게 보여줄까요?"
        default:
            return isPublished ? "기록이 저장됐어요" : "게시 전 마지막 확인이에요"
        }
    }

    var stepHelper: String {
        switch currentStep {
        case 1:
            return "방문 코스와 함께한 멤버를 먼저 확인해요."
        case 2:
            // 결정 ⑪ — 서버에 피드 대표 사진이 없다. 고른 순서가 곧 `sequence` 다.
            return "최대 10장까지, 고른 순서대로 보여요."
        case 3:
            return "대부분 자동으로 채워졌어요. 한 줄만 남겨주세요."
        case 4:
            // **고른 공개 범위를 따라간다.** 예전에는 「친구에게만 공개…」로 고정이라
            // 전체공개·나만 보기를 골라도 「친구에게만」이라고 적혔다 — 문구 문제가 아니라
            // **공개 범위를 틀리게 알려 주는 것**이다(사용자가 전체공개로 올리면서 친구만
            // 본다고 믿는다). 웹이 먼저 고쳤고 같은 조립 방식을 쓴다(웹 `visibilityHelper`).
            return "\(selectedVisibility.helperText) 경로와 멤버 정보를 함께 보여줘요."
        default:
            return "사진, 경로, 멤버가 한 장의 피드처럼 구성됐어요."
        }
    }

    var metaTags: [String] {
        [selectedVisibility.rawValue, "경로지도"] + (course?.tags ?? [])
    }

    var photoColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
    }

    func publishAndDismiss() {
        guard !isPublished else {
            dismiss()
            return
        }

        // 코스를 못 고른 상태에서 게시하면 코스 값을 지어내야 한다 — 그 전에는 게시하지 않는다.
        // 다만 **아무 말 없이 멈추지는 않는다** — 버튼을 눌렀는데 화면이 그대로면 고장으로 보인다.
        guard let course else {
            publishError = "여행을 먼저 고르면 게시할 수 있어요. STEP 1 로 돌아가 코스를 확인해주세요."
            return
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = memo.trimmingCharacters(in: .whitespacesAndNewlines)

        // 서버 계약을 **보내기 전에** 같은 말로 검사한다. 예전에는 검증이 없어서 사진 0장·
        // 빈 본문이 그대로 올라갔고, 화면 맨 아래에 서버 원문(「공백일 수 없습니다」)이 찍혔다
        // (TC WRITE-011·WRITE-016). 웹·안드로이드는 이미 같은 자리에서 막는다
        // (웹 `사진을 한 장 이상 골라주세요.` · 안드 `사진을 최소 한 장 골라 주세요.`).
        //
        // 근거: `CreateFeedRequest.content` 는 `@NotBlank @Size(max = 500)` 이고,
        // 사진은 `images` 파트로 최소 1장이 필요하다.
        guard !pickedPhotos.isEmpty else {
            publishError = "사진을 한 장 이상 골라주세요."
            return
        }
        let serverContent = Self.contentWithTitle(trimmedTitle, body)
        guard !serverContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // 문구는 2026-09-14 결정 ⑧ 정본 그대로다 — 세 플랫폼이 같은 문장을 쓴다.
            publishError = "제목이나 내용 중 하나는 써 주세요."
            return
        }
        guard serverContent.count <= Self.bodyLimit else {
            publishError = "본문은 \(Self.bodyLimit)자까지 올릴 수 있어요. "
                + "지금 \(serverContent.count)자예요."
            return
        }

        let post = FeedPost(
            id: "feed-local-\(UUID().uuidString)",
            authorName: "",
            authorAvatar: "",
            region: course.region,
            createdAt: "방금",
            photoMascot: course.mascot,
            caption: body,
            tags: Array((["여행기록"] + course.tags).prefix(4)),
            route: course.stops,
            visibility: selectedVisibility,
            likeCount: 0,
            commentCount: 0,
            mood: course.mood,
            title: trimmedTitle.isEmpty ? course.title : trimmedTitle,
            subtitle: "#여행기록 #\(selectedVisibility.rawValue)",
            detailBody: body,
            distanceText: course.distance,
            durationText: course.duration,
            visitCountText: "\(course.stops.count)곳",
            // 사진이 없으면 `1/0` 같은 배지를 만들지 않는다.
            photoCountText: pickedPhotos.isEmpty ? "" : "사진 \(pickedPhotos.count)장"
        )

        // **서버에 올린다.** 예전에는 이 자리에서 화면 안 목록에만 끼워 넣고 끝냈다 —
        // 앱을 다시 켜면 사라지고 웹·안드로이드에서도 보이지 않았다 (2026-09-09 발견).
        // 웹 `createFeed` · 안드 `FeedRepository.createFeed` 와 같은 엔드포인트를 쓴다.
        guard MoyeoServerSync.isEnabled, let roomID = selectedTrip?.room.roomId else {
            // 미로그인·목데이터 상태에서는 올릴 곳이 없다 — 화면 안 목록만 갱신한다.
            isPublished = true
            onPublish(post)
            dismiss()
            return
        }
        isPublishing = true
        // 다시 누르면 옛 실패 문구부터 지운다 — 원인을 고쳐도 남아 있으면 또 실패한 줄 안다.
        publishError = nil
        Task {
            defer { isPublishing = false }
            do {
                _ = try await FeedAPIClient.shared.createFeed(
                    chatRoomID: roomID,
                    content: Self.contentWithTitle(trimmedTitle, body),
                    visibility: selectedVisibility.serverValue,
                    images: Self.multipartImages(from: pickedPhotos)
                )
            } catch {
                publishError = error.moyeoUserMessage(
                    fallback: "여행기록을 올리지 못했어요. 잠시 후 다시 시도해주세요."
                )
                return
            }
            isPublished = true
            onPublish(post)
            dismiss()
        }
    }

    /// 제목이 있으면 본문 첫 줄로 올려 보낸다 — 서버에 제목 필드가 없다 (BE §8-7).
    private static func contentWithTitle(_ title: String, _ body: String) -> String {
        guard !title.isEmpty else { return body }
        return body.isEmpty ? title : "\(title)\n\n\(body)"
    }

    /// 고른 사진을 서버가 받는 `images` 파트로 만든다. JPEG 0.85 는 20MB 상한 안에 넉넉히 든다.
    private static func multipartImages(from images: [UIImage]) -> [MoyeoMultipartFile] {
        images.enumerated().compactMap { index, image in
            guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
            return MoyeoMultipartFile(
                partName: "images",
                fileName: "feed-\(index + 1).jpg",
                mimeType: "image/jpeg",
                data: data
            )
        }
    }
}

private extension FeedVisibility {
    /// 서버 `visibility` 값. 웹·안드로이드와 같은 문자열이다.
    var serverValue: String {
        switch self {
        case .publicAll: "PUBLIC"
        case .friendsOnly: "FRIENDS"
        case .privateOnly: "PRIVATE"
        }
    }
}

private extension FeedVisibility {
    var accessibilityKey: String {
        switch self {
        case .publicAll:
            return "public"
        case .friendsOnly:
            return "friends"
        case .privateOnly:
            return "private"
        }
    }

    var helperText: String {
        switch self {
        case .publicAll:
            return "발견 탭에서도 보이고, 경북 여행자 누구나 볼 수 있어요."
        case .friendsOnly:
            return "서로 친구인 사람에게만 보여요. 기본값이에요."
        case .privateOnly:
            return "나만 볼 수 있는 기록으로 저장돼요."
        }
    }
}

private struct FeedWritePhotoTile: View {
    /// 사용자가 고른 실제 사진.
    let image: UIImage
    let accessibilityIndex: Int
    var onRemove: (() -> Void)?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 110)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.black.opacity(0.45))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .accessibilityLabel("피드 사진 \(accessibilityIndex) 빼기")
                .accessibilityIdentifier("feed.write.removePhoto.\(accessibilityIndex)")
            }
        }
        .frame(height: 110)
        .accessibilityLabel("피드 사진 \(accessibilityIndex)")
    }
}

private struct FeedWriteAddPhotoTile: View {
    var body: some View {
        VStack(spacing: 6) {
            // ENV-006: 옆의 「사진 추가」 글자가 이미 뜻을 준다 —
            // 숨기지 않으면 VoiceOver 가 심볼 이름(「plus」)을 덧붙여 읽는다.
            Image(systemName: "plus")
                .font(.caption.weight(.heavy))
                .accessibilityHidden(true)
            Text("사진 추가")
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(MoyeoTheme.muted)
        .frame(maxWidth: .infinity)
        .frame(height: 110)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(MoyeoTheme.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        .accessibilityLabel("사진 추가")
    }
}

/// 24-1 함께 간 멤버 칩. 프로필 이미지가 없으면 닉네임에서 계산한 동물 이모지를 쓴다 —
/// 표는 `MoyeoNicknameAnimal` 하나뿐이다 (NO-MOCK R5).
private struct FeedWriteCompanionChip: View {
    let companion: ServerTripCompanion

    var body: some View {
        HStack(spacing: 6) {
            avatar
            Text(companion.nickname)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MoyeoTheme.text700)
                .lineLimit(1)
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .frame(height: 36)
        .background(MoyeoTheme.subtleBackground)
        .clipShape(Capsule())
        .accessibilityLabel("함께 간 멤버 \(companion.nickname)")
    }

    @ViewBuilder
    private var avatar: some View {
        if let url = companion.profileImageURL {
            CachedRemoteImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                MoyeoTheme.leaf
            }
            .frame(width: 24, height: 24)
            .clipShape(Circle())
        } else {
            MascotAvatar(
                mascot: MoyeoNicknameAnimal.emoji(forNickname: companion.nickname)
                    ?? MoyeoNicknameAnimal.unknown,
                size: 24,
                background: MoyeoTheme.leaf
            )
        }
    }
}

/// 24 경로 미리보기 — 방문지 좌표로 실제 카카오 지도를 그린다 (NO-MOCK-CANON R4).
private struct FeedWriteRoutePreview: View {
    let stops: [ItineraryStop]

    private var routeMarkers: [MoyeoMapMarker] {
        stops.compactMap { stop in
            guard let coordinate = MoyeoMapCoordinate(latitude: stop.latitude, longitude: stop.longitude) else {
                return nil
            }
            return MoyeoMapMarker(id: stop.id, coordinate: coordinate, order: stop.order)
        }
    }

    var body: some View {
        let markers = routeMarkers
        if markers.count == stops.count, let first = markers.first {
            MoyeoMapView(
                content: MoyeoMapContent(
                    center: first.coordinate,
                    level: 11,
                    markers: markers,
                    polyline: markers.map(\.coordinate)
                ),
                isInteractive: false,
                fallback: { MoyeoMapUnavailableView(message: "지도를 불러오지 못했어요.") }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("여행 경로 지도, 방문지 \(stops.count)곳")
        }
    }
}

private struct FeedWriteMetaRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.forest)
                .frame(width: 24, height: 24)
                .background(MoyeoTheme.leaf)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.muted)
                Text(value)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
    }
}
