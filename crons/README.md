# crons

launchd jobs. Each folder holds the plist and the script it runs; the plist references the
script at `~/.local/bin/<name>.sh`, so install is:

```sh
cp <job>/<name>.sh ~/.local/bin/ && chmod +x ~/.local/bin/<name>.sh
cp <job>/fr.marius.<name>.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/fr.marius.<name>.plist
```

| Job | What it does |
|---|---|
| `revive` | Every 30 s, relaunches the programs listed in its `WATCH` table if they are gone (today: alt-tab). One script instead of a `KeepAlive` plist per app, which a hand-installed app does not have. `touch ~/.local/state/revive.off.<name>` pauses one entry. |
| `mac-guard` | Stops what is taking the machine down before it freezes: a storm of refused synthetic events gets its sender killed, and memory or load at the floor gets the biggest processes `SIGSTOP`ped, then `SIGCONT`ed when it recovers. Reversible by design. Runs as `Interactive` so it can notify. |

Both log to `~/.local/state/<name>.log` and send errors to `~/.local/state/<name>.err`. Read the script before installing it:
each one names what it kills or restarts.
