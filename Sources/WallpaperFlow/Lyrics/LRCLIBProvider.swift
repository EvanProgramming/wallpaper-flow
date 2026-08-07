@preconcurrency import Foundation

// MARK: - LRCLIB API Response Models

private struct LRCLIBSearchResult: Decodable, Sendable {
    let id: Int
    let trackName: String
    let artistName: String
    let albumName: String?
    let duration: Double?
    let plainLyrics: String?
    let syncedLyrics: String?
    let isrc: String?
}

// MARK: - LRCLIB Provider

public final class LRCLIBProvider: @unchecked Sendable {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let baseURL = "https://lrclib.net/api"

    public init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }
}

// MARK: - LyricsProvider Conformance

extension LRCLIBProvider: LyricsProvider {
    public func lyrics(for track: TrackIdentity) async throws -> SyncedLyrics {
        // Prefer ISRC lookup when available
        if let isrc = track.isrc, !isrc.isEmpty {
            do {
                return try await fetchByISRC(isrc, track: track)
            } catch LyricsError.notFound {
                // Fall through to search
            }
        }

        return try await search(track: track)
    }
}

// MARK: - Private Methods

extension LRCLIBProvider {

    private func fetchByISRC(_ isrc: String, track: TrackIdentity) async throws -> SyncedLyrics {
        guard var components = URLComponents(string: "\(baseURL)/get") else {
            throw LyricsError.invalidTrack
        }
        components.queryItems = [URLQueryItem(name: "isrc", value: isrc)]

        guard let url = components.url else {
            throw LyricsError.invalidTrack
        }

        let data = try await performRequest(url: url)
        let result = try decoder.decode(LRCLIBSearchResult.self, from: data)
        return try parseResponse(result, track: track)
    }

    private func search(track: TrackIdentity) async throws -> SyncedLyrics {
        let query = "\(track.title) \(track.artist)"
        guard var components = URLComponents(string: "\(baseURL)/search") else {
            throw LyricsError.invalidTrack
        }
        components.queryItems = [URLQueryItem(name: "q", value: query)]

        guard let url = components.url else {
            throw LyricsError.invalidTrack
        }

        let data = try await performRequest(url: url)
        let results = try decoder.decode([LRCLIBSearchResult].self, from: data)

        guard let best = results.first else {
            throw LyricsError.notFound
        }

        return try parseResponse(best, track: track)
    }

    private func performRequest(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Identify the client per LRCLIB guidelines
        request.setValue("WallpaperFlow/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LyricsError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LyricsError.networkError(NSError(domain: "LRCLIBProvider", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]))
        }

        switch httpResponse.statusCode {
        case 200:
            return data
        case 404:
            throw LyricsError.notFound
        case 429:
            throw LyricsError.rateLimited
        case 400:
            throw LyricsError.invalidTrack
        default:
            throw LyricsError.networkError(NSError(domain: "LRCLIBProvider",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"]))
        }
    }

    private func parseResponse(_ result: LRCLIBSearchResult, track: TrackIdentity) throws -> SyncedLyrics {
        // Prefer synced lyrics
        if let synced = result.syncedLyrics, !synced.isEmpty {
            let lines = LyricsParser.parse(lrcText: synced)
            guard !lines.isEmpty else {
                throw LyricsError.parsingFailed
            }
            return SyncedLyrics(lines: lines, provider: "lrclib", lyricsType: .lineSynced)
        }

        // Fall back to plain lyrics
        if let plain = result.plainLyrics, !plain.isEmpty {
            let lines = plain
                .components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .map { LyricLine(startTime: 0, text: $0) }

            return SyncedLyrics(lines: lines, provider: "lrclib", lyricsType: .plain)
        }

        throw LyricsError.notFound
    }
}