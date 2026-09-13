import Foundation

/// Result of splitting "yhfy 4:24-26" into a name part and a numeric part.
struct ParsedQuery: Equatable {
    var name: String
    var chapter: Int?
    var verse: Int?
    var verseEnd: Int?
}

enum QueryParser {
    // "4", "4:24", "4 24", "4.24", "4：24", "4:24-26", "4:24~26", "4:24至26"
    private static let numberRegex = try! NSRegularExpression(
        pattern: #"^\s*([0-9]+)(?:\s*[:：.,，、\s]\s*([0-9]+)(?:\s*[-~—至到]\s*([0-9]+))?)?\s*$"#
    )

    /// Returns nil when the numeric tail is malformed (e.g. "4:24:").
    static func parse(_ raw: String) -> ParsedQuery? {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Name = leading run of non-digit characters.
        // Only ASCII digits split the name: Character.isNumber is also true for 一/二/三,
        // which appear in book names such as 约翰一书.
        let nameEnd = q.firstIndex(where: { $0.isASCII && $0.isNumber }) ?? q.endIndex
        let name = q[q.startIndex..<nameEnd].trimmingCharacters(in: .whitespaces).lowercased()
        let rest = String(q[nameEnd...])
        if rest.trimmingCharacters(in: .whitespaces).isEmpty {
            return ParsedQuery(name: name, chapter: nil, verse: nil, verseEnd: nil)
        }
        let ns = rest as NSString
        guard let m = numberRegex.firstMatch(in: rest, range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        func group(_ i: Int) -> Int? {
            let r = m.range(at: i)
            guard r.location != NSNotFound else { return nil }
            return Int(ns.substring(with: r))
        }
        return ParsedQuery(name: name, chapter: group(1), verse: group(2), verseEnd: group(3))
    }
}
