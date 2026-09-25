#!/bin/bash
# mac-guard — stops whatever is taking the machine down, before the freeze.
#
# Two detectors, one process:
#   A. storm of refused synthesized events (the 2026-09-22 freeze) -> kills the culprit
#   B. memory/load at the floor -> SIGSTOP the biggest ones, SIGCONT once it recovers
#
# SIGSTOP rather than kill for B: reversible, frees the CPU instantly, loses nothing.
set -u

STATE="$HOME/.local/state"
LOG="$STATE/mac-guard.log"
STOPPED="$STATE/mac-guard.stopped"
NEVER='WindowServer|launchd|kernel_task|loginwindow|Finder|logd|tccd|trustd|runningboardd|Fleet|claude|ghostty|mac-guard'

STORM_N=${STORM_N:-40}      # refused events per 10 s window before acting
FREE_MIN=${FREE_MIN:-8}     # % free memory below which we start stopping
TICKS=${TICKS:-2}           # consecutive bad ticks before acting (anti-flapping)

note() {
    printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"
    osascript -e "display notification \"$*\" with title \"mac-guard\"" 2>/dev/null
}

# WindowServer's message doesn't name the sender. tccd does: it's the one we query to find
# out who just got refused the right to post events.
offender() {
    # The requested service is on the AUTHREQ_CTX line, the identity on AUTHREQ_ATTRIBUTION:
    # two separate lines linked by msgID. Without that correlation we pick up the latest TCC
    # request to come in, whatever it is — and kill an innocent.
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

safe() {   # $1 = pid: true if we're allowed to touch it
    [ "$1" = "$$" ] && return 1
    [ "$(ps -o pgid= -p "$1" 2>/dev/null | tr -d ' ')" = "$(ps -o pgid= -p $$ | tr -d ' ')" ] && return 1
    local c; c=$(ps -o comm= -p "$1" 2>/dev/null) || return 1
    [ -n "$c" ] || return 1
    printf '%s' "$c" | grep -qE "$NEVER" && return 1
    [ "$(ps -o uid= -p "$1" 2>/dev/null | tr -d ' ')" = "$(id -u)" ]
}

# --- A. storm of synthesized events ------------------------------------------
watch_events() {
    # Blocking read, no `read -t`: /bin/bash is 3.2, where a timeout and an end of stream
    # both return 1 — no way to tell "nothing is coming" from "the stream is dead". A real
    # storm sends 60 to 100 lines/s, so the window closes on the arrival of the next line;
    # and a storm that stops on its own leaves nobody to kill. An end of stream exits the
    # loop and the stream is picked up again.
    while :; do
        local count=0 window=$SECONDS name pid busy
        while IFS= read -r _; do
            count=$((count + 1))
            [ $((SECONDS - window)) -ge 10 ] || continue
            if [ "$count" -ge "$STORM_N" ]; then
                read -r name pid < <(offender)
                # Having asked for the right recently doesn't make you the culprit. The one
                # looping on refusals burns CPU: without that, we kill nobody.
                busy=0
                [ -n "${pid:-}" ] && busy=$(ps -o %cpu= -p "$pid" 2>/dev/null | tr -d ' ' | cut -d. -f1)
                if [ -n "${pid:-}" ] && [ "${busy:-0}" -ge 20 ] && safe "$pid"; then
                    kill -9 "$pid" 2>/dev/null \
                        && note "killed $name (pid $pid) — $count refused events in 10 s"
                else
                    note "event storm ($count/10 s) — ${name:-culprit} not confirmed (cpu ${busy:-?}%), nothing killed"
                fi
            fi
            count=0; window=$SECONDS
        done < <(${STREAM:-stream_refusals})
        [ -n "${STREAM:-}" ] && return 0     # under test, a single pass
        sleep 5                               # stream dropped: pick it up again
    done
}

stream_refusals() {
    log stream --style compact \
        --predicate 'eventMessage CONTAINS "prohibited from synthesizing"' 2>/dev/null
}

# --- B. memory at the floor ---------------------------------------------------
resume_all() {
    [ -s "$STOPPED" ] || return 0
    while read -r p; do kill -CONT "$p" 2>/dev/null; done < "$STOPPED"
    note "resumed $(wc -l < "$STOPPED" | tr -d ' ') processes"
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
                note "stopped $(basename "$comm") (pid $pid, $((rss / 1024)) MB) — free memory ${free}%"
            done
            bad=0
        fi
        sleep 10
    done
}

# --- self-test: the logic without killing anything ---------------------------
# Replays the 2026-09-22 signature: 50 refusals in a row, without touching the real stream.
if [ "${1:-}" = "--storm-test" ]; then
    LOG="${2:-/dev/stdout}"
    fake() { i=0; while [ $i -lt 130 ]; do echo "Sender is prohibited from synthesizing events"; i=$((i+1)); sleep 0.1; done; }
    STORM_N=40 STREAM=fake watch_events &
    w=$!; sleep 13; kill $w 2>/dev/null
    exit 0
fi

if [ "${1:-}" = "--selftest" ]; then
    fail=0
    safe 1 && { echo "FAIL: launchd (pid 1) deemed touchable"; fail=1; }
    safe $$ && { echo "FAIL: mac-guard itself deemed touchable"; fail=1; }
    # own process group: a child of the guard shares its pgid and must stay untouchable,
    # which would say nothing about the logic for a real hog.
    perl -e 'setpgrp; exec "sleep", "300"' & victim=$!
    sleep 0.3
    safe "$victim" || { echo "FAIL: a sleep outside my group deemed untouchable"; fail=1; }
    sleep 300 >/dev/null 2>&1 & child=$!
    safe "$child" && { echo "FAIL: a child of the guard deemed touchable"; fail=1; }
    kill -9 "$child" 2>/dev/null
    kill -STOP "$victim" 2>/dev/null
    [ "$(ps -o state= -p $victim | cut -c1)" = "T" ] || { echo "FAIL: SIGSTOP had no effect"; fail=1; }
    kill -CONT "$victim" 2>/dev/null; kill -9 "$victim" 2>/dev/null
    o=$(offender)
    if [ -n "$o" ]; then
        set -- $o
        log show --last 2m --style compact --predicate 'process == "tccd"' 2>/dev/null \
            | grep -q "identifier=$1" || { echo "FAIL: offender() made up $1"; fail=1; }
        echo "ok: offender() -> $o (correlated PostEvent/Accessibility)"
    else
        echo "ok: offender() empty — no recent PostEvent refusal"
    fi
    [ "$fail" = 0 ] && echo "SELFTEST OK" || { echo "SELFTEST FAILED"; exit 1; }
    exit 0
fi

note "started (storm>=$STORM_N/10s, free memory <$FREE_MIN%)"
trap 'resume_all; exit 0' TERM INT
watch_events &
watch_memory &
wait
