import SwiftUI
import UIKit

actor MoyeoImageRepository {
    static let shared = MoyeoImageRepository()
    static let maximumAttempts = 3

    /// 메모리 캐시. **상한을 반드시 준다** — 안 주면 시스템 판단에만 의존해
    /// 사진이 많은 화면을 오래 돌 때 메모리 압박이 커진다.
    /// 안드로이드가 `LruCache(24MB)` 를 쓰므로 같은 값으로 맞춘다.
    private let memoryCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 24 * 1024 * 1024
        return cache
    }()
    private let session: URLSession
    private let cacheDirectory: URL
    private var inFlight: [String: Task<UIImage, Error>] = [:]

    init(session: URLSession = .shared, cacheDirectory: URL? = nil) {
        self.session = session
        let baseDirectory = cacheDirectory ?? FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("MoyeoImages", isDirectory: true)
        self.cacheDirectory = baseDirectory
        try? FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )
    }

    /// NSCache 의 비용 단위 — 대략의 바이트 수다.
    /// 이 값을 넘기지 않으면 `totalCostLimit` 이 **아무 일도 하지 않는다**(모든 항목의 비용이 0).
    nonisolated private static func memoryCost(of image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }

    nonisolated static func cacheKey(for url: URL) -> String {
        let decodedName = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        let source = decodedName.isEmpty ? "image" : decodedName
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let scalars = source.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "_" }
        return String(scalars)
    }

    func image(for url: URL) async throws -> UIImage {
        let key = Self.cacheKey(for: url)
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }

        let fileURL = cacheDirectory.appendingPathComponent(key, isDirectory: false)
        if let data = try? Data(contentsOf: fileURL), let cached = UIImage(data: data) {
            memoryCache.setObject(cached, forKey: key as NSString, cost: Self.memoryCost(of: cached))
            return cached
        }

        if let task = inFlight[key] {
            return try await task.value
        }

        let task = Task<UIImage, Error> {
            var lastError: Error = URLError(.cannotDecodeContentData)
            for attempt in 1...Self.maximumAttempts {
                do {
                    var request = URLRequest(url: url)
                    request.cachePolicy = .returnCacheDataElseLoad
                    request.timeoutInterval = 30
                    let (data, response) = try await session.data(for: request)
                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode),
                          let image = UIImage(data: data) else {
                        throw URLError(.cannotDecodeContentData)
                    }
                    try? data.write(to: fileURL, options: .atomic)
                    return image
                } catch {
                    lastError = error
                    if attempt < Self.maximumAttempts {
                        try? await Task.sleep(for: .milliseconds(300 * attempt))
                    }
                }
            }
            throw lastError
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }

        let loaded = try await task.value
        memoryCache.setObject(loaded, forKey: key as NSString, cost: Self.memoryCost(of: loaded))
        return loaded
    }
}

struct CachedRemoteImage<Content: View, Placeholder: View>: View {
    let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    /// 이미지가 **필수인 자리**에서 URL 이 없거나 내려받기가 실패했을 때 대신 그릴 마스코트 에셋의 비율.
    ///
    /// `nil` 이면 기존처럼 `placeholder` 를 그린다 — 아바타처럼 닉네임에서 유도한 대체 표시가
    /// 이미 있는 자리는 그 편이 더 낫다.
    private let fallbackShape: MoyeoPlaceholderImage.Shape?

    @State private var loadedImage: UIImage?
    @State private var loadFailed = false

    init(
        url: URL?,
        fallbackShape: MoyeoPlaceholderImage.Shape? = nil,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.fallbackShape = fallbackShape
        self.content = content
        self.placeholder = placeholder
    }

    /// 로딩 중과 "이미지가 없음"을 구분한다.
    /// 로딩 중에는 `placeholder`(스켈레톤·그라디언트)를 두고, 없거나 실패한 뒤에만 마스코트를 그린다.
    /// 로딩 중에 마스코트를 먼저 보여주면 사진이 뒤늦게 갈리며 화면이 튄다.
    private var showsFallback: Bool {
        guard fallbackShape != nil else { return false }
        return url == nil || loadFailed
    }

    var body: some View {
        Group {
            if let loadedImage {
                content(Image(uiImage: loadedImage))
            } else if let fallbackShape, showsFallback {
                // 호출부의 resizable·scaledToFill·clipShape 가 그대로 적용되도록 content 로 넘긴다.
                content(Image(MoyeoPlaceholderImage.assetName(for: fallbackShape)))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            loadedImage = nil
            loadFailed = false
            guard let url else { return }
            do {
                loadedImage = try await MoyeoImageRepository.shared.image(for: url)
            } catch {
                // 실패를 조용히 넘기지 않는다 — 이 자리는 마스코트로 채워야 한다.
                loadFailed = true
            }
        }
    }
}
