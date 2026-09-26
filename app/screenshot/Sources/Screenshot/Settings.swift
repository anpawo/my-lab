import Foundation
import ScreenshotCore

/// `defaults write com.mr.screenshot <key> <value>` and the bar's Options menu write the same keys.
enum Settings {
    private static let d = UserDefaults.standard

    /// Every folder a capture is written to; several at once is fine. Empty means the
    /// clipboard only (the file then lives in the history folder).
    static var folders: [URL] {
        get { (d.stringArray(forKey: "folders") ?? ["~/Desktop"]).map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) } }
        set { d.set(newValue.map(\.path), forKey: "folders") }
    }
    static var folder: URL { folders.first ?? history }
    /// Seconds before a timed capture; 0 is immediate.
    static var timer: Int {
        get { d.integer(forKey: "timer") }
        set { d.set(newValue, forKey: "timer") }
    }
    static var cursor: Bool {
        get { d.bool(forKey: "cursor") }
        set { d.set(newValue, forKey: "cursor") }
    }
    static var copies: Bool {
        get { d.object(forKey: "copy") as? Bool ?? true }
        set { d.set(newValue, forKey: "copy") }
    }
    static var thumbnail: Bool {
        get { d.object(forKey: "thumbnail") as? Bool ?? true }
        set { d.set(newValue, forKey: "thumbnail") }
    }
    static var microphone: Bool {
        get { d.bool(forKey: "microphone") }
        set { d.set(newValue, forKey: "microphone") }
    }

    static var bar: BarState {
        get { BarState(target: Target(rawValue: d.string(forKey: "target") ?? "") ?? .area,
                       kind: Kind(rawValue: d.string(forKey: "kind") ?? "") ?? .photo) }
        set { d.set(newValue.target.rawValue, forKey: "target"); d.set(newValue.kind.rawValue, forKey: "kind") }
    }
    /// The last rectangle, in AppKit global points.
    static var lastRect: CGRect? {
        get { d.string(forKey: "rect").map { NSRectFromString($0) }.flatMap { $0.isEmpty ? nil : $0 } }
        set { d.set(newValue.map { NSStringFromRect($0) }, forKey: "rect") }
    }

    static let history = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("screenshot")
    static let historySize = 20
}
