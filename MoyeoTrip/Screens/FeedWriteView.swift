//
//  FeedWriteView.swift
//  MoyeoTrip
//

// swiftlint:disable file_length

import SwiftUI

struct FeedWriteView: View {
    @Environment(\.dismiss) private var dismiss
    /// 24-1~24-5 단계별 캡처를 위해 시작 단계를 지정할 수 있다.
    var initialStep: Int = 1
    var onPublish: (FeedPost) -> Void = { _ in }

    @State private var title = "첫 반패키지 단풍 여행"
    // 본문은 기획·웹·안드로이드와 같은 한 문단이다 (카운터는 본문 글자수만 센다)
    @State private var memo = "처음 반패키지 여행이었는데 동행분들이 너무 좋으셨어요. 첨성대 야경이 진짜 인생샷..."
    @State private var selectedCoverIndex = 0
    @State private var currentStep = 1
    @State private var isPublished = false
    @State private var selectedVisibility: FeedVisibility = .friendsOnly
    // 화면기획 24-1은 경주 감성 힐링 코스가 선택된 상태에서 시작한다 (두 번째 후보가 주왕산)
    @State private var selectedCourseID = FeedWriteCourseCandidate.planning[0].id

    private let photos: [CourseMood] = [.sunrise, .forest, .coral]
    private let stepCount = 5

    private var candidate: FeedWriteCourseCandidate {
        FeedWriteCourseCandidate.planning.first { $0.id == selectedCourseID }
            ?? FeedWriteCourseCandidate.planning[0]
    }

    private var course: TravelCourse {
        MockData.course(for: selectedCourseID) ?? MockData.courses[0]
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
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .accessibilityIdentifier("screen.feedWrite.step\(currentStep)")
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
            ForEach(Array(photos.enumerated()), id: \.offset) { index, mood in
                FeedWritePhotoTile(
                    mood: mood,
                    isSelectedCover: selectedCoverIndex == index,
                    accessibilityIndex: index + 1
                )
                .onTapGesture {
                    selectedCoverIndex = index
                }
            }

            FeedWriteAddPhotoTile()
        }
    }

    var courseSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("기록할 코스")
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(FeedWriteCourseCandidate.planning) { option in
                        courseOption(option)
                    }
                }
                .padding(.trailing, 4)
            }
            .scrollIndicators(.hidden)
        }
    }

    func courseOption(_ candidate: FeedWriteCourseCandidate) -> some View {
        let isSelected = candidate.id == selectedCourseID

        return Button {
            selectedCourseID = candidate.id
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                MoyeoPhotoTile(
                    mascot: candidate.mascot,
                    mood: candidate.mood,
                    height: 66,
                    cornerRadius: 10
                )

                Text(candidate.title)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)

                Text("\(candidate.region) · \(candidate.scheduleText)")
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
        .accessibilityIdentifier("feed.write.course.\(candidate.id)")
    }

    var routeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("경로 (자동)")
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.ink)

            FeedWriteRoutePreview(stops: course.stops)
                .frame(height: 118)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 4) {
                Image(systemName: "mappin")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(MoyeoTheme.brandText)
                Text(candidate.routeMetaText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MoyeoTheme.muted)
            }
        }
        .padding(12)
        .background(MoyeoTheme.subtleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    var metaCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            FeedWriteMetaRow(icon: "map.fill", title: "코스", value: candidate.title)
            FeedWriteMetaRow(
                icon: "location.fill",
                title: "지역",
                value: "\(candidate.region) · \(candidate.scheduleText) · \(candidate.distanceText)")
            FeedWriteMetaRow(icon: "eye.fill", title: "공개", value: "\(selectedVisibility.rawValue) · 경로지도 포함")

            HStack(spacing: 12) {
                ParticipantStack(participants: Array(MockData.participants.prefix(3)), size: 28)
                Text("함께한 멤버 3명")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(MoyeoTheme.ink)
                Spacer()
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

    /// 화면기획 24-1 — 함께 간 멤버 (4). 첫 칩이 나(따스한 사슴 3492)다.
    var membersCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("함께 간 멤버 (\(FeedWriteView.companions.count))")
                .font(.caption.weight(.heavy))
                .foregroundStyle(MoyeoTheme.text700)

            FlexibleChipRows(items: FeedWriteView.companions) { companion in
                HStack(spacing: 6) {
                    MascotAvatar(mascot: companion.avatar, size: 24, background: MoyeoTheme.card)
                    Text(companion.isMe ? "\(companion.name) (나)" : companion.name)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(companion.isMe ? MoyeoTheme.onLeaf : MoyeoTheme.text700)
                }
                .padding(.leading, 6)
                .padding(.trailing, 10)
                .frame(height: 36)
                .background(companion.isMe ? MoyeoTheme.primary100 : MoyeoTheme.subtleBackground)
                .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(MoyeoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MoyeoTheme.softLine, lineWidth: 1)
        }
        .accessibilityIdentifier("feed.write.members")
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
        [selectedVisibility.rawValue, "경로지도", candidate.region] + candidate.tags
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

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMemo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = trimmedMemo.isEmpty ? "경북 여행의 좋은 순간을 기록했어요." : trimmedMemo
        let post = FeedPost(
            id: "feed-local-\(UUID().uuidString)",
            authorName: MockData.profile.name,
            authorAvatar: MockData.profile.avatar,
            region: course.region,
            createdAt: "방금",
            photoMascot: course.mascot,
            caption: body,
            tags: Array((["여행기록", course.region] + course.tags).prefix(4)),
            route: course.stops,
            visibility: selectedVisibility,
            likeCount: 0,
            commentCount: 0,
            mood: course.mood,
            title: trimmedTitle.isEmpty ? course.title : trimmedTitle,
            subtitle: "#여행기록 #\(course.region) #\(selectedVisibility.rawValue)",
            detailBody: body,
            distanceText: course.distance,
            durationText: course.duration,
            visitCountText: "\(course.stops.count)곳",
            photoCountText: "1/\(photos.count)"
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

/// 화면기획 24-1 코스 후보. 기획 목데이터는 코스 이름 · 지역 · 일정 유형 ·
/// 경로 거리와 태그를 직접 갖고 있어서, 탐색용 코스 목록과 값이 다르다.
struct FeedWriteCourseCandidate: Identifiable, Hashable {
    let id: String
    let title: String
    let region: String
    let scheduleText: String
    let distanceText: String
    let stopCount: Int
    let dateRangeText: String
    let tags: [String]
    let mascot: String
    let mood: CourseMood

    var routeMetaText: String {
        "\(region) · \(stopCount) stops · \(dateRangeText)"
    }

    static let planning: [FeedWriteCourseCandidate] = [
        FeedWriteCourseCandidate(
            id: "course-gyeongju-history",
            title: "경주 감성 힐링 코스",
            region: "경주",
            scheduleText: "1박 2일",
            distanceText: "42.6km",
            stopCount: 4,
            dateRangeText: "11/8 ~ 11/9",
            tags: ["힐링", "야경"],
            mascot: "🌙",
            mood: .coral
        ),
        FeedWriteCourseCandidate(
            id: "course-cheongsong-juwangsan",
            title: "주왕산 & 주산지 힐링 트레킹",
            region: "청송",
            scheduleText: "당일치기",
            distanceText: "6.2km",
            stopCount: 3,
            dateRangeText: "5/25",
            tags: ["자연", "히든명소"],
            mascot: "🌲",
            mood: .forest
        ),
        FeedWriteCourseCandidate(
            id: "course-andong-hahoe",
            title: "안동 하회마을 하루 코스",
            region: "안동",
            scheduleText: "당일치기",
            distanceText: "8.1km",
            stopCount: 4,
            dateRangeText: "6/9",
            tags: ["역사", "문화"],
            mascot: "🏡",
            mood: .sunrise
        )
    ]
}

struct FeedWriteCompanion: Identifiable, Hashable {
    let id: String
    let name: String
    let avatar: String
    var isMe = false
}

extension FeedWriteView {
    /// 화면기획 24-1 함께 간 멤버 4명
    static let companions: [FeedWriteCompanion] = [
        FeedWriteCompanion(id: "me", name: "따스한 사슴 3492", avatar: "🦌", isMe: true),
        FeedWriteCompanion(id: "bear", name: "우직한 곰 7821", avatar: "🐻"),
        FeedWriteCompanion(id: "turtle", name: "잔잔한 거북이 9032", avatar: "🐢"),
        FeedWriteCompanion(id: "crane", name: "고요한 두루미 1130", avatar: "🪽")
    ]
}

/// 칩이 한 줄을 넘으면 다음 줄로 흐르게 감싼다 (화면기획의 flex-wrap)
private struct FlexibleChipRows<Item: Identifiable, Content: View>: View {
    let items: [Item]
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row) { item in
                        content(item)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var rows: [[Item]] {
        stride(from: 0, to: items.count, by: 2).map { start in
            Array(items[start..<min(start + 2, items.count)])
        }
    }
}

private struct FeedWritePhotoTile: View {
    let mood: CourseMood
    let isSelectedCover: Bool
    let accessibilityIndex: Int

    var body: some View {
        ZStack(alignment: .topLeading) {
            MoyeoPhotoTile(mascot: "", mood: mood, height: 110, cornerRadius: 10)

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

private struct FeedWriteRoutePreview: View {
    let stops: [String]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let points = routePoints(in: size)

            ZStack {
                LinearGradient(
                    colors: [MoyeoTheme.mapGreen, MoyeoTheme.mapWater],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                ForEach(0..<5, id: \.self) { index in
                    Path { path in
                        let y = size.height * (0.24 + CGFloat(index) * 0.13)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addCurve(
                            to: CGPoint(x: size.width, y: y + 18),
                            control1: CGPoint(x: size.width * 0.28, y: y - 20),
                            control2: CGPoint(x: size.width * 0.64, y: y + 28)
                        )
                    }
                    .stroke(MoyeoTheme.softLine, lineWidth: 1)
                }

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(MoyeoTheme.forest, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    Text("\(index + 1)")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(MoyeoTheme.forest))
                        .overlay(Circle().stroke(MoyeoTheme.card, lineWidth: 3))
                        .position(point)
                }
            }
        }
        .accessibilityLabel("자동 생성된 여행 경로 \(stops.joined(separator: ", "))")
    }

    private func routePoints(in size: CGSize) -> [CGPoint] {
        [
            CGPoint(x: size.width * 0.17, y: size.height * 0.74),
            CGPoint(x: size.width * 0.40, y: size.height * 0.58),
            CGPoint(x: size.width * 0.67, y: size.height * 0.45),
            CGPoint(x: size.width * 0.83, y: size.height * 0.24)
        ]
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
