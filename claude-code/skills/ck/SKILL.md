---
name: ck
description: >
  commit-kill. Commits and pushes the repo the session is in, then ends this Claude session and
  closes the terminal tab it runs in. Triggers: "/ck", "ck", "commit kill", "commit-kill".
---

# ck — commit, push, kill

Do the three steps in order. Anything that fails before the last step stops the skill: report
in one line, kill nothing.

1. **Commit.** `git status --porcelain` in the current directory. Not a repo → stop. Nothing
   listed → skip to the push. Otherwise `git add -A` and commit with a one-sentence title in
   the repo's own style (read `git log --oneline -5`), written from the diff, ending with the
   `Co-Authored-By` trailer the session already uses.
2. **Push.** `git push`, or `git push -u origin <branch>` when the branch has no upstream.
   Rejected push → stop and say why; the commit stays local.
3. **Kill.** Print the one-line summary (`<hash> pushed to <remote>/<branch>`), then run
   `~/.claude/skills/ck/kill.sh` as the very last tool call. It ends the `claude` process and
   the shell above it a second later, and Ghostty closes the surface on its own. Nothing you
   write after it will be read.

`kill.sh --dry-run` prints the pids it would signal without signalling them.
