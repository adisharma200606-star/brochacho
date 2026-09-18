// swift-tools-version:5.9
import PackageDescription

// BrochachoCore is the brain: matching, the stash, the line picker, config.
// It uses Foundation only, so it builds and tests on macOS and on Linux.
// The notch app (App/) depends on it; nothing here depends on the app.
let package = Package(
    name: "BrochachoCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "BrochachoCore", targets: ["BrochachoCore"])
    ],
    targets: [
        .target(name: "BrochachoCore", path: "Sources/BrochachoCore"),
        .testTarget(name: "BrochachoCoreTests", dependencies: ["BrochachoCore"], path: "Tests/BrochachoCoreTests")
    ]
)
