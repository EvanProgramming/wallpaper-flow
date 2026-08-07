// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WallpaperFlow",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "WallpaperFlow", targets: ["WallpaperFlow"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "WallpaperFlow",
            dependencies: [],
            path: "Sources/WallpaperFlow",
            resources: [
                .process("Shaders")
            ],
            swiftSettings: [
                .unsafeFlags(["-framework", "Cocoa"]),
                .unsafeFlags(["-framework", "SwiftUI"]),
                .unsafeFlags(["-framework", "AppKit"]),
                .unsafeFlags(["-framework", "Metal"]),
                .unsafeFlags(["-framework", "MetalKit"]),
                .unsafeFlags(["-framework", "CoreAudio"]),
                .unsafeFlags(["-framework", "AudioToolbox"]),
                .unsafeFlags(["-framework", "Accelerate"]),
                .unsafeFlags(["-framework", "MusicKit"]),
                .unsafeFlags(["-framework", "ShazamKit"]),
                .unsafeFlags(["-framework", "Combine"]),
                .unsafeFlags(["-framework", "OSLog"])
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-framework", "-Xlinker", "Cocoa"]),
                .unsafeFlags(["-Xlinker", "-framework", "-Xlinker", "SwiftUI"]),
                .unsafeFlags(["-Xlinker", "-framework", "-Xlinker", "AppKit"]),
                .unsafeFlags(["-Xlinker", "-framework", "-Xlinker", "Metal"]),
                .unsafeFlags(["-Xlinker", "-framework", "-Xlinker", "MetalKit"]),
                .unsafeFlags(["-Xlinker", "-framework", "-Xlinker", "CoreAudio"]),
                .unsafeFlags(["-Xlinker", "-framework", "-Xlinker", "AudioToolbox"]),
                .unsafeFlags(["-Xlinker", "-framework", "-Xlinker", "Accelerate"]),
                .unsafeFlags(["-Xlinker", "-framework", "-Xlinker", "MusicKit"]),
                .unsafeFlags(["-Xlinker", "-framework", "-Xlinker", "ShazamKit"]),
                .unsafeFlags(["-Xlinker", "-framework", "-Xlinker", "Combine"]),
                .unsafeFlags(["-Xlinker", "-framework", "-Xlinker", "OSLog"])
            ]
        )
    ]
)