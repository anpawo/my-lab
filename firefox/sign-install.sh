#!/bin/sh
# Signs both extensions on AMO (unlisted channel) then opens them in Firefox,
# which offers "Add": the install survives restarts.
# Prerequisite: AMO API key in ~/.web-ext-config.cjs
#   https://addons.mozilla.org/developers/addon/api/key/
# AMO refuses to re-sign an already signed version: bump "version" in manifest.json first.
set -e
out=$HOME/.local/share/firefox-extensions
cd "$(dirname "$0")"
for e in youtube-maxed instagram-unfollow-checker; do
  (cd "$e" && npx --yes web-ext sign --channel unlisted --artifacts-dir "$out" --no-input)
  open -a Firefox "$(ls -t "$out"/*.xpi | head -1)"
done
