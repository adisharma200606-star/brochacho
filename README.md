# Brochacho

A voice that lives in the MacBook notch.

- **`docs/GUIDE.md`** — how every feature works and how to change it. Start here.
- **`docs/IPHONE.md`** — the two iPhone shortcuts, step by step.
- `SPEC.md` — the original design brief.

## What exists right now

| Folder | What it is | State |
|---|---|---|
| `reference-js/` | The brain (matcher, stash, line picker) in plain JavaScript. It is the source of truth for behaviour. | **Tested. 30 tests passing**: 88 matcher cases, the stash, the lines, the timer, living bookmarks, and the tuner (pitch detection within 0.3 cents on synthetic plucks for every string of all 17 tunings). Run `node --test reference-js/*.test.js`. |
| `fixtures/` | Golden test files written by the JS tests. The Swift port must reproduce them exactly. | Generated. |
| `defaults/` | The default list of things to open (`catalog.json`), the tuner's tunings (`tunings.json`) and the seed line bank. | Done, editable. |
| `prototype/` | A phone-friendly page that simulates the notch with real spring physics, the real matcher, the stash and a browser Italian voice. `python3 prototype/build.py` rebuilds `index.html`. | Works in a browser. Used to tune the feel before the Mac exists. |

| `Sources/BrochachoCore/` + `Tests/` | The brain and the tuner maths ported to Swift (Foundation only). Tests load the golden fixtures and must match the JS reference exactly. | **Written, syntax-checked, never compiled.** `swift test` on a Mac, or let CI do it. |
| `.github/workflows/ci.yml` | On every push to `main`, a GitHub cloud Mac runs the JS tests, `swift test`, and (once `App/` exists) builds the app. Logs are also pushed to the `ci-logs` branch. | Ready. Runs as soon as the repo is on GitHub. |

## What does not exist yet

- `App/` — the macOS notch app (SwiftUI + DynamicNotchKit).
- `DAY_ONE.md`, `BLIND_SPOTS.md`, `REFERENCES.md`.

## Honest status of the Swift code

No Swift toolchain could be installed where this was written (swift.org is blocked there), so the Swift
has passed a syntax check (tree-sitter) and a careful read, and nothing more. The CI workflow exists to
fix that: the first push compiles it on a real Mac.
