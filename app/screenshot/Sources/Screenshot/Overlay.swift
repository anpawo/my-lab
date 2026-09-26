import AppKit
import ScreenshotCore

/// One per display: shows the frozen screen, dims it, and takes the mouse and keyboard.
/// Non-activating, so the app under the cursor keeps focus and looks normal in the shot.
final class Overlay: NSPanel {
    let display: NSScreen
    let frozen: CGImage

    init(screen: NSScreen, frozen: CGImage, session: Session) {
        self.display = screen
        self.frozen = frozen
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .screenSaver
        isOpaque = true
        backgroundColor = .black
        hasShadow = false
        acceptsMouseMovedEvents = true
        hidesOnDeactivate = false
        animationBehavior = .none
        isReleasedWhenClosed = false
        sharingType = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView = OverlayView(screen: screen, frozen: frozen, session: session)
        makeFirstResponder(contentView)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class OverlayView: NSView {
    private let display: NSScreen
    private var screen: NSScreen { display }
    private let image: NSImage
    private unowned let session: Session
    private enum Drag { case none, new(CGPoint), move(CGPoint), resize(Int) }
    private var drag = Drag.none

    init(screen: NSScreen, frozen: CGImage, session: Session) {
        self.display = screen
        self.image = NSImage(cgImage: frozen, size: screen.frame.size)
        self.session = session
        super.init(frame: CGRect(origin: .zero, size: screen.frame.size))
        wantsLayer = true
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways], owner: self))
    }
    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // Local ↔ global (AppKit) points.
    private func global(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + screen.frame.minX, y: p.y + screen.frame.minY) }
    private func local(_ r: CGRect) -> CGRect { r.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY) }

    // MARK: Mouse

    override func mouseMoved(with event: NSEvent) {
        let p = global(convert(event.locationInWindow, from: nil))
        let w = session.state.target == .window ? session.windows.first { $0.frame.contains(p) } : nil
        cursor(at: p).set()
        if session.hoverScreen != screen || session.hoverWindow?.id != w?.id {
            session.hoverScreen = screen
            session.hoverWindow = w
            session.redraw()
        }
    }

    override func mouseExited(with event: NSEvent) {
        // Leaving for the bar is not leaving the screen.
        guard !screen.frame.contains(NSEvent.mouseLocation) else { return }
        if session.hoverScreen == screen {
            session.hoverScreen = nil
            session.hoverWindow = nil
            session.redraw()
        }
    }

    override func mouseDown(with event: NSEvent) {
        session.makeKey(window as! Overlay)
        let p = global(convert(event.locationInWindow, from: nil))
        switch session.state.target {
        case .screen: session.commit(screen: screen)
        case .window:
            if let w = session.windows.first(where: { $0.frame.contains(p) }) { session.commit(window: w) }
        case .area, .text:
            if let r = session.selection {
                if let i = (0..<8).first(where: { handlePoint(r, $0).distance(to: p) < 8 }) { drag = .resize(i); return }
                if r.contains(p) { drag = .move(CGPoint(x: p.x - r.minX, y: p.y - r.minY)); return }
            }
            drag = .new(p)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let p = global(convert(event.locationInWindow, from: nil))
        let bounds = screen.frame
        switch drag {
        case .none: return
        case .new(let start): session.selection = ScreenshotCore.rect(from: start, to: p).intersection(bounds)
        case .move(let grip):
            guard let r = session.selection else { return }
            session.selection = nudge(r, dx: p.x - grip.x - r.minX, dy: p.y - grip.y - r.minY, resize: false, bounds: bounds)
        case .resize(let i):
            guard let r = session.selection else { return }
            session.selection = resized(r, handle: i, to: CGPoint(x: min(max(p.x, bounds.minX), bounds.maxX),
                                                                   y: min(max(p.y, bounds.minY), bounds.maxY)))
        }
        session.redraw()
    }

    override func mouseUp(with event: NSEvent) {
        if case .new = drag, let r = session.selection, r.width < 3 || r.height < 3 { session.selection = nil }
        drag = .none
        session.refresh()
    }

    override func rightMouseDown(with event: NSEvent) { session.close() }

    private func cursor(at p: CGPoint) -> NSCursor {
        guard session.state.needsSelection else { return .camera }
        if let r = session.selection {
            if (0..<8).contains(where: { handlePoint(r, $0).distance(to: p) < 8 }) { return .crosshair }
            if r.contains(p) { return .openHand }
        }
        return .crosshair
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        let mods = event.modifierFlags
        switch event.keyCode {
        case 53: session.close()
        case 36, 76: session.commit()
        case 123, 124, 125, 126:
            let (dx, dy): (CGFloat, CGFloat) = [123: (-1, 0), 124: (1, 0), 125: (0, -1), 126: (0, 1)][Int(event.keyCode)]!
            if mods.contains(.command) {
                if dx != 0 { session.step(Int(dx)) }
            } else {
                let step: CGFloat = mods.contains(.shift) ? 10 : 1
                session.nudge(dx: dx * step, dy: dy * step, resize: mods.contains(.option))
            }
        default: break
        }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        image.draw(in: bounds)
        // The whole screen goes a little dark while the bar is up, so it reads as "capturing";
        // the part that will end up in the picture stays at full brightness.
        let dim = NSColor(white: 0, alpha: session.state.needsSelection ? 0.35 : 0.25)
        switch session.state.target {
        case .screen:
            if session.hoverScreen != screen { dim.setFill(); bounds.fill() }
            else { outline(bounds.insetBy(dx: 2, dy: 2), label: "\(pixels(bounds))") }
        case .window:
            dim.setFill(); bounds.fill()
            if let w = session.hoverWindow {
                let r = local(w.frame)
                image.draw(in: r, from: r, operation: .copy, fraction: 1)
                outline(r, label: "\(w.app)  \(pixels(r))")
            }
        case .area, .text:
            dim.setFill(); bounds.fill()
            guard let sel = session.selection, screen.frame.contains(sel) else { return }
            let r = local(sel)
            image.draw(in: r, from: r, operation: .copy, fraction: 1)
            outline(r, label: pixels(r))
            NSColor.white.setFill()
            for i in 0..<8 {
                let p = handlePoint(r, i)
                NSBezierPath(ovalIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)).fill()
            }
        }
    }

    private func pixels(_ r: CGRect) -> String {
        let s = screen.backingScaleFactor
        return "\(Int(r.width * s)) × \(Int(r.height * s))"
    }

    private func outline(_ r: CGRect, label: String) {
        NSColor.white.setStroke()
        let path = NSBezierPath(rect: r.insetBy(dx: -0.5, dy: -0.5))
        path.lineWidth = 1
        path.stroke()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.white,
        ]
        let size = (label as NSString).size(withAttributes: attrs)
        var box = CGRect(x: r.minX, y: r.minY - size.height - 10, width: size.width + 12, height: size.height + 6)
        if box.minY < 0 { box.origin.y = r.minY + 4 }
        if box.maxX > bounds.maxX { box.origin.x = bounds.maxX - box.width }
        NSColor(white: 0, alpha: 0.7).setFill()
        NSBezierPath(roundedRect: box, xRadius: 4, yRadius: 4).fill()
        (label as NSString).draw(at: CGPoint(x: box.minX + 6, y: box.minY + 3), withAttributes: attrs)
    }
}

extension CGPoint {
    func distance(to p: CGPoint) -> CGFloat { hypot(x - p.x, y - p.y) }
}

extension NSCursor {
    /// The camera the system shows for screen and window picks: a white symbol with a dark rim.
    static let camera: NSCursor = {
        let size = CGSize(width: 30, height: 30)
        let img = NSImage(size: size, flipped: false) { _ in
            let sym = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: nil)!
                .withSymbolConfiguration(.init(pointSize: 22, weight: .medium))!
            let white = NSImage(size: sym.size, flipped: false) { _ in
                sym.draw(in: CGRect(origin: .zero, size: sym.size))
                NSColor.white.set()
                CGRect(origin: .zero, size: sym.size).fill(using: .sourceAtop)
                return true
            }
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.9)
            shadow.shadowBlurRadius = 2.5
            shadow.set()
            white.draw(in: CGRect(x: (size.width - sym.size.width) / 2, y: (size.height - sym.size.height) / 2,
                                  width: sym.size.width, height: sym.size.height))
            return true
        }
        return NSCursor(image: img, hotSpot: CGPoint(x: 15, y: 15))
    }()
}
