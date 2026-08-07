import Foundation
import OSLog

// MARK: - Artwork Loader

/// Loads album artwork asynchronously with on-disk caching.
///
/// Caches artwork data to `Application Support/Wallpaper Flow/cache/artwork/`
/// keyed by the track's ISRC or a normalized title+artist string.
/// Expired cache entries (older than 30 days) are evicted on access.
public final class ArtworkLoader: @unchecked Sendable {
    private let cacheDirectory: URL
    private let fileManager: FileManager
    private let ttl: TimeInterval = 30 * 24 * 60 * 60  // 30 days
    private let lock = NSLock()
    private let session: URLSession
    
    public init() {
        self.cacheDirectory = URL.artworkCacheDirectory
        self.fileManager = FileManager.default
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        self.session = URLSession(configuration: config)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    deinit {
        session.invalidateAndCancel()
    }
    
    // MARK: - Public API
    
    /// Loads artwork data for the given URL and cache key.
    ///
    /// Checks the disk cache first. If a valid (non-expired) entry exists,
    /// returns it immediately without a network request. Otherwise downloads
    /// the data, caches it to disk, and returns it.
    ///
    /// - Parameters:
    ///   - url: The remote artwork URL.
    ///   - key: A cache key, typically from `TrackIdentity.cacheKey()`.
    /// - Returns: The raw image data.
    /// - Throws: `URLError` or file-system errors.
    public func load(url: URL, key: String) async throws -> Data {
        // Check disk cache first
        if let cached = cachedData(for: key) {
            Logger.music.debug("Artwork cache hit for key: \(key)")
            return cached
        }
        
        Logger.music.debug("Artwork cache miss for key: \(key), downloading…")
        
        // Download from network
        let request = URLRequest(url: url)
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // Persist to disk cache
        cacheData(data, for: key)
        
        return data
    }
    
    /// Returns cached artwork data for the given key, or `nil` if the cache
    /// entry is missing or expired.
    ///
    /// - Parameter key: The cache key to look up.
    /// - Returns: The cached data, or `nil`.
    public func cachedData(for key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        
        let fileURL = cacheDirectory.appendingPathComponent(sanitized(key))
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        // Check expiry
        let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path)
        if let modificationDate = attributes?[.modificationDate] as? Date,
           Date().timeIntervalSince(modificationDate) > ttl {
            // Expired – remove it
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
        
        return try? Data(contentsOf: fileURL)
    }
    
    // MARK: - Private Helpers
    
    private func cacheData(_ data: Data, for key: String) {
        lock.lock()
        defer { lock.unlock() }
        
        let fileURL = cacheDirectory.appendingPathComponent(sanitized(key))
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Logger.music.error("Failed to write artwork cache: \(error.localizedDescription)")
        }
    }
    
    /// Sanitizes a cache key into a safe filename.
    private func sanitized(_ key: String) -> String {
        // Replace characters that are problematic in filenames
        key.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
    }
}