import AppKit

// MARK: - Settings (config.toml + CLI overrides)

struct Settings {
    // general
    var animation = "rain"              // rain | typer | random
    var idleSeconds: Double = 60
    var mediaCheck = true
    var opacity: CGFloat = 0.92         // black background alpha
    var fps: Double = 30
    var color = RGB(hex: "#00ff41")!

    // [rain]
    var rainFontSize: CGFloat = 16

    // [typer]
    var typerFont = ""                  // empty = SF Mono (system monospaced)
    var typerFontSize: CGFloat = 18
    var typerTextFile = "~/.config/matrix-overlay/typer.txt"
    var typerCPS: Double = 14           // average characters per second
    var typerTypoRate: Double = 0.02    // chance of a typo per letter
    var typerLoop = true
    var typerOpacity: CGFloat = 1.0

    static var configDir: URL {
        if let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"], !xdg.isEmpty {
            return URL(fileURLWithPath: xdg).appendingPathComponent("matrix-overlay")
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/matrix-overlay")
    }
    static var configURL: URL { configDir.appendingPathComponent("config.toml") }

    static func expand(_ path: String) -> String { (path as NSString).expandingTildeInPath }

    static func configMTime(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    static func load(from url: URL) -> Settings {
        var s = Settings()
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return s }
        let t = TOML.parse(text)
        func str(_ k: String) -> String? { t[k] }
        func num(_ k: String) -> Double? { t[k].flatMap(Double.init) }
        func bool(_ k: String) -> Bool? { t[k].map { $0 == "true" } }

        if let v = str("animation") { s.animation = v.lowercased() }
        if let v = num("idle_seconds") { s.idleSeconds = max(5, v) }
        if let v = bool("media_check") { s.mediaCheck = v }
        if let v = num("opacity") { s.opacity = CGFloat(min(1, max(0, v))) }
        if let v = num("fps") { s.fps = min(120, max(10, v)) }
        if let v = str("color"), let c = RGB(hex: v) { s.color = c }

        if let v = num("rain.font_size") { s.rainFontSize = CGFloat(v) }

        if let v = str("typer.font") { s.typerFont = v }
        if let v = num("typer.font_size") { s.typerFontSize = CGFloat(v) }
        if let v = str("typer.text_file") { s.typerTextFile = v }
        if let v = num("typer.chars_per_second") { s.typerCPS = max(1, v) }
        if let v = num("typer.typo_rate") { s.typerTypoRate = min(0.5, max(0, v)) }
        if let v = bool("typer.loop") { s.typerLoop = v }
        if let v = num("typer.opacity") { s.typerOpacity = CGFloat(min(1, max(0, v))) }
        return s
    }
}

struct RGB {
    var r: CGFloat, g: CGFloat, b: CGFloat
    init(r: CGFloat, g: CGFloat, b: CGFloat) { self.r = r; self.g = g; self.b = b }
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = UInt32(h, radix: 16) else { return nil }
        r = CGFloat((v >> 16) & 0xff) / 255
        g = CGFloat((v >> 8) & 0xff) / 255
        b = CGFloat(v & 0xff) / 255
    }
    func cg(_ scale: CGFloat = 1, alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: r * scale, green: g * scale, blue: b * scale, alpha: alpha)
    }
    func mixed(withWhite t: CGFloat) -> RGB {
        RGB(r: r + (1 - r) * t, g: g + (1 - g) * t, b: b + (1 - b) * t)
    }
}

// Minimal TOML subset: [section], key = "string" | 'string' | number | bool, # comments.
enum TOML {
    static func parse(_ text: String) -> [String: String] {
        var out: [String: String] = [:]
        var section = ""
        for raw in text.components(separatedBy: .newlines) {
            let line = stripComment(raw).trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                section = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                continue
            }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            var val = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            if val.count >= 2, let f = val.first, (f == "\"" || f == "'"), val.last == f {
                val = String(val.dropFirst().dropLast())
                if f == "\"" { val = val.replacingOccurrences(of: "\\\"", with: "\"") }
            }
            out[section.isEmpty ? key : "\(section).\(key)"] = val
        }
        return out
    }

    private static func stripComment(_ s: String) -> String {
        var quote: Character? = nil
        for (i, c) in s.enumerated() {
            if let q = quote { if c == q { quote = nil } }
            else if c == "\"" || c == "'" { quote = c }
            else if c == "#" { return String(s.prefix(i)) }
        }
        return s
    }
}
