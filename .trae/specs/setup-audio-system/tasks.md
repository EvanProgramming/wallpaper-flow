# Tasks

- [x] Task 1: Implement lock-free ring buffer
  - [x] Create `AudioRingBuffer` with fixed-size circular buffer
  - [x] Implement single-producer, single-consumer with atomic head/tail
  - [x] Support Float32 stereo frames
  - [x] No memory allocation in write path

- [x] Task 2: Implement Core Audio system tap source
  - [x] Create `CoreAudioSystemSource` conforming to AudioSource
  - [x] Use CATapDescription with stereo global tap
  - [x] Exclude self from tap
  - [x] Handle permission errors gracefully
  - [x] Implement start/stop lifecycle

- [x] Task 3: Implement Microphone source
  - [x] Create `MicrophoneSource` conforming to AudioSource
  - [x] Use AVAudioEngine with inputNode tap
  - [x] Resample to 48 kHz
  - [x] Handle permission errors

- [x] Task 4: Implement AudioSession manager
  - [x] Create `AudioSession` that manages current source
  - [x] Handle source switching
  - [x] Handle permission requests
  - [x] Provide current AudioFeatureFrame to observers

- [x] Task 5: Implement DSP engine
  - [x] Create `AudioAnalyzer` class
  - [x] Implement FFT using vDSP.FFT (2048-point, Hann window)
  - [x] Implement logarithmic spectrum mapping (64 bands, 20 Hz – 20 kHz)
  - [x] Implement waveform extraction (512 samples)
  - [x] Implement RMS/peak/loudness computation
  - [x] Implement stereo balance/width computation

- [x] Task 6: Implement beat detection
  - [x] Create `BeatDetector` with spectral flux algorithm
  - [x] Implement adaptive threshold with moving median
  - [x] Implement refractory filter
  - [x] Output beatImpulse with exponential decay

- [x] Task 7: Implement gain normalization
  - [x] Create `GainNormalizer` with rolling RMS/peak
  - [x] Implement 5-10 second rolling window
  - [x] Output normalized energy (0.0 – 1.0)

- [x] Task 8: Implement audio smoothing
  - [x] Create `AudioSmoother` with asymmetric attack/release
  - [x] Support per-feature smoothing parameters
  - [x] Wire into the DSP pipeline

- [x] Task 9: Wire up AudioSession in AppDelegate
  - [x] Connect AudioSession to AppState
  - [x] Handle source switching from menu bar
  - [x] Verify build succeeds

# Task Dependencies
- [Task 1] must be completed before [Task 5], [Task 6], [Task 7], [Task 8]
- [Task 2] and [Task 3] depend on [Task 1]
- [Task 4] depends on [Task 2], [Task 3]
- [Task 5] depends on [Task 1]
- [Task 6] depends on [Task 5]
- [Task 7] depends on [Task 5]
- [Task 8] depends on [Task 5]
- [Task 9] depends on [Task 4], [Task 5], [Task 6], [Task 7], [Task 8]