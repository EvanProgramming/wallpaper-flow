import Foundation
import AppKit

// MARK: - Album Color Palette

public struct Palette: Sendable, Codable, Hashable {
    public var primary: SIMD3<Float>
    public var secondary: SIMD3<Float>
    public var accent: SIMD3<Float>
    public var darkBase: SIMD3<Float>
    
    public init(
        primary: SIMD3<Float> = SIMD3<Float>(0.2, 0.3, 0.5),
        secondary: SIMD3<Float> = SIMD3<Float>(0.5, 0.2, 0.4),
        accent: SIMD3<Float> = SIMD3<Float>(0.8, 0.3, 0.2),
        darkBase: SIMD3<Float> = SIMD3<Float>(0.05, 0.05, 0.1)
    ) {
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
        self.darkBase = darkBase
    }
    
    // Default dark palette
    public static let dark = Palette(
        primary: SIMD3<Float>(0.2, 0.3, 0.5),
        secondary: SIMD3<Float>(0.5, 0.2, 0.4),
        accent: SIMD3<Float>(0.8, 0.3, 0.2),
        darkBase: SIMD3<Float>(0.02, 0.02, 0.05)
    )
    
    // Warm palette
    public static let warm = Palette(
        primary: SIMD3<Float>(0.5, 0.2, 0.1),
        secondary: SIMD3<Float>(0.7, 0.4, 0.1),
        accent: SIMD3<Float>(0.9, 0.6, 0.2),
        darkBase: SIMD3<Float>(0.05, 0.02, 0.02)
    )
    
    // Cool palette
    public static let cool = Palette(
        primary: SIMD3<Float>(0.1, 0.3, 0.5),
        secondary: SIMD3<Float>(0.2, 0.5, 0.7),
        accent: SIMD3<Float>(0.4, 0.8, 1.0),
        darkBase: SIMD3<Float>(0.02, 0.04, 0.08)
    )
    
    public static let `default` = Palette.dark
    
    public func lerp(to other: Palette, t: Float) -> Palette {
        Palette(
            primary: SIMD3<Float>(self.primary.x + (other.primary.x - self.primary.x) * t,
                                  self.primary.y + (other.primary.y - self.primary.y) * t,
                                  self.primary.z + (other.primary.z - self.primary.z) * t),
            secondary: SIMD3<Float>(self.secondary.x + (other.secondary.x - self.secondary.x) * t,
                                    self.secondary.y + (other.secondary.y - self.secondary.y) * t,
                                    self.secondary.z + (other.secondary.z - self.secondary.z) * t),
            accent: SIMD3<Float>(self.accent.x + (other.accent.x - self.accent.x) * t,
                                 self.accent.y + (other.accent.y - self.accent.y) * t,
                                 self.accent.z + (other.accent.z - self.accent.z) * t),
            darkBase: SIMD3<Float>(self.darkBase.x + (other.darkBase.x - self.darkBase.x) * t,
                                   self.darkBase.y + (other.darkBase.y - self.darkBase.y) * t,
                                   self.darkBase.z + (other.darkBase.z - self.darkBase.z) * t)
        )
    }
}