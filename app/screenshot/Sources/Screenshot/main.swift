import AppKit
import Carbon.HIToolbox
import ScreenshotCore

@MainActor
final class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var status: NSStatusItem?
    private let recent = NSMenu()
    private var stopItem: NSMenuItem?

    func applicationDidFinishLaunching(_ note: Notification) {
        // An agent with no window is a candidate for automatic termination; that is how it
        // "crashed" without a crash report.
        ProcessInfo.processInfo.disableAutomaticTermination("hotkey listener")
        ProcessInfo.processInfo.disableSuddenTermination()
        Capture.prefetch()
        if let i = CommandLine.arguments.firstIndex(of: "--render-bar") {
            // The bar as a PNG, never shown: how its look gets checked without a window.
            Session.shared.selection = CGRect(x: 0, y: 0, width: 10, height: 10)
            let bar = Bar(session: Session.shared, on: NSScreen.main!)
            try? bar.render()?.write(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
            exit(0)
        }
        if CommandLine.arguments.contains("--screen") {
            // Headless check: every display to the folder, then exit.
            Task {
                for s in NSScreen.screens {
                    do { print(try Output.save(try await Capture.screen(s), scale: s.backingScaleFactor).path) }
                    catch { print("error: \(error.localizedDescription)"); exit(1) }
                }
                exit(0)
            }
            return
        }
        HotKey.register(key: kVK_ANSI_5, modifiers: cmdKey | shiftKey, id: 1) {
            Task { @MainActor in Session.shared.toggle() }
        }
        installMenu()
        Session.shared.onRecordingChange = { [weak self] title in
            guard let button = self?.status?.button else { return }
            self?.stopItem?.isHidden = title == nil
            if let title {
                button.image = nil
                button.attributedTitle = NSAttributedString(string: title, attributes: [.foregroundColor: NSColor.systemRed])
            } else {
                button.attributedTitle = NSAttributedString()
                button.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "screenshot")
            }
        }
    }

    private func installMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "screenshot")
        let menu = NSMenu()
        let capture = menu.addItem(withTitle: "Capture…", action: #selector(capture), keyEquivalent: "5")
        capture.keyEquivalentModifierMask = [.command, .shift]
        capture.target = self
        let stop = menu.addItem(withTitle: "Stop Recording", action: #selector(stopRecording), keyEquivalent: "")
        stop.target = self
        stop.isHidden = true
        stopItem = stop
        let recentItem = menu.addItem(withTitle: "Recent", action: nil, keyEquivalent: "")
        recent.delegate = self
        recentItem.submenu = recent
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        status = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let urls = Output.recent()
        if urls.isEmpty { menu.addItem(withTitle: "None", action: nil, keyEquivalent: "") }
        for url in urls {
            let m = menu.addItem(withTitle: url.lastPathComponent, action: #selector(openRecent(_:)), keyEquivalent: "")
            m.target = self
            m.representedObject = url
        }
    }

    @objc private func capture() {
        // Let the menu close before the freeze, or it ends up in the picture.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { Session.shared.toggle() }
    }
    @objc private func stopRecording() { Session.shared.stopRecording() }
    @objc private func openRecent(_ item: NSMenuItem) {
        if let url = item.representedObject as? URL { NSWorkspace.shared.open(url) }
    }
}

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { App() }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
