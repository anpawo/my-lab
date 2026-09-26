import AppKit
import ScreenCaptureKit
import ScreenshotCore

/// A window as CoreGraphics lists it: front-to-back order, which ScreenCaptureKit does not give.
struct WindowInfo {
    let id: CGWindowID
    let frame: CGRect        // AppKit global points
    let app: String
    let title: String
}

/// ScreenCaptureKit, one frame at a time. Our own process is excluded from every display
/// filter, so overlays never have to hide before a shot.
enum Capture {
    private static let pid = ProcessInfo.processInfo.processIdentifier
    private static var cached: SCShareableContent?

    /// Fetched at launch and after each capture, so opening the bar does not wait ~100 ms on it.
    static func prefetch() {
        Task { cached = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) }
    }

    static func content() async throws -> SCShareableContent {
        if let cached { return cached }
        let c = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        cached = c
        return c
    }

    static func displayFilter(_ screen: NSScreen) async throws -> (SCDisplay, SCContentFilter) {
        let content = try await content()
        guard let display = content.displays.first(where: { $0.displayID == screen.displayID }) else {
            throw ShotError.noDisplay
        }
        let mine = content.applications.filter { $0.processID == pid }
        return (display, SCContentFilter(display: display, excludingApplications: mine, exceptingWindows: []))
    }

    /// The whole display, at its native pixel size.
    static func screen(_ screen: NSScreen) async throws -> CGImage {
        let (_, filter) = try await displayFilter(screen)
        let config = SCStreamConfiguration()
        config.width = Int(screen.frame.width * screen.backingScaleFactor)
        config.height = Int(screen.frame.height * screen.backingScaleFactor)
        return try await shoot(filter, config)
    }

    /// `rect` in AppKit global points, inside `screen`.
    static func area(_ rect: CGRect, on screen: NSScreen) async throws -> CGImage {
        let (_, filter) = try await displayFilter(screen)
        let config = SCStreamConfiguration()
        config.sourceRect = displayLocal(rect, in: screen.frame)
        config.width = Int(rect.width * screen.backingScaleFactor)
        config.height = Int(rect.height * screen.backingScaleFactor)
        return try await shoot(filter, config)
    }

    /// With its shadow on a transparent background, like ⌘⇧4-space; without, like ⌥-click there.
    static func window(_ w: WindowInfo, shadow: Bool) async throws -> CGImage {
        guard let sc = try await content().windows.first(where: { $0.windowID == w.id }) else { throw ShotError.noWindow }
        let filter = SCContentFilter(desktopIndependentWindow: sc)
        let config = SCStreamConfiguration()
        config.ignoreShadowsSingleWindow = !shadow
        let scale = CGFloat(filter.pointPixelScale)
        config.width = Int(filter.contentRect.width * scale)
        config.height = Int(filter.contentRect.height * scale)
        return try await shoot(filter, config)
    }

    private static func shoot(_ filter: SCContentFilter, _ config: SCStreamConfiguration) async throws -> CGImage {
        config.showsCursor = Settings.cursor
        config.captureResolution = .best
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    /// Normal-level windows, frontmost first, ours left out.
    @MainActor
    static func windows() -> [WindowInfo] {
        let mainHeight = NSScreen.screens[0].frame.height
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        return list.compactMap { w in
            guard w[kCGWindowLayer as String] as? Int == 0,
                  w[kCGWindowOwnerPID as String] as? Int32 != pid,
                  (w[kCGWindowAlpha as String] as? Double ?? 1) > 0.01,
                  let id = w[kCGWindowNumber as String] as? CGWindowID,
                  let bounds = CGRect(dictionaryRepresentation: w[kCGWindowBounds as String] as! CFDictionary),
                  bounds.width > 32, bounds.height > 32
            else { return nil }
            return WindowInfo(id: id, frame: appKit(bounds, mainHeight: mainHeight),
                              app: w[kCGWindowOwnerName as String] as? String ?? "",
                              title: w[kCGWindowName as String] as? String ?? "")
        }
    }
}

enum ShotError: LocalizedError {
    case noDisplay, noWindow
    var errorDescription: String? {
        switch self {
        case .noDisplay: return "display not shareable — Screen Recording permission?"
        case .noWindow: return "window is gone"
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
    }
    static var underMouse: NSScreen {
        let p = NSEvent.mouseLocation
        return screens.first { $0.frame.contains(p) } ?? main ?? screens[0]
    }
    static func containing(_ r: CGRect) -> NSScreen {
        let c = CGPoint(x: r.midX, y: r.midY)
        return screens.first { $0.frame.contains(c) } ?? screens.max { $0.frame.intersection(r).area < $1.frame.intersection(r).area }!
    }
}

extension CGRect { var area: CGFloat { isNull ? 0 : width * height } }
