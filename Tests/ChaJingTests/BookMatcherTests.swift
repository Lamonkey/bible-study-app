import XCTest
@testable import ChaJing

final class BookMatcherTests: XCTestCase {
    /// Small synthetic library so the tests do not depend on the bundled text.
    static func book(_ id: Int, _ name: String, _ abbr: String, _ pinyin: String, aliases: [String] = [], chapters: [Int]) -> Book {
        Book(id: id, name: name, abbr: abbr, aliases: aliases, pinyin: pinyin.components(separatedBy: " "),
             chapters: chapters.map { n in (1...n).map { "\(name) v\($0)" } })
    }

    let books: [Book] = [
        book(6, "约书亚记", "书", "yue shu ya ji", chapters: Array(repeating: 24, count: 24)),
        book(36, "西番雅书", "番", "xi fan ya shu", chapters: [18, 15, 20]),
        book(40, "马太福音", "太", "ma tai fu yin", chapters: Array(repeating: 30, count: 28)),
        book(43, "约翰福音", "约", "yue han fu yin", chapters: Array(repeating: 54, count: 21)),
        book(62, "约翰一书", "约一", "yue han yi shu", aliases: ["约翰壹书", "约壹"], chapters: [10, 29, 24, 21, 21]),
        book(63, "约翰二书", "约二", "yue han er shu", chapters: [13]),
    ]

    func names(_ q: String) -> [String] {
        SearchEngine(books: books).search(q).map(\.title)
    }

    func testInitials() {
        XCTAssertEqual(names("yhfy"), ["约翰福音"])
        XCTAssertEqual(names("mt"), ["马太福音"])
        XCTAssertEqual(names("yh"), ["约翰福音", "约翰一书", "约翰二书"])
    }

    func testFullAndMixedPinyin() {
        XCTAssertEqual(names("yuehan"), ["约翰福音", "约翰一书", "约翰二书"])
        XCTAssertEqual(names("yuehanfuyin"), ["约翰福音"])
        XCTAssertEqual(names("yuehfy"), ["约翰福音"])
        XCTAssertEqual(names("yueshu"), ["约书亚记"])
    }

    func testWildcards() {
        XCTAssertEqual(names("y*fy"), ["约翰福音"])
        XCTAssertEqual(names("*fy"), ["西番雅书", "马太福音", "约翰福音"])
        XCTAssertEqual(names("?han"), ["约翰福音", "约翰一书", "约翰二书"])
        XCTAssertEqual(names("*"), ["约书亚记", "西番雅书", "马太福音", "约翰福音", "约翰一书", "约翰二书"])
    }

    func testNoFuzzyMatching() {
        XCTAssertEqual(names("yhfyx"), [])
        XCTAssertEqual(names("yfhy"), [])   // wrong order never matches
        XCTAssertEqual(names("zzz"), [])
        XCTAssertEqual(names("约翰福因"), [])
    }

    func testChineseMatching() {
        XCTAssertEqual(names("约翰福音"), ["约翰福音"])
        XCTAssertEqual(names("约"), ["约翰福音", "约书亚记", "约翰一书", "约翰二书"])  // abbreviation ranks first
        XCTAssertEqual(names("福音"), ["马太福音", "约翰福音"])
        XCTAssertEqual(names("约翰壹书"), ["约翰一书"])
        XCTAssertEqual(names("约壹"), ["约翰一书"])
    }

    func testChapterAndVerseFilterCandidates() {
        XCTAssertEqual(names("yhfy 4:24"), ["约翰福音 4:24"])
        XCTAssertEqual(names("yhfy 4 24"), ["约翰福音 4:24"])
        XCTAssertEqual(names("yh 4:24"), ["约翰福音 4:24"])          // 约翰一书 4 has only 21 verses
        XCTAssertEqual(names("yh 4:21"), ["约翰福音 4:21", "约翰一书 4:21"])
        XCTAssertEqual(names("yh 2"), ["约翰福音 2", "约翰一书 2"])   // 约翰二书 has one chapter
        XCTAssertEqual(names("yhfy 99"), [])
        XCTAssertEqual(names("yhfy 4:999"), [])
        XCTAssertEqual(names("yhfy 4:24:"), [])
    }

    func testVerseRangeIsClampedToChapter() {
        let r = SearchEngine(books: books).search("yhfy 4:50-99").first
        XCTAssertEqual(r?.verseEnd, 54)
        XCTAssertEqual(r?.title, "约翰福音 4:50-54")
    }
}
