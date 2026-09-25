# instagram-unfollow-checker

Answers three questions about your Instagram account, from a toolbar button:

- Who **unfollowed you** since the last scan
- Who **you follow that doesn't follow you back**
- Who **follows you that you don't follow back**

Accounts with 10k+ followers are listed separately — following a creator without a
follow back is normal, and mixing them in buries the names that actually matter.

## Use

Open Instagram, click the toolbar icon, hit **Scan**. The first scan only
saves a baseline; every scan after that shows the diff.

The scan runs in the content script, so closing the popup or switching windows
doesn't stop it. A system notification fires when it lands. The Instagram tab has to
stay open — it carries the session cookies.

## How it works

| File | Role |
|---|---|
| `scan.js` | content script; calls Instagram's own web API from the page, computes the diffs, stores |
| `bg.js` | fires the system notification |
| `popup.js` | button and rendering, reads `storage.local` |
| `diff.js` | set difference |
| `check.js` | `node check.js` — self-check for `diff` |

No DOM scraping: the followers modal only loads what you scroll, so the extension calls
`/api/v1/friendships/<id>/followers/` the way the web app itself does, paging 50 at a
time with a 400 ms gap. Follower counts need one `/users/<pk>/info/` request per account,
so they're only fetched for the cross list (capped at 100), never for your whole graph.

Snapshots live in `browser.storage.local`. One snapshot is kept; each scan replaces it.

## Tuning

- `CREATOR` in `scan.js` — the 10k threshold
- `LOOKUP_CAP` in `scan.js` — max follower-count lookups per scan
- `APP_ID` in `scan.js` — Instagram's public web app id, hardcoded; read it from the
  page HTML if Instagram ever rotates it
