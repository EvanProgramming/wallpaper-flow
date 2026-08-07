# Wallpaper Flow — Audio System

## Why

The audio system is the sensory foundation of Wallpaper Flow. Without real-time audio capture and analysis, no visual scene can respond to music. This phase implements the complete audio pipeline: capture, ring buffer, DSP analysis, and feature frame generation.

## What Changes

- Implement Core Audio Process Tap for system audio capture (macOS 14.2+)
- Implement Microphone audio source using AVAudioEngine
- Create lock-free ring buffer for audio callback → DSP worker
- Build DSP engine: FFT (vDSP), logarithmic spectrum mapping, waveform extraction
- Implement beat/onset detection using spectral flux
- Create gain normalization with rolling RMS/peak
- Implement audio smoothing (asymmetric attack/release)
- Wire AudioFeatureFrame generation at ~93 Hz
- Add AudioSession management for permissions

## Impact

- Affected specs: Audio module, DSP module
- Affected code: New files in Audio/ and DSP/ directories

## ADDED Requirements

### Requirement: Core Audio System Tap
The system SHALL capture system audio using Core Audio Process Tap API.

#### Scenario: System audio capture starts
- **WHEN** the user selects System Audio source
- **THEN** a CATapDescription is created with stereo global tap
- **AND** Wallpaper Flow process is excluded from the tap
- **AND** PCM data is delivered at 48 kHz, Float32, stereo
- **AND** data is written to the ring buffer

### Requirement: Microphone Capture
The system SHALL capture microphone audio using AVAudioEngine.

#### Scenario: Microphone capture starts
- **WHEN** the user selects Microphone source
- **THEN** AVAudioEngine inputNode tap is installed
- **AND** PCM data is resampled to 48 kHz if needed
- **AND** data is written to the ring buffer

### Requirement: Lock-Free Ring Buffer
The system SHALL provide a single-producer, single-consumer lock-free ring buffer.

#### Scenario: Audio callback writes to ring buffer
- **WHEN** audio callback delivers PCM frames
- **THEN** frames are written to the ring buffer without blocking
- **AND** no memory allocation occurs in the callback

### Requirement: DSP Engine
The system SHALL perform real-time audio analysis using Accelerate framework.

#### Scenario: FFT processing
- **WHEN** DSP worker reads from ring buffer
- **THEN** Hann window is applied
- **THEN** 2048-point FFT is computed
- **THEN** magnitude spectrum is calculated
- **THEN** 64 logarithmic bands are mapped (20 Hz – 20 kHz)
- **THEN** waveform (512 samples) is extracted
- **THEN** AudioFeatureFrame is produced at ~93 Hz

### Requirement: Beat Detection
The system SHALL detect beats using spectral flux with adaptive threshold.

#### Scenario: Beat detection
- **WHEN** spectral flux exceeds adaptive threshold
- **THEN** beatImpulse is set to 1.0 with exponential decay
- **AND** refractory period prevents double triggering

### Requirement: Gain Normalization
The system SHALL normalize audio levels using rolling RMS/peak estimation.

#### Scenario: Automatic gain normalization
- **WHEN** audio levels change
- **THEN** rolling RMS (5-10 second window) is maintained
- **THEN** normalized energy is computed
- **AND** quiet songs are amplified, loud songs are attenuated

### Requirement: Audio Smoothing
The system SHALL apply asymmetric smoothing with different attack/release times per feature.

#### Scenario: Smoothing parameters
- **WHEN** audio features are computed
- **THEN** beat uses fastest smoothing (attack: 15ms, release: 80ms)
- **THEN** waveform uses fast smoothing
- **THEN** spectrum uses medium smoothing
- **THEN** background energy uses slow smoothing
- **THEN** color transitions use very slow smoothing