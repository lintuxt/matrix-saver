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

## Recording a demo video

SaverTest has a hidden `--record` mode. It renders the rain offscreen with the
real Metal renderer at a fixed frame rate and writes raw BGRA frames to stdout,
so frames are exact and nothing takes over your displays.

```sh
xcodebuild -project MatrixSaver.xcodeproj -scheme SaverTest -configuration Release \
  -derivedDataPath build build

build/Build/Products/Release/SaverTest.app/Contents/MacOS/SaverTest \
    --record --width 3840 --height 2160 --scale 2 --seconds 15 |
  ffmpeg -f rawvideo -pix_fmt bgra -s 3840x2160 -r 30 -i - \
    -c:v libx265 -crf 16 -pix_fmt yuv420p -tag:v hvc1 demo-4k.mp4
```

The README animation (`docs/media/demo.webp`) is a seamless 6-second loop cut from
that video: 7 seconds of footage, with the last second cross-faded into the first.
It's encoded as animated WebP with `img2webp` from Homebrew's `webp` package,
because GitHub won't play videos committed to a repo and a GIF would be twice the
size with banded glow:

```sh
mkdir frames
ffmpeg -ss 2 -t 7 -i demo-4k.mp4 -filter_complex "[0]fps=20,scale=1280:720:flags=lanczos,split=3[a][b][c];\
[a]trim=0:1,setpts=PTS-STARTPTS[head];[b]trim=6:7,setpts=PTS-STARTPTS[tail];\
[c]trim=1:6,setpts=PTS-STARTPTS[mid];[tail][head]xfade=transition=fade:duration=1:offset=0[blend];\
[blend][mid]concat=n=2:v=1[out]" -map "[out]" frames/f%04d.png
img2webp -loop 0 -lossy -q 75 -m 6 -d 50 frames/f*.png -o docs/media/demo.webp
```

| Option | Default |
|---|---|
| `--width`, `--height` | `1920`, `1080` (pixels) |
| `--scale` | `1` (use `2` for retina-sharp glyphs) |
| `--fps`, `--seconds` | `30`, `12` |
| `--palette`, `--glyph-size`, `--glow` | `green`, `18`, `true` |

Render at `--scale 2` and downscale: at 1× the glyphs look soft, and thin
green-on-black strokes need a high-quality encode (low CRF) to survive
compression. The System Failure alert is a separate AppKit overlay and isn't
captured.

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
