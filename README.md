# Brochacho

A voice that lives in the MacBook notch. See `SPEC.md` for the full design.

## What exists right now

| Folder | What it is | State |
|---|---|---|
| `reference-js/` | The brain (matcher, stash, line picker) in plain JavaScript. It is the source of truth for behaviour. | **Tested. 14 tests, 76 matcher cases, all passing.** Run `node --test reference-js/core.test.js`. |
| `fixtures/` | Golden test files written by the JS tests. The Swift port must reproduce them exactly. | Generated. |
| `defaults/` | The default list of things to open (`catalog.json`) and the seed line bank. | Done, editable. |
| `prototype/` | A phone-friendly page that simulates the notch with real spring physics, the real matcher, the stash and a browser Italian voice. `python3 prototype/build.py` rebuilds `index.html`. | Works in a browser. Used to tune the feel before the Mac exists. |

## What does not exist yet

- `Sources/BrochachoCore` — the Swift port of `reference-js/core.js`.
- `App/` — the macOS notch app (SwiftUI + DynamicNotchKit).
- `DAY_ONE.md`, `BLIND_SPOTS.md`, `REFERENCES.md`.

Nothing in Swift has been compiled. No Swift toolchain could be installed in the build sandbox (swift.org is blocked there), which is why the brain was built and tested in JavaScript first.
