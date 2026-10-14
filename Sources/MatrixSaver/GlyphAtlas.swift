import AppKit
import CoreText
import Metal
import os

/// Single-channel glyph atlas consumed by `rainFragment`.
///
/// Layout: glyph `g` sits at grid cell (g % cols, g / cols), row 0 at the TOP of the
/// texture. Each cell is one rain cell in pixels: round(cellW × scale) × round(cellH × scale).
@MainActor
final class GlyphAtlas {
    static let cols = 10
    static let rows = 8

    /// Half-width katakana U+FF66…U+FF9D (56), digits (10), symbols (11) = 77 glyphs.
    static let glyphs: [Character] = {
        var chars: [Character] = (0xFF66...0xFF9D).map { Character(UnicodeScalar($0)!) }
        chars += Array("0123456789")
        chars += Array(":.\"=*+-<>\u{00A6}|")
        return chars
    }()

    static let katakanaCount = 56

    let texture: MTLTexture
    let glyphCount: Int
    let cellPixelSize: (width: Int, height: Int)
    var cols: Int { Self.cols }
    var rows: Int { Self.rows }

    private static let log = Logger(subsystem: "ai.lintuxt.MatrixSaver", category: "GlyphAtlas")

    private struct Key: Hashable {
        let device: ObjectIdentifier
        let glyphSize: Double
        let scale: Double
    }

    private static var cache: [Key: GlyphAtlas] = [:]

    /// Process-wide cache keyed by (scale, glyphSize). Main thread only.
    static func shared(device: MTLDevice, glyphSize: Double, scale: Double) -> GlyphAtlas? {
        let key = Key(device: ObjectIdentifier(device), glyphSize: glyphSize, scale: scale)
        if let hit = cache[key] { return hit }
        guard let atlas = GlyphAtlas(device: device, glyphSize: glyphSize, scale: scale) else { return nil }
        cache[key] = atlas
        return atlas
    }

    private init?(device: MTLDevice, glyphSize: Double, scale: Double) {
        let cellW = max(Int((glyphSize * 0.72 * scale).rounded()), 1)
        let cellH = max(Int((glyphSize * scale).rounded()), 1)
        let width = cellW * Self.cols
        let height = cellH * Self.rows

        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            Self.log.error("atlas bitmap context failed (\(width)x\(height))")
            return nil
        }
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        ctx.setAllowsFontSmoothing(false)
        ctx.setShouldSmoothFonts(false)
        ctx.setFillColor(gray: 1, alpha: 1)

        let font = Self.makeFont(size: glyphSize * 0.78 * scale)
        let ascent = CTFontGetAscent(font)
        let descent = CTFontGetDescent(font)
        let attrs: [CFString: Any] = [kCTFontAttributeName: font,
                                      kCTForegroundColorFromContextAttributeName: true]

        for (g, ch) in Self.glyphs.enumerated() {
            let col = g % Self.cols
            let row = g / Self.cols
            // CG origin is bottom-left; bitmap memory row 0 (texture top) is CG's top.
            let cx = (Double(col) + 0.5) * Double(cellW)
            let cy = Double(height) - (Double(row) + 0.5) * Double(cellH)

            let str = CFAttributedStringCreate(nil, String(ch) as CFString, attrs as CFDictionary)!
            let line = CTLineCreateWithAttributedString(str)
            let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            let midX = bounds.isEmpty ? CTLineGetTypographicBounds(line, nil, nil, nil) / 2 : bounds.midX

            ctx.saveGState()
            ctx.translateBy(x: cx, y: cy)
            if g < Self.katakanaCount { ctx.scaleBy(x: -1, y: 1) }
            // Horizontally center the ink; vertically center the font's line box.
            ctx.textPosition = CGPoint(x: -midX, y: (descent - ascent) / 2)
            CTLineDraw(line, ctx)
            ctx.restoreGState()
        }

        guard let data = ctx.data else { return nil }
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: width,
                                                            height: height, mipmapped: false)
        desc.usage = .shaderRead
        guard let tex = device.makeTexture(descriptor: desc) else {
            Self.log.error("atlas texture allocation failed")
            return nil
        }
        tex.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                    withBytes: data, bytesPerRow: ctx.bytesPerRow)
        tex.label = "GlyphAtlas \(glyphSize)pt @\(scale)x"

        texture = tex
        glyphCount = Self.glyphs.count
        cellPixelSize = (cellW, cellH)
    }

    private static func makeFont(size: Double) -> CTFont {
        let name = "HiraginoSans-W4"
        let font = CTFontCreateWithName(name as CFString, size, nil)
        if CTFontCopyPostScriptName(font) as String == name { return font }
        log.notice("\(name) unavailable; falling back to monospaced system font")
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular) as CTFont
    }
}
