import SwiftUI
import UIKit

actor MoyeoImageRepository {
    static let shared = MoyeoImageRepository()
    static let maximumAttempts = 3

    private let memoryCache = NSCache<NSString, UIImage>()
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
            memoryCache.setObject(cached, forKey: key as NSString)
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
        memoryCache.setObject(loaded, forKey: key as NSString)
        return loaded
    }
}

struct CachedRemoteImage<Content: View, Placeholder: View>: View {
    let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage?

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let loadedImage {
                content(Image(uiImage: loadedImage))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            loadedImage = nil
            guard let url else { return }
            loadedImage = try? await MoyeoImageRepository.shared.image(for: url)
        }
    }
}
