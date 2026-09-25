#!/bin/bash
# revive — rallume ce qui doit toujours tourner. Le pendant de mac-guard : lui arrête ce qui
# emporte la machine, celui-ci relance ce qui a disparu.
#
# Un passage toutes les 30 s plutôt qu'un KeepAlive par programme : launchd sait garder un
# agent vivant, mais il faut alors un plist par application, et une app qu'on installe à la
# main (ou qui ne vient pas d'un .app à soi) n'en a pas.
#
# Mettre un programme en pause sans toucher au script :
#   touch ~/.local/state/revive.off.alt-tab      # et rm pour le remettre
set -u

STATE="$HOME/.local/state"
LOG="$STATE/revive.log"
mkdir -p "$STATE"

# nom | motif cherché dans la ligne de commande | comment le relancer
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

	# Seul un relancement écrit : un log d'une ligne toutes les 30 s pour dire que tout va
	# bien est un log que personne n'ouvre.
	printf '%s relance %s\n' "$(date '+%F %T')" "$name" >> "$LOG"
	eval "$command" >/dev/null 2>&1
done
