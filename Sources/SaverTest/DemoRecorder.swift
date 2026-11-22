import Foundation
import Metal
import QuartzCore

/// Renders the rain offscreen at a fixed frame rate and writes raw BGRA frames to stdout,
/// for piping into ffmpeg. Development only:
///
///   SaverTest --record [--width 1920] [--height 1080] [--scale 1] [--fps 30]
///             [--seconds 12] [--palette green] [--glyph-size 18] [--glow true]
///     | ffmpeg -f rawvideo -pix_fmt bgra -s 1920x1080 -r 30 -i - demo.mp4
@MainActor
enum DemoRecorder {
    static func run(_ args: [String]) -> Int32 {
        func value(_ name: String, _ fallback: String) -> String {
            guard let i = args.firstIndex(of: name), i + 1 < args.count else { return fallback }
            return args[i + 1]
        }
        let width = Int(value("--width", "1920")) ?? 1920
        let height = Int(value("--height", "1080")) ?? 1080
        let scale = Double(value("--scale", "1")) ?? 1
        let fps = Int(value("--fps", "30")) ?? 30
        let seconds = Double(value("--seconds", "12")) ?? 12
        var settings = SaverSettings.defaults
        settings.palette = SaverSettings.Palette(rawValue: value("--palette", "green")) ?? .green
        settings.glyphSize = (Double(value("--glyph-size", "18")) ?? 18).rounded()
        settings.glow = value("--glow", "true") == "true"

        guard let renderer = RainRenderer(layer: CAMetalLayer()),
              let atlas = GlyphAtlas.shared(device: renderer.device, glyphSize: settings.glyphSize, scale: scale)
        else { fputs("DemoRecorder: Metal unavailable\n", stderr); return 1 }
        renderer.atlas = atlas

        let device = renderer.device
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: RenderContext.outputFormat,
                                                            width: width, height: height, mipmapped: false)
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .private
        let bytesPerRow = width * 4
        guard let target = device.makeTexture(descriptor: desc),
              let readback = device.makeBuffer(length: bytesPerRow * height, options: .storageModeShared),
              let queue = RenderContext.shared?.queue
        else { fputs("DemoRecorder: could not allocate frame buffers\n", stderr); return 1 }

        let cellHeight = settings.glyphSize
        let pointsHigh = Double(height) / scale
        var u = Uniforms()
        u.viewOriginWorld = .zero
        u.cellSize = SIMD2(Float(settings.glyphSize * 0.72), Float(cellHeight))
        u.tint = settings.palette.tint
        u.scale = Float(scale)
        u.speed = Float(settings.speed)
        u.density = Float(settings.density)
        u.worldRows = Float((pointsHigh / cellHeight).rounded(.up))
        u.seed = MatrixSaverView.seed
        u.glyphCount = UInt32(atlas.glyphCount)
        u.atlasCols = UInt32(atlas.cols)
        u.atlasRows = UInt32(atlas.rows)

        let frames = Int(seconds * Double(fps))
        let fadeFrames = Double(fps) * 0.75
        let start = 300.0  // any start time works: every frame is a pure function of time
        let out = FileHandle.standardOutput

        for i in 0..<frames {
            u.time = RainMath.wrappedTime(start + Double(i) / Double(fps))
            u.fade = Float(min(1, Double(i) / fadeFrames, Double(frames - 1 - i) / fadeFrames))
            guard renderer.render(uniforms: u, glow: settings.glow, into: target) != nil,
                  let cmd = queue.makeCommandBuffer(), let blit = cmd.makeBlitCommandEncoder()
            else { fputs("DemoRecorder: frame \(i) failed\n", stderr); return 1 }
            blit.copy(from: target, sourceSlice: 0, sourceLevel: 0,
                      sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                      sourceSize: MTLSize(width: width, height: height, depth: 1),
                      to: readback, destinationOffset: 0,
                      destinationBytesPerRow: bytesPerRow, destinationBytesPerImage: bytesPerRow * height)
            blit.endEncoding()
            cmd.commit()
            cmd.waitUntilCompleted()
            out.write(Data(bytesNoCopy: readback.contents(), count: readback.length, deallocator: .none))
        }
        return 0
    }
}
