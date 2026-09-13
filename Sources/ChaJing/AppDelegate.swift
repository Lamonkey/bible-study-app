import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotkey: GlobalHotkey?
    private var chord: SpaceChordMonitor?
    private var chordMenuItem: NSMenuItem!
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = BibleStore.shared // load text up front so the first search is instant

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "book.closed", accessibilityDescription: "查经")
        statusItem.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.addItem(withTitle: "打开查经搜索  (⌥Space / Space+P)", action: #selector(openSearch), keyEquivalent: "")
        menu.addItem(.separator())
        chordMenuItem = NSMenuItem(title: "", action: #selector(toggleChord), keyEquivalent: "")
        menu.addItem(chordMenuItem)
        menu.addItem(withTitle: "打开「辅助功能」设置…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "关于查经", action: #selector(about), keyEquivalent: "")
        menu.addItem(withTitle: "退出", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu

        // Always-available fallback: Option + Space.
        hotkey = GlobalHotkey { [weak self] in self?.openSearch() }
        hotkey?.register()

        // Requested chord: hold Space, press P.
        chord = SpaceChordMonitor { [weak self] in self?.openSearch() }
        if !(chord?.start() ?? false) {
            SpaceChordMonitor.requestPermission()
            // Poll until the user grants Accessibility, then start the tap.
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] t in
                guard let self else { t.invalidate(); return }
                if self.chord?.start() ?? false {
                    t.invalidate()
                    self.permissionTimer = nil
                    self.updateChordMenu()
                }
            }
        }
        updateChordMenu()
    }

    private func updateChordMenu() {
        if chord?.isRunning ?? false {
            chordMenuItem.title = "Space+P 快捷键：已启用（点击停用）"
        } else if SpaceChordMonitor.isTrusted {
            chordMenuItem.title = "Space+P 快捷键：已停用（点击启用）"
        } else {
            chordMenuItem.title = "Space+P 快捷键：需要辅助功能权限"
        }
    }

    @objc private func openSearch() {
        SearchPanelController.shared.toggle()
    }

    @objc private func toggleChord() {
        guard let chord else { return }
        if chord.isRunning {
            chord.stop()
        } else if !chord.start() {
            SpaceChordMonitor.requestPermission()
        }
        updateChordMenu()
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func about() {
        let alert = NSAlert()
        alert.messageText = "查经 ChaJing"
        alert.informativeText = "简体和合本经文快速检索。\n\n快捷键：⌥Space，或按住 Space 再按 P。\n输入示例：yhfy 4:24 · yuehan 3 16 · 约 4:24 · 林前 13:4-8\n\n经文来源：\(BibleStore.shared.data.source)"
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
