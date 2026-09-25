#!/bin/sh
# Signe les deux extensions sur AMO (canal unlisted) puis les ouvre dans Firefox,
# qui propose "Ajouter" : l'installation survit aux redémarrages.
# Prérequis : clé API AMO dans ~/.web-ext-config.cjs
#   https://addons.mozilla.org/developers/addon/api/key/
# AMO refuse de re-signer une version déjà signée : bumper "version" dans manifest.json avant.
set -e
out=$HOME/.local/share/firefox-extensions
cd "$(dirname "$0")"
for e in youtube-maxed instagram-unfollow-checker; do
  (cd "$e" && npx --yes web-ext sign --channel unlisted --artifacts-dir "$out" --no-input)
  open -a Firefox "$(ls -t "$out"/*.xpi | head -1)"
done
