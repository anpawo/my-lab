# claude-code

How my Claude Code looks and behaves. Everything here was measured against Claude Code
2.1.282 and 2.1.283 (native install, macOS). Minified names inside the binary move between
releases, so the patcher finds its sites with regexes anchored on string literals, and a
`SessionStart` hook re-applies it after every auto-update.

| Piece | Goes to | What it does |
|---|---|---|
| `hooks/adhd-colors.sh` | `~/.claude/hooks/` | `MessageDisplay` hook: paints a pastel band under the first and last `⟶` lines of every answer, edge to edge. |
| `patches/bullet-band.py` | `~/.claude/patches/` | Patches the Claude Code binary: the bullet column joins the band, the footer mode line goes away in favour of the status line, two blank rows stay under the prompt, bands survive a resume. |
| `statusline.sh` | `~/.claude/statusline.sh` | Directory, permission mode, model and effort, context fill, plan usage with reset countdown, running agents, git state. |
| `themes/mr.json` | `~/.claude/themes/` | The stock light theme with a warm background behind my own messages, so my turns are findable when scrolling back. `"theme": "custom:mr"`. |
| `trust-folders.py` | `~/.claude/` | Seeds the "do you trust this folder" flag for `$HOME` and every git repo under it, from `SessionStart`, so a fresh clone never prompts. |
| `hooks/context-guard.py` | `~/.claude/hooks/` | `UserPromptSubmit` hook: one reminder at 100k, 200k, 400k… tokens that attention degrades past 100k, whatever the window size. |
| `hooks/session-start-memory.py` | `~/.claude/hooks/` | `SessionStart` hook: loads the memory index into context. |
| `hooks/patch-check.sh` | `~/.claude/hooks/` | `SessionStart` hook: if the running binary (`$CLAUDE_CODE_EXECPATH`) has lost the patch to an auto-update, re-applies `bullet-band.py` and tells Claude to ask for a restart. |
| `skills/`, `commands/` | `~/.claude/skills/`, `~/.claude/commands/` | `table` (project status as one icon table), `ck` (commit, push, kill the session and its tab), `ww` (re-explain the last answer), `swift-macos` and `android-room-gradle` (verified toolchain traps). |
| `settings.excerpt.json` | merge into `~/.claude/settings.json` | The `statusLine`, `hooks` and `theme` keys that wire the above. |

The answer-shape rule that the hook and the patch rely on, from my `~/.claude/CLAUDE.md`:

> Every answer opens with `⟶ ` and a one-sentence answer, and closes with `⟶ ` and the next
> action, doable in under two minutes. Nothing else starts with `⟶`.

## The `MessageDisplay` hook

`MessageDisplay` exists since CLI 2.1.282 and is not listed by `/hooks`. It receives every batch
of completed lines while an answer streams, as `{turn_id, message_id, index, final, delta}`, and
its `hookSpecificOutput.displayContent` replaces the batch on screen only: the transcript and
what the model sees are untouched. Six things had to be measured to make a band out of it:

| Fact | Consequence |
|---|---|
| ANSI written by the model is escaped; ANSI in `displayContent` is honoured. | The hook can colour, the model cannot. |
| The renderer keeps SGR codes only: `\e[1G`, `\e[K` are dropped. | Full width is padding with U+00A0 up to `$COLUMNS - 2` (the 2-column indent). Plain spaces get trimmed. |
| An inline `code` span emits `\e[39m` mid-line. | Colour the background, not the text: a foreground colour is cut in half, the background holds to the `\e[49m` at end of line. |
| `COLUMNS` and `LINES` are in the hook's environment; `/dev/tty` is not reachable. | Width from `$COLUMNS`, `stty` on the parent's tty as fallback. |
| Batches must keep their trailing newline. | `split("\n")`/`join` in jq, never `$(...)`, which eats it and glues two batches. |
| Line 0 of batch 0 is the first line of the message. | Green vs blue is decided by position, not by a keyword. |

## Patching the binary

The hook stops at the text. The `⏺` bullet is its own 2-cell box drawn by the binary, the footer
is a fixed-height box, and a resumed transcript is rendered without the hook. So the binary is
patched, and the interesting part is how, because none of it is documented:

1. `~/.local/share/claude/versions/<v>` is a Bun single-file Mach-O. At its end:
   `[module graph][Offsets, 32 bytes: byte_count u64, modules {offset u32, length u32}, …]["\n---- Bun! ----\n"]`,
   offsets relative to the graph start (= trailer − 32 − byte_count).
2. The module table is 52-byte records: name, contents, ?, **bytecode** (u32 pairs), two u32,
   the name again, flags. 2,299 chunks in 2.1.282, each with source *and* JSC bytecode.
3. Each edit is same-length inside its chunk; the bytes it needs are reclaimed from that chunk's
   licence comment (the `// @bun @bytecode` marker on line 1 is kept).
4. The chunk's bytecode pointer is zeroed, otherwise Bun keeps running the old code.
5. Written to `<v>.new` then renamed over: never truncate a file a running `claude` has mapped.
   Re-signed ad hoc with `codesign -s - -f --preserve-metadata=entitlements,flags`, because
   the `allow-jit` entitlement has to survive.

`bullet-band.py <binary>` does all of it, keeps `<binary>.orig`, is idempotent (`--check` exits 0
when already patched), and stops if a site is not matched exactly the expected number of times.
Every site is a regex anchored on string literals (`"aria-label":"claude:"`, `"pasting-message"`,
`rule:"first-entry"`…) that captures the minified names it needs, so the same script took
2.1.282 → 2.1.283 unchanged. Two traps: identifiers are reused across chunks (a lookup for the
footer's `Box` must stay inside the footer's chunk), and two sites can be byte-identical (splice
by absolute offset, not by `bytes.replace`). Revert: `mv <v>.orig <v>`.

What it changes, each one a same-length or comment-reclaimed edit:

- **Bullet column.** The assistant row is `[bullet box][text]` with the bullet box stretched to
  the message height. It becomes a column with `justifyContent: space-between`: its top cell
  takes the green background when the first line starts with `⟶`, a bottom cell of two spaces
  takes the blue one when the last line does.
- **Bands on resume.** The completed-message render paints the first and last `⟶` lines itself,
  with the same colours and padding; a line the hook already painted starts with ESC and is skipped.
- **Footer.** The mode line (`⏵⏵ bypass permissions on (shift+tab to cycle)`) is never built:
  the status line shows the mode instead, in the same red and wording. The footer box is
  `height:3` instead of `height:1`, so two blank rows stay under the prompt, and the three hints
  that replace it (exit, pasting, expand-paste) are boxed at the same height so nothing jumps.
- **Mode file.** Nothing on disk changes when the mode cycles, so the state-change handler
  writes the new mode to `~/.claude/sessions/<pid>.mode`; the status line reads it first and
  falls back to the last `permission-mode` line of the transcript.

`tweakcc` (`npx tweakcc unpack`) is the off-the-shelf tool for this kind of patch; on 2.1.282 it
extracted 22 KB of a 150 MB bundle, so its layout knowledge was stale at the time.

## Checking it without opening a window

`pty.fork()` + `claude --model haiku "<prompt>"` in Python, capture the bytes, kill; replay
through `pyte` to read the screen. That is how every claim above was verified: the band's
escape codes in the raw bytes, the footer on row 38 of 40 with rows 39 and 40 empty, the
bands present after `--resume`.

## Skills I use but did not write

Not in this repo, because they are someone else's. Rated out of five, from daily use.

| Skill | From | Rating | Note |
|---|---|---|---|
| `design-council` | local skill (v0.2.1) after the `design-council` plugin in [sjsyrek/claude-plugins](https://github.com/sjsyrek/claude-plugins) | ★★★★★ | The one I reach for on any decision that crosses domains: eleven role-specialised seats, a real debate with the invoking Claude as CEO, one decision log at the end. |
| `llm-council` | [Yonas Valentin](https://github.com/yonasvalentin), MIT | ★★★★☆ | Five independent takes on the same question, then an anonymous cross-review. It surfaces what a single answer misses, and it works outside code too: pricing, positioning, a plan. |
| `i-have-adhd` | plugin, [ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd) | ★★★★★ | Cuts every answer into three parts I can read at a glance: a one-line answer, the details, the next thing to do. The bands above exist to make those three parts visible; this plugin is why they are there. |
