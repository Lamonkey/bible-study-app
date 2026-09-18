import Foundation

/// Loads and holds the bundled 简体和合本 text.
final class BibleStore {
    static let shared = BibleStore()

    let data: BibleData
    let books: [Book]
    private let byID: [Int: Book]

    /// SwiftPM's generated `Bundle.module` only looks beside the executable's bundle root
    /// and at the absolute build directory of the machine that compiled it, and traps if
    /// neither exists. A packaged .app keeps resources in Contents/Resources, so look
    /// there first; fall back to `Bundle.module` for `swift run` and `swift test`.
    private static var resources: Bundle {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("ChaJing_ChaJing.bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        return Bundle.module
    }

    private init() {
        guard let url = Self.resources.url(forResource: "cus", withExtension: "json") else {
            fatalError("cus.json missing from bundle; run `python3 scripts/build_data.py`")
        }
        do {
            let raw = try Data(contentsOf: url)
            data = try JSONDecoder().decode(BibleData.self, from: raw)
        } catch {
            fatalError("failed to load cus.json: \(error)")
        }
        books = data.books
        byID = Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0) })
    }

    func book(id: Int) -> Book? { byID[id] }

    func reference(_ p: Passage) -> String {
        guard let b = book(id: p.bookID) else { return "" }
        var s = "\(b.name) \(p.chapter)"
        if let r = p.verseRange {
            s += ":\(r.lowerBound)"
            if r.count > 1 { s += "-\(r.upperBound)" }
        }
        return s
    }

    /// Verse text for a passage (whole chapter when no verse given), one verse per line.
    func text(for p: Passage, numbered: Bool = true) -> String {
        guard let b = book(id: p.bookID) else { return "" }
        let verses = b.verses(chapter: p.chapter)
        let range = p.verseRange.map { $0.clamped(to: 1...max(1, verses.count)) } ?? 1...max(1, verses.count)
        guard !verses.isEmpty else { return "" }
        return range.map { n in numbered ? "\(n) \(verses[n - 1])" : verses[n - 1] }.joined(separator: "\n")
    }
}
