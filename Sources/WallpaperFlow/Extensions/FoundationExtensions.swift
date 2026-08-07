import Foundation
import CoreGraphics

// MARK: - Bundle Helpers

extension Bundle {
    static let wallpaperFlow: Bundle = {
        // Use the main bundle for Info.plist access
        return .main
    }()
    
    var appName: String {
        infoDictionary?["CFBundleName"] as? String ?? "Wallpaper Flow"
    }
    
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    var appBuild: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - CGImage Extension

extension CGImage {
    var size: CGSize {
        CGSize(width: width, height: height)
    }
}

// MARK: - CGFloat Clamping

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Float Clamping

extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
    
    func normalizedToZeroOne() -> Float {
        return clamped(to: 0...1)
    }
}

// MARK: - Double Clamping

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - URL Helpers

extension URL {
    static var applicationSupportDirectory: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent("Wallpaper Flow", isDirectory: true)
        return appSupport
    }
    
    static var settingsFile: URL {
        return applicationSupportDirectory.appendingPathComponent("settings.json")
    }
    
    static var cacheDirectory: URL {
        return applicationSupportDirectory.appendingPathComponent("cache", isDirectory: true)
    }
    
    static var artworkCacheDirectory: URL {
        return cacheDirectory.appendingPathComponent("artwork", isDirectory: true)
    }
    
    static var lyricsCacheDirectory: URL {
        return cacheDirectory.appendingPathComponent("lyrics", isDirectory: true)
    }
}

// MARK: - Logger

import OSLog

extension Logger {
    static let app = Logger(subsystem: "com.wallpaperflow.app", category: "App")
    static let audio = Logger(subsystem: "com.wallpaperflow.app", category: "Audio")
    static let dsp = Logger(subsystem: "com.wallpaperflow.app", category: "DSP")
    static let music = Logger(subsystem: "com.wallpaperflow.app", category: "Music")
    static let lyrics = Logger(subsystem: "com.wallpaperflow.app", category: "Lyrics")
    static let rendering = Logger(subsystem: "com.wallpaperflow.app", category: "Rendering")
    static let wallpaper = Logger(subsystem: "com.wallpaperflow.app", category: "Wallpaper")
    static let ui = Logger(subsystem: "com.wallpaperflow.app", category: "UI")
    static let persistence = Logger(subsystem: "com.wallpaperflow.app", category: "Persistence")
}