import XCTest
import CoreGraphics

final class WorldGeometryTests: XCTestCase {
    func testRealLayout() {
        let frames = [CGRect(x: 0, y: 0, width: 2560, height: 1440),
                      CGRect(x: 2560, y: 0, width: 2560, height: 1440),
                      CGRect(x: -1920, y: 180, width: 1920, height: 1080)]
        let g = WorldGeometry(screenFrames: frames)
        XCTAssertEqual(g.union, CGRect(x: -1920, y: 0, width: 7040, height: 1440))
        XCTAssertEqual(g.worldOrigin(of: frames[0]), CGPoint(x: 1920, y: 0))
        XCTAssertEqual(g.worldOrigin(of: frames[1]), CGPoint(x: 4480, y: 0))
        XCTAssertEqual(g.worldOrigin(of: frames[2]), CGPoint(x: 0, y: 180))
        XCTAssertEqual(g.rows(cellHeight: 18), 80)
    }

    func testVerticalStack() {
        let top = CGRect(x: 0, y: 1080, width: 1920, height: 1080)
        let bottom = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let g = WorldGeometry(screenFrames: [top, bottom])
        XCTAssertEqual(g.union, CGRect(x: 0, y: 0, width: 1920, height: 2160))
        XCTAssertEqual(g.worldOrigin(of: top), CGPoint(x: 0, y: 0))
        XCTAssertEqual(g.worldOrigin(of: bottom), CGPoint(x: 0, y: 1080))
        XCTAssertEqual(g.rows(cellHeight: 18), 120)
        XCTAssertEqual(g.rows(cellHeight: 25), 87)  // ceil(86.4)
    }
}
