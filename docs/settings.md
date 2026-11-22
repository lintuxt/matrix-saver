# Settings

Change settings from **System Settings › Wallpaper › Screen Saver › Options…**,
or from Terminal with `matrix-config`.

Changes apply the next time the screen saver starts.

<br>

## Options

| Setting | `matrix-config` key | Values | Default |
|---|---|---|---|
| Palette | `palette` | `green`, `amber`, `blue`, `red`, `white` | `green` |
| Speed | `speed` | `0.25` – `3.0` | `1.0` |
| Density | `density` | `0.1` – `1.0` | `0.6` |
| Glyph size | `glyphSize` | `10` – `40` pt | `18` |
| Glow | `glow` | `true`, `false` | `true` |
| System Failure alert | `systemFailure` | `true`, `false` | `false` |

**System Failure alert.** When on, a film-style "SYSTEM FAILURE" box appears in
the centre of each display for about 7 seconds, roughly every 4 minutes, at the
same moment on every display. The rain freezes while it's shown.

<br>

## matrix-config

Installed to `~/.local/bin` by the one-line installer, and included in every
release zip.

```sh
matrix-config                            # show current settings
matrix-config palette=amber speed=1.5    # change one or more
matrix-config glow=false systemFailure=true
matrix-config --reset                    # back to defaults
matrix-config --help
```

Values are validated before anything is written, so a typo changes nothing.

Why it exists: the **Options…** button often stops responding after a
full-screen preview until System Settings is reopened. That's a bug in Apple's
`legacyScreenSaver` host, not in MatrixSaver.

<br>

## Hidden debug defaults

These are for development. Both live in the screen saver host's preferences:

```sh
PREFS=~/Library/Containers/com.apple.ScreenSaver.Engine.legacyScreenSaver/Data/Library/Preferences/ByHost/ai.lintuxt.MatrixSaver
```

`defaults` appends the machine's host UUID to that path by itself, so don't add it.

**`SystemFailureAlways`** keeps the System Failure alert on screen, for checking
its look:

```sh
defaults write "$PREFS" SystemFailureAlways -bool true
defaults delete "$PREFS" SystemFailureAlways
```

**`ExitOnStop`** makes the saver exit its host process when it stops. Off by
default, because it's unreliable on recent macOS (see
[How it works](how-it-works.md#the-macos-screen-saver-host)):

```sh
defaults write "$PREFS" ExitOnStop -bool true
defaults delete "$PREFS" ExitOnStop
```
