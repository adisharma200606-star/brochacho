import AppKit
import BrochachoCore

/// Carries out an `ActionPlan`. The brain decides, this file does.
enum Opener {

    /// Opens a site, an app or a folder. Returns false when it could not.
    @discardableResult
    static func run(_ plan: ActionPlan, config: Config) -> Bool {
        switch plan {
        case .openURL(let url, let profile, _):
            return openInBrave(url, profileDirectory: config.brave.profileDirectory(for: profile), brave: config.brave)
        case .openApp(let bundleID, _):
            return openApp(bundleID)
        case .openPath(let path, _):
            return NSWorkspace.shared.open(URL(fileURLWithPath: BrochachoPaths.expandTilde(path)))
        case .openTool, .ask:
            return false    // these are handled by the Brain, not here
        }
    }

    /// Launches Brave's own program file with the profile and the address.
    ///
    /// `open -a "Brave Browser" --args ...` would be simpler, but macOS throws the arguments away when Brave
    /// is already running, and Brave is always already running. Started this way, the new process hands the
    /// address to the running Brave, in the right profile, and exits.
    static func openInBrave(_ address: String, profileDirectory: String, brave: BraveConfig) -> Bool {
        let binary = URL(fileURLWithPath: brave.binaryPath)
        if FileManager.default.isExecutableFile(atPath: binary.path) {
            let process = Process()
            process.executableURL = binary
            process.arguments = ["--profile-directory=\(profileDirectory)", address]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                return true
            } catch {
                NSLog("Brochacho: could not start Brave: \(error)")
            }
        }
        // Brave is not where the config says. Fall back to whatever the default browser is.
        guard let url = URL(string: address) else { return false }
        return NSWorkspace.shared.open(url)
    }

    static func openApp(_ bundleID: String) -> Bool {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            NSLog("Brochacho: no app with bundle id \(bundleID)")
            return false
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
        return true
    }

    /// Opens something from the stash. Links go to the personal Brave profile; files open in their own app.
    /// Notes have nothing to open: the notch shows them.
    @discardableResult
    static func open(_ item: StashItem, config: Config) -> Bool {
        switch item.kind {
        case "url":
            return openInBrave(item.payload, profileDirectory: config.brave.personalProfileDir, brave: config.brave)
        case "file", "image":
            return NSWorkspace.shared.open(URL(fileURLWithPath: item.payload))
        default:
            return true
        }
    }
}
