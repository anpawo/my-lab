# my-lab

Little apps made for my needs. Each one is a folder at the root of this repo, and each one
runs on my Mac today.

## Using one

```sh
git clone https://github.com/anpawo/my-lab.git && cd my-lab/<app>
./install.sh
```

`install.sh` builds the app, copies it to `~/Applications` and registers a launchd agent so it
starts with your session. All it needs is a Swift toolchain and the Command Line Tools, no
Xcode. Written for macOS on Apple Silicon. MIT, see [`LICENSE`](LICENSE).

**If you took one home, leave a star.** It is the only signal I get that any of this was
useful to someone else.

## The apps

- [alt-tab](alt-tab/README.md): a replacement for the ⌘Tab switcher of macOS, one tile per
  window, each with a picture of itself.
- [screenshot](screenshot/README.md): a ⌘⇧5 replacement, the same bar and six modes, the file
  on disk the moment you click.
