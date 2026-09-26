import AppKit

/// A capture kept in the top-right corner, thumbnail-sized, until closed. Pins stack downward
/// and the next thumbnails appear under them. A click offers Copy, Open, Close.
final class Pin: NSPanel, NSMenuDelegate {
    private static var pins: [Pin] = []
    private let url: URL

    static func show(_ image: CGImage, url: URL) {
        pins.append(Pin(image, url: url))
    }

    /// Where the stack ends on this screen: the next card goes below it.
    static func stackBottom(on screen: NSScreen) -> CGFloat {
        pins.filter { $0.screen == screen }.map(\.frame.minY).min() ?? screen.visibleFrame.maxY
    }

    private init(_ image: CGImage, url: URL) {
        self.url = url
        let s = NSScreen.underMouse
        let width = (s.visibleFrame.width / 10).rounded()
        let height = (width * CGFloat(image.height) / CGFloat(image.width)).rounded()
        super.init(contentRect: CGRect(x: 0, y: 0, width: width, height: height),
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
        setFrameOrigin(CGPoint(x: s.visibleFrame.maxX - width - 16, y: Pin.stackBottom(on: s) - height - 16))
        orderFrontRegardless()
    }

    override var canBecomeKey: Bool { false }

    func menu(at point: CGPoint) {
        let menu = NSMenu()
        for (title, sel) in [("Copy", #selector(copyImage)), ("Open", #selector(open)), ("Close", #selector(dismiss))] {
            let m = menu.addItem(withTitle: title, action: sel, keyEquivalent: "")
            m.target = self
        }
        menu.popUp(positioning: nil, at: point, in: contentView)
    }

    @objc private func copyImage() {
        if let png = try? Data(contentsOf: url) { Output.copy(png, url: url) }
    }
    @objc private func open() { NSWorkspace.shared.open(url) }
    @objc func dismiss() {
        orderOut(nil)
        Pin.pins.removeAll { $0 === self }
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
        override func mouseDown(with event: NSEvent) { pin.menu(at: convert(event.locationInWindow, from: nil)) }
    }
}
