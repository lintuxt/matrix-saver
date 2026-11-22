# Installing MatrixSaver

Requires macOS 14 or later, on Apple Silicon or Intel.

Nothing here needs `sudo`. Everything is installed into your home folder.

<br>

## One-line install (recommended)

```sh
curl -fsSL https://raw.githubusercontent.com/lintuxt/matrix-saver/trunk/install.sh | bash
```

wget works the same way:

```sh
wget -qO- https://raw.githubusercontent.com/lintuxt/matrix-saver/trunk/install.sh | bash
```

The script:

1. Finds the latest [GitHub Release](https://github.com/lintuxt/matrix-saver/releases).
2. Downloads `MatrixSaver-vX.Y.Z.zip` and verifies its SHA-256 checksum.
3. Installs `MatrixSaver.saver` into `~/Library/Screen Savers`.
4. Installs the `matrix-config` helper into `~/.local/bin`.
5. Restarts the macOS screen saver host so the new version is picked up.

Then open **System Settings › Wallpaper › Screen Saver** and pick **Matrix**.
To see it right away:

```sh
open -a ScreenSaverEngine
```

Prefer to read the script first? It's [install.sh](../install.sh) in this repo.

<br>

## Options

Pass options after `bash -s --`:

```sh
# A specific release
curl -fsSL https://raw.githubusercontent.com/lintuxt/matrix-saver/trunk/install.sh | bash -s -- --version v1.0.0

# Uninstall
curl -fsSL https://raw.githubusercontent.com/lintuxt/matrix-saver/trunk/install.sh | bash -s -- --uninstall
```

| Option | Effect |
|---|---|
| `--release` | Download a prebuilt release (default when piped) |
| `--source` | Build from a local clone with Xcode (default inside a clone) |
| `--version vX.Y.Z` | Install that release instead of the latest |
| `--uninstall` | Remove the screen saver and `matrix-config` |
| `--help` | Show usage |

| Environment variable | Default |
|---|---|
| `MATRIX_SAVER_DIR` | `~/Library/Screen Savers` |
| `MATRIX_SAVER_BIN_DIR` | `~/.local/bin` |
| `MATRIX_SAVER_VERSION` | latest release |

<br>

## Manual install

1. Download the latest `MatrixSaver-vX.Y.Z.zip` from
   [Releases](https://github.com/lintuxt/matrix-saver/releases) and unzip it.

2. The screen saver is not notarized by Apple, so clear the download
   quarantine. In Terminal, from the unzipped folder:

   ```sh
   xattr -dr com.apple.quarantine MatrixSaver.saver
   ```

   Without this, macOS refuses to open it. Alternatively, approve it under
   **System Settings › Privacy & Security › Open Anyway** after the first attempt.

3. Double-click `MatrixSaver.saver` and choose to install it.

4. Pick **Matrix** in **System Settings › Wallpaper › Screen Saver**.

<br>

## Build from source

Requires Xcode. On Xcode 26 or later, also install the Metal Toolchain
component (`xcodebuild -downloadComponent MetalToolchain`).

```sh
git clone https://github.com/lintuxt/matrix-saver.git
cd matrix-saver
./install.sh
```

Inside a clone, `install.sh` builds Release with Xcode instead of downloading.
If [XcodeGen](https://github.com/yonaskolb/XcodeGen) is installed it regenerates
the project first. Local builds aren't quarantined, so there's no security prompt.

<br>

## Uninstall

```sh
matrix-config --reset   # optional: clear your settings first
curl -fsSL https://raw.githubusercontent.com/lintuxt/matrix-saver/trunk/install.sh | bash -s -- --uninstall
```

Or by hand: delete `~/Library/Screen Savers/MatrixSaver.saver` and
`~/.local/bin/matrix-config`.

<br>

## Troubleshooting

**"Matrix" doesn't appear in the list.**
Quit and reopen System Settings. The list is read when the pane opens.

**macOS says the screen saver can't be opened.**
It was downloaded through a browser and is quarantined. Run
`xattr -dr com.apple.quarantine ~/Library/Screen\ Savers/MatrixSaver.saver`.

**The Options… button stops responding.**
A known bug in Apple's screen saver host after a full-screen preview. Reopen
System Settings, or use [`matrix-config`](settings.md) instead.

**`matrix-config: command not found`.**
`~/.local/bin` isn't on your `PATH`. Run it as `~/.local/bin/matrix-config`, or add
`export PATH="$HOME/.local/bin:$PATH"` to your `~/.zshrc`.

**One display stays black.**
Apple's screen saver host on recent macOS sometimes fails to start a saver on
secondary displays. See [How it works](how-it-works.md#the-macos-screen-saver-host).
