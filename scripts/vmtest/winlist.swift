// Prints the on-screen windows of the current Space, front to back:
//   layer  owner  [x,y wxh]
// Needs no permission (window titles would). Used by fullscreen_overlay_test.sh to assert
// which windows are really visible: layer 0 = normal, 3 = floating, 24/25 = menu bar.
import CoreGraphics
import Foundation

let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
let list = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] ?? []
for w in list {
    let owner = w[kCGWindowOwnerName as String] as? String ?? "?"
    let layer = w[kCGWindowLayer as String] as? Int ?? -1
    let b = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
    func n(_ k: String) -> Int { Int((b[k] as? Double) ?? Double(b[k] as? Int ?? 0)) }
    print("\(layer)\t\(owner)\t[\(n("X")),\(n("Y")) \(n("Width"))x\(n("Height"))]")
}
