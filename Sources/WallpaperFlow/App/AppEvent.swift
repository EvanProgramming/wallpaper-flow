import Foundation
@preconcurrency import Combine

// MARK: - App Event

public enum AppEvent: Sendable {
    // Audio events
    case audioStarted
    case audioStopped
    case audioPermissionDenied
    
    // Track events
    case trackChanged(TrackState)
    case trackPaused
    case trackResumed
    
    // Lyrics events
    case lyricsLoaded
    case lyricsUnavailable
    
    // Display events
    case displayAdded
    case displayRemoved
    
    // Scene events
    case sceneChanged(SceneID)
    case paletteChanged(Palette)
    
    // App lifecycle
    case appWillTerminate
    case appDidBecomeActive
    case appDidResignActive
    case thermalStateChanged(ProcessInfo.ThermalState)
}

// MARK: - App Event Bus

public final class AppEventBus: @unchecked Sendable {
    public static let shared = AppEventBus()
    
    private let subject = PassthroughSubject<AppEvent, Never>()
    private var lock = os_unfair_lock_s()
    
    private init() {}
    
    public func subscribe() -> AsyncStream<AppEvent> {
        AsyncStream { continuation in
            let cancellable = subject.sink { event in
                continuation.yield(event)
            }
            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }
    
    public func publisher() -> AnyPublisher<AppEvent, Never> {
        subject.eraseToAnyPublisher()
    }
    
    public func publish(_ event: AppEvent) {
        subject.send(event)
    }
}