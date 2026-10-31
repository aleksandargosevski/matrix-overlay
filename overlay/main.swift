import AppKit

// Usage:
//   matrix-overlay                      show once (hotkey mode), dismiss on any input
//   matrix-overlay --daemon             stay running, show after idle_seconds from config
//   matrix-overlay --init-config        create ~/.config/matrix-overlay/{config.toml,typer.txt}
// Overrides: --animation rain|typer|random  --idle <sec> (implies --daemon)
//            --size <pt>  --opacity <0-1>  --no-media-check  --config <path>

var daemon = false
var initConfig = false
var configURL = Settings.configURL
var overrides: [(inout Settings) -> Void] = []

var argIt = Array(CommandLine.arguments.dropFirst()).makeIterator()
while let a = argIt.next() {
    switch a {
    case "--daemon": daemon = true
    case "--init-config": initConfig = true
    case "--config": if let p = argIt.next() { configURL = URL(fileURLWithPath: Settings.expand(p)) }
    case "--idle":
        daemon = true
        if let v = argIt.next().flatMap(Double.init) { overrides.append { $0.idleSeconds = v } }
    case "--animation":
        if let v = argIt.next()?.lowercased() { overrides.append { $0.animation = v } }
    case "--size":
        if let v = argIt.next().flatMap(Double.init) {
            overrides.append { $0.rainFontSize = CGFloat(v); $0.typerFontSize = CGFloat(v) }
        }
    case "--opacity":
        if let v = argIt.next().flatMap(Double.init) { overrides.append { $0.opacity = CGFloat(v) } }
    case "--no-media-check": overrides.append { $0.mediaCheck = false }
    case "-h", "--help":
        print("matrix-overlay [--daemon] [--init-config] [--animation rain|typer|random] [--idle sec] [--size pt] [--opacity 0-1] [--no-media-check] [--config path]")
        exit(0)
    default: break
    }
}

func currentSettings() -> Settings {
    var s = Settings.load(from: configURL)
    overrides.forEach { $0(&s) }
    return s
}

if initConfig {
    let fm = FileManager.default
    let dir = configURL.deletingLastPathComponent()
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    if !fm.fileExists(atPath: configURL.path) {
        try? DefaultContent.config.write(to: configURL, atomically: true, encoding: .utf8)
        print("Created \(configURL.path)")
    } else { print("Exists  \(configURL.path)") }
    let typer = dir.appendingPathComponent("typer.txt")
    if !fm.fileExists(atPath: typer.path) {
        try? DefaultContent.snippets.joined(separator: "\n---\n").write(to: typer, atomically: true, encoding: .utf8)
        print("Created \(typer.path)")
    } else { print("Exists  \(typer.path)") }
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let overlay = Overlay()

    var settings = currentSettings()
    var settingsMTime = Settings.configMTime(configURL)

    if !daemon {
        overlay.onDismiss = { exit(0) }
        DispatchQueue.main.async { overlay.show(settings: settings) }
    } else {
        log("daemon: idle \(settings.idleSeconds)s, animation \(settings.animation), media check \(settings.mediaCheck)")
    }

    var lastMediaCheck = Date.distantPast
    var lastBlockReason: String? = nil
    var lastConfigCheck = Date()

    let watcher = Timer(timeInterval: 0.25, repeats: true) { _ in
        MainActor.assumeIsolated {
            // hot-reload config
            if Date().timeIntervalSince(lastConfigCheck) > 2 {
                lastConfigCheck = Date()
                let m = Settings.configMTime(configURL)
                if m != settingsMTime {
                    settingsMTime = m
                    settings = currentSettings()
                    log("config reloaded: idle \(settings.idleSeconds)s, animation \(settings.animation)")
                }
            }

            let idle = secondsIdle()
            if overlay.isShown {
                if Date().timeIntervalSince(overlay.shownAt) > 1.5, idle < 0.3 { overlay.hide() }
                return
            }
            guard daemon, idle >= settings.idleSeconds else {
                lastBlockReason = nil
                return
            }
            if screenIsLocked() { return }
            if settings.mediaCheck {
                if Date().timeIntervalSince(lastMediaCheck) < 5, lastBlockReason != nil { return }
                lastMediaCheck = Date()
                if let reason = Media.blockingReason() {
                    if reason != lastBlockReason { log("skip: \(reason)") }
                    lastBlockReason = reason
                    return
                }
                lastBlockReason = nil
            }
            overlay.show(settings: settings)
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
