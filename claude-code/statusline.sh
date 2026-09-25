#!/usr/bin/env bash
input=$(cat)

# Tout à gauche : un bloc rouge tant que le dernier prompt tapé a été coupé par Fleet
# (le tampon `.stopped` du hook est plus récent que le tampon `.prompted`). Il disparaît
# au prochain prompt, qui remet `.prompted` à jour.
sid=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)
stopmark=""
if [[ -n "$sid" && -f "$HOME/.claude/fleet/state/$sid.stopped" ]]; then
  stopped=$(cat "$HOME/.claude/fleet/state/$sid.stopped" 2>/dev/null || echo 0)
  prompted=$(cat "$HOME/.claude/fleet/state/$sid.prompted" 2>/dev/null || echo 0)
  [[ "${stopped:-0}" -gt "${prompted:-0}" ]] && stopmark=$'\033[48;5;196m\033[97;1m STOPPED \033[0m '
fi

# Fleet a élu une session par groupe — celle que les autres nomment comme l'auteur de leur
# brief — et écrit leurs ids là. Le dire ici parce que c'est le seul écran qu'on regarde quand
# on est dedans : une session ne sait pas autrement qu'elle est la main de son dossier.
if [[ -n "$sid" ]]; then
  group=$(awk -v s="$sid" '$1 == s { print $2; exit }' "$HOME/.claude/fleet/state/heads" 2>/dev/null)
fi

# Colors — one distinct hue per segment, 256-color so the segments stay
# distinguishable. Separators are dim so the data reads louder than the chrome.
DIR='\033[38;5;62m'    # periwinkle — matches the file-path blue in transcript output
MODEL='\033[38;5;129m' # deep violet
CTX='\033[38;5;34m'    # grass green
DIM='\033[38;5;240m'   # separators only
R='\033[0m'            # reset
SEP="${DIM}|${R}"

# Usage-bar hues, picked by headroom rather than by segment.
OK='\033[38;5;62m'     # periwinkle — same blue as the path
WARN='\033[38;5;179m'  # soft amber
CRIT='\033[38;5;168m'  # dusty rose
AGENT='\033[38;5;215m' # abricot — les agents en cours, distinct des barres d'usage

# Git-state hues, ordered by how much work exists in only one place.
SYNCED='\033[38;5;71m'  # green — committed and pushed, nothing to lose
UNPUSH='\033[38;5;179m' # amber — committed, but the remote doesn't have it
UNCOMM='\033[38;5;168m' # rose — uncommitted, exists only in this working tree
PAREN='\033[38;5;16m'  # black — the " - " separators

# Current directory — the session's cwd, which follows a mid-session `cd`.
# Falls back through the older payload shapes, then to $PWD.
dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // .workspace.project_dir // empty' 2>/dev/null)
[[ -z "$dir" ]] && dir="$PWD"
repo="$dir"            # keep the real path; $dir gets tilde-shortened for display
dir="${dir/#$HOME/~}"

# Sous ~/self, le nom du projet suffit : tout le reste du chemin est du bruit commun.
case "$dir" in '~/self/'*) dir="${dir#'~/self/'}"; dir="${dir%%/*}";; esac

# Un suffixe sur le dossier, rien de plus : « projet - fleet head ».
[[ -n "$group" ]] && dir="$dir ${PAREN}-${DIR} fleet head"

# Last segment, answering the two questions I'd otherwise stop and run `git status` for:
# is anything uncommitted, and is anything unpushed. Worst state wins, so it only reads
# "up to date" when both are clean. A detached HEAD has nothing to push: no word unless dirty.
# Note the ahead-count is measured against the last-fetched upstream, not the live
# remote — this says "I haven't pushed", not "the remote has moved on".
if git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$repo" branch --show-current 2>/dev/null)
  [[ -z "$branch" ]] && branch="detached $(git -C "$repo" rev-parse --short HEAD 2>/dev/null)"
  word=""
  if [[ -n $(git -C "$repo" status --porcelain 2>/dev/null | head -n1) ]]; then
    col=$UNCOMM; word="uncommitted"
  elif [[ "$branch" == detached* ]]; then
    col=$DIM
  elif ! git -C "$repo" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    col=$DIM; word="local only"
  elif [[ $(git -C "$repo" rev-list --count '@{u}..HEAD' 2>/dev/null) != 0 ]]; then
    col=$UNPUSH; word="unpushed"
  else
    col=$SYNCED; word="up to date"
  fi
  git_seg=" ${SEP} ${col}@${branch}${word:+ ${PAREN}-${col} $word}${R}"
else
  git_seg=" ${SEP} ${DIM}not a repo${R}"
fi

# Model: already formatted as "Sonnet 4.6", suivi du niveau d'effort (.effort.level :
# low / medium / high / xhigh / max), absent des vieilles versions du CLI.
model=$(echo "$input" | jq -r '.model.display_name // .model // "?"' 2>/dev/null)
model=${model%% (*}
effort=$(echo "$input" | jq -r '.effort.level // empty' 2>/dev/null)
[[ -n "$effort" ]] && model="${model} ${PAREN}-${MODEL} ${effort}"

# Mode de permission, à gauche du modèle, même rouge et mêmes mots que la ligne de pied de page
# que le patch binaire retire. Le payload ne le porte pas ; le journal de session
# écrit une ligne `permission-mode` à chaque prompt, on prend la dernière. Un shift+tab entre
# deux prompts n'apparaît donc qu'au prompt suivant.
MODE_BYPASS='\033[38;2;171;43;63m' # le rouge exact de la ligne « bypass permissions on » de Claude Code
MODE_EDIT='\033[38;5;179m'   # ambre
MODE_PLAN='\033[38;5;62m'    # pervenche
tp=$(echo "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
mode_seg=""
# Le binaire patché (bullet-band.py) écrit le mode dans ~/.claude/sessions/<pid>.mode dès qu'il
# change ; le transcript ne l'écrit qu'au prompt suivant. Fichier d'abord, transcript en secours.
pm=$(cat "$HOME/.claude/sessions/${CLAUDE_PID:-$PPID}.mode" 2>/dev/null)
if [[ -z "$pm" && -r "$tp" ]]; then
  pm=$(tail -c 200000 "$tp" 2>/dev/null | grep -oE '"type":"permission-mode","permissionMode":"[A-Za-z]+"' | tail -1)
  pm=${pm##*:\"}; pm=${pm%\"}
fi
if [[ -n "$pm" ]]; then
  case "$pm" in
    bypassPermissions) mode_seg="${MODE_BYPASS}⏵⏵ bypass permissions on${R}";;
    dontAsk)           mode_seg="${MODE_BYPASS}⏵⏵ don't ask on${R}";;
    acceptEdits)       mode_seg="${MODE_EDIT}⏵⏵ accept edits on${R}";;
    auto)              mode_seg="${MODE_EDIT}auto mode on${R}";;
    plan)              mode_seg="${MODE_PLAN}plan mode on${R}";;
  esac
  [[ -n "$mode_seg" ]] && mode_seg="${mode_seg} ${SEP} "
fi

# Context fill as "4% 1M" — percentage of the window plus the window size. The raw
# token count is dropped: it's the same measurement the percentage already states.
read -r ctx_pct total < <(echo "$input" | jq -r '
  def human:
    if   . >= 1000000 then (. / 1000000 * 10 | round / 10 | tostring + "M")
    elif . >= 1000    then (. / 1000 | round | tostring + "k")
    else tostring end;
  [ (.context_window.used_percentage // 0 | round),
    (.context_window.context_window_size // 0 | human) ] | @tsv
' 2>/dev/null)
[[ -z "$ctx_pct" || "$ctx_pct" == "null" ]] && ctx_pct="0"
[[ -z "$total"   || "$total"   == "null" ]] && total="?"

# Plan usage limits (Claude.ai subscription windows), refreshed on every status line run.
# five_hour = current session window, seven_day = weekly "all models" bar.
# The percentages arrive as floats (e.g. 14.000000000000002), so round them here —
# bash arithmetic can't compare a decimal, so an unrounded value breaks the > 90 tests
# as well as printing an absurd number of digits.
read -r fh_pct fh_reset sd_pct sd_reset < <(echo "$input" | jq -r '
  def pct: if . == null then "-" else round end;
  [ (.rate_limits.five_hour.used_percentage  | pct),
    (.rate_limits.five_hour.resets_at        // 0),
    (.rate_limits.seven_day.used_percentage  | pct),
    (.rate_limits.seven_day.resets_at        // 0) ] | @tsv
' 2>/dev/null)

# Compact "2h50m" / "45m" countdown from an epoch reset timestamp.
countdown() {
  local left=$(( $1 - $(date +%s) ))
  (( left <= 0 )) && { echo "now"; return; }
  if (( left >= 3600 )); then
    local h=$(( left / 3600 )) m=$(( (left % 3600) / 60 ))
    # Drop a zero minutes component so a whole-hour reset reads "5h", not "5h0m".
    (( m == 0 )) && echo "${h}h" || echo "${h}h${m}m"
  else echo "$(( left / 60 ))m"; fi
}

# Colour the usage bars by headroom: green < 60%, amber < 85%, red beyond.
usage_color() {
  if [[ "$1" == "-" ]]; then echo "$DIM"
  elif (( $1 >= 85 )); then echo "$CRIT"
  elif (( $1 >= 60 )); then echo "$WARN"
  else echo "$OK"; fi
}

limits=""
if [[ -n "$fh_pct" && "$fh_pct" != "-" ]]; then
  fh_col=$(usage_color "$fh_pct")
  limits=" ${SEP} ${fh_col}${fh_pct}% usage ${PAREN}-${fh_col} reset $(countdown "$fh_reset")${R}"
elif [[ -n "$sd_pct" && "$sd_pct" != "-" ]]; then
  # Claude Code retire `five_hour` dès que sa fenêtre est passée sans nouvelle réponse
  # (0 % de fait) : la semaine tient la barre en attendant, plutôt qu'un « loading » sans fin.
  sd_col=$(usage_color "$sd_pct")
  limits=" ${SEP} ${sd_col}${sd_pct}% wk ${PAREN}-${sd_col} reset $(countdown "$sd_reset")${R}"
else
  # Les limites arrivent quelques secondes après le lancement : un « loading » qui avance à
  # chaque rafraîchissement, sur une largeur fixe pour que la ligne ne bouge pas.
  dots=$(( $(date +%s) % 3 + 1 ))
  limits=" ${SEP} ${OK}$(printf 'loading usage%-3s' "$(printf '.%.0s' $(seq 1 $dots))")${R}"
fi
# The weekly bar is noise until it's nearly spent — surface it only past 90%,
# and always in the alert colour, since by then it's the binding constraint.
if [[ -n "$fh_pct" && "$fh_pct" != "-" && -n "$sd_pct" && "$sd_pct" != "-" ]] && (( sd_pct > 90 )); then
  limits+=" ${SEP} ${CRIT}${sd_pct}% wk${R}"
fi


# Agents en cours, lus dans le journal de session. Le payload ne porte pas
# l'information mais il donne `transcript_path`, et le journal contient un
# tool_use "Agent" au lancement puis un tool_result au retour : ce qui reste
# sans resultat tourne encore.
#
# Trois filtres en flux, jamais de contenu dans une variable bash — 4 Mo dans
# un `<<<` coutent 1,7 s, la meme donnee en flux 100 ms. On ne lit que la fin
# du journal : un agent encore actif a forcement ete lance recemment.
FENETRE_AGENTS=1000000
agents=""
if [[ -r "$tp" ]]; then
  liste=$(tail -c "$FENETRE_AGENTS" "$tp" 2>/dev/null \
    | grep -oE '"id":"toolu_[A-Za-z0-9]+","name":"Agent","input":\{"description":"[^"]*"|"tool_use_id":"toolu_[A-Za-z0-9]+"' \
    | awk '
      /"name":"Agent"/ {
        id = $0; sub(/^"id":"/, "", id); sub(/".*/, "", id)
        d  = $0; sub(/.*"description":"/, "", d); sub(/"$/, "", d)
        nom[id] = d; ordre[++n] = id; next
      }
      { id = $0; sub(/^"tool_use_id":"/, "", id); sub(/"$/, "", id); fini[id] = 1 }
      END {
        for (i = 1; i <= n; i++) if (!(ordre[i] in fini)) liste[++k] = nom[ordre[i]]
        if (k == 0) exit
        printf "%d agent%s: ", k, (k > 1 ? "s" : "")
        for (i = 1; i <= k; i++) printf "%s%s", (i > 1 ? ", " : ""), liste[i]
      }')
  [[ -n "$liste" ]] && agents=" ${SEP} ${AGENT}${liste}${R}"
fi

echo -e "${stopmark}${DIR}${dir}${R} ${SEP} ${mode_seg}${MODEL}${model}${R} ${SEP} ${CTX}${ctx_pct}% token ${PAREN}-${CTX} ${total}${R}${limits}${agents}${git_seg}"
