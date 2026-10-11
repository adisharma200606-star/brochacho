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
  "target:flip": ("fl", [
    "The world, upside down.", "Flipped. Like a pancake.", "Other way up, boss.", "Capovolto. Done.",
    "Now everything is the right way.", "Turned around. Very professional.",
  ]),
  "timer_stopped": ("ts", [
    "Clock stopped.", "Fine. No more waiting.", "Time is yours again.", "Stopped. Like it never started.",
  ]),
  "timer_extended": ("te", [
    "A little more time. Prego.", "More minutes, on the house.", "Extended. Don't tell anyone.",
  ]),
  "ticked": ("tk", [
    "Done. Crossed off.", "One less thing.", "Finito. Next.", "Checked. Beautiful.",
  ]),
  "target:help": ("hp", ["Allora. Let me show you.", "The grand tour.", "Sit down. I explain."]),

  # Jobs. The tone is the family business: jobs, favours, what's owed. Lines in job_card, job_check, job_owed
  # and bedtime are shown on the card when he flies out; they are never spoken unless the card is clicked.
  "job_added": ("ja", [
    "The jobs are on the books.", "Noted. The family thanks you.", "It's in the ledger now.", "Consider it a contract.",
    "Jobs assigned. I'll be around.", "Written down. In pen.", "I got the list, boss.", "Capisce. The jobs are set.",
    "On the books. No backing out.", "A day's work. I like it.",
  ]),
  "job_started": ("js", [
    "Now we're talking business.", "Good. Go do the job.", "That's my guy.", "The work, she begins.",
    "Atta boy. I'll leave you to it.", "Professional. Very professional.", "Get in there, boss.", "This is how it's done.",
    "Respect. Go get it.", "The family is proud already.",
  ]),
  "job_done": ("jd", [
    "Job's done. Clean work.", "Paid in full.", "Beautiful. Not a trace.", "That's a made man.",
    "Crossed off the books.", "The family thanks you.", "Like a professional. Bellissimo.", "Done. We never discuss it.",
    "Another one, handled.", "Respect. Real respect.", "Finito. You earned your cannoli.", "Debt settled.",
  ]),
  "job_skipped": ("jk", [
    "Fine. We forget about it.", "Off the books. This time.", "I didn't see nothing.", "Skipped. It happens to everybody.",
    "We let it slide. Today.", "Forget about it.",
  ]),
  "job_later": ("jl", [
    "Later. I'll come back around.", "Half an hour. I'm counting.", "I'll be back. Don't make me.",
    "Okay. I know where you live.", "Later then. I'm patient. Mostly.", "Fine. I'll wait outside.",
  ]),
  "job_card": ("jc", [
    "Got a job for you.", "Boss. The job.", "We need to talk business.", "The job won't do itself.",
    "A little job. Nothing heavy.", "Excuse me. Business.", "I'm here about the job.", "Time to earn, boss.",
    "Allora. The work is waiting.", "A favour, for the family.", "Psst. The job.", "You know why I'm here.",
  ]),
  "job_check": ("jh", [
    "So. Is it done.", "Checking on the job.", "How's the work going, boss.", "I'm just asking. Is it finished.",
    "Report back to me.", "The job. Tell me it's handled.",
  ]),
  "job_owed": ("jo", [
    "You still owe me this.", "Another day. Still owed.", "This one's getting old, boss.", "The interest is piling up.",
    "I'm a patient man. Usually.", "This debt, it follows you.", "The books don't lie, boss.", "Three days. I'm counting.",
  ]),
  "bedtime": ("bt", [
    "Why you up. Bed.", "Hey. The bed misses you.", "It's late. Go to sleep.", "Even the family sleeps, boss.",
    "Lights out. I mean it.", "Nobody good is awake now.", "The night shift is mine. Sleep.", "Bed. Before I get upset.",
    "Close the books. Sleep.", "Mamma says go to bed.",
  ]),
  "sleep_going": ("sg", [
    "Buonanotte, boss.", "Sleep good. I keep watch.", "Sogni d'oro.", "Good man. Good night.",
    "The books are closed. Rest.", "Goodnight. Tomorrow, more business.",
  ]),
  "diary_saved": ("dy", [
    "Into the diary. Very private.", "Written down. I didn't read it.", "Your secrets are safe.",
    "Dear diary, he says.", "In the book. Locked.", "The memoirs grow.",
  ]),
  "quiet_on": ("qt", [
    "Okay. I stay in the notch.", "Quiet as a mouse.", "Not a peep. Until tomorrow.", "I'll be in the back.",
  ]),
  # The dragon, when you call him out with "pet". Only ever said right after something you did to him.
  "pet_hello": ("ph", [
    "You called, boss.", "Eccomi. Here I am.", "Somebody wants a dragon.", "I was napping. For you, okay.",
    "Out of the notch. Finally.", "Ciao, bello.", "The family pet reports for duty.", "Fresh air. Bellissimo.",
  ]),
  "petted": ("pt", [
    "Ahh. Right there.", "Okay okay, I'm a softie.", "Don't tell the family.", "Mamma mia, that's nice.",
    "A little to the left.", "This is the good life.", "You got good hands, boss.", "I'm purring. Dragons purr.",
    "Bellissimo. Don't stop.", "Respect. And scratches.",
  ]),
  "thrown": ("tw", [
    "Ey. I'm flying here.", "Was that necessary.", "My wings. My beautiful wings.", "I'll remember this.",
    "Whoa. Whoa. Okay.", "You throw like my cousin.", "The room, she's spinning.", "Again. No. Maybe.",
  ]),
  "fetched": ("ft", [
    "Got it. What now.", "Here. Like a good dragon.", "Delivered. No questions asked.", "Fetched. Where's my treat.",
    "Done. I'm very fast.", "Special delivery, boss.",
  ]),
  "follow_on": ("fo", [
    "Lead the way.", "Right behind you, boss.", "Like a shadow. A big one.", "Where you go, I go.",
  ]),
  "pet_bye": ("pb", [
    "Back to the notch.", "Ciao. Call me.", "I'll be upstairs.", "Nap time. Arrivederci.",
  ]),
  "music_play": ("mp", [
    "Music for the boss.", "The band is playing.", "Put the needle down.", "A little music. Bellissimo.",
    "Turn it up, I say.", "The jukebox, she obeys.", "Music. For the soul.", "Ecco. Your song.",
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
