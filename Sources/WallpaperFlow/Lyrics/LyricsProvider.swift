import Foundation

// MARK: - Lyrics Provider Protocol

public protocol LyricsProvider: AnyObject, Sendable {
    func lyrics(for track: TrackIdentity) async throws -> SyncedLyrics
}

// MARK: - Lyrics Errors

public enum LyricsError: LocalizedError {
    case notFound
    case networkError(Error)
    case parsingFailed
    case rateLimited
    case invalidTrack
    
    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "Lyrics not found for this track"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parsingFailed:
            return "Failed to parse lyrics data"
        case .rateLimited:
            return "Too many requests, please try again later"
        case .invalidTrack:
            return "Invalid track information"
        }
    }
}