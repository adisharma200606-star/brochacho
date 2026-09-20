import AppKit
import BrochachoCore
import SwiftUI

/// The settings window. Opened by typing "settings" in the notch, or from the right-click menu on the notch.
/// Everything here edits the same `config.json` described in docs/GUIDE.md; nothing is stored anywhere else
/// except the API key, which goes to the Keychain.
@MainActor
final class SettingsWindow {
    private var window: NSWindow?

    func show(brain: Brain) {
        if window == nil {
            let host = NSHostingController(rootView: SettingsView(state: SettingsState(brain: brain)))
            let window = NSWindow(contentViewController: host)
            window.title = "Brochacho"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 720, height: 520))
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        // The app has no Dock icon, so it has to step forward by itself for the window to take the keyboard.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

/// A working copy of the config. "Save" writes it back through the Brain, which re-applies everything.
@MainActor
final class SettingsState: ObservableObject {
    let brain: Brain
    @Published var config: Config
    @Published var selection: String? = nil
    @Published var apiKey: String = ""
    @Published var note: String = ""

    init(brain: Brain) {
        self.brain = brain
        self.config = brain.config
        self.apiKey = AskClient.Keychain.read() ?? ""
    }

    var selectedIndex: Int? {
        guard let selection = selection else { return nil }
        return config.catalog.firstIndex { $0.name == selection }
    }

    func addEntry(from tab: TabGrabber.Tab? = nil) {
        var name = "new thing"
        var n = 2
        while config.catalog.contains(where: { $0.name == name }) {
            name = "new thing \(n)"
            n += 1
        }
        let entry = CatalogEntry(name: name, display: tab?.title.isEmpty == false ? tab?.title : nil, aliases: [], kind: .site,
                                 target: tab?.url ?? "https://", profile: "personal")
        config.catalog.append(entry)
        selection = name
        note = tab == nil ? "" : "Filled in from the page in front. Give it a name."
    }

    func addFrontPage() {
        guard let tab = TabGrabber.frontTab() else {
            note = "No browser page in front, or the browser would not say. Open the page, then try again."
            return
        }
        addEntry(from: tab)
    }

    func deleteSelected() {
        guard let index = selectedIndex else { return }
        config.catalog.remove(at: index)
        selection = nil
    }

    /// A name that another entry already answers to, if any.
    func clash(for entry: CatalogEntry) -> String? {
        let mine = Set(entry.keys.map { TextTools.normalize($0) }.filter { !$0.isEmpty })
        for other in config.catalog where other.name != entry.name {
            for key in other.keys where mine.contains(TextTools.normalize(key)) {
                return "\"\(key)\" already opens \(other.shownName)."
            }
        }
        return nil
    }

    func save() {
        AskClient.Keychain.write(apiKey)
        brain.update(config)
        note = "Saved."
    }
}

struct SettingsView: View {
    @ObservedObject var state: SettingsState

    var body: some View {
        TabView {
            ThingsTab(state: state).tabItem { Text("Things") }
            VoiceTab(state: state).tabItem { Text("Voice and sound") }
            AskTab(state: state).tabItem { Text("Ask") }
            KeysTab(state: state).tabItem { Text("Hotkeys and files") }
        }
        .padding(16)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Text(state.note).foregroundStyle(.secondary)
                Spacer()
                Button("Save") { state.save() }
                    .keyboardShortcut("s", modifiers: .command)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
}

// MARK: Things

private struct ThingsTab: View {
    @ObservedObject var state: SettingsState

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                List(state.config.catalog, id: \.name, selection: $state.selection) { entry in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.shownName)
                        Text(entry.keys.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Button("Add") { state.addEntry() }
                    Button("Add the page I'm on") { state.addFrontPage() }
                    Spacer()
                    Button("Delete") { state.deleteSelected() }.disabled(state.selectedIndex == nil)
                }
            }
            .frame(width: 270)

            if let index = state.selectedIndex {
                EntryForm(entry: $state.config.catalog[index], selection: $state.selection, clash: state.clash(for: state.config.catalog[index]))
            } else {
                Text("Pick a thing on the left, or add one.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct EntryForm: View {
    @Binding var entry: CatalogEntry
    @Binding var selection: String?
    let clash: String?

    private var aliasText: Binding<String> {
        Binding(
            get: { entry.aliases.joined(separator: ", ") },
            set: { entry.aliases = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        )
    }

    private func optional(_ keyPath: WritableKeyPath<CatalogEntry, String?>) -> Binding<String> {
        Binding(
            get: { entry[keyPath: keyPath] ?? "" },
            set: { entry[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    var body: some View {
        Form {
            TextField("Name (what you type)", text: Binding(
                get: { entry.name },
                set: { entry.name = $0.lowercased(); selection = entry.name }
            ))
            TextField("Other names, separated by commas", text: aliasText)
            TextField("Shown as", text: optional(\.display))

            Picker("Opens", selection: $entry.kind) {
                Text("A web page").tag(EntryKind.site)
                Text("An app").tag(EntryKind.app)
                Text("A folder or file").tag(EntryKind.path)
                Text("Something built in").tag(EntryKind.tool)
            }

            TextField(targetLabel, text: $entry.target)

            if entry.kind == .site {
                Picker("Brave profile", selection: Binding(get: { entry.profile ?? "personal" }, set: { entry.profile = $0 })) {
                    Text("Personal").tag("personal")
                    Text("Work").tag("work")
                }
                TextField("Search address, with {q} where the words go (optional)", text: optional(\.searchTemplate))
                Toggle("Remember where I left off", isOn: $entry.living)
            }

            if let clash = clash {
                Text(clash).foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var targetLabel: String {
        switch entry.kind {
        case .site: return "Address"
        case .app: return "Bundle identifier, like com.valvesoftware.steam"
        case .path: return "Path, like ~/Downloads"
        case .tool: return "Tool name: tuner, timer, note, reminder or settings"
        }
    }
}

// MARK: Voice and sound

private struct VoiceTab: View {
    @ObservedObject var state: SettingsState

    var body: some View {
        Form {
            Toggle("He speaks", isOn: $state.config.speak)
            Picker("Voice", selection: $state.config.theme.voice.voiceName) {
                Text("Best Italian voice installed").tag("")
                ForEach(Mouth.italianVoiceNames, id: \.self) { Text($0).tag($0) }
            }
            Slider(value: $state.config.theme.voice.frequency, in: 0...1) { Text("How often he talks") }
            Slider(value: $state.config.theme.voice.rate, in: 0.6...1.4) { Text("Speed") }
            Slider(value: $state.config.theme.voice.pitch, in: 0.5...1.5) { Text("Pitch") }
            Button("Say a line") { state.brain.sayTestLine(with: state.config.theme.voice) }

            Divider()
            Toggle("Interface sounds", isOn: $state.config.feedback.sounds)
            Slider(value: $state.config.feedback.volume, in: 0...1) { Text("Volume") }
            Toggle("Trackpad taps", isOn: $state.config.feedback.haptics)

            Text("More and better Italian voices: System Settings, Accessibility, Spoken Content, System Voice, Manage Voices, Italian.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: Ask

private struct AskTab: View {
    @ObservedObject var state: SettingsState

    var body: some View {
        Form {
            SecureField("Claude API key", text: $state.apiKey)
            Text("From console.anthropic.com. It is kept in this Mac's Keychain, never in a file.")
                .font(.caption).foregroundStyle(.secondary)
            TextField("Model", text: $state.config.ask.model)
            TextField("Monthly budget in US dollars", value: $state.config.ask.monthlyBudgetUSD, format: .number)
            Text(String(format: "Spent this month: $%.4f", AskClient.Spending.thisMonth()))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: Hotkeys and files

private struct KeysTab: View {
    @ObservedObject var state: SettingsState

    var body: some View {
        Form {
            TextField("Open the box", text: $state.config.hotkeys.openBox)
            TextField("Hold to talk", text: $state.config.hotkeys.talk)
            TextField("Save the page in front", text: $state.config.hotkeys.saveTab)
            TextField("Mark my place", text: $state.config.hotkeys.markPlace)
            Text("Write them like ctrl+opt+space. Each needs a normal key at the end; a modifier alone cannot be a hotkey on a Mac.")
                .font(.caption).foregroundStyle(.secondary)

            Divider()
            TextField("Brave personal profile folder", text: $state.config.brave.personalProfileDir)
            TextField("Brave work profile folder", text: $state.config.brave.workProfileDir)
            TextField("Language for talking (en-IN, en-US, en-GB)", text: $state.config.speechLocale)

            Divider()
            Button("Show the config file in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([BrochachoPaths.configFile])
            }
        }
    }
}
