# firefox-extension

Two small browser extensions for Firefox and Chrome, no build step and no dependencies.

| Folder | What it does |
|---|---|
| [`youtube-maxed`](youtube-maxed) | Strips Shorts and promo shelves from YouTube, 4 videos per row, fuller titles |
| [`instagram-unfollow-checker`](instagram-unfollow-checker) | Tracks who unfollowed you and who doesn't follow you back |

## Install

### Chrome

1. Open `chrome://extensions`, enable **Developer mode**
2. **Load unpacked**, pick the folder you want

### Firefox

Release Firefox only installs signed add-ons, and temporary ones (about:debugging) vanish
at restart. `./sign-install.sh` signs both on AMO (unlisted channel, nothing public) and
opens the signed `.xpi` in Firefox; if no install prompt shows up, `about:addons` → gear →
**Install Add-on From File…** on the file in `~/.local/share/firefox-extensions/`.

It needs an AMO API key in `~/.web-ext-config.cjs` (`{ sign: { apiKey, apiSecret } }`), from
<https://addons.mozilla.org/developers/addon/api/key/>. AMO refuses to sign a version twice:
bump `version` in `manifest.json` before re-signing.
