import AppKit
import BrochachoCore
import SwiftUI

/// Three slides that explain the whole thing. Shown once on first launch; after that from the "?" in
/// settings, or by typing "help" in the notch. The hotkeys shown are whatever the config says right now.
@MainActor
final class TutorialWindow {
    private static let seenKey = "brochacho.tutorialSeen.v1"
    private var window: NSWindow?

    static var hasBeenSeen: Bool {
        return UserDefaults.standard.bool(forKey: seenKey)
    }

    func show(hotkeys: Hotkeys, theme: NotchTheme) {
        UserDefaults.standard.set(true, forKey: TutorialWindow.seenKey)
        window?.close()
        let view = TutorialView(slides: TutorialWindow.slides(hotkeys), theme: theme) { [weak self] in self?.window?.close() }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .black
        window.setContentSize(NSSize(width: 560, height: 420))
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// "ctrl+opt+space" as the Mac writes it: ⌃⌥Space.
    static func symbols(_ hotkey: String) -> String {
        let parts = hotkey.lowercased().split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        return parts.map { part -> String in
            switch part {
            case "cmd", "command": return "⌘"
            case "opt", "option", "alt": return "⌥"
            case "ctrl", "control": return "⌃"
            case "shift": return "⇧"
            case "space": return "Space"
            case "return", "enter": return "↩"
            default: return part.uppercased()
            }
        }.joined()
    }

    struct Slide {
        let title: String
        let lines: [(key: String, text: String)]
    }

    static func slides(_ hotkeys: Hotkeys) -> [Slide] {
        return [
            Slide(title: "Type a name.", lines: [
                (symbols(hotkeys.openBox), "opens the notch. Type yt, gmail, steam, any app on this Mac. Enter."),
                ("hold " + symbols(hotkeys.talk), "and say it instead. Let go when you are done."),
                ("yt berserk", "a site's name, then words, searches that site."),
                ("what is…", "anything that reads like a question gets a short answer.")
            ]),
            Slide(title: "Keep it. Get it back.", lines: [
                ("drag", "a link, a picture or a file onto the notch to keep it."),
                (symbols(hotkeys.saveTab), "keeps the page you are looking at."),
                ("click", "the notch, or type bored, and he hands one back."),
                (symbols(hotkeys.markPlace), "remembers where you stopped reading.")
            ]),
            Slide(title: "Little tools.", lines: [
                ("tune", "a guitar and ukulele tuner.  timer 10  counts down."),
                ("remind me…", "to call mom tomorrow at 5.  note  buy strings."),
                ("notes · reminders", "glance at what you saved, tick things off."),
                ("one eighty", "flips the screen.  settings  ·  help  ·  right-click the notch.")
            ])
        ]
    }
}

private struct TutorialView: View {
    let slides: [TutorialWindow.Slide]
    let theme: NotchTheme
    let close: () -> Void
    @State private var index = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(index + 1) / \(slides.count)")
                .font(theme.font(13))
                .foregroundStyle(NotchTheme.dim)
                .padding(.top, 36)

            Text(slides[index].title)
                .font(theme.font(44, .light))
                .kerning(-1)
                .foregroundStyle(.white)
                .padding(.top, 6)
                .padding(.bottom, 22)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(slides[index].lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text(line.key)
                            .font(theme.font(15, .medium))
                            .foregroundStyle(theme.tint)
                            .frame(width: 150, alignment: .leading)
                        Text(line.text)
                            .font(theme.font(15))
                            .foregroundStyle(Color(white: 0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .id(index)
            .transition(.opacity)

            Spacer()

            HStack(spacing: 8) {
                ForEach(0..<slides.count, id: \.self) { dot in
                    Capsule()
                        .fill(dot == index ? Color.white : Color.white.opacity(0.25))
                        .frame(width: dot == index ? 22 : 8, height: 8)
                }
                Spacer()
                if index > 0 {
                    Button("Back") { withAnimation(theme.spring) { index -= 1 } }
                        .buttonStyle(PillButtonStyle(theme: theme))
                }
                Button(index == slides.count - 1 ? "Done" : "Next") {
                    if index == slides.count - 1 {
                        close()
                    } else {
                        withAnimation(theme.spring) { index += 1 }
                    }
                }
                .buttonStyle(PillButtonStyle(theme: theme))
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 40)
        .frame(width: 560, height: 420, alignment: .topLeading)
        .background(
            ZStack {
                Color.black
                RadialGradient(colors: [theme.glowColors[1].opacity(0.35), .clear], center: .topTrailing, startRadius: 10, endRadius: 420)
                RadialGradient(colors: [theme.glowColors[0].opacity(0.22), .clear], center: .bottomLeading, startRadius: 10, endRadius: 380)
            }
        )
        .foregroundStyle(.white)
    }
}
