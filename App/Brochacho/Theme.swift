import BrochachoCore
import SwiftUI

/// The Aurora look, turned from config values into things SwiftUI can use.
struct NotchTheme: Equatable {
    var glowColors: [Color]
    var glowStrength: Double
    var textSize: CGFloat
    var caretPulse: Double
    /// The colour of the line he says.
    var tint: Color
    var stiffness: Double
    var damping: Double

    /// The same spring as the phone prototype: mass 1, and the two numbers from the config.
    var spring: Animation {
        return .interpolatingSpring(mass: 1, stiffness: stiffness, damping: damping, initialVelocity: 0)
    }

    static let off = Color(red: 1.0, green: 0.62, blue: 0.04)      // a string that is out of tune
    static let ok = Color(red: 0.19, green: 0.82, blue: 0.35)      // a string that is in tune
    static let dim = Color(white: 0.6)
    static let row = Color.white.opacity(0.14)

    init(_ theme: Theme) {
        let rgb = theme.look.glowRGB
        glowColors = rgb.map { Color(red: $0.red, green: $0.green, blue: $0.blue) }
        glowStrength = theme.look.glowStrength
        textSize = CGFloat(theme.look.textSize)
        caretPulse = max(0.15, theme.look.caretBlinkMs / 1000)
        // A pale tint of the outer glow colour, so the line belongs to whichever palette is chosen.
        let outer = rgb[2]
        tint = Color(red: 0.75 + outer.red * 0.25, green: 0.75 + outer.green * 0.25, blue: 0.75 + outer.blue * 0.25)
        stiffness = theme.motion.stiffness
        damping = theme.motion.damping
    }

    /// Helvetica Neue ships with every Mac. These are its PostScript names.
    func font(_ size: CGFloat, _ weight: HelveticaWeight = .regular) -> Font {
        return .custom(weight.rawValue, size: size)
    }

    enum HelveticaWeight: String {
        case ultraLight = "HelveticaNeue-UltraLight"
        case light = "HelveticaNeue-Light"
        case regular = "HelveticaNeue"
        case medium = "HelveticaNeue-Medium"
        case bold = "HelveticaNeue-Bold"
    }
}
