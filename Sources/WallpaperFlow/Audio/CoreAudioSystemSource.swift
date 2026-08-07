import Foundation
import AVFoundation
import OSLog

// MARK: - Core Audio System Source

public final class CoreAudioSystemSource: AudioSource {
    
    public var isRunning: Bool = false
    public let format: AudioFormat = .default
    
    public var onAudioBuffer: (@Sendable (UnsafeBufferPointer<Float>, AVAudioTime) -> Void)?
    public var onError: (@Sendable (Error) -> Void)?
    
    private let engine = AVAudioEngine()
    private var ringBuffer: AudioRingBuffer?
    private let processID: pid_t
    
    public init(processID: pid_t = -1) {
        self.processID = processID
    }
    
    public func start() throws {
        guard !isRunning else { throw AudioSourceError.alreadyRunning }
        
        let mainMixer = engine.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0)
        
        // Ensure we're working with Float32
        guard outputFormat.commonFormat == .pcmFormatFloat32 else {
            throw AudioSourceError.invalidFormat
        }
        
        // Create ring buffer
        ringBuffer = AudioRingBuffer(capacity: 32768, channelCount: 2)
        
        // Install tap on the main mixer to capture system audio output
        mainMixer.installTap(onBus: 0, bufferSize: 4096, format: outputFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            guard let channelData = buffer.floatChannelData else { return }
            let frameLength = Int(buffer.frameLength)
            let channelCount = Int(buffer.format.channelCount)
            
            // Always produce interleaved stereo data
            let interleaved = UnsafeMutablePointer<Float>.allocate(capacity: frameLength * 2)
            defer { interleaved.deallocate() }
            
            if buffer.format.isInterleaved {
                // Already interleaved — copy directly
                interleaved.update(from: channelData[0], count: frameLength * 2)
            } else if channelCount >= 2 {
                // Non-interleaved stereo — interleave channels
                for i in 0..<frameLength {
                    interleaved[i * 2] = channelData[0][i]
                    interleaved[i * 2 + 1] = channelData[1][i]
                }
            } else {
                // Mono — duplicate to stereo
                for i in 0..<frameLength {
                    interleaved[i * 2] = channelData[0][i]
                    interleaved[i * 2 + 1] = channelData[0][i]
                }
            }
            
            // Write to ring buffer
            self.ringBuffer?.write(interleaved, frameCount: frameLength)
            
            // Notify callback
            let buf = UnsafeBufferPointer(start: interleaved, count: frameLength * 2)
            self.onAudioBuffer?(buf, time)
        }
        
        // Start the engine
        try engine.start()
        isRunning = true
        Logger.audio.info("CoreAudio system source started")
    }
    
    public func stop() {
        guard isRunning else { return }
        
        engine.mainMixerNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        ringBuffer = nil
        Logger.audio.info("CoreAudio system source stopped")
    }
}