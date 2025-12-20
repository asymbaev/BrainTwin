import Foundation
import AVFoundation
import os

// ✅ REMOVED @MainActor - file operations should NOT block UI
class AudioCacheManager {
    static let shared = AudioCacheManager()

    private let cacheDirectory: URL
    private let maxCacheSize: Int = 50 * 1024 * 1024 // 50 MB

    private init() {
        // ✅ FIXED: Use Caches directory (persistent, won't be cleared randomly)
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cachesDir.appendingPathComponent("AudioCache", isDirectory: true)

        // Create directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            print("📁 AudioCacheManager initialized at: \(cacheDirectory.path)")
        } catch {
            print("❌ Failed to create cache directory: \(error)")
        }
    }

    // MARK: - Cache Key Generation

    private func cacheKey(for urlString: String) -> String {
        return urlString.data(using: .utf8)?.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-") ?? urlString.hashValue.description
    }

    private func cacheURL(for urlString: String) -> URL {
        let key = cacheKey(for: urlString)
        return cacheDirectory.appendingPathComponent(key).appendingPathExtension("mp3")
    }

    // MARK: - Cache Check

    func isCached(_ urlString: String) -> Bool {
        let fileURL = cacheURL(for: urlString)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    // MARK: - Retrieve Cached Audio (NON-BLOCKING)

    func getCachedAudio(_ urlString: String) async -> Data? {
        let fileURL = cacheURL(for: urlString)

        return await Task.detached {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return nil
            }

            do {
                let data = try Data(contentsOf: fileURL)
                await MainActor.run {
                    print("✅ Retrieved cached audio: \(fileURL.lastPathComponent) (\(data.count) bytes)")
                }
                return data
            } catch {
                await MainActor.run {
                    print("❌ Failed to read cached audio: \(error)")
                }
                return nil
            }
        }.value
    }

    // MARK: - Download and Cache

    func downloadAndCache(_ urlString: String) async throws -> Data {
        // Check cache first (non-blocking)
        if let cachedData = await getCachedAudio(urlString) {
            print("🎯 Using cached audio for: \(urlString)")
            return cachedData
        }

        // Download if not cached
        print("⬇️ Downloading audio from: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        print("✅ Downloaded \(data.count) bytes")

        // Cache the data
        let fileURL = cacheURL(for: urlString)
        do {
            try data.write(to: fileURL)
            print("💾 Cached audio at: \(fileURL.lastPathComponent)")
        } catch {
            print("⚠️ Failed to cache audio: \(error)")
            // Continue even if caching fails
        }

        return data
    }

    // MARK: - Batch Pre-download

    func preDownloadAudioFiles(_ urlStrings: [String]) async {
        guard !urlStrings.isEmpty else {
            print("ℹ️ No audio URLs to pre-download")
            return
        }

        print("🚀 Pre-downloading \(urlStrings.count) audio files...")

        // Clean cache before downloading new files
        await cleanCacheIfNeeded()

        // Download all files in parallel
        await withTaskGroup(of: Void.self) { group in
            for urlString in urlStrings {
                group.addTask {
                    do {
                        _ = try await self.downloadAndCache(urlString)
                    } catch {
                        print("❌ Failed to pre-download audio from \(urlString): \(error)")
                    }
                }
            }
        }

        print("✅ Pre-download completed for \(urlStrings.count) files")
    }

    // MARK: - Cache Management

    func getCacheSize() -> Int {
        guard let files = try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        return files.reduce(0) { total, fileURL in
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + size
        }
    }

    func cleanCacheIfNeeded() async {
        let currentSize = getCacheSize()
        print("📊 Current cache size: \(currentSize / 1024 / 1024) MB")

        guard currentSize > maxCacheSize else {
            return
        }

        print("🧹 Cache size exceeded \(maxCacheSize / 1024 / 1024) MB, cleaning...")

        // Get all files with their creation dates
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        ) else {
            return
        }

        // Sort by modification date (oldest first)
        let sortedFiles = files.sorted { file1, file2 in
            let date1 = (try? file1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            let date2 = (try? file2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            return date1 < date2
        }

        // Delete oldest files until we're under the limit
        var totalSize = currentSize
        for fileURL in sortedFiles {
            guard totalSize > maxCacheSize / 2 else { break } // Keep cleaning until we're at 50% capacity

            let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0

            do {
                try FileManager.default.removeItem(at: fileURL)
                totalSize -= fileSize
                print("🗑️ Deleted cached file: \(fileURL.lastPathComponent)")
            } catch {
                print("❌ Failed to delete file: \(error)")
            }
        }

        print("✅ Cache cleaned. New size: \(totalSize / 1024 / 1024) MB")
    }

    func clearAllCache() {
        do {
            try FileManager.default.removeItem(at: cacheDirectory)
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            print("✅ Cleared all audio cache")
        } catch {
            print("❌ Failed to clear cache: \(error)")
        }
    }
}
