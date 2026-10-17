# MatrixSaver

A macOS screen saver that renders Matrix-style digital rain with Metal, styled after the 1999 film: mirrored katakana, long fading trails, a dim out-of-focus background layer, and an optional "SYSTEM FAILURE" alert that freezes the rain. The rain flows continuously across all your displays and stays in sync between them.

Runs on macOS 14 or later, Apple Silicon and Intel.

## Install

1. Download the latest `MatrixSaver-vX.Y.Z.zip` from [Releases](https://github.com/lintuxt/matrix-saver/releases) and unzip it.
2. The screen saver is not notarized by Apple, so clear the download quarantine first. In Terminal, from the unzipped folder:

   ```sh
   xattr -dr com.apple.quarantine MatrixSaver.saver
   ```

   Without this step macOS refuses to open it. You can instead approve it in System Settings > Privacy & Security > "Open Anyway" after the first attempt.
3. Double-click `MatrixSaver.saver` and choose to install it.
4. Pick **Matrix** in System Settings > Screen Saver (on macOS 26, Wallpaper > Screen Saver).

To uninstall, delete `~/Library/Screen Savers/MatrixSaver.saver`.

## Settings

Open System Settings > Screen Saver > MatrixSaver > Options:

- Palette: green (default), amber, blue, red, white
- Speed: 0.25 to 3.0 (default 1.0)
- Density: 0.1 to 1.0 (default 0.6)
- Glyph size: 10 to 40 pt (default 18)
- Glow: on by default
- System Failure alert: off by default. When on, a film-style "SYSTEM FAILURE" box appears at the centre of each display for about 7 seconds, once every ~4 minutes, at the same moment on every display.

The Options button often stops responding after a full-screen preview until System Settings is reopened (a `legacyScreenSaver` bug). The same settings can be read and changed from the command line with `matrix-config`, included in the download and in this repo:

```sh
./matrix-config                          # show current settings
./matrix-config palette=amber speed=1.5  # change one or more
./matrix-config --reset                  # back to defaults
```

Changes apply the next time the screen saver starts.

## Build from source

Requires Xcode (with the Metal Toolchain component on Xcode 26+). Builds aren't quarantined, so there's no security prompt:

```sh
git clone https://github.com/lintuxt/matrix-saver.git
cd matrix-saver
./install.sh
```

Generates the Xcode project (if `xcodegen` is installed), builds Release, copies the bundle to `~/Library/Screen Savers/MatrixSaver.saver` and restarts the `legacyScreenSaver` host processes.

## Test without installing

The `SaverTest` scheme is a small host app that runs the same view:

```sh
xcodebuild -project MatrixSaver.xcodeproj -scheme SaverTest -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/SaverTest.app                  # full screen on every display
open build/Build/Products/Debug/SaverTest.app --args --preview # one 320x200 window
```

Keys: `s` opens the configure sheet, `q` or Esc quits.

## Logs

```sh
log stream --predicate 'subsystem == "ai.lintuxt.MatrixSaver"'
```

## legacyScreenSaver caveats

On macOS Sonoma through Tahoe the `legacyScreenSaver` host is unreliable: `stopAnimation` is not called on real dismissal, old view instances are never destroyed, `isPreview` can be wrong, and `exit(0)` is unreliable on Tahoe. The saver works around this (display link started only in `startAnimation`, `willstop` notification, lame-duck handling of older instances). Sources:

- https://github.com/AerialScreensaver/ScreenSaverMinimal
- https://wadetregaskis.com/how-to-make-a-macos-screen-saver/
- https://github.com/JohnCoates/Aerial/issues/1396
- https://developer.apple.com/forums/thread/787444
- https://mjtsai.com/blog/2025/12/10/how-to-make-a-macos-screen-saver/

### Hidden `SystemFailureAlways` default

Keeps the System Failure alert on screen, for checking how it looks:

```sh
defaults write ~/Library/Containers/com.apple.ScreenSaver.Engine.legacyScreenSaver/Data/Library/Preferences/ByHost/ai.lintuxt.MatrixSaver SystemFailureAlways -bool true
```

Delete it again with `defaults delete <same path> SystemFailureAlways`.

### Hidden `ExitOnStop` default

Off by default. To experiment with exiting the host process on stop:

```sh
defaults write ~/Library/Containers/com.apple.ScreenSaver.Engine.legacyScreenSaver/Data/Library/Preferences/ByHost/ai.lintuxt.MatrixSaver ExitOnStop -bool true
```

## Releasing

Push a `vX.Y.Z` tag; the Release workflow builds a universal `.saver` and attaches the zip to a GitHub Release.

## License

MIT. Not affiliated with or endorsed by Warner Bros. or the makers of *The Matrix*.
