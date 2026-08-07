import Foundation
import Accelerate

// MARK: - Beat Detector

public final class BeatDetector: @unchecked Sendable {
    
    // Spectral flux history
    private var history: [Float] = []
    private let historySize: Int = 43 // ~0.5 seconds at 93 Hz
    
    // Energy history
    private var energyHistory: [Float] = []
    private let energyHistorySize: Int = 43
    
    // Beat state
    private var beatImpulse: Float = 0
    private var refractoryTimer: Int = 0
    private let refractoryPeriod: Int = 10 // ~107ms at 93 Hz
    
    // Threshold
    private let thresholdMultiplier: Float = 1.5
    private var previousSpectrum: [Float]?
    
    // Smoothing
    private var previousImpulse: Float = 0
    
    public init() {}
    
    // MARK: - Processing
    
    /// Process a spectrum frame and return beat impulse (0.0 – 1.0)
    /// - Parameters:
    ///   - spectrum: Current 64-band magnitude spectrum
    ///   - bass: Current bass energy
    /// - Returns: Beat impulse value (0.0 – 1.0, decaying)
    public func process(spectrum: [Float], bass: Float) -> Float {
        // Compute spectral flux (positive spectral difference)
        let flux = computeSpectralFlux(current: spectrum)
        
        // Update history
        history.append(flux)
        if history.count > historySize {
            history.removeFirst()
        }
        
        // Compute adaptive threshold
        let threshold = computeAdaptiveThreshold()
        
        // Beat detection
        var isBeat = false
        
        // Decrease refractory timer
        if refractoryTimer > 0 {
            refractoryTimer -= 1
        }
        
        // Check for beat onset
        if flux > threshold && refractoryTimer == 0 && flux > 0.01 {
            isBeat = true
            refractoryTimer = refractoryPeriod
            
            // Use bass energy to boost confidence
            let bassBoost = 1.0 + bass * 0.5
            beatImpulse = min(1.0, (flux / threshold) * 0.5 * bassBoost)
        }
        
        // Decay the beat impulse
        beatImpulse *= 0.85 // Exponential decay (fast)
        if beatImpulse < 0.001 {
            beatImpulse = 0
        }
        
        // Store current spectrum for next comparison
        previousSpectrum = spectrum
        
        // Energy-based onset detection
        let energyOnset = computeEnergyOnset(bass: bass)
        let onsetStrength = max(flux / max(threshold, 0.001), energyOnset)
        
        return isBeat ? beatImpulse : beatImpulse
    }
    
    // MARK: - Spectral Flux
    
    private func computeSpectralFlux(current: [Float]) -> Float {
        guard let previous = previousSpectrum, previous.count == current.count else {
            return 0
        }
        
        var flux: Float = 0
        let minCount = min(previous.count, current.count)
        
        // Only use bins up to 10 kHz (about index 40 at 48 kHz with 64 bands)
        let maxBand = min(minCount, 48)
        
        for i in 0..<maxBand {
            let diff = current[i] - previous[i]
            if diff > 0 {
                flux += diff
            }
        }
        
        return flux / Float(maxBand)
    }
    
    // MARK: - Adaptive Threshold
    
    private func computeAdaptiveThreshold() -> Float {
        guard !history.isEmpty else { return 0.01 }
        
        // Compute median of recent flux values
        let sorted = history.sorted()
        let median = sorted[sorted.count / 2]
        
        // Compute mean of top half for more sensitivity
        let topHalf = sorted[sorted.count / 2...]
        let mean = topHalf.reduce(0, +) / Float(max(1, topHalf.count))
        
        // Use median + offset for threshold
        let threshold = max(median * thresholdMultiplier, mean * 0.8)
        
        return max(threshold, 0.001)
    }
    
    // MARK: - Energy Onset
    
    private func computeEnergyOnset(bass: Float) -> Float {
        energyHistory.append(bass)
        if energyHistory.count > energyHistorySize {
            energyHistory.removeFirst()
        }
        
        guard energyHistory.count >= 3 else { return 0 }
        
        let recent = energyHistory.suffix(3).reduce(0, +) / 3.0
        let average = energyHistory.reduce(0, +) / Float(energyHistory.count)
        
        if average > 0.01 && recent > average * 2.0 {
            return (recent - average) / average
        }
        
        return 0
    }
    
    // MARK: - Reset
    
    public func reset() {
        history.removeAll()
        energyHistory.removeAll()
        beatImpulse = 0
        refractoryTimer = 0
        previousSpectrum = nil
    }
}