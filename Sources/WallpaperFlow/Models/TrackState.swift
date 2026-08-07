import Foundation
import AppKit

// MARK: - Track Identity

public struct TrackIdentity: Hashable, Codable, Sendable {
    public var isrc: String?
    public var title: String
    public var artist: String
    public var album: String?
    public var duration: TimeInterval?
    
    public init(isrc: String? = nil, title: String, artist: String, album: String? = nil, duration: TimeInterval? = nil) {
        self.isrc = isrc
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
    }
    
    public func cacheKey() -> String {
        if let isrc = isrc, !isrc.isEmpty {
            return isrc
        }
        let normalizedArtist = artist.lowercased().trimmingCharacters(in: .whitespaces)
        let normalizedTitle = title.lowercased().trimmingCharacters(in: .whitespaces)
        let durationBucket = duration.map { String(Int($0 / 10) * 10) } ?? "unknown"
        return "\(normalizedArtist)_\(normalizedTitle)_\(durationBucket)"
    }
}

// MARK: - Playback State

public enum PlaybackState: String, Codable, Sendable {
    case playing
    case paused
    case stopped
    case unknown
}

// MARK: - Metadata Source

public enum MetadataSource: String, Codable, Sendable {
    case appleMusic
    case shazam
    case manual
    case none
}

// MARK: - Track State

public struct TrackState: Codable, Sendable, Hashable {
    public var id: String
    public var title: String
    public var artist: String
    public var album: String?
    public var artwork: Data?
    public var duration: TimeInterval
    public var playbackPosition: TimeInterval
    public var playbackState: PlaybackState
    public var isrc: String?
    public var metadataSource: MetadataSource
    public var confidence: Float
    
    public init(
        id: String = UUID().uuidString,
        title: String = "Unknown Track",
        artist: String = "Unknown Artist",
        album: String? = nil,
        artwork: Data? = nil,
        duration: TimeInterval = 0,
        playbackPosition: TimeInterval = 0,
        playbackState: PlaybackState = .unknown,
        isrc: String? = nil,
        metadataSource: MetadataSource = .none,
        confidence: Float = 0
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.artwork = artwork
        self.duration = duration
        self.playbackPosition = playbackPosition
        self.playbackState = playbackState
        self.isrc = isrc
        self.metadataSource = metadataSource
        self.confidence = confidence
    }
    
    public var identity: TrackIdentity {
        TrackIdentity(isrc: isrc, title: title, artist: artist, album: album, duration: duration)
    }
    
    public var hasMetadata: Bool {
        metadataSource != .none && title != "Unknown Track"
    }
    
    public static let empty = TrackState()
}