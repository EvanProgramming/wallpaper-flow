import Foundation
import Metal
import MetalKit

// MARK: - Placeholder Scene

public final class PlaceholderScene: WallpaperScene {
    public let id: SceneID
    public let name: String
    public let thumbnail: Data?
    
    public init(id: SceneID, name: String, thumbnail: Data? = nil) {
        self.id = id
        self.name = name
        self.thumbnail = thumbnail
    }
    
    public func configure(with config: SceneConfig) {}
    
    public func update(with frame: AudioFeatureFrame, track: TrackState, lyrics: LyricsState, palette: Palette, deltaTime: Float) {}
    
    public func render(encoder: MTLRenderCommandEncoder, viewport: MTLViewport, uniforms: Uniforms) throws {
        // Placeholder: clear to dark color
    }
    
    public func handleTrackChange(from oldTrack: TrackState?, to newTrack: TrackState?) {}
    
    public func handlePaletteChange(from oldPalette: Palette, to newPalette: Palette, progress: Float) {}
    
    public func setupResources(device: MTLDevice, library: MTLLibrary, view: MTKView) throws {}
    
    public func cleanup() {}
}