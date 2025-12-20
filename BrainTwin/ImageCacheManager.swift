import UIKit
import SwiftUI
import Combine
import os

@MainActor
class ImageCacheManager: ObservableObject {
    static let shared = ImageCacheManager()

    private let cache = NSCache<NSString, UIImage>()
    @Published private(set) var cachedImages: [String: UIImage] = [:]

    private init() {
        cache.countLimit = 20  // Cache up to 20 images
        cache.totalCostLimit = 50 * 1024 * 1024  // 50 MB limit
    }

    /// Pre-fetch and cache an image from URL
    func prefetchImage(from urlString: String) async {
        // Check if already cached
        if let cachedImage = cache.object(forKey: urlString as NSString) {
            cachedImages[urlString] = cachedImage
            print("✅ [ImageCache] Image already cached: \(urlString)")
            return
        }

        guard let url = URL(string: urlString) else {
            print("❌ [ImageCache] Invalid URL: \(urlString)")
            return
        }

        print("📥 [ImageCache] Downloading image: \(urlString)")

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            guard let image = UIImage(data: data) else {
                print("❌ [ImageCache] Failed to decode image from data")
                return
            }

            // Cache the image
            cache.setObject(image, forKey: urlString as NSString)
            cachedImages[urlString] = image

            print("✅ [ImageCache] Image cached successfully (\(data.count) bytes)")
        } catch {
            print("❌ [ImageCache] Download failed: \(error)")
        }
    }

    /// Get cached image synchronously (returns nil if not cached)
    func getCachedImage(for urlString: String) -> UIImage? {
        // Check published dictionary first (for SwiftUI reactivity)
        if let image = cachedImages[urlString] {
            return image
        }

        // Check NSCache
        if let image = cache.object(forKey: urlString as NSString) {
            cachedImages[urlString] = image  // Sync to published dict
            return image
        }

        return nil
    }

    /// Clear all cached images
    func clearCache() {
        cache.removeAllObjects()
        cachedImages.removeAll()
        print("🗑️ [ImageCache] Cache cleared")
    }
}

/// SwiftUI View for displaying cached images
struct CachedAsyncImage: View {
    let url: String
    let placeholder: AnyView

    @StateObject private var cacheManager = ImageCacheManager.shared
    @State private var image: UIImage?

    init(url: String, @ViewBuilder placeholder: () -> some View) {
        self.url = url
        self.placeholder = AnyView(placeholder())
    }

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
            } else {
                placeholder
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: cacheManager.cachedImages[url]) { newImage in
            if let newImage = newImage {
                image = newImage
            }
        }
    }

    private func loadImage() {
        // Try to get cached image immediately
        if let cachedImage = cacheManager.getCachedImage(for: url) {
            image = cachedImage
            return
        }

        // If not cached, try to fetch it
        Task {
            await cacheManager.prefetchImage(from: url)
            if let cachedImage = cacheManager.getCachedImage(for: url) {
                image = cachedImage
            }
        }
    }
}
