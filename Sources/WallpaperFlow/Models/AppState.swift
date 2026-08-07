import Foundation
import Observation
import AppKit

// MARK: - App State

@Observable
public final class AppState {
    public var audioState = AudioState()
    public var trackState = TrackState()
    public var lyricsState = LyricsState()
    public var visualState = VisualState()
    public var displayState = DisplayState()
    public var isActive: Bool = true
    public var isPaused: Bool = false
    public var currentScene: SceneConfig = .default
    public var performanceMode: PerformanceMode = .automatic
    public var thermalState: ProcessInfo.ThermalState = .nominal
    
    public init() {}
    
    public var hasAudioActivity: Bool {
        audioState.isActive && audioState.rms > 0.01
    }
}

// MARK: - Audio State

@Observable
public final class AudioState {
    public var isActive: Bool = false
    public var sourceType: AudioSourceType = .systemAudio
    public var rms: Float = 0
    public var peak: Float = 0
    public var isMuted: Bool = false
    
    public init() {}
}

// MARK: - Audio Source Type

public enum AudioSourceType: String, CaseIterable, Codable, Sendable {
    case systemAudio = "System Audio"
    case microphone = "Microphone"
    case selectedApp = "Selected Application"
    
    public var id: String { rawValue }
}

// MARK: - Visual State

@Observable
public final class VisualState {
    public var isRendering: Bool = false
    public var currentFPS: Int = 0
    public var palette: Palette = .default
    public var targetPalette: Palette = .default
    public var paletteTransition: Float = 1.0
    
    public init() {}
}

// MARK: - Display State

@Observable
public final class DisplayState {
    public var displayCount: Int = NSScreen.screens.count
    public var screens: [NSScreen] = NSScreen.screens
    public var activeDisplayIDs: Set<UUID> = []
    
    public init() {
        updateScreens()
    }
    
    public func updateScreens() {
        screens = NSScreen.screens
        displayCount = screens.count
    }
}

// MARK: - Audio Source Type

extension AudioSourceType {
    public var requiresSystemAudioPermission: Bool {
        self == .systemAudio || self == .selectedApp
    }
    
    public var requiresMicrophonePermission: Bool {
        self == .microphone
    }
}