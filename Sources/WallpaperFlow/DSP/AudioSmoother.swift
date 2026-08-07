import Foundation

// MARK: - Feature Type

public enum SmoothableFeature: CaseIterable {
    case beat
    case waveform
    case spectrum
    case bass
    case mid
    case treble
    case loudness
    case color
    case background
}

// MARK: - Smoothing Parameters

public struct SmoothingParams: Sendable {
    public let attackSeconds: Float
    public let releaseSeconds: Float
    
    public init(attackSeconds: Float, releaseSeconds: Float) {
        self.attackSeconds = attackSeconds
        self.releaseSeconds = releaseSeconds
    }
    
    /// Convert time constants to coefficient at given frame rate
    public func coefficient(for frameRate: Float, isAttack: Bool) -> Float {
        let time = isAttack ? attackSeconds : releaseSeconds
        guard time > 0 else { return 1.0 }
        return exp(-1.0 / (time * frameRate))
    }
}

// MARK: - Audio Smoother

public final class AudioSmoother: @unchecked Sendable {
    
    private let frameRate: Float = 93.0 // ~93 Hz
    
    // Per-feature parameters
    private let params: [SmoothableFeature: SmoothingParams]
    
    // Current smoothed values
    private var smoothedValues: [SmoothableFeature: Float] = [:]
    
    public init() {
        // Define asymmetric attack/release times per feature
        var params: [SmoothableFeature: SmoothingParams] = [:]
        
        // Beat: fastest response
        params[.beat] = SmoothingParams(attackSeconds: 0.015, releaseSeconds: 0.08)
        
        // Waveform: fast
        params[.waveform] = SmoothingParams(attackSeconds: 0.02, releaseSeconds: 0.05)
        
        // Spectrum: medium
        params[.spectrum] = SmoothingParams(attackSeconds: 0.03, releaseSeconds: 0.12)
        
        // Bass: medium-fast
        params[.bass] = SmoothingParams(attackSeconds: 0.025, releaseSeconds: 0.10)
        
        // Mid: medium
        params[.mid] = SmoothingParams(attackSeconds: 0.03, releaseSeconds: 0.12)
        
        // Treble: medium-fast
        params[.treble] = SmoothingParams(attackSeconds: 0.02, releaseSeconds: 0.10)
        
        // Loudness: slow
        params[.loudness] = SmoothingParams(attackSeconds: 0.05, releaseSeconds: 0.18)
        
        // Color: very slow
        params[.color] = SmoothingParams(attackSeconds: 0.5, releaseSeconds: 2.0)
        
        // Background: slowest
        params[.background] = SmoothingParams(attackSeconds: 0.2, releaseSeconds: 1.0)
        
        self.params = params
        
        // Initialize all values to 0
        for feature in SmoothableFeature.allCases {
            smoothedValues[feature] = 0
        }
    }
    
    // MARK: - Smoothing
    
    /// Smooth a single value using asymmetric attack/release
    /// - Parameters:
    ///   - value: Raw input value
    ///   - feature: Feature type to determine smoothing parameters
    /// - Returns: Smoothed value
    public func smooth(value: Float, for feature: SmoothableFeature) -> Float {
        guard let param = params[feature] else { return value }
        
        let current = smoothedValues[feature] ?? 0
        let isAttack = value > current
        let coeff = param.coefficient(for: frameRate, isAttack: isAttack)
        
        let smoothed = current * coeff + value * (1.0 - coeff)
        smoothedValues[feature] = smoothed
        
        return smoothed
    }
    
    /// Smooth an array of values (for spectrum and waveform)
    /// - Parameters:
    ///   - values: Array of raw input values
    ///   - feature: Feature type
    /// - Returns: Array of smoothed values
    public func smoothArray(_ values: [Float], for feature: SmoothableFeature) -> [Float] {
        return values.map { smooth(value: $0, for: feature) }
    }
    
    // MARK: - Reset
    
    public func reset() {
        for feature in SmoothableFeature.allCases {
            smoothedValues[feature] = 0
        }
    }
}