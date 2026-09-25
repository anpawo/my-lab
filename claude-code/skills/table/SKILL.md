---
name: table
description: A project's state in a single icon table — ✅ done / 🟠 in progress / ❌ to do or broken. Triggers: "/table", "table todo", "what works and what doesn't", "where are we at", "où on en est", "status table".
---

# table

One markdown table, nothing else. No sentence before, no sentence after, no "next steps".

| Column | Content |
|---|---|
| Item | short name of the piece (file, feature, procedure) |
| Status | `✅` done and verified · `🟠` in progress / not wired up yet / unverified · `❌` to do, broken, or blocked |
| Note | ≤ 8 words: what is missing or what blocks. Empty if ✅ |

Rules:
- Read the real state (files, tests, logs, processes) before writing; never from the conversation's memory alone.
- `✅` only if verified in this session (green test, output seen). Written but never run = `🟠`.
- Sort: ❌ on top, then 🟠, then ✅.
- One row per piece, no sub-tables, no sections. If the user gives a scope (`/table recon-v3`), stick to it.
