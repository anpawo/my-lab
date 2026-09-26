import AppKit

/// The corner card after a capture. Five seconds, paused under the mouse; the file is already
/// written, unlike the system's, whose card *is* the wait.
@MainActor
final class Thumbnail: NSPanel {
    enum Content {
        case image(CGImage, URL, CGRect)
        case movie(CGImage?, URL)
    }

    private static var current: Thumbnail?
    private let content: Content
    private var timer: Timer?
    private let buttons = NSStackView()

    static func show(_ content: Content) {
        guard Settings.thumbnail else { return }
        current?.orderOut(nil)
        current = Thumbnail(content)
    }

    private init(_ content: Content) {
        self.content = content
        // A tenth of the screen wide, the capture's own aspect ratio, top-right corner.
        let v = NSScreen.underMouse.visibleFrame
        let width = (v.width / 10).rounded()
        var height = (width * 0.625).rounded()
        switch content {
        case .image(let img, _, _), .movie(.some(let img), _):
            height = (width * CGFloat(img.height) / CGFloat(img.width)).rounded()
        default: break
        }
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

        let view = CardView(frame: CGRect(origin: .zero, size: frame.size), card: self)
        contentView = view
        switch content {
        case .image(let img, _, _), .movie(.some(let img), _):
            let iv = NSImageView(frame: view.bounds)
            iv.image = NSImage(cgImage: img, size: view.bounds.size)
            iv.imageScaling = .scaleProportionallyUpOrDown
            iv.autoresizingMask = [.width, .height]
            view.addSubview(iv)
        case .movie(nil, _):
            view.addSubview(label("Enregistrement", in: view.bounds))
        }
        if case .image = content {
            for (symbol, action, tip) in [("pin", #selector(pin), "Épingler"), ("trash", #selector(trash), "Supprimer")] {
                let b = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: tip)!, target: self, action: action)
                b.bezelStyle = .circular
                b.toolTip = tip
                buttons.addArrangedSubview(b)
            }
            buttons.frame = CGRect(x: 6, y: frame.height - 34, width: 80, height: 28)
            buttons.isHidden = true
            view.addSubview(buttons)
        }

        setFrameOrigin(CGPoint(x: v.maxX - frame.width - 16, y: v.maxY - frame.height - 16))
        orderFrontRegardless()
        arm()
    }

    private func label(_ s: String, in r: CGRect) -> NSTextField {
        let t = NSTextField(wrappingLabelWithString: s)
        t.frame = r
        t.textColor = .white
        t.maximumNumberOfLines = 8
        t.alignment = .center
        return t
    }

    func arm() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.dismiss() }
        }
    }
    func hold() { timer?.invalidate() }
    func hover(_ on: Bool) { buttons.isHidden = !on }

    func dismiss() {
        timer?.invalidate()
        orderOut(nil)
        if Thumbnail.current === self { Thumbnail.current = nil }
    }

    var url: URL {
        switch content {
        case .image(_, let u, _), .movie(_, let u): return u
        }
    }

    func open() {
        NSWorkspace.shared.open(url)
        dismiss()
    }

    @objc private func pin() {
        if case .image(let img, _, let rect) = content { Pin.show(img, at: rect) }
        dismiss()
    }

    @objc private func trash() {
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        dismiss()
    }

    private final class CardView: NSView, NSDraggingSource {
        unowned let card: Thumbnail
        private var down: CGPoint?
        init(frame: CGRect, card: Thumbnail) {
            self.card = card
            super.init(frame: frame)
            wantsLayer = true
            layer?.cornerRadius = 8
            layer?.masksToBounds = true
            layer?.backgroundColor = NSColor(white: 0.15, alpha: 0.95).cgColor
            layer?.borderColor = NSColor.white.withAlphaComponent(0.8).cgColor
            layer?.borderWidth = 2
            addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
        }
        required init?(coder: NSCoder) { nil }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseEntered(with event: NSEvent) { card.hold(); card.hover(true) }
        override func mouseExited(with event: NSEvent) { card.arm(); card.hover(false) }
        override func mouseDown(with event: NSEvent) { down = event.locationInWindow }
        override func mouseUp(with event: NSEvent) { if down != nil { card.open() }; down = nil }
        override func mouseDragged(with event: NSEvent) {
            guard let start = down, start.distance(to: event.locationInWindow) > 6 else { return }
            down = nil
            let item = NSDraggingItem(pasteboardWriter: card.url as NSURL)
            item.setDraggingFrame(bounds, contents: card.contentView?.subviews.compactMap { $0 as? NSImageView }.first?.image)
            beginDraggingSession(with: [item], event: event, source: self)
        }
        func draggingSession(_ s: NSDraggingSession, sourceOperationMaskFor c: NSDraggingContext) -> NSDragOperation { .copy }
        func draggingSession(_ s: NSDraggingSession, endedAt p: NSPoint, operation: NSDragOperation) { card.dismiss() }
    }
}
