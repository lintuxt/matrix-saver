import XCTest

final class SaverSettingsTests: XCTestCase {
    private var suiteName = ""
    private var store: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "ai.lintuxt.MatrixSaver.tests.\(UUID().uuidString)"
        store = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        store.removePersistentDomain(forName: suiteName)
        store = nil
        super.tearDown()
    }

    func testDefaults() {
        let d = SaverSettings.defaults
        XCTAssertEqual(d.palette, .green)
        XCTAssertEqual(d.speed, 1.0)
        XCTAssertEqual(d.density, 0.6)
        XCTAssertEqual(d.glyphSize, 18)
        XCTAssertTrue(d.glow)
        XCTAssertFalse(d.systemFailure)
        XCTAssertEqual(SaverSettings.load(from: store), d, "empty store loads defaults")
    }

    func testClamping() {
        let low = SaverSettings(palette: .red, speed: 0, density: -1, glyphSize: 2, glow: false).clamped()
        XCTAssertEqual(low.speed, 0.25)
        XCTAssertEqual(low.density, 0.1)
        XCTAssertEqual(low.glyphSize, 10)

        let high = SaverSettings(palette: .red, speed: 9, density: 5, glyphSize: 400, glow: false).clamped()
        XCTAssertEqual(high.speed, 3.0)
        XCTAssertEqual(high.density, 1.0)
        XCTAssertEqual(high.glyphSize, 40)

        let nan = SaverSettings(speed: .nan, density: .infinity, glyphSize: .nan).clamped()
        XCTAssertEqual(nan, .defaults)
    }

    func testRoundTrip() {
        let s = SaverSettings(palette: .amber, speed: 2.5, density: 0.3, glyphSize: 24, glow: false, systemFailure: true)
        let posted = expectation(forNotification: SaverSettings.didChange, object: nil)
        s.save(to: store)
        wait(for: [posted], timeout: 1)
        XCTAssertEqual(SaverSettings.load(from: store), s)
    }

    func testLoadClampsAndIgnoresBadValues() {
        store.set("magenta", forKey: "palette")
        store.set(10.0, forKey: "speed")
        store.set(0.0, forKey: "density")
        store.set(99.0, forKey: "glyphSize")
        store.set(false, forKey: "glow")
        let s = SaverSettings.load(from: store)
        XCTAssertEqual(s.palette, .green)
        XCTAssertEqual(s.speed, 3.0)
        XCTAssertEqual(s.density, 0.1)
        XCTAssertEqual(s.glyphSize, 40)
        XCTAssertFalse(s.glow)
    }

    func testPaletteTints() {
        XCTAssertEqual(SaverSettings.Palette.allCases.count, 5)
        XCTAssertEqual(SaverSettings.Palette.green.tint, SIMD4<Float>(0.08, 0.9, 0.24, 1))
        XCTAssertEqual(SaverSettings.Palette.white.tint, SIMD4<Float>(0.85, 0.9, 0.9, 1))
        for p in SaverSettings.Palette.allCases { XCTAssertFalse(p.displayName.isEmpty) }
    }
}
