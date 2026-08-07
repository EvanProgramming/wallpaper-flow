import Foundation
import AVFoundation
import OSLog

// MARK: - Audio Session

@Observable
public final class AudioSession: @unchecked Sendable {
    
    public var currentFrame: AudioFeatureFrame = .zero
    public var isActive: Bool = false
    public var currentSourceType: AudioSourceType = .systemAudio
    
    private var currentSource: AudioSource?
    private let analyzer = AudioAnalyzer()
    private var displayLink: CVDisplayLink?
    private var isProcessing: Bool = false
    
    public init() {}
    
    // MARK: - Source Management
    
    public func startSource(_ type: AudioSourceType) {
        stopCurrentSource()
        
        currentSourceType = type
        
        let source: AudioSource
        switch type {
        case .systemAudio:
            source = CoreAudioSystemSource()
        case .microphone:
            source = MicrophoneSource()
        case .selectedApp:
            source = CoreAudioSystemSource() // Will be configured with specific PID
        }
        
        // Set up ring buffer
        let ringBuffer = AudioRingBuffer(capacity: 32768, channelCount: 2)
        analyzer.setRingBuffer(ringBuffer)
        
        // Wire audio callback to ring buffer
        source.onAudioBuffer = { [weak self] buffer, time in
            // Buffer is already written to ring buffer by the source
            // The analyzer reads from the ring buffer
        }
        
        source.onError = { error in
            Logger.audio.error("Audio source error: \(error.localizedDescription)")
            AppEventBus.shared.publish(.audioPermissionDenied)
        }
        
        do {
            try source.start()
            currentSource = source
            isActive = true
            startProcessing()
            AppEventBus.shared.publish(.audioStarted)
            Logger.audio.info("Audio session started: \(type.rawValue)")
        } catch {
            Logger.audio.error("Failed to start audio source: \(error.localizedDescription)")
            AppEventBus.shared.publish(.audioPermissionDenied)
        }
    }
    
    public func stopCurrentSource() {
        guard isActive else { return }
        
        stopProcessing()
        currentSource?.stop()
        currentSource = nil
        isActive = false
        AppEventBus.shared.publish(.audioStopped)
        Logger.audio.info("Audio session stopped")
    }
    
    // MARK: - Processing Loop
    
    private func startProcessing() {
        guard !isProcessing else { return }
        isProcessing = true
        
        Task.detached { [weak self] in
            guard let self = self else { return }
            
            let interval: UInt64 = UInt64(1.0 / 93.0 * 1_000_000_000) // ~93 Hz
            
            while self.isProcessing {
                if let frame = self.analyzer.processNextFrame() {
                    await MainActor.run {
                        self.currentFrame = frame
                    }
                }
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }
    
    private func stopProcessing() {
        isProcessing = false
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopCurrentSource()
    }
}