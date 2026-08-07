import Foundation
import AVFoundation
import OSLog

// MARK: - Music Manager

@MainActor
public final class MusicManager {

    private let appState: AppState
    private let appleMusicProvider = AppleMusicProvider()
    private let shazamProvider = ShazamProvider()
    private let artworkLoader = ArtworkLoader()
    private let lyricsProvider = LRCLIBProvider()
    private let lyricsSynchronizer: LyricsSynchronizer
    private let logger = Logger.music

    private var currentAudioSession: AudioSession?
    private var currentTrackID: String?
    private var currentArtworkURL: URL?

    public init(appState: AppState) {
        self.appState = appState
        self.lyricsSynchronizer = LyricsSynchronizer(lyricsState: appState.lyricsState)
    }

    // MARK: - Audio Session Integration

    /// Connect to an audio session for Shazam buffer feeding
    public func connect(audioSession: AudioSession) {
        currentAudioSession = audioSession
    }

    // MARK: - Start/Stop

    public func start() {
        // Start Apple Music provider
        appleMusicProvider.onTrackChanged = { [weak self] track in
            Task { @MainActor in
                self?.handleTrackChanged(track)
            }
        }
        appleMusicProvider.start()

        // Start Shazam provider
        shazamProvider.onTrackChanged = { [weak self] track in
            Task { @MainActor in
                self?.handleTrackChanged(track)
            }
        }
        shazamProvider.start()

        logger.info("MusicManager started")
    }

    public func stop() {
        appleMusicProvider.stop()
        shazamProvider.stop()
        logger.info("MusicManager stopped")
    }

    // MARK: - Audio Buffer Feeding (for Shazam)

    /// Feed an audio buffer to the Shazam provider for recognition
    public func feedAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        shazamProvider.recognize(buffer)
    }

    // MARK: - Track Change Handling

    private func handleTrackChanged(_ track: TrackState) {
        guard track.id != currentTrackID else {
            // Update playback position only
            appState.trackState = track
            lyricsSynchronizer.update(playbackPosition: track.playbackPosition)
            return
        }

        currentTrackID = track.id
        appState.trackState = track
        appState.lyricsState.availability = .loading

        // Load artwork
        loadArtwork(for: track)

        // Load lyrics
        loadLyrics(for: track.identity)

        // Publish event
        AppEventBus.shared.publish(.trackChanged(track))
    }

    // MARK: - Artwork Loading

    private func loadArtwork(for track: TrackState) {
        // Check if artwork is already in track state
        if track.artwork != nil {
            extractPalette(from: track.artwork!)
            return
        }

        // For Apple Music, artwork is loaded differently
        // For now, if we have a URL, load it
        // This is called when Apple Music provides artwork
    }

    /// Called when Apple Music provides artwork data
    public func handleArtworkData(_ data: Data) {
        var track = appState.trackState
        track.artwork = data
        appState.trackState = track

        extractPalette(from: data)
    }

    private func extractPalette(from imageData: Data) {
        Task.detached(priority: .utility) {
            let palette = PaletteExtractor.extract(from: imageData)
            await MainActor.run {
                // Smooth palette transition through visual state
                self.appState.visualState.targetPalette = palette
                self.appState.visualState.paletteTransition = 0
                AppEventBus.shared.publish(.paletteChanged(palette))
            }
        }
    }

    // MARK: - Lyrics Loading

    private func loadLyrics(for track: TrackIdentity) {
        Task {
            // Check cache first
            let cacheKey = track.cacheKey()
            if let cached = LyricsCache.load(key: cacheKey) {
                await MainActor.run {
                    self.lyricsSynchronizer.setLyrics(cached)
                    self.appState.lyricsState.availability = .available(cached)
                    AppEventBus.shared.publish(.lyricsLoaded)
                }
                return
            }

            // Fetch from network
            do {
                let lyrics = try await lyricsProvider.lyrics(for: track)
                LyricsCache.save(key: cacheKey, lyrics: lyrics)
                await MainActor.run {
                    self.lyricsSynchronizer.setLyrics(lyrics)
                    self.appState.lyricsState.availability = .available(lyrics)
                    AppEventBus.shared.publish(.lyricsLoaded)
                }
            } catch {
                await MainActor.run {
                    self.appState.lyricsState.availability = .unavailable
                    AppEventBus.shared.publish(.lyricsUnavailable)
                }
            }
        }
    }

    // MARK: - Playback Position Update

    public func updatePlaybackPosition(_ position: TimeInterval) {
        lyricsSynchronizer.update(playbackPosition: position)
    }

    public func updateEstimatedPosition(_ position: TimeInterval) {
        lyricsSynchronizer.update(estimatedPosition: position)
    }

    public func setLyricsOffset(_ offset: TimeInterval) {
        lyricsSynchronizer.setOffset(offset)
    }
}