import AppKit
import SwiftUI

/// Floating, non-activating panel that can still take keyboard focus (Spotlight style).
final class SearchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class SearchPanelController: NSObject, NSWindowDelegate {
    static let shared = SearchPanelController()

    let model = SearchViewModel()
    private var panel: SearchPanel!
    private var keyMonitor: Any?

    private override init() {
        super.init()
        let panel = SearchPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 460),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.delegate = self

        let visual = NSVisualEffectView()
        visual.material = .hudWindow
        visual.blendingMode = .behindWindow
        visual.state = .active
        let hosting = NSHostingView(rootView: SearchView(model: model))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        visual.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: visual.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: visual.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: visual.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: visual.bottomAnchor),
        ])
        panel.contentView = visual
        self.panel = panel
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        if panel.isVisible { hide() } else { show() }
    }

    func show() {
        model.query = ""
        centerOnActiveScreen()
        installKeyMonitor()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        model.focusToken += 1
    }

    func hide() {
        removeKeyMonitor()
        panel.orderOut(nil)
    }

    private func centerOnActiveScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { panel.center(); return }
        let size = panel.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2 + frame.height * 0.12
        )
        panel.setFrameOrigin(origin)
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            let cmd = event.modifierFlags.contains(.command)
            switch event.keyCode {
            case 53: // esc
                self.hide(); return nil
            case 125: // down
                self.model.moveSelection(by: 1); return nil
            case 126: // up
                self.model.moveSelection(by: -1); return nil
            case 36, 76: // return / keypad enter
                if cmd { self.model.copySelected() } else { self.model.openSelected() }
                return nil
            case 45 where event.modifierFlags.contains(.control): // ctrl-n
                self.model.moveSelection(by: 1); return nil
            case 35 where event.modifierFlags.contains(.control): // ctrl-p
                self.model.moveSelection(by: -1); return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }

    // Behave like Spotlight: clicking elsewhere dismisses the bar.
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
