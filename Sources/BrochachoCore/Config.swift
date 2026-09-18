import Foundation

// Everything the user can change lives in one file: ~/.brochacho/config.json
// Every field has a default, so a config that leaves things out (or an older config) still loads.

public struct Hotkeys: Codable, Equatable {
    /// Opens the box in the notch. Written as "opt+space" in config.json under the key "open".
    public var openBox: String
    /// Held down to talk, released to run. Config key "talk".
    public var talk: String
    /// Saves the front browser tab to the stash. No window appears. Config key "save".
    public var saveTab: String

    public init(openBox: String = "opt+space", talk: String = "right_opt", saveTab: String = "opt+s") {
        self.openBox = openBox
        self.talk = talk
        self.saveTab = saveTab
    }

    private enum CodingKeys: String, CodingKey {
        case openBox = "open"
        case talk
        case saveTab = "save"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Hotkeys()
        openBox = try c.decodeIfPresent(String.self, forKey: .openBox) ?? d.openBox
        talk = try c.decodeIfPresent(String.self, forKey: .talk) ?? d.talk
        saveTab = try c.decodeIfPresent(String.self, forKey: .saveTab) ?? d.saveTab
    }
}

public struct BraveConfig: Codable, Equatable {
    /// The Brave binary. Launched directly, because `open -a` drops its arguments when Brave is already running.
    public var binaryPath: String
    /// Folder names inside Brave's user data directory. Found on day one; see DAY_ONE.md.
    public var personalProfileDir: String
    public var workProfileDir: String

    public init(binaryPath: String = "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
                personalProfileDir: String = "Default", workProfileDir: String = "Profile 1") {
        self.binaryPath = binaryPath
        self.personalProfileDir = personalProfileDir
        self.workProfileDir = workProfileDir
    }

    private enum CodingKeys: String, CodingKey { case binaryPath, personalProfileDir, workProfileDir }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = BraveConfig()
        binaryPath = try c.decodeIfPresent(String.self, forKey: .binaryPath) ?? d.binaryPath
        personalProfileDir = try c.decodeIfPresent(String.self, forKey: .personalProfileDir) ?? d.personalProfileDir
        workProfileDir = try c.decodeIfPresent(String.self, forKey: .workProfileDir) ?? d.workProfileDir
    }

    /// The profile directory for a catalog entry's `profile` value.
    public func profileDirectory(for profile: String) -> String {
        return profile == "work" ? workProfileDir : personalProfileDir
    }
}

/// The spring that drives the notch. Same numbers as the phone prototype:
/// SwiftUI `interpolatingSpring(mass: 1, stiffness:, damping:)`.
public struct MotionTheme: Codable, Equatable {
    public var stiffness: Double
    public var damping: Double

    public init(stiffness: Double = 260, damping: Double = 24) {
        self.stiffness = stiffness
        self.damping = damping
    }

    private enum CodingKeys: String, CodingKey { case stiffness, damping }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = MotionTheme()
        stiffness = try c.decodeIfPresent(Double.self, forKey: .stiffness) ?? d.stiffness
        damping = try c.decodeIfPresent(Double.self, forKey: .damping) ?? d.damping
    }
}

public struct LookTheme: Codable, Equatable {
    /// Text colour as "#RRGGBB".
    public var phosphor: String
    /// Glow radius in points. 0 turns it off.
    public var glow: Double
    /// Font family name. Falls back to the system monospaced font when it is not installed.
    public var font: String
    public var textSize: Double
    /// How long the cursor stays on (and then off), in milliseconds.
    public var cursorBlinkMs: Double

    public init(phosphor: String = "#FFB000", glow: Double = 6, font: String = "VT323", textSize: Double = 22,
                cursorBlinkMs: Double = 530) {
        self.phosphor = phosphor
        self.glow = glow
        self.font = font
        self.textSize = textSize
        self.cursorBlinkMs = cursorBlinkMs
    }

    private enum CodingKeys: String, CodingKey { case phosphor, glow, font, textSize, cursorBlinkMs }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = LookTheme()
        phosphor = try c.decodeIfPresent(String.self, forKey: .phosphor) ?? d.phosphor
        glow = try c.decodeIfPresent(Double.self, forKey: .glow) ?? d.glow
        font = try c.decodeIfPresent(String.self, forKey: .font) ?? d.font
        textSize = try c.decodeIfPresent(Double.self, forKey: .textSize) ?? d.textSize
        cursorBlinkMs = try c.decodeIfPresent(Double.self, forKey: .cursorBlinkMs) ?? d.cursorBlinkMs
    }

    /// The phosphor colour as red, green, blue in 0...1. Falls back to amber when the string is not "#RRGGBB".
    public var phosphorRGB: (red: Double, green: Double, blue: Double) {
        let amber = (red: 1.0, green: 176.0 / 255.0, blue: 0.0)
        var hex = phosphor.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.utf8.count == 6, let value = UInt32(hex, radix: 16) else { return amber }
        return (red: Double((value >> 16) & 0xFF) / 255.0,
                green: Double((value >> 8) & 0xFF) / 255.0,
                blue: Double(value & 0xFF) / 255.0)
    }
}

public struct VoiceTheme: Codable, Equatable {
    /// The name of the system voice to use. Empty means "the best Italian voice installed".
    public var voiceName: String
    /// 1.0 is the voice's normal speed.
    public var rate: Double
    public var pitch: Double
    /// Chance, 0 to 1, that a line is spoken as well as shown.
    public var frequency: Double

    public init(voiceName: String = "", rate: Double = 0.95, pitch: Double = 0.9, frequency: Double = 0.6) {
        self.voiceName = voiceName
        self.rate = rate
        self.pitch = pitch
        self.frequency = frequency
    }

    private enum CodingKeys: String, CodingKey { case voiceName, rate, pitch, frequency }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = VoiceTheme()
        voiceName = try c.decodeIfPresent(String.self, forKey: .voiceName) ?? d.voiceName
        rate = try c.decodeIfPresent(Double.self, forKey: .rate) ?? d.rate
        pitch = try c.decodeIfPresent(Double.self, forKey: .pitch) ?? d.pitch
        frequency = try c.decodeIfPresent(Double.self, forKey: .frequency) ?? d.frequency
    }
}

/// The block the phone prototype exports. Paste it over "theme" in config.json.
public struct Theme: Codable, Equatable {
    public var motion: MotionTheme
    public var look: LookTheme
    public var voice: VoiceTheme

    public init(motion: MotionTheme = MotionTheme(), look: LookTheme = LookTheme(), voice: VoiceTheme = VoiceTheme()) {
        self.motion = motion
        self.look = look
        self.voice = voice
    }

    private enum CodingKeys: String, CodingKey { case motion, look, voice }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        motion = try c.decodeIfPresent(MotionTheme.self, forKey: .motion) ?? MotionTheme()
        look = try c.decodeIfPresent(LookTheme.self, forKey: .look) ?? LookTheme()
        voice = try c.decodeIfPresent(VoiceTheme.self, forKey: .voice) ?? VoiceTheme()
    }
}

public struct Config: Codable, Equatable {
    public var hotkeys: Hotkeys
    public var brave: BraveConfig
    /// Master switch for the voice. The amber line shows either way.
    public var speak: Bool
    public var theme: Theme
    public var catalog: [CatalogEntry]

    public init(hotkeys: Hotkeys = Hotkeys(), brave: BraveConfig = BraveConfig(), speak: Bool = true,
                theme: Theme = Theme(), catalog: [CatalogEntry] = DefaultCatalog.entries) {
        self.hotkeys = hotkeys
        self.brave = brave
        self.speak = speak
        self.theme = theme
        self.catalog = catalog
    }

    private enum CodingKeys: String, CodingKey { case hotkeys, brave, speak, theme, catalog }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hotkeys = try c.decodeIfPresent(Hotkeys.self, forKey: .hotkeys) ?? Hotkeys()
        brave = try c.decodeIfPresent(BraveConfig.self, forKey: .brave) ?? BraveConfig()
        speak = try c.decodeIfPresent(Bool.self, forKey: .speak) ?? true
        theme = try c.decodeIfPresent(Theme.self, forKey: .theme) ?? Theme()
        catalog = try c.decodeIfPresent([CatalogEntry].self, forKey: .catalog) ?? DefaultCatalog.entries
    }
}
