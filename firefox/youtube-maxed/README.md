# youtube-maxed

Declutters the YouTube web UI. Pure CSS plus ~15 lines of JS.

| Change | Where |
|---|---|
| Shorts shelves gone (home, search, channels, grid items) | `hide.css` |
| "Get more from memberships" and "new content labels" cards gone | `hide.js` |
| 4 videos per row instead of 3 | `hide.css` — `--ytd-rich-grid-items-per-row` |
| Titles on 3 lines instead of 2 | `hide.css` — `-webkit-line-clamp` |

## Notes

- Shorts are hidden with CSS only: YouTube rebuilds its DOM constantly, and a
  `display: none` survives that without a MutationObserver.
- The membership and content-label cards carry no distinguishing attribute — only
  their text identifies them — so those need JS. The regex lives at the top of `hide.js`;
  add a pattern there when a new promo shelf shows up.
- YouTube renames its CSS classes regularly. If titles clamp back to 2 lines, grep the
  live stylesheet for `line-clamp` and update the selector.
