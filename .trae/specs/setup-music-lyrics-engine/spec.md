# Wallpaper Flow — Music & Lyrics Engine

## Why

The audio system provides raw PCM analysis, but the visual engine needs musical context to create a compelling experience. Without song metadata, artwork, and synchronized lyrics, the wallpaper remains a generic audio visualizer. This phase implements the complete music metadata pipeline and lyrics engine.

## What Changes

- Implement AppleMusicProvider using MusicKit's SystemMusicPlayer
- Implement ShazamKit generic detection for non-Apple Music sources
- Create TrackResolver for unified track identity management
- Implement ArtworkLoader with caching
- Implement PaletteExtractor for album artwork color analysis
- Implement LRCLIB lyrics provider
- Create LyricsParser for LRC format
- Implement LyricsSynchronizer with playback clock estimation
- Create LyricsCache for offline support
- Wire everything into AppState and event system

## Impact

- Affected specs: Music module, Lyrics module
- Affected code: New files in Music/ and Lyrics/ directories
- New dependencies: MusicKit, ShazamKit (already in Package.swift)
- Extends: TrackState, LyricsState, AppState

## ADDED Requirements

### Requirement: Apple Music Provider

The system SHALL provide real-time track information from Apple Music using MusicKit.

#### Scenario: Apple Music track detection
- **WHEN** Apple Music is playing
- **THEN** SystemMusicPlayer.shared.queue.currentEntry provides track metadata
- **AND** title, artist, album, artwork, duration are extracted
- **AND** playbackTime provides current position
- **AND** changes are published within 1 second

#### Scenario: Track change notification
- **WHEN** Apple Music changes track
- **THEN** a trackChanged event is published
- **AND** old artwork is faded out over 700-1500ms
- **AND** new artwork is loaded and faded in

### Requirement: ShazamKit Generic Detection

The system SHALL identify unknown music using ShazamKit streaming recognition.

#### Scenario: Generic music identification
- **WHEN** system audio is active and no MusicKit metadata is available
- **THEN** audio PCM is branched to SHSession.matchStreamingBuffer()
- **AND** recognition is triggered only after stable signal detection
- **AND** results are cached to avoid re-recognition
- **AND** re-recognition only occurs on audio discontinuity or timeout

#### Scenario: Recognition strategy
- **WHEN** audio starts
- **THEN** wait for stable signal (1-2 seconds of consistent audio)
- **THEN** call matchStreamingBuffer()
- **THEN** cache the result
- **THEN** only re-recognize on: major audio discontinuity, silence→new playback, or 5-minute timeout

### Requirement: Artwork Loader

The system SHALL load and cache album artwork images.

#### Scenario: Artwork loading
- **WHEN** track metadata provides artwork URL
- **THEN** artwork is downloaded asynchronously
- **AND** cached to disk at Application Support/Wallpaper Flow/cache/artwork/
- **AND** cache key is based on track ISRC or normalized title+artist
- **AND** artwork is never loaded on the main thread

### Requirement: Palette Extractor

The system SHALL extract a color palette from album artwork.

#### Scenario: Color extraction
- **WHEN** new artwork is loaded
- **THEN** artwork is downsampled to 32×32
- **THEN** K-Means clustering extracts 3-5 dominant color clusters
- **THEN** clusters are scored to produce: Primary, Secondary, Accent, Dark Base
- **THEN** palette is published for scene consumption
- **AND** palette transitions are smoothed over 1.5-3 seconds

#### Scenario: Palette filtering
- **WHEN** extracting colors
- **THEN** extremely dark, extremely bright, and low-saturation colors are filtered
- **THEN** the resulting palette is suitable for visual accent on dark backgrounds

### Requirement: Lyrics Provider (LRCLIB)

The system SHALL fetch synchronized lyrics from LRCLIB public API.

#### Scenario: Lyrics fetching
- **WHEN** track identity is known
- **THEN** LRCLIB API is queried with title, artist, album, duration
- **AND** synced lyrics are parsed from LRC format
- **AND** results are cached locally
- **AND** missing lyrics trigger automatic scene layout adjustment

#### Scenario: LRC parsing
- **WHEN** LRC data is received
- **THEN** timestamps are parsed as [mm:ss.xx] format
- **THEN** lines are converted to LyricLine objects with startTime and endTime
- **THEN** word-level tokens are extracted if available

### Requirement: Lyrics Synchronizer

The system SHALL synchronize lyrics display with playback position.

#### Scenario: Apple Music synchronization
- **WHEN** Apple Music is the source
- **THEN** playbackTime provides accurate position
- **THEN** current lyric line is determined by matching startTime/endTime
- **THEN** previous line (opacity 0.25), current line (opacity 1.0), next line (opacity 0.25)

#### Scenario: Generic playback synchronization
- **WHEN** ShazamKit identified the track
- **THEN** PlaybackClockEstimator estimates position using recognition offset + monotonic clock
- **THEN** lyrics offset is adjustable by user (-5.0s to +5.0s, 50ms steps)

#### Scenario: Lyrics visual behavior
- **WHEN** lyrics are displayed
- **THEN** transition uses blur + opacity + vertical translation over 250-450ms
- **THEN** current line responds subtly to bass, loudness, and beat
- **THEN** scale = 1.0 + beat * 0.015 (maximum subtlety)
- **THEN** no traditional karaoke coloring

### Requirement: Lyrics Cache

The system SHALL cache lyrics for offline access.

#### Scenario: Cache behavior
- **WHEN** lyrics are fetched
- **THEN** they are stored in Application Support/Wallpaper Flow/cache/lyrics/
- **THEN** cache key is based on track ISRC or normalized title+artist+duration
- **THEN** cached lyrics are used when network is unavailable
- **THEN** cache has TTL of 30 days

## MODIFIED Requirements

### Requirement: TrackState

Extend TrackState to support:
- `artwork: NSImage?` - loaded album artwork
- `palette: Palette` - extracted color palette
- `metadataSource: MetadataSource` - .appleMusic, .shazam, .none
- `confidence: Float` - metadata confidence level

## REMOVED Requirements

None.