import AppKit
import OSLog

// MARK: - Display Manager

@Observable
public final class DisplayManager {
    
    public var activeDisplays: [DisplayInfo] = []
    public var mainDisplay: DisplayInfo?
    
    private var displayReconfigurationObserver: NSObjectProtocol?
    
    public init() {
        refreshDisplays()
        startObserving()
    }
    
    deinit {
        stopObserving()
    }
    
    // MARK: - Display Info
    
    public struct DisplayInfo: Hashable {
        public let uuid: UUID
        public let screen: NSScreen
        public let frame: CGRect
        public let backingScaleFactor: CGFloat
        public let isMain: Bool
        
        public init(screen: NSScreen) {
            self.uuid = UUID()
            self.screen = screen
            self.frame = screen.frame
            self.backingScaleFactor = screen.backingScaleFactor
            self.isMain = (screen == NSScreen.screens.first)
        }
        
        public var displayID: CGDirectDisplayID? {
            // Get the display ID from the screen
            let screenInfo = screen.deviceDescription
            return screenInfo[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        }
    }
    
    // MARK: - Display Management
    
    public func refreshDisplays() {
        let screens = NSScreen.screens
        activeDisplays = screens.map { DisplayInfo(screen: $0) }
        mainDisplay = activeDisplays.first(where: { $0.isMain })
        
        Logger.wallpaper.info("Displays refreshed: \(self.activeDisplays.count) display(s)")
        for display in activeDisplays {
            Logger.wallpaper.debug("  Display: \(display.frame.size.width)x\(display.frame.size.height) @\(display.backingScaleFactor)x")
        }
    }
    
    public func displayInfo(for screen: NSScreen) -> DisplayInfo? {
        return activeDisplays.first { $0.screen == screen }
    }
    
    // MARK: - Observation
    
    private func startObserving() {
        displayReconfigurationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let oldCount = self.activeDisplays.count
            self.refreshDisplays()
            let newCount = self.activeDisplays.count
            
            if newCount > oldCount {
                self.publishDisplayEvent(.displayAdded)
            } else if newCount < oldCount {
                self.publishDisplayEvent(.displayRemoved)
            }
        }
    }
    
    private func stopObserving() {
        if let observer = displayReconfigurationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func publishDisplayEvent(_ event: AppEvent) {
        AppEventBus.shared.publish(event)
    }
}