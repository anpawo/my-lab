#!/bin/bash
# mac-guard — arrête ce qui est en train d'emporter la machine, avant le gel.
#
# Deux détecteurs, un seul processus :
#   A. tempête d'events synthétisés refusés (le gel du 2026-09-22) -> tue le coupable
#   B. mémoire/charge au plancher -> SIGSTOP les plus gros, SIGCONT quand ça repart
#
# SIGSTOP plutôt que kill sur B : réversible, libère le CPU instantanément, ne perd rien.
set -u

STATE="$HOME/.local/state"
LOG="$STATE/mac-guard.log"
STOPPED="$STATE/mac-guard.stopped"
NEVER='WindowServer|launchd|kernel_task|loginwindow|Finder|logd|tccd|trustd|runningboardd|Fleet|claude|ghostty|mac-guard'

STORM_N=${STORM_N:-40}      # events refusés par fenêtre de 10 s avant d'agir
FREE_MIN=${FREE_MIN:-8}     # % de mémoire libre en dessous duquel on stoppe
TICKS=${TICKS:-2}           # ticks consécutifs mauvais avant d'agir (anti-flapping)

note() {
    printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"
    osascript -e "display notification \"$*\" with title \"mac-guard\"" 2>/dev/null
}

# Le message de WindowServer ne nomme pas l'expéditeur. tccd, lui, le nomme : c'est lui
# qu'on interroge pour savoir qui vient de se faire refuser le droit de poster des events.
offender() {
    # Le service demandé est dans la ligne AUTHREQ_CTX, l'identité dans AUTHREQ_ATTRIBUTION :
    # deux lignes distinctes reliées par msgID. Sans cette corrélation on ramasse la dernière
    # requête TCC venue, quelle qu'elle soit — et on tue un innocent.
    log show --last 45s --style compact \
        --predicate 'process == "tccd" AND eventMessage CONTAINS "AUTHREQ_"' 2>/dev/null \
    | awk '
        match($0, /msgID=[0-9]+\.[0-9]+/) {
            id = substr($0, RSTART+6, RLENGTH-6)
            if ($0 ~ /AUTHREQ_CTX/ && match($0, /service=kTCCService[A-Za-z]+/))
                svc[id] = substr($0, RSTART+8, RLENGTH-8)
            else if ($0 ~ /AUTHREQ_ATTRIBUTION/ && match($0, /identifier=[A-Za-z0-9._-]+, pid=[0-9]+/)) {
                who[id] = substr($0, RSTART+11, RLENGTH-11)
                order[++n] = id
            }
        }
        END {
            for (i = n; i >= 1; i--) {
                id = order[i]
                if (svc[id] == "kTCCServicePostEvent" || svc[id] == "kTCCServiceAccessibility") {
                    sub(/, pid=/, " ", who[id]); print who[id]; exit
                }
            }
        }'
}

safe() {   # $1 = pid : vrai si on a le droit d'y toucher
    [ "$1" = "$$" ] && return 1
    [ "$(ps -o pgid= -p "$1" 2>/dev/null | tr -d ' ')" = "$(ps -o pgid= -p $$ | tr -d ' ')" ] && return 1
    local c; c=$(ps -o comm= -p "$1" 2>/dev/null) || return 1
    [ -n "$c" ] || return 1
    printf '%s' "$c" | grep -qE "$NEVER" && return 1
    [ "$(ps -o uid= -p "$1" 2>/dev/null | tr -d ' ')" = "$(id -u)" ]
}

# --- A. tempête d'events synthétisés -----------------------------------------
watch_events() {
    # Lecture bloquante, sans `read -t` : /bin/bash est en 3.2, où un timeout et une fin de
    # flux rendent tous deux 1 — impossible de distinguer "rien n'arrive" de "le flux est
    # mort". Une vraie tempête envoie 60 à 100 lignes/s, donc la fenêtre se referme sur
    # l'arrivée de la ligne suivante ; et une tempête qui s'arrête d'elle-même n'a plus
    # personne à tuer. Une fin de flux sort de la boucle et le flux est repris.
    while :; do
        local count=0 window=$SECONDS name pid busy
        while IFS= read -r _; do
            count=$((count + 1))
            [ $((SECONDS - window)) -ge 10 ] || continue
            if [ "$count" -ge "$STORM_N" ]; then
                read -r name pid < <(offender)
                # Demander le droit récemment ne fait pas de vous le coupable. Celui qui
                # boucle sur des refus brûle du CPU : sans ça, on ne tue personne.
                busy=0
                [ -n "${pid:-}" ] && busy=$(ps -o %cpu= -p "$pid" 2>/dev/null | tr -d ' ' | cut -d. -f1)
                if [ -n "${pid:-}" ] && [ "${busy:-0}" -ge 20 ] && safe "$pid"; then
                    kill -9 "$pid" 2>/dev/null \
                        && note "tué $name (pid $pid) — $count events refusés en 10 s"
                else
                    note "tempête d'events ($count/10 s) — ${name:-coupable} non confirmé (cpu ${busy:-?}%), rien tué"
                fi
            fi
            count=0; window=$SECONDS
        done < <(${STREAM:-stream_refusals})
        [ -n "${STREAM:-}" ] && return 0     # en test, un seul passage
        sleep 5                               # flux tombé : on le reprend
    done
}

stream_refusals() {
    log stream --style compact \
        --predicate 'eventMessage CONTAINS "prohibited from synthesizing"' 2>/dev/null
}

# --- B. mémoire au plancher ---------------------------------------------------
resume_all() {
    [ -s "$STOPPED" ] || return 0
    while read -r p; do kill -CONT "$p" 2>/dev/null; done < "$STOPPED"
    note "reprise de $(wc -l < "$STOPPED" | tr -d ' ') processus"
    : > "$STOPPED"
}

watch_memory() {
    local bad=0 free lvl
    : > "$STOPPED"
    while :; do
        free=$(memory_pressure -Q 2>/dev/null | sed -n 's/.*free percentage: \([0-9]*\)%.*/\1/p')
        lvl=$(sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null)
        if [ "${free:-100}" -lt "$FREE_MIN" ] || [ "${lvl:-1}" -ge 4 ]; then
            bad=$((bad + 1))
        else
            [ "$bad" -gt 0 ] && resume_all
            bad=0
        fi
        if [ "$bad" -ge "$TICKS" ]; then
            ps -eo pid=,rss=,comm= -m | head -40 | while read -r pid rss comm; do
                [ "$(wc -l < "$STOPPED" | tr -d ' ')" -ge 3 ] && break
                safe "$pid" || continue
                kill -STOP "$pid" 2>/dev/null || continue
                echo "$pid" >> "$STOPPED"
                note "stoppé $(basename "$comm") (pid $pid, $((rss / 1024)) Mo) — mémoire libre ${free}%"
            done
            bad=0
        fi
        sleep 10
    done
}

# --- autotest : la logique sans rien tuer ------------------------------------
# Rejoue la signature du 2026-09-22 : 50 refus d'affilée, sans toucher au vrai flux.
if [ "${1:-}" = "--storm-test" ]; then
    LOG="${2:-/dev/stdout}"
    fake() { i=0; while [ $i -lt 130 ]; do echo "Sender is prohibited from synthesizing events"; i=$((i+1)); sleep 0.1; done; }
    STORM_N=40 STREAM=fake watch_events &
    w=$!; sleep 13; kill $w 2>/dev/null
    exit 0
fi

if [ "${1:-}" = "--selftest" ]; then
    fail=0
    safe 1 && { echo "FAIL: launchd (pid 1) jugé touchable"; fail=1; }
    safe $$ && { echo "FAIL: mac-guard lui-même jugé touchable"; fail=1; }
    # propre groupe de processus : un enfant du garde partage son pgid et doit rester
    # intouchable, ce qui ne dirait rien de la logique pour un vrai gourmand.
    perl -e 'setpgrp; exec "sleep", "300"' & victim=$!
    sleep 0.3
    safe "$victim" || { echo "FAIL: un sleep hors de mon groupe jugé intouchable"; fail=1; }
    sleep 300 >/dev/null 2>&1 & child=$!
    safe "$child" && { echo "FAIL: un enfant du garde jugé touchable"; fail=1; }
    kill -9 "$child" 2>/dev/null
    kill -STOP "$victim" 2>/dev/null
    [ "$(ps -o state= -p $victim | cut -c1)" = "T" ] || { echo "FAIL: SIGSTOP sans effet"; fail=1; }
    kill -CONT "$victim" 2>/dev/null; kill -9 "$victim" 2>/dev/null
    o=$(offender)
    if [ -n "$o" ]; then
        set -- $o
        log show --last 2m --style compact --predicate 'process == "tccd"' 2>/dev/null \
            | grep -q "identifier=$1" || { echo "FAIL: offender() a inventé $1"; fail=1; }
        echo "ok: offender() -> $o (corrélé PostEvent/Accessibility)"
    else
        echo "ok: offender() vide — aucun refus PostEvent récent"
    fi
    [ "$fail" = 0 ] && echo "SELFTEST OK" || { echo "SELFTEST ÉCHOUÉ"; exit 1; }
    exit 0
fi

note "démarré (storm>=$STORM_N/10s, mémoire libre <$FREE_MIN%)"
trap 'resume_all; exit 0' TERM INT
watch_events &
watch_memory &
wait
