# Day one: from a fresh Mac to Brochacho running

Set aside an afternoon. Most of it is waiting for Xcode to download. The code already **compiles and passes its tests on GitHub's cloud Mac**, so the build should go through; what has never happened is *running* it, and that is where today's surprises will be.

**The easy way to do all of this:** install Claude Code, open it in this folder, and say:

> Read CLAUDE.md, then take me through DAY_ONE.md one step at a time. Run the commands yourself, fix what breaks, and explain what you are doing as you go. I am new to this.

Claude Code can run the builds, read the errors and fix the files itself. A normal Claude chat can only advise, and you would be copying errors back and forth by hand.

---

## 1. Install Xcode (about an hour, mostly downloading)

**Xcode**, from the App Store. It is large. Open it once when it finishes and accept what it asks. That is the only tool you need to run the app.

(Homebrew, `xcodegen` and `node` are only needed if you want to run the JavaScript tests or change `App/project.yml`. Skip them for now.)

## 2. Get the code, inside Xcode

No Terminal needed.

1. Open Xcode. On the welcome screen choose **Clone Git Repository…** (or Source Control → Clone… from the menu).
2. Paste `https://github.com/adisharma200606-star/brochacho.git` and press Clone.
3. It will ask you to sign in to GitHub. Choose **Sign in with your GitHub account** (or Xcode → Settings → Accounts → + → GitHub). A personal access token works as the password if it asks for one.
4. Pick a folder to keep it in, such as `~/Code`.

Xcode may open the folder as a Swift package (the brain). That is fine, but it is not the app. Close it and instead open **`App/Brochacho.xcodeproj`** from the cloned folder (File → Open…). The project file is generated on GitHub's cloud Mac and kept up to date there.

## 3. Check the brain (optional, needs Terminal)

```
cd ~/Code/brochacho
swift test        # 41 tests. These pass on the cloud Mac.
```

If it fails on your Mac, tell Claude. One rule: **never edit anything in `fixtures/` by hand.** Those files are the answer sheet, written by the JavaScript tests. If Swift disagrees with them, Swift is wrong.

## 4. Build the app

With `App/Brochacho.xcodeproj` open in Xcode:

1. Click the blue **Brochacho** project at the top of the left sidebar, then the **Brochacho** target, then **Signing & Capabilities**.
2. Under **Team**, choose your name ("Personal Team"). If it is not there, add your Apple ID under Xcode → Settings → Accounts. It is free.
   *Why this matters:* macOS remembers permissions (microphone, controlling Brave) per signed app. Without a team, every rebuild looks like a new app and macOS asks again, every time.
3. Press **⌘R** to build and run. It builds cleanly on the cloud Mac, so it should here too. If not, give the errors to Claude.

When it runs, nothing appears. That is correct: there is no Dock icon and no window. It is waiting in the notch.

## 5. First run

1. Press **⌥Space** (option and space). The notch should grow into a box. Type `yt` and press Enter.
2. macOS will ask for permissions over the first few minutes. Say yes to each:

| It asks for | When | If you said no by mistake |
|---|---|---|
| Microphone | at launch | System Settings → Privacy & Security → Microphone |
| Speech Recognition | at launch | … → Speech Recognition |
| Controlling "Brave Browser" | the first time you press the save hotkey | … → Automation |
| Controlling "Notes" | the first `note …` | … → Automation |
| Reminders | the first `remind …` | … → Reminders |

## 6. Tell it about your Brave profiles

Sites will open in the wrong profile until you do this.

1. In Brave, in your **personal** profile, open `brave://version`. Find **Profile Path**. The last part is the folder name: `Default`, `Profile 1`, `Profile 2`…
2. Do the same in your **work** profile.
3. Type `settings` in the notch → **Hotkeys and files** → fill in the two folder names → **Save**.

## 7. Choose his voice

System Settings → Accessibility → Spoken Content → System Voice → **Manage Voices…** → Italian. Download one or two (the larger "Enhanced" or "Premium" ones sound far better). Then `settings` → **Voice and sound** → pick it → **Say a line**.

## 8. Bring your tuned look over

In the phone prototype open **Settings to copy** and copy. Then `settings` → **Hotkeys and files** → **Show the config file in Finder**, open `config.json` in a text editor, and paste the `theme` and `feedback` blocks over the ones there. Quit and reopen Brochacho.

## 9. The API key, for Ask

Go to console.anthropic.com, add a few dollars of credit, and create a key. Then `settings` → **Ask** → paste it → **Save**. It goes into the Mac's Keychain.

## 10. Walk through everything

Tick these off. When one fails, look it up in `BLIND_SPOTS.md` before anything else.

- [ ] ⌥Space opens the box, and **typing works straight away** without clicking
- [ ] `yt` + Enter opens YouTube in the **personal** Brave profile, in well under 1.5 seconds
- [ ] the line shows, he speaks (some of the time), the notch closes by itself
- [ ] `yt berserk amv` opens YouTube's search results
- [ ] the arrow keys move the highlight; Escape closes; clicking elsewhere closes
- [ ] `steam` opens Steam; `dl` opens Downloads
- [ ] dragging a link from Brave **onto the notch** saves it (sound, line)
- [ ] ⌃⌥S saves the page in front
- [ ] clicking the closed notch opens something you saved; **another** gives a different one
- [ ] right-clicking the notch shows Settings, Mute, Quit
- [ ] holding ⌃⌥Space, saying "YouTube", letting go: it opens
- [ ] `tune`: pluck a string, the needle moves, it locks green, you hear the chime
- [ ] `timer 10s`: the time shows beside the notch, and he tells you when it ends
- [ ] `remind me to stretch in 2 minutes`: it appears in Reminders, and your iPhone buzzes
- [ ] `note testing` appears in Notes
- [ ] `what is a closure` gets a short answer; `how do i undo a git commit?` gives a command with Copy
- [ ] make an entry with "Remember where I left off", go to another page on that site, press ⌃⌥M, and the entry now opens the new page

## 11. Make it start by itself

In Xcode: Product → Show Build Folder in Finder → `Products/Debug/Brochacho.app`. Drag it to Applications. Then System Settings → General → Login Items → **+** → Brochacho.

## Afterwards

- Update the **Status** lines in `docs/GUIDE.md` for everything that now works. Rewrite anything that turned out different.
- Every `git push` to `main` builds and tests on a cloud Mac (`.github/workflows/ci.yml`); the logs land on the `ci-logs` branch.
- Parked ideas are at the end of `docs/GUIDE.md`. Version 1 is frozen until the list above is all ticked.
