import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var hotkey: GlobalHotkey?
    private var chord: SpaceChordMonitor?
    private var chordMenuItems: [NSMenuItem] = []
    private var permissionTimer: Timer?
    /// Set only by the explicit 退出 commands; every other quit request just hides windows.
    private var reallyQuit = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = BibleStore.shared // load text up front so the first search is instant
        NSApp.mainMenu = buildMainMenu()
        installStatusItem()

        // Always-available hotkey: Option + Space.
        hotkey = GlobalHotkey { [weak self] in self?.toggleSearch() }
        hotkey?.register()

        // Requested chord: hold Space, press P.
        chord = SpaceChordMonitor { [weak self] in self?.toggleSearch() }
        if !(chord?.start() ?? false) {
            SpaceChordMonitor.requestPermission()
            waitForPermission()
        }
        updateChordMenu()

        SearchWindowController.shared.show(activate: true)
    }

    /// The hotkeys only matter while the app is running, so keep running with no windows.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Only 退出 in the menu-bar icon / app menu really quits. ⌘Q or "退出" from the Dock
    /// just puts the windows away and leaves the app running in the background.
    /// Logout / shutdown / restart carry a quit reason and are always honoured.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if reallyQuit || Self.quitRequestedBySystem { return .terminateNow }
        closeAllWindows()
        return .terminateCancel
    }

    private static var quitRequestedBySystem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventClass == AEEventClass(kCoreEventClass),
              event.eventID == AEEventID(kAEQuitApplication) else { return false }
        return event.attributeDescriptor(forKeyword: AEKeyword(kAEQuitReason)) != nil
    }

    private func closeAllWindows() {
        SearchWindowController.shared.hide()
        AboutWindowController.shared.close()
        for c in ReaderWindows.shared.controllers { c.close() }
    }

    // MARK: - Menu-bar icon

    private func installStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "book.closed", accessibilityDescription: "好查经")
        statusItem.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.addItem(withTitle: "打开搜索  (⌥Space / Space+P)", action: #selector(showSearch), keyEquivalent: "")
        menu.addItem(.separator())
        let chordItem = NSMenuItem(title: "", action: #selector(toggleChord), keyEquivalent: "")
        chordMenuItems.append(chordItem)
        menu.addItem(chordItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "关于好查经", action: #selector(about), keyEquivalent: "")
        menu.addItem(withTitle: "退出好查经", action: #selector(quit), keyEquivalent: "")
        menu.items.forEach { $0.target = self }
        menu.delegate = self
        statusItem.menu = menu
    }

    /// Dock icon click with no visible window: bring the search back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { SearchWindowController.shared.show(activate: true) }
        return true
    }

    // MARK: - Menu

    private func buildMainMenu() -> NSMenu {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于好查经", action: #selector(about), keyEquivalent: "").target = self
        appMenu.addItem(.separator())
        let chordItem = NSMenuItem(title: "", action: #selector(toggleChord), keyEquivalent: "")
        chordItem.target = self
        chordMenuItems.append(chordItem)
        appMenu.addItem(chordItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏好查经", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "隐藏其他", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "显示全部", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "关闭所有窗口（保留后台）", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(withTitle: "退出好查经", action: #selector(quit), keyEquivalent: "").target = self
        appMenu.delegate = self
        main.addItem(submenu(appMenu, title: "好查经"))

        let file = NSMenu(title: "文件")
        file.addItem(withTitle: "搜索经文", action: #selector(showSearch), keyEquivalent: "f").target = self
        file.addItem(withTitle: "在新窗口打开经文", action: #selector(duplicateWindow(_:)), keyEquivalent: "d").target = self
        file.addItem(.separator())
        file.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        main.addItem(submenu(file, title: "文件"))

        let edit = NSMenu(title: "编辑")
        edit.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(submenu(edit, title: "编辑"))

        let window = NSMenu(title: "窗口")
        window.addItem(withTitle: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(withTitle: "缩放", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        window.addItem(.separator())
        window.addItem(withTitle: "前置全部窗口", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        main.addItem(submenu(window, title: "窗口"))
        NSApp.windowsMenu = window

        return main
    }

    private func submenu(_ menu: NSMenu, title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    /// The item is named after what clicking it does, in each of its three states.
    private func updateChordMenu() {
        let title: String
        if chord?.isRunning ?? false {
            title = "停用 Space+P 快捷键"
        } else if SpaceChordMonitor.isTrusted {
            title = "启用 Space+P 快捷键"
        } else {
            title = "开启 Space+P 快捷键（需授权辅助功能）…"
        }
        chordMenuItems.forEach { $0.title = title }
    }

    /// Permission can change while the app runs, so re-read the state whenever a menu opens.
    func menuNeedsUpdate(_ menu: NSMenu) {
        updateChordMenu()
    }

    /// Poll until the user grants Accessibility, then start the tap by itself.
    private func waitForPermission() {
        guard permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            if self.chord?.start() ?? false {
                t.invalidate()
                self.permissionTimer = nil
                self.updateChordMenu()
            }
        }
    }

    // MARK: - Actions

    private func toggleSearch() {
        SearchWindowController.shared.toggle()
    }

    @objc private func showSearch() {
        SearchWindowController.shared.show()
    }

    /// ⌘D: duplicate the active reader window, or open the search selection in a new one.
    @objc private func duplicateWindow(_ sender: Any?) {
        if let reader = activeReader {
            reader.duplicateWindow(sender)
        } else if SearchWindowController.shared.isFrontmost {
            SearchWindowController.shared.duplicateWindow(sender)
        }
    }

    private var activeReader: ReaderWindowController? {
        (NSApp.keyWindow ?? NSApp.mainWindow)?.windowController as? ReaderWindowController
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(duplicateWindow(_:)) {
            return activeReader != nil
                || (SearchWindowController.shared.isFrontmost && SearchWindowController.shared.model.selected != nil)
        }
        return true
    }

    @objc private func toggleChord() {
        guard let chord else { return }
        if chord.isRunning {
            chord.stop()
        } else if !chord.start() {
            // No Accessibility permission yet: take the user straight to where it is granted.
            // The system prompt only ever appears once, so also open the pane itself, and
            // keep polling so the chord switches on the moment the box is ticked.
            SpaceChordMonitor.requestPermission()
            openAccessibilitySettings()
            waitForPermission()
        }
        updateChordMenu()
    }

    @objc private func quit() {
        reallyQuit = true
        NSApp.terminate(nil)
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func about() {
        AboutWindowController.shared.show()
    }
}
