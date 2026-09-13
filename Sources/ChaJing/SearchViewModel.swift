import AppKit
import Combine
import Foundation

/// State behind the floating search bar.
final class SearchViewModel: ObservableObject {
    @Published var query: String = "" {
        didSet { refresh() }
    }
    @Published private(set) var results: [SearchResult] = []
    @Published var selectedIndex: Int = 0
    /// Bumped every time the panel is shown so the view re-focuses the text field.
    @Published var focusToken: Int = 0

    private let engine = SearchEngine()

    var selected: SearchResult? {
        guard results.indices.contains(selectedIndex) else { return nil }
        return results[selectedIndex]
    }

    private func refresh() {
        results = engine.search(query)
        selectedIndex = 0
    }

    func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), results.count - 1)
    }

    /// Enter: open the reader window at the selected passage.
    func openSelected() {
        guard let r = selected else { return }
        ReaderWindowController.shared.show(passage: r.passage)
        SearchPanelController.shared.hide()
    }

    /// ⌘Enter: copy the selected verse(s) (or whole chapter) with its reference.
    func copySelected() {
        guard let r = selected else { return }
        let store = BibleStore.shared
        let text = store.text(for: r.passage, numbered: r.verse == nil)
        let payload = "\(text)\n—— \(store.reference(r.passage)) (和合本)"
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(payload, forType: .string)
        SearchPanelController.shared.hide()
    }
}
