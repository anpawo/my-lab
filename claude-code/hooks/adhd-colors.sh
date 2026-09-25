#!/usr/bin/env bash
# MessageDisplay hook: pastel full-width band under the two i-have-adhd marker lines.
# Both start with "⟶": the very first line of the message is the answer (green), any later one is the next step (blue).
# Ink keeps only SGR codes (cursor moves and \e[K are stripped), so the band is padded with NBSPs
# to the terminal width minus Ink's 2-column indent; markdown markup in the line makes it slightly short, never wrapped.
cols=${COLUMNS:-$(stty size </dev/$(ps -o tty= -p $PPID | tr -d " ") 2>/dev/null | cut -d" " -f2)}; cols=${cols:-80}
jq -c --argjson w "$((cols - 2))" --arg g $'\033[48;2;214;245;214m' --arg b $'\033[48;2;214;230;255m' --arg r $'\033[0m' '
  .index as $i | (.delta // "") | split("\n") | to_entries
  | map(if (.value | startswith("⟶"))
        then (if $i == 0 and .key == 0 then $g else $b end) + .value + (" " * ([$w - (.value | length), 0] | max)) + $r
        else .value end)
  | join("\n")
  | {hookSpecificOutput:{hookEventName:"MessageDisplay",displayContent:.}}'
