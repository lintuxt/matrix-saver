# How it works

<br>

## Rendering

Every glyph on screen is a pure function of four inputs: a fixed seed, the column,
the row, and the wall-clock time. Nothing is simulated frame to frame.

That is what keeps several displays in sync. macOS runs a separate copy of the
screen saver on each display, and the copies never talk to each other. Each one
computes the same function over its own slice of a shared "world": the union of
all your displays, in points. Drops cross from one display to the next without
coordination, and nothing drifts, even across sleep and wake.

A few details:

- **Time** wraps every 1024 seconds to keep float precision high on the GPU.
  Each column's speed is snapped so it completes a whole number of cycles per
  wrap, so the wrap is invisible.
- **Glyphs** are half-width katakana, mirrored as in the film, plus digits and a
  few symbols. They're drawn once into a texture atlas with fonts that ship with
  macOS.
- **The shader** runs as one full-screen pass for the rain, then an optional
  quarter-resolution blur for the glow, then a composite.
- **The Swift twin.** The cell function exists twice, in `Shaders.metal` and in
  `RainMath.swift`. A GPU parity test keeps the two identical.

<br>

## The macOS screen saver host

Third-party screen savers run inside Apple's `legacyScreenSaver` process. From
macOS Sonoma onward it has well-documented bugs:

- `stopAnimation` isn't called when the screen saver is dismissed. It is only
  called for the preview in System Settings.
- Old screen saver instances are never destroyed. A new one is created every
  time the saver starts or the Wallpaper pane opens.
- `isPreview` can be wrong.
- `exit(0)`, the usual workaround, became unreliable on macOS Tahoe, because the
  host relaunches the process.
- Secondary displays sometimes stay black. Nothing a saver can do fixes this.

What MatrixSaver does about it:

- **No drawing before start.** It renders only after `startAnimation`, driven by
  its own display link rather than the host's timer.
- **Real stop signal.** It listens for the system's `com.apple.screensaver.willstop`
  notification. On stop it halts rendering and frees its GPU memory.
- **Lame ducks.** When a new instance starts on a display, older instances on the
  same display retire permanently and release everything they hold. Instances
  on other displays are left alone.
- **No `exit(0)` by default.** It's available as the hidden `ExitOnStop` setting
  for experiments (see [settings.md](settings.md#hidden-debug-defaults)).

<br>

## Further reading

- [ScreenSaverMinimal](https://github.com/AerialScreensaver/ScreenSaverMinimal), a template that tracks each macOS release's quirks
- [How to make a macOS screen saver](https://wadetregaskis.com/how-to-make-a-macos-screen-saver/), Wade Tregaskis
- [Aerial issue #1396](https://github.com/JohnCoates/Aerial/issues/1396), Tahoe screen saver problems
- [Apple Developer Forums thread 787444](https://developer.apple.com/forums/thread/787444), macOS 26 screen saver issues
- [Michael Tsai's roundup](https://mjtsai.com/blog/2025/12/10/how-to-make-a-macos-screen-saver/)
