import AppKit
import Combine
import Foundation

/// State behind the floating search bar.
final class SearchViewModel: ObservableObject {
    @Published var query: String = "" {
        didSet {
            // Typing scrolls the preview to the verse; rewrites made by the app say how.
            previewScroll = pendingScroll ?? .top
            pendingScroll = nil
            refresh()
        }
    }
    /// How the preview should position itself for the current query.
    @Published private(set) var previewScroll: PreviewScroll = .top
    private var pendingScroll: PreviewScroll?
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

    // MARK: - Moving around from the preview

    /// ← / →: previous / next chapter of the selected book. Going back lands on the LAST
    /// verse, shown at the bottom, because someone paging backwards is reading upwards;
    /// going forward lands on verse 1 at the top. The query is rewritten to match, with the
    /// full book name so that an ambiguous input such as "yh" cannot change books.
    func stepChapter(_ delta: Int) {
        guard let r = selected, canStepChapter(delta) else { return }
        let chapter = (r.chapter ?? 1) + delta
        let verse = delta < 0 ? r.book.verseCount(chapter: chapter) : 1
        pendingScroll = delta < 0 ? .bottom : .top
        query = "\(r.book.name) \(chapter):\(verse)"
    }

    func canStepChapter(_ delta: Int) -> Bool {
        guard let r = selected else { return false }
        let chapter = (r.chapter ?? 1) + delta
        return chapter >= 1 && chapter <= r.book.chapterCount
    }

    /// Verses picked with the mouse in the preview: the highlight and the query follow,
    /// and the preview stays where it is instead of jumping to the first picked verse.
    func selectVerses(_ range: ClosedRange<Int>) {
        guard let r = selected else { return }
        let chapter = r.chapter ?? 1
        let count = r.book.verseCount(chapter: chapter)
        guard count > 0 else { return }
        let lo = min(max(range.lowerBound, 1), count), hi = min(max(range.upperBound, lo), count)
        let text = "\(r.book.name) \(chapter):\(lo)" + (hi > lo ? "-\(hi)" : "")
        guard text != query else { return }
        pendingScroll = .stay
        query = text
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
