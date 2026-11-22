import AppKit
import ScreenSaver

/// Borderless windows can't become key by default; we need key events for s / q / Esc.
final class SaverWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "q", "\u{1B}":
            NSApp.terminate(nil)
        case "s":
            (NSApp.delegate as? AppDelegate)?.openConfigureSheet()
        default:
            super.keyDown(with: event)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windows: [SaverWindow] = []
    private var views: [MatrixSaverView] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--preview") {
            openPreview()
        } else {
            openFullScreen()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        views.forEach { $0.stopAnimation() }
    }

    /// Opens the configure sheet on the main-screen window, whichever window received the key.
    func openConfigureSheet() {
        let target = windows.first { $0.screen == NSScreen.main } ?? windows.first
        guard let target, target.attachedSheet == nil,
              let view = target.contentView as? MatrixSaverView,
              let sheet = view.configureSheet else { return }
        target.makeKeyAndOrderFront(nil)
        target.beginSheet(sheet)
    }

    private func openPreview() {
        let rect = NSRect(x: 0, y: 0, width: 320, height: 200)
        let window = SaverWindow(contentRect: rect, styleMask: [.titled, .closable],
                                 backing: .buffered, defer: false)
        window.title = "Matrix Preview"
        window.isReleasedWhenClosed = false
        install(in: window, rect: rect, isPreview: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func openFullScreen() {
        for screen in NSScreen.screens {
            let window = SaverWindow(contentRect: screen.frame, styleMask: [.borderless],
                                     backing: .buffered, defer: false, screen: screen)
            window.level = .screenSaver
            window.isReleasedWhenClosed = false
            window.backgroundColor = .black
            install(in: window, rect: NSRect(origin: .zero, size: screen.frame.size), isPreview: false)
            window.setFrame(screen.frame, display: true)
            window.orderFront(nil)
        }
        // Make the main-screen window key (last-ordered window would otherwise win).
        (windows.first { $0.screen == NSScreen.main } ?? windows.first)?.makeKeyAndOrderFront(nil)
    }

    private func install(in window: SaverWindow, rect: NSRect, isPreview: Bool) {
        guard let view = MatrixSaverView(frame: rect, isPreview: isPreview) else { return }
        view.autoresizingMask = [.width, .height]
        window.contentView = view
        window.makeFirstResponder(view)
        windows.append(window)
        views.append(view)
        view.startAnimation()
    }
}

if CommandLine.arguments.contains("--record") {
    exit(MainActor.assumeIsolated { DemoRecorder.run(CommandLine.arguments) })
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
