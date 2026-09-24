// swift-tools-version: 5.9
import PackageDescription

// A small Objective-C bridge for rotating a display ("one eighty"). Written in Objective-C, not Swift,
// on purpose: Objective-C's own alloc/init and message-send syntax calls an undeclared method correctly
// with one category declaration (see RotationBridge.m). The equivalent in pure Swift needs manual
// Objective-C-runtime pointer work, which is far easier to get subtly wrong — the first version of this
// file was written that way and did not work on real hardware.
let package = Package(
    name: "RotationBridge",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "RotationBridge", targets: ["RotationBridge"])
    ],
    targets: [
        .target(
            name: "RotationBridge",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("IOKit")
            ]
        )
    ]
)
