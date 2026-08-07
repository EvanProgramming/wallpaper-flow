import Foundation

// MARK: - Now Playing Provider Protocol

public protocol NowPlayingProvider: AnyObject, Sendable {
    var currentTrack: TrackState? { get }
    var isActive: Bool { get }
    
    func start()
    func stop()
    
    var onTrackChanged: (@Sendable (TrackState) -> Void)? { get set }
    var onPlaybackStateChanged: (@Sendable (PlaybackState) -> Void)? { get set }
    var onPlaybackPositionChanged: (@Sendable (TimeInterval) -> Void)? { get set }
    var onError: (@Sendable (Error) -> Void)? { get set }
}