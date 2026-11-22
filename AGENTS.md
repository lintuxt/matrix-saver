# AGENTS.md

Instructions for AI agents (Claude Code, Codex, Cursor and similar) asked to
install MatrixSaver for a user. For changing the code, see
[docs/development.md](docs/development.md).

MatrixSaver is a macOS screen saver. Installing it needs no `sudo`, no
interactive prompts and no Xcode. It only writes inside the user's home folder.

<br>

## 1. Check the machine

```sh
uname -s                 # must print: Darwin
sw_vers -productVersion  # major version must be 14 or higher
```

If either check fails, stop and tell the user MatrixSaver requires macOS 14+.

<br>

## 2. Install

```sh
curl -fsSL https://raw.githubusercontent.com/lintuxt/matrix-saver/trunk/install.sh | bash
```

- It is non-interactive and safe to re-run. Re-running upgrades to the latest
  release.
- It exits non-zero with an `install.sh: …` message on any failure, including a
  checksum mismatch. Report that message to the user verbatim; don't retry
  with modifications.
- It restarts the `legacyScreenSaver` processes. That's expected and harmless.
- To pin a version, append `bash -s -- --version vX.Y.Z` instead of `bash`.

Don't download the release zip by hand, and don't build from source unless the
user asks. Don't use `sudo`.

<br>

## 3. Verify

```sh
test -d ~/Library/Screen\ Savers/MatrixSaver.saver && echo installed
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
  ~/Library/Screen\ Savers/MatrixSaver.saver/Contents/Info.plist
~/.local/bin/matrix-config
```

Expected:

- `installed`
- a version number such as `1.0.0`
- six settings lines: `palette`, `speed`, `density`, `glyphSize`, `glow`,
  `systemFailure`

<br>

## 4. Hand off to the user

Selecting a screen saver is a System Settings choice the user makes; there is
no supported command for it on current macOS. Open the pane for them:

```sh
open "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension"
```

Then tell them to click **Screen Saver…** and pick **Matrix**. If they want a
preview right away, `open -a ScreenSaverEngine` starts it immediately (any key
or mouse movement dismisses it). Ask before running it, since it takes over
every display.

<br>

## Optional: settings

Only if the user asks. Validate against the allowed values below; `matrix-config`
rejects anything else without writing.

```sh
~/.local/bin/matrix-config palette=amber speed=1.5
```

| Key | Values | Default |
|---|---|---|
| `palette` | `green`, `amber`, `blue`, `red`, `white` | `green` |
| `speed` | `0.25` – `3.0` | `1.0` |
| `density` | `0.1` – `1.0` | `0.6` |
| `glyphSize` | `10` – `40` | `18` |
| `glow` | `true`, `false` | `true` |
| `systemFailure` | `true`, `false` | `false` |

<br>

## Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/lintuxt/matrix-saver/trunk/install.sh | bash -s -- --uninstall
```

User settings are kept. Run `~/.local/bin/matrix-config --reset` before
uninstalling if the user wants them cleared.
