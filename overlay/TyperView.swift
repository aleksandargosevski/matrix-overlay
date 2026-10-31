import AppKit
import CoreText
import QuartzCore

// "Someone is typing code by hand": variable rhythm, thinking pauses, auto-indent,
// occasional typos fixed with backspace, blinking block cursor, scrolling.
final class TyperView: NSView {
    private enum Action { case type(Character, Double), backspace(Double), pause(Double) }

    private let s: Settings
    private let font: CTFont
    private let charW: CGFloat, lineH: CGFloat, descent: CGFloat
    private let pad: CGFloat = 48
    private let textColor: CGColor, dimColor: CGColor, glowColor: CGColor

    private let snippets: [String]
    private var snippetIndex: Int
    private var source: [Character] = []
    private var pos = 0
    private var queue: [Action] = []
    private var lines: [String] = [""]
    private var nextAt: CFTimeInterval = 0
    private var lastTypedAt: CFTimeInterval = 0
    private var finishedAt: CFTimeInterval?
    private var timer: Timer?

    private var maxLines: Int { max(1, Int((bounds.height - 2 * pad) / lineH)) }
    private var maxCols: Int { max(10, Int((bounds.width - 2 * pad) / charW)) }

    init(frame: NSRect, settings: Settings, snippets: [String], startIndex: Int) {
        s = settings
        let size = settings.typerFontSize
        if !settings.typerFont.isEmpty, let f = NSFont(name: settings.typerFont, size: size) {
            font = f as CTFont
        } else {
            font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular) as CTFont
        }
        var glyph = CGGlyph(0)
        var ch: UniChar = 0x4D // "M"
        CTFontGetGlyphsForCharacters(font, &ch, &glyph, 1)
        var adv = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, &adv, 1)
        charW = adv.width > 0 ? adv.width : size * 0.6
        lineH = (size * 1.45).rounded()
        descent = CTFontGetDescent(font)
        textColor = settings.color.cg()
        dimColor = settings.color.cg(0.55)
        glowColor = settings.color.cg(alpha: 0.6)
        self.snippets = snippets.isEmpty ? [DefaultContent.snippets[0]] : snippets
        snippetIndex = startIndex % self.snippets.count
        super.init(frame: frame)
        loadSnippet()
        nextAt = CACurrentMediaTime() + 0.6
        let t = Timer(timeInterval: 1 / max(30, settings.fps), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
    required init?(coder: NSCoder) { fatalError() }

    func stop() { timer?.invalidate(); timer = nil }

    private func loadSnippet() {
        source = Array(snippets[snippetIndex].replacingOccurrences(of: "\t", with: "    "))
        pos = 0
        queue = []
        lines = [""]
        finishedAt = nil
    }

    // MARK: rhythm
    private func charDelay(for c: Character) -> Double {
        let base = 1 / s.typerCPS
        var d = base * Double.random(in: 0.45...1.6)
        if Double.random(in: 0...1) < 0.04 { d += Double.random(in: 0.4...1.4) }  // thinking
        if ".;,)}".contains(c) { d += base * 1.5 }
        if c == " " { d *= 0.7 }
        return d
    }

    private func enqueueNext() {
        guard pos < source.count else { return }
        let c = source[pos]
        pos += 1

        if c == "\n" {
            queue.append(.type("\n", Double.random(in: 0.25...0.8)))
            // auto-indent: leading whitespace appears instantly, like an editor
            while pos < source.count, source[pos] == " " {
                queue.append(.type(" ", 0))
                pos += 1
            }
            return
        }

        if c.isLetter, Double.random(in: 0...1) < s.typerTypoRate {
            let wrongCount = Int.random(in: 1...3)
            for _ in 0..<wrongCount {
                queue.append(.type(TyperView.nearbyKey(c), charDelay(for: c)))
            }
            queue.append(.pause(Double.random(in: 0.2...0.6)))
            for _ in 0..<wrongCount { queue.append(.backspace(Double.random(in: 0.05...0.12))) }
        }
        queue.append(.type(c, charDelay(for: c)))
    }

    private static let rowsQWERTY = ["qwertyuiop", "asdfghjkl", "zxcvbnm"].map(Array.init)
    private static func nearbyKey(_ c: Character) -> Character {
        let lower = Character(c.lowercased())
        for row in rowsQWERTY {
            if let i = row.firstIndex(of: lower) {
                let j = min(row.count - 1, max(0, i + (Bool.random() ? 1 : -1)))
                let k = row[j]
                return c.isUppercase ? Character(k.uppercased()) : k
            }
        }
        return "x"
    }

    // MARK: loop
    private func tick() {
        let now = CACurrentMediaTime()
        var steps = 0
        while now >= nextAt, steps < 50 {
            if queue.isEmpty { enqueueNext() }
            guard !queue.isEmpty else { break }
            let a = queue.removeFirst()
            steps += 1
            switch a {
            case .type(let c, let d): apply(c); lastTypedAt = now; nextAt += d
            case .backspace(let d):
                if !lines[lines.count - 1].isEmpty { lines[lines.count - 1].removeLast() }
                lastTypedAt = now; nextAt += d
            case .pause(let d): nextAt += d
            }
            if nextAt < now - 0.5 { nextAt = now }
        }

        if queue.isEmpty, pos >= source.count {
            if finishedAt == nil { finishedAt = now }
            if s.typerLoop, let f = finishedAt, now - f > 4 {
                snippetIndex = (snippetIndex + 1) % snippets.count
                loadSnippet()
                nextAt = now + 0.8
            }
        }
        needsDisplay = true
    }

    private func apply(_ c: Character) {
        if c == "\n" {
            lines.append("")
        } else {
            if lines[lines.count - 1].count >= maxCols { lines.append("") }
            lines[lines.count - 1].append(c)
        }
        if lines.count > maxLines { lines.removeFirst(lines.count - maxLines) }
    }

    // MARK: draw
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
        ctx.setFillColor(CGColor(gray: 0, alpha: s.typerOpacity))
        ctx.fill(bounds)
        ctx.textMatrix = .identity
        ctx.setShadow(offset: .zero, blur: 8, color: glowColor)

        let top = bounds.height - pad
        var cursorX = pad, cursorY = top - lineH
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let isComment = trimmed.hasPrefix("//") || trimmed.hasPrefix("#") || trimmed.hasPrefix("--")
            let attrs: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): isComment ? dimColor : textColor,
            ]
            let ctLine = CTLineCreateWithAttributedString(NSAttributedString(string: line, attributes: attrs))
            let y = top - CGFloat(i + 1) * lineH
            ctx.textPosition = CGPoint(x: pad, y: y + descent)
            CTLineDraw(ctLine, ctx)
            if i == lines.count - 1 {
                cursorX = pad + CGFloat(line.count) * charW
                cursorY = y
            }
        }

        let now = CACurrentMediaTime()
        let typing = now - lastTypedAt < 0.5
        if typing || fmod(now, 1.06) < 0.53 {
            ctx.setFillColor(textColor)
            ctx.fill(CGRect(x: cursorX, y: cursorY + descent * 0.3, width: charW, height: lineH * 0.8))
        }
    }
}
