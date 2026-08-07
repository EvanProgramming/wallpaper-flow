import Foundation

// MARK: - Audio Feature Frame

public struct AudioFeatureFrame: Sendable {
    public var timestamp: Double
    
    // Energy
    public var rms: Float
    public var peak: Float
    public var loudness: Float
    
    // Frequency Bands
    public var subBass: Float
    public var bass: Float
    public var lowMid: Float
    public var mid: Float
    public var highMid: Float
    public var treble: Float
    public var air: Float
    
    // Beat
    public var beatImpulse: Float
    public var onsetStrength: Float
    
    // Stereo
    public var stereoBalance: Float
    public var stereoWidth: Float
    
    // Full Data
    public var spectrum: [Float]
    public var waveformL: [Float]
    public var waveformR: [Float]
    
    public init(
        timestamp: Double = 0,
        rms: Float = 0,
        peak: Float = 0,
        loudness: Float = 0,
        subBass: Float = 0,
        bass: Float = 0,
        lowMid: Float = 0,
        mid: Float = 0,
        highMid: Float = 0,
        treble: Float = 0,
        air: Float = 0,
        beatImpulse: Float = 0,
        onsetStrength: Float = 0,
        stereoBalance: Float = 0,
        stereoWidth: Float = 0,
        spectrum: [Float] = Array(repeating: 0, count: 64),
        waveformL: [Float] = Array(repeating: 0, count: 512),
        waveformR: [Float] = Array(repeating: 0, count: 512)
    ) {
        self.timestamp = timestamp
        self.rms = rms
        self.peak = peak
        self.loudness = loudness
        self.subBass = subBass
        self.bass = bass
        self.lowMid = lowMid
        self.mid = mid
        self.highMid = highMid
        self.treble = treble
        self.air = air
        self.beatImpulse = beatImpulse
        self.onsetStrength = onsetStrength
        self.stereoBalance = stereoBalance
        self.stereoWidth = stereoWidth
        self.spectrum = spectrum
        self.waveformL = waveformL
        self.waveformR = waveformR
    }
    
    public static let zero = AudioFeatureFrame()
}

// MARK: - Frequency Band Configuration

public struct FrequencyBands: Sendable {
    public static let subBassRange: ClosedRange<Float> = 20...60
    public static let bassRange: ClosedRange<Float> = 60...180
    public static let lowMidRange: ClosedRange<Float> = 180...500
    public static let midRange: ClosedRange<Float> = 500...2000
    public static let highMidRange: ClosedRange<Float> = 2000...6000
    public static let trebleRange: ClosedRange<Float> = 6000...16000
    public static let airRange: ClosedRange<Float> = 16000...20000
}