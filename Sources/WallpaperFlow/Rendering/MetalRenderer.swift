import AppKit
import Metal
import MetalKit
import OSLog

// MARK: - Metal Renderer

@MainActor
public final class MetalRenderer: NSObject, @preconcurrency MTKViewDelegate {

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    private var scene: WallpaperScene?
    private var lastFrameTime: CFAbsoluteTime

    // Audio frame — updated by WallpaperCoordinator
    nonisolated(unsafe) public var currentAudioFrame: AudioFeatureFrame = .zero
    nonisolated(unsafe) public var currentPalette: Palette = .default
    nonisolated(unsafe) public var currentTrack: TrackState = .init()
    nonisolated(unsafe) public var currentLyrics: LyricsState = .init()

    private var time: Float = 0

    // Shader function names
    private let vertexFunctionName: String
    private let fragmentFunctionName: String

    public init(device: MTLDevice,
                vertexFunction: String = "aurora_vertex",
                fragmentFunction: String = "aurora_fragment") throws
    {
        self.device = device
        self.vertexFunctionName = vertexFunction
        self.fragmentFunctionName = fragmentFunction
        self.lastFrameTime = CFAbsoluteTimeGetCurrent()

        guard let queue = device.makeCommandQueue() else {
            throw RendererError.failedToCreateCommandQueue
        }
        self.commandQueue = queue

        super.init()
    }

    // MARK: - Pipeline Setup

    public func createPipelineState(library: MTLLibrary, view: MTKView) throws {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: vertexFunctionName)
        descriptor.fragmentFunction = library.makeFunction(name: fragmentFunctionName)
        descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat

        // Enable alpha blending for smooth transitions
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        self.pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    // MARK: - Scene

    public func setScene(_ scene: WallpaperScene) {
        self.scene = scene
    }

    // MARK: - MTKViewDelegate

    nonisolated public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // View size changed — nothing special needed for full-screen quad
    }

    nonisolated public func draw(in view: MTKView) {
        MainActor.assumeIsolated {
            guard let pipelineState = self.pipelineState,
                  let scene = self.scene,
                  let drawable = view.currentDrawable,
                  let descriptor = view.currentRenderPassDescriptor,
                  let commandBuffer = self.commandQueue.makeCommandBuffer()
            else { return }

            // Calculate delta time
            let now = CFAbsoluteTimeGetCurrent()
            let dt = Float(min(now - self.lastFrameTime, 0.1))
            self.lastFrameTime = now
            self.time += dt

            // Build uniforms from current audio data
            let frame = self.currentAudioFrame
            let palette = self.currentPalette

            let uniforms = Uniforms(
                time: self.time,
                deltaTime: dt,
                viewportSize: CGSize(width: CGFloat(drawable.texture.width),
                                     height: CGFloat(drawable.texture.height)),
                displayScale: Float(view.window?.backingScaleFactor ?? 2),
                bass: frame.bass,
                mid: frame.mid,
                treble: frame.treble,
                beat: frame.beatImpulse,
                loudness: frame.loudness,
                stereoBalance: frame.stereoBalance,
                primaryColor: palette.primary,
                secondaryColor: palette.secondary,
                accentColor: palette.accent,
                darkBaseColor: palette.darkBase,
                intensity: 0.8,
                motion: 0.5,
                glow: 0.6,
                particleAmount: 0.5,
                audioReactivity: 0.8,
                lyricsProgress: 0,
                hasLyrics: false
            )

            // Update scene
            scene.update(
                with: frame,
                track: self.currentTrack,
                lyrics: self.currentLyrics,
                palette: palette,
                deltaTime: dt
            )

            // Encode
            let viewport = MTLViewport(
                originX: 0, originY: 0,
                width: Double(drawable.texture.width),
                height: Double(drawable.texture.height),
                znear: 0, zfar: 1
            )

            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                return
            }

            encoder.setViewport(viewport)
            encoder.setRenderPipelineState(pipelineState)

            // Pass uniforms as buffer(0)
            var u = uniforms
            encoder.setFragmentBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 0)

            // Draw full-screen quad (2 triangles = 4 vertices)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

// MARK: - Error

public enum RendererError: Error {
    case failedToCreateCommandQueue
    case failedToCreatePipelineState
}