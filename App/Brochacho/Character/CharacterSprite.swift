import AppKit
import BrochachoCore
import SwiftUI

/// The pictures of the character: sitting (idle) and flying. All facing right; the view mirrors them.
///
/// Where they come from, first match wins:
///   1. `character.folder` in the config (~/.brochacho/character by default):
///      idle_0.png, idle_1.png… and fly_0.png, fly_1.png… or simply idle.png and fly.png.
///      A folder with any other PNGs in it uses those, in name order, as the idle frames.
///   2. The little dragon that ships inside the app (scripts/make_sprites.py).
/// Someone else's art (a Dragonite) belongs in the folder, never in the repo.
struct CharacterFrames {
    var idle: [NSImage]
    var fly: [NSImage]

    static func load(folder: String) -> CharacterFrames {
        let url = URL(fileURLWithPath: BrochachoPaths.expandTilde(folder), isDirectory: true)
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? [])
            .filter { $0.lowercased().hasSuffix(".png") }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let images: ([String]) -> [NSImage] = { list in list.compactMap { NSImage(contentsOf: url.appendingPathComponent($0)) } }

        var idle = images(names.filter { $0.lowercased().hasPrefix("idle") })
        let fly = images(names.filter { $0.lowercased().hasPrefix("fly") })
        if idle.isEmpty { idle = images(names.filter { !$0.lowercased().hasPrefix("fly") }) }
        if idle.isEmpty { return bundled }
        return CharacterFrames(idle: idle, fly: fly.isEmpty ? idle : fly)
    }

    /// The little dragon. Xcode flattens resources, so they sit at the top of the bundle; the folder is a fallback.
    static let bundled: CharacterFrames = {
        let image: (String) -> NSImage? = { name in
            let url = Bundle.main.url(forResource: name, withExtension: "png")
                ?? Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "character")
            return url.flatMap { NSImage(contentsOf: $0) }
        }
        let idle = ["dragon_idle_0", "dragon_idle_1"].compactMap(image)
        let fly = ["dragon_fly_0", "dragon_fly_1"].compactMap(image)
        if idle.isEmpty { NSLog("Brochacho: the dragon's pictures are missing from the app") }
        return CharacterFrames(idle: idle, fly: fly.isEmpty ? idle : fly)
    }()
}

/// The character, animated. Pixel art stays crisp because it is scaled without smoothing.
struct CharacterView: View {
    let frames: CharacterFrames
    var flying = false
    var facingLeft = false

    var body: some View {
        let list = flying ? frames.fly : frames.idle
        let interval = flying ? 0.14 : 0.55
        TimelineView(.periodic(from: .now, by: interval)) { context in
            let index = list.isEmpty ? 0 : Int(context.date.timeIntervalSinceReferenceDate / interval) % list.count
            Group {
                if list.indices.contains(index) {
                    Image(nsImage: list[index])
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Color.clear
                }
            }
            .scaleEffect(x: facingLeft ? -1 : 1, y: 1)
        }
    }
}
