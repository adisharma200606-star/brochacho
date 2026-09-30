import AppKit
import BrochachoCore
import DynamicNotchKit
import SwiftUI

/// Opens and closes the notch. A thin wrapper around DynamicNotchKit that adds the three things a launcher
/// needs and the library does not do by itself: taking the keyboard at once, closing on Escape or a click
/// elsewhere, and moving the selection with the arrow keys.
@MainActor
final class NotchController {
    private let model: NotchModel
    private let notch: DynamicNotch<NotchRootView, CompactLeadingView, CompactTrailingView>
    private var keyMonitor: Any?
    private var clickMonitor: Any?

    private(set) var isOpen = false
    /// Called when the person dismisses the notch themselves (Escape, or a click somewhere else).
    var onDismiss: () -> Void = {}
    /// Called on Return/Enter while the box is open. Handled here, in the same reliable local key
    /// monitor as Escape and the arrow keys, rather than relying only on SwiftUI's TextField `.onSubmit` —
    /// a real case existed where Return stopped reaching that callback (remote input via iPhone Mirroring)
    /// while every other key kept working fine through this monitor.
    var onEnter: () -> Void = {}

    init(model: NotchModel) {
        self.model = model
        // Hover behaviour is left empty on purpose. The library's "keep visible while hovering" would hold the
        // notch open after an action if the pointer happened to be resting near the top of the screen.
        notch = DynamicNotch(hoverBehavior: [], style: .auto) {
            NotchRootView(model: model)
        } compactLeading: {
            CompactLeadingView(model: model)
        } compactTrailing: {
            CompactTrailingView(model: model)
        }
        apply(model.theme)
        installMonitors()
    }

    /// Pushes the look into the notch: the spring from the config, and the glow.
    func apply(_ theme: NotchTheme) {
        notch.transitionConfiguration = DynamicNotchTransitionConfiguration(
            openingAnimation: theme.spring,
            closingAnimation: .smooth(duration: 0.3),
            conversionAnimation: theme.spring,
            skipIntermediateHides: true
        )
        notch.glowColors = theme.glowColors
        notch.glowStrength = theme.glowStrength
        notch.rimColor = theme.accent.opacity(0.85)
        notch.grainImage = theme.grain > 0 ? NotchTheme.grainImage : nil
        notch.grainOpacity = theme.grain
    }

    /// The screen with the notch if there is one, otherwise the main screen.
    static var preferredScreen: NSScreen {
        if let notched = NSScreen.screens.first(where: { $0.brochachoNotchFrame != nil }) { return notched }
        return NSScreen.main ?? NSScreen.screens[0]
    }

    /// Opens the notch. `takeKeyboard` is true for the box, false for a line that only needs to be read.
    func open(takeKeyboard: Bool) {
        isOpen = true
        let screen = NotchController.preferredScreen
        Task { await notch.expand(on: screen) }
        guard takeKeyboard else { return }

        // `expand` only returns after its animation. The window exists long before that, so take the
        // keyboard as soon as it appears instead of waiting: typing must work from the first moment.
        Task { @MainActor in
            for _ in 0..<40 {
                if let window = notch.windowController?.window {
                    window.makeKey()
                    model.focusToken += 1
                    return
                }
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
        }
    }

    /// Closes the notch. While a timer is running it shrinks to the compact form, which shows the time left.
    func close() {
        isOpen = false
        let screen = NotchController.preferredScreen
        // The small timer beside the notch only exists on a screen with a notch (for example, not while the
        // screen is flipped upside down).
        let showTimer = model.timerText != nil && screen.brochachoNotchFrame != nil
        Task {
            if showTimer {
                await notch.compact(on: screen)
            } else {
                await notch.hide()
            }
        }
    }

    private func installMonitors() {
        // Keys pressed while our panel has the keyboard.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isOpen else { return event }
            switch event.keyCode {
            case 53:    // Escape
                self.onDismiss()
                return nil
            case 36, 76:  // Return, and the numeric-keypad Enter
                if self.model.screen == .input {
                    self.onEnter()
                    return nil
                }
                return event
            case 125:   // down arrow
                if self.model.screen == .input { self.model.moveSelection(1); return nil }
                return event
            case 126:   // up arrow
                if self.model.screen == .input { self.model.moveSelection(-1); return nil }
                return event
            default:
                return event
            }
        }
        // A click anywhere outside our own windows. Global monitors only ever see other apps' events.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isOpen else { return }
                self.onDismiss()
            }
        }
    }
}

extension NSScreen {
    /// The rectangle of the physical notch in screen coordinates, or nil on a screen without one.
    /// (DynamicNotchKit has the same calculation, but keeps it private.)
    var brochachoNotchFrame: NSRect? {
        guard let left = auxiliaryTopLeftArea?.width, let right = auxiliaryTopRightArea?.width else { return nil }
        let height = safeAreaInsets.top
        let width = frame.width - left - right
        guard width > 0, height > 0 else { return nil }
        return NSRect(x: frame.midX - width / 2, y: frame.maxY - height, width: width, height: height)
    }
}
