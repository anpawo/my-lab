#!/usr/bin/env bash
# Builds and signs dist/mr. screenshot.app. Does not install: `./install.sh` does.
# Self-signed "Shot Self-Signed" if present (./make-signing-identity.sh), else ad-hoc — and an
# ad-hoc signature loses the Screen Recording grant at every rebuild.
set -euo pipefail
cd "$(dirname "$0")"
APP="dist/mr. screenshot.app"
swift run -c release check
swift build -c release --product screenshot
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/screenshot" "$APP/Contents/MacOS/screenshot"
cp Resources/Info.plist "$APP/Contents/"
# Not a pipe into grep: under pipefail, grep -q closing early makes the whole test fail and
# the build silently falls back to ad-hoc — which is how the Screen Recording grant got lost.
if [[ "$(security find-identity -v -p codesigning)" == *"Shot Self-Signed"* ]]; then
  codesign --force --sign "Shot Self-Signed" "$APP"
else
  codesign --force --sign - "$APP"
fi
echo "==> $APP"
