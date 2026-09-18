// Throwaway full-screen app used by fullscreen_overlay_test.sh inside the Tart VM.
// One loud window that goes full screen (its own Space) right after launch, with a text
// field holding keyboard focus. It reports its own state on screen and in
// /tmp/fshost-state.txt so a script can tell whether it stayed active / key / full screen
// while 好查经 is summoned on top of it.
//
//   swiftc -O -o FullscreenHost FullscreenHost.swift      (the test script does this)
import AppKit

final class Delegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let status = NSTextField(labelWithString: "")
    let field = NSTextField(string: "")
    var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 900, height: 600),
                          styleMask: [.titled, .closable, .resizable, .miniaturizable],
                          backing: .buffered, defer: false)
        window.title = "FullscreenHost"
        window.collectionBehavior = [.fullScreenPrimary]
        window.backgroundColor = NSColor(red: 1.0, green: 0.0, blue: 0.55, alpha: 1)

        let title = NSTextField(labelWithString: "FULLSCREEN HOST")
        title.font = .boldSystemFont(ofSize: 96)
        title.textColor = .white
        status.font = .monospacedSystemFont(ofSize: 28, weight: .bold)
        status.textColor = .yellow
        field.font = .systemFont(ofSize: 24)
        field.placeholderString = "keyboard focus lives here"
        field.widthAnchor.constraint(equalToConstant: 500).isActive = true

        let stack = NSStackView(views: [title, status, field])
        stack.orientation = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = window.contentView!
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -60),
        ])

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(field)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.window.toggleFullScreen(nil) }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in self.report() }
    }

    func report() {
        let full = window.styleMask.contains(.fullScreen)
        let line = "active=\(NSApp.isActive ? 1 : 0) key=\(window.isKeyWindow ? 1 : 0) fullscreen=\(full ? 1 : 0) onActiveSpace=\(window.isOnActiveSpace ? 1 : 0)"
        status.stringValue = line
        try? (line + "\n").write(toFile: "/tmp/fshost-state.txt", atomically: true, encoding: .utf8)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
