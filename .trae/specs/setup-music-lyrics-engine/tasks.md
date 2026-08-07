# Tasks

- [x] Task 1: Implement Apple Music NowPlaying provider
  - [x] Create `AppleMusicProvider` conforming to `NowPlayingProvider`
  - [x] Use `SystemMusicPlayer.shared.queue.currentEntry` for track metadata
  - [x] Observe playback state changes (playing, paused, track change)
  - [x] Extract title, artist, album, artwork, duration, playbackTime
  - [x] Publish track changes via AppEventBus

- [x] Task 2: Implement ShazamKit generic detection
  - [x] Create `ShazamProvider` with streaming recognition
  - [x] Branch audio PCM to `SHSession.matchStreamingBuffer()`
  - [x] Implement stable signal detection before recognition
  - [x] Implement recognition caching strategy
  - [x] Implement re-recognition on audio discontinuity or timeout

- [x] Task 3: Implement Artwork loader with caching
  - [x] Create `ArtworkLoader` for async artwork loading
  - [x] Implement disk cache at Application Support/Wallpaper Flow/cache/artwork/
  - [x] Cache key based on ISRC or normalized title+artist
  - [x] Load artwork off main thread

- [x] Task 4: Implement Palette extractor
  - [x] Create `PaletteExtractor` using K-Means clustering
  - [x] Downsample artwork to 32×32
  - [x] Extract 3-5 dominant color clusters
  - [x] Filter dark/bright/low-saturation colors
  - [x] Produce Primary, Secondary, Accent, Dark Base palette
  - [x] Implement smooth palette transitions (1.5-3 seconds)

- [x] Task 5: Implement LRCLIB lyrics provider
  - [x] Create `LRCLIBProvider` conforming to `LyricsProvider`
  - [x] Query LRCLIB API with title, artist, album, duration
  - [x] Parse synced lyrics from LRC format
  - [x] Handle missing lyrics gracefully
  - [x] Cache lyrics locally

- [x] Task 6: Implement LRC parser
  - [x] Create `LyricsParser` for LRC format
  - [x] Parse [mm:ss.xx] timestamps
  - [x] Convert to LyricLine objects with startTime/endTime
  - [x] Extract word-level tokens if available
  - [x] Handle malformed LRC data gracefully

- [x] Task 7: Implement Lyrics synchronizer
  - [x] Create `LyricsSynchronizer` for playback position tracking
  - [x] Use Apple Music playbackTime for accurate sync
  - [x] Implement PlaybackClockEstimator for generic detection
  - [x] Support user-adjustable offset (-5.0s to +5.0s, 50ms steps)
  - [x] Return current/previous/next lyric lines

- [x] Task 8: Implement Lyrics cache
  - [x] Create `LyricsCache` for offline lyrics storage
  - [x] Store at Application Support/Wallpaper Flow/cache/lyrics/
  - [x] Cache key based on ISRC or normalized title+artist+duration
  - [x] 30-day TTL

- [x] Task 9: Extend TrackState and LyricsState models
  - [x] Add artwork, palette, metadataSource, confidence to TrackState
  - [x] Ensure LyricsState supports all line states
  - [x] Wire into AppState observable

- [x] Task 10: Wire up Music & Lyrics in AppState
  - [x] Connect AppleMusicProvider to AppState via MusicManager
  - [x] Connect ShazamProvider to audio session via MusicManager
  - [x] Connect lyric engine to AppState via MusicManager
  - [x] Handle source switching in AppDelegate
  - [x] Fix build errors across all modules
  - [x] Verify build succeeds

# Task Dependencies
- [Task 1] and [Task 2] can be parallelized
- [Task 3] depends on [Task 1], [Task 2]
- [Task 4] depends on [Task 3]
- [Task 5] and [Task 6] can be parallelized
- [Task 7] depends on [Task 5], [Task 6]
- [Task 8] depends on [Task 5]
- [Task 9] is independent - can be done in parallel
- [Task 10] depends on [Task 1], [Task 2], [Task 3], [Task 4], [Task 7], [Task 8], [Task 9]