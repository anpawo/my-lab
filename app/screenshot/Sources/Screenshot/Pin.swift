import AppKit

/// A capture floating where it was taken, above everything, on every Space. Drag to move,
/// scroll for opacity, Escape or the corner cross to close. No timeout: it stays until you say.
final class Pin: NSPanel {
    private static var pins: [Pin] = []

    static func show(_ image: CGImage, at rect: CGRect) {
        pins.append(Pin(image, at: rect))
    }

    private let close = NSButton()

    private init(_ image: CGImage, at rect: CGRect) {
        super.init(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = PinView(frame: CGRect(origin: .zero, size: rect.size), pin: self)
        let iv = NSImageView(frame: view.bounds)
        iv.image = NSImage(cgImage: image, size: rect.size)
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.autoresizingMask = [.width, .height]
        view.addSubview(iv)
        close.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
        close.isBordered = false
        close.imagePosition = .imageOnly
        close.contentTintColor = .white
        close.wantsLayer = true
        close.layer?.backgroundColor = NSColor(white: 0, alpha: 0.65).cgColor
        close.layer?.cornerRadius = 11
        close.frame = CGRect(x: 6, y: rect.height - 28, width: 22, height: 22)
        close.target = self
        close.action = #selector(dismiss)
        close.isHidden = true
        view.addSubview(close)
        contentView = view
        orderFrontRegardless()
    }

    override var canBecomeKey: Bool { true }

    func hover(_ on: Bool) { close.isHidden = !on }

    override func scrollWheel(with event: NSEvent) {
        alphaValue = min(1, max(0.15, alphaValue + event.scrollingDeltaY / 100))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { dismiss() }
    }

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
            layer?.borderColor = NSColor.white.withAlphaComponent(0.6).cgColor
            layer?.borderWidth = 1
            addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
        }
        required init?(coder: NSCoder) { nil }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseEntered(with event: NSEvent) { pin.hover(true) }
        override func mouseExited(with event: NSEvent) { pin.hover(false) }
        override func mouseDown(with event: NSEvent) { pin.makeKey(); super.mouseDown(with: event) }
    }
}
