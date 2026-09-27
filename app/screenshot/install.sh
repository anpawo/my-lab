#!/usr/bin/env bash
# Builds, copies to ~/Applications, and registers a LaunchAgent: it starts at login and comes
# back if anything kills it. Not `open -a`: an app opened from a Claude Code session inherits
# its CLAUDE_PID, and Fleet reaps it as a leftover once that session ends — which is how it kept
# "closing itself" (SIGTERM sent by Fleet, 27-09).
set -euo pipefail
cd "$(dirname "$0")"
./build.sh
LABEL="com.mr.screenshot"
DEST="$HOME/Applications/mr. screenshot.app"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
launchctl bootout "gui/$UID/$LABEL" 2>/dev/null || true
pkill -f "mr. screenshot.app/Contents/MacOS/screenshot" 2>/dev/null || true
rm -rf "$DEST"; mkdir -p "$HOME/Applications"; cp -R "dist/mr. screenshot.app" "$DEST"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>$DEST/Contents/MacOS/screenshot</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>ProcessType</key>
	<string>Interactive</string>
	<key>StandardErrorPath</key>
	<string>/tmp/screenshot.log</string>
</dict>
</plist>
EOF
launchctl bootstrap "gui/$UID" "$PLIST"
echo "⌘⇧5 opens the bar — turn the system's ⌘⇧5 off first: Settings → Keyboard → Shortcuts → Screenshots."
