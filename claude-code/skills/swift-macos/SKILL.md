---
name: swift-macos
description: >
  Verified traps of the Swift/macOS toolchain WITHOUT Xcode (Command Line Tools only) and of
  macOS windowing, on this machine. Load as soon as you write, compile, test or sign
  Swift/AppKit/Carbon code, read a window title or geometry, capture the screen, or want
  visual feedback from a GUI app (AppKit, Qt/QML). Projects concerned: alt-tab, vane, fleet,
  video-code. Triggers: "swift test", "codesign", "window title", "titre de fenêtre",
  "screencapture", "open the window to check", "ouvrir la fenêtre pour vérifier",
  "Space"/"desktop"/"bureau", WindowRef, TCC.
---

# Swift & macOS without Xcode — what breaks silently

Xcode is **not** installed, only the Command Line Tools. Everything below follows from that,
and every point was measured here, not read. The common thread: these traps **succeed without
an error** (exit 0, empty output, empty string) and read like a bug in the code you just wrote.

## `swift test` is a silent green, not a run

`swift test` compiles a `.xctest` bundle and **exits 0 without running anything**: XCTest ships
with Xcode, not with the CLT, so nothing loads the bundle. `swift test list` is empty too.
- **Do this:** an `executableTarget` launched with `swift run check`. Zero dependencies,
  headless, fails loudly. Precedent: `app/alt-tab/Sources/check`.
- swift-testing is present (`…/CommandLineTools/…/Testing.framework`) but its **runner** is
  missing — linking it buys nothing.

## `WindowRef` is a Carbon typedef

A target that imports Carbon (`Carbon.HIToolbox`, for `RegisterEventHotKey`) cannot also
define a type named `WindowRef`: Quickdraw still typedefs it, every use becomes "ambiguous
for type lookup". Same trap for the other Quickdraw-era names — rename the local type.

## A window title always costs a TCC authorization

The private path `CGSCopyWindowProperty(cid, wid, "kCGSWindowTitle")` is gated **exactly like**
the public `kCGWindowName` on macOS 26.5: from a signed `.app` with neither Accessibility nor
Screen Recording, it returns `kCGErrorSuccess` and an **empty string** for every window. The
"titles without permission trick" floating around switcher repos is dead here.
- Titles cost Accessibility (`kAXTitleAttribute`) or Screen Recording (`kCGWindowName`) —
  choose **which**, not **whether**. A replayable 60-line C probe lives in `alt-tab`'s history.

## A minimized window changes its AX subrole

A minimized window (or one of a hidden app) answers `kAXSubroleAttribute` = **`AXDialog`**, not
`AXStandardWindow`. The rule "the standard subrole is the whole filter" therefore makes
minimized windows structurally invisible to a switcher, and it looks like AX not reporting them.
It does report them: `kAXWindowsAttribute` lists them, `_AXUIElementGetWindow` gives a valid id,
`CGSCopySpacesForWindows` still gives their Space. They are absent from
`CGWindowListCopyWindowInfo(.optionOnScreenOnly)`; `.optionAll` has them but drowns them among
~80 offscreen surfaces — **AX is the only usable source**. Confirmed on macOS 26.5, Firefox + Swift app.

## Signing triggers GUI dialogs that block a non-interactive shell

`security add-trusted-cert` and the first `codesign` with a fresh identity raise **password
dialogs** that block a non-interactive shell forever. An agent cannot get through; **Marius
has to run `./make-signing-identity.sh` himself**. The identity imports without the trust
step, but `codesign` still prompts.
- Modern OpenSSL's PKCS#12 defaults (AES-256/PBES2) are rejected by `SecKeychainItemImport`:
  `-certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1` + a **non-empty** password required.
  Working script: `app/alt-tab/make-signing-identity.sh`.

## `screencapture` on a locked session renders the wallpaper, without a word

`screencapture -x shot.png` **succeeds** (exit 0, 7.7 MB PNG, no message) with the screen locked.
The file contains only the wallpaper: no windows, no **menu bar** — the missing menu bar is
the only sign. It reads like "empty screen" or "app without a window".
- **Do not conclude "missing permission"**: that reflex is wrong here. Tell them apart in one
  command — `swift -e 'import CoreGraphics; print(CGPreflightScreenCaptureAccess())'` (read-only).
  Lock: `ioreg -n Root -d1 -a | grep -A1 CGSSessionScreenIsLocked`.
- The permission is granted to the terminal's **host app** (walk up `ps -o ppid=,comm=`), not
  to `claude` or `screencapture`.
- Corollary when driving from the phone: the Mac is locked most of the time → **no capture
  possible without unlocking**.

## Do not open a window to check — rendering ≠ displaying

macOS has **no public API** to open a window on a chosen Space.
`NSWindow.collectionBehavior` only knows "on every desktop" or "follow me", never "desktop 3".
Getting there takes private SkyLight/CGS + SIP disabled (which is why yabai injects itself into the Dock).
So **a window opened by an agent lands on the desktop where Marius is working** and interrupts
his work. The hard rule is in `~/.claude/CLAUDE.md` (the "no window for testing" rule); here is
**how** to get pixels without displaying:
- **Qt/QML**: `QQuickWindow::grabWindow()` on a window **created and never shown** returns a
  complete image (measured on video-code: 2880×1800, non-blank). The scene graph draws, the
  compositor is never involved. `QQuickRenderControl` is the documented route if the shortcut fails.
  Trap: `visible:` **and** `visibility:` on an `ApplicationWindow` is a conflict resolved in an
  unspecified order — state visibility with `visibility:` alone.
- **AppKit**: render the view into a bitmap (`bitmapImageRepForCachingDisplay` /
  `cacheDisplay(in:)`) without `makeKeyAndOrderFront`.
- If no windowless path exists for what needs to be seen: **say so and ask**.
