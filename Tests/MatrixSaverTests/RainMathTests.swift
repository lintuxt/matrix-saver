import XCTest

final class RainMathTests: XCTestCase {
    let seed: UInt32 = 0x4D41_5452

    func testPcgStableValues() {
        XCTAssertEqual(RainMath.pcg(0), 129_708_002)
        XCTAssertEqual(RainMath.pcg(1), 2_831_084_092)
        XCTAssertEqual(RainMath.pcg(0x4D41_5452), 1_481_109_240)
    }

    func testDeterministic() {
        for i: UInt32 in 0..<100 {
            let a = RainMath.cell(seed: seed, col: i, row: i * 3, time: 12.5, speed: 1, density: 0.6, worldRows: 80, glyphCount: 80)
            let b = RainMath.cell(seed: seed, col: i, row: i * 3, time: 12.5, speed: 1, density: 0.6, worldRows: 80, glyphCount: 80)
            XCTAssertEqual(a, b)
        }
    }

    func testRanges() {
        for h: UInt32 in [0, 1, 255, 256, 0xFFFF_FFFF, 0x8000_0000] {
            let u = RainMath.unit(h)
            XCTAssertGreaterThanOrEqual(u, 0)
            XCTAssertLessThan(u, 1)
        }
        for col: UInt32 in 0..<100 {
            for row: UInt32 in 0..<80 {
                let c = RainMath.cell(seed: seed, col: col, row: row, time: 33.3, speed: 1.7, density: 0.8, worldRows: 80, glyphCount: 80)
                XCTAssertLessThan(c.glyph, 80)
                XCTAssertGreaterThanOrEqual(c.brightness, 0)
                XCTAssertLessThanOrEqual(c.brightness, 1)
            }
        }
    }

    func testDensityIncreasesLitFraction() {
        func lit(_ density: Float) -> Int {
            var n = 0
            for col: UInt32 in 0..<200 {
                for row: UInt32 in 0..<80 {
                    let c = RainMath.cell(seed: seed, col: col, row: row, time: 10, speed: 1, density: density, worldRows: 80, glyphCount: 80)
                    if c.brightness > 0 { n += 1 }
                }
            }
            return n
        }
        XCTAssertGreaterThan(lit(1.0), lit(0.1))
    }

    func testSeamlessWrap() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<50 {
            let col = UInt32.random(in: 0..<500, using: &rng)
            let s = UInt32.random(in: 0..<RainMath.streams, using: &rng)
            for (speed, density) in [(Float(1), Float(0.6)), (2.3, 1.0), (0.25, 0.1)] {
                let a = RainMath.headRow(seed: seed, col: col, stream: s, time: 0, speed: speed, density: density, worldRows: 80)
                let b = RainMath.headRow(seed: seed, col: col, stream: s, time: 1024, speed: speed, density: density, worldRows: 80)
                XCTAssertEqual(a.active, b.active)
                guard a.active else { continue }
                // Period = worldRows + len + gap; compare circularly. Recover it from rows.
                var diff = abs(a.headRow - b.headRow)
                // Allow wrap-around at the period boundary: head values near 0 vs near period.
                diff = min(diff, abs(diff - periodOf(col: col, stream: s, speed: speed, density: density)))
                XCTAssertLessThan(diff, 0.02, "col \(col) stream \(s)")
            }
        }
    }

    private func periodOf(col: UInt32, stream s: UInt32, speed: Float, density: Float) -> Float {
        let rLen = RainMath.unit(RainMath.hash(seed, col, s, 2))
        let rGap = RainMath.unit(RainMath.hash(seed, col, s, 3))
        let len = RainMath.mix(RainMath.minTrail, RainMath.maxTrail, rLen)
        let gap = 80 * RainMath.mix(0.1, 1.2, rGap) * max(1.2 / max(density, 0.05) - 1.0, 0.05)
        return 80 + len + gap
    }

    func testUniformsLayout() {
        XCTAssertEqual(MemoryLayout<Uniforms>.stride, 80)
        XCTAssertEqual(MemoryLayout<Uniforms>.size, 80)
    }
}
