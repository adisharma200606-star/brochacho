# Blind spots

Everything in here is a guess that could not be checked without a Mac. Each one says **where** it is in the code, **what** was assumed, and **what to try** if it turns out wrong. When you confirm or fix one, delete it from this file, so the file always shows what is still unknown.

The honest headline: **the code compiles and passes its tests, but the app has never been launched.** On 24 September 2026 GitHub's macOS runner (Xcode 16.4, Swift 6.1.2) ran `swift test` (41 tests, all pass) and built the app with no warnings in its own code. Everything below is about what happens when it *runs*.

---

## A. Compile time: resolved

The whole section that used to be here is gone: the first cloud build compiled everything. Two facts from that build worth keeping:

- Resources land at the top of the app bundle (`Brochacho.app/Contents/Resources/open.wav`, `lines.json`), which is where `SoundPlayer` and `Brain` look first.
- The build had one warning, from Apple's tooling about AppIntents metadata. It is harmless and not from this code.

## B. Things likely to misbehave at run time

### The notch window

| # | Where | Assumed | If wrong |
|---|---|---|---|
| B1 | `NotchController.open` | DynamicNotchKit's panel is a non-activating panel that `canBecomeKey`, so calling `makeKey()` lets you type without Brochacho stealing focus from the app you were in. | If typing does nothing: call `NSApp.activate(ignoringOtherApps: true)` just before `window.makeKey()`. If the text field still is not focused, check `focusToken` reaches `InputScreen` and try `DispatchQueue.main.asyncAfter(0.05)` before setting `focused = true`. **This is the single most important thing to get right.** |
| B2 | same | The window exists within a few milliseconds of `expand()` being called, so the loop that waits for it takes the keyboard almost at once. The first one or two keystrokes may still reach the previous app. | Measure. If keys are lost, make the panel key earlier by creating it ahead of time, which needs a small change in the vendored library. |
| B3 | `NotchSensor.swift` | A borderless panel placed over the physical notch, at window level *main menu + 3*, receives clicks and drags there. A fill of 1% opacity is enough for macOS not to pass clicks through. | If clicks do nothing: raise the level (try `.statusBar`, then `.popUpMenu`), and check the frame with a visible colour. If drags are not accepted, confirm `registerForDraggedTypes` ran and try `.screenSaver` level. |
| B4 | `NotchSensor.place` | The sensor is only created on a screen that has a notch. On an external monitor there is none: no click-to-pull and no drop target there. | By design. On those screens, type `bored` to pull, and use the save hotkey to save. |
| B5 | `App/Vendor/…/NotchContentView.swift` | Three coloured `.shadow` layers on the masked notch shape draw the Aurora glow, and fade with the open and close animation. | If the glow is clipped or missing, check the panel is large enough (it is half the screen) and try a smaller radius. If it looks heavy, lower the opacities in the patch or `glowStrength`. |
| B6 | `Views/NotchRootView.swift` | The expanded notch sizes itself to its content (`fixedSize`), so switching screens resizes it with the spring. | If switching screens jumps or clips, give each screen a fixed height, or wrap the switch in `.transition(.opacity)`. |
| B7 | `NotchController.close` | While a timer runs, closing goes to the *compact* state, which shows a dot on the left of the notch and the time on the right. | If compact mode looks wrong or flickers, set `skipIntermediateHides` to `false`, or show the timer only when the notch is opened. |

### Opening things

| # | Where | Assumed | If wrong |
|---|---|---|---|
| B8 | `Opener.openInBrave` | Starting Brave's program file with `--profile-directory=… <address>` while Brave is already running hands the address to the running Brave in that profile, and the new process exits. This is standard Chromium behaviour. | If it opens a second Brave, or the wrong profile: confirm the folder names (DAY_ONE step 6). As a fallback use `open -na "Brave Browser" --args --profile-directory=… <address>`. |
| B9 | `defaults/catalog.json` | Bundle identifiers: `net.whatsapp.WhatsApp`, `com.spotify.client`, `com.valvesoftware.steam`, `com.microsoft.VSCode`. | For any app that will not open: `osascript -e 'id of app "WhatsApp"'` prints the real one. Fix it in settings. |
| B10 | whole app | The target is under 1.5 seconds from Enter to the page being open. Never measured. | Time it. The brain takes well under a millisecond; any delay is in launching Brave. |

### The front tab, Notes, Reminders

| # | Where | Assumed | If wrong |
|---|---|---|---|
| B11 | `TabGrabber.swift` | Brave answers the same AppleScript as Chrome (`URL of active tab of front window`, `title of …`), under the name "Brave Browser". macOS asks once for permission to control it. | If it returns nothing, run the script by hand in Script Editor to see the real error. Check System Settings → Privacy & Security → Automation. |
| B12 | `CaptureWriter.makeNote` | `make new note with properties {body:"…"}` works with HTML in the body, in the default account. `show fresh` brings a new empty note forward. | Test in Script Editor. Some setups need `tell account "iCloud"`. |
| B13 | `CaptureWriter.makeReminder` | `requestFullAccessToReminders` on macOS 14 and later, the older call before that. `defaultCalendarForNewReminders()` is not nil. An `EKAlarm` with an absolute date is what makes the iPhone notify. | If saving fails with no calendar, the Mac has no Reminders account yet: open Reminders once. |

### Voice, sound, ears

| # | Where | Assumed | If wrong |
|---|---|---|---|
| B14 | `Mouth.pickVoice` | At least one Italian voice ("Alice") is installed on a fresh Mac, and `quality.rawValue` orders voices from worst to best. | If he speaks with the default English voice, download an Italian voice (DAY_ONE step 7). |
| B15 | `Mouth.say` | The config's speed (1.0 = normal) maps onto AVSpeech's scale by multiplying the default rate. | If he is too fast or slow, change `theme.voice.rate`; if the mapping is badly off, adjust the formula. |
| B16 | `Ears.swift` | `en-IN` is a supported speech language, ideally on-device. If it is not on-device, macOS sends audio to Apple for recognition. | The settings could show `ears.isOnDevice`; it does not yet. Try `en-US` or `en-GB` in settings if recognition is poor. |
| B17 | `Ears.swift`, `MicTuner.swift` | Each owns its own `AVAudioEngine`. They are never meant to run at once (opening the box stops the tuner). | If the microphone fails to start after using the other one, share a single engine. |
| B18 | `MicTuner.swift` | The tap delivers buffers near the requested 2048 frames, and detecting a 4096-sample window takes a few milliseconds in a release build. In a **debug** build it may be several times slower. | If the needle lags in debug, that is expected; test the tuner in a release build before worrying. |
| B19 | `SoundPlayer.play` | Trackpad taps only happen on a Force Touch trackpad with a finger on it. | Nothing to fix. |

### Ask

| # | Where | Assumed | If wrong |
|---|---|---|---|
| B20 | `AskClient.ask`, `Ask.requestBody` | POST `https://api.anthropic.com/v1/messages` with headers `x-api-key`, `anthropic-version: 2023-06-01`, `content-type: application/json`; body has `model`, `max_tokens`, `system` (a plain string) and `messages`. Checked against Anthropic's documentation in September 2026. The reply has `content[].text` and `usage.input_tokens` / `output_tokens`. | The error text from the API is shown in the notch. If `system` must be a list of blocks, change `Ask.Body`. |
| B21 | `Config.swift`, `AskConfig` | The model name `claude-haiku-4-5` and its price ($1 and $5 per million tokens) are right. Prices are only used to count against the monthly budget. | Change `ask.model` and the two price fields in the config. |
| B22 | `AskClient.Keychain` | A generic-password Keychain item works for an unsandboxed, locally signed app. With ad-hoc signing macOS may ask for the login password on each rebuild. | Sign with your Personal Team (DAY_ONE step 4). |

### Files

| # | Where | Assumed | If wrong |
|---|---|---|---|
| B23 | `Stores.swift`, `stashFile` | iCloud Drive is at `~/Library/Mobile Documents/com~apple~CloudDocs`. | If the stash is not syncing, check that folder exists; otherwise the stash quietly lives in `~/.brochacho`. |
| B24 | `Stores.swift`, `phoneFolder` | The Shortcuts app's iCloud folder is `~/Library/Mobile Documents/iCloud~is~workflow~my~workflows/Documents`. | After building the iPhone shortcuts, find `phone-inbox.txt` in Finder, get its real path, and correct the constant. |

### Hotkeys

| # | Where | Assumed | If wrong |
|---|---|---|---|
| B25 | `Config.swift`, `Hotkeys` | ⌥Space, ⌃⌥Space, ⌃⌥S and ⌃⌥M are free. ⌥Space can clash with input-source switching or another launcher. | Change them in settings. A hotkey needs a normal key at the end; a modifier alone cannot be registered. |
| B26 | `Brain.startTalking` | Holding the talk hotkey sends one key-down and, on release, one key-up (HotKey library, Carbon events). Key repeat does not re-trigger key-down. | If it re-triggers, `startTalking` already ignores calls while listening. |

## C. Known gaps (not guesses: simply not built)

- Ask answers arrive all at once, not word by word as in the phone prototype.
- The settings window cannot edit custom tunings or lines; those are edited in `config.json` and `lines.json`.
- Changing a hotkey takes effect on **Save**, without a restart, but has not been tested.
- The iPhone shortcuts (`docs/IPHONE.md`) have never been built on a phone.
- There is no app icon.
