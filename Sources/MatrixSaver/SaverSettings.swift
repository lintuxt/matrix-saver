import Foundation
import ScreenSaver
import simd

/// User-facing settings, persisted in the screen saver's module defaults.
struct SaverSettings: Equatable {
    enum Palette: String, CaseIterable {
        case green, amber, blue, red, white

        /// Linear-ish RGB tint (alpha 1).
        var tint: SIMD4<Float> {
            switch self {
            case .green: SIMD4(0.08, 0.9, 0.24, 1)  // deeper film green
            case .amber: SIMD4(1.0, 0.65, 0.15, 1)
            case .blue: SIMD4(0.3, 0.6, 1.0, 1)
            case .red: SIMD4(1.0, 0.25, 0.2, 1)
            case .white: SIMD4(0.85, 0.9, 0.9, 1)
            }
        }

        var displayName: String {
            switch self {
            case .green: "Green"
            case .amber: "Amber"
            case .blue: "Blue"
            case .red: "Red"
            case .white: "White"
            }
        }
    }

    static let moduleName = "ai.lintuxt.MatrixSaver"
    static let didChange = Notification.Name("ai.lintuxt.MatrixSaver.settingsDidChange")

    static let speedRange: ClosedRange<Double> = 0.25...3.0
    static let densityRange: ClosedRange<Double> = 0.1...1.0
    static let glyphSizeRange: ClosedRange<Double> = 10...40

    enum Key {
        static let palette = "palette"
        static let speed = "speed"
        static let density = "density"
        static let glyphSize = "glyphSize"
        static let glow = "glow"
        static let systemFailure = "systemFailure"
    }

    var palette: Palette = .green
    var speed: Double = 1.0
    var density: Double = 0.6
    var glyphSize: Double = 18
    var glow: Bool = true
    /// Show a "SYSTEM FAILURE" alert every few minutes.
    var systemFailure: Bool = false

    static let defaults = SaverSettings()

    /// Cell size in points (width = 0.72 × glyphSize, height = glyphSize).
    var cellSize: CGSize { CGSize(width: glyphSize * 0.72, height: glyphSize) }

    func clamped() -> SaverSettings {
        var s = self
        s.speed = Self.clamp(speed, Self.speedRange, fallback: Self.defaults.speed)
        s.density = Self.clamp(density, Self.densityRange, fallback: Self.defaults.density)
        s.glyphSize = Self.clamp(glyphSize, Self.glyphSizeRange, fallback: Self.defaults.glyphSize)
        return s
    }

    private static func clamp(_ v: Double, _ r: ClosedRange<Double>, fallback: Double) -> Double {
        v.isFinite ? min(max(v, r.lowerBound), r.upperBound) : fallback
    }

    /// The screen saver's module defaults (nil only if ScreenSaver refuses the module name).
    static func store() -> UserDefaults? {
        ScreenSaverDefaults(forModuleWithName: moduleName)
    }

    static func load() -> SaverSettings {
        guard let store = store() else { return defaults }
        store.synchronize()  // pick up changes saved by another host process
        return load(from: store)
    }

    static func load(from store: UserDefaults) -> SaverSettings {
        var s = defaults
        if let raw = store.string(forKey: Key.palette), let p = Palette(rawValue: raw) { s.palette = p }
        if store.object(forKey: Key.speed) != nil { s.speed = store.double(forKey: Key.speed) }
        if store.object(forKey: Key.density) != nil { s.density = store.double(forKey: Key.density) }
        if store.object(forKey: Key.glyphSize) != nil { s.glyphSize = store.double(forKey: Key.glyphSize) }
        if store.object(forKey: Key.glow) != nil { s.glow = store.bool(forKey: Key.glow) }
        if store.object(forKey: Key.systemFailure) != nil { s.systemFailure = store.bool(forKey: Key.systemFailure) }
        return s.clamped()
    }

    func save() {
        guard let store = Self.store() else { return }
        save(to: store)
    }

    /// Writes the clamped settings, synchronizes, and posts `didChange` in-process.
    func save(to store: UserDefaults) {
        let s = clamped()
        store.set(s.palette.rawValue, forKey: Key.palette)
        store.set(s.speed, forKey: Key.speed)
        store.set(s.density, forKey: Key.density)
        store.set(s.glyphSize, forKey: Key.glyphSize)
        store.set(s.glow, forKey: Key.glow)
        store.set(s.systemFailure, forKey: Key.systemFailure)
        store.synchronize()
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }
}
