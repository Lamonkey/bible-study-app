import XCTest
@testable import ChaJing

/// Sanity checks on the shipped cus.json.
final class BundledDataTests: XCTestCase {
    func testAllBooksPresent() {
        let books = BibleStore.shared.books
        XCTAssertEqual(books.count, 66)
        XCTAssertEqual(books.first?.name, "创世记")
        XCTAssertEqual(books.last?.name, "启示录")
        XCTAssertEqual(books.map(\.id), Array(1...66))
        XCTAssertTrue(books.allSatisfy { !$0.chapters.isEmpty && $0.chapters.allSatisfy { !$0.isEmpty } })
    }

    func testJohn4_24() {
        let r = SearchEngine().search("yhfy 4:24")
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.title, "约翰福音 4:24")
        XCTAssertTrue(r.first?.subtitle.contains("神是个灵") ?? false)
    }

    func testPsalm23Text() {
        let text = BibleStore.shared.text(for: Passage(bookID: 19, chapter: 23, verse: 1, verseEnd: 1), numbered: false)
        XCTAssertTrue(text.contains("耶和华是我的牧者"))
    }
}
