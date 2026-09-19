# Brochacho — the guide

Everything Brochacho does, how to use it, and how to change it. Written for you, not for programmers.

**Read this first:** this guide describes how each feature *will* behave, and it is also the checklist the app is being built against. Each section starts with a **Status** line so you always know what is real today:

- **Brain tested** — the logic exists, runs, and passes tests (in JavaScript, in `reference-js/`).
- **Swift written** — the same logic is ported to Swift for the Mac. It passes a syntax check. It has not been compiled yet.
- **Screen not built** — the part you see and touch on the Mac does not exist yet.

When the app runs on your Mac, every Status line gets updated and anything that turned out different gets rewritten. If the guide and the app ever disagree, that is a bug in one of them. Tell me.

---

## Contents

1. [What it is](#1-what-it-is)
2. [Opening things](#2-opening-things)
3. [Talking instead of typing](#3-talking-instead-of-typing)
4. [Saving things (the stash)](#4-saving-things-the-stash)
5. [Getting things back](#5-getting-things-back)
6. [Bookmarks that remember where you stopped](#6-bookmarks-that-remember-where-you-stopped)
7. [The tuner](#7-the-tuner)
8. [The timer](#8-the-timer)
9. [Explain this](#9-explain-this)
10. [The voice](#10-the-voice)
11. [Adding your own things](#11-adding-your-own-things)
12. [Look and feel](#12-look-and-feel)
13. [Hotkeys](#13-hotkeys)
14. [The config file, key by key](#14-the-config-file-key-by-key)
15. [Where your files live](#15-where-your-files-live)
16. [When something goes wrong](#16-when-something-goes-wrong)
17. [What is built and what is not](#17-what-is-built-and-what-is-not)

---

## 1. What it is

Brochacho lives in the notch at the top of your MacBook screen. Most of the time you cannot see it. You call it, it does one thing fast, an Italian voice says a short line, and it disappears.

It follows five rules. They explain most of the choices below.

1. **The action comes first, the voice after.** He never makes you wait for a joke.
2. **Fast.** Under a second and a half from Enter to the thing being open.
3. **Nothing to memorise.** You type the *name* of what you want. There are no commands.
4. **He never speaks first.** He only talks in reply to something you just did, or something you asked him to tell you (like a timer ending).
5. **No face, no streaks, no dashboards, no watching your screen.**

---

## 2. Opening things

**Status:** brain tested · Swift written · screen not built

Press the **open** hotkey. The notch grows into a box. Type the name of the thing. Press Enter. It opens, the notch closes, he says a line.

### You can be lazy

| You type | What happens | Why |
|---|---|---|
| `yt` | YouTube | `yt` is a nickname (an *alias*) for YouTube |
| `you` | YouTube | the start of a name is enough |
| `y` | YouTube | even one letter, if nothing you use more starts with it |
| `code` | VS Code | a later word of the name works too |
| `ytb`, `linkdin` | YouTube, LinkedIn | skipped or missing letters are forgiven |
| `steem`, `cloud` | Steam, Claude | small typos are forgiven |

Up to four matches show under what you type. The top one is what Enter opens. Tap or click another row to open that one instead.

**When two things match equally well, the one you open more often wins.** Type `s` and you get Steam or Spotify depending on which you actually use. It learns this by counting, nothing cleverer.

Open the box and type nothing, and you see the four things you open most.

### Searching inside a site

Type a site's name, then what you want:

- `yt berserk amv` opens YouTube's search results for "berserk amv"
- `g how to tune a guitar` searches Google
- `gh dynamicnotchkit` searches GitHub

This works for any site that has a *search address* set (see [Adding your own things](#11-adding-your-own-things)).

### Extra words are ignored

`open youtube`, `play me some youtube`, `go to gmail`, `open the downloads folder` all work. Words like *open, play, me, some, the, go, to, please, set* carry no meaning, so they are dropped. This matters most when you talk.

### Sites open in the right Brave profile

Every site entry says which Brave profile it belongs to, `personal` or `work`. Brochacho launches Brave with that profile directly, so your personal YouTube never opens in your work window.

### If he does not know it

He shows `?`, says something like "Never heard of it", and nothing opens. Add it (section 11).

---

## 3. Talking instead of typing

**Status:** brain tested (spoken words go through the same matcher) · Swift not written · needs the Mac's microphone

**Hold** the talk key, say the name, **let go**. Letting go is what tells it you have finished, which is why it is faster than a button you tap.

- Speech is recognised on the Mac itself. Nothing is sent anywhere.
- You do not say "Brochacho". Just say the thing: "YouTube", "open Steam", "timer ten minutes".
- Mishearings are handled: "you to", "get hub", "what's app", "linked in" all land correctly.
- **If he is not sure, he does not guess.** He shows his best guess with a `?` and waits for Enter. Opening the wrong thing is worse than opening nothing.

Expect to type more than you talk. Typing `yt` is faster than speaking, and it works in class.

---

## 4. Saving things (the stash)

**Status:** brain tested · Swift written · screen not built

You find something good and want it later. Three ways to save it, none of which ask you a single question:

1. **Drag it onto the notch.** A link, some text, an image, a file. The notch swallows it.
2. **Press the save hotkey** while looking at a page in Brave. It saves that tab. No window appears.
3. **From your iPhone:** a share-sheet shortcut. See `docs/IPHONE.md` for the build steps. There is a matching **Bored** shortcut for getting things back on the phone, and both work for someone who only has an iPhone.

There are no folders and no tags. The moment a saving tool asks where something goes, people stop using it.

Saving the same thing twice does not make a duplicate. It just counts as freshly saved.

---

## 5. Getting things back

**Status:** brain tested · Swift written · screen not built

This is the half that other "save for later" tools get wrong. They make you go and look. Brochacho hands things back at the moment you were about to go looking for a distraction anyway.

**Click the notch** (or type `bored`). He opens **one** thing you saved.

- For a few seconds a small **another** button shows. Click it and he puts that one back and opens a different one. No commentary.
- Something you opened is never served again.
- He alternates between things from the last two weeks and older things, so old finds do not rot at the bottom.
- Something you skip three times goes to the back of the queue.
- If the stash is empty he says so. No guilt.

---

## 6. Bookmarks that remember where you stopped

**Status:** brain tested · Swift written · screen not built

A normal entry always opens the same page. A **living** entry opens wherever you last were.

**Example.** You make an entry called `bat` while on chapter 3 of Absolute Batman, and tick **remember where I left off**. Later you are on chapter 14. You press the **mark my place** hotkey. From now on `bat` opens chapter 14.

How he decides which entry to move:

- **Only living entries ever move.** `youtube` is not living, so pressing the hotkey on a YouTube video never overwrites it.
- If exactly one living entry belongs to the site you are on, he moves it.
- If several do (two manga on the same reader site), he picks the one whose address looks most like the page you are on (`/manga/absolute-batman/...` matches `bat`, not `berserk`).
- If he still cannot tell (two Netflix shows, whose addresses are just numbers), he shows both in the notch and you pick.
- If nothing living belongs to this site, he offers to make a new entry from the page.

Good uses: manga, a course, a long playlist, documentation you are working through, a show.

Limit: he can open the page. He cannot press play or scroll to your line. For Netflix, save the *watch* page and it resumes by itself.

---

## 7. The tuner

**Status:** brain tested (accurate to about a quarter of a cent on test tones) · Swift written · screen not built · microphone hookup not written

Type `tune`, `tuner` or `uke`. The notch becomes a tuner. Pluck a string.

### Reading it

- The **big letter** is the string it thinks you are tuning. It works this out by itself.
- The **needle** shows how far off you are. Left is flat (tune up), right is sharp (tune down). The number is in *cents*; 100 cents is one fret.
- When the needle sits in the middle and holds for about a third of a second, the display flips to **in tune**. It waits that moment on purpose so a passing wobble does not count.
- Strings you have already got right are underlined.
- When **every** string has been in tune once, he says one line ("Bellissimo. She sings."). Once per session, not once per string.

One stray sound (a knock on the desk, a harmonic) will not make it jump to another string. It only switches when two readings in a row agree.

### Tunings

Arrows flip through them.

| Guitar | Strings (low to high) |
|---|---|
| Standard | E A D G B E |
| Half step down | Eb Ab Db Gb Bb Eb |
| Full step down | D G C F A D |
| Drop D | D A D G B E |
| Double drop D | D A D G B D |
| DADGAD | D A D G A D |
| Open G | D G D G B D |
| Open D | D A D F# A D |
| Open E | E B E G# B E |
| Open C | C G C G C E |
| Drop C | C G C F A D |
| Drop B | B F# B E G# C# |
| Drop A | A E A D F# B |

| Ukulele | Strings (4th to 1st) |
|---|---|
| Standard (high G) | G C E A |
| Low G | G C E A, with the G an octave lower |
| Baritone | D G B E |
| D tuning | A D F# B |

**Chromatic** mode shows the nearest note of any kind, with its octave. Use it for anything not in the list, or for other instruments.

### Your own tunings

Add them under `tuner.customTunings` in the config (section 14). Notes are written as letter, optional `#` or `b`, and octave number: `E2`, `F#3`, `Bb3`. Middle C is `C4`.

### Settings

- `tuner.a4` — the pitch of A. 440 unless you are playing along with something tuned differently.
- `tuner.toleranceCents` — how close counts as in tune. Default 5. A good ear stops hearing the difference around there.

### Honest limits

- **Drop B and Drop A** put the lowest strings around 55 to 62 Hz. Laptop microphones are weak down there. Those strings will read, but slower and jumpier than the rest.
- While the tuner is open, macOS shows its orange microphone dot. That is normal. The microphone turns off when the tuner closes.
- A slack new string far below pitch shows as "way flat" on the nearest string. It never pretends to be in tune.

---

## 8. The timer

**Status:** brain tested · Swift written · screen not built

Type `timer` and how long. The notch closes and a thin bar drains across its bottom edge. When it ends, he tells you. (You asked him to, so rule 4 holds.)

| You type | You get |
|---|---|
| `timer 10` | 10 minutes. A bare number means minutes. |
| `timer 1.5` | 90 seconds |
| `timer 90s` · `timer 45 seconds` | seconds |
| `timer 25 min` · `timer 10m` | minutes |
| `timer 1h` · `timer 1h30` · `timer 1 hour 30 minutes` | hours |
| `timer 5m30` | 5 minutes 30 seconds |
| `timer 1:30` · `timer 1:30:00` | clock style |
| `10 min timer` · `set a timer for 10 minutes` | the natural way round works too |
| `countdown 5` | `countdown` is a nickname for the timer |

Shortest is one second, longest is 24 hours. If he cannot read it ("timer soon"), he says so and starts nothing.

Hover the notch to see the time left. Click it to cancel.

There is one timer at a time. There are no streaks, no history, and no "you focused for 3 hours today". It is a kitchen timer.

---

## 9. Explain this

**Status:** designed · nothing written yet · needs a Claude API key

You are looking at an error message or a line of code you do not understand.

1. Select it and copy it (⌘C).
2. Press the **explain** hotkey.
3. A short explanation in plain English appears in the notch: what it means, the most likely cause, the first thing to try.

This is the only feature that uses the internet and the only one that costs money: roughly a cent per use, paid from a Claude Console API key that you add once. The key is kept in the Mac's Keychain, never in the config file.

It reads the clipboard and nothing else. It never looks at your screen, and it only runs when you press the hotkey.

---

## 10. The voice

**Status:** brain tested (which line, how often, no repeats) · Swift written · sound not written

### What he says

Lines live in one file, `lines.json`. Each belongs to a category: opening a site, opening an app, saved, pulled, another, empty stash, unknown, timer done, all strings in tune, and so on.

Some things have their own lines. Open YouTube and you usually get a YouTube line; otherwise a general one. He never repeats any of the last five lines he used in a category.

**The rules every line follows:** eight words or fewer. About the task or about you, never about Italians. Never advice, never a question, never a comment on how long you have been doing something.

You can add, cut or rewrite lines by editing the file. Nothing else needs to change.

### How he sounds

Day one: a macOS **Italian** system voice reading the English text, which gives a thick accent for free. Better Italian voices can be downloaded in System Settings → Accessibility → Spoken Content.

Later, if you want: pre-made audio clips from a voice service. If a clip exists for a line, he plays it; otherwise he falls back to the system voice.

### How often

The text line **always** shows. Whether it is also *spoken* is a dial:

- `theme.voice.frequency` — 0 is never, 1 is every time. Default 0.6. The variety and this dial are what keep him funny after the hundredth time.
- `speak` — the master switch.
- **Mute** — right-click the notch. For class and the office.

---

## 11. Adding your own things

**Status:** brain tested · Swift written · settings window not built

Everything he can open is an **entry**. You add entries in a settings window, so you never have to touch a file.

An entry has:

| Field | Meaning | Example |
|---|---|---|
| Name | what you type | `bat` |
| Other names | nicknames that also work | `batman` |
| Shown as | how it looks on screen | `Absolute Batman` |
| Opens | a web page, an app, or a folder | the chapter page |
| Brave profile | for web pages | `personal` |
| Search address | optional; makes `name words` search the site | `https://site/search?q={q}` |
| Remember where I left off | makes it a living bookmark (section 6) | on |

**Add the page I'm on** fills in the address from the tab you are looking at. You only type the name. That is how `bleach` becomes "open Bleach on Netflix" in five seconds.

If a new name is exactly the same as one you already have, it warns you.

---

## 12. Look and feel

**Status:** look chosen (Aurora) · working in the phone prototype · Mac screens not built

The look is **Aurora**: a black notch that matches the hardware, Helvetica Neue inside it, soft translucent rows, and a three-colour glow around the edge while it is open. A professional-looking piece of software that happens to talk like an Italian uncle. The contrast is the joke.

- **Type:** Helvetica Neue, which ships on every Mac. The name you type is large and medium weight. The tuner's note is very large and very thin.
- **Rows:** the top match sits on a soft translucent pill. The others are grey.
- **Glow:** three colours. It fades in as the notch opens, and because it follows the same spring as the notch, a bouncy spring makes it flare for a moment. Palettes: Aurora (pink, blue, purple), Sunset, Mint, and Mono (white only).
- **Tuner colours:** orange while a string is off, green the moment it locks.
- **Timer:** a thin bar in the glow colours draining along the bottom of the closed notch.

What you can change without touching code:

- The notch opens and closes on a **spring**, tuned by you on the phone prototype. The two numbers, `stiffness` and `damping`, mean exactly the same thing on the Mac, so what you feel on the phone is what you get.
- Glow colours and strength, text size, and how fast the cursor pulses.
- On a screen with no notch (an external monitor), it appears as a small floating pill at the top centre.

To apply settings from the prototype: open **Settings to copy**, copy, and paste it over the `theme` block in the config.

---

## 13. Hotkeys

**Status:** placeholders. You choose the real ones on the Mac.

| Hotkey | Does | Default |
|---|---|---|
| Open | opens the box in the notch | `opt+space` |
| Talk | hold to talk, release to run | `right_opt` |
| Save | saves the front Brave tab to the stash | `opt+s` |
| Mark my place | moves a living bookmark to this page | not chosen |
| Explain | explains whatever you just copied | not chosen |

Pick ones you can hit with one hand that do not clash with VS Code.

---

## 14. The config file, key by key

`~/.brochacho/config.json`. It is created with sensible defaults the first time the app runs. **Every key is optional**: leave one out and the default is used. If you make a typo that breaks the file, the app uses defaults for that run and **leaves your file alone**, so a mistake never wipes your settings.

```json
{
  "hotkeys": { "open": "opt+space", "talk": "right_opt", "save": "opt+s" },
  "brave": {
    "binaryPath": "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
    "personalProfileDir": "Default",
    "workProfileDir": "Profile 1"
  },
  "speak": true,
  "theme": {
    "motion": { "stiffness": 260, "damping": 24 },
    "look":   { "palette": "aurora", "glowColors": ["#FF375F", "#0A84FF", "#BF5AF2"], "glowStrength": 0.8, "textSize": 19, "caretBlinkMs": 600 },
    "voice":  { "voiceName": "", "rate": 0.95, "pitch": 0.9, "frequency": 0.6 }
  },
  "tuner": { "a4": 440, "toleranceCents": 5, "lastTuningID": "guitar-standard", "customTunings": [] },
  "catalog": [ ]
}
```

| Key | Meaning |
|---|---|
| `hotkeys.*` | see section 13 |
| `brave.binaryPath` | where Brave lives. Only change it if you installed Brave somewhere unusual. |
| `brave.personalProfileDir`, `brave.workProfileDir` | the folder names Brave uses for your two profiles. Found on day one. |
| `speak` | master switch for the voice |
| `theme.motion.stiffness` | how hard the notch snaps open. Higher is snappier. |
| `theme.motion.damping` | how quickly it settles. Lower is bouncier. |
| `theme.look.glowColors` | the three glow colours, `#RRGGBB`, inner to outer. An unreadable one falls back to Aurora's. |
| `theme.look.glowStrength` | 0 is no glow, 1 is full |
| `theme.look.textSize`, `caretBlinkMs` | base text size in points; how long one cursor pulse takes |
| `theme.voice.voiceName` | which system voice. Empty means the best Italian one installed. |
| `theme.voice.rate`, `pitch` | 1.0 is the voice's normal speed and pitch |
| `theme.voice.frequency` | 0 to 1, how often lines are spoken as well as shown |
| `tuner.*` | see section 7 |
| `catalog` | your entries (section 11). One entry looks like this: |

```json
{ "name": "bat", "display": "Absolute Batman", "aliases": ["batman"], "kind": "site",
  "target": "https://…", "profile": "personal", "living": true }
```

`kind` is `site`, `app`, `path` or `tool`. For an app, `target` is its bundle identifier (for example `com.valvesoftware.steam`). For a folder, it is the path (`~/Downloads`). `tool` is for built-in things: `tuner` and `timer`.

---

## 15. Where your files live

| File | What it holds |
|---|---|
| `~/.brochacho/config.json` | every setting and every entry |
| `~/.brochacho/usage.json` | how often you open each thing, for tie-breaking |
| `~/.brochacho/line-state.json` | which lines he used recently, so he does not repeat |
| iCloud Drive `/Brochacho/stash.json` | the stash. If iCloud Drive is off, it lives in `~/.brochacho/` instead. |
| iCloud Drive `/Shortcuts/Brochacho/` | the three small text files the iPhone shortcuts and the Mac pass back and forth (`docs/IPHONE.md`) |

All plain text. You can open, read and back up any of them. If the stash file is ever damaged (a half-finished sync, say), the app moves it aside under a new name and starts a fresh one. **It never deletes it.**

---

## 16. When something goes wrong

This section will grow once the app has actually run. What can already be predicted:

| Problem | Likely cause | Fix |
|---|---|---|
| A site opens in the wrong Brave profile | the profile folder names in the config are wrong | find the real names (DAY_ONE.md) and set `brave.personalProfileDir` / `workProfileDir` |
| Hold-to-talk does nothing | microphone or speech permission was refused | System Settings → Privacy & Security → Microphone, and Speech Recognition |
| Save hotkey does nothing | macOS blocked Brochacho from asking Brave for its tab | System Settings → Privacy & Security → Automation → allow Brochacho to control Brave |
| The voice is not Italian | no Italian voice installed | System Settings → Accessibility → Spoken Content → System Voice → Manage Voices → Italian |
| Settings seem ignored after you edited the file | a typo broke the file, so defaults are in use | fix the typo. Your file was not touched. |
| The tuner is jumpy on the lowest string in Drop B or Drop A | laptop microphones are weak at those pitches | pluck closer to the laptop, or tune that string by ear from the one above |

---

## 17. What is built and what is not

| Piece | State |
|---|---|
| Matcher, stash, line picker, tuner maths, timer, living bookmarks, iPhone sync | **Built and tested in JavaScript** (30 tests) |
| The same, in Swift | **Written, syntax-checked, never compiled** |
| Phone prototype (notch feel, typing, stash, tuner, voice preview) | **Working** |
| Cloud-Mac build and test workflow | **Written**, waiting for the repo to be on GitHub |
| The Mac app: notch, hotkeys, opening things, drag to save, voice, settings window, tuner screen, timer bar | **Not written** |
| Hold-to-talk | **Not written** |
| Explain this | **Not written** |
| Full line bank | **233 lines written**, in `defaults/lines.json`. Edit freely. |
| Saving from the iPhone, and Bored on the iPhone | **Mac-side logic built and tested.** The two shortcuts are written up step by step in `docs/IPHONE.md` and have not been built on a real phone yet. |
| The look | **Aurora chosen.** Live in the phone prototype. |

Ideas that are parked, not planned: a metronome, screenshots into the stash, running your own Shortcuts by name, a live football score in the notch, silent "idle" cards (a chord shape, a line of Python) in the closed notch.
