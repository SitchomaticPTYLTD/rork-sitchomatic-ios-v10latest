import Foundation
import UIKit

@MainActor
class ScreenshotCacheService {
    static let shared = ScreenshotCacheService()

    private let cacheDirectory: URL
    private(set) var maxMemoryCacheCount: Int = 100
    private(set) var maxDiskCacheCount: Int = 500
    private let maxDiskCacheSizeBytes: Int64 = 200 * 1024 * 1024
    private var memoryCache: [String: UIImage] = [:]
    private var accessOrder: [String] = []

    init() {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDir.appendingPathComponent("ScreenshotCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func store(_ image: UIImage, forKey key: String) {
        memoryCache[key] = image
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
        evictMemoryCacheIfNeeded()

        Task.detached(priority: .utility) {
            let fileURL = self.fileURL(for: key)
            if let data = image.jpegData(compressionQuality: 0.5) {
                try? data.write(to: fileURL, options: .atomic)
            }
            await MainActor.run {
                self.evictDiskCacheIfNeeded()
            }
        }
    }

    func retrieve(forKey key: String) -> UIImage? {
        if let cached = memoryCache[key] {
            accessOrder.removeAll { $0 == key }
            accessOrder.append(key)
            return cached
        }

        let fileURL = fileURL(for: key)
        guard FileManager.default.fileExists(atPath: fileURL.path()),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }

        memoryCache[key] = image
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
        evictMemoryCacheIfNeeded()
        return image
    }

    func clearAll() {
        memoryCache.removeAll()
        accessOrder.removeAll()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    var diskCacheSizeBytes: Int64 {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for file in files {
            if let values = try? file.resourceValues(forKeys: [.fileSizeKey]),
               let size = values.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    var diskCacheSize: String {
        ByteCountFormatter.string(fromByteCount: diskCacheSizeBytes, countStyle: .file)
    }

    func setMaxCacheCounts(memory: Int, disk: Int) {
        maxMemoryCacheCount = max(10, memory)
        maxDiskCacheCount = max(20, disk)
        evictMemoryCacheIfNeeded()
        evictDiskCacheIfNeeded()
    }

    private func evictMemoryCacheIfNeeded() {
        while memoryCache.count > maxMemoryCacheCount, let oldest = accessOrder.first {
            memoryCache.removeValue(forKey: oldest)
            accessOrder.removeFirst()
        }
    }

    private func evictDiskCacheIfNeeded() {
        let diskMax = maxDiskCacheCount
        let sizeMax = maxDiskCacheSizeBytes
        Task.detached(priority: .utility) {
            let fm = FileManager.default
            let cachesDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let dir = cachesDir.appendingPathComponent("ScreenshotCache", isDirectory: true)
            guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else { return }

            let jpgFiles = files.filter { $0.pathExtension == "jpg" }

            let sorted = jpgFiles.sorted { a, b in
                let aDate = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let bDate = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return aDate < bDate
            }

            var removedByCount = 0
            if sorted.count > diskMax {
                let toRemove = sorted.prefix(sorted.count - diskMax)
                for file in toRemove {
                    try? fm.removeItem(at: file)
                    removedByCount += 1
                }
            }

            let remaining = sorted.dropFirst(removedByCount)
            var totalSize: Int64 = 0
            for file in remaining {
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                totalSize += Int64(size)
            }

            if totalSize > sizeMax {
                let target = sizeMax * 3 / 4
                for file in remaining {
                    guard totalSize > target else { break }
                    let size = Int64((try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
                    try? fm.removeItem(at: file)
                    totalSize -= size
                }
            }
        }
    }

    var diskFileCount: Int {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else { return 0 }
        return files.filter { $0.pathExtension == "jpg" }.count
    }

    private nonisolated func fileURL(for key: String) -> URL {
        let safeKey = key.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cachesDir.appendingPathComponent("ScreenshotCache", isDirectory: true).appendingPathComponent("\(safeKey).jpg")
    }
}
