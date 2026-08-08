import Foundation
import Accelerate
import OSLog

// MARK: - Audio Analyzer

public final class AudioAnalyzer: @unchecked Sendable {
    
    // FFT Constants
    private let fftSize: Int = 2048
    private let hopSize: Int = 512
    private let logBands: Int = 64
    private let waveformLength: Int = 512
    
    // FFT Resources
    private let fftSetup: FFTSetup
    private var window: [Float]
    private var fftBuffer: [Float]
    private var magnitudes: [Float]
    private var phaseBuffer: [Float]
    private var splitReal: [Float]
    private var splitImag: [Float]
    
    // Frequency mapping
    private let bandFrequencies: [Float]
    private let bandMappings: [(start: Int, end: Int)]
    
    // Smoothers for each feature
    private let smoother: AudioSmoother
    
    // Beat detector
    private let beatDetector: BeatDetector
    
    // Gain normalizer
    private let gainNormalizer: GainNormalizer
    
    // Ring buffer reference
    private var ringBuffer: AudioRingBuffer?
    
    // Processing state
    private var accumulatedFrames: [Float] = []
    private let sampleRate: Float = 48000.0
    
    public init() {
        // Create FFT setup using vDSP_create_fftsetup (widely available)
        let log2n = vDSP_Length(log2(Float(fftSize)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            fatalError("Failed to create vDSP FFT setup")
        }
        self.fftSetup = setup
        
        // Pre-compute Hann window
        self.window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        
        // Allocate buffers
        self.fftBuffer = [Float](repeating: 0, count: fftSize)
        self.magnitudes = [Float](repeating: 0, count: fftSize / 2)
        self.phaseBuffer = [Float](repeating: 0, count: fftSize / 2)
        self.splitReal = [Float](repeating: 0, count: fftSize / 2)
        self.splitImag = [Float](repeating: 0, count: fftSize / 2)
        
        // Pre-compute logarithmic frequency band mapping (inline, no self needed)
        let minFreq: Float = 20.0
        let maxFreq: Float = 20000.0
        let bins = fftSize / 2
        let binFreq = sampleRate / Float(fftSize)
        var mappings: [(start: Int, end: Int)] = []
        var frequencies: [Float] = []
        for i in 0..<logBands {
            let freq = minFreq * pow(maxFreq / minFreq, Float(i) / Float(logBands - 1))
            let nextFreq = i < logBands - 1 ? minFreq * pow(maxFreq / minFreq, Float(i + 1) / Float(logBands - 1)) : maxFreq
            let startBin = max(0, Int(freq / binFreq))
            let endBin = min(bins - 1, Int(nextFreq / binFreq))
            mappings.append((startBin, endBin))
            frequencies.append(freq)
        }
        self.bandMappings = mappings
        self.bandFrequencies = frequencies
        
        // Initialize sub-components
        self.smoother = AudioSmoother()
        self.beatDetector = BeatDetector()
        self.gainNormalizer = GainNormalizer()
    }
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }
    
    // MARK: - Configuration
    
    public func setRingBuffer(_ buffer: AudioRingBuffer) {
        self.ringBuffer = buffer
    }
    
    // MARK: - Processing
    
    public func processNextFrame() -> AudioFeatureFrame? {
        guard let ringBuffer = ringBuffer else { return nil }
        
        // Read frames from ring buffer
        let readFrames = 1024
        var tempBuffer = [Float](repeating: 0, count: readFrames * 2)
        let framesRead = ringBuffer.read(&tempBuffer, frameCount: readFrames)
        
        guard framesRead > 0 else { return nil }
        
        // Accumulate frames for FFT processing
        accumulatedFrames.append(contentsOf: tempBuffer[0..<(framesRead * 2)])
        
        // Keep only what we need
        let maxAccumulated = fftSize * 4 // Keep some history
        if accumulatedFrames.count > maxAccumulated {
            accumulatedFrames.removeFirst(accumulatedFrames.count - maxAccumulated)
        }
        
        // Process FFT when we have enough frames
        guard accumulatedFrames.count >= fftSize * 2 else { return nil }
        
        // Take the latest fftSize samples (left channel for now)
        let startIdx = accumulatedFrames.count - fftSize * 2
        let interleavedRange = accumulatedFrames[startIdx..<startIdx + fftSize * 2]
        var leftChannel = Array(interleavedRange.striding(by: 2))
        var rightChannel = Array(interleavedRange.dropFirst().striding(by: 2))
        
        // Ensure we have exactly fftSize samples
        if leftChannel.count < fftSize {
            leftChannel.append(contentsOf: [Float](repeating: 0, count: fftSize - leftChannel.count))
            rightChannel.append(contentsOf: [Float](repeating: 0, count: fftSize - rightChannel.count))
        }
        
        // Apply window
        vDSP_vmul(leftChannel, 1, window, 1, &fftBuffer, 1, vDSP_Length(fftSize))
        let leftMagnitudes = computeMagnitudes(from: fftBuffer)
        
        vDSP_vmul(rightChannel, 1, window, 1, &fftBuffer, 1, vDSP_Length(fftSize))
        let rightMagnitudes = computeMagnitudes(from: fftBuffer)
        
        // Compute log bands
        let leftBands = mapToLogBands(magnitudes: leftMagnitudes)
        let rightBands = mapToLogBands(magnitudes: rightMagnitudes)
        
        // Average for mono bands
        let monoBands = zip(leftBands, rightBands).map { ($0 + $1) * 0.5 }
        
        // Extract waveform (downsample from accumulated frames)
        let waveformStride = max(1, (framesRead * 2) / waveformLength)
        var waveformL = [Float](repeating: 0, count: waveformLength)
        var waveformR = [Float](repeating: 0, count: waveformLength)
        
        let wfStartIdx = max(0, accumulatedFrames.count - waveformLength * 2 * waveformStride)
        let wfSource: [Float] = Array(accumulatedFrames[wfStartIdx..<accumulatedFrames.count])
        let leftWF: [Float] = Array(wfSource.striding(by: 2))
        let rightWF: [Float] = Array(wfSource.dropFirst().striding(by: 2))
        
        for i in 0..<min(waveformLength, leftWF.count) {
            waveformL[i] = leftWF[i]
            waveformR[i] = rightWF[i]
        }
        
        // Compute RMS
        var meanSquareL: Float = 0
        vDSP_measqv(leftMagnitudes, 1, &meanSquareL, vDSP_Length(leftMagnitudes.count))
        var meanSquareR: Float = 0
        vDSP_measqv(rightMagnitudes, 1, &meanSquareR, vDSP_Length(rightMagnitudes.count))
        let rmsL = sqrt(meanSquareL)
        let rmsR = sqrt(meanSquareR)
        let rms = (rmsL + rmsR) * 0.5
        let peak = max(leftMagnitudes.max() ?? 0, rightMagnitudes.max() ?? 0)
        
        // Compute loudness (simple RMS-based)
        let loudness = min(1.0, rms * 3.0)
        
        // Extract frequency bands
        let subBass = bandAverage(monoBands, start: 0, end: 2)
        let bass = bandAverage(monoBands, start: 2, end: 6)
        let lowMid = bandAverage(monoBands, start: 6, end: 12)
        let mid = bandAverage(monoBands, start: 12, end: 24)
        let highMid = bandAverage(monoBands, start: 24, end: 36)
        let treble = bandAverage(monoBands, start: 36, end: 52)
        let air = bandAverage(monoBands, start: 52, end: 63)
        
        // Compute stereo balance and width
        let stereoBalance = computeStereoBalance(leftBands: leftBands, rightBands: rightBands)
        let stereoWidth = computeStereoWidth(leftBands: leftBands, rightBands: rightBands)
        
        // Beat detection
        let beat = beatDetector.process(spectrum: monoBands, bass: bass)
        
        // Gain normalization
        let normalizedLoudness = gainNormalizer.process(loudness)
        
        // Apply smoothing
        let smoothedBass = smoother.smooth(value: bass, for: .bass)
        let smoothedMid = smoother.smooth(value: mid, for: .mid)
        let smoothedTreble = smoother.smooth(value: treble, for: .treble)
        let smoothedBeat = smoother.smooth(value: beat, for: .beat)
        let smoothedLoudness = smoother.smooth(value: normalizedLoudness, for: .loudness)
        
        // Build feature frame
        var frame = AudioFeatureFrame(
            timestamp: CFAbsoluteTimeGetCurrent(),
            rms: rms.normalizedToZeroOne(),
            peak: peak.normalizedToZeroOne(),
            loudness: smoothedLoudness.normalizedToZeroOne(),
            subBass: subBass.normalizedToZeroOne(),
            bass: smoothedBass.normalizedToZeroOne(),
            lowMid: lowMid.normalizedToZeroOne(),
            mid: smoothedMid.normalizedToZeroOne(),
            highMid: highMid.normalizedToZeroOne(),
            treble: smoothedTreble.normalizedToZeroOne(),
            air: air.normalizedToZeroOne(),
            beatImpulse: smoothedBeat.normalizedToZeroOne(),
            onsetStrength: beat.normalizedToZeroOne(),
            stereoBalance: stereoBalance,
            stereoWidth: stereoWidth,
            spectrum: monoBands.map { $0.normalizedToZeroOne() },
            waveformL: waveformL,
            waveformR: waveformR
        )
        
        // Trim accumulated frames (keep last hopSize for overlap)
        if accumulatedFrames.count > fftSize * 2 {
            accumulatedFrames.removeFirst(accumulatedFrames.count - fftSize * 2)
        }
        
        return frame
    }
    
    // MARK: - FFT Processing
    
    private func computeMagnitudes(from buffer: [Float]) -> [Float] {
        // For vDSP_fft_zrip with a real input of length N:
        // Pack as: real[i] = buffer[2*i], imag[i] = buffer[2*i+1] for i in 0..<N/2
        let halfSize = fftSize / 2
        for i in 0..<halfSize {
            splitReal[i] = buffer[i * 2]
            splitImag[i] = buffer[i * 2 + 1]
        }
        
        let log2n = vDSP_Length(log2(Float(fftSize)))
        
        // Perform forward FFT using split complex
        splitReal.withUnsafeMutableBufferPointer { realBuf in
            splitImag.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))
            }
        }
        
        // Compute squared magnitudes (|real|^2 + |imag|^2)
        var magnitudes = [Float](repeating: 0, count: halfSize)
        splitReal.withUnsafeMutableBufferPointer { realBuf in
            splitImag.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(halfSize))
            }
        }
        
        // Take square root to get magnitude (Float version)
        var sqrtMag = magnitudes
        var count = Int32(halfSize)
        vvsqrtf(&sqrtMag, magnitudes, &count)
        
        // Normalize by FFT size
        var scale = 2.0 / Float(fftSize)
        vDSP_vsmul(sqrtMag, 1, &scale, &sqrtMag, 1, vDSP_Length(halfSize))
        
        return sqrtMag
    }
    
    // MARK: - Log Band Mapping
    
    private func computeLogBands(mappings: inout [(start: Int, end: Int)], frequencies: inout [Float]) {
        let minFreq: Float = 20.0
        let maxFreq: Float = 20000.0
        let bins = fftSize / 2
        let binFreq = sampleRate / Float(fftSize)
        
        for i in 0..<logBands {
            let freq = minFreq * pow(maxFreq / minFreq, Float(i) / Float(logBands - 1))
            let nextFreq = i < logBands - 1 ? minFreq * pow(maxFreq / minFreq, Float(i + 1) / Float(logBands - 1)) : maxFreq
            
            let startBin = max(0, Int(freq / binFreq))
            let endBin = min(bins - 1, Int(nextFreq / binFreq))
            
            mappings.append((startBin, endBin))
            frequencies.append(freq)
        }
    }
    
    private func mapToLogBands(magnitudes: [Float]) -> [Float] {
        var bands = [Float](repeating: 0, count: logBands)
        
        for i in 0..<logBands {
            let mapping = bandMappings[i]
            var sum: Float = 0
            let count = max(1, mapping.end - mapping.start + 1)
            
            for bin in mapping.start...mapping.end {
                guard bin < magnitudes.count else { break }
                sum += magnitudes[bin]
            }
            
            bands[i] = sum / Float(count)
        }
        
        // Apply compression to make more visually appealing
        for i in 0..<bands.count {
            bands[i] = sqrt(bands[i]) // Square root compression
        }
        
        return bands
    }
    
    private func bandAverage(_ bands: [Float], start: Int, end: Int) -> Float {
        let count = max(1, end - start + 1)
        let range = bands[start...end]
        return range.reduce(0, +) / Float(count)
    }
    
    // MARK: - Stereo Analysis
    
    private func computeStereoBalance(leftBands: [Float], rightBands: [Float]) -> Float {
        let leftEnergy = leftBands.reduce(0, +)
        let rightEnergy = rightBands.reduce(0, +)
        let total = leftEnergy + rightEnergy
        guard total > 0 else { return 0 }
        // -1 = full left, 0 = center, 1 = full right
        return (rightEnergy - leftEnergy) / total
    }
    
    private func computeStereoWidth(leftBands: [Float], rightBands: [Float]) -> Float {
        var diffSum: Float = 0
        for i in 0..<min(leftBands.count, rightBands.count) {
            diffSum += abs(leftBands[i] - rightBands[i])
        }
        return min(1.0, diffSum / Float(min(leftBands.count, rightBands.count)))
    }
}

// MARK: - Array Striding Extension

extension Array {
    func striding(by n: Int) -> UnfoldSequence<Element, Int> {
        return sequence(state: 0) { state in
            guard state < self.count else { return nil }
            defer { state += n }
            return self[state]
        }
    }
}

extension ArraySlice {
    func striding(by n: Int) -> UnfoldSequence<Element, Int> {
        return sequence(state: 0) { state in
            guard state < self.count else { return nil }
            defer { state += n }
            return self[self.startIndex + state]
        }
    }
}