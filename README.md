# my-lab

Things I build and tune for my own Mac, kept in one public place: a window switcher, the
scripts and launchd jobs that keep the machine honest, my Claude Code customisations, two
Firefox extensions, and the dotfiles behind my terminal. Everything here runs on my machine
today; nothing is a demo.

**If you learned something here or took a piece of it home, leave a star.** It is the only
signal I get that any of this was useful to someone else.

## Map

| Folder | What is in it |
|---|---|
| [`app/`](app) | Apps too young or too small for a repo of their own. `alt-tab`: a macOS window switcher that only switches windows (⌥Tab, one Space, icons and titles). |
| [`bin/`](bin) | Commands I type by hand. `mem` (what is eating memory), `online` (run a command once the network is back, for cron jobs started without Wi-Fi). |
| [`crons/`](crons) | launchd jobs, each folder holding the plist and the script it runs. `revive` restarts what died, `mac-guard` watches the machine's health. |
| [`claude-code/`](claude-code) | How my Claude Code looks and behaves: a `MessageDisplay` hook that paints the answer and next-step lines, a patcher for the binary itself, a status line, a theme, skills. Its README explains how the Bun binary is laid out and patched. |
| [`firefox/`](firefox) | Two extensions with no build step, and the script that signs them on Mozilla's add-on server so release Firefox accepts them. |
| [`dotfiles/`](dotfiles) | Ghostty, fish, zprofile, gitconfig, global gitignore. |

## Installing a piece

Each folder has its own README with the copy-and-run steps. Nothing installs itself: every
script is meant to be read before it is copied into `~/.local/bin` or `~/Library/LaunchAgents`.
Paths are written for macOS on Apple Silicon with Homebrew under `/opt/homebrew`.

## What is deliberately not here

No credentials, no exported app data, no work tooling, and nothing that profiles a person:
the `.gitignore` refuses the usual filenames, and each file was read before it was added.
The private half of my setup (the full machine inventory and the work jobs) lives elsewhere.

## License

MIT for everything I wrote, see [`LICENSE`](LICENSE). `app/alt-tab` carries its own copy.
