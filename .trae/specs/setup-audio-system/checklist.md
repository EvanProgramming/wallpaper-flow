# Checkpoints

- [x] Ring buffer is lock-free with no allocation in write path
- [x] Core Audio system tap captures stereo PCM at 48 kHz
- [x] Microphone source captures audio via AVAudioEngine
- [x] AudioSession manages source switching
- [x] FFT produces correct 64-band logarithmic spectrum
- [x] Waveform is extracted at 512 samples
- [x] Beat detection triggers on spectral flux events
- [x] Gain normalization prevents clipping and amplifies quiet signals
- [x] Audio smoothing prevents visual jitter with asymmetric attack/release
- [x] AudioFeatureFrame is produced at ~93 Hz
- [x] All AudioFeatureFrame values are normalized 0.0 – 1.0
- [x] Build succeeds with no errors