import AppKit
import Combine
import OSLog

// MARK: - App Delegate

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    
    private let appState = AppState()
    private var menuBarController: MenuBarController?
    private var wallpaperCoordinator: WallpaperCoordinator?
    private var settingsStore: SettingsStore?
    private var cancellables = Set<AnyCancellable>()
    
    public override init() {
        super.init()
    }
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.app.info("Wallpaper Flow starting...")
        
        // Initialize components
        settingsStore = SettingsStore(appState: appState)
        menuBarController = MenuBarController(appState: appState)
        wallpaperCoordinator = WallpaperCoordinator()
        
        // Restore settings
        settingsStore?.restore()
        
        // Subscribe to events
        setupEventSubscription()
        
        // Auto-apply wallpaper if it was active
        if appState.visualState.isRendering {
            wallpaperCoordinator?.applyWallpaper()
        }
        
        Logger.app.info("Wallpaper Flow started successfully")
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        Logger.app.info("Wallpaper Flow terminating...")
        
        // Save settings
        settingsStore?.save()
        
        // Remove wallpaper
        wallpaperCoordinator?.removeWallpaper()
        
        // Publish termination event
        AppEventBus.shared.publish(.appWillTerminate)
        
        cancellables.removeAll()
    }
    
    public func applicationDidChangeScreenParameters(_ notification: Notification) {
        Logger.app.info("Screen parameters changed")
    }
    
    // MARK: - Event Subscription
    
    private func setupEventSubscription() {
        AppEventBus.shared.publisher()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleEvent(event)
            }
            .store(in: &cancellables)
    }
    
    private func handleEvent(_ event: AppEvent) {
        switch event {
        case .displayAdded, .displayRemoved:
            Logger.app.debug("Display configuration changed")
        case .sceneChanged(let sceneID):
            Logger.app.debug("Scene changed to: \(sceneID)")
            settingsStore?.save()
        case .trackChanged(let track):
            Logger.app.debug("Track changed: \(track.title)")
            menuBarController?.updateNowPlaying()
        case .paletteChanged(_):
            Logger.app.debug("Palette changed")
        case .appWillTerminate:
            break
        case .audioStarted:
            Logger.app.debug("Audio started")
        case .audioStopped:
            Logger.app.debug("Audio stopped")
        case .audioPermissionDenied:
            Logger.app.warning("Audio permission denied")
        case .trackPaused:
            Logger.app.debug("Track paused")
        case .trackResumed:
            Logger.app.debug("Track resumed")
        case .lyricsLoaded:
            Logger.app.debug("Lyrics loaded")
        case .lyricsUnavailable:
            Logger.app.debug("Lyrics unavailable")
        case .appDidBecomeActive:
            Logger.app.debug("App became active")
        case .appDidResignActive:
            Logger.app.debug("App resigned active")
        case .thermalStateChanged(let state):
            Logger.app.debug("Thermal state changed to: \(state.rawValue)")
        }
    }
}