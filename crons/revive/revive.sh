#!/bin/bash
# revive — relaunches what must always be running. The counterpart of mac-guard: that one
# stops what's taking the machine down, this one restarts what has disappeared.
#
# A pass every 30 s rather than a KeepAlive per program: launchd knows how to keep an agent
# alive, but that takes one plist per application, and an app installed by hand (or that
# doesn't come from a .app of your own) has none.
#
# Pausing a program without touching the script:
#   touch ~/.local/state/revive.off.alt-tab      # and rm to bring it back
set -u

STATE="$HOME/.local/state"
LOG="$STATE/revive.log"
mkdir -p "$STATE"

# name | pattern searched for in the command line | how to relaunch it
WATCH=(
	"alt-tab|Alt-tab.app/Contents/MacOS/alt-tab|open -a $HOME/Applications/Alt-tab.app --args --agent"
)

for entry in "${WATCH[@]}"; do
	name=${entry%%|*}
	rest=${entry#*|}
	pattern=${rest%%|*}
	command=${rest#*|}

	[ -e "$STATE/revive.off.$name" ] && continue
	pgrep -f "$pattern" >/dev/null 2>&1 && continue

	# Only a relaunch writes: a one-line log every 30 s saying all is well is a log nobody
	# opens.
	printf '%s relaunching %s\n' "$(date '+%F %T')" "$name" >> "$LOG"
	eval "$command" >/dev/null 2>&1
done
