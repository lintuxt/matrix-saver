import Metal
import QuartzCore
import os

/// Process-wide Metal state shared by every saver view (one per display).
@MainActor
final class RenderContext {
    static let shared: RenderContext? = RenderContext()

    let device: MTLDevice
    let queue: MTLCommandQueue
    let rainPipeline: MTLRenderPipelineState
    let downsamplePipeline: MTLRenderPipelineState
    let blurPipeline: MTLRenderPipelineState
    let compositePipeline: MTLRenderPipelineState
    let sampler: MTLSamplerState
    /// 1×1 black texture bound as the glow input when glow is off.
    let blackTexture: MTLTexture

    static let intermediateFormat: MTLPixelFormat = .rgba16Float
    static let outputFormat: MTLPixelFormat = .bgra8Unorm

    private static let log = Logger(subsystem: "ai.lintuxt.MatrixSaver", category: "Renderer")

    private init?() {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            Self.log.error("no Metal device / command queue")
            return nil
        }
        do {
            // Load from the saver bundle, never Bundle.main (that's the host process).
            let library = try device.makeDefaultLibrary(bundle: Bundle(for: RenderContext.self))
            func pipeline(_ fragment: String, _ format: MTLPixelFormat) throws -> MTLRenderPipelineState {
                let d = MTLRenderPipelineDescriptor()
                d.label = fragment
                d.vertexFunction = library.makeFunction(name: "fullscreenVertex")
                d.fragmentFunction = library.makeFunction(name: fragment)
                d.colorAttachments[0].pixelFormat = format
                return try device.makeRenderPipelineState(descriptor: d)
            }
            rainPipeline = try pipeline("rainFragment", Self.intermediateFormat)
            downsamplePipeline = try pipeline("downsampleFragment", Self.intermediateFormat)
            blurPipeline = try pipeline("blurFragment", Self.intermediateFormat)
            compositePipeline = try pipeline("compositeFragment", Self.outputFormat)
        } catch {
            Self.log.error("pipeline setup failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        let sd = MTLSamplerDescriptor()
        sd.minFilter = .linear
        sd.magFilter = .linear
        sd.sAddressMode = .clampToEdge
        sd.tAddressMode = .clampToEdge
        guard let sampler = device.makeSamplerState(descriptor: sd) else { return nil }

        let bd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1,
                                                          mipmapped: false)
        bd.usage = .shaderRead
        guard let black = device.makeTexture(descriptor: bd) else { return nil }
        var zero: UInt32 = 0
        black.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &zero, bytesPerRow: 4)

        self.device = device
        self.queue = queue
        self.sampler = sampler
        self.blackTexture = black
    }
}

/// Per-view renderer: rain pass → optional glow (¼-res downsample + separable blur) →
/// composite into the layer's drawable. Main thread only.
@MainActor
final class RainRenderer {
    private let ctx: RenderContext
    private let layer: CAMetalLayer

    private var scene: MTLTexture?
    private var glowA: MTLTexture?
    private var glowB: MTLTexture?
    private var size = (width: 0, height: 0)

    var device: MTLDevice { ctx.device }

    /// Glyph atlas sampled by the rain pass. The view assigns it (from `GlyphAtlas.shared`)
    /// whenever scale or glyph size changes; frames are skipped while it is nil.
    var atlas: GlyphAtlas?

    init?(layer: CAMetalLayer) {
        guard let ctx = RenderContext.shared else { return nil }
        self.ctx = ctx
        self.layer = layer
        layer.device = ctx.device
        layer.pixelFormat = RenderContext.outputFormat
        layer.framebufferOnly = true
        layer.isOpaque = true
        layer.maximumDrawableCount = 3
    }

    /// Draws and presents one frame. `uniforms` must carry `atlas`'s glyphCount/cols/rows.
    func render(uniforms: Uniforms, glow: Bool) {
        guard atlas != nil, let drawable = layer.nextDrawable(),
              let cmd = ctx.queue.makeCommandBuffer() else { return }
        cmd.label = "MatrixSaver frame"
        guard encode(cmd, uniforms: uniforms, glow: glow, into: drawable.texture) else { return }
        cmd.present(drawable)
        cmd.commit()
    }

    /// Draws one frame into `target` (a `RenderContext.outputFormat` render target) and
    /// commits it. Used for offscreen capture; returns nil if nothing was drawn.
    func render(uniforms: Uniforms, glow: Bool, into target: MTLTexture) -> MTLCommandBuffer? {
        guard let cmd = ctx.queue.makeCommandBuffer() else { return nil }
        cmd.label = "MatrixSaver offscreen frame"
        guard encode(cmd, uniforms: uniforms, glow: glow, into: target) else { return nil }
        cmd.commit()
        return cmd
    }

    private func encode(_ cmd: MTLCommandBuffer, uniforms: Uniforms, glow: Bool, into target: MTLTexture) -> Bool {
        guard let atlas else { return false }
        ensureTextures(width: target.width, height: target.height)
        guard let scene, let glowA, let glowB else { return false }

        var u = uniforms
        draw(cmd, into: scene, pipeline: ctx.rainPipeline, label: "rain") { enc in
            enc.setFragmentBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 0)
            enc.setFragmentTexture(atlas.texture, index: 0)
        }

        if glow {
            draw(cmd, into: glowA, pipeline: ctx.downsamplePipeline, label: "downsample") { enc in
                enc.setFragmentTexture(scene, index: 0)
            }
            draw(cmd, into: glowB, pipeline: ctx.blurPipeline, label: "blurH") { enc in
                var dir = SIMD2<Float>(1, 0)
                enc.setFragmentTexture(glowA, index: 0)
                enc.setFragmentBytes(&dir, length: MemoryLayout<SIMD2<Float>>.stride, index: 0)
            }
            draw(cmd, into: glowA, pipeline: ctx.blurPipeline, label: "blurV") { enc in
                var dir = SIMD2<Float>(0, 1)
                enc.setFragmentTexture(glowB, index: 0)
                enc.setFragmentBytes(&dir, length: MemoryLayout<SIMD2<Float>>.stride, index: 0)
            }
        }

        draw(cmd, into: target, pipeline: ctx.compositePipeline, label: "composite") { enc in
            var strength: Float = glow ? 1.0 : 0.0
            enc.setFragmentBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 0)
            enc.setFragmentBytes(&strength, length: MemoryLayout<Float>.stride, index: 1)
            enc.setFragmentTexture(scene, index: 0)
            enc.setFragmentTexture(glow ? glowA : ctx.blackTexture, index: 1)
        }
        return true
    }

    private func draw(_ cmd: MTLCommandBuffer, into texture: MTLTexture, pipeline: MTLRenderPipelineState,
                      label: String, bind: (MTLRenderCommandEncoder) -> Void) {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .dontCare  // full-screen triangle covers every pixel
        pass.colorAttachments[0].storeAction = .store
        guard let enc = cmd.makeRenderCommandEncoder(descriptor: pass) else { return }
        enc.label = label
        enc.setRenderPipelineState(pipeline)
        enc.setFragmentSamplerState(ctx.sampler, index: 0)
        bind(enc)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        enc.endEncoding()
    }

    /// Drops the intermediate render targets; the next `render` recreates them.
    func releaseResources() {
        scene = nil
        glowA = nil
        glowB = nil
        size = (0, 0)
    }

    private func ensureTextures(width: Int, height: Int) {
        guard width != size.width || height != size.height || scene == nil else { return }
        size = (width, height)
        scene = makeTarget(width: width, height: height, label: "scene")
        let gw = max(width / 4, 1)
        let gh = max(height / 4, 1)
        glowA = makeTarget(width: gw, height: gh, label: "glowA")
        glowB = makeTarget(width: gw, height: gh, label: "glowB")
    }

    private func makeTarget(width: Int, height: Int, label: String) -> MTLTexture? {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: RenderContext.intermediateFormat,
                                                         width: width, height: height, mipmapped: false)
        d.usage = [.renderTarget, .shaderRead]
        d.storageMode = .private
        let t = ctx.device.makeTexture(descriptor: d)
        t?.label = label
        return t
    }
}
