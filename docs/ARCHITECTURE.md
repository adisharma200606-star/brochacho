# How Brochacho fits together

Written so that someone (or a Claude session) who has never seen the code can find their way around in ten minutes.

## The shape of it

```
   you                                   the Mac app (App/Brochacho)                          the brain (BrochachoCore)
 ────────                          ───────────────────────────────────────                  ──────────────────────────────
  hotkey  ───────▶ HotkeyCenter ─┐
  click / drop ──▶ NotchSensor ──┤
  typing ────────▶ InputScreen ──┼──▶  Brain  ──── "what did he mean?" ───────────────────▶  Matcher  ──▶ Decision
  voice ─────────▶ Ears ─────────┘      │   ◀─── "then do this" ──────────────────────────  ActionPlan
                                        │
                                        ├──▶ Opener          opens it (Brave with the right profile, apps, folders)   ← always first
                                        ├──▶ NotchModel ──▶ the screens inside the notch (Views/)
                                        ├──▶ NotchController ──▶ DynamicNotchKit (opens, closes, glow, spring)
                                        ├──▶ SoundPlayer     sounds and trackpad taps     ◀── Feedback.spec
                                        ├──▶ Mouth           the Italian voice            ◀── Lines.pick
                                        ├──▶ MicTuner ─────▶ PitchDetector ─▶ TunerSession ─▶ TunerDisplay
                                        ├──▶ CaptureWriter   Apple Notes, Apple Reminders ◀── ReminderParser
                                        ├──▶ AskClient       Claude API, Keychain, budget ◀── Ask.build / Ask.shape
                                        └──▶ stores          config, usage, stash, line history, phone files
```

Two ideas explain most of the design:

1. **The brain decides, the app does.** `BrochachoCore` has no UI, no network, no clock and no randomness of its own; time and random numbers are handed in. That is what lets it be tested completely without a Mac, and checked against the JavaScript reference line by line.
2. **One class knows everything; nothing else does.** `Brain` is the only place that touches all the parts. Views hold no logic, and the helper classes do one job each and know nothing about one another.

## The brain: `Sources/BrochachoCore`

| File | What it answers |
|---|---|
| `TextTools.swift` | Small text helpers: normalising, edit distance, percent-encoding. |
| `Catalog.swift` | What one "thing he can open" looks like (`CatalogEntry`). |
| `Matcher.swift` | "He typed `yt berserk`. What did he mean?" Returns a `Decision`: open, search, ask, empty or nothing. |
| `ActionPlan.swift` | Turns a `Decision` into a plain instruction: open this URL in this profile, open this app, show this tool, ask this question. |
| `Stash.swift` | Saved things, and the rules for handing one back (never repeat, mix fresh and old, skipped things go to the back). |
| `Lines.swift` | Which line he says, never repeating the last five, and whether it is spoken this time. |
| `Tuner.swift` | Note maths, YIN pitch detection, string matching, and `TunerSession`, which steadies the display. |
| `Extras.swift` | The timer (reading "1h30", counting down), living bookmarks (which entry moves), and folding the iPhone's files into the stash. |
| `Capture.swift` | Reading "call mom tomorrow at 5" into a title and a time. |
| `Ask.swift` | What is sent with a question, when the clipboard is included, and splitting the reply into text and a command. |
| `Feedback.swift` | Which sound and which trackpad tap go with each event. |
| `Config.swift` | Every setting, each with a default, so a partial or old config file always loads. |
| `Stores.swift` | Where files live, and reading and writing them safely (atomic writes; a broken file is never deleted). |
| `DefaultCatalog.swift`, `DefaultTunings.swift` | **Generated** from `defaults/*.json`. Do not edit by hand. |

Each of these is a port of a file in `reference-js/`. The port is kept honest by `fixtures/*.json`: the JavaScript tests write them, and the Swift tests must reproduce them.

## The app: `App/Brochacho`

| File | Job |
|---|---|
| `BrochachoApp.swift` | Entry point. No main window. `AppDelegate` creates the `Brain`. |
| `Brain.swift` | **Start here.** Every feature is a short method: `openBox`, `submit`, `run`, `showLine`, `pull`, `saveFrontTab`, `markMyPlace`, `startTalking`, `openTuner`, `startTimer`, `capture`, `ask`. |
| `NotchModel.swift` | Everything the notch shows, as published properties, plus the closures the views call. |
| `NotchController.swift` | Wraps DynamicNotchKit. Adds what a launcher needs: the keyboard from the first moment, Escape, arrow keys, click-away. |
| `NotchSensor.swift` | An invisible window over the physical notch that is always there, because DynamicNotchKit removes its own window when closed. Click = pull, right-click = menu, drop = save. |
| `Views/` | One file per screen: `InputScreen`, `LineScreen` (also `PullScreen`, `ChooserScreen`), `TunerScreen`, `AnswerScreen`, and `NotchRootView`, which switches between them. |
| `Theme.swift` | The Aurora look: config values turned into colours, fonts and the spring. |
| `HotkeyCenter.swift` | "ctrl+opt+space" from the config into a registered hotkey, with key-down and key-up. |
| `Opener.swift` | Carries out an `ActionPlan`. Launches Brave's program file directly so the profile flag survives. |
| `TabGrabber.swift` | Asks the front browser for its page, by AppleScript. |
| `Mouth.swift` | The voice: an Italian system voice reading English, or a recorded clip if one exists for the line. |
| `SoundPlayer.swift` | Plays the eight sounds and the trackpad taps. |
| `Ears.swift` | Hold-to-talk speech recognition. |
| `MicTuner.swift` | Microphone into the pitch detector, about twelve readings a second. |
| `CaptureWriter.swift` | Makes the note (AppleScript) or the reminder (EventKit). |
| `AskClient.swift` | One HTTPS call to the Claude API. Key in the Keychain. Monthly spending ledger. |
| `SettingsWindow.swift` | The settings window: things, voice and sound, Ask, hotkeys and files. |
| `Resources/` | `lines.json` (copied from `defaults/` by `scripts/sync_app_resources.py`) and `sounds/*.wav` (made by `scripts/make_sounds.py`). |

## What happens when he types `yt` and presses Enter

1. The **open** hotkey fires. `HotkeyCenter` calls `Brain.toggleBox`, which calls `openBox`.
2. `openBox` resets `NotchModel` to the input screen and calls `NotchController.open(takeKeyboard: true)`. The controller asks DynamicNotchKit to expand and, without waiting for the animation, makes the new window take the keyboard. `SoundPlayer` plays *open*.
3. Each keystroke reaches `InputScreen`'s text field, which calls `model.onTextChange`, which is `Brain.textChanged`. That runs `Matcher.match` and publishes the rows.
4. Enter calls `Brain.submit`. `ActionPlan.make` turns the decision into `.openURL(youtube, profile: personal)`.
5. `Brain.run` calls **`Opener.run` first**. Brave gets the address.
6. Then `count` bumps the usage counter, and `showLine` picks a line (`Lines.pick`), shows it, maybe says it (`Mouth`), and schedules the notch to close.

Every other feature follows the same pattern: a trigger, a decision from the brain, the action, then the line.

## Threads

Everything in the app runs on the main thread (`@MainActor`) except two things that would make it stutter: pitch detection (`MicTuner` uses its own queue and hops back to the main thread with each reading) and the network call in `AskClient` (async/await). Speech recognition calls back on its own thread and hops to the main thread at once.

## Files it reads and writes

See "Where your files live" in `docs/GUIDE.md`. The only secret, the API key, is in the Keychain.
