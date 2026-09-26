#!/usr/bin/env bash
# Claude Code auto-updates and the new binary loses the display patch: re-apply it and say so.
bin=${CLAUDE_CODE_EXECPATH:-$(readlink -f "$(command -v claude)")}
[ -f "$bin" ] || exit 0
python3 ~/.claude/patches/bullet-band.py "$bin" --check >/dev/null 2>&1 && exit 0
if out=$(python3 ~/.claude/patches/bullet-band.py "$bin" 2>&1); then
  echo "Claude Code binary $(basename "$bin") was unpatched (auto-update): bullet-band.py re-applied it. Tell the user to restart claude for the bands, footer and status-line mode to come back."
else
  echo "Claude Code binary $(basename "$bin") is unpatched and bullet-band.py failed (anchors probably moved with the release). Tell the user. Output: $out"
fi
