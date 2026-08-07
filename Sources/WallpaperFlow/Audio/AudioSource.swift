import Foundation
import CoreAudio
import AVFoundation

// MARK: - Audio Format

public struct AudioFormat: Sendable {
    public let sampleRate: Float64
    public let channelCount: UInt32
    public let bitsPerChannel: UInt32
    public let formatFlags: AudioFormatFlags
    
    public static let `default` = AudioFormat(
        sampleRate: 48000,
        channelCount: 2,
        bitsPerChannel: 32,
        formatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
    )
}

// MARK: - Audio Source Protocol

public protocol AudioSource: AnyObject {
    var isRunning: Bool { get }
    var format: AudioFormat { get }
    
    func start() throws
    func stop()
    
    var onAudioBuffer: (@Sendable (UnsafeBufferPointer<Float>, AVAudioTime) -> Void)? { get set }
    var onError: (@Sendable (Error) -> Void)? { get set }
}

// MARK: - Audio Source Errors

public enum AudioSourceError: LocalizedError {
    case permissionDenied
    case tapCreationFailed
    case invalidFormat
    case alreadyRunning
    case notRunning
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Audio capture permission was denied"
        case .tapCreationFailed:
            return "Failed to create audio tap"
        case .invalidFormat:
            return "Invalid audio format"
        case .alreadyRunning:
            return "Audio source is already running"
        case .notRunning:
            return "Audio source is not running"
        case .unknown(let error):
            return "Audio error: \(error.localizedDescription)"
        }
    }
}