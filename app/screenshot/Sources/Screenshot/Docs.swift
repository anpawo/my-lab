import AppKit
import ScreenshotCore

/// The README's pictures, drawn by the app's own views and never put on screen:
/// `screenshot --render-docs docs`. A stock wallpaper stands in for the desktop, so no real
/// window ends up in a public repo.
@MainActor
enum Docs {
    static func render(to dir: URL) {
        let session = Session.shared
        let screen = NSScreen.main!
        let s = screen.frame
        session.selection = CGRect(x: s.minX + s.width * 0.28, y: s.minY + s.height * 0.3,
                                   width: s.width * 0.44, height: s.height * 0.46).integral
        session.state = BarState(target: .area, kind: .photo)
        let bar = Bar(session: session, on: screen)
        save(bar.render(), dir, "bar.png")
        save(bar.render(hovering: 3).representation(using: .png, properties: [:]), dir, "bar-hover.png")
        session.state = BarState(target: .area, kind: .video)
        bar.refresh()
        save(bar.render(), dir, "bar-record.png")

        session.state = BarState(target: .area, kind: .photo)
        bar.refresh()
        let wall = NSImage(contentsOfFile: "/System/Library/Desktop Pictures/Sonoma.heic")!
            .cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let overlay = Overlay(screen: screen, frozen: wall, session: session)
        overlay.refreshLayers()
        // Cropped to the selection and the bar: the whole 2× screen of wallpaper is a 6 MB PNG.
        let crop = session.selection!.insetBy(dx: -120, dy: -48).union(bar.frame.insetBy(dx: 0, dy: -24)).intersection(s)
        let shot = Bar.canvas(crop.size) {
            Bar.pixels(overlay.contentView!).draw(in: s.offsetBy(dx: -crop.minX, dy: -crop.minY))
            // draw(in:) copies, alpha and all: the bar's rounded corners would come out black.
            Bar.pixels(bar.contentView!).draw(in: bar.frame.offsetBy(dx: -crop.minX, dy: -crop.minY), from: .zero,
                                              operation: .sourceOver, fraction: 1, respectFlipped: false, hints: nil)
        }
        save(shot.representation(using: .png, properties: [:]), dir, "overlay.png")
    }

    private static func save(_ png: Data?, _ dir: URL, _ name: String) {
        try! png!.write(to: dir.appendingPathComponent(name))
    }
}
