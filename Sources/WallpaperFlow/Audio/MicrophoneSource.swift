import Foundation
import AVFoundation
import OSLog

// MARK: - Microphone Source

public final class MicrophoneSource: AudioSource {
    
    public var isRunning: Bool = false
    public let format: AudioFormat = .default
    
    public var onAudioBuffer: (@Sendable (UnsafeBufferPointer<Float>, AVAudioTime) -> Void)?
    public var onError: (@Sendable (Error) -> Void)?
    
    private let audioEngine = AVAudioEngine()
    private var ringBuffer: AudioRingBuffer?
    
    public init() {}
    
    public func start() throws {
        guard !isRunning else { throw AudioSourceError.alreadyRunning }
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Ensure we're working with Float32
        guard inputFormat.commonFormat == .pcmFormatFloat32 else {
            throw AudioSourceError.invalidFormat
        }
        
        // Create ring buffer
        ringBuffer = AudioRingBuffer(capacity: 16384, channelCount: 2)
        
        // Install tap on the input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            guard let channelData = buffer.floatChannelData else { return }
            let frameLength = Int(buffer.frameLength)
            let channelCount = Int(buffer.format.channelCount)
            
            // If stereo, interleave channels; if mono, duplicate
            let interleaved = UnsafeMutablePointer<Float>.allocate(capacity: frameLength * 2)
            defer { interleaved.deallocate() }
            
            if channelCount >= 2 {
                // Already stereo
                for i in 0..<frameLength {
                    interleaved[i * 2] = channelData[0][i]
                    interleaved[i * 2 + 1] = channelData[1][i]
                }
            } else {
                // Mono → duplicate to stereo
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
        try audioEngine.start()
        isRunning = true
        Logger.audio.info("Microphone source started")
    }
    
    public func stop() {
        guard isRunning else { return }
        
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRunning = false
        ringBuffer = nil
        Logger.audio.info("Microphone source stopped")
    }
}