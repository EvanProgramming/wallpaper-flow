import Foundation
import os

// MARK: - Lyrics Synchronizer

public final class LyricsSynchronizer: @unchecked Sendable {
    private let lyricsState: LyricsState
    private let lock = OSAllocatedUnfairLock()

    private var clockEstimator: PlaybackClockEstimator?

    public init(lyricsState: LyricsState) {
        self.lyricsState = lyricsState
    }

    // MARK: - Public API

    /// Called by Apple Music provider with precise playback position from the player.
    public func update(playbackPosition: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }

        clockEstimator = nil
        recalculateCurrentLine(at: playbackPosition + lyricsState.offset)
    }

    /// Called by the generic clock estimator (Shazam-based sources).
    public func update(estimatedPosition: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }

        recalculateCurrentLine(at: estimatedPosition + lyricsState.offset)
    }

    /// Sets the user-adjustable offset. Range: -5.0 to +5.0, snapped to 50ms steps.
    public func setOffset(_ offset: TimeInterval) {
        let clamped = max(-5.0, min(5.0, offset))
        let stepped = round(clamped / 0.05) * 0.05
        lyricsState.offset = stepped
    }

    /// Loads new lyrics and resets the current line index.
    public func setLyrics(_ lyrics: SyncedLyrics) {
        lock.lock()
        defer { lock.unlock() }

        lyricsState.lyrics = lyrics
        lyricsState.currentLineIndex = nil
        lyricsState.availability = .available(lyrics)
    }

    /// Sets up a clock estimator for generic (Shazam) sources.
    public func setClockEstimator(
        recognitionTimestamp: TimeInterval,
        recognitionOffset: TimeInterval
    ) {
        lock.lock()
        defer { lock.unlock() }

        clockEstimator = PlaybackClockEstimator(
            recognitionTimestamp: recognitionTimestamp,
            recognitionOffset: recognitionOffset
        )
    }

    // MARK: - Private

    private func recalculateCurrentLine(at position: TimeInterval) {
        guard let lyrics = lyricsState.lyrics, !lyrics.lines.isEmpty else {
            lyricsState.currentLineIndex = nil
            return
        }

        let lines = lyrics.lines
        var newIndex: Int?

        // Find the last line whose start time is <= the current position.
        // If the position falls between line.startTime and line.endTime, that line is current.
        for (index, line) in lines.enumerated() {
            let lineStart = line.startTime
            let lineEnd = line.endTime ?? (index + 1 < lines.count
                ? lines[index + 1].startTime
                : .infinity)

            if position >= lineStart && position < lineEnd {
                newIndex = index
                break
            }
        }

        // If no exact match, find the nearest preceding line.
        if newIndex == nil {
            for (index, line) in lines.enumerated() {
                if line.startTime <= position {
                    newIndex = index
                } else {
                    break
                }
            }
        }

        // Edge case: position is before the first line.
        if newIndex == nil && !lines.isEmpty && position < lines[0].startTime {
            newIndex = 0
        }

        lyricsState.currentLineIndex = newIndex
    }
}

// MARK: - Playback Clock Estimator

extension LyricsSynchronizer {
    /// Estimates current playback position for generic (Shazam) sources
    /// using a monotonic clock and the recognition offset.
    final class PlaybackClockEstimator: @unchecked Sendable {
        private let recognitionTimestamp: TimeInterval
        private let recognitionOffset: TimeInterval

        init(recognitionTimestamp: TimeInterval, recognitionOffset: TimeInterval) {
            self.recognitionTimestamp = recognitionTimestamp
            self.recognitionOffset = recognitionOffset
        }

        /// The estimated current position in the track (seconds).
        var estimatedPosition: TimeInterval {
            let elapsed = ProcessInfo.processInfo.systemUptime - recognitionTimestamp
            return max(0, recognitionOffset + elapsed)
        }
    }
}