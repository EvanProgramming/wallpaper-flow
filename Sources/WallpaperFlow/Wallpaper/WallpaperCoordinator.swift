import AppKit
import Metal
import MetalKit
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
    private var renderers: [UUID: MetalRenderer] = [:]
    private var scene: WallpaperScene?

    // Audio source — set by AppDelegate to pipe data to renderers
    public weak var audioSession: AudioSession?

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

        // Try to load default library (from compiled .metallib in bundle)
        library = try? device?.makeDefaultLibrary(bundle: .main)
        if library == nil {
            Logger.rendering.warning("No default Metal library found, compiling from source")
            // Fallback: compile the shader source at runtime
            library = compileShaderLibrary(device: defaultDevice)
        }
        if library == nil {
            Logger.rendering.error("Failed to create Metal library")
        }

        Logger.rendering.info("Metal initialized: \(defaultDevice.name)")
    }

    private func compileShaderLibrary(device: MTLDevice) -> MTLLibrary? {
        // Look for the shader file in the app bundle
        guard let shaderURL = Bundle.main.url(forResource: "AuroraFlow", withExtension: "metal") else {
            Logger.rendering.error("Shader source file not found in bundle")
            return nil
        }
        do {
            let source = try String(contentsOf: shaderURL, encoding: .utf8)
            let library = try device.makeLibrary(source: source, options: nil)
            Logger.rendering.info("Shader library compiled from source")
            return library
        } catch {
            Logger.rendering.error("Failed to compile shader library: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Scene Management

    public func setScene(_ scene: WallpaperScene) {
        self.scene = scene
        // Update existing renderers
        for (id, renderer) in renderers {
            renderer.setScene(scene)
            if let window = wallpaperWindows[id] {
                try? scene.setupResources(device: device!, library: library!, view: window.getMetalView()!)
            }
        }
    }

    // MARK: - Wallpaper Management

    public func applyWallpaper() {
        guard !isActive else { return }
        guard let device = device, let library = library else {
            Logger.rendering.error("Cannot apply wallpaper: Metal not initialized")
            return
        }

        displayManager.refreshDisplays()

        for display in displayManager.activeDisplays {
            createWallpaperWindow(for: display, device: device, library: library)
        }

        isActive = true
        Logger.wallpaper.info("Wallpaper applied with \(self.wallpaperWindows.count) window(s)")

        setupDisplayObservation()
    }

    public func removeWallpaper() {
        guard isActive else { return }

        for (_, window) in wallpaperWindows {
            window.close()
        }
        wallpaperWindows.removeAll()
        renderers.removeAll()
        scene?.cleanup()
        isActive = false

        Logger.wallpaper.info("Wallpaper removed")
    }

    // MARK: - Frame Update (called from display link or timer)

    public func updateAudioFrame() {
        guard let session = audioSession else { return }
        let frame = session.currentFrame
        let palette = Palette.default // Will be updated by MusicManager
        for renderer in renderers.values {
            renderer.currentAudioFrame = frame
            renderer.currentPalette = palette
        }
    }

    // MARK: - Window Creation

    private func createWallpaperWindow(for display: DisplayManager.DisplayInfo, device: MTLDevice, library: MTLLibrary) {
        guard wallpaperWindows[display.uuid] == nil else { return }

        let window = WallpaperWindow(displayUUID: display.uuid, screen: display.screen)

        // Create renderer for this display
        guard let metalView = window.getMetalView() else {
            Logger.rendering.error("Failed to get Metal view for display")
            return
        }

        do {
            let renderer = try MetalRenderer(
                device: device,
                vertexFunction: "aurora_vertex",
                fragmentFunction: "aurora_fragment"
            )
            try renderer.createPipelineState(library: library, view: metalView)

            // Set the scene
            if let scene = scene {
                renderer.setScene(scene)
                try scene.setupResources(device: device, library: library, view: metalView)
            }

            // Connect renderer to view
            metalView.delegate = renderer
            metalView.device = device
            metalView.isPaused = false
            metalView.enableSetNeedsDisplay = false

            renderers[display.uuid] = renderer
        } catch {
            Logger.rendering.error("Failed to create renderer: \(error.localizedDescription)")
        }

        wallpaperWindows[display.uuid] = window
        Logger.wallpaper.debug("Created wallpaper window for display \(display.uuid)")
    }

    private func destroyWallpaperWindow(for displayUUID: UUID) {
        guard let window = wallpaperWindows.removeValue(forKey: displayUUID) else { return }
        renderers[displayUUID] = nil
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
        guard let device = device, let library = library else { return }
        let oldDisplays = Set(wallpaperWindows.keys)
        displayManager.refreshDisplays()
        let newDisplays = Set(displayManager.activeDisplays.map { $0.uuid })

        // Remove displays that are no longer connected
        for uuid in oldDisplays.subtracting(newDisplays) {
            destroyWallpaperWindow(for: uuid)
        }

        // Add new displays
        for display in displayManager.activeDisplays where !oldDisplays.contains(display.uuid) {
            createWallpaperWindow(for: display, device: device, library: library)
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
        for (_, window) in wallpaperWindows {
            window.sharingType = .none
        }
    }
}