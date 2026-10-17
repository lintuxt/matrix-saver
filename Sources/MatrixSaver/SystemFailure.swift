import Foundation

/// When the "SYSTEM FAILURE" alert is on screen.
///
/// Like the rain, it's a pure function of wall-clock time, so every display shows the
/// alert at the same moment without coordinating. Time is split into slots; each slot
/// shows the alert once, at a random offset. Uses unwrapped time so the schedule doesn't
/// repeat every time wrap.
enum SystemFailure {
    static let slotLength: Double = 256  // ~4.3 min
    static let visibleFor: Double = 7
    static let fadeFor: Double = 0.4
    /// Keeps the alert clear of slot edges so consecutive alerts never merge.
    static let margin: Double = 20

    /// Alert opacity (0…1) at `now` (seconds since 1970).
    static func opacity(seed: UInt32, now: TimeInterval) -> Float {
        let local = timeIntoAlert(seed: seed, now: now)
        guard local >= 0, local < visibleFor else { return 0 }
        return Float(min(1, local / fadeFor, (visibleFor - local) / fadeFor))
    }

    /// Clock for the rain when alerts are on: wall-clock time minus every second spent in
    /// an alert so far, so the rain freezes while the alert is up and resumes where it
    /// stopped. Each slot holds exactly one alert, which keeps this stateless.
    static func rainTime(seed: UInt32, now: TimeInterval) -> TimeInterval {
        let slot = self.slot(now)
        let paused = slot * visibleFor + min(max(timeIntoAlert(seed: seed, now: now), 0), visibleFor)
        return max(now, 0) - paused
    }

    private static func slot(_ now: TimeInterval) -> Double {
        (max(now, 0) / slotLength).rounded(.down)
    }

    /// Seconds since this slot's alert started (negative before it).
    private static func timeIntoAlert(seed: UInt32, now: TimeInterval) -> Double {
        let slot = self.slot(now)
        let r = Double(RainMath.unit(RainMath.hash(seed, UInt32(truncatingIfNeeded: Int64(slot)), 0, 99)))
        let start = margin + r * (slotLength - visibleFor - 2 * margin)
        return max(now, 0) - slot * slotLength - start
    }
}
