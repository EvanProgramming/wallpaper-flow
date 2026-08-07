import AppKit
import MetalKit

// MARK: - Wallpaper Window

public final class WallpaperWindow: NSWindow {
    
    private let displayUUID: UUID
    
    public init(displayUUID: UUID, screen: NSScreen) {
        self.displayUUID = displayUUID
        
        let rect = screen.frame
        
        super.init(
            contentRect: rect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        configureWindow(screen: screen)
        createMetalView(screen: screen)
    }
    
    private func configureWindow(screen: NSScreen) {
        // Window level: behind desktop icons
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        
        // Visual properties
        isOpaque = true
        hasShadow = false
        backgroundColor = .clear
        alphaValue = 1.0
        
        // Interactive behavior
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        
        // Space behavior
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle
        ]
        
        // Make it a desktop window
        canHide = false
        isExcludedFromWindowsMenu = true
        sharingType = .readOnly
        
        // Ensure it's positioned correctly
        setFrame(screen.frame, display: true)
        orderBack(nil)
    }
    
    private func createMetalView(screen: NSScreen) {
        // Create MTKView for Metal rendering
        let metalView = WallpaperMetalView(frame: screen.frame)
        contentView = metalView
    }
    
    public func updateFrame(for screen: NSScreen) {
        setFrame(screen.frame, display: true)
        contentView?.frame = screen.frame
    }
    
    public func getMetalView() -> WallpaperMetalView? {
        return contentView as? WallpaperMetalView
    }
}

// MARK: - Wallpaper Metal View

public final class WallpaperMetalView: MTKView {
    
    public override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        configureView()
    }
    
    public required init(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }
    
    private func configureView() {
        isPaused = true
        enableSetNeedsDisplay = false
        autoResizeDrawable = true
        framebufferOnly = true
        clearColor = MTLClearColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 1.0)
        isHidden = false
        
        // Set the view to be behind everything
        layer?.zPosition = -1
    }
    
    public override var wantsUpdateLayer: Bool {
        return true
    }
}