# Brochacho

A voice that lives in the MacBook notch. See `SPEC.md` for the full design.

## What exists right now

| Folder | What it is | State |
|---|---|---|
| `reference-js/` | The brain (matcher, stash, line picker) in plain JavaScript. It is the source of truth for behaviour. | **Tested. 14 tests, 76 matcher cases, all passing.** Run `node --test reference-js/core.test.js`. |
| `fixtures/` | Golden test files written by the JS tests. The Swift port must reproduce them exactly. | Generated. |
| `defaults/` | The default list of things to open (`catalog.json`) and the seed line bank. | Done, editable. |
| `prototype/` | A phone-friendly page that simulates the notch with real spring physics, the real matcher, the stash and a browser Italian voice. `python3 prototype/build.py` rebuilds `index.html`. | Works in a browser. Used to tune the feel before the Mac exists. |

| `Sources/BrochachoCore/` + `Tests/` | The brain ported to Swift (Foundation only). Tests load the golden fixtures and must match the JS reference exactly. | **Written, syntax-checked, never compiled.** `swift test` on a Mac, or let CI do it. |
| `.github/workflows/ci.yml` | On every push to `main`, a GitHub cloud Mac runs the JS tests, `swift test`, and (once `App/` exists) builds the app. Logs are also pushed to the `ci-logs` branch. | Ready. Runs as soon as the repo is on GitHub. |

## What does not exist yet

- `App/` — the macOS notch app (SwiftUI + DynamicNotchKit).
- The full 200-line bank (`defaults/lines.json`). `defaults/lines.seed.json` has the first 57.
- `DAY_ONE.md`, `BLIND_SPOTS.md`, `REFERENCES.md`.

## Honest status of the Swift code

No Swift toolchain could be installed where this was written (swift.org is blocked there), so the Swift
has passed a syntax check (tree-sitter) and a careful read, and nothing more. The CI workflow exists to
fix that: the first push compiles it on a real Mac.
