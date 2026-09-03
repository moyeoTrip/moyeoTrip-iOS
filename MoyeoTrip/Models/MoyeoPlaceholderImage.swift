import Foundation
import SwiftUI
import UIKit

/// 이미지가 필수인 자리에 실제 이미지가 없을 때 쓰는 공용 플레이스홀더.
///
/// 관광 데이터는 이미지가 간헐적으로 비어 있는데(한국관광공사 원본에 없는 콘텐츠가 있다),
/// 화면기획은 이미지가 항상 있다고 보고 그려져 있다. 빈 자리를 그대로 두면 레이아웃이 깨지므로
/// 마스코트 일러스트를 대신 넣는다. 관광지가 아니어도 이미지가 필수인 뷰에 같이 쓴다.
///
/// - `square`: 1:1 — 목록 썸네일, 정사각 프레임
/// - `landscape`: 16:9 — 상세 상단 히어로, 카드형 커버
///
/// 에셋은 HEIC 다(앱·웹은 HEIC/WEBP, 원본은 화면기획에 둔다).
enum MoyeoPlaceholderImage {
    /// 1:1 자리. 목록 썸네일·정사각 프레임.
    static let squareAssetName = "PlaceholderSquare"
    /// 16:9 자리. 상세 히어로·카드 커버.
    static let landscapeAssetName = "PlaceholderLandscape"

    /// 비율에 맞는 에셋 이름. 뷰에서 `Image(MoyeoPlaceholderImage.assetName(for:))` 로 쓴다.
    static func assetName(for shape: Shape) -> String {
        switch shape {
        case .square: return squareAssetName
        case .landscape: return landscapeAssetName
        }
    }

    enum Shape {
        case square
        case landscape

        /// 자리의 가로세로 비에서 가까운 쪽을 고른다. `scaledToFill` 로 잘리는 양을 줄인다.
        static func nearest(width: CGFloat, height: CGFloat) -> Shape {
            guard height > 0 else { return .landscape }
            let ratio = width / height
            return abs(ratio - 1.0) <= abs(ratio - 16.0 / 9.0) ? .square : .landscape
        }
    }

    /// 채팅방 생성에 올리는 기본 썸네일.
    ///
    /// 2026-08-26 서버 변경으로 `POST /chat-rooms` 의 `thumbnail` 파트가 필수다(없으면 400 `40041`,
    /// 이미지가 아니거나 20MB 초과면 400 `40042`). 서버가 저장 전에 비율 유지 FHD 축소 + WebP 변환을
    /// 직접 하므로(2026-08-29 안내) 클라에서 리사이즈·변환하지 않는다.
    /// 17 모집 만들기에 사진 선택 단계가 없어서 이 이미지를 올린다. 카드형 목록에 쓰이므로 16:9 다.
    ///
    /// JPEG 로 인코딩해 보낸다 — 서버는 PNG·WebP·HEIC·JPEG 를 모두 받지만(실서버 확인),
    /// `UIImage` 에서 바로 얻을 수 있고 어느 백엔드에서나 안전한 포맷이 JPEG 다.
    /// 에셋이 없으면 `nil` 을 돌려주고 서버가 400 으로 알려주게 둔다 — 조용히 성공한 척하지 않는다.
    static func roomThumbnail() -> MoyeoMultipartFile? {
        guard
            let image = UIImage(named: landscapeAssetName),
            let data = image.jpegData(compressionQuality: 0.85)
        else {
            return nil
        }
        return MoyeoMultipartFile(
            partName: "thumbnail",
            fileName: "placeholder-landscape.jpg",
            mimeType: "image/jpeg",
            data: data
        )
    }
}

/// URL 이 아예 없는 자리에 바로 그리는 플레이스홀더.
///
/// `CachedRemoteImage(fallbackShape:)` 는 "받아봤더니 실패" 를 덮는다. 이 뷰는 URL 자체가 없어
/// 요청을 보낼 것도 없는 자리(서버가 썸네일을 안 준 모임·코스·피드)에 쓴다.
/// 이전에는 이런 자리에 `MoyeoTheme.leaf` 빈 판을 뒀는데, 화면기획은 사진이 있다고 보고 그려져 있다.
struct MoyeoPlaceholderImageView: View {
    let shape: MoyeoPlaceholderImage.Shape

    var body: some View {
        Image(MoyeoPlaceholderImage.assetName(for: shape))
            .resizable()
            .scaledToFill()
    }
}
