import AppKit
import SwiftUI
import OSLog

// MARK: - Menu Bar Controller

public final class MenuBarController: NSObject {
    
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    
    private let appState: AppState
    
    public init(appState: AppState) {
        self.appState = appState
        super.init()
        setupMenuBar()
    }
    
    // MARK: - Setup
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let statusItem = statusItem else { return }
        
        // Set up the status item button
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Wallpaper Flow")
            button.action = #selector(menuBarItemClicked)
            button.target = self
        }
        
        buildMenu()
    }
    
    private func buildMenu() {
        menu = NSMenu()
        
        guard let menu = menu else { return }
        
        // Now Playing section
        let nowPlayingItem = NSMenuItem(
            title: "No Music Playing",
            action: nil,
            keyEquivalent: ""
        )
        nowPlayingItem.isEnabled = false
        menu.addItem(nowPlayingItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Pause Visuals
        let pauseItem = NSMenuItem(
            title: "Pause Visuals",
            action: #selector(togglePause),
            keyEquivalent: "p"
        )
        pauseItem.target = self
        pauseItem.state = appState.isPaused ? .on : .off
        menu.addItem(pauseItem)
        
        // Change Scene submenu
        let sceneMenu = NSMenu()
        for sceneType in SceneType.allCases {
            let sceneItem = NSMenuItem(
                title: sceneType.rawValue,
                action: #selector(changeScene(_:)),
                keyEquivalent: ""
            )
            sceneItem.target = self
            sceneItem.representedObject = sceneType
            sceneItem.state = appState.currentScene.sceneType == sceneType ? .on : .off
            sceneMenu.addItem(sceneItem)
        }
        let sceneMenuItem = NSMenuItem(title: "Change Scene", action: nil, keyEquivalent: "")
        sceneMenuItem.submenu = sceneMenu
        menu.addItem(sceneMenuItem)
        
        // Audio Source submenu
        let audioMenu = NSMenu()
        for source in AudioSourceType.allCases {
            let sourceItem = NSMenuItem(
                title: source.rawValue,
                action: #selector(changeAudioSource(_:)),
                keyEquivalent: ""
            )
            sourceItem.target = self
            sourceItem.representedObject = source
            sourceItem.state = appState.audioState.sourceType == source ? .on : .off
            audioMenu.addItem(sourceItem)
        }
        let audioMenuItem = NSMenuItem(title: "Audio Source", action: nil, keyEquivalent: "")
        audioMenuItem.submenu = audioMenu
        menu.addItem(audioMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Open Wallpaper Flow
        let openItem = NSMenuItem(
            title: "Open Wallpaper Flow",
            action: #selector(openMainWindow),
            keyEquivalent: "o"
        )
        openItem.target = self
        menu.addItem(openItem)
        
        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    // MARK: - Actions
    
    @objc private func menuBarItemClicked() {
        // Update now playing display
        updateNowPlaying()
    }
    
    @objc private func togglePause() {
        appState.isPaused.toggle()
        rebuildMenu()
    }
    
    @objc private func changeScene(_ sender: NSMenuItem) {
        guard let sceneType = sender.representedObject as? SceneType else { return }
        appState.currentScene.sceneType = sceneType
        AppEventBus.shared.publish(.sceneChanged(sceneType.id))
        rebuildMenu()
    }
    
    @objc private func changeAudioSource(_ sender: NSMenuItem) {
        guard let source = sender.representedObject as? AudioSourceType else { return }
        appState.audioState.sourceType = source
        rebuildMenu()
    }
    
    @objc private func openMainWindow() {
        // Post notification to open the main settings window
        NotificationCenter.default.post(name: .openMainWindow, object: nil)
    }
    
    @objc private func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Updates
    
    public func updateNowPlaying() {
        guard let menu = menu, menu.items.count > 0 else { return }
        
        let track = appState.trackState
        let title: String
        
        if track.hasMetadata {
            title = "\(track.title) — \(track.artist)"
        } else {
            title = "No Music Playing"
        }
        
        menu.items[0].title = title
    }
    
    public func rebuildMenu() {
        buildMenu()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    public static let openMainWindow = Notification.Name("com.wallpaperflow.openMainWindow")
    public static let openSettings = Notification.Name("com.wallpaperflow.openSettings")
}