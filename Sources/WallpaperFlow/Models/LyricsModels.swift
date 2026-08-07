import Foundation

// MARK: - Lyric Token

public struct LyricToken: Sendable, Codable, Hashable {
    public var startTime: Double
    public var endTime: Double
    public var text: String
    
    public init(startTime: Double, endTime: Double, text: String) {
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
}

// MARK: - Lyric Line

public struct LyricLine: Sendable, Codable, Hashable {
    public var startTime: Double
    public var endTime: Double?
    public var text: String
    public var tokens: [LyricToken]?
    
    public init(startTime: Double, endTime: Double? = nil, text: String, tokens: [LyricToken]? = nil) {
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.tokens = tokens
    }
}

// MARK: - Synced Lyrics

public struct SyncedLyrics: Sendable, Codable {
    public var lines: [LyricLine]
    public var provider: String
    public var lyricsType: LyricsType
    
    public init(lines: [LyricLine], provider: String = "unknown", lyricsType: LyricsType = .lineSynced) {
        self.lines = lines
        self.provider = provider
        self.lyricsType = lyricsType
    }
}

// MARK: - Lyrics Type

public enum LyricsType: String, Sendable, Codable {
    case lineSynced
    case wordSynced
    case plain
    case unavailable
}

// MARK: - Lyrics Availability

public enum LyricsAvailability: Sendable {
    case available(SyncedLyrics)
    case loading
    case unavailable
    case error(Error)
}

// MARK: - Lyrics State

@Observable
public final class LyricsState {
    public var lyrics: SyncedLyrics?
    public var currentLineIndex: Int?
    public var offset: TimeInterval
    public var availability: LyricsAvailability
    
    public init(
        lyrics: SyncedLyrics? = nil,
        currentLineIndex: Int? = nil,
        offset: TimeInterval = 0,
        availability: LyricsAvailability = .unavailable
    ) {
        self.lyrics = lyrics
        self.currentLineIndex = currentLineIndex
        self.offset = offset
        self.availability = availability
    }
    
    public var currentLine: LyricLine? {
        guard let index = currentLineIndex, let lyrics = lyrics, index < lyrics.lines.count else {
            return nil
        }
        return lyrics.lines[index]
    }
    
    public var previousLine: LyricLine? {
        guard let index = currentLineIndex, index > 0, let lyrics = lyrics else {
            return nil
        }
        return lyrics.lines[index - 1]
    }
    
    public var nextLine: LyricLine? {
        guard let index = currentLineIndex, let lyrics = lyrics,
              index + 1 < lyrics.lines.count else {
            return nil
        }
        return lyrics.lines[index + 1]
    }
    
    public var hasLyrics: Bool {
        if case .available = availability { return true }
        return false
    }
}