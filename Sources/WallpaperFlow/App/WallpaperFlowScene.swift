import SwiftUI
import OSLog

// MARK: - Settings Window Scene

public struct WallpaperFlowSettingsScene: Scene {
    
    @State private var appState = AppState()
    
    public init() {}
    
    public var body: some Scene {
        Window("Wallpaper Flow Settings", id: "settings") {
            SettingsView()
                .environment(appState)
                .frame(minWidth: 700, minHeight: 500)
        }
        .windowResizability(.contentMinSize)
        .windowStyle(.titleBar)
        .commandsRemoved()
    }
}

// MARK: - Settings View (Placeholder)

public struct SettingsView: View {
    
    @Environment(AppState.self) private var appState
    
    public init() {}
    
    public var body: some View {
        TabView {
            Text("Scenes")
                .tabItem {
                    Label("Scenes", systemImage: "square.3.layers.3d")
                }
            
            Text("Audio")
                .tabItem {
                    Label("Audio", systemImage: "waveform")
                }
            
            Text("Display")
                .tabItem {
                    Label("Display", systemImage: "display")
                }
            
            Text("Settings")
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .padding()
    }
}