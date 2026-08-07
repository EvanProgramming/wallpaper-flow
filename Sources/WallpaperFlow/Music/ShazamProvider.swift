import Foundation
@preconcurrency import AVFoundation
import OSLog
@preconcurrency import ShazamKit

// MARK: - Shazam Recognition Provider

public final class ShazamProvider: NSObject, @unchecked Sendable {

    // MARK: - Public Properties

    public private(set) var currentTrack: TrackState?
    public private(set) var isActive: Bool = false

    public var onTrackChanged: (@Sendable (TrackState) -> Void)?
    public var onPlaybackStateChanged: (@Sendable (PlaybackState) -> Void)?
    public var onError: (@Sendable (Error) -> Void)?

    // MARK: - Private Properties

    private let session: SHSession
    private let sessionQueue: DispatchQueue
    private let callbackQueue: DispatchQueue

    private var cachedResults: [String: TrackState] = [:]
    private var lastMatchDate: Date?
    private var lastMatchKey: String?

    private var recognitionState: RecognitionState = .accumulating
    private var activeAudioDuration: TimeInterval = 0
    private var lastActiveBufferDate: Date?
    private var silenceStartDate: Date?

    // MARK: - Constants

    private static let stableSignalDuration: TimeInterval = 1.5
    private static let silenceGapThreshold: TimeInterval = 2.0
    private static let reRecognizeInterval: TimeInterval = 300.0 // 5 minutes
    private static let energyThreshold: Float = 0.001

    // MARK: - Initialization

    override public init() {
        let session = SHSession()
        self.session = session
        self.sessionQueue = DispatchQueue(
            label: "com.wallpaperflow.shazam.session",
            qos: .userInitiated
        )
        self.callbackQueue = DispatchQueue(
            label: "com.wallpaperflow.shazam.callback",
            qos: .default
        )
        super.init()
        session.delegate = self
        Logger.music.info("ShazamProvider initialized")
    }

    // MARK: - Public Methods

    /// Feed an audio buffer for potential recognition.
    /// The buffer will be evaluated for energy and recognition conditions before
    /// being passed to the Shazam session.
    public func recognize(_ buffer: AVAudioPCMBuffer) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.processBuffer(buffer)
        }
    }
}

// MARK: - NowPlayingProvider

extension ShazamProvider: NowPlayingProvider {

    public func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.isActive = true
            self.resetRecognitionState()
            Logger.music.info("ShazamProvider started")
        }
    }

    public func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.isActive = false
            self.currentTrack = nil
            self.resetRecognitionState()
            Logger.music.info("ShazamProvider stopped")
        }
    }

    public var onPlaybackPositionChanged: (@Sendable (TimeInterval) -> Void)? {
        get { nil }
        set { /* Shazam provider does not track playback position */ }
    }
}

// MARK: - SHSessionDelegate

extension ShazamProvider: SHSessionDelegate {

    public func session(_ session: SHSession, didFind match: SHMatch) {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            let key = self.cacheKey(for: match)
            if let key {
                if let cached = self.cachedResults[key] {
                    self.currentTrack = cached
                    self.lastMatchDate = Date()
                    self.lastMatchKey = key
                    self.recognitionState = .matched

                    self.callbackQueue.async {
                        self.onTrackChanged?(cached)
                    }
                    return
                }
            }

            guard let trackState = self.trackState(from: match) else { return }

            self.currentTrack = trackState
            self.lastMatchDate = Date()
            self.lastMatchKey = key
            self.recognitionState = .matched

            if let key {
                self.cachedResults[key] = trackState
            }

            Logger.music.debug("Shazam matched: \(trackState.title) - \(trackState.artist)")

            self.callbackQueue.async {
                self.onTrackChanged?(trackState)
            }
        }
    }

    public func session(
        _ session: SHSession,
        didNotFindMatchFor signature: SHSignature,
        error: (any Error)?
    ) {
        Logger.music.debug("Shazam did not find match")
    }

    public func session(_ session: SHSession, didFailWithError error: any Error) {
        Logger.music.error("Shazam session error: \(error.localizedDescription)")

        callbackQueue.async { [weak self] in
            self?.onError?(error)
        }
    }
}

// MARK: - Recognition State Machine

private extension ShazamProvider {

    enum RecognitionState {
        /// Waiting for stable audio signal before first recognition or after a discontinuity.
        case accumulating
        /// Actively feeding buffers to the Shazam session.
        case recognizing
        /// A match has been found; monitoring for discontinuity or timeout.
        case matched
    }

    func processBuffer(_ buffer: AVAudioPCMBuffer) {
        let energy = calculateRMS(buffer)
        let now = Date()

        if energy < Self.energyThreshold {
            // Silence detected
            handleSilence(now: now)
            return
        }

        // Active audio present
        silenceStartDate = nil
        lastActiveBufferDate = now

        switch recognitionState {
        case .accumulating:
            activeAudioDuration += bufferDuration(buffer)
            if activeAudioDuration >= Self.stableSignalDuration {
                recognitionState = .recognizing
                activeAudioDuration = 0
                Logger.music.debug("Stable signal detected, starting recognition")
                feedToSession(buffer)
            }

        case .recognizing:
            feedToSession(buffer)

        case .matched:
            handleMatchedState()
        }
    }

    func handleSilence(now: Date) {
        if silenceStartDate == nil {
            silenceStartDate = now
            return
        }

        let silenceDuration = now.timeIntervalSince(silenceStartDate!)
        guard silenceDuration >= Self.silenceGapThreshold else { return }

        // Audio discontinuity detected
        Logger.music.debug("Audio discontinuity detected (silence > \(Self.silenceGapThreshold)s)")
        resetRecognitionState()

        // If we had a match, still notify potential playback change
        if recognitionState == .matched {
            currentTrack = nil
            callbackQueue.async { [weak self] in
                self?.onPlaybackStateChanged?(.stopped)
            }
        }
    }

    func handleMatchedState() {
        guard let lastMatch = lastMatchDate else { return }
        let elapsed = Date().timeIntervalSince(lastMatch)

        if elapsed >= Self.reRecognizeInterval {
            recognitionState = .recognizing
            Logger.music.debug("Re-recognition timeout reached, resuming recognition")
        }
    }

    func resetRecognitionState() {
        recognitionState = .accumulating
        activeAudioDuration = 0
        lastActiveBufferDate = nil
        silenceStartDate = nil
    }

    func feedToSession(_ buffer: AVAudioPCMBuffer) {
        guard let matchBuffer = prepareBufferForShazam(buffer) else { return }
        let audioTime = AVAudioTime(
            sampleTime: 0,
            atRate: Double(matchBuffer.format.sampleRate)
        )
        session.matchStreamingBuffer(matchBuffer, at: audioTime)
    }
}

// MARK: - Audio Processing

private extension ShazamProvider {

    func calculateRMS(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        var sumSquares: Float = 0
        var totalSamples: Int = 0

        for channel in 0..<channelCount {
            let data = channelData[channel]
            for i in 0..<frameLength {
                let sample = data[i]
                sumSquares += sample * sample
                totalSamples += 1
            }
        }

        guard totalSamples > 0 else { return 0 }
        return sqrt(sumSquares / Float(totalSamples))
    }

    func bufferDuration(_ buffer: AVAudioPCMBuffer) -> TimeInterval {
        let frameLength = Double(buffer.frameLength)
        let sampleRate = buffer.format.sampleRate
        guard sampleRate > 0 else { return 0 }
        return frameLength / sampleRate
    }

    func prepareBufferForShazam(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        // ShazamKit accepts any PCM format, but non-interleaved is preferred.
        if !buffer.format.isInterleaved {
            return buffer
        }
        return convertToNonInterleaved(buffer)
    }

    func convertToNonInterleaved(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let channelCount = buffer.format.channelCount
        let sampleRate = buffer.format.sampleRate
        let frameLength = buffer.frameLength

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        ) else {
            Logger.music.error("Failed to create non-interleaved format")
            return nil
        }

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameLength
        ) else {
            Logger.music.error("Failed to create output buffer")
            return nil
        }
        outputBuffer.frameLength = frameLength

        guard let interleavedData = buffer.floatChannelData?[0] else {
            Logger.music.error("No interleaved channel data available")
            return nil
        }

        for channel in 0..<Int(channelCount) {
            guard let channelData = outputBuffer.floatChannelData?[channel] else { continue }
            for frame in 0..<Int(frameLength) {
                channelData[frame] = interleavedData[frame * Int(channelCount) + channel]
            }
        }

        return outputBuffer
    }
}

// MARK: - Cache & Track Mapping

private extension ShazamProvider {

    func cacheKey(for match: SHMatch) -> String? {
        guard let mediaItem = match.mediaItems.first else { return nil }

        if let isrc = mediaItem.isrc, !isrc.isEmpty {
            return isrc
        }

        let title = (mediaItem.title ?? "").lowercased().trimmingCharacters(in: .whitespaces)
        let artist = (mediaItem.artist ?? "").lowercased().trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty, !artist.isEmpty else { return nil }

        return "\(artist)_\(title)"
    }

    func trackState(from match: SHMatch) -> TrackState? {
        guard let mediaItem = match.mediaItems.first else { return nil }

        let title = mediaItem.title ?? "Unknown Track"
        let artist = mediaItem.artist ?? "Unknown Artist"

        return TrackState(
            title: title,
            artist: artist,
            album: nil,
            duration: 0,
            isrc: mediaItem.isrc,
            metadataSource: .shazam,
            confidence: 1.0
        )
    }
}