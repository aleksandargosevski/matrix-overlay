import AppKit

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class Overlay {
    private(set) var windows: [OverlayWindow] = []
    private(set) var shownAt = Date.distantPast
    private var cursorHidden = false
    private var previousApp: NSRunningApplication?
    var onDismiss: (() -> Void)?
    var isShown: Bool { !windows.isEmpty }

    func show(settings s: Settings) {
        guard windows.isEmpty else { return }
        shownAt = Date()
        previousApp = NSWorkspace.shared.frontmostApplication

        var anim = s.animation
        if anim == "random" { anim = ["rain", "typer"].randomElement()! }
        let snippets = anim == "typer" ? Overlay.loadSnippets(s.typerTextFile) : []
        let start = snippets.isEmpty ? 0 : Int.random(in: 0..<snippets.count)

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
            let frame = NSRect(origin: .zero, size: screen.frame.size)
            w.contentView = anim == "typer"
                ? TyperView(frame: frame, settings: s, snippets: snippets, startIndex: start)
                : RainView(frame: frame, settings: s)
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
                ws.forEach { w in
                    (w.contentView as? RainView)?.stop()
                    (w.contentView as? TyperView)?.stop()
                    w.orderOut(nil)
                }
                if let prev, prev != NSRunningApplication.current { prev.activate() }
                else { NSApp.hide(nil) }
                self.onDismiss?()
            }
        })
    }

    static func loadSnippets(_ path: String) -> [String] {
        guard let text = try? String(contentsOfFile: Settings.expand(path), encoding: .utf8) else {
            return DefaultContent.snippets
        }
        var out: [String] = [], cur: [String] = []
        for line in text.components(separatedBy: .newlines) {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                out.append(cur.joined(separator: "\n")); cur = []
            } else { cur.append(line) }
        }
        out.append(cur.joined(separator: "\n"))
        let cleaned = out.map { $0.trimmingCharacters(in: .newlines) }.filter { !$0.isEmpty }
        return cleaned.isEmpty ? DefaultContent.snippets : cleaned
    }
}
