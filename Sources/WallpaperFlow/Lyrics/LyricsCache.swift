import Foundation
import os

// MARK: - Lyrics Cache

public final class LyricsCache: @unchecked Sendable {
    public static let shared = LyricsCache()

    private static let ttl: TimeInterval = 30 * 24 * 60 * 60 // 30 days
    private static let subdirectory = "cache/lyrics"

    private let lock = OSAllocatedUnfairLock()

    private init() {}

    // MARK: - Public API

    public static func save(key: String, lyrics: SyncedLyrics) {
        shared.lock.lock()
        defer { shared.lock.unlock() }

        guard let url = shared.cacheURL(for: key) else { return }

        do {
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(lyrics)
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("LyricsCache: Failed to save lyrics for key '\(key)': \(error.localizedDescription)")
        }
    }

    public static func load(key: String) -> SyncedLyrics? {
        shared.lock.lock()
        defer { shared.lock.unlock() }

        guard let url = shared.cacheURL(for: key) else { return nil }

        do {
            let resourceValues = try url.resourceValues(forKeys: [.contentModificationDateKey])
            guard let modificationDate = resourceValues.contentModificationDate else {
                return nil
            }

            guard Date().timeIntervalSince(modificationDate) < Self.ttl else {
                try? FileManager.default.removeItem(at: url)
                return nil
            }

            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(SyncedLyrics.self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - Private

    private func cacheURL(for key: String) -> URL? {
        guard let cachesDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "Wallpaper Flow"
        let baseURL = bundleID == "Wallpaper Flow"
            ? cachesDirectory.appendingPathComponent("Wallpaper Flow")
            : cachesDirectory.appendingPathComponent(bundleID)

        return baseURL
            .appendingPathComponent(Self.subdirectory)
            .appendingPathComponent(sanitizedFileName(key))
            .appendingPathExtension("json")
    }

    private func sanitizedFileName(_ key: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        return key
            .components(separatedBy: allowed.inverted)
            .joined(separator: "_")
    }
}