import AppKit
import CoreText

// MARK: - Config
// Argumenti: --idle 60 --size 16 --opacity 0.92 --no-media-check
struct Config {
    var idleSeconds: Double? = nil      // nil = hotkey mod: prikaži odmah, izađi posle gašenja
    var fontSize: CGFloat = 16
    var opacity: CGFloat = 0.92
    var fps: Double = 30
    var mediaCheck = true
}

var config = Config()
var argIt = Array(CommandLine.arguments.dropFirst()).makeIterator()
while let a = argIt.next() {
    switch a {
    case "--idle":           config.idleSeconds = Double(argIt.next() ?? "60")
    case "--size":           config.fontSize = CGFloat(Double(argIt.next() ?? "16") ?? 16)
    case "--opacity":        config.opacity = CGFloat(Double(argIt.next() ?? "0.92") ?? 0.92)
    case "--no-media-check": config.mediaCheck = false
    default: break
    }
}

func log(_ s: String) {
    FileHandle.standardError.write("[\(Date())] \(s)\n".data(using: .utf8)!)
}

func secondsIdle() -> Double {
    CGEventSource.secondsSinceLastEventType(.combinedSessionState,
                                            eventType: CGEventType(rawValue: ~0)!)
}

func screenIsLocked() -> Bool {
    guard let d = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
    return (d["CGSSessionScreenIsLocked"] as? Bool) == true
}

// MARK: - Media / call detection (YouTube, Meet, Zoom, Teams...)
// Ako bilo koji proces OSIM "keep-awake" alata drži display assertion (video u browseru,
// Zoom...), ili postoji WebRTC/call assertion, ne palimo matrix.
enum Media {
    static let ignoredOwners = ["caffeinate", "Raycast", "Amphetamine", "KeepingYouAwake",
                                "Lungo", "Theine", "powerd", "WindowServer", "coreaudiod"]
    static let displayTypes = ["PreventUserIdleDisplaySleep", "NoDisplaySleepAssertion"]
    static let callHints = ["WebRTC", "Video Wake Lock", "zoom.us", "Microsoft Teams",
                            "FaceTime", "Slack", "Discord", "Webex"]

    static func blockingReason() -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        p.arguments = ["-g", "assertions"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard let out = String(data: data, encoding: .utf8) else { return nil }

        for raw in out.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("pid "),
                  let open = line.firstIndex(of: "("),
                  let close = line.firstIndex(of: ")") , open < close else { continue }
            let owner = String(line[line.index(after: open)..<close])
            if ignoredOwners.contains(where: { owner.hasPrefix($0) }) { continue }
            if callHints.contains(where: { line.localizedCaseInsensitiveContains($0) }) {
                return "\(owner): call/video assertion"
            }
            if displayTypes.contains(where: { line.contains($0) }) {
                return "\(owner): display assertion"
            }
        }
        return nil
    }
}

// MARK: - Rain view
final class RainView: NSView {
    private struct Drop { var y: Double; var speed: Double; var length: Int }
    private static let levels = 12

    private let font: CTFont
    private let cellW: CGFloat, cellH: CGFloat
    private let bgAlpha: CGFloat
    private let colors: [CGColor]
    private let headColor = CGColor(srgbRed: 0.85, green: 1, blue: 0.88, alpha: 1)
    private let glowColor = CGColor(srgbRed: 0.3, green: 1, blue: 0.4, alpha: 0.9)
    private var cols = 0, rows = 0
    private var drops: [Drop] = []
    private var grid: [CGGlyph] = []
    private var pool: [CGGlyph] = []
    private var timer: Timer?

    init(frame: NSRect, fontSize: CGFloat, bgAlpha: CGFloat, fps: Double) {
        font = CTFontCreateWithName("HiraginoSans-W3" as CFString, fontSize, nil)
        cellW = (fontSize * 0.75).rounded()
        cellH = (fontSize * 1.2).rounded()
        self.bgAlpha = bgAlpha
        colors = (0..<RainView.levels).map { i in
            let t = CGFloat(i + 1) / CGFloat(RainView.levels)
            return CGColor(srgbRed: 0, green: 0.35 + 0.65 * t, blue: 0.15 * t, alpha: t)
        }
        super.init(frame: frame)
        pool = RainView.makePool(font: font)
        setupGrid()
        let t = Timer(timeInterval: 1 / fps, repeats: true) { [weak self] _ in
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

// MARK: - Overlay windows (po jedan na svaki monitor)
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class Overlay {
    private let config: Config
    private(set) var windows: [OverlayWindow] = []
    private(set) var shownAt = Date.distantPast
    private var cursorHidden = false
    private var previousApp: NSRunningApplication?
    var onDismiss: (() -> Void)?
    var isShown: Bool { !windows.isEmpty }

    init(config: Config) { self.config = config }

    func show() {
        guard windows.isEmpty else { return }
        shownAt = Date()
        previousApp = NSWorkspace.shared.frontmostApplication
        for screen in NSScreen.screens {
            let w = OverlayWindow(contentRect: screen.frame, styleMask: .borderless,
                                  backing: .buffered, defer: false)
            w.setFrame(screen.frame, display: false)
            w.level = .screenSaver
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = false
            w.isReleasedWhenClosed = false
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            w.contentView = RainView(frame: NSRect(origin: .zero, size: screen.frame.size),
                                     fontSize: config.fontSize, bgAlpha: config.opacity, fps: config.fps)
            w.alphaValue = 0
            w.orderFrontRegardless()
            windows.append(w)
        }
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKey()
        if !cursorHidden { NSCursor.hide(); cursorHidden = true }
        let ws = windows
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.8
            ws.forEach { $0.animator().alphaValue = 1 }
        }
    }

    func hide() {
        guard !windows.isEmpty else { return }
        let ws = windows
        windows = []
        if cursorHidden { NSCursor.unhide(); cursorHidden = false }
        let prev = previousApp
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            ws.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: {
            MainActor.assumeIsolated {
                ws.forEach { ($0.contentView as? RainView)?.stop(); $0.orderOut(nil) }
                if let prev, prev != NSRunningApplication.current { prev.activate() }
                else { NSApp.hide(nil) }
                self.onDismiss?()
            }
        })
    }
}

// MARK: - Main
MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let overlay = Overlay(config: config)

    if config.idleSeconds == nil {
        overlay.onDismiss = { exit(0) }
        DispatchQueue.main.async { overlay.show() }
    } else {
        log("idle mode: \(config.idleSeconds!)s, media check: \(config.mediaCheck)")
    }

    var lastMediaCheck = Date.distantPast
    var lastBlockReason: String? = nil

    let watcher = Timer(timeInterval: 0.25, repeats: true) { _ in
        MainActor.assumeIsolated {
            let idle = secondsIdle()
            if overlay.isShown {
                if Date().timeIntervalSince(overlay.shownAt) > 1.5, idle < 0.3 { overlay.hide() }
                return
            }
            guard let limit = config.idleSeconds, idle >= limit else {
                lastBlockReason = nil
                return
            }
            if screenIsLocked() { return }
            if config.mediaCheck {
                // pmset ne zovemo češće od jednom u 5 s
                if Date().timeIntervalSince(lastMediaCheck) < 5, lastBlockReason != nil { return }
                lastMediaCheck = Date()
                if let reason = Media.blockingReason() {
                    if reason != lastBlockReason { log("skip: \(reason)") }
                    lastBlockReason = reason
                    return
                }
                lastBlockReason = nil
            }
            overlay.show()
        }
    }
    RunLoop.main.add(watcher, forMode: .common)

    NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel]) { e in
        let consumed = MainActor.assumeIsolated { () -> Bool in
            guard overlay.isShown else { return false }
            overlay.hide()
            return true
        }
        return consumed ? nil : e
    }

    app.run()
}
