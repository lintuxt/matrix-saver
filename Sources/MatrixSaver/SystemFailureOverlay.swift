import AppKit
import QuartzCore

/// Film-style "SYSTEM FAILURE" alert box, centred over the rain.
final class SystemFailureOverlay: NSView {
    private let box = CALayer()
    private let text = CATextLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.opacity = 0

        box.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
        box.shadowOpacity = 0.9
        box.shadowOffset = .zero
        text.alignmentMode = .center
        box.addSublayer(text)
        layer?.addSublayer(box)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// Sets tint and opacity; called every frame, so changes are not animated.
    func update(tint: SIMD4<Float>, opacity: Float, scale: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        layer?.opacity = opacity
        guard opacity > 0 else { return }

        let color = NSColor(red: CGFloat(tint.x), green: CGFloat(tint.y), blue: CGFloat(tint.z), alpha: 1)
        let bright = color.blended(withFraction: 0.25, of: .white) ?? color
        box.borderColor = color.cgColor
        box.shadowColor = color.cgColor
        text.contentsScale = scale

        // Small and understated like the film's alert: ~2.6% of the view height, so the
        // box spans about a sixth of the screen width. The preview thumbnail scales down too.
        let fontSize = max(bounds.height * 0.026, 7)
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: bright, .kern: fontSize * 0.18,
        ]
        let label = NSAttributedString(string: "SYSTEM FAILURE", attributes: attributes)
        text.string = label

        let textSize = label.size()
        let padding = CGSize(width: fontSize * 0.9, height: fontSize * 0.5)
        let boxSize = CGSize(width: textSize.width + padding.width * 2,
                             height: textSize.height + padding.height * 2)
        box.frame = CGRect(x: (bounds.width - boxSize.width) / 2, y: (bounds.height - boxSize.height) / 2,
                           width: boxSize.width, height: boxSize.height).integral
        box.borderWidth = max(fontSize * 0.06, 1)
        box.shadowRadius = fontSize * 0.3
        text.frame = CGRect(x: 0, y: padding.height, width: box.frame.width, height: textSize.height)
    }
}
