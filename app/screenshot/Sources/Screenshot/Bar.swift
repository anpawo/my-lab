import AppKit
import ScreenshotCore

/// The ⌘⇧5 strip, laid out like the system's: ✕, the stills, the recordings, Options, the
/// button. Never key: keys go to the overlay.
final class Bar: NSPanel {
    // Apple's geometry, measured on the system bar at 2×: 53 pt tall, ✕ at 14.5, stills on a
    // 50 pt pitch in 44×36 buttons, recordings on a 59.25 pt pitch in 53-wide ones, dividers
    // 10 and 7 pt after the groups, Options 17.5 pt after, the button 15 pt after that.
    static let height: CGFloat = 53
    private unowned let session: Session
    private var buttons: [ModeButton] = []
    private let go = NSButton()
    private let options = NSButton()

    init(session: Session, on screen: NSScreen) {
        self.session = session
        super.init(contentRect: CGRect(x: 0, y: 0, width: 700, height: Bar.height), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        animationBehavior = .none
        isReleasedWhenClosed = false
        sharingType = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        acceptsMouseMovedEvents = true
        let back = NSVisualEffectView()
        back.material = .popover
        back.state = .active
        // An effect view ignores its layer's corner radius; its mask image is what rounds it.
        back.maskImage = Bar.roundedMask
        contentView = back
        // The overlay sets its own cursor on every move; the bar takes the arrow back.
        back.addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect], owner: self))

        let mid = Bar.height / 2
        let close = NSButton(image: Glyph.close, target: self, action: #selector(cancel))
        close.isBordered = false
        close.imagePosition = .imageOnly
        close.contentTintColor = NSColor.labelColor.withAlphaComponent(0.4)
        close.frame = CGRect(x: 14.5, y: mid - 8.5, width: 17, height: 17)
        back.addSubview(close)

        var x: CGFloat = 43.75
        for state in BarState.all {
            let b = ModeButton(state: state, target: self, action: #selector(pick(_:)))
            let wide = state.kind == .video
            if wide && buttons.last?.mode.kind == .photo {
                back.addSubview(Bar.divider(at: x + 4))       // 10 pt after the last still
                x += 16.5
            }
            b.frame = CGRect(x: x, y: mid - 18, width: wide ? 53 : 44, height: 36)
            x += wide ? 59.25 : 50
            back.addSubview(b)
            buttons.append(b)
        }
        back.addSubview(Bar.divider(at: x + 0.75))            // 7 pt after the last recording
        x += 18.25

        options.title = "Options"
        options.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 9, weight: .semibold))
        options.imagePosition = .imageTrailing
        options.imageHugsTitle = true
        options.isBordered = false
        options.font = .systemFont(ofSize: 15)
        options.contentTintColor = .labelColor
        options.target = self
        options.action = #selector(showOptions)
        options.sizeToFit()
        options.frame = CGRect(x: x, y: mid - options.frame.height / 2, width: options.frame.width + 4, height: options.frame.height)
        back.addSubview(options)
        x = options.frame.maxX + 15

        // Painted by hand: AppKit only tints a default button in a key window, and this one never is.
        go.isBordered = false
        go.font = .systemFont(ofSize: 15, weight: .medium)
        go.wantsLayer = true
        go.layer?.cornerRadius = 8
        go.target = self
        go.action = #selector(commit)
        go.frame = CGRect(x: x, y: mid - 18.25, width: 100, height: 36.5)
        back.addSubview(go)
        refresh()

        let width = go.frame.maxX + 8.5
        back.frame = CGRect(x: 0, y: 0, width: width, height: Bar.height)
        let v = screen.visibleFrame
        setFrame(CGRect(x: (v.midX - width / 2).rounded(), y: v.minY + 24, width: width, height: Bar.height), display: false)
    }

    override var canBecomeKey: Bool { false }
    override func mouseEntered(with event: NSEvent) { NSCursor.arrow.set() }
    override func mouseMoved(with event: NSEvent) { NSCursor.arrow.set() }

    func refresh() {
        let s = session.state
        for b in buttons { b.isSelected = b.mode == s }
        let title = s.kind == .photo ? "Capture" : "Enregistrer"
        go.attributedTitle = NSAttributedString(string: title, attributes: [.foregroundColor: NSColor.white, .font: go.font!])
        go.isEnabled = !(s.needsSelection && session.selection == nil)
        go.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(go.isEnabled ? 1 : 0.4).cgColor
        let w = max(81.5, (title as NSString).size(withAttributes: [.font: go.font!]).width + 30)
        if go.frame.width != w {
            go.frame.size.width = w
            let width = go.frame.maxX + 8.5
            contentView?.frame.size.width = width
            setFrame(CGRect(x: (frame.midX - width / 2).rounded(), y: frame.minY, width: width, height: Bar.height), display: true)
        }
    }

    /// The bar as pixels, at 2×, without ever being on screen.
    func render() -> Data? {
        let view = contentView!
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width * 2), pixelsHigh: Int(view.bounds.height * 2),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep.representation(using: .png, properties: [:])
    }

    private static let roundedMask: NSImage = {
        let img = NSImage(size: CGSize(width: 26, height: 26), flipped: false) { r in
            NSBezierPath(roundedRect: r, xRadius: 12, yRadius: 12).fill()
            return true
        }
        img.capInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        img.resizingMode = .stretch
        return img
    }()

    private static func divider(at x: CGFloat) -> NSView {
        let v = NSView(frame: CGRect(x: x, y: (Bar.height - 22) / 2, width: 1, height: 22))
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.18).cgColor
        return v
    }

    @objc private func showOptions() {
        let menu = optionsMenu()
        menu.popUp(positioning: nil, at: CGPoint(x: 0, y: options.bounds.height + 6), in: options)
    }

    /// The system's three sections, filled with what this app actually does.
    private func optionsMenu() -> NSMenu {
        let menu = NSMenu()
        func header(_ t: String) { menu.addItem(withTitle: t, action: nil, keyEquivalent: "") }
        func item(_ t: String, _ sel: Selector, on: Bool, tag: Int = 0) {
            let m = menu.addItem(withTitle: t, action: sel, keyEquivalent: "")
            m.target = self
            m.state = on ? .on : .off
            m.tag = tag
            m.indentationLevel = 1
        }
        header("Enregistrer dans")
        let home = FileManager.default.homeDirectoryForCurrentUser
        for (name, dir) in [("Bureau", home.appendingPathComponent("Desktop")),
                            ("Téléchargements", home.appendingPathComponent("Downloads")),
                            ("Documents", home.appendingPathComponent("Documents"))] {
            item(name, #selector(setFolder(_:)), on: Settings.saves && Settings.folder.path == dir.path)
            menu.items.last!.representedObject = dir
        }
        let custom = ![home.appendingPathComponent("Desktop"), home.appendingPathComponent("Downloads"),
                       home.appendingPathComponent("Documents")].map(\.path).contains(Settings.folder.path)
        if custom { item(Settings.folder.lastPathComponent, #selector(setFolder(_:)), on: Settings.saves)
                    menu.items.last!.representedObject = Settings.folder }
        item("Presse-papiers seulement", #selector(clipboardOnly), on: !Settings.saves)
        item("Autre dossier…", #selector(pickFolder), on: false)
        menu.addItem(.separator())
        header("Minuteur")
        for (t, secs) in [("Aucun", 0), ("5 secondes", 5), ("10 secondes", 10)] {
            item(t, #selector(setTimer(_:)), on: Settings.timer == secs, tag: secs)
        }
        menu.addItem(.separator())
        header("Options")
        item("Afficher la vignette", #selector(toggleThumbnail), on: Settings.thumbnail)
        item("Copier dans le presse-papiers", #selector(toggleCopy), on: Settings.copies)
        item("Afficher le pointeur", #selector(toggleCursor), on: Settings.cursor)
        if session.state.kind == .video { item("Enregistrer le micro", #selector(toggleMic), on: Settings.microphone) }
        return menu
    }

    @objc private func setFolder(_ item: NSMenuItem) {
        Settings.folder = item.representedObject as! URL
        Settings.saves = true
    }
    @objc private func clipboardOnly() { Settings.saves = false; Settings.copies = true }
    @objc private func toggleThumbnail() { Settings.thumbnail.toggle() }
    @objc private func toggleCopy() { Settings.copies.toggle() }

    @objc private func pick(_ b: ModeButton) { session.state = b.mode; session.refresh() }
    @objc private func cancel() { session.close() }
    @objc private func commit() { session.commit() }
    @objc private func setTimer(_ item: NSMenuItem) { Settings.timer = item.tag }
    @objc private func toggleCursor() { Settings.cursor.toggle() }
    @objc private func toggleMic() { Settings.microphone.toggle() }

    @objc private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = Settings.folder
        panel.level = level
        NSApp.activate()
        if panel.runModal() == .OK, let url = panel.url { Settings.folder = url; Settings.saves = true }
    }
}

/// One mode. The selected one sits on a rounded tint, like the system's.
final class ModeButton: NSButton {
    let mode: BarState
    var isSelected = false {
        didSet {
            layer?.backgroundColor = isSelected ? NSColor.labelColor.withAlphaComponent(0.1).cgColor : nil
            contentTintColor = NSColor.labelColor.withAlphaComponent(isSelected ? 0.95 : 0.7)
        }
    }

    init(state: BarState, target: AnyObject, action: Selector) {
        self.mode = state
        super.init(frame: .zero)
        self.target = target
        self.action = action
        image = Glyph.image(for: state)
        isBordered = false
        imagePosition = .imageOnly
        contentTintColor = NSColor.labelColor.withAlphaComponent(0.7)
        toolTip = Glyph.tip[state.target]! + (state.kind == .video ? " (vidéo)" : "")
        wantsLayer = true
        layer?.cornerRadius = 8
    }
    required init?(coder: NSCoder) { nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// The system's glyphs, traced from its bar: a 28.5 × 22.5 rounded rect with a 2 pt stroke and
/// 4.5 pt corners; a menu-bar line and a dock for the display, three dots for the window,
/// dashes for the area; the recordings add a ring badge that punches through the corner.
enum Glyph {
    static let tip: [Target: String] = [.screen: "Écran entier", .window: "Fenêtre", .area: "Zone"]

    static func image(for s: BarState) -> NSImage {
        let recording = s.kind == .video
        let size = recording ? CGSize(width: 34, height: 25) : CGSize(width: 29, height: 22.5)
        let img = NSImage(size: size, flipped: true) { _ in
            let r = CGRect(x: 1, y: 1, width: 26.5, height: 20.5)      // 2 pt stroke, centred on 1
            let stroke = NSBezierPath()
            stroke.lineWidth = 2
            stroke.lineCapStyle = .butt
            let radius: CGFloat = 4.5
            switch s.target {
            case .screen, .window:
                stroke.appendRoundedRect(r, xRadius: radius, yRadius: radius)
            case .area:
                // Solid corners, two dashes on the long edges, one on the short ones.
                dashedRoundedRect(r, radius: radius, into: stroke)
            }
            stroke.stroke()
            switch s.target {
            case .screen:
                let bar = NSBezierPath()
                bar.move(to: CGPoint(x: r.minX + 1, y: 5)); bar.line(to: CGPoint(x: r.maxX - 1, y: 5))
                bar.lineWidth = 2
                bar.stroke()
                NSBezierPath(roundedRect: CGRect(x: 6, y: 14.5, width: 17.5, height: 3.5), xRadius: 1.75, yRadius: 1.75).fill()
            case .window:
                for i in 0..<3 { NSBezierPath(ovalIn: CGRect(x: 4.2 + CGFloat(i) * 3.4, y: 4.2, width: 2.2, height: 2.2)).fill() }
            case .area: break
            }
            if recording {
                let ctx = NSGraphicsContext.current!
                ctx.compositingOperation = .destinationOut
                NSBezierPath(ovalIn: CGRect(x: 19.75, y: 10.75, width: 15.5, height: 15.5)).fill()
                ctx.compositingOperation = .sourceOver
                let ring = NSBezierPath(ovalIn: CGRect(x: 22.25, y: 13.25, width: 10.5, height: 10.5))
                ring.lineWidth = 2
                ring.stroke()
                NSBezierPath(ovalIn: CGRect(x: 24, y: 15, width: 7, height: 7)).fill()
            }
            return true
        }
        img.isTemplate = true
        return img
    }

    private static func dashedRoundedRect(_ r: CGRect, radius: CGFloat, into p: NSBezierPath) {
        func dashes(from a: CGPoint, to b: CGPoint, count: Int) {
            let len = hypot(b.x - a.x, b.y - a.y)
            let gap = (len - CGFloat(count) * 5.5) / CGFloat(count + 1)
            let ux = (b.x - a.x) / len, uy = (b.y - a.y) / len
            for i in 0..<count {
                let s = gap + CGFloat(i) * (5.5 + gap)
                p.move(to: CGPoint(x: a.x + ux * s, y: a.y + uy * s))
                p.line(to: CGPoint(x: a.x + ux * (s + 5.5), y: a.y + uy * (s + 5.5)))
            }
        }
        dashes(from: CGPoint(x: r.minX + radius, y: r.minY), to: CGPoint(x: r.maxX - radius, y: r.minY), count: 2)
        dashes(from: CGPoint(x: r.maxX, y: r.minY + radius), to: CGPoint(x: r.maxX, y: r.maxY - radius), count: 1)
        dashes(from: CGPoint(x: r.minX + radius, y: r.maxY), to: CGPoint(x: r.maxX - radius, y: r.maxY), count: 2)
        dashes(from: CGPoint(x: r.minX, y: r.minY + radius), to: CGPoint(x: r.minX, y: r.maxY - radius), count: 1)
        // The four corners: quarter arcs, in the flipped (y-down) space.
        for (cx, cy, a0) in [(r.maxX - radius, r.minY + radius, 270.0), (r.maxX - radius, r.maxY - radius, 0.0),
                             (r.minX + radius, r.maxY - radius, 90.0), (r.minX + radius, r.minY + radius, 180.0)] as [(CGFloat, CGFloat, Double)] {
            let arc = NSBezierPath()
            arc.appendArc(withCenter: CGPoint(x: cx, y: cy), radius: radius, startAngle: a0, endAngle: a0 + 90)
            p.append(arc)
        }
    }

    /// The ✕: a 17 pt disc with a knocked-out cross.
    static let close: NSImage = {
        let img = NSImage(size: CGSize(width: 17, height: 17), flipped: true) { _ in
            NSBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 17, height: 17)).fill()
            NSGraphicsContext.current!.compositingOperation = .destinationOut
            let x = NSBezierPath()
            x.move(to: CGPoint(x: 5.5, y: 5.5)); x.line(to: CGPoint(x: 11.5, y: 11.5))
            x.move(to: CGPoint(x: 11.5, y: 5.5)); x.line(to: CGPoint(x: 5.5, y: 11.5))
            x.lineWidth = 1.8
            x.lineCapStyle = .round
            x.stroke()
            return true
        }
        img.isTemplate = true
        return img
    }()
}
