import AppKit
import SwiftUI

/// The character out of the notch: a small window, exactly his size, that flies around the screen.
///
/// He comes out when a job is due and wanders silently. He never speaks while he is out; the voice waits
/// until someone clicks him. Because the *window itself* moves and is only as big as he is, every click
/// that misses him lands on whatever is underneath, as if he were not there.
///
/// How bold he is depends on how often he has been ignored (`level`, from `Jobs.nextNudge`):
///   0  bobs just under the notch
///   1  drifts along the top of the screen
///   2  wanders the upper third, half as big again
///   3  loops around the middle of the screen, twice the size
/// If nobody clicks him for `roamSeconds`, he flies home and `onGaveUp` runs (the next time he is bolder).
@MainActor
final class Roamer {
    var onClick: () -> Void = {}
    var onGaveUp: () -> Void = {}
    var menuProvider: () -> NSMenu? = { nil }

    private(set) var isOut = false

    private enum Phase {
        case leaving(since: Date)
        case roaming
        case holding(at: CGPoint)
        case returning(since: Date, from: CGPoint, fromScale: CGFloat, then: () -> Void)
    }

    private final class Look: ObservableObject {
        @Published var frames = CharacterFrames.bundled
        @Published var flying = true
        @Published var facingLeft = false
    }

    private let look = Look()
    private var panel: NSPanel?
    private var ticker: Timer?
    private var phase = Phase.roaming
    private var level = 0
    private var size: CGFloat = 64
    private var started = Date()
    private var giveUpAt = Date.distantFuture
    private var center = CGPoint.zero
    private var scale: CGFloat = 1

    /// Where he is now, in screen coordinates. Used to put the job card beside him.
    var frame: NSRect {
        return panel?.frame ?? .zero
    }

    // MARK: out and home

    func flyOut(level: Int, size: CGFloat, frames: CharacterFrames, roamSeconds: Double) {
        self.level = max(0, min(3, level))
        self.size = max(24, size)
        look.frames = frames
        look.flying = true
        started = Date()
        giveUpAt = Date().addingTimeInterval(max(20, roamSeconds))
        center = Roamer.home
        scale = 0.3
        phase = .leaving(since: Date())
        isOut = true
        makePanel()
        panel?.orderFrontRegardless()
        startTicking()
    }

    /// Stays where he is (while his card is open).
    func hold() {
        guard isOut else { return }
        phase = .holding(at: center)
        look.flying = false
        giveUpAt = .distantFuture
    }

    /// Back into the notch. `then` runs once he has arrived.
    func goHome(then: @escaping () -> Void = {}) {
        guard isOut else {
            then()
            return
        }
        look.flying = true
        phase = .returning(since: Date(), from: center, fromScale: scale, then: then)
    }

    // MARK: the window

    private func makePanel() {
        if panel != nil { return }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        // Above ordinary windows and the menu bar, below the notch sensor and the notch itself.
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        let host = NSHostingView(rootView: RoamerView(look: look))
        let catcher = ClickCatcher(frame: panel.contentLayoutRect)
        catcher.autoresizingMask = [.width, .height]
        host.frame = catcher.bounds
        host.autoresizingMask = [.width, .height]
        catcher.addSubview(host)
        catcher.onClick = { [weak self] in self?.onClick() }
        catcher.menuProvider = { [weak self] in self?.menuProvider() }
        panel.contentView = catcher
        self.panel = panel
    }

    private func startTicking() {
        ticker?.invalidate()
        // 30 times a second is smooth enough for a little dragon and easy on the battery.
        ticker = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func stop() {
        ticker?.invalidate()
        ticker = nil
        panel?.orderOut(nil)
        isOut = false
    }

    // MARK: moving

    /// Where the notch is: he leaves from here and comes back here.
    private static var home: CGPoint {
        let screen = NotchController.preferredScreen
        if let notch = screen.brochachoNotchFrame { return CGPoint(x: notch.midX, y: notch.midY) }
        return CGPoint(x: screen.frame.midX, y: screen.frame.maxY - 12)
    }

    /// Where the path for his level wants him at `t` seconds, and how big.
    private func target(_ t: Double) -> (CGPoint, CGFloat) {
        let f = NotchController.preferredScreen.visibleFrame
        let top = f.maxY - size * 0.75
        switch level {
        case 0:
            return (CGPoint(x: f.midX + sin(t * 0.9) * 40, y: top + sin(t * 3) * 4), 1)
        case 1:
            return (CGPoint(x: f.midX + sin(t * 0.22) * f.width * 0.42, y: top + sin(t * 1.7) * 8), 1)
        case 2:
            return (CGPoint(x: f.midX + sin(t * 0.3) * f.width * 0.4, y: f.maxY - f.height * 0.22 + sin(t * 0.53) * f.height * 0.12), 1.5)
        default:
            // A figure of eight around the middle of the screen.
            return (CGPoint(x: f.midX + sin(t * 0.5) * f.width * 0.28, y: f.midY + sin(t * 1.0) * f.height * 0.2), 2)
        }
    }

    private func tick() {
        guard isOut else { return }
        let now = Date()
        let t = now.timeIntervalSince(started)
        var next = center
        var nextScale = scale

        switch phase {
        case .leaving(let since):
            let p = ease(min(1, now.timeIntervalSince(since) / 1.1))
            let (goal, goalScale) = target(t)
            next = lerp(Roamer.home, goal, p)
            nextScale = 0.3 + (goalScale - 0.3) * p
            if p >= 1 { phase = .roaming }
        case .roaming:
            (next, nextScale) = target(t)
            if now >= giveUpAt {
                goHome { [weak self] in self?.onGaveUp() }
            }
        case .holding(let spot):
            next = CGPoint(x: spot.x, y: spot.y + sin(t * 2.5) * 2)
        case .returning(let since, let from, let fromScale, let then):
            let p = ease(min(1, now.timeIntervalSince(since) / 0.9))
            next = lerp(from, Roamer.home, p)
            nextScale = fromScale + (0.2 - fromScale) * p
            if p >= 1 {
                stop()
                then()
                return
            }
        }

        if abs(next.x - center.x) > 0.3 { look.facingLeft = next.x < center.x }
        center = next
        scale = nextScale
        let side = size * scale
        panel?.setFrame(NSRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side), display: true)
    }

    private func ease(_ p: Double) -> Double {
        return p < 0.5 ? 2 * p * p : 1 - pow(-2 * p + 2, 2) / 2
    }

    private func lerp(_ a: CGPoint, _ b: CGPoint, _ p: Double) -> CGPoint {
        return CGPoint(x: a.x + (b.x - a.x) * p, y: a.y + (b.y - a.y) * p)
    }

    private struct RoamerView: View {
        @ObservedObject var look: Look

        var body: some View {
            CharacterView(frames: look.frames, flying: look.flying, facingLeft: look.facingLeft)
                .shadow(color: .black.opacity(0.35), radius: 3, y: -1)
        }
    }
}

/// Takes every click inside the little window for itself, so SwiftUI never has to be the key window to react.
private final class ClickCatcher: NSView {
    var onClick: () -> Void = {}
    var menuProvider: () -> NSMenu? = { nil }

    override func hitTest(_ point: NSPoint) -> NSView? {
        return frame.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onClick()
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = menuProvider() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}
