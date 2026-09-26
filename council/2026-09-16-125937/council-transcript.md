# Council: Wednesday, 16 September 2026, 12:59

## Original question

Which system-wide macOS autocorrect / text-expansion tool (Typinator, aText, TextExpander, Espanso, Keyboard Maestro, Rocket Typist, Alfred, macOS text replacement) should Marius use so typos get fixed on the fly in Chromium apps like Microsoft Teams? Types FR + EN on macOS 26.

## Framed question

CORE DECISION
Which tool (if any) should the user adopt so that typos are corrected AS HE TYPES, system-wide on macOS, in particular inside Chromium/Electron/WebView2 apps such as the new Microsoft Teams for Mac, which today only underlines errors in red and offered English-only suggestions ("crier / career" for the French word "creer")?

USER-PROVIDED CONTEXT
- He types in FRENCH and ENGLISH, mixed, in chat apps (Teams with external partners, Discord, etc.).
- macOS 26 Tahoe (Darwin 25.6), Apple Silicon.
- Existing tools on the machine: Handy (local speech-to-text, pastes via Cmd+V). No text expander installed.
- Preference profile: lazy/minimal setups, hates unnecessary tooling, one-time purchases over subscriptions, strong privacy stance (local first, never send credentials/text to random services), does not like polish-for-polish.
- The trigger was a Teams chat where "creer" got flagged with English suggestions and nothing was fixed automatically.

RESEARCH FACTS (web research done 2026-09-16)
- macOS built-in autocorrect and Text Replacement use NSTextInputClient/NSSpellChecker; Chromium/Electron apps do not call them. They do nothing in Teams/Chrome/Slack/VS Code.
- New Teams for Mac: multi-language spell check (up to 5 languages, Settings > General > Editor spellcheck > Manage) since mid-2025. Teams also shipped its OWN autocorrect ("Correct words while typing"), rolled out Dec 2025 to Feb 2026 on Mac/Windows/web; on by default for the primary language, off by default for extra languages (can be enabled per language); "commonly misspelled words" only, no custom entries; Mac users still report flaky multi-language handling (Mar 2026).
- Typinator 10.2 (Ergonis, Jul/Aug 2026): ships vendor-maintained AutoCorrection sets: US-EN 800+, UK-EN 800+, FR 800+, DE, NL, designed to coexist. $49.99 one-time (Mac) or $29.99/yr Mac+iOS. 10.0 built for Tahoe. Vendor lists Teams/Slack/Notion as supported. Event monitoring + clipboard/keystroke insertion.
- Espanso 2.4.1 (Sep 2026, free, GPL, Rust, local): community hub packages typofixer-fr and typofixer-en (entry counts unverified). Known Tahoe pain: Accessibility permission loops (#2530, #2402, #2576), must remove old Accessibility entry before upgrading (#2562). Electron apps often drop injected keys; needs clipboard backend per app.
- TextExpander 8.4.7 (Aug 2026): subscription only ($60/yr); public autocorrect groups incl. one French; Tahoe trigger-char bugs reported Feb 2026.
- aText: last release Jul 2024, site lists macOS up to 15, no Tahoe statement; $29.99 lifetime; English misspelling snippets, French unverified. Effectively dormant.
- Keyboard Maestro ($36) / Alfred / Rocket Typist: snippet engines only, no misspelling dictionary.
- Grammarly Desktop: EN only, suggestions not auto-apply, breaks in new Teams. LanguageTool desktop: FR+EN suggestions overlay, no silent autocorrect. Antidote 12: full FR/EN corrector but manual invocation (Connectix), €59-89/yr. Charm ($19.99, on-device LLM): EN only, manual in Electron. Cotypist: on-device inline typo fix + autocomplete, FR unverified, $72/yr, 16 GB RAM recommended.

STAKES
Wrong choice = money spent on a subscription he resents, a tool fighting the OS (Accessibility loops, secure-input breakage, expansions firing inside code/passwords/terminal), or worse: auto-"corrections" that silently mangle French words with an English dictionary, or leak typed text to a cloud service. Also the cost of any tool at all when a per-app setting might already solve the actual pain.

## Workspace context used

- ~/.claude/CLAUDE.md: minimal change, no unnecessary tooling, no agent-opened windows, reuse what exists.
- memory/tools/handy.md: Handy (local speech-to-text) installed, pastes via Cmd+V.
- Web research pass (2026-09-16) on all candidate tools, folded into the framed question.
- Post-review system check: macOS spelling prefs at default (automatic by language, AppleLanguages en-US + fr-US), layout U.S., press-and-hold default.

---

## Round 1: Advisor responses (raw, de-anonymized)

### The Contrarian

The load-bearing assumption nobody is examining: that "creer" flagged in Teams is a *typo* problem. It is not. "creer" is not a misspelling of "créer" in any French autocorrect dictionary; it is the correct word with the accent dropped, and the actual failure was Teams running an English-only dictionary against French text. Every system-wide autocorrector on the list (Typinator FR 800+, espanso typofixer-fr) targets *common misspellings*, not "user typed é as e". The very case that triggered this question will not be fixed by the $49.99 tool. He will buy it, type "creer" again, and watch it stay "creer".

Worse mechanism: mixed FR/EN in the same sentence with two vendor sets "designed to coexist". "Coexist" means the sets don't share trigger strings, not that the tool knows which language he is in. An English set with 800+ entries will contain triggers like "cant", "wont", "dont", "sont"-adjacent tokens; a French set will contain "ou", "a", "sa" style fixes if it touches accents at all. Type "sont" in an English chat, or "coin"/"chat"/"pain" in French, and something fires. Teams's own autocorrect at least knows the declared language; a keystroke-level replacer knows nothing. He wanted fewer red underlines; he will get silent substitutions that make a message to an external partner wrong without any underline warning him.

The year-two friction: an Accessibility-permission daemon (Typinator, espanso, all of them) sits under every keystroke, including Terminal, Claude Code, password fields when secure input flickers, and Handy's Cmd+V pastes. The research already lists Tahoe permission loops for espanso and trigger bugs for TextExpander on the same OS. He will spend more minutes disabling it per app than he ever lost to a red underline.

The right question is not "which tool" but "is this pain even recurring". Teams > Editor spellcheck > add French, enable "Correct words while typing" for French, and see whether the pain survives a month. If the accent-dropping is the real habit, no third-party dictionary fixes it anyway.

### The First Principles Thinker

You are asking "which tool", but the incident that triggered this does not contain a tool-shaped problem.

Strip it down. One word, "creer", underlined in one app, with suggestions from the wrong dictionary. That is not evidence that macOS lacks system-wide autocorrect. It is evidence that Teams' spell checker had no French dictionary loaded. Your own research says so: Teams now ships multi-language spellcheck (up to 5 languages) and its own autocorrect, on by default for the primary language, off by default for the others. French was off. The fix is a checkbox in Settings > General > Editor spellcheck, costs zero dollars, adds zero Accessibility-permission daemons, and touches nothing outside Teams.

Now test the premises the framed question smuggles in:

- "System-wide." You named two apps. Two per-app settings is not a system-wide problem. Discord's Chromium spellcheck also takes a language list.
- "As I type." Was the pain that nothing auto-fixed, or that the red underline offered "career" for a French word? The second is the one that actually annoyed you, and it is a dictionary-language bug, not a missing feature.
- "Typos." "creer" is a missing accent, not a keystroke slip. An 800-entry misspelling list (Typinator FR) may or may not contain it; you have no data on what your errors actually look like, because you have one sample.

The fatal flaw in the tool route: mixed FR/EN in the same message is the one case dictionary autocorrect cannot do safely. "chat", "pain", "coin", "main", "on" are valid in both languages; every misspelling set that "coexists" is guessing. A resident keystroke monitor that silently rewrites words is the highest-cost, highest-risk category on your list, bought to solve a problem you have observed once.

The right question is: after enabling French in Teams and Discord, does anything still hurt in the next two weeks? If yes, you will have real samples, and then the tool question is worth asking.

### The Expansionist

The question is framed too small. "Fix typos in Teams" is the symptom; the trigger word gives away the real prize: "creer" is not a misspelling, it is French typed without accents. That is a whole typing habit, and it is the thing worth buying.

The upside nobody is pricing:

- **Accent-free French at full speed, everywhere.** A vendor-maintained FR set of 800+ entries (Typinator 10.2) is mostly accent restorations: creer→créer, etre→être, deja→déjà, francais→français. Turn that on and he never reaches for Option-e again, in Teams, Discord, Gmail, the terminal's chat pane. The Teams-only toggle (free, "commonly misspelled words", no custom entries) cannot do this and dies at the Teams window edge. Discord and every external partner chat stay broken.
- **The dictionary compounds.** Every typo he corrects once becomes a rule forever. In a year he has a personal FR/EN orthography layer that no per-app setting will ever give him. Espanso stores this as YAML he can grep, version and carry to the next Mac; Typinator exports sets. Either way the asset outlives the tool.
- **Handy already proves the delivery path.** Speech-to-text pasting via Cmd+V works in his Electron apps today. A clipboard-backend expander rides the exact same channel, so the "Electron drops injected keys" objection is already answered on this machine.
- **One-time $49.99 buys the FR+EN coexistence explicitly designed to not fight each other**, which is the one thing Teams still gets wrong on Mac as of March 2026.

Ride it further: once the corrector is in place, add his own recurring English/French false friends and his project names, and Handy's transcripts become a source of new entries. Don't settle for the free Teams checkbox; it solves one app and zero accents.

### The Outsider

Reading this cold, the question buries its own answer in the research facts. Teams shipped its own autocorrect ("Correct words while typing") in Dec 2025–Feb 2026, and it is on by default for the primary language, off by default for the others. The trigger incident was "creer" getting English suggestions. That is exactly what you'd expect if French is not the primary language and French autocorrect was never switched on. The fix described on the page is a checkbox: Settings > General > Editor spellcheck > Manage, add French, enable correct-while-typing for it. Cost: zero. That is the first thing to try, and the question should have been "does the per-app setting fix it?" before "which $50 tool?"

Things a stranger cannot parse on this page:

- "system-wide" vs "in Teams" are two different asks. The trigger is one app. The framing escalates to all Chromium apps with no evidence he types badly enough in Discord to care.
- "800+ FR AutoCorrection set" (Typinator) means nothing without knowing what's in it. 800 entries could be "ceer -> créer" or could be 800 English-loanword fixes. Unverified for the actual failure case.
- "typofixer-fr (entry counts unverified)" for Espanso: same, plus a page full of Tahoe bugs (#2530, #2402, #2576, #2562) and "Electron apps often drop injected keys". The one environment he cares about is the one it's worst at.
- Nothing states which language Teams considers his primary. That single fact decides the whole thing and is absent.

Fatal-flaw check on the paid options: every keystroke tool listed works by clipboard/keystroke injection and a mixed FR/EN typist gets fired on by two dictionaries at once. "crier / career" for "creer" is precisely what a dumb English autocorrect does to French, and a $50 tool doing that silently across every app is worse than red underlines.

Answer: flip the Teams setting, type for a week, come back only if it's still broken.

### The Executor

Monday morning, before spending a cent: open Teams, Settings > General > Editor spellcheck > Manage, add French, and turn on "Correct words while typing" for French. It's off by default for extra languages, which is almost certainly why "creer" got English suggestions and no fix. Then type "creer" in a chat to yourself. That's a five-minute experiment that may close the whole question, because the trigger was one Teams chat, not Discord, not a system-wide itch.

If that works, stop. Live with it a week. Discord will still only underline, but that's a hypothetical pain until it actually bites.

If Teams' autocorrect is flaky (the March 2026 reports say Mac multi-language is), the next cheapest test is Typinator's trial, not Espanso. Espanso is free, but the Tahoe Accessibility loops (#2530, #2402, #2576) plus per-app clipboard backend tuning for Electron is a Saturday gone, and the FR/EN typofixer entry counts aren't even verified. Typinator 10.2 gives 800+ FR and 800+ EN sets built to coexist, built for Tahoe, $49.99 once. The trial answers in a day whether keystroke injection actually lands in Teams and Discord on this machine.

The two things that will eat time, whichever tool:

- Expansions firing where they must not: Terminal, VS Code, password fields, Handy's Cmd+V paste. Day one, exclude those apps explicitly. Test a paste from Handy and a typed shell command before trusting it.
- Real-word collisions between the FR and EN sets when mixing languages in one message. Keep a scratch chat open for the first week, watch for mangled words, delete offending entries as they appear.

Ship order: Teams setting (5 min) → one week → Typinator trial only if needed → buy only if you caught it fixing something you'd have shipped wrong.

---

## Anonymization map

Session timestamp: `2026-09-16-125937` · permutation index: `97`

| Advisor | Letter shown to reviewers |
|---|---|
| Contrarian | B |
| First Principles Thinker | C |
| Expansionist | E |
| Outsider | D |
| Executor | A |

---

## Round 2: Peer reviews (reviewers saw only the anonymized A to E responses)

### Reviewer 1

**1. Strongest: A.** Only one that gives a runnable sequence with a fallback (Teams toggle → week → Typinator trial → buy only on evidence), names the day-one exclusions (Terminal, VS Code, password fields, Handy's Cmd+V), and plans for FR/EN collisions instead of just warning about them.

**2. Biggest blind spot: E.** It builds the whole case on "the FR set is mostly accent restorations" while the research marks entry contents unverified, and it never confronts that accent restoration is context-dependent: a/à, ou/où, la/là, sur/sûr, du/dû cannot be fixed by any word list. It also ignores that its "dictionary compounds" asset fires blind on English text in mixed messages, the exact mangling B/C/D flag.

**3. What all five missed:**
- The actual complaint was wrong-language *suggestions*, not missing auto-fix. The safest first step is adding French to Teams/Discord spellcheck with autocorrect left **off**: correct underlines, zero silent rewrites. Nobody separated the two toggles.
- Four responses treat the Teams autocorrect checkbox as risk-free, but it is the same silent replacer, driven by the multi-language detection the research says is flaky on Mac as of March 2026. Teams-mangling a message to an external partner is the identical failure mode they fear from Typinator, minus the exclusion list.
- Handy already produces accented French; dictating French messages sidesteps the accent habit with tooling he owns.

### Reviewer 2

**1. Strongest: C.** It correctly diagnoses "creer" as a dropped accent, not a typo (so an 800-entry misspelling set is unverified for the actual failure), covers both named apps with per-app language settings, names the mixed FR/EN real-word collision risk, and sets a concrete exit criterion: collect real samples for two weeks before any tool question. A is more procedural but escalates to a Typinator trial without checking that the set addresses accents at all.

**2. Biggest blind spot: E.** It sells Typinator on the claim that its FR set is "mostly accent restorations" with zero evidence, and never mentions real-word collisions ("chat", "pain", "coin", "sont"), Accessibility loops, secure-input flicker, or exclusions for Terminal/VS Code/Handy. It also conflates Handy's hotkey paste with trigger detection: pasting works; keystroke *monitoring* is the part that breaks in Electron.

**3. Missed by all five:**
- The premise that Chromium/Electron ignore NSSpellChecker is at least partly wrong on macOS: Chrome and Electron defer to the native spellchecker, whose language list is System Settings > Keyboard > Spelling ("Automatic by Language" / add French). That is one zero-cost setting covering Teams, Discord and everything else, and nobody proposed checking it.
- The habit is input-side, not correction-side: Handy already produces accented French; a Tahoe press-and-hold or a French layout removes the error before any corrector is needed.

### Reviewer 3

**1. Strongest: A.** Only response that both deflates the question (Teams checkbox first, one-week wait) and gives a concrete path if it fails: Typinator trial before purchase, day-one exclusion list (Terminal, VS Code, password fields, Handy's Cmd+V), scratch chat to catch FR/EN collisions. C is sharper on premises but stops at "wait for samples."

**2. Biggest blind spot: E.** Asserts the Typinator FR set is "mostly accent restorations" with zero evidence (the research explicitly calls entry contents unverified), and claims Handy's Cmd+V "proves the delivery path" when a one-shot transcript paste is nothing like mid-word keystroke substitution. It never addresses real-word collisions in mixed FR/EN, the exact failure mode the stakes section names, and cheerfully proposes expansions in "the terminal's chat pane."

**3. What all five missed:**
- The accent-dropping is an **input-layer** problem, not a spellcheck one. Nobody asked which keyboard layout he uses. A French/dead-key layout, or press-and-hold accents, restores é at the keystroke, works in every app including Electron, costs nothing, and involves no daemon. That sits above every tool discussed.
- **Privacy of the "free" fix**: Teams spellcheck/autocorrect is Microsoft Editor, a cloud service. Given his local-first stance, the checkbox everyone recommends may be the option that ships his text off-device. Verify before flipping it.

### Reviewer 4

**1. Strongest: A.** Only response that turns the diagnosis into a sequenced plan with the two real failure modes named up front: app exclusions (Terminal, VS Code, password fields, Handy's Cmd+V) and FR/EN real-word collisions, each with a concrete day-one test. It also prices Espanso's Tahoe cost honestly instead of calling it "free".

**2. Biggest blind spot: E.** It sells accent restoration everywhere and never asks what an FR set does inside an English sentence ("a", "ou", "sur", "chat", "pain" all fire). It also misreads Handy as proof: Handy only pastes; it never intercepts keystrokes, so it proves nothing about trigger detection in Electron, which is the part that breaks.

**3. What all five missed.** On macOS, Chromium/Electron spellcheck (underline + suggestions) is delegated to NSSpellChecker, and the language comes from System Settings > Keyboard > Text Input > Edit > Spelling. If that is set to "U.S. English" rather than "Automatic by Language", every Electron app (Discord included) gets English-only suggestions, exactly the observed symptom. The framed "research fact" that Chromium ignores the OS is only true for autocorrect, not spellcheck. The council should verify that one system setting before Teams' own toggle: it is the only fix that is zero-cost, system-wide, and daemon-free. Nobody also asked whether accent-less French in chat is a cost at all.

### Reviewer 5

**1. Strongest: A.** Same free-first diagnosis as B/C/D, but the only one that ships an order (Teams toggle → week → Typinator trial → buy only on caught mistakes) and names the two operational traps day one: exclusions for Terminal/VS Code/password fields/Handy's paste, and FR/EN real-word collisions with a scratch chat to catch them.

**2. Biggest blind spot: E.** It builds the whole case on "the FR set is mostly accent restorations" with zero evidence (research says entry contents unverified), never mentions collisions, secure input or terminal firing, and misreads Handy: Handy proves clipboard *paste* lands in Electron, not that per-keystroke *trigger detection* works there, which is the failing half.

**3. What all five missed:**
- B and E flatly contradict each other on whether "creer→créer" is in any set, and nobody proposed the two-minute settle: espanso's typofixer-fr YAML is public on the hub, Typinator's trial ships its FR set; grep both for `creer`, `etre`, `deja`. That one check decides accent-habit vs typo-tool.
- The accent habit has a native, daemon-free fix nobody named: press-and-hold on `e` (works in Chromium) or a layout where accents are first-class (French/ABC-Extended).
- Discord's Chromium spellcheck languages follow macOS System Settings > Keyboard > Spelling; adding French there is the actual free "system-wide" lever for the underline problem.

---

## Chairman synthesis

### Where the council agrees

- **Contrarian, First Principles, Outsider, Executor** (4 of 5): the trigger was Teams running an English-only dictionary against French text, not a missing macOS feature. First move is free: add French in Teams (Settings > General > Editor spellcheck > Manage). Every reviewer picked one of these four as strongest.
- **Contrarian, First Principles, Expansionist**: "creer" is a dropped accent, not a keystroke slip. Whether any autocorrect set fixes it is unverified.
- **Contrarian, First Principles, Outsider, Executor**: mixed FR/EN in one message is exactly where word-list autocorrect fails (chat, pain, coin, sont, a/à, ou/où fire in both languages). A silent replacer that mangles a message to an external partner is worse than a red underline.
- **Contrarian, Executor**: any resident keystroke daemon (Typinator, Espanso) fires in Terminal, Claude Code, password fields and under Handy's Cmd+V paste; exclusions become a maintenance chore.
- **Executor, Outsider**: Espanso is not "free" on Tahoe: Accessibility loops and per-app clipboard backend tuning cost a Saturday.

### Where the council clashes

- **Buy now vs. free checkbox first.** The Expansionist says buy Typinator ($49.99 once) for accent-free French everywhere and a personal dictionary that compounds; the other four say flip the Teams setting and wait. Reasonable because a one-time tool covering Discord and Gmail is cheap if accents really are a daily habit, and wasteful if the pain was one word in one app.
- **Does a French autocorrect set even contain "creer → créer"?** The Contrarian says no set targets dropped accents; the Expansionist says the sets are mostly accent restorations. Both are guessing: the research left set contents unverified, and Reviewer 5 points out it is a two-minute grep to settle.
- **Escalation path.** The Executor escalates to a Typinator trial after one week; the First Principles Thinker refuses any tool until two weeks of real error samples exist. Either is defensible: a trial is cheap, but without samples nobody knows what the tool should fix.

### Blind spots the council caught

- **Fix the input, not the correction** (Reviewers 1, 2, 3, 5 converged). The habit is typing French without accents. Press-and-hold on a vowel works in every Chromium app, a French or ABC-Extended layout makes accents first-class, and Handy already dictates accented French. All three are daemon-free and cost nothing. Checked after the review: the Mac runs the plain U.S. layout with press-and-hold at default, so this is available today.
- **Underline and autocorrect are two different toggles** (Reviewer 1). The complaint was wrong-language suggestions. Adding French with autocorrect left off gives correct underlines and zero silent rewrites. Four advisors treated Teams' "Correct words while typing" as risk-free; it is the same silent replacer, driven by multi-language detection reported flaky on Mac in March 2026. Reviewer 3 adds that it is Microsoft Editor, a cloud service, worth checking against his local-first stance.
- **The "Chromium ignores macOS" premise was oversold** (Reviewers 2, 4, 5). Chromium and Electron on macOS delegate spellcheck underlines to the native spell checker, whose languages come from System Settings > Keyboard > Text Input > Spelling. Checked after the review: that setting is at its default, automatic by language, with French already listed. So Discord should already underline French correctly, and the Teams failure is Teams' own Editor dictionary, which confirms the Teams-side fix.

### The recommendation

Buy nothing. Four advisors and all five reviewers agree the pain was a missing French dictionary in Teams, and the system check confirms macOS itself already handles French. Add French to Teams' Editor spellcheck with autocorrect left off, and fix the accent habit at the keyboard (press-and-hold, or Handy for longer French messages). I am overruling the Expansionist: the case for Typinator rests on an unverified claim about what its French set contains and ignores mixed-language collisions. Revisit a tool only if two weeks of real samples show repeated misspellings that a word list could fix, and grep espanso's typofixer-fr for those exact words before spending a cent.

### The one thing to do first

In Teams, open Settings > General > Editor spellcheck > Manage, add Français, leave "Correct words while typing" off, restart Teams and retype "creer" in a chat to yourself.
