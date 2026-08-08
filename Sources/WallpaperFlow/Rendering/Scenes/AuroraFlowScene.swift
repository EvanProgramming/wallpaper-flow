import AppKit
import Metal
import MetalKit
import OSLog

// MARK: - Aurora Flow Scene

public final class AuroraFlowScene: @unchecked Sendable, WallpaperScene {

    public let id: SceneID = "aurora-flow"
    public let name: String = "Aurora Flow"
    public let thumbnail: Data? = nil

    nonisolated(unsafe) private var device: MTLDevice?
    nonisolated(unsafe) private var library: MTLLibrary?

    public init() {}

    // MARK: - WallpaperScene

    public func configure(with config: SceneConfig) {
        // Configuration handled via uniforms in renderer
    }

    public func update(with frame: AudioFeatureFrame, track: TrackState, lyrics: LyricsState, palette: Palette, deltaTime: Float) {
        // Scene-specific logic (e.g., particle updates) would go here
        // For shader-only scenes, the renderer handles everything via uniforms
    }

    public func render(encoder: MTLRenderCommandEncoder, viewport: MTLViewport, uniforms: Uniforms) throws {
        // Shader-based scene — the MetalRenderer handles the full-screen quad draw
        // This method is kept for compatibility with the WallpaperScene protocol
    }

    public func handleTrackChange(from oldTrack: TrackState?, to newTrack: TrackState?) {}

    public func handlePaletteChange(from oldPalette: Palette, to newPalette: Palette, progress: Float) {}

    public func setupResources(device: MTLDevice, library: MTLLibrary, view: MTKView) throws {
        self.device = device
        self.library = library
    }

    public func cleanup() {
        device = nil
        library = nil
    }
}