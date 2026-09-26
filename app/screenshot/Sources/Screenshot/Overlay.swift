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
    // The veil over this screen; in screen mode it fades between the two values on hover.
    private var veil: CGFloat = 0.45
    private var veilTarget: CGFloat = 0.45
    private var fade: Timer?

    private func fadeVeil(to target: CGFloat) {
        guard target != veilTarget else { return }
        veilTarget = target
        fade?.invalidate()
        let from = veil, start = Date()
        fade = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            let k = min(1, Date().timeIntervalSince(start) / 0.2)
            self.veil = from + (target - from) * CGFloat(k)
            self.needsDisplay = true
            self.display()
            if k >= 1 { t.invalidate() }
        }
    }

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
        case .area:
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
            if (0..<8).contains(where: { handlePoint(r, $0).distance(to: p) < 8 }) { return .selection }
            if r.contains(p) { return .openHand }
        }
        return .selection
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
        // The whole screen stays a little dark while the bar is up, whatever the mouse does, so
        // it reads as "capturing". What the click would take gets a lighter tint and an outline;
        // only the area selection shows through at full brightness.
        if session.state.target == .screen {
            // The screen under the mouse is the one a click takes: its veil fades away.
            fadeVeil(to: session.hoverScreen == screen ? 0.08 : 0.45)
        } else {
            veil = 0.45
            veilTarget = 0.45
        }
        NSColor(white: 0, alpha: veil).setFill()
        bounds.fill()
        switch session.state.target {
        case .screen: break
        case .window:
            // Only the hovered window shows through the veil.
            if let w = session.hoverWindow {
                let r = local(w.frame)
                image.draw(in: r, from: r, operation: .copy, fraction: 1)
                let frame = NSBezierPath(roundedRect: r.insetBy(dx: 1, dy: 1), xRadius: 10, yRadius: 10)
                frame.lineWidth = 2
                NSColor.white.setStroke()
                frame.stroke()
                label("\(w.app)  \(pixels(w.frame))", below: r)
            }
        case .area:
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

    private func outline(_ r: CGRect, label text: String) {
        NSColor.white.setStroke()
        let path = NSBezierPath(rect: r.insetBy(dx: -0.5, dy: -0.5))
        path.lineWidth = 1
        path.stroke()
        label(text, below: r)
    }

    private func label(_ label: String, below r: CGRect) {
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
    /// The system's own screenshot cursors, straight from HIServices: the camera for screen and
    /// window picks, the ringed cross for the area. Their plists give the hotspots and a soft
    /// shadow, applied here since the PDFs carry none.
    static let camera = system("screenshotwindow", hotSpot: CGPoint(x: 14, y: 11)) ?? .arrow
    static let selection = system("screenshotselection", hotSpot: CGPoint(x: 15, y: 15)) ?? .crosshair

    private static func system(_ name: String, hotSpot: CGPoint) -> NSCursor? {
        let base = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/Resources/cursors/"
        guard let pdf = NSImage(contentsOfFile: base + name + "/cursor.pdf") else { return nil }
        let img = NSImage(size: pdf.size, flipped: false) { r in
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
            shadow.shadowOffset = CGSize(width: 0, height: -1)
            shadow.shadowBlurRadius = 2
            shadow.set()
            pdf.draw(in: r)
            return true
        }
        return NSCursor(image: img, hotSpot: hotSpot)
    }
}
