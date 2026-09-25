# bin

| Command | What it does |
|---|---|
| `mem` | The five processes eating the most memory, with an option to kill one. |
| `online <cmd> [args…]` | Waits for the network (up to `ONLINE_WAIT` seconds, default 20 min), then runs the command. Meant as a prefix in launchd jobs: a job that starts without Wi-Fi is postponed instead of failing. Exits 0 when it gives up, so the job reads as "skipped", not "broken". |

Install: copy into `~/.local/bin` and `chmod +x`.
