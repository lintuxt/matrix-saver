import CoreGraphics

/// Maps a view's on-screen rect into the shared "world": the union of all displays,
/// in points, with the origin at the top-left and y pointing down.
struct WorldGeometry: Equatable {
    let union: CGRect  // AppKit global coordinates (y up)

    init(screenFrames: [CGRect]) {
        union = screenFrames.reduce(CGRect.null) { $0.union($1) }
    }

    /// Top-left of `rect` (AppKit global coordinates) in world coordinates.
    func worldOrigin(of rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX - union.minX, y: union.maxY - rect.maxY)
    }

    func rows(cellHeight: CGFloat) -> CGFloat {
        (union.height / cellHeight).rounded(.up)
    }
}
