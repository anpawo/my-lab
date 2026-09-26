import AppKit
import ScreenshotCore
import UniformTypeIdentifiers

enum Output {
    /// PNG tagged with 72 × scale dpi, so Preview and browsers show a Retina shot at its point
    /// size — the one thing Capso and better-shot get wrong.
    static func png(_ image: CGImage, scale: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        let dpi = 72 * scale
        CGImageDestinationAddImage(dest, image, [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? data as Data : nil
    }

    /// Writes the file to every chosen folder, copies it, keeps a copy in the history, and
    /// returns the first one.
    @MainActor
    static func save(_ image: CGImage, scale: CGFloat, kind: String = "Screenshot", app: String? = nil) throws -> URL {
        guard let png = png(image, scale: scale) else { throw CocoaError(.fileWriteUnknown) }
        let name = fileName(kind: kind, app: app, ext: "png")
        var first: URL?
        for folder in Settings.folders {
            let url = folder.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try png.write(to: url)
            first = first ?? url
        }
        let url: URL
        if let first { url = first; remember(url) } else {
            url = Settings.history.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: Settings.history, withIntermediateDirectories: true)
            try png.write(to: url)
            prune()
        }
        if Settings.copies { copy(png, url: url) }
        return url
    }

    /// One pasteboard item with the image and the file: the file URL is what makes ⌘V work in a
    /// terminal, the PNG what makes it work everywhere else.
    static func copy(_ png: Data, url: URL) {
        let item = NSPasteboardItem()
        item.setData(png, forType: .png)
        item.setString(url.absoluteString, forType: .fileURL)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([item])
    }

    /// A copy under Application Support, the newest 20 only: the menu bar's "Récentes".
    static func remember(_ url: URL) {
        let fm = FileManager.default
        try? fm.createDirectory(at: Settings.history, withIntermediateDirectories: true)
        try? fm.copyItem(at: url, to: Settings.history.appendingPathComponent(url.lastPathComponent))
        prune()
    }

    static func prune() {
        for old in recent().dropFirst(Settings.historySize) { try? FileManager.default.removeItem(at: old) }
    }

    static func recent() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: Settings.history, includingPropertiesForKeys: nil)) ?? []
        return urls.filter { !$0.lastPathComponent.hasPrefix(".") }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }
}
