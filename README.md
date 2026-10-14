# MatrixSaver

A macOS screen saver that renders Matrix-style digital rain with Metal (AppKit + Metal, no SwiftUI in the render path). Runs on macOS 14+.

## Settings

Open System Settings > Screen Saver > MatrixSaver > Options:

- Palette: green (default), amber, blue, red, white
- Speed: 0.25 to 3.0 (default 1.0)
- Density: 0.1 to 1.0 (default 0.6)
- Glyph size: 10 to 40 pt (default 18)
- Glow: on by default

## Install

```sh
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

### Hidden `ExitOnStop` default

Off by default. To experiment with exiting the host process on stop:

```sh
defaults -currentHost write ~/Library/Containers/com.apple.ScreenSaver.Engine.legacyScreenSaver/Data/Library/Preferences/ByHost/ai.lintuxt.MatrixSaver ExitOnStop -bool true
```
