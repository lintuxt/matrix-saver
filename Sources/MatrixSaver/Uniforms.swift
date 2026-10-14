import simd

/// Per-frame uniform block. Layout must match `Uniforms` in Shaders.metal (80 bytes).
struct Uniforms {
    var viewOriginWorld: SIMD2<Float> = .zero  // view's top-left in world points (y down)
    var cellSize: SIMD2<Float> = .zero         // points
    var tint: SIMD4<Float> = .zero
    var scale: Float = 1                       // pixels per point
    var time: Float = 0                        // seconds, wraps every RainMath.timeWrap
    var speed: Float = 1
    var density: Float = 0.6
    var worldRows: Float = 0
    var fade: Float = 1
    var seed: UInt32 = 0
    var glyphCount: UInt32 = 0
    var atlasCols: UInt32 = 0
    var atlasRows: UInt32 = 0
    var pad0: UInt32 = 0
    var pad1: UInt32 = 0
}
