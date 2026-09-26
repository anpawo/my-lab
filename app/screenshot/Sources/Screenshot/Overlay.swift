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
    func refreshLayers() { (contentView as! OverlayView).update() }
}

private final class OverlayView: NSView {
    private let display: NSScreen
    private var screen: NSScreen { display }
    private let image: NSImage
    private unowned let session: Session
    private enum Drag { case none, new(CGPoint), move(CGPoint), resize(Int) }
    private var drag = Drag.none

    // Everything on screen is a layer, so a hover costs a mask path: redrawing a 2940×1912
    // image on every mouse move is what lagged.
    private let veil = CALayer()
    private let hole = CAShapeLayer()
    private let frameLayer = CAShapeLayer()
    private let frameBase = CAShapeLayer()   // white under the black dashes: no gaps, two colours
    private let windowGroup = CALayer()      // window mode: a light blue wash in a white frame,
    private let windowTint = CAShapeLayer()  // masked to what shows from behind the windows in front
    private let windowFrame = CAShapeLayer()
    private let windowMask = CAShapeLayer()
    private let handlesLayer = CAShapeLayer()
    private let handleDots = CAShapeLayer()
    private let labelBack = CALayer()
    private let label = CATextLayer()

    init(screen: NSScreen, frozen: CGImage, session: Session) {
        self.display = screen
        self.image = NSImage(cgImage: frozen, size: screen.frame.size)
        self.session = session
        super.init(frame: CGRect(origin: .zero, size: screen.frame.size))
        wantsLayer = true
        layer!.contents = frozen
        layer!.contentsScale = screen.backingScaleFactor
        layer!.contentsGravity = .resize
        veil.frame = bounds
        veil.backgroundColor = NSColor.black.cgColor
        veil.opacity = 0.6
        hole.fillRule = .evenOdd
        hole.fillColor = NSColor.black.cgColor
        veil.mask = hole
        windowTint.fillColor = NSColor(red: 0.45, green: 0.7, blue: 1, alpha: 0.5).cgColor
        windowFrame.fillColor = nil
        windowFrame.strokeColor = NSColor.white.cgColor
        windowFrame.lineWidth = 2
        frameBase.fillColor = nil
        frameBase.strokeColor = NSColor.white.cgColor
        frameBase.lineWidth = 1
        frameLayer.fillColor = nil
        frameLayer.strokeColor = NSColor.white.cgColor
        handlesLayer.fillColor = NSColor.white.cgColor
        handleDots.fillColor = NSColor(white: 0.5, alpha: 1).cgColor
        labelBack.backgroundColor = NSColor(white: 0, alpha: 0.7).cgColor
        labelBack.cornerRadius = 4
        label.fontSize = 10
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        label.foregroundColor = NSColor(white: 1, alpha: 0.75).cgColor
        label.alignmentMode = .center
        label.contentsScale = screen.backingScaleFactor
        windowGroup.frame = bounds
        windowGroup.addSublayer(windowTint)
        windowGroup.addSublayer(windowFrame)
        windowGroup.mask = windowMask
        for l in [veil, windowGroup, frameBase, frameLayer, handlesLayer, handleDots, labelBack, label] { layer!.addSublayer(l) }
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
            // Like the system: with a selection up, corners and edges resize it, its inside moves
            // it, and only ⌘-click starts a fresh one from the cursor.
            if let r = session.selection, !event.modifierFlags.contains(.command) {
                if let i = handle(of: r, at: p) { drag = .resize(i); return }
                if r.contains(p) { drag = .move(CGPoint(x: p.x - r.minX, y: p.y - r.minY)); return }
                return
            }
            drag = .new(p)
        }
    }

    /// The handle under `p`: a corner within 8 pt, else an edge within 6 pt.
    private func handle(of r: CGRect, at p: CGPoint) -> Int? {
        if let i = [0, 2, 4, 6].first(where: { handlePoint(r, $0).distance(to: p) < 8 }) { return i }
        let inX = (r.minX - 6...r.maxX + 6).contains(p.x), inY = (r.minY - 6...r.maxY + 6).contains(p.y)
        if inX && abs(p.y - r.minY) < 6 { return 1 }
        if inY && abs(p.x - r.maxX) < 6 { return 3 }
        if inX && abs(p.y - r.maxY) < 6 { return 5 }
        if inY && abs(p.x - r.minX) < 6 { return 7 }
        return nil
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
        if let r = session.selection, !NSEvent.modifierFlags.contains(.command) {
            if let i = handle(of: r, at: p) {
                let positions: [NSCursor.FrameResizePosition] = [.bottomLeft, .bottom, .bottomRight, .right, .topRight, .top, .topLeft, .left]
                return .frameResize(position: positions[i], directions: .all)
            }
            if r.contains(p) { return .openHand }
        }
        // Outside the box the screen is veiled, where the dark cross would vanish.
        return session.selection == nil ? .selection : .selectionLight
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

    // MARK: Layers

    /// Called by the session after any hover or state change.
    func update() {
        let target = session.state.target
        // One veil, framed in white on what the click would take: the window and the selection
        // are cut out of it, a whole screen stays under it or nothing would look dark.
        var cut: CGRect?
        var text: String?
        switch target {
        case .screen:
            if session.hoverScreen == screen { cut = bounds; text = pixels(screen.frame) }
        case .window:
            if let w = session.hoverWindow { text = w.app }
        case .area:
            if let sel = session.selection, screen.frame.contains(sel) { cut = local(sel); text = pixels(sel) }
        }
        let rounded = target != .area

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        veil.opacity = target == .window ? 0 : 0.6
        if target == .window, let w = session.hoverWindow {
            let r = local(w.frame)
            // 17 pt: a circle fitted to a macOS 26 window's corner in a shadowless capture.
            windowTint.path = CGPath(roundedRect: r, cornerWidth: 17, cornerHeight: 17, transform: nil)
            // Stroke just outside the window, concentric: its inner edge is the window's own edge.
            windowFrame.path = CGPath(roundedRect: r.insetBy(dx: -1, dy: -1), cornerWidth: 18, cornerHeight: 18, transform: nil)
            // The list is front to back: everything before the hovered window covers it.
            let fronts = session.windows.prefix { $0.id != w.id }.map { local($0.frame) }
            let mask = CGMutablePath()
            for part in visible(r, behind: Array(fronts)) { mask.addRect(part) }
            // Windows in front have round corners: give the cut the same, by adding back the
            // slivers between each square corner and its arc.
            for f in fronts { addFillets(of: f, inside: r, to: mask) }
            windowMask.path = mask
        } else {
            windowTint.path = nil
            windowFrame.path = nil
        }
        let path = CGMutablePath()
        path.addRect(bounds)
        if let cut, target != .screen { path.addRect(cut) }
        hole.path = path
        if target == .window, let text {
            // The window's name sits above the bar, centred on the screen.
            frameLayer.path = nil; frameBase.path = nil; handlesLayer.path = nil; handleDots.path = nil
            label.string = text
            let size = (text as NSString).size(withAttributes: [.font: label.font as! NSFont])
            let box = CGRect(x: (bounds.midX - size.width / 2 - 6).rounded(),
                             y: local(screen.visibleFrame).minY + 24 + Bar.height + 12,
                             width: size.width + 12, height: size.height + 6)
            labelBack.frame = box
            label.frame = box.insetBy(dx: 0, dy: 3)
        } else if let cut {
            // The selection: a black dotted line, white handles with a gray core.
            frameLayer.lineWidth = rounded ? 2 : 1
            frameLayer.strokeColor = (rounded ? NSColor.white : NSColor.black).cgColor
            frameLayer.lineDashPattern = rounded ? nil : [4, 4]
            frameLayer.path = target == .screen ? screenFrame(cut.insetBy(dx: 1, dy: 1))
                : rounded ? CGPath(roundedRect: cut.insetBy(dx: 1, dy: 1), cornerWidth: 10, cornerHeight: 10, transform: nil)
                : CGPath(rect: cut.insetBy(dx: -0.5, dy: -0.5), transform: nil)
            frameBase.path = rounded ? nil : frameLayer.path
            let handles = CGMutablePath(), dots = CGMutablePath()
            if target == .area {
                for i in 0..<8 {
                    let p = handlePoint(cut, i)
                    handles.addEllipse(in: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10))
                    dots.addEllipse(in: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5))
                }
            }
            handlesLayer.path = handles
            handleDots.path = dots
            label.string = text
            let size = (text! as NSString).size(withAttributes: [.font: label.font as! NSFont])
            var box = CGRect(x: cut.minX, y: cut.minY - size.height - 10, width: size.width + 12, height: size.height + 6)
            if box.minY < 0 { box.origin.y = cut.minY + 4 }
            if box.maxX > bounds.maxX { box.origin.x = bounds.maxX - box.width }
            if target == .screen { box.origin = CGPoint(x: bounds.midX - box.width / 2, y: bounds.maxY - box.height - 40) }
            labelBack.frame = box
            label.frame = box.insetBy(dx: 0, dy: 3)
        } else {
            frameLayer.path = nil
            frameBase.path = nil
            handlesLayer.path = nil
            handleDots.path = nil
            labelBack.frame = .zero
            label.frame = .zero
        }
        CATransaction.commit()
    }

    /// The four corner slivers of `f` (a macOS window's 17 pt radius), for the corners that
    /// fall inside `r`: square corner minus quarter disc.
    private func addFillets(of f: CGRect, inside r: CGRect, to path: CGMutablePath) {
        let radius: CGFloat = 17
        for (sx, sy) in [(1.0, 1.0), (-1.0, 1.0), (-1.0, -1.0), (1.0, -1.0)] as [(CGFloat, CGFloat)] {
            let corner = CGPoint(x: sx > 0 ? f.minX : f.maxX, y: sy > 0 ? f.minY : f.maxY)
            guard r.insetBy(dx: 1, dy: 1).contains(corner) else { continue }
            let onX = CGPoint(x: corner.x + sx * radius, y: corner.y)    // where the arc meets the x edge
            let onY = CGPoint(x: corner.x, y: corner.y + sy * radius)
            path.move(to: corner)
            path.addLine(to: onX)
            path.addArc(tangent1End: corner, tangent2End: onY, radius: radius)
            path.addLine(to: onY)
            path.closeSubpath()
        }
    }

    /// The display's own outline: round top corners on a notched panel, square everywhere else.
    private func screenFrame(_ r: CGRect) -> CGPath {
        let top: CGFloat = screen.safeAreaInsets.top > 0 ? 12 : 0
        let p = CGMutablePath()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - top))
        p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.maxX - top, y: r.maxY), radius: top)
        p.addLine(to: CGPoint(x: r.minX + top, y: r.maxY))
        p.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.maxY - top), radius: top)
        p.closeSubpath()
        return p
    }

    private func pixels(_ r: CGRect) -> String {
        let s = screen.backingScaleFactor
        return "\(Int(r.width * s)) × \(Int(r.height * s))"
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
    static let selectionLight = system("screenshotselection", hotSpot: CGPoint(x: 15, y: 15), white: true) ?? .crosshair

    private static func system(_ name: String, hotSpot: CGPoint, white: Bool = false) -> NSCursor? {
        let base = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/Resources/cursors/"
        guard let pdf = NSImage(contentsOfFile: base + name + "/cursor.pdf") else { return nil }
        let img = NSImage(size: pdf.size, flipped: false) { r in
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(white ? 0.8 : 0.45)
            shadow.shadowOffset = CGSize(width: 0, height: -1)
            shadow.shadowBlurRadius = 2
            shadow.set()
            if white {
                let tinted = NSImage(size: pdf.size, flipped: false) { rr in
                    pdf.draw(in: rr)
                    NSColor.white.set()
                    rr.fill(using: .sourceAtop)
                    return true
                }
                tinted.draw(in: r)
            } else {
                pdf.draw(in: r)
            }
            return true
        }
        return NSCursor(image: img, hotSpot: hotSpot)
    }
}
