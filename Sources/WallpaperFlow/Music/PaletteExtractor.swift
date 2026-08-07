import Foundation
import CoreGraphics
import ImageIO
import OSLog

// MARK: - Palette Extractor

/// Extracts a `Palette` from album artwork image data using K-Means
/// clustering (k=4) on a 32×32 downsampled version of the image.
///
/// `PaletteExtractor` is a pure struct with no mutable state, making it
/// fully `Sendable` and safe to use from any concurrency context.
public struct PaletteExtractor: Sendable {
    
    /// Extracts a color palette from the given artwork image data.
    ///
    /// - Parameter imageData: Raw image data (JPEG, PNG, etc.).
    /// - Returns: A `Palette` with four extracted colors, or `.default`
    ///   if extraction fails or no valid clusters remain.
    public static func extract(from imageData: Data) -> Palette {
        guard let pixels = downsampleAndExtractPixels(from: imageData),
              !pixels.isEmpty else {
            Logger.music.debug("PaletteExtractor: no pixels extracted, returning default")
            return Palette.default
        }
        
        let clusters = kMeansClustering(pixels: pixels, k: 4, maxIterations: 20)
        let result = scorePalette(from: clusters)
        
        let primaryStr = "\(result.primary)"
        let secondaryStr = "\(result.secondary)"
        let accentStr = "\(result.accent)"
        let darkBaseStr = "\(result.darkBase)"
        let logMsg = "PaletteExtractor: extracted \(clusters.count) clusters → primary: \(primaryStr), secondary: \(secondaryStr), accent: \(accentStr), darkBase: \(darkBaseStr)"
        Logger.music.debug("\(logMsg)")
        
        return result
    }
    
    // MARK: - Downsampling & Pixel Extraction
    
    /// Downsamples the image to 32×32 pixels and returns the raw RGB values
    /// as `SIMD3<Float>` in the 0.0–1.0 range (sRGB).
    private static func downsampleAndExtractPixels(from data: Data) -> [SIMD3<Float>]? {
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: 32,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCache: false,
        ]
        
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }
        
        return extractPixels(from: thumbnail)
    }
    
    /// Reads raw RGBA pixel data from a `CGImage` and returns normalized
    /// RGB float values.
    private static func extractPixels(from image: CGImage) -> [SIMD3<Float>] {
        let width = image.width
        let height = image.height
        let totalPixels = width * height
        
        guard totalPixels > 0 else { return [] }
        
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bytesPerRow = width * 4
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return []
        }
        
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return [] }
        
        let bytes = data.bindMemory(to: UInt8.self, capacity: totalPixels * 4)
        var pixels = [SIMD3<Float>]()
        pixels.reserveCapacity(totalPixels)
        
        for i in 0..<totalPixels {
            let offset = i * 4
            let r = Float(bytes[offset]) / 255.0
            let g = Float(bytes[offset + 1]) / 255.0
            let b = Float(bytes[offset + 2]) / 255.0
            pixels.append(SIMD3<Float>(r, g, b))
        }
        
        return pixels
    }
    
    // MARK: - K-Means Clustering
    
    /// Runs a simple K-Means clustering on the given pixel data.
    ///
    /// - Parameters:
    ///   - pixels: Array of RGB float triples (0.0–1.0).
    ///   - k: Number of clusters (default 4).
    ///   - maxIterations: Maximum iterations before stopping.
    /// - Returns: Array of `(color, count)` tuples for each non-empty cluster.
    private static func kMeansClustering(
        pixels: [SIMD3<Float>],
        k: Int,
        maxIterations: Int
    ) -> [(color: SIMD3<Float>, count: Int)] {
        guard !pixels.isEmpty, k > 0 else { return [] }
        guard pixels.count >= k else {
            // Not enough pixels – return each pixel as its own cluster
            return pixels.map { ($0, 1) }
        }
        
        // --- Initialise centres evenly across the pixel array ---
        var centers = [SIMD3<Float>]()
        let step = pixels.count / k
        for i in 0..<k {
            let idx = min(i * step, pixels.count - 1)
            centers.append(pixels[idx])
        }
        
        var assignments = [Int](repeating: 0, count: pixels.count)
        
        // --- Iterate ---
        for _ in 0..<maxIterations {
            var changed = false
            
            // Assign each pixel to the nearest centre
            for i in 0..<pixels.count {
                var minDist = Float.greatestFiniteMagnitude
                var best = 0
                for j in 0..<k {
                    let diff = pixels[i] - centers[j]
                    let dist = diff.x * diff.x + diff.y * diff.y + diff.z * diff.z
                    if dist < minDist {
                        minDist = dist
                        best = j
                    }
                }
                if assignments[i] != best {
                    changed = true
                    assignments[i] = best
                }
            }
            
            if !changed { break }
            
            // Recompute centres
            var sums = [SIMD3<Float>](repeating: .zero, count: k)
            var counts = [Int](repeating: 0, count: k)
            for i in 0..<pixels.count {
                let c = assignments[i]
                sums[c] += pixels[i]
                counts[c] += 1
            }
            for j in 0..<k where counts[j] > 0 {
                centers[j] = sums[j] / Float(counts[j])
            }
        }
        
        // Count final assignments
        var counts = [Int](repeating: 0, count: k)
        for i in 0..<pixels.count {
            counts[assignments[i]] += 1
        }
        
        return zip(centers, counts)
            .filter { $0.1 > 0 }
            .map { ($0.0, $0.1) }
    }
    
    // MARK: - Scoring
    
    /// Filters unwanted clusters and assigns the four palette roles.
    private static func scorePalette(
        from clusters: [(color: SIMD3<Float>, count: Int)]
    ) -> Palette {
        // --- Filter ---
        let filtered = clusters.filter { cluster in
            let b = brightness(cluster.color)
            let s = saturation(cluster.color)
            return b >= 0.1 && b <= 0.95 && s >= 0.05
        }
        
        guard !filtered.isEmpty else {
            Logger.music.debug("PaletteExtractor: no clusters survived filtering, returning default")
            return Palette.default
        }
        
        // Sort by pixel count descending
        let sorted = filtered.sorted { $0.count > $1.count }
        
        let primary = sorted[0].color
        
        // Handle cases with fewer than 4 clusters
        switch sorted.count {
        case 1:
            return Palette(primary: primary,
                           secondary: Palette.default.secondary,
                           accent: Palette.default.accent,
                           darkBase: Palette.default.darkBase)
        case 2:
            return Palette(primary: primary,
                           secondary: sorted[1].color,
                           accent: Palette.default.accent,
                           darkBase: Palette.default.darkBase)
        case 3:
            return Palette(primary: primary,
                           secondary: sorted[1].color,
                           accent: sorted[2].color,
                           darkBase: Palette.default.darkBase)
        default:
            // 4+ clusters – assign all four roles
            let secondary = sorted[1].color
            let remaining = Array(sorted.dropFirst(2))
            
            // Accent: highest saturation among remaining
            let accent = remaining.max { saturation($0.color) < saturation($1.color) }!.color
            
            // DarkBase: lowest brightness (darkest non-black) among remaining
            let darkBase = remaining.min { brightness($0.color) < brightness($1.color) }!.color
            
            return Palette(primary: primary,
                           secondary: secondary,
                           accent: accent,
                           darkBase: darkBase)
        }
    }
    
    // MARK: - Color Helpers
    
    /// Returns the perceived brightness (V in HSV) of an sRGB colour.
    @inline(__always)
    private static func brightness(_ color: SIMD3<Float>) -> Float {
        max(color.x, color.y, color.z)
    }
    
    /// Returns a simple saturation estimate (range of RGB channels / max).
    @inline(__always)
    private static func saturation(_ color: SIMD3<Float>) -> Float {
        let mx = max(color.x, color.y, color.z)
        let mn = min(color.x, color.y, color.z)
        guard mx > 0 else { return 0 }
        return (mx - mn) / mx
    }
}