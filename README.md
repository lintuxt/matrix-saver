# MatrixSaver

Matrix-style digital rain for your Mac's screen saver, rendered with Metal.

Styled after the 1999 film: mirrored katakana, long fading trails, a dim
out-of-focus background layer, and an optional **SYSTEM FAILURE** alert that
freezes the rain.

The rain flows as one continuous canvas across all of your displays, and every
display stays in sync.

- macOS 14 or later
- Apple Silicon and Intel
- No sudo, no background processes

<br>

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/lintuxt/matrix-saver/trunk/install.sh | bash
```

Or with wget:

```sh
wget -qO- https://raw.githubusercontent.com/lintuxt/matrix-saver/trunk/install.sh | bash
```

Then open **System Settings › Wallpaper › Screen Saver** and pick **Matrix**.

The script downloads the latest release, verifies its checksum, and installs
the screen saver into `~/Library/Screen Savers`. See [docs/install.md](docs/install.md)
for manual installs, building from source, specific versions and uninstalling.

> Using an AI coding agent? Point it at [AGENTS.md](AGENTS.md).

<br>

## Settings

Use the **Options…** button in Screen Saver settings, or the bundled
`matrix-config` command:

```sh
matrix-config                           # show current settings
matrix-config palette=amber speed=1.5   # change one or more
matrix-config --reset                   # back to defaults
```

Palette, speed, density, glyph size, glow and the System Failure alert are all
configurable. Details in [docs/settings.md](docs/settings.md).

<br>

## Documentation

| Guide | What's in it |
|---|---|
| [Install](docs/install.md) | One-line install, manual install, source builds, uninstall, troubleshooting |
| [Settings](docs/settings.md) | Every option, `matrix-config`, hidden debug defaults |
| [Development](docs/development.md) | Building, the SaverTest app, tests, logs, releasing |
| [How it works](docs/how-it-works.md) | Rendering design and macOS screen saver host workarounds |
| [AGENTS.md](AGENTS.md) | Step-by-step install and verification for AI agents |

<br>

## License

Released under the [MIT License](LICENSE).
Copyright © 2026 Alexis Charytonow and MatrixSaver contributors.

MatrixSaver is an unofficial fan project. *The Matrix* is a trademark of
Warner Bros. Entertainment Inc.; this project is not affiliated with,
sponsored or endorsed by Warner Bros. or the film's creators. No film footage,
artwork or fonts are included. Glyphs are drawn at runtime with fonts that
ship with macOS.
