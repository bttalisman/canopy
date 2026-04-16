import SwiftUI

/// A drop-in replacement for AsyncImage that caches images in memory and on disk.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: UIImage?

    var body: some View {
        if let image {
            content(Image(uiImage: image))
        } else {
            placeholder()
                .task {
                    self.image = await ImageCache.shared.load(url: url)
                }
        }
    }
}

extension CachedAsyncImage where Placeholder == ProgressView<EmptyView, EmptyView> {
    init(url: URL, @ViewBuilder content: @escaping (Image) -> Content) {
        self.url = url
        self.content = content
        self.placeholder = { ProgressView() }
    }
}

actor ImageCache {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCacheURL: URL

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = caches.appendingPathComponent("ImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }

    func load(url: URL) async -> UIImage? {
        let key = cacheKey(for: url)

        // 1. Memory cache
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }

        // 2. Disk cache
        let diskPath = diskCacheURL.appendingPathComponent(key)
        if let data = try? Data(contentsOf: diskPath), let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: key as NSString, cost: data.count)
            return image
        }

        // 3. Network
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let image = UIImage(data: data) else { return nil }

            memoryCache.setObject(image, forKey: key as NSString, cost: data.count)
            try? data.write(to: diskPath)
            return image
        } catch {
            return nil
        }
    }

    private func cacheKey(for url: URL) -> String {
        // SHA256-like hash from the URL string
        let str = url.absoluteString
        var hash: UInt64 = 5381
        for char in str.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(char)
        }
        return String(hash, radix: 16)
    }
}
