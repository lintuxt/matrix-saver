import XCTest

final class SystemFailureTests: XCTestCase {
    let seed: UInt32 = 0x4D41_5452

    /// Samples one slot at 10 Hz: the alert shows exactly once, for ~visibleFor seconds.
    func testOneAlertPerSlot() {
        for slot in [0.0, 1, 7, 6_900_000] {
            let base = slot * SystemFailure.slotLength
            var visible = 0.0, rises = 0, peak: Float = 0
            var prev: Float = 0
            for i in 0..<Int(SystemFailure.slotLength * 10) {
                let o = SystemFailure.opacity(seed: seed, now: base + Double(i) / 10)
                if o > 0 { visible += 0.1 }
                if o > 0 && prev == 0 { rises += 1 }
                peak = max(peak, o)
                prev = o
            }
            XCTAssertEqual(rises, 1, "slot \(slot)")
            XCTAssertEqual(visible, SystemFailure.visibleFor, accuracy: 0.2, "slot \(slot)")
            XCTAssertEqual(peak, 1)
        }
    }

    func testSlotsDiffer() {
        func start(_ slot: Double) -> Double {
            let base = slot * SystemFailure.slotLength
            return stride(from: 0.0, to: SystemFailure.slotLength, by: 0.5)
                .first { SystemFailure.opacity(seed: seed, now: base + $0) > 0 } ?? -1
        }
        XCTAssertGreaterThan(Set((0..<8).map { start(Double($0)) }).count, 1)
    }

    /// The rain clock never jumps, stands still exactly while the alert is up, and runs at
    /// real speed otherwise, across several slot boundaries.
    func testRainFreezesDuringAlertAndResumesSmoothly() {
        let base = 6_900_000 * SystemFailure.slotLength
        let dt = 0.05
        var frozen = 0.0
        var prev = SystemFailure.rainTime(seed: seed, now: base)
        var prevInAlert = false
        for i in 1...Int(3 * SystemFailure.slotLength / dt) {
            let now = base + Double(i) * dt
            let t = SystemFailure.rainTime(seed: seed, now: now)
            let step = t - prev
            XCTAssertGreaterThanOrEqual(step, -1e-6, "rain time went backwards at \(now)")
            XCTAssertLessThanOrEqual(step, dt + 1e-6, "rain time jumped at \(now)")
            let inAlert = SystemFailure.opacity(seed: seed, now: now) > 0
            if inAlert && prevInAlert {
                XCTAssertEqual(step, 0, accuracy: 1e-6, "rain should be frozen at \(now)")
            }
            if step < dt / 2 { frozen += dt }
            prev = t
            prevInAlert = inAlert
        }
        XCTAssertEqual(frozen, 3 * SystemFailure.visibleFor, accuracy: 0.3)
    }
}
