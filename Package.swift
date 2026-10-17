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
var dependencies: [Package.Dependency] = []

// The app needs AppKit and SwiftUI, so it is only declared on macOS. This lets
// `swift test` run the core tests on Linux too.
#if os(macOS)
dependencies.append(.package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.6.0"))
targets.append(.executableTarget(
    name: "TrashFlush",
    dependencies: ["TrashFlushCore", .product(name: "Lottie", package: "lottie-spm")],
    resources: [.copy("Resources/confetti-burst.json")]
))
#endif

let package = Package(
    name: "TrashFlush",
    platforms: [.macOS(.v14)],
    dependencies: dependencies,
    targets: targets
)
