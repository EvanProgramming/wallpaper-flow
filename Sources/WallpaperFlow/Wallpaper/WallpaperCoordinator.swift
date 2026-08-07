import AppKit
import Metal
import OSLog

// MARK: - Wallpaper Coordinator

@Observable
@MainActor
public final class WallpaperCoordinator {
    
    public var isActive: Bool = false
    public private(set) var wallpaperWindows: [UUID: WallpaperWindow] = [:]
    
    private let displayManager = DisplayManager()
    private var device: MTLDevice?
    private var library: MTLLibrary?
    
    public init() {
        setupMetal()
    }
    
    // MARK: - Metal Setup
    
    private func setupMetal() {
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            Logger.rendering.error("Failed to create Metal device")
            return
        }
        device = defaultDevice
        
        // Create default library
        library = try? device?.makeDefaultLibrary(bundle: .main)
        if library == nil {
            Logger.rendering.warning("No default Metal library found, will create at runtime")
        }
        
        Logger.rendering.info("Metal initialized: \(defaultDevice.name)")
    }
    
    // MARK: - Wallpaper Management
    
    public func applyWallpaper() {
        guard !isActive else { return }
        
        displayManager.refreshDisplays()
        
        for display in displayManager.activeDisplays {
            createWallpaperWindow(for: display)
        }
        
        isActive = true
        Logger.wallpaper.info("Wallpaper applied with \(self.wallpaperWindows.count) window(s)")
        
        // Start observing display changes
        setupDisplayObservation()
    }
    
    public func removeWallpaper() {
        guard isActive else { return }
        
        for (_, window) in wallpaperWindows {
            window.close()
        }
        wallpaperWindows.removeAll()
        isActive = false
        
        Logger.wallpaper.info("Wallpaper removed")
    }
    
    // MARK: - Window Creation
    
    private func createWallpaperWindow(for display: DisplayManager.DisplayInfo) {
        guard wallpaperWindows[display.uuid] == nil else { return }
        
        let window = WallpaperWindow(displayUUID: display.uuid, screen: display.screen)
        
        // Assign Metal device to the view
        if let metalView = window.getMetalView() {
            metalView.device = device
        }
        
        wallpaperWindows[display.uuid] = window
        Logger.wallpaper.debug("Created wallpaper window for display \(display.uuid)")
    }
    
    private func destroyWallpaperWindow(for displayUUID: UUID) {
        guard let window = wallpaperWindows.removeValue(forKey: displayUUID) else { return }
        window.close()
        Logger.wallpaper.debug("Destroyed wallpaper window for display \(displayUUID)")
    }
    
    // MARK: - Display Observation
    
    private var displayObserver: NSObjectProtocol?
    
    private func setupDisplayObservation() {
        displayObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDisplayChange()
        }
    }
    
    private func handleDisplayChange() {
        let oldDisplays = Set(wallpaperWindows.keys)
        displayManager.refreshDisplays()
        let newDisplays = Set(displayManager.activeDisplays.map { $0.uuid })
        
        // Remove displays that are no longer connected
        for uuid in oldDisplays.subtracting(newDisplays) {
            destroyWallpaperWindow(for: uuid)
        }
        
        // Add new displays
        for display in displayManager.activeDisplays where !oldDisplays.contains(display.uuid) {
            createWallpaperWindow(for: display)
        }
        
        // Update existing windows for resolution changes
        for display in displayManager.activeDisplays {
            if let window = wallpaperWindows[display.uuid] {
                window.updateFrame(for: display.screen)
            }
        }
    }
    
    // MARK: - Screenshot Prevention
    
    public func preventScreenCapture() {
        // Ensure windows are marked as non-recordable
        for (_, window) in wallpaperWindows {
            window.sharingType = .none
        }
    }
}