import Foundation
import Metal
import MetalKit

// MARK: - Scene Protocol

public protocol WallpaperScene: AnyObject, Sendable {
    var id: SceneID { get }
    var name: String { get }
    var thumbnail: Data? { get }
    
    func configure(with config: SceneConfig)
    func update(with frame: AudioFeatureFrame, track: TrackState, lyrics: LyricsState, palette: Palette, deltaTime: Float)
    func render(encoder: MTLRenderCommandEncoder, viewport: MTLViewport, uniforms: Uniforms) throws
    func handleTrackChange(from oldTrack: TrackState?, to newTrack: TrackState?)
    func handlePaletteChange(from oldPalette: Palette, to newPalette: Palette, progress: Float)
    
    // Resource management
    func setupResources(device: MTLDevice, library: MTLLibrary, view: MTKView) throws
    func cleanup()
}

// MARK: - Uniforms

public struct Uniforms {
    public var time: Float
    public var deltaTime: Float
    public var viewportSize: CGSize
    public var displayScale: Float
    
    // Audio
    public var bass: Float
    public var mid: Float
    public var treble: Float
    public var beat: Float
    public var loudness: Float
    public var stereoBalance: Float
    
    // Palette
    public var primaryColor: SIMD3<Float>
    public var secondaryColor: SIMD3<Float>
    public var accentColor: SIMD3<Float>
    public var darkBaseColor: SIMD3<Float>
    
    // Scene config
    public var intensity: Float
    public var motion: Float
    public var glow: Float
    public var particleAmount: Float
    public var audioReactivity: Float
    
    // Lyrics
    public var lyricsProgress: Float
    public var hasLyrics: Bool
    
    public init(
        time: Float = 0,
        deltaTime: Float = 0,
        viewportSize: CGSize = .zero,
        displayScale: Float = 2,
        bass: Float = 0,
        mid: Float = 0,
        treble: Float = 0,
        beat: Float = 0,
        loudness: Float = 0,
        stereoBalance: Float = 0,
        primaryColor: SIMD3<Float> = SIMD3<Float>(0.2, 0.3, 0.5),
        secondaryColor: SIMD3<Float> = SIMD3<Float>(0.5, 0.2, 0.4),
        accentColor: SIMD3<Float> = SIMD3<Float>(0.8, 0.3, 0.2),
        darkBaseColor: SIMD3<Float> = SIMD3<Float>(0.05, 0.05, 0.1),
        intensity: Float = 0.7,
        motion: Float = 0.5,
        glow: Float = 0.6,
        particleAmount: Float = 0.5,
        audioReactivity: Float = 0.8,
        lyricsProgress: Float = 0,
        hasLyrics: Bool = false
    ) {
        self.time = time
        self.deltaTime = deltaTime
        self.viewportSize = viewportSize
        self.displayScale = displayScale
        self.bass = bass
        self.mid = mid
        self.treble = treble
        self.beat = beat
        self.loudness = loudness
        self.stereoBalance = stereoBalance
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.accentColor = accentColor
        self.darkBaseColor = darkBaseColor
        self.intensity = intensity
        self.motion = motion
        self.glow = glow
        self.particleAmount = particleAmount
        self.audioReactivity = audioReactivity
        self.lyricsProgress = lyricsProgress
        self.hasLyrics = hasLyrics
    }
}

// MARK: - Scene Manager

@Observable
public final class SceneManager {
    public var currentScene: WallpaperScene?
    public var availableScenes: [WallpaperScene] = []
    
    public init() {}
    
    public func registerScene(_ scene: WallpaperScene) {
        if !availableScenes.contains(where: { $0.id == scene.id }) {
            availableScenes.append(scene)
        }
    }
    
    public func switchToScene(id: SceneID) {
        guard let scene = availableScenes.first(where: { $0.id == id }) else { return }
        currentScene?.cleanup()
        currentScene = scene
    }
}