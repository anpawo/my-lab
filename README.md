# my-lab

Two small macOS apps I made for my own Mac, too young or too small for a repo of their own.
Both run on my machine today; neither is a demo.

**If you learned something here or took a piece of it home, leave a star.** It is the only
signal I get that any of this was useful to someone else.

| App | What it is |
|---|---|
| [`alt-tab`](alt-tab) | A macOS window switcher that only switches windows: ⌥Tab, one Space, icons and titles. |
| [`screenshot`](screenshot) | A ⌘⇧5 replacement for macOS: the same bar and six modes, the file on disk the moment you click, pins, and an Options menu that saves to several folders at once. |

![mr. screenshot: the bar under an area selection](screenshot/docs/overlay.png)

## Installing

Both are Swift with no Xcode needed: each app's `install.sh` builds it and installs it as a
launchd agent. Each folder has its own README with the steps. Paths are written for macOS on
Apple Silicon.

## License

MIT, see [`LICENSE`](LICENSE). `alt-tab` carries its own copy.
