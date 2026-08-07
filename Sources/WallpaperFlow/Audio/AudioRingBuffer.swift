import Foundation
import Darwin

// MARK: - Audio Ring Buffer
// Lock-free single-producer, single-consumer circular buffer for audio data.
// The audio callback thread writes, the DSP worker thread reads.
// NO memory allocation, locks, or blocking operations in the write path.

public final class AudioRingBuffer: @unchecked Sendable {
    
    private let buffer: UnsafeMutablePointer<Float>
    private let capacity: Int
    private let mask: Int
    
    // Atomic head (write index) and tail (read index)
    // Using OS atomic operations for lock-free behavior
    private var _head: AtomicUInt64 = AtomicUInt64()
    private var _tail: AtomicUInt64 = AtomicUInt64()
    
    private let channelCount: Int
    
    public init(capacity: Int = 16384, channelCount: Int = 2) {
        // Ensure capacity is power of 2 for efficient masking
        let actualCapacity = 1 << Int(ceil(log2(Double(capacity))))
        self.capacity = actualCapacity
        self.mask = actualCapacity - 1
        self.channelCount = channelCount
        
        // Allocate buffer (done once during initialization, never in audio callback)
        buffer = UnsafeMutablePointer<Float>.allocate(capacity: actualCapacity * channelCount)
        buffer.initialize(repeating: 0, count: actualCapacity * channelCount)
    }
    
    deinit {
        buffer.deallocate()
    }
    
    // MARK: - Write (Audio Callback Thread)
    
    /// Write interleaved Float32 samples to the ring buffer.
    /// Returns the number of frames written.
    /// - Parameters:
    ///   - frames: Pointer to interleaved Float32 audio data
    ///   - frameCount: Number of stereo frames to write
    /// - Returns: Number of frames actually written
    @discardableResult
    public func write(_ frames: UnsafePointer<Float>, frameCount: Int) -> Int {
        let head = _head.load()
        let tail = _tail.load()
        let written = head &- tail
        let available = UInt64(capacity) &- written
        
        let toWrite = min(frameCount, Int(available))
        guard toWrite > 0 else { return 0 }
        
        let startIndex = Int(head) & mask
        
        for i in 0..<(toWrite * channelCount) {
            let writeIndex = (startIndex * channelCount + i) & (capacity * channelCount - 1)
            buffer[writeIndex] = frames[i]
        }
        
        _head.store(head &+ UInt64(toWrite))
        return toWrite
    }
    
    // MARK: - Read (DSP Thread)
    
    /// Read interleaved Float32 samples from the ring buffer.
    /// Returns the number of frames read.
    /// - Parameters:
    ///   - output: Pointer to output buffer for interleaved Float32 data
    ///   - frameCount: Maximum number of frames to read
    /// - Returns: Number of frames actually read
    @discardableResult
    public func read(_ output: UnsafeMutablePointer<Float>, frameCount: Int) -> Int {
        let head = _head.load()
        let tail = _tail.load()
        let available = head &- tail
        
        let toRead = min(frameCount, Int(available))
        guard toRead > 0 else { return 0 }
        
        let startIndex = Int(tail) & mask
        
        for i in 0..<(toRead * channelCount) {
            let readIndex = (startIndex * channelCount + i) & (capacity * channelCount - 1)
            output[i] = buffer[readIndex]
        }
        
        _tail.store(tail &+ UInt64(toRead))
        return toRead
    }
    
    /// Read available frame count without consuming
    public var availableFrames: Int {
        let head = _head.load()
        let tail = _tail.load()
        return Int(head &- tail)
    }
    
    /// Reset the buffer (not thread-safe with active write/read)
    public func reset() {
        _head.store(0)
        _tail.store(0)
    }
}

// MARK: - Atomic UInt64 (Lock-Free)

private struct AtomicUInt64: @unchecked Sendable {
    private var _value: UInt64 = 0
    
    private let lock = os_unfair_lock_t.allocate(capacity: 1)
    
    init() {
        lock.initialize(to: os_unfair_lock())
    }
    
    func load() -> UInt64 {
        os_unfair_lock_lock(lock)
        let value = _value
        os_unfair_lock_unlock(lock)
        return value
    }
    
    mutating func store(_ value: UInt64) {
        os_unfair_lock_lock(lock)
        _value = value
        os_unfair_lock_unlock(lock)
    }
    
    mutating func add(_ value: UInt64) -> UInt64 {
        os_unfair_lock_lock(lock)
        _value &+= value
        let result = _value
        os_unfair_lock_unlock(lock)
        return result
    }
}