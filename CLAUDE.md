# Read this first

You are picking up **Brochacho**, a Mac app that lives in the MacBook notch: type or say the name of a thing and it opens, drag something onto the notch and it is saved, click the notch and one saved thing comes back, and an Italian-accented voice says a short line after each action. It was designed and written for one person, Adi, who is a self-taught builder with no computer-science background. Explain things to him in plain language, teach as you go, and be honest rather than flattering. He asked for that explicitly.

## Updating the app on Adi's Mac

After pushing a change, wait for the CI run to finish (it commits the regenerated Xcode project back to `main`), then Adi runs `~/Code/brochacho/scripts/install.sh`, which pulls, builds a Release copy, signs it, installs it in /Applications and relaunches it.

## The single most important fact

**The app compiles and its brain passes its tests, but the app has never been run.** It was written on a phone, in a sandbox with no Mac. On 24 September 2026 GitHub's cloud Mac (Xcode 16.4, Swift 6.1.2) compiled everything: `swift test` passed all 41 tests, and the app built with no warnings in its own code. What no one has done yet is launch it: nothing about the notch, the hotkeys, the voice, the microphone or the permissions has been seen working. `BLIND_SPOTS.md` lists every runtime guess.

Also tested: the JavaScript reference implementation of the brain (`reference-js/`, 36 passing tests) and the phone prototype built on it.

## What to do, in order

1. Read `DAY_ONE.md` and follow it with Adi. It goes from a fresh Mac to a running app.
2. `swift test` at the repo root. It passes on the cloud Mac; if it fails here, see "How the tests work" below before touching any test or fixture.
3. `cd App && xcodegen generate`, then build the `Brochacho` scheme. It builds on the cloud Mac.
4. Run it. Walk through the smoke test at the end of `DAY_ONE.md`. For each thing that misbehaves, look in `BLIND_SPOTS.md` first: the likely cause is probably already written down.
5. When something in `docs/GUIDE.md` turns out to be wrong, fix the guide too, and update its Status lines. The guide is Adi's manual and it must stay true.

## Rules of the product. Do not break these while fixing things.

1. **The action happens first.** The line, the sound and the voice come after and never delay it.
2. **Fast.** Under 1.5 seconds from Enter to the thing being open. Measure it; treat a regression as a bug.
3. **Nothing to memorise.** The box matches *names*. There is no command language. Anything that is not "open a thing" is a gesture, a hotkey, or a tool that is itself just a name (`timer 10`, `note buy strings`).
4. **He never speaks first.** Voice and sound only answer something the person just did, or something they asked to be told (a timer ending).
5. **No face, no character, no streaks, no dashboards, no watching the screen, no companion behaviour.** This was rejected many times. If an idea starts with "he notices that…", it is out.
6. **Version 1 is frozen.** Do not add features until it runs and Adi asks. Ideas go in the parked list at the end of `docs/GUIDE.md`.

## Map of the repo

| Path | What it is |
|---|---|
| `docs/GUIDE.md` | Adi's manual: every feature, every setting. Each section has an honest Status line. |
| `docs/ARCHITECTURE.md` | How the code fits together, file by file. Read this before changing the app. |
| `DAY_ONE.md` | Fresh Mac to running app, step by step. |
| `BLIND_SPOTS.md` | Every assumption that could not be checked without a Mac, and what to try if it is wrong. |
| `REFERENCES.md` | Third-party code and licences. |
| `reference-js/` | **The source of truth for behaviour.** Matcher, stash, lines, tuner, timer, bookmarks, reminders, asking. Plain JavaScript with tests. |
| `fixtures/` | Golden test data written by the JS tests. The Swift tests load these and must reproduce them. |
| `Sources/BrochachoCore/`, `Tests/` | The brain ported to Swift. Foundation only, no UI. Must behave exactly like `reference-js/`. |
| `App/` | The Mac app. `project.yml` generates the Xcode project. `Brochacho/` is the source. `Vendor/DynamicNotchKit` is a lightly patched copy of the notch-window library. |
| `defaults/` | Shared data: the catalog of things to open, the tunings, the 243 lines. |
| `scripts/` | Generators: Swift defaults from the shared JSON, the lines, the sounds. |
| `prototype/` | The phone prototype (a single web page). Useful as a picture of how every screen should look and feel. |
| `docs/IPHONE.md` | Two iPhone Shortcuts that save to and pull from the same stash. Untested; not the priority. |

## How the tests work. Read before "fixing" a failing test.

Behaviour is defined once, in JavaScript, and checked twice:

```
reference-js/*.js  --(node --test)-->  hand-written expectations pass  -->  writes fixtures/*.json
Sources/BrochachoCore/*.swift  --(swift test)-->  must reproduce fixtures/*.json exactly
```

- If a Swift test fails, the Swift port is wrong (or will not compile). Fix the Swift. **Never edit a fixture by hand.**
- If the *behaviour* should change, change `reference-js/`, update its hand-written expectations, run `node --test reference-js/*.test.js` (this rewrites the fixtures), then bring the Swift into line.
- `Sources/BrochachoCore/DefaultCatalog.swift` and `DefaultTunings.swift` are generated. Edit `defaults/*.json` and run `python3 scripts/gen_default_catalog.py` / `gen_default_tunings.py`.
- After editing `defaults/lines.json` (or `scripts/build_lines.py`), run `python3 scripts/sync_app_resources.py` so the app bundles the new lines.

## Conventions

- Comments explain *why*, in plain words, because the owner of this code is learning. Keep that up.
- The app target is deliberately thin. Logic belongs in `BrochachoCore`, where it can be tested without a Mac's UI.
- `Brain.swift` is the only class that knows about all the others. Views never do work; they read `NotchModel` and call the closures on it.
- Secrets: the Claude API key lives in the Keychain (`AskClient.Keychain`). Never write it to a file or a log.
