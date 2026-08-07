import Foundation
@preconcurrency import MusicKit
import OSLog

// MARK: - Apple Music Provider

public final class AppleMusicProvider: @unchecked Sendable, NowPlayingProvider {

    public var currentTrack: TrackState?
    public var isActive: Bool = false

    public var onTrackChanged: (@Sendable (TrackState) -> Void)?
    public var onPlaybackStateChanged: (@Sendable (PlaybackState) -> Void)?
    public var onPlaybackPositionChanged: (@Sendable (TimeInterval) -> Void)?
    public var onError: (@Sendable (Error) -> Void)?

    private var timer: Timer?
    private var lastTrackID: String?
    private let logger = Logger.music

    public init() {}

    public func start() {
        guard !isActive else { return }
        isActive = true

        startPolling()

        // Get initial track
        updateCurrentTrack()

        logger.info("Apple Music provider started")
    }

    public func stop() {
        guard isActive else { return }
        isActive = false

        timer?.invalidate()
        timer = nil

        logger.info("Apple Music provider stopped")
    }

    // MARK: - Polling

    private func startPolling() {
        let newTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCurrentTrack()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func updateCurrentTrack() {
        Task { @MainActor in
            let player = SystemMusicPlayer.shared

            guard let currentEntry = player.queue.currentEntry else {
                // No track playing
                if currentTrack != nil {
                    currentTrack = nil
                    lastTrackID = nil
                    onPlaybackStateChanged?(.stopped)
                }
                return
            }

            // Extract track info
            let title = currentEntry.title ?? "Unknown Track"
            let artist = currentEntry.subtitle ?? "Unknown Artist"
            // Entry duration is not directly available; resolve via MusicKit if needed
            let duration: TimeInterval = 0
            let playbackTime = player.playbackTime

            // Map MusicKit playback status to our PlaybackState
            let playbackState: PlaybackState
            switch player.state.playbackStatus {
            case .playing:
                playbackState = .playing
            case .paused:
                playbackState = .paused
            case .stopped, .interrupted:
                playbackState = .stopped
            @unknown default:
                playbackState = .unknown
            }

            // Build a stable track ID
            let isrc = currentEntry.item?.isrc
            let trackID: String
            if let isrc = isrc, !isrc.isEmpty {
                trackID = isrc
            } else {
                trackID = "\(title)_\(artist)"
            }

            let track = TrackState(
                id: trackID,
                title: title,
                artist: artist,
                album: nil,
                artwork: nil,
                duration: duration,
                playbackPosition: playbackTime,
                playbackState: playbackState,
                isrc: isrc,
                metadataSource: .appleMusic,
                confidence: 1.0
            )

            // Check for track change
            if trackID != lastTrackID {
                lastTrackID = trackID
                currentTrack = track
                onTrackChanged?(track)
            } else {
                let previousPlaybackState = currentTrack?.playbackState
                currentTrack = track
                onPlaybackPositionChanged?(playbackTime)
                if playbackState != previousPlaybackState {
                    onPlaybackStateChanged?(playbackState)
                }
            }
        }
    }
}