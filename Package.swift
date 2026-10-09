// swift-tools-version:6.0
import PackageDescription

// Two targets keep the code easy to test:
// - TrashFlushCore: plain Swift (Foundation only). Trash scanning, flush
//   detection, sound synthesis and animation math. Builds and tests anywhere.
// - TrashFlush: the macOS menu bar app (SwiftUI + a little AppKit).
var targets: [Target] = [
    .target(name: "TrashFlushCore"),
    .testTarget(name: "TrashFlushCoreTests", dependencies: ["TrashFlushCore"]),
]

// The app needs AppKit and SwiftUI, so it is only declared on macOS. This lets
// `swift test` run the core tests on Linux too.
#if os(macOS)
targets.append(.executableTarget(name: "TrashFlush", dependencies: ["TrashFlushCore"]))
#endif

let package = Package(
    name: "TrashFlush",
    platforms: [.macOS(.v14)],
    targets: targets
)
