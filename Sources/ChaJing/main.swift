import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Regular app: Dock icon, main menu, windows. The hotkeys are live while it runs.
app.setActivationPolicy(.regular)
app.run()
