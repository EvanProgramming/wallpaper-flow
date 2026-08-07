import Foundation
import OSLog

// MARK: - Settings Store

public final class SettingsStore: @unchecked Sendable {
    
    private let appState: AppState
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager
    private var saveTask: Task<Void, Never>?
    
    public init(appState: AppState) {
        self.appState = appState
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.fileManager = FileManager.default
        
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        ensureDirectoriesExist()
    }
    
    // MARK: - Settings Model
    
    private struct PersistedSettings: Codable {
        var sceneType: SceneType
        var sceneConfig: SceneConfig
        var audioSourceType: AudioSourceType
        var performanceMode: PerformanceMode
        var isPaused: Bool
        var wasRendering: Bool
        
        static let `default` = PersistedSettings(
            sceneType: .auroraFlow,
            sceneConfig: .default,
            audioSourceType: .systemAudio,
            performanceMode: .automatic,
            isPaused: false,
            wasRendering: false
        )
    }
    
    // MARK: - File Management
    
    private func ensureDirectoriesExist() {
        do {
            try fileManager.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: .cacheDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: .artworkCacheDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: .lyricsCacheDirectory, withIntermediateDirectories: true)
        } catch {
            Logger.persistence.error("Failed to create directories: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Save & Restore
    
    public func save() {
        let settings = PersistedSettings(
            sceneType: appState.currentScene.sceneType,
            sceneConfig: appState.currentScene,
            audioSourceType: appState.audioState.sourceType,
            performanceMode: appState.performanceMode,
            isPaused: appState.isPaused,
            wasRendering: appState.visualState.isRendering
        )
        
        do {
            let data = try encoder.encode(settings)
            try data.write(to: .settingsFile, options: .atomic)
            Logger.persistence.info("Settings saved")
        } catch {
            Logger.persistence.error("Failed to save settings: \(error.localizedDescription)")
        }
    }
    
    public func restore() {
        guard fileManager.fileExists(atPath: URL.settingsFile.path) else {
            Logger.persistence.info("No saved settings found, using defaults")
            applyDefaults()
            return
        }
        
        do {
            let data = try Data(contentsOf: .settingsFile)
            let settings = try decoder.decode(PersistedSettings.self, from: data)
            apply(settings)
            Logger.persistence.info("Settings restored")
        } catch {
            Logger.persistence.error("Failed to restore settings: \(error.localizedDescription), using defaults")
            applyDefaults()
        }
    }
    
    // MARK: - Auto-save
    
    public func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
            self?.save()
        }
    }
    
    // MARK: - Private
    
    private func apply(_ settings: PersistedSettings) {
        appState.currentScene = settings.sceneConfig
        appState.currentScene.sceneType = settings.sceneType
        appState.audioState.sourceType = settings.audioSourceType
        appState.performanceMode = settings.performanceMode
        appState.isPaused = settings.isPaused
        appState.visualState.isRendering = settings.wasRendering
    }
    
    private func applyDefaults() {
        apply(.default)
    }
}