#!/usr/bin/env bash
# Builds, installs to ~/Applications, and starts it. Keeping it running is revive's job.
set -euo pipefail

cd "$(dirname "$0")"

DEST="$HOME/Applications/Alt-tab.app"

# The one build path; --arch native because this machine is the only one that will run it.
python3 build.py --arch native

echo "==> Installing to $DEST"
mkdir -p "$HOME/Applications"
pkill -f "Alt-tab.app/Contents/MacOS/alt-tab" 2>/dev/null || true
rm -rf "$DEST"
cp -R dist/Alt-tab.app "$DEST"

echo "==> Starting"
# No LaunchAgent of its own any more: `revive` (fr.marius.revive) checks every 30 s that the
# programs that must always be running are, and restarts the ones that are not — alt-tab is
# one line in its list. One plist for all of them rather than one per app.
open -a "$DEST" --args --agent

echo
echo "Installed, and invisible: no Dock icon and nothing in the menu bar."
echo
echo "Hold ⌥ and press Tab to switch windows; Escape cancels. With ⌥ still held,"
echo "click a tile to switch to it, or the red cross on its picture to close it."
echo "⌥Tab rather than ⌘Tab so the system switcher is still there to compare with;"
echo "open the app to change it, and for everything else it can be told to do."
echo
echo "The first time you commit a switch, macOS will ask for Accessibility."
echo "Until it is granted the panel lists applications without window names,"
echo "and cannot raise anything: System Settings → Privacy & Security → Accessibility."
echo
echo "  See what it sees:  $DEST/Contents/MacOS/alt-tab --render"
echo "  Logs:              ~/Library/Logs/alt-tab.log"
echo "  Uninstall:         ./uninstall.sh"
