# What was changed in this copy of DynamicNotchKit

This folder is a copy of [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit) 1.1.0 by Kai Azim, used under its MIT licence (see `LICENSE`).

It is copied into the repo, instead of being downloaded, for one reason: the library draws the notch's shadow itself, and it masks whatever you put inside the notch to the notch's shape. So the Aurora glow, which sits *outside* that shape, cannot be added from outside the library. Two small edits add it. Both are marked `BROCHACHO PATCH` in the source.

1. `Sources/DynamicNotchKit/DynamicNotch/DynamicNotch.swift` gains two published properties, `glowColors` and `glowStrength`. Leave them alone and the library behaves exactly as upstream.
2. `Sources/DynamicNotchKit/Views/NotchContentView.swift` adds three coloured shadows that are only visible while the notch is expanded.

Also removed: the `Documentation.docc` folder and the `swift-docc-plugin` dependency in `Package.swift`, so building needs no extra downloads.

To update to a newer upstream version: replace `Sources/` with the new one and re-apply the two edits.
