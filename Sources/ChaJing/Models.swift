import Foundation

/// One of the 66 books, with its text and the metadata used for matching.
struct Book: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let abbr: String
    let aliases: [String]
    /// Pinyin syllables, e.g. ["yue", "han", "fu", "yin"].
    let pinyin: [String]
    /// chapters[c - 1][v - 1] is the text of verse c:v.
    let chapters: [[String]]

    var chapterCount: Int { chapters.count }

    func verseCount(chapter: Int) -> Int {
        guard chapter >= 1, chapter <= chapters.count else { return 0 }
        return chapters[chapter - 1].count
    }

    func verses(chapter: Int) -> [String] {
        guard chapter >= 1, chapter <= chapters.count else { return [] }
        return chapters[chapter - 1]
    }

    /// "yhfy" for 约翰福音.
    var initials: String { pinyin.map { String($0.prefix(1)) }.joined() }
    /// "yuehanfuyin" for 约翰福音.
    var fullPinyin: String { pinyin.joined() }

    /// Pinyin syllables of `abbr`, derived by locating each abbreviation character in
    /// `name`: ["lin", "qian"] for 林前 (哥林多前书). Empty if the abbreviation is not an
    /// in-order subsequence of the name.
    var abbrPinyin: [String] {
        guard pinyin.count == name.count else { return [] }
        let chars = Array(name)
        var out: [String] = []
        var pos = 0
        for c in abbr {
            guard let i = chars[pos...].firstIndex(of: c) else { return [] }
            out.append(pinyin[i])
            pos = i + 1
        }
        return out
    }
    /// "lq" for 林前.
    var abbrInitials: String { abbrPinyin.map { String($0.prefix(1)) }.joined() }
    /// "linqian" for 林前.
    var abbrFullPinyin: String { abbrPinyin.joined() }

    static func == (lhs: Book, rhs: Book) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct BibleData: Codable {
    let version: String
    let source: String
    let books: [Book]
}

/// A reference like 约翰福音 4:24-26. `verse == nil` means the whole chapter.
struct Passage: Hashable {
    var bookID: Int
    var chapter: Int
    var verse: Int?
    var verseEnd: Int?

    var verseRange: ClosedRange<Int>? {
        guard let v = verse else { return nil }
        return v...max(v, verseEnd ?? v)
    }
}
