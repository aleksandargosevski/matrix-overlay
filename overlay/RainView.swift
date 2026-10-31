import AppKit
import CoreText

final class RainView: NSView {
    private struct Drop { var y: Double; var speed: Double; var length: Int }
    private static let levels = 12

    private let font: CTFont
    private let cellW: CGFloat, cellH: CGFloat
    private let bgAlpha: CGFloat
    private let colors: [CGColor]
    private let headColor: CGColor
    private let glowColor: CGColor
    private var cols = 0, rows = 0
    private var drops: [Drop] = []
    private var grid: [CGGlyph] = []
    private var pool: [CGGlyph] = []
    private var timer: Timer?

    init(frame: NSRect, settings s: Settings) {
        let size = s.rainFontSize
        font = CTFontCreateWithName("HiraginoSans-W3" as CFString, size, nil)
        cellW = (size * 0.75).rounded()
        cellH = (size * 1.2).rounded()
        bgAlpha = s.opacity
        colors = (0..<RainView.levels).map { i in
            let t = CGFloat(i + 1) / CGFloat(RainView.levels)
            return s.color.cg(0.35 + 0.65 * t, alpha: t)
        }
        headColor = s.color.mixed(withWhite: 0.8).cg()
        glowColor = s.color.mixed(withWhite: 0.2).cg(alpha: 0.9)
        super.init(frame: frame)
        pool = RainView.makePool(font: font)
        setupGrid()
        let t = Timer(timeInterval: 1 / s.fps, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
    required init?(coder: NSCoder) { fatalError() }

    func stop() { timer?.invalidate(); timer = nil }

    private static func makePool(font: CTFont) -> [CGGlyph] {
        var chars: [UniChar] = (0xFF66...0xFF9D).map { UniChar($0) }   // half-width katakana
        chars += Array("0123456789Z:.=*+-<>|".utf16)
        var glyphs = [CGGlyph](repeating: 0, count: chars.count)
        CTFontGetGlyphsForCharacters(font, chars, &glyphs, chars.count)
        let g = glyphs.filter { $0 != 0 }
        return g.isEmpty ? [CGGlyph(1)] : g
    }

    private func setupGrid() {
        cols = Int(bounds.width / cellW) + 1
        rows = Int(bounds.height / cellH) + 1
        grid = (0..<cols * rows).map { _ in pool.randomElement()! }
        drops = (0..<cols).map { _ in newDrop(initial: true) }
    }

    private func newDrop(initial: Bool) -> Drop {
        let spread = Double(rows) * (initial ? 1.5 : 0.5)
        return Drop(y: -Double.random(in: 0...spread),
                    speed: Double.random(in: 0.25...0.9),
                    length: Int.random(in: 8...max(9, rows * 2 / 3)))
    }

    private func tick() {
        if let w = window, !w.occlusionState.contains(.visible) { return }
        for c in 0..<cols {
            let old = Int(floor(drops[c].y))
            drops[c].y += drops[c].speed
            let new = Int(floor(drops[c].y))
            if new != old, new >= 0, new < rows { grid[new * cols + c] = pool.randomElement()! }
            if new - drops[c].length > rows { drops[c] = newDrop(initial: false) }
        }
        for _ in 0..<max(1, grid.count / 60) { grid[Int.random(in: 0..<grid.count)] = pool.randomElement()! }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
        ctx.setFillColor(CGColor(gray: 0, alpha: bgAlpha))
        ctx.fill(bounds)
        ctx.textMatrix = .identity

        let n = RainView.levels
        var gB = [[CGGlyph]](repeating: [], count: n + 1)
        var pB = [[CGPoint]](repeating: [], count: n + 1)
        let descent = CTFontGetDescent(font)

        for c in 0..<cols {
            let d = drops[c]
            let head = Int(floor(d.y))
            for i in 0..<d.length {
                let r = head - i
                guard r >= 0, r < rows else { continue }
                let b = i == 0 ? n : min(n - 1, Int((1 - Double(i) / Double(d.length)) * Double(n)))
                gB[b].append(grid[r * cols + c])
                pB[b].append(CGPoint(x: CGFloat(c) * cellW,
                                     y: bounds.height - CGFloat(r + 1) * cellH + descent))
            }
        }
        for b in 0...n where !gB[b].isEmpty {
            if b == n {
                ctx.setShadow(offset: .zero, blur: 10, color: glowColor)
                ctx.setFillColor(headColor)
            } else {
                ctx.setShadow(offset: .zero, blur: 0, color: nil)
                ctx.setFillColor(colors[b])
            }
            CTFontDrawGlyphs(font, gB[b], pB[b], gB[b].count, ctx)
        }
    }
}
