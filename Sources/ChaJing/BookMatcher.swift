import Foundation

/// How strongly a book matched the name part of the query. Lower sorts first.
enum MatchRank: Int, Comparable {
    case exact = 0      // "yhfy", "yuehanfuyin", "约", "约翰福音"
    case prefix = 1     // "yh", "yueh", "约翰"
    case partial = 2    // "yuehfy", "福音"
    case all = 3        // empty name: every book

    static func < (lhs: MatchRank, rhs: MatchRank) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct BookMatch {
    let book: Book
    let rank: MatchRank
}

/// Deterministic book-name matching. No fuzzy / edit-distance matching by design:
/// a query either matches under the rules below or it does not.
///
/// * Chinese name: exact abbreviation, or exact substring of the book name / alias.
/// * Latin name: pinyin matched syllable by syllable. Each chunk of the query must be
///   a prefix of the corresponding syllable, so "yhfy", "yuehan" and "yuehfy" all hit
///   约翰福音. `*` matches any number of whole syllables, `?` exactly one syllable.
///   A query may stop early (prefix of the book) but never skips or reorders syllables.
enum BookMatcher {
    static func match(name rawName: String, in books: [Book]) -> [BookMatch] {
        let name = rawName.trimmingCharacters(in: .whitespaces).lowercased()
        if name.isEmpty {
            return books.map { BookMatch(book: $0, rank: .all) }
        }
        var hits: [BookMatch] = []
        if containsCJK(name) {
            for b in books {
                let names = [b.name] + b.aliases
                if name == b.abbr || names.contains(name) {
                    hits.append(BookMatch(book: b, rank: .exact))
                } else if names.contains(where: { $0.hasPrefix(name) }) {
                    hits.append(BookMatch(book: b, rank: .prefix))
                } else if names.contains(where: { $0.contains(name) }) {
                    hits.append(BookMatch(book: b, rank: .partial))
                }
            }
        } else {
            guard name.allSatisfy({ ($0 >= "a" && $0 <= "z") || $0 == "*" || $0 == "?" }) else {
                return []
            }
            let q = Array(name)
            for b in books {
                let syls = b.pinyin.map { Array($0) }
                guard pinyinMatch(q, 0, syls, 0) else { continue }
                if name == b.initials || name == b.fullPinyin {
                    hits.append(BookMatch(book: b, rank: .exact))
                } else if b.initials.hasPrefix(name) || b.fullPinyin.hasPrefix(name) {
                    hits.append(BookMatch(book: b, rank: .prefix))
                } else {
                    hits.append(BookMatch(book: b, rank: .partial))
                }
            }
        }
        return hits.sorted { a, b in
            a.rank != b.rank ? a.rank < b.rank : a.book.id < b.book.id
        }
    }

    static func containsCJK(_ s: String) -> Bool {
        s.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF }
    }

    /// Recursive syllable matcher; see type doc for the rules.
    static func pinyinMatch(_ q: [Character], _ qi: Int, _ syls: [[Character]], _ si: Int) -> Bool {
        if qi == q.count { return true }
        let c = q[qi]
        if c == "*" {
            var s2 = si
            while s2 <= syls.count {
                if pinyinMatch(q, qi + 1, syls, s2) { return true }
                s2 += 1
            }
            return false
        }
        if si == syls.count { return false }
        if c == "?" {
            return pinyinMatch(q, qi + 1, syls, si + 1)
        }
        let syl = syls[si]
        var k = 1
        while k <= syl.count, qi + k <= q.count, q[qi + k - 1] == syl[k - 1] {
            if pinyinMatch(q, qi + k, syls, si + 1) { return true }
            k += 1
        }
        return false
    }
}
