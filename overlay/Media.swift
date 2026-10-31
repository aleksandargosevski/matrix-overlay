import Foundation
import CoreGraphics

func secondsIdle() -> Double {
    CGEventSource.secondsSinceLastEventType(.combinedSessionState,
                                            eventType: CGEventType(rawValue: ~0)!)
}

func screenIsLocked() -> Bool {
    guard let d = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
    return (d["CGSSessionScreenIsLocked"] as? Bool) == true
}

func log(_ s: String) {
    FileHandle.standardError.write("[\(Date())] \(s)\n".data(using: .utf8)!)
}

// Video/call detection: any display-sleep or WebRTC/call assertion held by a process
// other than keep-awake tools blocks the idle trigger.
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
                  let close = line.firstIndex(of: ")"), open < close else { continue }
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
