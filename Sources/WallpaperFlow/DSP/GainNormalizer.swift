import Foundation
import Accelerate

// MARK: - Gain Normalizer

public final class GainNormalizer: @unchecked Sendable {
    
    // Rolling window for RMS estimation
    private var rmsHistory: [Float] = []
    private let windowSize: Int
    
    // Target levels
    private let targetRMS: Float = 0.15
    private let maxGain: Float = 4.0
    private let minGain: Float = 0.5
    
    // Smoothing
    private var currentGain: Float = 1.0
    private let gainSmoothing: Float = 0.97
    
    // Dynamic range
    private var floor: Float = 0.01
    private var ceiling: Float = 1.0
    
    public init(windowSeconds: Double = 7.0, expectedFrameRate: Double = 93.0) {
        self.windowSize = Int(windowSeconds * expectedFrameRate)
    }
    
    // MARK: - Processing
    
    /// Process a loudness value and return normalized loudness
    /// - Parameter loudness: Raw loudness value (0.0 – 1.0+)
    /// - Returns: Normalized loudness (0.0 – 1.0)
    public func process(_ loudness: Float) -> Float {
        // Update RMS history
        rmsHistory.append(loudness)
        if rmsHistory.count > windowSize {
            rmsHistory.removeFirst()
        }
        
        // Compute rolling RMS
        let rollingRMS: Float
        if rmsHistory.isEmpty {
            rollingRMS = loudness
        } else {
            let sumSquares = rmsHistory.reduce(0) { $0 + $1 * $1 }
            rollingRMS = sqrt(sumSquares / Float(rmsHistory.count))
        }
        
        // Update floor and ceiling
        updateDynamicRange()
        
        // Compute target gain
        let targetGain: Float
        if rollingRMS > 0.001 {
            targetGain = targetRMS / rollingRMS
        } else {
            targetGain = maxGain
        }
        
        // Clamp gain
        let clampedGain = min(maxGain, max(minGain, targetGain))
        
        // Smooth gain changes
        currentGain = currentGain * gainSmoothing + clampedGain * (1.0 - gainSmoothing)
        
        // Apply gain
        let normalized = loudness * currentGain
        
        // Apply dynamic range compression
        let compressed = compress(normalized)
        
        // Clamp to valid range
        return min(1.0, max(0.0, compressed))
    }
    
    // MARK: - Dynamic Range
    
    private func updateDynamicRange() {
        guard !rmsHistory.isEmpty else { return }
        
        let sorted = rmsHistory.sorted()
        let count = sorted.count
        
        // Floor is the 10th percentile
        let floorIndex = max(0, Int(Float(count) * 0.1))
        floor = max(0.001, sorted[floorIndex])
        
        // Ceiling is the 95th percentile
        let ceilingIndex = min(count - 1, Int(Float(count) * 0.95))
        ceiling = max(floor, sorted[ceilingIndex])
    }
    
    // MARK: - Compression
    
    private func compress(_ value: Float) -> Float {
        // Simple soft knee compression
        let threshold: Float = 0.8
        let ratio: Float = 3.0
        let knee: Float = 0.1
        
        if value < threshold - knee {
            return value
        } else if value < threshold + knee {
            // Soft knee transition
            let x = (value - threshold + knee) / (2.0 * knee)
            let gain = 1.0 + (1.0 / ratio - 1.0) * x * x * (3.0 - 2.0 * x)
            return threshold + (value - threshold) * gain
        } else {
            // Hard compression
            return threshold + (value - threshold) / ratio
        }
    }
    
    // MARK: - Reset
    
    public func reset() {
        rmsHistory.removeAll()
        currentGain = 1.0
        floor = 0.01
        ceiling = 1.0
    }
}