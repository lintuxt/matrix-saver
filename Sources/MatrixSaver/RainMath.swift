import Foundation

/// Swift twin of the cell function in Shaders.metal. Keep the two in lockstep:
/// the GPU parity test compares them.
///
/// Every cell is a pure function of (seed, column, row, time), so independent
/// instances on different displays agree without talking to each other.
enum RainMath {
    /// Time wraps at this period. Column speeds are snapped so every column completes
    /// a whole number of cycles per wrap, which makes the wrap seamless.
    static let timeWrap: Double = 1024
    static let streams: UInt32 = 2
    /// Trail length in rows. Long, slowly fading trails like the 1999 film.
    static let minTrail: Float = 14
    static let maxTrail: Float = 48
    /// Cells this many rows behind a head mutate fast; the rest of the trail barely changes.
    static let nearHeadRows: Float = 3

    struct Cell: Equatable {
        var brightness: Float  // 0 = empty
        var head: Float        // 1 = leading glyph of a drop
        var glyph: UInt32
    }

    static func pcg(_ v: UInt32) -> UInt32 {
        let state = v &* 747_796_405 &+ 2_891_336_453
        let word = ((state >> ((state >> 28) &+ 4)) ^ state) &* 277_803_737
        return (word >> 22) ^ word
    }

    static func hash(_ seed: UInt32, _ a: UInt32, _ b: UInt32, _ c: UInt32) -> UInt32 {
        pcg(seed ^ pcg(a ^ pcg(b ^ pcg(c))))
    }

    /// Uniform float in [0, 1) using 24 bits, exact in Float on both CPU and GPU.
    static func unit(_ h: UInt32) -> Float {
        Float(h >> 8) * (1.0 / 16_777_216.0)
    }

    static func mix(_ a: Float, _ b: Float, _ t: Float) -> Float { a + (b - a) * t }

    static func wrappedTime(_ now: TimeInterval) -> Float {
        Float(now.truncatingRemainder(dividingBy: timeWrap))
    }

    /// Head position of one stream of a column. `active` is false when the stream is
    /// density-culled.
    static func headRow(seed: UInt32, col: UInt32, stream s: UInt32, time t: Float,
                        speed: Float, density: Float, worldRows: Float)
        -> (headRow: Float, len: Float, active: Bool) {
        if s > 0 && unit(hash(seed, col, s, 4)) >= density { return (0, 0, false) }
        let rSpeed = unit(hash(seed, col, s, 0))
        let rPhase = unit(hash(seed, col, s, 1))
        let rLen = unit(hash(seed, col, s, 2))
        let rGap = unit(hash(seed, col, s, 3))

        let len = mix(minTrail, maxTrail, rLen)
        let gap = worldRows * mix(0.1, 1.2, rGap) * max(1.2 / max(density, 0.05) - 1.0, 0.05)
        let period = worldRows + len + gap
        let rawSpeed = speed * mix(8, 22, rSpeed)  // rows per second
        let cycles = max((rawSpeed * Float(timeWrap) / period).rounded(), 1)
        let rowsPerSec = cycles * period / Float(timeWrap)

        let x = t * rowsPerSec + rPhase * period
        return (x - period * (x / period).rounded(.down), len, true)
    }

    static func cell(seed: UInt32, col: UInt32, row: UInt32, time t: Float,
                     speed: Float, density: Float, worldRows: Float, glyphCount: UInt32) -> Cell {
        var bright: Float = 0
        var head: Float = 0
        var nearest = Float.greatestFiniteMagnitude  // rows behind the closest head
        for s in 0..<streams {
            let st = headRow(seed: seed, col: col, stream: s, time: t,
                             speed: speed, density: density, worldRows: worldRows)
            if !st.active { continue }
            let len = st.len
            let d = st.headRow - Float(row)
            if d >= 0 && d < len {
                let f = 1 - d / len
                let b = f * f.squareRoot()
                if b > bright { bright = b }
                if d < 1 { head = 1 }
                nearest = min(nearest, d)
            }
        }
        let r = unit(hash(seed, col, row, 7))
        let rate = nearest < nearHeadRows ? mix(8, 14, r) : mix(0.05, 0.5, r)  // changes per second
        let tick = UInt32(max(t * rate, 0).rounded(.down))
        let glyph = hash(seed, col, row, tick &+ 11) % max(glyphCount, 1)
        return Cell(brightness: bright, head: head, glyph: glyph)
    }
}
