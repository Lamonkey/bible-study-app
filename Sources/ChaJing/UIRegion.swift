import SwiftUI

/// Names a part of the UI. At runtime this only publishes a preference value that nothing
/// reads; the offscreen snapshot test (`make ui-shots`) collects the frames and writes them
/// to docs/ui/shots/manifest.json, so the UI documents can outline and label each part on
/// the real screenshots.
struct UIRegionKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    func uiRegion(_ id: String) -> some View {
        // transform (not set), so a region can contain other regions without hiding them
        transformAnchorPreference(key: UIRegionKey.self, value: .bounds) { $0[id] = $1 }
    }
}
