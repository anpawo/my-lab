import AppKit
import AVFoundation
import Carbon.HIToolbox
import ScreenCaptureKit
import ScreenshotCore

/// The bar and its overlays, from ⌘⇧5 to the file on disk.
@MainActor
final class Session {
    static let shared = Session()

    var state = Settings.bar
    /// AppKit global points; only for area and text.
    var selection: CGRect? = Settings.lastRect
    var hoverWindow: WindowInfo?
    var hoverScreen: NSScreen?
    private(set) var windows: [WindowInfo] = []
    private var overlays: [Overlay] = []
    private var bar: Bar?
    private let recorder = Recorder()
    private var clock: Timer?
    private var opening = false
    var onRecordingChange: ((String?) -> Void)?

    var isOpen: Bool { !overlays.isEmpty }

    /// ⌘⇧5: open; open again: photo ↔ video; while recording: stop.
    func toggle() {
        if recorder.isRecording { stopRecording(); return }
        // Without the grant ScreenCaptureKit fails silently; this opens the right Settings pane.
        NSLog("screenshot: ⌘⇧5")
        guard CGPreflightScreenCaptureAccess() else {
            NSLog("screenshot: no Screen Recording permission")
            // Prompts once; afterwards it is a no-op, so open the pane ourselves.
            if !CGRequestScreenCaptureAccess() {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
            }
            return
        }
        if isOpen { state.toggleKind(); refresh(); return }
        open()
    }

    func open() {
        guard !isOpen, !opening else { return }
        opening = true
        state = Settings.bar
        hoverScreen = NSScreen.underMouse
        windows = Capture.windows()
        Task {
            var frozen: [CGDirectDisplayID: CGImage] = [:]
            do {
                // Every display at once: the screen is frozen as of a single instant.
                try await withThrowingTaskGroup(of: (CGDirectDisplayID, CGImage).self) { group in
                    for screen in NSScreen.screens {
                        group.addTask { (screen.displayID, try await Capture.screen(screen)) }
                    }
                    for try await (id, image) in group { frozen[id] = image }
                }
            } catch {
                NSLog("screenshot: \(error.localizedDescription)")
                opening = false
                return
            }
            opening = false
            guard !isOpen else { return }
            if let r = selection, !NSScreen.screens.contains(where: { $0.frame.contains(r) }) { selection = nil }
            overlays = NSScreen.screens.map { Overlay(screen: $0, frozen: frozen[$0.displayID]!, session: self) }
            overlays.forEach { $0.orderFrontRegardless() }
            let under = NSScreen.underMouse
            (overlays.first { $0.display == under } ?? overlays[0]).makeKey()
            bar = Bar(session: self, on: under)
            bar?.orderFrontRegardless()
            refresh()
            // Escape and Return as system-wide chords while the overlay is up: a non-activating
            // panel does not always get key events, and these two must never depend on it.
            HotKey.register(key: kVK_Escape, modifiers: 0, id: 2) { Task { @MainActor in Session.shared.close() } }
            HotKey.register(key: kVK_Return, modifiers: 0, id: 3) { Task { @MainActor in Session.shared.commit() } }
        }
    }

    func close() {
        HotKey.unregister(id: 2)
        HotKey.unregister(id: 3)
        overlays.forEach { $0.orderOut(nil) }
        overlays = []
        bar?.orderOut(nil)
        bar = nil
        hoverWindow = nil
        hoverScreen = nil
        Settings.bar = state
        Settings.lastRect = selection
    }

    func step(_ delta: Int) { state.step(delta); refresh() }
    func set(_ target: Target) { state.target = target; refresh() }
    func toggleKind() { state.toggleKind(); refresh() }

    func nudge(dx: CGFloat, dy: CGFloat, resize: Bool) {
        guard let r = selection else { return }
        selection = ScreenshotCore.nudge(r, dx: dx, dy: dy, resize: resize, bounds: NSScreen.containing(r).frame)
        refresh()
    }

    /// After a state change: the bar and every overlay. Panels at screen-saver level do not
    /// always flush a `needsDisplay` without a mouse event, so this draws now.
    func refresh() {
        bar?.refresh()
        overlays.forEach { $0.contentView?.needsDisplay = true; $0.contentView?.display() }
    }

    /// After a hover change: overlays only. Touching the bar on every mouse move made it flash.
    func redraw() {
        overlays.forEach { $0.contentView?.needsDisplay = true }
    }

    func makeKey(_ overlay: Overlay) {
        if !overlay.isKeyWindow { overlay.makeKey() }
    }

    // MARK: Commit

    /// Enter, the Capture button, or a click on a screen or window.
    func commit(screen: NSScreen? = nil, window: WindowInfo? = nil) {
        let state = state
        let selection = selection
        let window = window ?? hoverWindow
        let shadow = !NSEvent.modifierFlags.contains(.option)
        if state.needsSelection && selection == nil { return }
        if state.target == .window && window == nil { return }
        let frozen = Dictionary(uniqueKeysWithValues: overlays.map { ($0.display.displayID, $0.frozen) })
        close()
        if state.kind == .video { startRecording(state.target, screen: screen, window: window, rect: selection); return }

        Task {
            do {
                let live = Settings.timer > 0
                if live { try await Task.sleep(for: .seconds(Settings.timer)) }
                switch state.target {
                case .screen:
                    var last: (URL, CGImage, CGRect)?
                    for s in screen.map({ [$0] }) ?? NSScreen.screens {
                        let image = live ? try await Capture.screen(s) : frozen[s.displayID]!
                        last = (try Output.save(image, scale: s.backingScaleFactor), image, s.frame)
                    }
                    if let (url, image, rect) = last { Thumbnail.show(.image(image, url, rect)) }
                case .window:
                    let w = window!
                    let image = try await Capture.window(w, shadow: shadow)
                    let url = try Output.save(image, scale: NSScreen.containing(w.frame).backingScaleFactor, app: w.app)
                    Thumbnail.show(.image(image, url, w.frame))
                case .area, .text:
                    let r = selection!.integral
                    let s = NSScreen.containing(r)
                    let image = live ? try await Capture.area(r, on: s)
                        : frozen[s.displayID]!.cropping(to: pixelCrop(r, in: s.frame, scale: s.backingScaleFactor))!
                    if state.target == .area {
                        Thumbnail.show(.image(image, try Output.save(image, scale: s.backingScaleFactor), r))
                    } else {
                        let text = try await OCR.text(in: image)
                        Output.copy(text: text)
                        Thumbnail.show(.text(text))
                    }
                }
            } catch {
                NSLog("screenshot: \(error.localizedDescription)")
            }
            Capture.prefetch()
        }
    }

    // MARK: Video

    private func startRecording(_ target: Target, screen: NSScreen?, window: WindowInfo?, rect: CGRect?) {
        Task {
            do {
                switch target {
                case .screen:
                    let s = screen ?? NSScreen.underMouse
                    let (_, filter) = try await Capture.displayFilter(s)
                    try await recorder.start(filter: filter, size: s.frame.size, scale: s.backingScaleFactor)
                case .window:
                    guard let w = window, let sc = try await Capture.content().windows.first(where: { $0.windowID == w.id }) else { return }
                    let filter = SCContentFilter(desktopIndependentWindow: sc)
                    try await recorder.start(filter: filter, size: filter.contentRect.size, scale: CGFloat(filter.pointPixelScale))
                case .area, .text:
                    let r = rect!.integral
                    let s = NSScreen.containing(r)
                    let (_, filter) = try await Capture.displayFilter(s)
                    try await recorder.start(filter: filter, size: r.size, scale: s.backingScaleFactor,
                                             sourceRect: displayLocal(r, in: s.frame))
                }
            } catch {
                NSLog("screenshot: \(error.localizedDescription)")
                return
            }
            clock = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
            tick()
        }
    }

    private func tick() {
        let t = Int(Date().timeIntervalSince(recorder.started))
        onRecordingChange?(String(format: "● %d:%02d", t / 60, t % 60))
    }

    func stopRecording() {
        clock?.invalidate()
        clock = nil
        onRecordingChange?(nil)
        Task {
            guard let url = await recorder.stop() else { return }
            Output.remember(url)
            let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            gen.appliesPreferredTrackTransform = true
            let frame = try? await gen.image(at: .zero).image
            Thumbnail.show(.movie(frame, url))
            Capture.prefetch()
        }
    }
}
