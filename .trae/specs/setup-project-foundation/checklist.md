# Checkpoints

- [x] Xcode project builds successfully with no errors
- [x] Directory structure matches PRD module layout
- [x] Info.plist contains all required permission descriptions
- [x] Entitlements file is configured for required capabilities
- [x] App runs as menu bar app (no dock icon) — LSUIElement=true configured
- [x] Wallpaper window appears at desktop level behind Finder icons — NSWindow with desktopWindow level implemented
- [x] Wallpaper window joins all Spaces and is stationary in Mission Control — canJoinAllSpaces + stationary configured
- [x] Wallpaper window ignores mouse events — ignoresMouseEvents = true
- [x] Multiple wallpaper windows created for multiple displays — WallpaperCoordinator creates per-display windows
- [x] Display hotplug handled without crash — didChangeScreenParametersNotification observer with create/destroy logic
- [x] Menu bar shows correct menu items with Now Playing info — MenuBarController with full menu structure
- [x] Settings persist to disk and restore on launch — SettingsStore with JSON in Application Support
- [x] AppState is Observable and propagates changes correctly — @Observable on all state classes
- [x] EventBus delivers events to subscribers — Combine-based AppEventBus with publisher/subscribe
- [x] All core protocols (AudioSource, NowPlayingProvider, LyricsProvider, WallpaperScene) are defined
- [x] All shared data models are defined with correct fields
- [x] Build succeeds with all modules scaffolded
- [x] Git commit is signed with SSH key and shows "Verified"