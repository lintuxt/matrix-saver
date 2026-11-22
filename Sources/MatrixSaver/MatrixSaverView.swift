import AppKit
import QuartzCore
import ScreenSaver
import SwiftUI
import os

/// Principal class of the saver bundle. One instance per display (plus previews).
///
/// legacyScreenSaver never destroys old instances and rarely calls `stopAnimation`, so this
/// view owns its lifecycle: it renders only between `startAnimation` and a stop signal
/// (`stopAnimation` or distributed `willstop`), and an older instance for the same screen
/// turns itself into an inert "lame duck" when a newer one starts.
@objc(MatrixSaverView)
final class MatrixSaverView: ScreenSaverView {
    private static let log = Logger(subsystem: "ai.lintuxt.MatrixSaver", category: "View")
    private static let instanceStarted = Notification.Name("ai.lintuxt.MatrixSaver.instanceStarted")
    private static let willStop = Notification.Name("com.apple.screensaver.willstop")
    private static let didStart = Notification.Name("com.apple.screensaver.didstart")
    private static let exitOnStopKey = "ExitOnStop"
    /// Hidden default: keep the System Failure alert on screen (for checking its look).
    private static let systemFailureAlwaysKey = "SystemFailureAlways"
    static let seed: UInt32 = 0x4D41_5452  // "MATR"
    private static var nextSerial = 0

    private let serial: Int
    private var metalView: MetalLayerView? = MetalLayerView()
    private var failureOverlay: SystemFailureOverlay? = SystemFailureOverlay()
    private var renderer: RainRenderer?
    private var settings = SaverSettings.load()
    private var systemFailureAlways = false

    private var isPreviewMode: Bool
    private var instanceKey = "unknown"
    private var isLameDuck = false
    /// True once the host has called `startAnimation`; never-started instances must not render.
    private var hasStarted = false
    private var isRunning: Bool { displayLink != nil }

    private var displayLink: CADisplayLink?
    private var startDate = Date()
    private var exitWork: DispatchWorkItem?

    private var viewOriginWorld = CGPoint.zero
    private var worldRows: CGFloat = 0
    private var backingScale: CGFloat = 2

    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var sheetWindow: NSWindow?

    private var pid: Int32 { ProcessInfo.processInfo.processIdentifier }

    // MARK: - Init

    override init?(frame: NSRect, isPreview: Bool) {
        Self.nextSerial += 1
        serial = Self.nextSerial
        isPreviewMode = Self.detectPreview(isPreview: isPreview, rect: frame)
        super.init(frame: frame, isPreview: isPreview)
        commonInit()
    }

    required init?(coder: NSCoder) {
        Self.nextSerial += 1
        serial = Self.nextSerial
        isPreviewMode = false
        super.init(coder: coder)
        isPreviewMode = Self.detectPreview(isPreview: isPreview, rect: bounds)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        animationTimeInterval = 1.0  // frames come from our display link; keep the host timer idle

        if let metalView {
            metalView.frame = bounds
            metalView.autoresizingMask = [.width, .height]
            addSubview(metalView)
        }
        if let failureOverlay {
            failureOverlay.frame = bounds
            failureOverlay.autoresizingMask = [.width, .height]
            addSubview(failureOverlay)  // above the rain
        }
        if let metalLayer = metalView?.metalLayer {
            renderer = RainRenderer(layer: metalLayer)
        }
        if renderer == nil { Self.log.error("renderer unavailable (serial \(self.serial))") }

        let local = NotificationCenter.default
        observe(local, Self.instanceStarted) { [weak self] note in self?.otherInstanceStarted(note) }
        observe(local, SaverSettings.didChange) { [weak self] _ in self?.settingsChanged() }
        observe(local, NSApplication.didChangeScreenParametersNotification) { [weak self] _ in
            self?.updateGeometry()
        }
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Self.willStop) { [weak self] _ in self?.screensaverWillStop() }
        observe(distributed, Self.didStart) { [weak self] _ in self?.screensaverDidStart() }

        Self.log.info("init serial=\(self.serial) preview=\(self.isPreviewMode) pid=\(self.pid)")
    }

    deinit {
        MainActor.assumeIsolated {
            displayLink?.invalidate()
            exitWork?.cancel()
            for (center, token) in observers { center.removeObserver(token) }
        }
    }

    /// Observers are delivered on the main queue, so the closure may assume main-actor isolation.
    private func observe(_ center: NotificationCenter, _ name: Notification.Name,
                         _ handler: @escaping @MainActor (Notification) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { note in
            // Delivered on the main queue; the notification never leaves the main thread.
            nonisolated(unsafe) let note = note
            MainActor.assumeIsolated { handler(note) }
        }
        observers.append((center, token))
    }

    private static func detectPreview(isPreview: Bool, rect: NSRect) -> Bool {
        isPreview || rect.width < 400 || rect == .zero
    }

    // MARK: - Lifecycle

    override func startAnimation() {
        if isLameDuck { return }
        super.startAnimation()
        hasStarted = true
        exitWork?.cancel()
        exitWork = nil
        isPreviewMode = Self.detectPreview(isPreview: isPreview, rect: bounds)
        instanceKey = currentInstanceKey()
        settings = SaverSettings.load()
        systemFailureAlways = SaverSettings.store()?.bool(forKey: Self.systemFailureAlwaysKey) == true
        Self.log.info("""
            start serial=\(self.serial) preview=\(self.isPreviewMode) \
            key=\(self.instanceKey, privacy: .public) pid=\(self.pid)
            """)
        startLink()
        NotificationCenter.default.post(name: Self.instanceStarted, object: self)
    }

    override func stopAnimation() {
        Self.log.info("stop serial=\(self.serial) preview=\(self.isPreviewMode) pid=\(self.pid)")
        stopLink()
        releaseGPUResources()
        super.stopAnimation()
    }

    private func screensaverWillStop() {
        guard !isLameDuck, !isPreviewMode else { return }
        Self.log.info("""
            willstop serial=\(self.serial) preview=\(self.isPreviewMode) \
            key=\(self.instanceKey, privacy: .public) pid=\(self.pid)
            """)
        stopLink()
        releaseGPUResources()
        guard !isPreviewMode, SaverSettings.store()?.bool(forKey: Self.exitOnStopKey) == true else { return }
        exitWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.isRunning else { return }
                Self.log.info("ExitOnStop: exiting pid=\(self.pid)")
                exit(0)
            }
        }
        exitWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    private func screensaverDidStart() {
        guard !isPreviewMode, hasStarted, !isRunning, !isLameDuck, window != nil else { return }
        startLink()
    }

    private func otherInstanceStarted(_ note: Notification) {
        guard !isLameDuck, let other = note.object as? MatrixSaverView, other !== self,
              other.serial > serial else { return }
        // Compare against our LIVE key: never-started instances still hold "unknown".
        let liveKey = currentInstanceKey()
        // An unresolved ("unknown") key on either side must never lame-duck anyone.
        guard !other.instanceKey.contains("unknown"), !liveKey.contains("unknown"),
              other.instanceKey == liveKey else { return }
        instanceKey = liveKey
        becomeLameDuck(replacedBy: other.serial)
    }

    private func becomeLameDuck(replacedBy newer: Int) {
        Self.log.info("""
            lameDuck serial=\(self.serial) replacedBy=\(newer) preview=\(self.isPreviewMode) \
            key=\(self.instanceKey, privacy: .public) pid=\(self.pid)
            """)
        isLameDuck = true
        stopLink()
        exitWork?.cancel()
        exitWork = nil
        for (center, token) in observers { center.removeObserver(token) }
        observers.removeAll()
        releaseGPUResources()
        renderer = nil
        metalView?.removeFromSuperview()
        metalView = nil  // frees the CAMetalLayer and its drawable pool
        failureOverlay?.removeFromSuperview()
        failureOverlay = nil
    }

    private func currentInstanceKey() -> String {
        let prefix = Self.detectPreview(isPreview: isPreview, rect: bounds) ? "p" : "f"
        guard let window else { return "\(prefix)-unknown" }
        var screen = window.screen
        if screen == nil {
            screen = NSScreen.screens.max { a, b in
                let ia = a.frame.intersection(window.frame)
                let ib = b.frame.intersection(window.frame)
                return ia.width * ia.height < ib.width * ib.height
            }
            if let s = screen, s.frame.intersection(window.frame).isNull { screen = nil }
        }
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen?.deviceDescription[key] as? NSNumber else { return "\(prefix)-unknown" }
        return "\(prefix)-\(number.stringValue)"
    }

    // MARK: - Display link

    private func startLink() {
        guard !isLameDuck, displayLink == nil, renderer != nil else { return }
        startDate = Date()
        updateGeometry(starting: true)
        let link = displayLink(target: DisplayLinkProxy(self), selector: #selector(DisplayLinkProxy.tick(_:)))
        let fps: Float = isPreviewMode ? 30 : 60
        link.preferredFrameRateRange = CAFrameRateRange(minimum: fps / 2, maximum: fps, preferred: fps)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    /// Drops intermediate textures and shrinks the drawable pool to 1×1.
    /// `updateGeometry(starting:)` (called by `startLink`) restores the drawable size on restart.
    private func releaseGPUResources() {
        renderer?.releaseResources()
        metalView?.metalLayer?.drawableSize = CGSize(width: 1, height: 1)
    }

    fileprivate func renderFrame() {
        guard let renderer, let atlas = renderer.atlas else { return }
        let cell = cellSize
        var u = Uniforms()
        u.viewOriginWorld = SIMD2(Float(viewOriginWorld.x), Float(viewOriginWorld.y))
        u.cellSize = SIMD2(Float(cell.width), Float(cell.height))
        u.tint = settings.palette.tint
        u.scale = Float(backingScale)
        let now = Date().timeIntervalSince1970
        // With the alert on, the rain freezes while it's up (as in the film's last shot).
        u.time = RainMath.wrappedTime(settings.systemFailure ? SystemFailure.rainTime(seed: Self.seed, now: now) : now)
        u.speed = Float(settings.speed)
        u.density = Float(settings.density)
        u.worldRows = Float(worldRows)
        u.fade = Float(min(1, Date().timeIntervalSince(startDate) / 1.0))
        u.seed = Self.seed
        u.glyphCount = UInt32(atlas.glyphCount)
        u.atlasCols = UInt32(atlas.cols)
        u.atlasRows = UInt32(atlas.rows)
        renderer.render(uniforms: u, glow: settings.glow && !isPreviewMode)

        let alert: Float = if systemFailureAlways { 1 } else if settings.systemFailure {
            SystemFailure.opacity(seed: Self.seed, now: now)
        } else { 0 }
        failureOverlay?.update(tint: settings.palette.tint, opacity: alert * u.fade, scale: backingScale)
    }

    // MARK: - Geometry & settings

    /// Glyph size rounded to whole points: it keys the process-wide atlas cache.
    private var glyphSize: Double { settings.glyphSize.rounded() }
    private var cellSize: CGSize { CGSize(width: glyphSize * 0.72, height: glyphSize) }

    private func updateGeometry(starting: Bool = false) {
        guard !isLameDuck else { return }
        backingScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        isPreviewMode = Self.detectPreview(isPreview: isPreview, rect: bounds)

        if !isPreviewMode, let window {
            let geometry = WorldGeometry(screenFrames: NSScreen.screens.map(\.frame))
            let rect = window.convertToScreen(convert(bounds, to: nil))
            viewOriginWorld = geometry.worldOrigin(of: rect)
            worldRows = geometry.rows(cellHeight: cellSize.height)
        } else {
            viewOriginWorld = .zero
            worldRows = WorldGeometry(screenFrames: [bounds]).rows(cellHeight: cellSize.height)
        }

        // While stopped the drawable pool stays shrunk to 1×1 (see releaseGPUResources).
        if isRunning || starting, let metalLayer = metalView?.metalLayer {
            metalLayer.contentsScale = backingScale
            metalLayer.drawableSize = CGSize(width: max(bounds.width * backingScale, 1),
                                             height: max(bounds.height * backingScale, 1))
        }
        updateAtlas()
    }

    private func updateAtlas() {
        guard let renderer else { return }
        renderer.atlas = GlyphAtlas.shared(device: renderer.device, glyphSize: glyphSize,
                                           scale: Double(backingScale))
    }

    private func settingsChanged() {
        settings = SaverSettings.load()
        updateGeometry()  // glyph size affects rows and the atlas
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateGeometry()
        if hasStarted, !isLameDuck, window != nil {
            instanceKey = currentInstanceKey()
            NotificationCenter.default.post(name: Self.instanceStarted, object: self)
        }
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateGeometry()
    }

    override func layout() {
        super.layout()
        updateGeometry()
    }

    // MARK: - Drawing fallback

    override func draw(_ rect: NSRect) {
        NSColor.black.setFill()
        rect.fill()
    }

    override func animateOneFrame() {}

    // MARK: - Configure sheet

    override var hasConfigureSheet: Bool { true }

    override var configureSheet: NSWindow? {
        // Fresh window each time so the form starts from the saved settings.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 300),
                              styleMask: [.titled], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        window.title = "Matrix"
        let sheet = ConfigureSheet(initial: SaverSettings.load()) { [weak window] in
            guard let window else { return }
            if let parent = window.sheetParent {
                parent.endSheet(window)
            } else {
                window.close()
            }
        }
        window.contentViewController = NSHostingController(rootView: sheet)
        sheetWindow = window
        return window
    }
}

/// Layer-hosting view backed by a CAMetalLayer.
private final class MetalLayerView: NSView {
    var metalLayer: CAMetalLayer? { layer as? CAMetalLayer }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
    }

    override func makeBackingLayer() -> CALayer {
        let layer = CAMetalLayer()
        layer.backgroundColor = NSColor.black.cgColor
        return layer
    }
}

/// Display-link target that holds the view weakly (CADisplayLink retains its target).
@MainActor
private final class DisplayLinkProxy: NSObject {
    private weak var view: MatrixSaverView?

    init(_ view: MatrixSaverView) {
        self.view = view
    }

    @objc func tick(_ link: CADisplayLink) {
        guard let view else {
            link.invalidate()
            return
        }
        view.renderFrame()
    }
}
