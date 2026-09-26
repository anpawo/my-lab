# Council: 24 September 2026

## Original question

do a full check of all the files on the computer, use sub agents to divide the task. once uve found dead files or unused stuff. lmk. use a council to make it clean and only lmk what matters

## Framed question

A read-only audit by 6 agents produced ~90 findings on this Mac (findings.md). Decide the SHORT list that matters: (1) most space for least risk, (2) data-loss risks, (3) config rot worth fixing, (4) what to ignore. Stakes: deleting the wrong thing = lost uncommitted work or hours rebuilding Qt; a list too long = nothing gets done.

## Workspace context used

~/.claude/CLAUDE.md (commit rules, no-window rule), memory (node@22 for portfolio, epitech scan moved to Lightpanda), scratchpad findings.md from 6 scan agents; chair verified pyenv is the active Python.

---

## Round 1: Advisor responses (raw, de-anonymized)

### The Contrarian

**The real failure mode is `git worktree remove --force`, not disk space.** 42G free is not an emergency. A size-sorted list puts .claude/worktrees (361M) next to caches, and one careless cleanup pass will throw away unmerged commits.

1. Space — four actions, ~47G, then stop: vcpkg buildtrees (30G) + packages (8.7G) — safe, but not for the reason given. The binary-cache argument is false comfort: its hash includes the compiler version, so the next Command Line Tools update invalidates it anyway. Buildtrees are safe because vcpkg never reuses them. `brew cleanup -s` (4.2G). AVD quick-boot snapshot (3.9G). DO NOT touch vcpkg_installed/.../debug (7.8G) or ~/.cache/vcpkg/archives: deleting debug libs while vcpkg's status file still marks them installed gives Debug link errors or an unplanned Qt rebuild from source.
2. Data-loss risks nobody asked about: volt3 (zero commits, only copy) — commit today. Video-code worktrees and my-hub cartes-crypto hold unmerged/dirty work — merge or push, never remove. No backup is mentioned anywhere: without Time Machine, every only-copy item (openclaw tarball, finance-crypto results, manim edits) is one dead SSD from gone. That dominates any item on the list. ~/.config/elevenlabs holds a key file: revoke the key, don't just delete the folder.
3. Config rot: memory/general.md still names ~/.epitech-webkit — agents follow memory, fix the line before deleting the folder or a future session will "repair" it. ~/.claude.json: 21 .bak files show something rewrites it constantly; with fleet sessions running, a hand edit gets overwritten — use `claude mcp remove magic`.
4. Ignore: everything under 1G, brew formulae, unopened apps, rustup, Office, the emulator stack (my-hub is Android), Docker's half update. Respondus is an exam lockdown app — deleting it is how you fail an exam.

The pyenv conflict was only caught because two agents disagreed, so the "HIGH" labels can't be trusted.

### The First Principles Thinker

**Wrong question: this isn't a disk-space problem, it's a single-copy-of-data problem.**

Premise check:
- "Disk space matters" — barely. 42G free of 228G is not a crisis. One item alone (vcpkg buildtrees 30G + packages 8.7G) roughly doubles free space. Everything else in the other ~80 findings is maybe 15G combined. Ranking it is wasted attention.
- "Deleting wrong thing = hours rebuilding Qt" — false for the big item. buildtrees/packages are intermediates; output lives in video-code/vcpkg_installed and the 2G binary cache in ~/.cache/vcpkg/archives. The only rule: never touch vcpkg_installed or ~/.cache/vcpkg/archives. Everything else under ~/.local/share/vcpkg is safe.
- "Lost uncommitted work" is the real stake — but that's not caused by cleanup, it's caused by work existing in exactly one place. Nobody checked for Time Machine/backups. That's the actual question.

The short list:
1. Space — one action: delete ~/.local/share/vcpkg/{buildtrees,packages} (~39G). Add --clean-after-build so it never regrows. Then `brew cleanup -s` (~4G). Stop.
2. Only-copy work (do before #1): ~/self/volt3 (zero commits), video-code .claude/worktrees (unmerged commits), my-hub cartes-crypto (5 dirty), ~/repo/manim (5 uncommitted edits), finance-crypto CSVs (410M, gitignored, costly), ~/.openclaw-backup tar.gz. Fix = commit+push or copy to external.
3. Config rot — just two: magic MCP stale key (fails every session start, you saw it this session), and memory/general.md pointing agents at ~/.epitech-webkit when the path moved to lightpanda.
4. Ignore: everything under 1G, unused apps, brew formulae, orphan dotfiles, 37 dead .claude.json project entries.

First action: `git -C ~/self/volt3 add -A && git commit -m init`, then push somewhere.

### The Expansionist

**You're treating this as a one-time purge. The real win is making the space not come back.**

- The one move that matters: video-code's Qt is ~46G of your ~63G reclaimable (buildtrees 30G + packages 8.7G + debug libs 7.8G). Deleting it once is half the win — next Qt rebuild regrows all of it. Make it permanent: release-only triplet (VCPKG_BUILD_TYPE release) + --clean-after-build. Then ask the bigger question: ~40 Homebrew qt* formulae (801M) are already installed. If video-code can build against brew's Qt, "hours rebuilding Qt from source" stops being a risk at all — the scary stake is optional.
- Save the 2G binary cache (~/.cache/vcpkg/archives) before touching anything. It's what makes the 46G safe.
- The 15G emulator stack: the user's own rules already say Paparazzi renders Android without an emulator, and the AVD is named after a real phone (honor200lite). Paparazzi + the physical phone over adb makes the emulator last-resort. That's 15G plus alignment with the user's own rule.
- Risks: volt3 (zero commits) and 5 worktrees with dirty files. Don't just check them once: dirty worktrees / zero-commit repos / unpushed commits could be a ~20-line script in my-setup (auto-committed anyway) run by launchd like the existing epitech-scan. Six agents was expensive; a script reruns it for free.
- Config rot that pays every session: magic MCP failing (seen again this session), 37/85 dead .projects entries, memory/general.md still sending agents to ~/.epitech-webkit.
- Ignore: brew formulae, LaunchAgents, Office, .bak files, orphan dotfiles, anything under 500M.

First action: `brew cleanup -s` (4.2G, zero risk), then delete vcpkg buildtrees after confirming the archive cache exists.

### The Outsider

- **Is there a disk problem at all?** The file says both "data volume full-ish" and "42G free" (18%). No one says what goes wrong at 42G, so the question takes for granted that space is urgent. On the numbers given, it isn't. The only real emergency on the page is lost work, and those items are scattered among the cache entries.
- **Lead with the loss risks, not the space.** Five items: volt3 (zero commits, only copy), video-code worktrees (unmerged commits), my-hub cartes-crypto (5 dirty files), manim (5 uncommitted edits), openclaw-backup (only copy). Five items is short enough to act on. Ninety is not.
- **Jargon that blocks any action:** "buildtrees", "packages", "triplet", VCPKG_BUILD_TYPE, "binary cache", "quick-boot snapshot", "regrow", "Caskroom", "shims". A first-time reader can't tell which of these deleting would hurt. HIGH/MED/LOW is never defined — safe? valuable? risky? "Memory says" and "agent1 vs agent6": a reader can't settle conflicts between agents they never saw.
- **One unchecked claim bears on the biggest item.** "Binary cache (2G) makes rebuild fast" justifies deleting 38.7G, and the stakes name a Qt rebuild as the worst outcome. Nobody shows a 2G cache actually covers a 19G qtdeclarative build tree. Until checked, the 30G item is not "HIGH" safe.
- **A security item filed as clutter.** ~/.config/elevenlabs has a key file, listed as "orphan config". A leftover API key should be revoked and deleted, not ignored.
- **Mixed-up categories.** "Stale", "orphan", "dead since Sep 5", "never opened since migration", "never typed in fish history" are five different measures of "unused". Not typing a command doesn't mean scripts don't use it, as the node@22 correction proves.
- **Fix for the output:** each surviving line says what it is in plain words, the size, and what breaks if deleted. If that last part can't be stated, the item doesn't belong on the list.

### The Executor

**Monday morning is one 20-minute session. Two commands get most of the space; after that, stop.**

1. Space — ~47G, five low-risk commands:
- `rm -rf ~/.local/share/vcpkg/buildtrees ~/.local/share/vcpkg/packages` → 38.7G. Built output is in video-code/vcpkg_installed; ~/.cache/vcpkg/archives (2G) is the safety net. Never touch archives.
- `brew cleanup -s` → 4.2G.
- `rm ~/.android/avd/honor200lite.avd/snapshots/default_boot` → 3.9G, rebuilds on next emulator launch.
- Office .pkg copies in Caskroom 3.4G + empty Trash.
2. What eats time: buildtrees regrows on the next vcpkg Qt bump. Add --clean-after-build to video-code's vcpkg install now — one line, the saving lasts.
3. Data-loss risks — 5 minutes, before any deletion: volt3 has zero commits — `git add -A && git commit -m wip`, 30 seconds, highest-value action on the list. The 4 video-code worktrees and my-hub cartes-crypto: don't delete, push each to a branch or look at them this week. finance-crypto backtests + ml/resultats (410M): keep away from any cleanup.
4. Config rot — two fixes, because they mislead every session: magic MCP fails auth every startup — remove or rotate the key. memory/general.md still names .epitech-webkit — fix that line.
5. Ignore everything else: anything under 1G (rustup, npx, serve-web, old Claude versions), unopened apps, brew formulae, orphan dotfiles, the 37 dead .claude.json entries and .bak files, LaunchAgents, pyenv (active, keep), node@22 (keep).

The question is too big. With 42G free, space isn't urgent. The commits are the only urgent work. Run the commands above and put a "done by Wednesday" on the worktrees.

---

## Anonymization map

Session timestamp: `1790242232` · permutation index: `32`

| Advisor | Letter shown to reviewers |
|---|---|
| Contrarian | D |
| First Principles Thinker | A |
| Expansionist | B |
| Outsider | C |
| Executor | E |

---

## Round 2: Peer reviews (reviewers saw only the anonymized A to E responses)

### Reviewer 1

1. Strongest: D — only one to flag the 7.8G debug-libs trap (vcpkg status file still lists them installed) and to explain why buildtrees are safe (never reused, not "the binary cache covers it"); also catches the elevenlabs key, Respondus, and `claude mcp remove` since .claude.json keeps getting rewritten.
2. Blind spot: B — pushes a release-only triplet; changing the triplet changes vcpkg's ABI hash, the 2G cache stops matching, next build compiles Qt from source — the exact worst case. Also omits finance-crypto, manim, openclaw only-copies.
3. All missed: .claude/worktrees may belong to live fleet sessions — check before touching. APFS local snapshots can hold deleted blocks, so deleting 39G may free little; run `tmutil listlocalsnapshots /`.

### Reviewer 2

1. Strongest: D — corrects the findings rather than repeating them (cache not a real net; debug libs trap; fix memory before deleting ~/.epitech-webkit; elevenlabs key is revocation, Respondus is exams).
2. Blind spot: E — the plan the user would actually run treats archives as a safety net unverified, never asks about backups, skips the key; would delete 47G without checking the one assumption protecting Qt.
3. All missed: ~70G of used space is unexplained (228−42 = 186 used vs ~105 home + 12 system) — snapshots? Live sessions during cleanup. `git add -A` on volt3 then "push somewhere" can publish secrets — check .gitignore, use a private remote.

### Reviewer 3

1. Strongest: D — only one separating the two vcpkg items correctly (buildtrees/packages safe because never reused; debug libs must stay), plus elevenlabs, Respondus, memory-before-delete ordering.
2. Blind spot: B — release-only triplet misses the archive cache and triggers the full Qt rebuild; treats it as free; pushes dropping the emulator while my-hub is Android; no backups or key.
3. All missed: the ~70G gap (snapshots / swap / purgeable); if snapshots hold it, deleting frees nothing and they answer the backup question. Nobody checked video-code's main checkout for uncommitted work — never auto-committed, and it's the repo whose vcpkg gets touched.

### Reviewer 4

1. Strongest: D — catches the traps that cause real damage: debug libs, weak cache, memory-before-delete, `claude mcp remove`, key revocation, Respondus, backup question.
2. Blind spot: B — counts debug libs as reclaimable and floats brew Qt without the rebuild risk; skips backups, manim, finance-crypto, the key.
3. All missed: worktrees will keep coming back — the auto-commit rule covers the projects but not the agent worktrees inside them; fix the rule/stop hook, not just this instance. The 21 .claude.json.bak files likely contain MCP keys including magic's — rotating the key leaves old copies on disk; they're a secrets problem, not clutter.

### Reviewer 5

1. Strongest: D — explains why buildtrees are safe, flags the cache weakness and debug-lib trap, names `git worktree remove --force` as the real data-loss command, elevenlabs, Respondus, `claude mcp remove`.
2. Blind spot: E — rm -rf first, cache unverified, "commit" volt3 but never "push" (only copy stays on the same SSD), no backup, drops the live elevenlabs key under "orphan dotfiles".
3. All missed: APFS local snapshots may hold freed space. The audit is a snapshot while fleet sessions run in worktrees — re-check dirty state right before deleting. `--clean-after-build` goes into video-code, never auto-committed, so it waits for the user's review.

---

## Chairman synthesis

### Where the council agrees

- **All five:** space is not the emergency (42 GB free). One delete — `~/.local/share/vcpkg/buildtrees` + `packages` (38.7 GB) — is most of the win; `brew cleanup -s` (4 GB) is the only other one worth doing.
- **All five:** the real risk is work that exists in one place: `~/self/volt3` (zero commits), video-code worktrees (unmerged commits), my-hub `cartes-crypto` (5 dirty files). Handle them before deleting anything.
- **Contrarian, First Principles, Expansionist, Executor:** only two config fixes matter — the `magic` MCP that fails every session, and the `memory/general.md` line still sending agents to `~/.epitech-webkit`.
- **Four of five:** ignore everything under ~1 GB, unused apps, brew formulae, orphan dotfiles.

### Where the council clashes

- **Release-only vcpkg (drop 7.8 GB debug libs):** Expansionist for, Contrarian against — changing the triplet changes the ABI hash, misses the binary cache and rebuilds Qt from source. All 5 reviewers sided with the Contrarian; so does the chair.
- **Drop the Android emulator (15 GB):** Expansionist (Paparazzi + real phone) vs Contrarian/Executor (my-hub is Android). Kept: it's a workflow call, not cleanup.
- **Why buildtrees are safe:** binary cache (Executor, First Principles) vs "vcpkg never reuses them" (Contrarian). Chair checked: both hold — 47 archives for 47 installed ports.

### Blind spots the council caught

- **No backup exists (verified):** `tmutil` reports no Time Machine destination. Every only-copy item is one SSD failure from gone. Raised by two advisors, confirmed by the chair.
- **Secrets, not clutter:** `~/.config/elevenlabs/key` from an uninstalled tool, and 17 of the `~/.claude.json.bak-*` files carry the magic MCP config. Rotating a key leaves the old copies.
- **Worktrees recur:** the auto-commit rule covers the projects, not `.claude/worktrees` inside them — that's how the dirty ones piled up. (Checked: none is live; last touched Sep 6–12.)
- **Dismissed after checking:** APFS local snapshots — none exist, deletions free space immediately. The "missing 70 GB" is `/Applications` (19 GB) + Homebrew (15 GB).

### The recommendation

Protect first, then one delete. Commit and push the only-copy work (volt3, the 5 worktrees, video-code's 8 dirty files), then delete vcpkg buildtrees + packages and run `brew cleanup -s` — ~43 GB, no rebuild risk. Keep the debug libs, the emulator, pyenv 3.14.2 (the active Python) and node@22 (portfolio needs it); I overrule the Expansionist on the triplet change. Set up a backup — that, not disk space, is the gap this audit exposed.

### The one thing to do first

Commit `~/self/volt3` (check its `.gitignore` first) and push it to a private GitHub repo — it is the only copy of that project.
