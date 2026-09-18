import AppKit
import SwiftUI

/// The search window is an `NSPanel` so that it can carry `.nonactivatingPanel`: the one
/// style that lets a window take the keyboard while its app stays in the background.
/// That is what makes the hotkey an overlay (Spotlight / Raycast style) instead of an app
/// switch, and an app switch is what drags the user out of a full-screen Space.
/// Apart from that it is dressed as an ordinary main window (title bar, close button,
/// resizable, listed in the 窗口 menu, can be main).
final class SearchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// The app's main window: the search bar with live results. Summoned by the global
/// hotkeys, ⌘F, the Dock icon or the 文件 menu; hidden with esc / ⌘W.
///
/// Two ways of coming up:
///   * overlay   (hotkey / menu-bar icon while another app is frontmost): the panel becomes
///     key WITHOUT activating 好查经, floats above the frontmost app, full screen or not,
///     and on hide the keyboard focus falls straight back to that app.
///   * activated (launch, Dock icon, or the app is already active): a normal app window.
final class SearchWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SearchWindowController()

    let model = SearchViewModel()
    private var keyMonitor: Any?
    private var activeObserver: NSObjectProtocol?

    private init() {
        let window = SearchPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 460),
            // .nonactivatingPanel must be in the mask from the start: AppKit only tells the
            // window server "this window never activates its app" at creation, flipping the
            // bit later is unreliable.
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.title = "好查经"
        window.minSize = NSSize(width: 640, height: 380)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        // NSPanel defaults that do not suit a main window:
        window.hidesOnDeactivate = false          // panels vanish when the app deactivates
        window.isFloatingPanel = false            // level is managed in show()
        window.becomesKeyOnlyIfNeeded = false
        window.isExcludedFromWindowsMenu = false  // panels are left out of the 窗口 menu
        // .fullScreenAuxiliary: allowed to share a Space with another app's full-screen window.
        // .moveToActiveSpace:   when ordered front it comes to the Space the user is on,
        //                       instead of pulling the user to the Space it was last on.
        // (Not .canJoinAllSpaces: this window does not auto-dismiss, so it would follow the
        // user onto every Space until hidden.)
        window.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        window.contentView = NSHostingView(rootView: SearchView(model: model))
        window.center()
        window.setFrameAutosaveName("ChaJingSearch")
        super.init(window: window)
        window.delegate = self
        // Once the user really comes to the app (Dock, ⌘Tab, a reader opens), stop floating
        // so the search stacks with the reader windows like any other window.
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.window?.level = .normal }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Visible and holding the keyboard. Deliberately not tied to `NSApp.isActive`: as an
    /// overlay the panel is key while the app is inactive. (A window of a deactivated app
    /// is never key, so this is still false when the search merely sits behind other apps.)
    var isFrontmost: Bool {
        guard let window else { return false }
        return window.isVisible && window.isKeyWindow
    }

    /// Hotkey behaviour: bring the search up, or put it away if it is already in front.
    func toggle() {
        if isFrontmost { hide() } else { show() }
    }

    /// - Parameter activate: also bring the whole app forward (launch, Dock icon). Leave it
    ///   false for the hotkeys: activating a regular app makes macOS switch to a Space that
    ///   holds its windows, i.e. away from the full-screen app the user is working in.
    func show(activate: Bool = false) {
        guard let window else { return }
        if !window.isVisible {
            model.query = ""
            centerOnActiveScreen()
        }
        installKeyMonitor()
        // Still open on a Space the user has left: take it off screen first, so that it is
        // ordered in afresh on the current Space (the same path as summoning it from hidden).
        if window.isVisible && !window.isOnActiveSpace { window.orderOut(nil) }
        let overlay = !activate && !NSApp.isActive
        // .floating is the lowest level that stays above another app's full-screen window
        // (and above its normal windows) once that app is clicked again. It is only used
        // for the overlay case so that the search never hovers over our own readers.
        window.level = overlay ? .floating : .normal
        window.makeKeyAndOrderFront(nil)
        if activate { NSApp.activate(ignoringOtherApps: true) }
        model.focusToken += 1
    }

    func hide() {
        removeKeyMonitor()
        window?.orderOut(nil)
        window?.level = .normal
    }

    /// ⌘D in the search window: open the selected passage in a new reader window.
    @objc func duplicateWindow(_ sender: Any?) {
        model.openSelected(inNewWindow: true)
    }

    private func centerOnActiveScreen() {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { window.center(); return }
        let size = window.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2 + frame.height * 0.12
        )
        window.setFrameOrigin(origin)
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let window = self.window, window.isKeyWindow else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            switch event.keyCode {
            case 53: // esc
                self.hide(); return nil
            case 125: // down
                self.model.moveSelection(by: 1); return nil
            case 126: // up
                self.model.moveSelection(by: -1); return nil
            case 36, 76: // return / keypad enter
                if flags.contains(.command) {
                    self.model.copySelected()
                } else {
                    self.model.openSelected(inNewWindow: flags.contains(.shift))
                }
                return nil
            case 45 where flags.contains(.control): // ctrl-n
                self.model.moveSelection(by: 1); return nil
            case 35 where flags.contains(.control): // ctrl-p
                self.model.moveSelection(by: -1); return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }

    func windowWillClose(_ notification: Notification) {
        removeKeyMonitor()
    }
}
