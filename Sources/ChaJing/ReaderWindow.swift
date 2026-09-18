import AppKit
import Combine
import SwiftUI

final class ReaderModel: ObservableObject {
    @Published var passage: Passage
    /// Going back a chapter shows its end (the reader is moving upwards through the text);
    /// everything else starts at the top.
    private(set) var scroll: PreviewScroll = .top

    init(passage: Passage) { self.passage = passage }

    var book: Book? { BibleStore.shared.book(id: passage.bookID) }

    /// Show a different passage in this window, positioned at its verse.
    func show(_ newPassage: Passage) {
        scroll = .top
        passage = newPassage
    }

    func step(_ delta: Int) {
        guard let b = book else { return }
        let c = passage.chapter + delta
        guard c >= 1, c <= b.chapterCount else { return }
        scroll = delta < 0 ? .bottom : .top
        passage = Passage(bookID: b.id, chapter: c, verse: nil, verseEnd: nil)
    }
}

struct ReaderView: View {
    @ObservedObject var model: ReaderModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { model.step(-1) }) { Image(systemName: "chevron.left") }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    .disabled(model.passage.chapter <= 1)
                    .uiRegion("reader.prev")
                Spacer()
                Text(BibleStore.shared.reference(Passage(bookID: model.passage.bookID, chapter: model.passage.chapter, verse: nil, verseEnd: nil)))
                    .font(.system(size: 15, weight: .semibold))
                    .uiRegion("reader.title")
                Spacer()
                Button(action: { ReaderWindows.shared.open(model.passage, inNewWindow: true) }) {
                    Image(systemName: "plus.square.on.square")
                }
                .help("在新窗口打开同一处经文 (⌘D)")
                .uiRegion("reader.duplicate")
                Button(action: { model.step(1) }) { Image(systemName: "chevron.right") }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                    .disabled(model.passage.chapter >= (model.book?.chapterCount ?? 1))
                    .uiRegion("reader.next")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .uiRegion("reader.toolbar")
            Divider()
            PassageView(passage: model.passage, highlight: model.passage.verseRange, scroll: model.scroll)
                .uiRegion("reader.passage")
        }
        .frame(minWidth: 480, minHeight: 360)
    }
}

/// One reader window. Sits in the responder chain so ⌘D (duplicateWindow:) reaches it.
final class ReaderWindowController: NSWindowController, NSWindowDelegate {
    let model: ReaderModel
    private var titleSink: AnyCancellable?

    init(passage: Passage) {
        model = ReaderModel(passage: passage)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 720),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.contentView = NSHostingView(rootView: ReaderView(model: model))
        super.init(window: window)
        window.delegate = self
        titleSink = model.$passage.sink { [weak window] p in
            window?.title = BibleStore.shared.reference(p)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc func duplicateWindow(_ sender: Any?) {
        ReaderWindows.shared.open(model.passage, inNewWindow: true)
    }

    func windowWillClose(_ notification: Notification) {
        ReaderWindows.shared.remove(self)
    }
}

/// Registry of open reader windows. Any number can be open side by side.
final class ReaderWindows {
    static let shared = ReaderWindows()

    private(set) var controllers: [ReaderWindowController] = []
    private var lastSize: NSSize?

    /// The reader window nearest the front, if any.
    var frontmost: ReaderWindowController? {
        for w in NSApp.orderedWindows {
            if let c = w.windowController as? ReaderWindowController, w.isVisible { return c }
        }
        return nil
    }

    /// Show a passage: in the frontmost reader window, or in a fresh one when asked
    /// (or when none is open yet).
    func open(_ passage: Passage, inNewWindow: Bool) {
        if !inNewWindow, let c = frontmost {
            c.model.show(passage)
            c.showWindow(nil)
            c.window?.makeKeyAndOrderFront(nil)
        } else {
            let c = ReaderWindowController(passage: passage)
            place(c)
            controllers.append(c)
            c.showWindow(nil)
            c.window?.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    fileprivate func remove(_ c: ReaderWindowController) {
        if let size = c.window?.frame.size { lastSize = size }
        controllers.removeAll { $0 === c }
    }

    /// New windows keep the size of the last one and cascade from the frontmost.
    private func place(_ c: ReaderWindowController) {
        guard let w = c.window else { return }
        if let anchor = frontmost?.window {
            w.setFrame(NSRect(origin: w.frame.origin, size: anchor.frame.size), display: false)
            // cascadeTopLeft(from:) places the window AT the point and returns the next
            // cascade point, so step once more to land beside the anchor, not on top of it.
            let next = w.cascadeTopLeft(from: NSPoint(x: anchor.frame.minX, y: anchor.frame.maxY))
            w.cascadeTopLeft(from: next)
        } else {
            if let size = lastSize {
                w.setFrame(NSRect(origin: w.frame.origin, size: size), display: false)
            }
            w.center()
        }
    }
}
