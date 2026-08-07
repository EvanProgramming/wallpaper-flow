import Foundation
import CoreAudio
import AudioToolbox
import AVFoundation
import OSLog

// MARK: - Core Audio System Source

public final class CoreAudioSystemSource: AudioSource {
    
    public var isRunning: Bool = false
    public let format: AudioFormat = .default
    
    public var onAudioBuffer: (@Sendable (UnsafeBufferPointer<Float>, AVAudioTime) -> Void)?
    public var onError: (@Sendable (Error) -> Void)?
    
    private var tap: AudioProcessTap?
    private var ringBuffer: AudioRingBuffer?
    private var audioQueue: DispatchQueue?
    private let processID: pid_t
    
    public init(processID: pid_t = -1) {
        self.processID = processID
    }
    
    public func start() throws {
        guard !isRunning else { throw AudioSourceError.alreadyRunning }
        
        do {
            try createTap()
            isRunning = true
            Logger.audio.info("CoreAudio system source started")
        } catch {
            Logger.audio.error("Failed to start CoreAudio source: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func stop() {
        guard isRunning else { return }
        
        destroyTap()
        isRunning = false
        Logger.audio.info("CoreAudio system source stopped")
    }
    
    // MARK: - Process Tap Creation
    
    private func createTap() throws {
        // Create tap description for stereo global tap
        let tapDesc: CATapDescription
        
        if processID > 0 {
            // Tap specific process
            tapDesc = CATapDescription(stereoGlobalTap: [processID])
        } else {
            // Tap all system audio, excluding self
            let selfPID = ProcessInfo.processInfo.processIdentifier
            tapDesc = CATapDescription(stereoGlobalTapButExcludeProcesses: [selfPID])
        }
        
        // Configure tap
        tapDesc.audioFormat = .default
        tapDesc.exclusive = false
        tapDesc.enabled = true
        
        // Create the tap
        var tapOutput: AudioProcessTap?
        var tapID: AudioProcessTapID = 0
        
        let status = AudioHardwareCreateProcessTap(
            tapDesc,
            &tapOutput,
            &tapID
        )
        
        guard status == noErr, let tap = tapOutput else {
            throw AudioSourceError.tapCreationFailed
        }
        
        self.tap = tap
        
        // Set up the IO proc
        let queue = DispatchQueue(label: "com.wallpaperflow.audio.tap", qos: .userInitiated)
        self.audioQueue = queue
        
        // Create ring buffer
        ringBuffer = AudioRingBuffer(capacity: 32768, channelCount: 2)
        
        // Set the IO proc on the tap
        AudioHardwareProcessTapIOProc(tap) { [weak self] (tapID, time, frameCount, ioData) in
            guard let self = self, let ioData = ioData else { return }
            
            let abl = ioData.pointee
            let bufferList = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer<AudioBufferList>(OpaquePointer(abl)))
            
            guard let firstBuffer = bufferList.first,
                  let data = firstBuffer.mData else { return }
            
            let frameCount = Int(firstBuffer.mDataByteSize) / MemoryLayout<Float>.size
            let floatPtr = data.bindMemory(to: Float.self, capacity: frameCount)
            
            let buffer = UnsafeBufferPointer(start: floatPtr, count: frameCount)
            let audioTime = AVAudioTime(sampleTime: time.mSampleTime, atRate: Double(time.mSampleRate))
            
            // Write to ring buffer
            self.ringBuffer?.write(floatPtr, frameCount: frameCount / 2)
            
            // Notify callback
            self.onAudioBuffer?(buffer, audioTime)
        }
        
        // Start the tap
        AudioHardwareProcessTapStart(tap)
    }
    
    private func destroyTap() {
        guard let tap = tap else { return }
        AudioHardwareProcessTapStop(tap)
        AudioHardwareDestroyProcessTap(tap)
        self.tap = nil
        ringBuffer = nil
    }
}