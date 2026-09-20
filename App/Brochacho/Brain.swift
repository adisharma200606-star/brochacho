import AppKit
import BrochachoCore
import SwiftUI

/// The Brain connects everything. It is the only class that knows about all the others.
///
///   hotkeys, the notch sensor  ->  Brain  ->  BrochachoCore decides  ->  Brain acts  ->  notch, voice, sounds
///
/// Two rules shape almost every method here:
///   1. The action happens first. The line, the sound and the voice come after and never hold it up.
///   2. He never speaks first. Everything below starts from something the person did.
@MainActor
final class Brain {
    // State that lives in files (see docs/GUIDE.md, "Where your files live").
    private(set) var config: Config
    private var usage: [String: Int]
    private var stash: Stash
    private var lineState: LineState
    private var lineBank: LineBank

    // The parts.
    private let model: NotchModel
    private let controller: NotchController
    private let sensor = NotchSensor()
    private let hotkeys = HotkeyCenter()
    private let mouth = Mouth()
    private let sounds = SoundPlayer()
    private let ears = Ears()
    private let micTuner = MicTuner()
    private let settingsWindow = SettingsWindow()

    // What is going on right now.
    private var decision: Decision?
    private var closeTask: Task<Void, Never>?
    private var tunerSession = TunerSession()
    private var tuning: ResolvedTuning?
    private var tuningIndex = 0
    private var wasInTune = false
    private var countdown: CountdownTimer?
    private var countdownTicker: Timer?
    private var pendingBookmarkURL: String?
    private var pendingBookmarkChoices: [CatalogEntry] = []
    private var askTask: Task<Void, Never>?

    init() {
        let loaded = ConfigStore.load()
        config = loaded.config
        if let problem = loaded.problem { NSLog("Brochacho: config problem, using defaults for now: \(problem)") }
        usage = UsageStore.load()
        lineState = LineStateStore.load()
        let stashLoaded = StashStore.load()
        stash = stashLoaded.stash
        if let problem = stashLoaded.problem { NSLog("Brochacho: stash problem: \(problem)") }
        lineBank = LineBankStore.load(from: Bundle.main.url(forResource: "lines", withExtension: "json"))

        model = NotchModel(theme: NotchTheme(config.theme))
        controller = NotchController(model: model)
    }

    // MARK: - Starting and stopping

    func start() {
        wireModel()
        applyConfig()
        sounds.preload()
        ears.requestPermissions()
        sensor.onClick = { [weak self] in self?.pull() }
        sensor.onDrop = { [weak self] things in self?.handleDrop(things) }
        sensor.menuProvider = { [weak self] in self?.contextMenu() }
        sensor.start()
        controller.onDismiss = { [weak self] in
            self?.sounds.play(.close)
            self?.close()
        }
    }

    func shutDown() {
        micTuner.stop()
        mouth.stop()
        persistStash()
    }

    /// Called by the settings window. Saves, then re-applies everything that depends on the config.
    func update(_ newConfig: Config) {
        config = newConfig
        do {
            try ConfigStore.save(config)
        } catch {
            NSLog("Brochacho: could not save the config: \(error)")
        }
        applyConfig()
    }

    private func applyConfig() {
        model.theme = NotchTheme(config.theme)
        controller.apply(model.theme)
        mouth.apply(config.theme.voice)
        sounds.apply(config.feedback)
        ears.setLocale(config.speechLocale)
        tunerSession.options.toleranceCents = config.tuner.toleranceCents

        hotkeys.removeAll()
        let ok = [
            hotkeys.register(config.hotkeys.openBox, onDown: { [weak self] in self?.toggleBox() }),
            hotkeys.register(config.hotkeys.talk, onDown: { [weak self] in self?.startTalking() }, onUp: { [weak self] in self?.stopTalking() }),
            hotkeys.register(config.hotkeys.saveTab, onDown: { [weak self] in self?.saveFrontTab() }),
            hotkeys.register(config.hotkeys.markPlace, onDown: { [weak self] in self?.markMyPlace() })
        ]
        if ok.contains(false) { NSLog("Brochacho: a hotkey in the config could not be understood: \(config.hotkeys)") }
    }

    private func wireModel() {
        model.onTextChange = { [weak self] text in self?.textChanged(text) }
        model.onSubmit = { [weak self] index in self?.submit(choosing: index) }
        model.onAnother = { [weak self] in self?.pull(another: true) }
        model.onChoose = { [weak self] index in self?.chooseBookmark(index) }
        model.onTuningStep = { [weak self] step in self?.stepTuning(step) }
        model.onCopyCommand = { [weak self] in self?.copyCommand() }
    }

    // MARK: - The box

    private func toggleBox() {
        if controller.isOpen && model.screen == .input {
            sounds.play(.close)
            close()
        } else {
            openBox()
        }
    }

    private func openBox(listening: Bool = false) {
        cancelAutoClose()
        stopTuner()
        model.text = ""
        model.isListening = listening
        model.screen = .input
        textChanged("")
        controller.open(takeKeyboard: true)
        sounds.play(.open)
    }

    private func textChanged(_ text: String) {
        let decision = Matcher.match(text, catalog: config.catalog, usage: usage)
        self.decision = decision
        model.selected = 0
        model.isUnknown = decision.mode == .nothing

        if decision.mode == .ask {
            model.rows = [NotchModel.Row(id: 0, title: "Ask: \(decision.query ?? "")", detail: "Claude")]
            return
        }
        model.rows = decision.results.enumerated().map { index, hit in
            var title = hit.entry.shownName
            if decision.mode == .search, let query = decision.query, !query.isEmpty { title += "  ›  \(query)" }
            return NotchModel.Row(id: index, title: title, detail: Brain.whereItOpens(hit.entry, searching: decision.mode == .search))
        }
    }

    /// The small grey text on the right of a row: where this thing will open.
    private static func whereItOpens(_ entry: CatalogEntry, searching: Bool) -> String {
        switch entry.kind {
        case .site: return searching ? "search" : "Brave, \(entry.profile ?? "personal")"
        case .app: return "app"
        case .path: return "Finder"
        case .tool:
            switch entry.target {
            case "note": return "Apple Notes"
            case "reminder": return "Apple Reminders"
            default: return "in the notch"
            }
        }
    }

    /// Enter, or a click on a row. `index` nil means "whichever row is highlighted".
    private func submit(choosing index: Int?) {
        let decision = self.decision ?? Matcher.match(model.text, catalog: config.catalog, usage: usage)
        let chosen = index ?? model.selected

        switch decision.mode {
        case .empty where index == nil && model.rows.isEmpty:
            return
        case .nothing:
            sounds.play(.unknown)
            showLine(category: "unknown", target: nil)
            return
        default:
            break
        }

        let plan = decision.mode == .ask ? ActionPlan.make(from: decision) : ActionPlan.make(from: decision, choosing: chosen)
        guard let plan = plan else { return }
        run(plan)
    }

    // MARK: - Doing things

    private func run(_ plan: ActionPlan) {
        switch plan {
        case .openURL, .openApp, .openPath:
            // Rule 1: the thing opens first.
            Opener.run(plan, config: config)
            count(plan.entryName)
            showLine(category: plan.lineCategory, target: plan.entryName)

        case .openTool(let tool, let argument, let entry):
            count(entry)
            switch tool {
            case "tuner": openTuner(entry: entry)
            case "timer": startTimer(argument, entry: entry)
            case "note": capture(note: argument, entry: entry)
            case "reminder": capture(reminder: argument, entry: entry)
            case "pull": pull(fromBox: true)
            case "settings":
                close()
                settingsWindow.show(brain: self)
            default:
                sounds.play(.unknown)
                showLine(category: "unknown", target: nil)
            }

        case .ask(let question):
            ask(question)
        }
    }

    private func count(_ entryName: String) {
        guard !entryName.isEmpty else { return }
        usage[entryName, default: 0] += 1
        UsageStore.save(usage)
    }

    // MARK: - Lines

    /// Shows a line in the notch and, some of the time, says it. `text` replaces what is shown (used for
    /// confirmations like "call mom · Tomorrow 17:00") while the voice still says a proper line.
    private func showLine(category: String, target: String?, text: String? = nil, alwaysSpeak: Bool = false, hold: Double? = nil) {
        let frequency = alwaysSpeak ? 1.0 : config.theme.voice.frequency
        let pick = Lines.pick(bank: lineBank, state: &lineState, category: category, target: target,
                              frequency: frequency, rng: { Double.random(in: 0..<1) })
        LineStateStore.save(lineState)

        model.isListening = false
        model.lineText = text ?? pick?.text ?? ""
        model.screen = .line
        if !controller.isOpen { controller.open(takeKeyboard: false) }
        if let pick = pick, config.speak { mouth.say(pick) }

        let shown = model.lineText
        closeAfter(hold ?? (1.3 + Double(shown.count) * 0.045))
    }

    private func closeAfter(_ seconds: Double) {
        cancelAutoClose()
        closeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.close()
        }
    }

    private func cancelAutoClose() {
        closeTask?.cancel()
        closeTask = nil
    }

    private func close() {
        cancelAutoClose()
        askTask?.cancel()
        askTask = nil
        stopTuner()
        if ears.isListening { ears.stop { _ in } }
        model.isListening = false
        controller.close()
    }

    // MARK: - The stash

    private func persistStash() {
        do {
            try StashStore.save(stash)
        } catch {
            NSLog("Brochacho: could not save the stash: \(error)")
        }
        PhoneStore.push(stash)
    }

    /// A click on the notch, or "another".
    private func pull(another: Bool = false, fromBox: Bool = false) {
        if controller.isOpen && !another && !fromBox { return }   // a click while something is showing does nothing
        cancelAutoClose()
        PhoneStore.pull(into: &stash)
        let now = SystemClock.nowMs()
        let rng: () -> Double = { Double.random(in: 0..<1) }
        let item = another ? stash.another(now: now, rng: rng) : stash.serve(now: now, rng: rng)
        persistStash()

        guard let item = item else {
            showLine(category: "empty_stash", target: nil)
            return
        }

        Opener.open(item, config: config)                // first
        sounds.play(another ? .another : .pulled)

        let days = max(0, (now - item.savedAt) / Stash.dayMs)
        model.pullTitle = item.title?.isEmpty == false ? (item.title ?? item.payload) : item.payload
        model.pullDetail = days == 0 ? "saved today" : (days == 1 ? "saved yesterday" : "saved \(days) days ago")
        model.screen = .pull
        if !controller.isOpen { controller.open(takeKeyboard: false) }

        let pick = Lines.pick(bank: lineBank, state: &lineState, category: another ? "another" : "pulled", target: nil,
                              frequency: config.theme.voice.frequency, rng: { Double.random(in: 0..<1) })
        if let pick = pick, config.speak { mouth.say(pick) }
        closeAfter(6)
    }

    private func save(payload: String, kind: String, title: String?, source: String) {
        stash.add(payload: payload, kind: kind, title: title, source: source, now: SystemClock.nowMs())
        persistStash()
        sounds.play(.saved)
        showLine(category: "saved", target: nil)
    }

    private func saveFrontTab() {
        guard let tab = TabGrabber.frontTab() else {
            sounds.play(.unknown)
            showLine(category: "unknown", target: nil, text: "No page in front to save.")
            return
        }
        save(payload: tab.url, kind: "url", title: tab.title, source: "hotkey")
    }

    private func handleDrop(_ things: [DroppedThing]) {
        for thing in things {
            switch thing {
            case .link(let url):
                stash.add(payload: url.absoluteString, kind: "url", source: "drop", now: SystemClock.nowMs())
            case .text(let text):
                stash.add(payload: text, kind: "text", source: "drop", now: SystemClock.nowMs())
            case .file(let url):
                stash.add(payload: url.path, kind: "file", title: url.lastPathComponent, source: "drop", now: SystemClock.nowMs())
            case .image(let image):
                if let path = Brain.keep(image) {
                    stash.add(payload: path, kind: "image", title: "An image you saved", source: "drop", now: SystemClock.nowMs())
                }
            }
        }
        persistStash()
        sounds.play(.saved)
        showLine(category: "saved", target: nil)
    }

    /// A dropped image has no file of its own, so it is written into ~/.brochacho/images.
    private static func keep(_ image: NSImage) -> String? {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        let folder = BrochachoPaths.configDirectory.appendingPathComponent("images", isDirectory: true)
        let file = folder.appendingPathComponent("\(UUID().uuidString).png")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try png.write(to: file)
            return file.path
        } catch {
            return nil
        }
    }

    // MARK: - Bookmarks that remember where he stopped

    private func markMyPlace() {
        guard let tab = TabGrabber.frontTab() else {
            sounds.play(.unknown)
            showLine(category: "unknown", target: nil, text: "No page in front to mark.")
            return
        }
        switch LivingBookmarks.find(for: tab.url, in: config.catalog) {
        case .update(let entry):
            moveBookmark(entry.name, to: tab.url)
        case .ambiguous(let entries):
            pendingBookmarkURL = tab.url
            pendingBookmarkChoices = entries
            model.chooserTitle = "Which one are you reading?"
            model.chooserOptions = entries.map { $0.shownName }
            model.screen = .chooser
            cancelAutoClose()
            controller.open(takeKeyboard: false)
        case .noMatch:
            sounds.play(.unknown)
            showLine(category: "unknown", target: nil, text: "Nothing here remembers its place yet.", hold: 2.6)
        }
    }

    private func chooseBookmark(_ index: Int) {
        guard pendingBookmarkChoices.indices.contains(index), let url = pendingBookmarkURL else { return }
        moveBookmark(pendingBookmarkChoices[index].name, to: url)
        pendingBookmarkURL = nil
        pendingBookmarkChoices = []
    }

    private func moveBookmark(_ name: String, to url: String) {
        var updated = config
        updated.catalog = LivingBookmarks.move(name, to: url, in: config.catalog)
        update(updated)
        sounds.play(.bookmarkMoved)
        showLine(category: "bookmark_moved", target: nil)
    }

    // MARK: - Talking

    private func startTalking() {
        guard !ears.isListening else { return }
        mouth.stop()
        openBox(listening: true)
        let hints = config.catalog.flatMap { $0.keys }
        ears.start(hints: hints) { [weak self] heard in
            guard let self = self, self.model.isListening else { return }
            self.model.text = heard
        }
    }

    private func stopTalking() {
        guard ears.isListening else { return }
        ears.stop { [weak self] heard in
            guard let self = self else { return }
            self.model.isListening = false
            let text = heard.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                self.close()
                return
            }
            self.model.text = text
            self.textChanged(text)
            // Opening the wrong thing is worse than opening nothing: only act by itself when sure.
            if self.decision?.confident == true {
                self.submit(choosing: nil)
            }
        }
    }

    // MARK: - The tuner

    private var tunings: [Tuning] {
        return config.tuner.allTunings + [Tuning(id: "chromatic", instrument: "", name: "Chromatic", strings: [])]
    }

    private func openTuner(entry: String) {
        cancelAutoClose()
        tuningIndex = tunings.firstIndex { $0.id == config.tuner.lastTuningID } ?? 0
        setTuning()
        model.screen = .tuner
        if !controller.isOpen { controller.open(takeKeyboard: true) }

        let pick = Lines.pick(bank: lineBank, state: &lineState, category: "open_tool", target: entry,
                              frequency: config.theme.voice.frequency, rng: { Double.random(in: 0..<1) })
        if let pick = pick, config.speak { mouth.say(pick) }

        micTuner.start { [weak self] reading in self?.heard(reading) }
    }

    private func setTuning() {
        let chosen = tunings[tuningIndex]
        tuning = chosen.strings.isEmpty ? nil : ResolvedTuning(chosen, a4: config.tuner.a4)
        tunerSession = TunerSession()
        tunerSession.options.toleranceCents = config.tuner.toleranceCents
        wasInTune = false
        model.tuningName = chosen.instrument.isEmpty ? chosen.name : "\(chosen.instrument.capitalized), \(chosen.name.lowercased())"
        model.tuningStrings = chosen.strings
        model.lockedStrings = []
        model.tuner = .idle
    }

    private func stepTuning(_ step: Int) {
        tuningIndex = (tuningIndex + step + tunings.count) % tunings.count
        setTuning()
        var updated = config
        updated.tuner.lastTuningID = tunings[tuningIndex].id
        config = updated
        try? ConfigStore.save(config)
    }

    private func heard(_ reading: PitchReading?) {
        guard model.screen == .tuner else { return }
        let shown = tunerSession.feed(reading, nowMs: SystemClock.nowMs(), tuning: tuning, a4: config.tuner.a4)
        model.tuner = shown
        model.lockedStrings = tunerSession.lockedStringIndexes

        if shown.allInTuneNow {
            sounds.play(.allInTune)
            let pick = Lines.pick(bank: lineBank, state: &lineState, category: "all_in_tune", target: nil,
                                  frequency: 1, rng: { Double.random(in: 0..<1) })
            if let pick = pick, config.speak { mouth.say(pick) }
        } else if shown.inTune && !wasInTune {
            sounds.play(.tunerLock)
        }
        wasInTune = shown.inTune
    }

    private func stopTuner() {
        micTuner.stop()
    }

    // MARK: - The timer

    private func startTimer(_ argument: String?, entry: String) {
        let words = (argument ?? "").trimmingCharacters(in: .whitespaces)

        if words.isEmpty {
            if countdown != nil {
                cancelTimer()
                showLine(category: "open_tool", target: nil, text: "Timer cancelled.")
            } else {
                showLine(category: "open_tool", target: nil, text: "Say how long: timer 10, timer 90s, timer 1:30", hold: 3)
            }
            return
        }
        guard let seconds = DurationParser.parse(words) else {
            sounds.play(.unknown)
            showLine(category: "unknown", target: nil, text: "I could not read “\(words)” as a time.", hold: 2.6)
            return
        }

        cancelTimer()
        let timer = CountdownTimer(seconds: seconds, nowMs: SystemClock.nowMs())
        countdown = timer
        refreshTimer()
        countdownTicker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshTimer() }
        }
        showLine(category: "open_tool", target: entry)
    }

    private func refreshTimer() {
        guard let countdown = countdown else { return }
        let status = countdown.status(nowMs: SystemClock.nowMs())
        model.timerText = status.text
        model.timerFraction = status.fraction
        if status.done {
            cancelTimer()
            sounds.play(.timerDone)
            showLine(category: "timer_done", target: nil, alwaysSpeak: true, hold: 3)
        }
    }

    private func cancelTimer() {
        countdownTicker?.invalidate()
        countdownTicker = nil
        countdown = nil
        model.timerText = nil
        model.timerFraction = 0
    }

    // MARK: - Notes and reminders

    private func capture(note argument: String?, entry: String) {
        let text = (argument ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            close()
            _ = CaptureWriter.openFreshNote()
            return
        }
        let ok = CaptureWriter.makeNote(text)
        sounds.play(ok ? .captured : .unknown)
        showLine(category: "open_tool", target: entry, text: ok ? "Note: \(text)" : "Notes would not take it. Check Privacy, Automation.", hold: 3)
    }

    private func capture(reminder argument: String?, entry: String) {
        let text = (argument ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            close()
            CaptureWriter.openReminders()
            return
        }
        let nowWall = ReminderParser.wall(from: Date())
        let parsed = ReminderParser.parse(text, nowWall: nowWall)
        let due = parsed.dueWall.map { ReminderParser.date(fromWall: $0) }
        let said = ReminderParser.describe(dueWall: parsed.dueWall, nowWall: nowWall)

        // Show what was understood straight away; the save itself takes a moment.
        sounds.play(.captured)
        showLine(category: "open_tool", target: entry, text: "\(parsed.title)  ·  \(said)", hold: 3.2)
        CaptureWriter.makeReminder(title: parsed.title, due: due) { [weak self] ok in
            guard !ok else { return }
            self?.sounds.play(.unknown)
            self?.showLine(category: "unknown", target: nil, text: "Reminders would not take it. Check Privacy, Reminders.", hold: 3.5)
        }
    }

    // MARK: - Ask

    private func ask(_ question: String) {
        cancelAutoClose()
        askTask?.cancel()
        model.question = question
        model.answerText = ""
        model.answerCommand = nil
        model.didCopy = false
        model.isThinking = true
        model.screen = .answer
        if !controller.isOpen { controller.open(takeKeyboard: true) }

        // The clipboard is only read, and only sent, when the question points at it ("explain this").
        let clip = Ask.wantsClipboard(question) ? NSPasteboard.general.string(forType: .string) : nil
        let settings = config.ask

        askTask = Task { @MainActor [weak self] in
            let text: String
            var command: String? = nil
            do {
                let answer = try await AskClient.ask(question: question, clip: clip, config: settings)
                text = answer.text
                command = answer.command
            } catch {
                text = AskClient.explain(error)
            }
            guard let self = self, !Task.isCancelled, self.model.screen == .answer else { return }
            self.model.isThinking = false
            self.model.answerText = text
            self.model.answerCommand = command
            self.sounds.play(.answer)
            let pick = Lines.pick(bank: self.lineBank, state: &self.lineState, category: "explained", target: nil,
                                  frequency: self.config.theme.voice.frequency, rng: { Double.random(in: 0..<1) })
            if let pick = pick, self.config.speak { self.mouth.say(pick) }
        }
    }

    private func copyCommand() {
        guard let command = model.answerCommand else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        model.didCopy = true
    }

    // MARK: - The right-click menu, and a test line for the settings window

    private func contextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(MenuAction("Settings…") { [weak self] in
            guard let self = self else { return }
            self.settingsWindow.show(brain: self)
        })
        menu.addItem(MenuAction(mouth.isMuted ? "Let him talk" : "Mute him") { [weak self] in
            guard let self = self else { return }
            self.mouth.isMuted.toggle()
            if self.mouth.isMuted { self.mouth.stop() }
            self.showLine(category: self.mouth.isMuted ? "muted_on" : "muted_off", target: nil, alwaysSpeak: !self.mouth.isMuted)
        })
        if countdown != nil {
            menu.addItem(MenuAction("Cancel the timer") { [weak self] in self?.cancelTimer() })
        }
        menu.addItem(.separator())
        menu.addItem(MenuAction("Quit Brochacho") { NSApp.terminate(nil) })
        return menu
    }

    func sayTestLine(with voice: VoiceTheme) {
        mouth.apply(voice)
        mouth.say(text: "Opening YouTube. Mamma mia.")
    }
}

/// A menu item that runs a closure, so the menu needs no target-action plumbing.
final class MenuAction: NSMenuItem {
    private let run: () -> Void

    init(_ title: String, run: @escaping () -> Void) {
        self.run = run
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("not used")
    }

    @objc private func fire() {
        run()
    }
}
