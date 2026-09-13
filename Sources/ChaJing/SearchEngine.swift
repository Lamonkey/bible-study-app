import Foundation

/// One row in the search panel.
struct SearchResult: Identifiable, Hashable {
    let book: Book
    let rank: MatchRank
    /// nil when the query named only a book.
    let chapter: Int?
    let verse: Int?
    let verseEnd: Int?

    var id: String { "\(book.id)-\(chapter ?? 0)-\(verse ?? 0)-\(verseEnd ?? 0)" }

    /// Passage to display / open. Book-only results open chapter 1.
    var passage: Passage {
        Passage(bookID: book.id, chapter: chapter ?? 1, verse: verse, verseEnd: verseEnd)
    }

    var title: String {
        guard let c = chapter else { return book.name }
        var s = "\(book.name) \(c)"
        if let v = verse {
            s += ":\(v)"
            if let e = verseEnd, e > v { s += "-\(e)" }
        }
        return s
    }

    var subtitle: String {
        guard let c = chapter else { return "\(book.abbr) · \(book.chapterCount) 章" }
        let verses = book.verses(chapter: c)
        if let v = verse, v >= 1, v <= verses.count {
            return verses[v - 1]
        }
        return "\(verses.count) 节 · " + (verses.first ?? "")
    }

    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct SearchEngine {
    let books: [Book]

    init(books: [Book] = BibleStore.shared.books) {
        self.books = books
    }

    func search(_ query: String) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let parsed = QueryParser.parse(trimmed) else { return [] }
        var results: [SearchResult] = []
        for m in BookMatcher.match(name: parsed.name, in: books) {
            let b = m.book
            if let c = parsed.chapter {
                // A chapter / verse the book does not have disqualifies it.
                guard c >= 1, c <= b.chapterCount else { continue }
                if let v = parsed.verse {
                    guard v >= 1, v <= b.verseCount(chapter: c) else { continue }
                }
                let end = parsed.verseEnd.map { min($0, b.verseCount(chapter: c)) }
                results.append(SearchResult(book: b, rank: m.rank, chapter: c, verse: parsed.verse, verseEnd: end))
            } else {
                results.append(SearchResult(book: b, rank: m.rank, chapter: nil, verse: nil, verseEnd: nil))
            }
        }
        return results
    }
}
