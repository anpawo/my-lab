#!/bin/sh
# Ends the Claude session this shell runs under, then the login shell above it, so the terminal
# surface closes on its own. Detached in its own session: the tool shell that started us is
# gone by the time the first signal goes out.
pid=$$
while [ "$pid" != 1 ] && [ -n "$pid" ]; do
	case "$(basename -- "$(ps -o comm= -p "$pid")")" in claude) claude=$pid; break ;; esac
	pid=$(ps -o ppid= -p "$pid" | tr -d ' ')
done
[ -n "$claude" ] || { echo "ck: no claude process above pid $$" >&2; exit 1; }
shell=$(ps -o ppid= -p "$claude" | tr -d ' ')

# The Ghostty this surface belongs to, if it is a Ghostty. Closing the last surface of an
# instance does not end it — an app with no window is still an app, the macOS way — and the
# leftover has no window to ⌘-Tab to, so nothing shows it. Click its Dock icon and it opens
# a blank terminal on a fresh prompt: that is where they came from.
term=
up=$shell
n=0
while [ -n "$up" ] && [ "$up" != 1 ] && [ $n -lt 6 ]; do
	case "$(basename -- "$(ps -o comm= -p "$up")")" in ghostty) term=$up; break ;; esac
	up=$(ps -o ppid= -p "$up" | tr -d ' ')
	n=$((n + 1))
done

if [ "$1" = "--dry-run" ]; then
	echo "would TERM claude $claude, then HUP $(ps -o comm= -p "$shell") $shell"
	[ -n "$term" ] && echo "would then quit ghostty $term if it has no surface left"
	exit 0
fi
# The quit is conditional and last: `pgrep -P` lists one child per surface, so an instance
# with another tab or window open still has one and is left alone. Terminal.app and iTerm are
# never quit — they keep the window and say "[Process completed]", which is a window with
# something in it.
/usr/bin/perl -MPOSIX -e 'POSIX::setsid(); exec @ARGV' -- /bin/sh -c "
	sleep 1; kill -TERM $claude; sleep 1; kill -KILL $claude 2>/dev/null; kill -HUP $shell
	[ -n '$term' ] || exit 0
	sleep 2
	[ -z \"\$(pgrep -P $term 2>/dev/null)\" ] && kill -TERM $term
" >/dev/null 2>&1 </dev/null &
