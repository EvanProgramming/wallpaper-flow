# Wallpaper Flow — Project Foundation & Core Architecture

## Why

This project is a greenfield macOS application. There is no existing code, no Xcode project, and no module structure. The first phase must establish the complete project skeleton, core architecture patterns, and foundational modules that all subsequent phases will build upon.

## What Changes

- Create Xcode project with proper bundle identifier, signing, and macOS 15.0+ target
- Establish the full directory structure matching the PRD module layout
- Implement App entry point with SwiftUI lifecycle and MenuBar app pattern
- Build WallpaperCoordinator, WallpaperWindow, and DisplayManager for desktop-level wallpaper windows across multiple displays
- Implement AppState management using Observable macro and AsyncStream event system
- Create SettingsStore with JSON persistence in Application Support
- Implement MenuBarController with proper menu structure
- Establish core protocol definitions (AudioSource, NowPlayingProvider, LyricsProvider, WallpaperScene)
- Define all shared data models (TrackState, AudioFeatureFrame, LyricsState, etc.)
- Set up project scaffolding for all empty modules
- Configure Info.plist with required permissions descriptions
- Configure entitlements for audio capture, microphone, and MusicKit

## Impact

- Affected specs: Entire project foundation
- Affected code: All new files — no existing code to modify

## ADDED Requirements

### Requirement: Xcode Project Configuration
The system SHALL provide a properly configured Xcode project targeting macOS 15.0+ with Apple Silicon as primary architecture.

#### Scenario: Project builds successfully
- **WHEN** the project is opened in Xcode and built
- **THEN** it compiles without errors and produces a runnable macOS application bundle

### Requirement: Desktop Wallpaper Windows
The system SHALL create borderless, non-interactive NSWindow instances at the `desktopWindow` level that sit behind Finder icons.

#### Scenario: Wallpaper appears on all desktops
- **WHEN** the application launches
- **THEN** a wallpaper window is created for each connected display
- **AND** the window appears behind Finder desktop icons
- **AND** the window joins all Spaces
- **AND** the window is stationary in Mission Control
- **AND** the window ignores mouse events
- **AND** the window is opaque and shadowless

#### Scenario: Display hotplug
- **WHEN** a new display is connected
- **THEN** a new wallpaper window is created for that display
- **WHEN** a display is removed
- **THEN** the corresponding wallpaper window is destroyed
- **AND** no crash occurs

### Requirement: Menu Bar App
The system SHALL run as a menu bar application with no dock icon after initial configuration.

#### Scenario: Menu bar menu
- **WHEN** the user clicks the menu bar icon
- **THEN** a menu is shown with: Now Playing info, Pause Visuals toggle, Change Scene submenu, Audio Source submenu, Open Wallpaper Flow, Settings, Quit

### Requirement: App State Management
The system SHALL provide centralized state management using @Observable and AsyncStream-based event system.

#### Scenario: State changes propagate
- **WHEN** any state property changes (e.g., currentTrack, audioLevels)
- **THEN** all observing components receive the update
- **AND** no NotificationCenter spam occurs

### Requirement: Settings Persistence
The system SHALL persist user settings to `Application Support/Wallpaper Flow/settings.json`.

#### Scenario: Settings save and restore
- **WHEN** the user changes a setting
- **THEN** it is immediately written to disk
- **WHEN** the app restarts
- **THEN** all settings are restored from disk

### Requirement: Core Protocol Definitions
The system SHALL define the following protocols as public interfaces:
- `AudioSource` — abstract audio capture
- `NowPlayingProvider` — music metadata
- `LyricsProvider` — synchronized lyrics
- `WallpaperScene` — Metal-rendered visual scene

### Requirement: Shared Data Models
The system SHALL define the following shared data structures in a dedicated `Models/` module:
- `TrackState` — current track metadata (id, title, artist, album, artwork, duration, playbackPosition, playbackState, isrc, metadataSource, confidence)
- `AudioFeatureFrame` — real-time audio analysis (rms, peak, loudness, bass, mid, treble, beatImpulse, spectrum, waveformL, waveformR, stereoBalance, stereoWidth)
- `LyricsState` — current lyrics state (lines, currentLineIndex, offset, availability)
- `AppState` — top-level app state container
- `AudioState` — audio source state
- `VisualState` — scene and rendering state
- `DisplayState` — display configuration
- `SceneConfig` — per-scene configuration
- `PerformanceMode` — enum (automatic, quality, balanced, batterySaver)
- `Palette` — album color palette (primary, secondary, accent, darkBase)

### Requirement: Module Directory Structure
The system SHALL create the following directory structure under the project root, matching the PRD architecture:

```
WallpaperFlow/
  App/
  Wallpaper/
  Audio/
  DSP/
  Music/
  Lyrics/
  Rendering/
  Scenes/
    AuroraFlow/
    GlassWave/
    Orbit/
    CinematicLyrics/
  Shaders/
  UI/
  Persistence/
  Models/
  Extensions/
```