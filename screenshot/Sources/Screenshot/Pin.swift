import AppKit
import ScreenshotCore

/// A capture kept in the top-right corner, thumbnail-sized, until closed. Pins stack downward
/// and the next thumbnails appear under them. A click copies, a double click opens the file,
/// a right click unpins.
final class Pin: NSPanel {
    private static var pins: [Pin] = []
    private let url: URL
    private let screenOf: NSScreen

    static func show(_ image: CGImage, url: URL) {
        pins.append(Pin(image, url: url))
    }

    /// Where the stack ends on this screen: the next card goes below it.
    static func stackBottom(on screen: NSScreen) -> CGFloat {
        pins.filter { $0.screenOf == screen }.map(\.frame.minY).min() ?? screen.visibleFrame.maxY
    }

    /// Re-stacks a screen's pins from the top, so closing one lets the others move up.
    private static func restack(on screen: NSScreen) {
        var y = screen.visibleFrame.maxY
        for p in pins where p.screenOf == screen {
            y -= p.frame.height + 16
            p.setFrameOrigin(CGPoint(x: p.frame.minX, y: y))
        }
    }

    private init(_ image: CGImage, url: URL) {
        self.url = url
        let s = NSScreen.underMouse
        screenOf = s
        let size = cardSize(CGSize(width: image.width, height: image.height), side: (s.visibleFrame.width / 10).rounded())
        super.init(contentRect: CGRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        sharingType = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = PinView(frame: CGRect(origin: .zero, size: frame.size), pin: self)
        let iv = NSImageView(frame: view.bounds)
        iv.image = NSImage(cgImage: image, size: view.bounds.size)
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.autoresizingMask = [.width, .height]
        view.addSubview(iv)
        contentView = view
        setFrameOrigin(CGPoint(x: s.visibleFrame.maxX - size.width - 16, y: Pin.stackBottom(on: s) - size.height - 16))
        orderFrontRegardless()
    }

    override var canBecomeKey: Bool { false }

    func copyImage() {
        if let png = try? Data(contentsOf: url) { Output.copy(png, url: url) }
    }
    func open() { NSWorkspace.shared.open(url) }
    func dismiss() {
        orderOut(nil)
        Pin.pins.removeAll { $0 === self }
        Pin.restack(on: screenOf)
    }

    private final class PinView: NSView {
        unowned let pin: Pin
        init(frame: CGRect, pin: Pin) {
            self.pin = pin
            super.init(frame: frame)
            wantsLayer = true
            layer?.cornerRadius = 8
            layer?.masksToBounds = true
            layer?.borderColor = NSColor.white.withAlphaComponent(0.8).cgColor
            layer?.borderWidth = 2
        }
        required init?(coder: NSCoder) { nil }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) { if event.clickCount == 2 { pin.open() } else { pin.copyImage() } }
        override func rightMouseDown(with event: NSEvent) { pin.dismiss() }
    }
}
