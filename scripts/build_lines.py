"""Builds defaults/lines.json, the full line bank.

Rules every line follows (enforced below where a machine can check them):
  - eight words or fewer
  - about the task or about the person using it, never about Italians
  - never advice, never a question, never a comment on how long he has been doing something
"""
import json, pathlib, re

BANK = {
  "open_site": ("os", [
    "It's done. Don't ask how.", "Consider it handled.", "For you, anything.", "Ecco. There she is.",
    "Badabing. She's open.", "I know a guy. He opened it.", "Nobody saw nothing. It's open.", "Done. We never spoke.",
    "Mamma mia, that was fast.", "Open. Like it was never closed.", "Prego.", "Subito, boss.",
    "One click. Like butter.", "She opens for you, only you.", "I made a call. It's open.", "Allora. Here we are.",
    "Fresh from the internet.", "Badaboom. Delivered.", "The door, she's open.", "A favour, from me to you.",
    "Served hot.", "Easy. Like Sunday morning.", "Your page, signore.", "I pulled some strings.", "Finito. Enjoy.",
  ]),
  "open_app": ("oa", [
    "She's running, boss.", "Up she goes.", "I woke her up for you.", "Badaboom. Running.",
    "The engine, she purrs.", "Started. Smooth, like olive oil.", "She's awake and she's beautiful.", "Rolling.",
    "Up and at it.", "I kicked the tyres. She's good.", "Lights on. Everybody's home.", "Here she comes.",
    "Ecco. Open for business.", "Warmed up and ready.", "She answers to you now.",
  ]),
  "open_path": ("op", [
    "The drawer is open.", "Here's where you keep things.", "I didn't touch nothing in there.", "Your files, signore.",
    "The cellar door, she's open.", "Everything's where you left it.", "The back room. Make yourself comfortable.",
    "Mind the mess. It's yours.", "Open. I looked away, I promise.", "The filing cabinet of dreams.",
  ]),
  "open_tool": ("ot", [
    "At your service.", "Right away, boss.", "The tools, they are ready.", "Say no more.",
    "I got just the thing.", "Allora. Let's work.", "Special equipment. Very professional.", "Coming right up.",
  ]),
  "saved": ("sv", [
    "I'll hold onto this.", "In the vault.", "Safe with me.", "Nobody finds it but you.", "Gulp. Delizioso.",
    "Locked up tight.", "I put it somewhere nice.", "It's in the family now.", "Under the mattress she goes.",
    "Kept. Like a good secret.", "Swallowed whole.", "Mine now. Yours later.", "In the good drawer.",
    "Tucked away, nice and cosy.", "I never forget a link.", "Filed under beautiful things.", "Yum.",
    "Got it. Forget about it.", "Saved. Not a word to anyone.", "Into my pocket she goes.",
  ]),
  "pulled": ("pl", [
    "From the vault, for you.", "This one, you liked.", "You got good taste, you know.", "An oldie. A goodie.",
    "I kept this warm for you.", "Look what I found in my pocket.", "A little something from before.",
    "You saved it. I remembered it.", "Special delivery, from past you.", "Fresh from the cellar.",
    "This one's been waiting.", "A gift. From you, to you.", "I been holding this one.", "Dusted off, good as new.",
    "Tonight's special.",
  ]),
  "another": ("an", [
    "Fine. Another.", "Picky. I respect it.", "Next.", "Not that one. Okay, okay.", "Back in the vault she goes.",
    "Plenty more where that came from.", "Allora, something else.", "I got others.", "Tough crowd.", "Reshuffling.",
  ]),
  "empty_stash": ("es", [
    "The vault is empty, boss.", "Nothing in here. Drop me something.", "Cupboard's bare.", "I got nothing. Feed me.",
    "Empty. Like my wallet.", "All out. Every last one.", "The cellar, she is dry.", "Nothing left but dust.",
  ]),
  "unknown": ("un", [
    "Never heard of it.", "That one, I don't know.", "Who. Never met him.", "Not in my book.", "You lost me, boss.",
    "I asked around. Nobody knows it.", "Come again.", "That's not one of ours.", "Niente. I got nothing.",
    "Doesn't ring a bell.", "New to me.", "My cousin might know. I don't.",
  ]),
  "muted_on": ("mo", ["My lips, sealed.", "Not a peep.", "Quiet as a church.", "Silenzio."]),
  "muted_off": ("mf", ["I'm back.", "You missed me. I know.", "The voice returns.", "Allora. Where were we."]),
  "timer_done": ("td", [
    "Time's up, boss.", "Basta. That's the time.", "Ding. Finito.", "The clock says stop.", "And that's time.",
    "Pencils down.", "The sand ran out.", "Time. Like you asked.", "She's done. Take her out the oven.", "Tick tock, finito.",
  ]),
  "all_in_tune": ("at", [
    "Bellissimo. She sings.", "Perfetto. Now play something.", "In tune. Like family.", "Six for six. Beautiful.",
    "Now that is a guitar.", "Music to my ears. Literally.", "She's ready for the stage.", "Every string, an angel.",
  ]),
  "bookmark_moved": ("bm", [
    "I remember where you stopped.", "Page marked. Go live your life.", "Dog-eared, nice and neat.",
    "Your place is safe with me.", "Bookmark moved. Very organised.", "I put a finger on the page.",
    "Noted. You can close it now.", "Got your spot.",
  ]),
  "explained": ("ex", [
    "Here. In plain words.", "I asked the professor.", "Translation, for normal people.", "It's simpler than it looks.",
    "The smart one explains.", "Allora. Here's what it means.",
  ]),
  "target:youtube": ("yt", [
    "Opening YouTube. Mamma mia.", "YouTube. Some serious Italian business.", "The tube of you. She's open.",
    "YouTube. Capisce.", "Roll the pictures.", "Lights, camera, YouTube.", "The big screen, the small window.",
    "Showtime.",
  ]),
  "target:youtube music": ("ym", ["Music, maestro.", "A little something for the ears.", "The jukebox is open."]),
  "target:gmail": ("gm", [
    "The mail. Nobody read it, I swear.", "Letters for the boss.", "The post has arrived.",
    "Your correspondence, signore.", "Inbox. I didn't peek.",
  ]),
  "target:google": ("gg", ["Go ask the big book.", "The oracle is in.", "Google. She knows everything.", "Ask, and she answers."]),
  "target:github": ("gh", [
    "The code vault. She's open.", "Where the magic is kept.", "GitHub. Very professional.",
    "The workshop ledger.", "Commits and dreams, all in here.",
  ]),
  "target:linkedin": ("li", [
    "Put on the nice suit.", "LinkedIn. Shake some hands.", "Business time. Very serious.",
    "The networking, she begins.", "Everybody here is thrilled to announce.",
  ]),
  "target:claude": ("cl", [
    "Go ask the professor.", "The smart one. She's open.", "My cousin, the genius.",
    "Claude. Brains of the family.", "The consigliere is in.",
  ]),
  "target:whatsapp": ("wa", ["Go talk to your people.", "The family chat.", "Messages. I didn't read them.", "Your people are in here."]),
  "target:spotify": ("sp", ["Music, maestro.", "Put something on.", "The band is ready.", "A little mood music."]),
  "target:steam": ("st", [
    "Go. Make the family proud.", "Steam. Shoot straight, eh.", "Game time, boss.",
    "The arcade is open.", "Have fun. You earned it.",
  ]),
  "target:vs code": ("vc", [
    "Back to the workshop.", "The tools are on the table.", "Time to build something.",
    "The forge is hot.", "Where the real work happens.",
  ]),
  "target:downloads": ("dl", ["Everything you ever downloaded. Everything.", "The junk drawer.", "Downloads. No judgement."]),
  "target:desktop": ("dk", ["The desk. As you left it.", "Desktop. A little messy, a little genius.", "Your desk, signore."]),
  "target:tuner": ("tu", [
    "Let's hear her sing.", "Strings, eh. We fix them.", "Pluck. I listen.", "My ears are all yours.",
    "Bring her here. We make her sing.", "The tuning fork is out.",
  ]),
  "target:note": ("nt", [
    "Noted.", "Written down. In ink.", "I remember, so you can forget.", "It's in the little black book.", "On paper. Safe.",
  ]),
  "target:reminder": ("rm", [
    "I'll tap your shoulder.", "Consider yourself reminded.", "It's in the book.", "I won't let you forget.",
    "Marked. I'm watching the clock.",
  ]),
  "target:timer": ("tm", [
    "The clock, she's running.", "I watch the time. You work.", "Timer set. I'm counting.",
    "Go. I'll tell you when.", "Tick tock, I'm on it.",
  ]),
}

out, seen, problems = {}, {}, []
for category, (prefix, texts) in BANK.items():
    lines = []
    for i, text in enumerate(texts, 1):
        words = len(text.split())
        if words > 8: problems.append(f"too long ({words} words): {text}")
        if "?" in text: problems.append(f"a question: {text}")
        if len(text) > 48: problems.append(f"too long to say in 2.5 s: {text}")
        lines.append({"id": f"{prefix}{i:02d}", "text": text})
    out[category] = lines

ids = [l["id"] for ls in out.values() for l in ls]
assert len(ids) == len(set(ids)), "duplicate ids"
if problems:
    raise SystemExit("\n".join(problems))

root = pathlib.Path(__file__).resolve().parent.parent
(root / "defaults" / "lines.json").write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n")
print(sum(len(v) for v in out.values()), "lines in", len(out), "categories")
