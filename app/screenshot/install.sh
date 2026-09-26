#!/usr/bin/env bash
# Builds, copies to ~/Applications, starts it.
set -euo pipefail
cd "$(dirname "$0")"
./build.sh
DEST="$HOME/Applications/mr. screenshot.app"
pkill -f "mr. screenshot.app/Contents/MacOS/screenshot" 2>/dev/null || true
rm -rf "$DEST"; mkdir -p "$HOME/Applications"; cp -R "dist/mr. screenshot.app" "$DEST"
open -a "$DEST"
echo "⌘⇧5 opens the bar — turn the system's ⌘⇧5 off first: Settings → Keyboard → Shortcuts → Screenshots."
