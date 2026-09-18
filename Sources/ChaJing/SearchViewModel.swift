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

    /// Enter: show the selected passage in the frontmost reader window.
    /// ⇧Enter / ⌘D: open it in a new reader window so several passages can be read side by side.
    func openSelected(inNewWindow: Bool = false) {
        guard let r = selected else { return }
        ReaderWindows.shared.open(r.passage, inNewWindow: inNewWindow)
        SearchWindowController.shared.hide(clearQuery: true)
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
        // Keep the query, selection and scroll position: copying is usually one step of
        // several (copy a verse, paste it, come back for the next one).
        SearchWindowController.shared.hide()
    }
}
