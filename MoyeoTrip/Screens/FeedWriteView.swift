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
    @State private var selectedCoverIndex = 0
    @State private var currentStep = 1
    @State private var isPublished = false
    @State private var selectedVisibility: FeedVisibility = .friendsOnly
    /// 기록할 코스 후보 — **내가 다녀온 여행**(`ended && status == "CONFIRMED"`)만이다.
    /// 예전에는 `GET /travel-courses/public` 을 후보로 써서 내가 가지도 않은 남의 코스
    /// (`27-3 검증 코스`)가 「어떤 여행을 기록할까요?」의 후보로 떴다.
    /// 취소된 방(`CANCELLED`)은 끝난 것이지 다녀온 것이 아니다 — 후보가 아니다.
    @State private var trips: [FeedWriteTripCandidate] = []
    @State private var selectedRoomID: Int64?
    /// 고른 방의 동행자. **아직 못 받았으면 nil** 이고 멤버 카드를 그리지 않는다 —
    /// 빈 배열(`(0)`)은 "혼자 다녀왔다"는 사실이지 "못 받았다"가 아니다 (NO-MOCK R1).
    @State private var companions: [ServerTripCompanion]?

    /// 24-2 사진 — **사용자가 고른 것만** 그린다.
    /// 예전에는 `[.sunrise, .forest, .coral]` 색 타일 3장을 미리 채워 두었다 (목데이터 · NO-MOCK R1).
    @State private var pickedPhotoItems: [PhotosPickerItem] = []
    @State private var pickedPhotos: [UIImage] = []
    private let stepCount = 5

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
        guard let rooms = try? await ChatRoomAPIClient.shared.myRooms() else { return }

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

            Spacer()

            Text("피드 글쓰기")
                .font(.headline.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)

            Spacer()

            Button {
                publishAndDismiss()
            } label: {
                Text(isPublished ? "게시됨" : "게시")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(currentStep >= stepCount ? MoyeoTheme.forest : MoyeoTheme.muted)
                    .frame(width: 40, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(currentStep < stepCount || isPublished)
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

    var memoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("제목", text: $title)
                .font(.headline.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)
                .textInputAutocapitalization(.never)

            TextEditor(text: $memo)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MoyeoTheme.text700)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 84)

            Text("\(min(memo.count, 500)) / 500")
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
                FeedWritePhotoTile(
                    image: image,
                    isSelectedCover: selectedCoverIndex == index,
                    accessibilityIndex: index + 1
                )
                .onTapGesture {
                    selectedCoverIndex = index
                }
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
        selectedCoverIndex = min(selectedCoverIndex, max(images.count - 1, 0))
    }

    var courseSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("기록할 코스")
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)

            if trips.isEmpty {
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
                    .frame(height: 50)
                    .background(MoyeoTheme.forest)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(currentStep >= stepCount ? "feed.write.complete" : "feed.write.next")
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(MoyeoTheme.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MoyeoTheme.softLine)
                .frame(height: 1)
        }
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
            return "대표 사진을 골라요"
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
            return "사진과 지도 조합이 피드 첫 화면에 함께 보여요."
        case 3:
            return "대부분 자동으로 채워졌어요. 한 줄만 남겨주세요."
        case 4:
            return "친구에게만 공개하고 경로와 멤버 정보를 함께 보여줘요."
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
        guard let course else { return }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = memo.trimmingCharacters(in: .whitespacesAndNewlines)
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
            photoCountText: pickedPhotos.isEmpty ? "" : "1/\(pickedPhotos.count)"
        )

        isPublished = true
        onPublish(post)
        dismiss()
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
    let isSelectedCover: Bool
    let accessibilityIndex: Int

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 110)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if isSelectedCover {
                Text("대표")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .frame(height: 20)
                    .background(MoyeoTheme.forest)
                    .clipShape(Capsule())
                    .padding(7)
            }
        }
        .accessibilityLabel("피드 사진 \(accessibilityIndex)")
    }
}

private struct FeedWriteAddPhotoTile: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.caption.weight(.heavy))
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
                fallback: { MoyeoTheme.mapGreen }
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
