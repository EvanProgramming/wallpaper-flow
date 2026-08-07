import Foundation

// MARK: - Scene ID

public typealias SceneID = String

// MARK: - Scene Type

public enum SceneType: String, CaseIterable, Codable, Sendable {
    case auroraFlow = "Aurora Flow"
    case glassWave = "Glass Wave"
    case orbit = "Orbit"
    case cinematicLyrics = "Cinematic Lyrics"
    
    public var id: SceneID {
        switch self {
        case .auroraFlow: return "aurora-flow"
        case .glassWave: return "glass-wave"
        case .orbit: return "orbit"
        case .cinematicLyrics: return "cinematic-lyrics"
        }
    }
}

// MARK: - Scene Config

public struct SceneConfig: Codable, Sendable {
    public var sceneType: SceneType
    public var intensity: Float
    public var motion: Float
    public var glow: Float
    public var particleAmount: Float
    public var audioReactivity: Float
    public var useArtworkColors: Bool
    public var showLyrics: Bool
    public var showMusicCard: Bool
    
    public init(
        sceneType: SceneType = .auroraFlow,
        intensity: Float = 0.7,
        motion: Float = 0.5,
        glow: Float = 0.6,
        particleAmount: Float = 0.5,
        audioReactivity: Float = 0.8,
        useArtworkColors: Bool = true,
        showLyrics: Bool = true,
        showMusicCard: Bool = true
    ) {
        self.sceneType = sceneType
        self.intensity = intensity
        self.motion = motion
        self.glow = glow
        self.particleAmount = particleAmount
        self.audioReactivity = audioReactivity
        self.useArtworkColors = useArtworkColors
        self.showLyrics = showLyrics
        self.showMusicCard = showMusicCard
    }
    
    public static let `default` = SceneConfig()
}