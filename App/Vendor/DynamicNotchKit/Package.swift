// swift-tools-version: 6.0
// Vendored copy of DynamicNotchKit 1.1.0 (MIT, Kai Azim). See PATCHES.md for the two small changes made here.
// The documentation plugin dependency is removed so that building needs no extra downloads.

import PackageDescription

let package = Package(
    name: "DynamicNotchKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "DynamicNotchKit", targets: ["DynamicNotchKit"])
    ],
    targets: [
        .target(name: "DynamicNotchKit", path: "Sources")
    ]
)
