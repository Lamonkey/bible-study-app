import AppKit
import SwiftUI

final class ReaderModel: ObservableObject {
    @Published var passage = Passage(bookID: 43, chapter: 1, verse: nil, verseEnd: nil)

    var book: Book? { BibleStore.shared.book(id: passage.bookID) }

    func step(_ delta: Int) {
        guard let b = book else { return }
        let c = passage.chapter + delta
        guard c >= 1, c <= b.chapterCount else { return }
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
                Spacer()
                Text(BibleStore.shared.reference(Passage(bookID: model.passage.bookID, chapter: model.passage.chapter, verse: nil, verseEnd: nil)))
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button(action: { model.step(1) }) { Image(systemName: "chevron.right") }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                    .disabled(model.passage.chapter >= (model.book?.chapterCount ?? 1))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            Divider()
            PassageView(passage: model.passage, highlight: model.passage.verseRange)
        }
        .frame(minWidth: 480, minHeight: 360)
    }
}

final class ReaderWindowController {
    static let shared = ReaderWindowController()

    let model = ReaderModel()
    private var window: NSWindow?

    func show(passage: Passage) {
        model.passage = passage
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 720),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            w.title = "查经"
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: ReaderView(model: model))
            w.center()
            w.setFrameAutosaveName("ChaJingReader")
            window = w
        }
        window?.title = BibleStore.shared.reference(passage)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
