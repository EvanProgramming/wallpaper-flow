# Tasks

- [x] Task 1: Create Xcode project and configure build settings
  - [x] Create Xcode project with bundle identifier `com.wallpaperflow.app`
  - [x] Set macOS 15.0 deployment target, Apple Silicon arch
  - [x] Configure Info.plist with `NSAudioCaptureUsageDescription`, `NSMicrophoneUsageDescription`
  - [x] Configure entitlements for audio capture, microphone, MusicKit, network
  - [x] Set app to run as Menu Bar app (LSUIElement = true)
  - [x] Create the full directory structure matching PRD module layout
  - [x] Remove Wallpaper Flow PRD doc from repo tracking (should not be in the app bundle)

- [x] Task 2: Implement shared data models
  - [x] Create `TrackState` struct
  - [x] Create `AudioFeatureFrame` struct
  - [x] Create `LyricLine` and `LyricToken` structs
  - [x] Create `LyricsState` struct
  - [x] Create `AppState`, `AudioState`, `VisualState`, `DisplayState` Observable classes
  - [x] Create `SceneConfig` struct
  - [x] Create `PerformanceMode` enum
  - [x] Create `Palette` struct
  - [x] Create `SceneID` typealias and `SceneType` enum

- [x] Task 3: Implement core protocols
  - [x] Create `AudioSource` protocol
  - [x] Create `NowPlayingProvider` protocol
  - [x] Create `LyricsProvider` protocol
  - [x] Create `WallpaperScene` protocol
  - [x] Create `AppEvent` enum for event system
  - [x] Create `AppEventBus` using Combine + AsyncStream

- [x] Task 4: Implement Wallpaper window system
  - [x] Create `WallpaperWindow` (NSWindow subclass) with desktop window level, no shadow, ignores mouse, joins all spaces, stationary
  - [x] Create `DisplayManager` that monitors `didChangeScreenParametersNotification`
  - [x] Create `WallpaperCoordinator` that manages per-display wallpaper windows
  - [x] Handle display hotplug: create/destroy windows accordingly

- [x] Task 5: Implement App entry and MenuBar
  - [x] Create `WallpaperFlowApp` SwiftUI app entry point
  - [x] Create `MenuBarController` with full menu structure
  - [x] Integrate MenuBarController with AppDelegate
  - [x] Implement LSUIElement behavior (no dock icon)

- [x] Task 6: Implement Settings persistence
  - [x] Create `SettingsStore` with JSON encoding/decoding
  - [x] Store settings at `Application Support/Wallpaper Flow/settings.json`
  - [x] Auto-save on change, restore on launch
  - [x] Create default settings

- [x] Task 7: Implement AppState integration
  - [x] Wire up AppState as the central @Observable state container
  - [x] Connect AppState to settings persistence
  - [x] Connect AppState to wallpaper windows
  - [x] Connect AppState to menu bar updates
  - [x] Verify build succeeds

# Task Dependencies
- [Task 1] must be completed before all other tasks
- [Task 2] and [Task 3] can be parallelized
- [Task 4] depends on [Task 1]
- [Task 5] depends on [Task 1]
- [Task 6] depends on [Task 1]
- [Task 7] depends on [Task 2], [Task 3], [Task 4], [Task 5], [Task 6]