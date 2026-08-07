import SwiftUI
import OSLog

// MARK: - Wallpaper Flow App

@main
struct WallpaperFlowApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @State private var showingSettings = false
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Wallpaper Flow") {
                    NSApplication.shared.orderFrontStandardAboutPanel(nil)
                }
            }
            CommandGroup(replacing: .systemServices) {
                Button("Settings...") {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .help) {
                Button("Wallpaper Flow Help") {
                    // Open help URL
                    if let url = URL(string: "https://wallpaperflow.app/help") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}