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

/// The "Aurora" look: a black notch, Helvetica Neue, and a soft three-colour glow while it is open.
public struct LookTheme: Codable, Equatable {
    /// The name of the palette chosen in the prototype ("aurora", "sunset", "mint", "mono"). Informational.
    public var palette: String
    /// The three glow colours as "#RRGGBB": inner, middle, outer.
    public var glowColors: [String]
    /// 0 turns the glow off, 1 is full strength.
    public var glowStrength: Double
    /// Base text size in points. The typed text and the tuner note scale from it.
    public var textSize: Double
    /// How long one pulse of the cursor takes, in milliseconds.
    public var caretBlinkMs: Double

    public static let auroraColors = ["#FF375F", "#0A84FF", "#BF5AF2"]

    public init(palette: String = "aurora", glowColors: [String] = LookTheme.auroraColors, glowStrength: Double = 0.8,
                textSize: Double = 19, caretBlinkMs: Double = 600) {
        self.palette = palette
        self.glowColors = glowColors
        self.glowStrength = glowStrength
        self.textSize = textSize
        self.caretBlinkMs = caretBlinkMs
    }

    private enum CodingKeys: String, CodingKey { case palette, glowColors, glowStrength, textSize, caretBlinkMs }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = LookTheme()
        palette = try c.decodeIfPresent(String.self, forKey: .palette) ?? d.palette
        glowColors = try c.decodeIfPresent([String].self, forKey: .glowColors) ?? d.glowColors
        glowStrength = try c.decodeIfPresent(Double.self, forKey: .glowStrength) ?? d.glowStrength
        textSize = try c.decodeIfPresent(Double.self, forKey: .textSize) ?? d.textSize
        caretBlinkMs = try c.decodeIfPresent(Double.self, forKey: .caretBlinkMs) ?? d.caretBlinkMs
    }

    /// The three glow colours as red, green, blue in 0...1. Always returns exactly three, falling back to
    /// the Aurora colours for anything missing or unreadable.
    public var glowRGB: [(red: Double, green: Double, blue: Double)] {
        return (0..<3).map { index in
            let fallback = LookTheme.auroraColors[index]
            let hex = index < glowColors.count ? glowColors[index] : fallback
            return LookTheme.rgb(hex: hex) ?? LookTheme.rgb(hex: fallback) ?? (red: 1, green: 1, blue: 1)
        }
    }

    /// "#RRGGBB" or "RRGGBB" to red, green, blue in 0...1. Nil when it cannot be read.
    public static func rgb(hex raw: String) -> (red: Double, green: Double, blue: Double)? {
        var hex = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.utf8.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
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

public struct TunerConfig: Codable, Equatable {
    /// Reference pitch for A4 in Hz. 440 unless he is playing along with something tuned differently.
    public var a4: Double
    /// How close, in cents, counts as in tune.
    public var toleranceCents: Double
    /// The tuning the tuner opens on. "chromatic" means any note.
    public var lastTuningID: String
    /// His own tunings, shown after the built-in ones.
    public var customTunings: [Tuning]

    public init(a4: Double = 440, toleranceCents: Double = 5, lastTuningID: String = "guitar-standard", customTunings: [Tuning] = []) {
        self.a4 = a4
        self.toleranceCents = toleranceCents
        self.lastTuningID = lastTuningID
        self.customTunings = customTunings
    }

    private enum CodingKeys: String, CodingKey { case a4, toleranceCents, lastTuningID, customTunings }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = TunerConfig()
        a4 = try c.decodeIfPresent(Double.self, forKey: .a4) ?? d.a4
        toleranceCents = try c.decodeIfPresent(Double.self, forKey: .toleranceCents) ?? d.toleranceCents
        lastTuningID = try c.decodeIfPresent(String.self, forKey: .lastTuningID) ?? d.lastTuningID
        customTunings = try c.decodeIfPresent([Tuning].self, forKey: .customTunings) ?? d.customTunings
    }

    /// Built-in tunings followed by his own.
    public var allTunings: [Tuning] {
        return DefaultTunings.all + customTunings
    }
}

/// Settings for "Ask". The key itself is never stored here: it lives in the Mac's Keychain.
public struct AskConfig: Codable, Equatable {
    /// Which Claude model answers. The small fast one is the right default.
    public var model: String
    /// The longest reply allowed, in tokens. Three sentences fit comfortably.
    public var maxTokens: Int
    /// A spending ceiling per calendar month, in US dollars. When it is reached he says so and stops asking.
    public var monthlyBudgetUSD: Double

    public init(model: String = "claude-haiku-4-5", maxTokens: Int = 300, monthlyBudgetUSD: Double = 2) {
        self.model = model
        self.maxTokens = maxTokens
        self.monthlyBudgetUSD = monthlyBudgetUSD
    }

    private enum CodingKeys: String, CodingKey { case model, maxTokens, monthlyBudgetUSD }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AskConfig()
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? d.model
        maxTokens = try c.decodeIfPresent(Int.self, forKey: .maxTokens) ?? d.maxTokens
        monthlyBudgetUSD = try c.decodeIfPresent(Double.self, forKey: .monthlyBudgetUSD) ?? d.monthlyBudgetUSD
    }
}

public struct Config: Codable, Equatable {
    public var hotkeys: Hotkeys
    public var brave: BraveConfig
    /// Master switch for the voice. The amber line shows either way.
    public var speak: Bool
    public var theme: Theme
    public var tuner: TunerConfig
    public var ask: AskConfig
    public var feedback: FeedbackConfig
    public var catalog: [CatalogEntry]

    public init(hotkeys: Hotkeys = Hotkeys(), brave: BraveConfig = BraveConfig(), speak: Bool = true,
                theme: Theme = Theme(), tuner: TunerConfig = TunerConfig(), ask: AskConfig = AskConfig(),
                feedback: FeedbackConfig = FeedbackConfig(), catalog: [CatalogEntry] = DefaultCatalog.entries) {
        self.hotkeys = hotkeys
        self.brave = brave
        self.speak = speak
        self.theme = theme
        self.tuner = tuner
        self.ask = ask
        self.feedback = feedback
        self.catalog = catalog
    }

    private enum CodingKeys: String, CodingKey { case hotkeys, brave, speak, theme, tuner, ask, feedback, catalog }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hotkeys = try c.decodeIfPresent(Hotkeys.self, forKey: .hotkeys) ?? Hotkeys()
        brave = try c.decodeIfPresent(BraveConfig.self, forKey: .brave) ?? BraveConfig()
        speak = try c.decodeIfPresent(Bool.self, forKey: .speak) ?? true
        theme = try c.decodeIfPresent(Theme.self, forKey: .theme) ?? Theme()
        tuner = try c.decodeIfPresent(TunerConfig.self, forKey: .tuner) ?? TunerConfig()
        ask = try c.decodeIfPresent(AskConfig.self, forKey: .ask) ?? AskConfig()
        feedback = try c.decodeIfPresent(FeedbackConfig.self, forKey: .feedback) ?? FeedbackConfig()
        catalog = try c.decodeIfPresent([CatalogEntry].self, forKey: .catalog) ?? DefaultCatalog.entries
    }
}
