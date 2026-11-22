# Development

<br>

## Requirements

- Xcode 16 or later (Swift 6). On Xcode 26+, also the Metal Toolchain component:

  ```sh
  xcodebuild -downloadComponent MetalToolchain
  ```

- Optional: [XcodeGen](https://github.com/yonaskolb/XcodeGen). `project.yml` is
  the source of truth, and the generated `MatrixSaver.xcodeproj` is committed. Run
  `xcodegen generate` after adding or removing files, and commit the result.

<br>

## Build and install

```sh
./install.sh
```

Inside a clone this builds Release, installs into `~/Library/Screen Savers`, and
restarts the screen saver host. See [install.md](install.md) for options.

<br>

## Test without installing

The `SaverTest` scheme is a small app that hosts the same view outside Apple's
screen saver host, which makes debugging much easier.

```sh
xcodebuild -project MatrixSaver.xcodeproj -scheme SaverTest -configuration Debug \
  -derivedDataPath build build

open build/Build/Products/Debug/SaverTest.app                    # full screen, every display
open build/Build/Products/Debug/SaverTest.app --args --preview   # one 320×200 window
```

| Key | Action |
|---|---|
| `s` | Open the settings sheet |
| `q` or Esc | Quit |

<br>

## Tests

```sh
xcodebuild -project MatrixSaver.xcodeproj -scheme MatrixSaver -derivedDataPath build test
```

Tests cover the rain math, display geometry, settings, and the System Failure
schedule. They also run a GPU parity test that checks the Metal shader against
its Swift twin cell by cell. It needs a Metal-capable Mac.

<br>

## Logs

```sh
/usr/bin/log stream --predicate 'subsystem == "ai.lintuxt.MatrixSaver"'
```

Every instance logs its creation, start, stop and retirement, with its serial
number, screen and preview flag. That's the fastest way to see what Apple's
screen saver host is doing. In zsh, use the full `/usr/bin/log` path, because
`log` is a shell builtin.

<br>

## Project layout

| Path | Purpose |
|---|---|
| `Sources/MatrixSaver/` | The screen saver bundle: view, renderer, shaders, settings |
| `Sources/SaverTest/` | Development host app |
| `Tests/MatrixSaverTests/` | Unit and GPU parity tests |
| `install.sh` | Installer: release download or source build |
| `matrix-config` | Command-line settings editor |
| `.github/workflows/release.yml` | Tag-triggered release build |

<br>

## Releasing

1. Bump `CFBundleShortVersionString` in `Sources/MatrixSaver/Info.plist`.
2. Push a tag:

   ```sh
   git tag v1.2.3 && git push origin v1.2.3
   ```

The Release workflow builds a universal `.saver` and publishes
`MatrixSaver-v1.2.3.zip` with a `.sha256` checksum. The one-line installer always
picks up the latest release, so nothing else needs updating.
