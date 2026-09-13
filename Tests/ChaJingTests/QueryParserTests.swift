import XCTest
@testable import ChaJing

final class QueryParserTests: XCTestCase {
    func testNameOnly() {
        XCTAssertEqual(QueryParser.parse("yhfy"), ParsedQuery(name: "yhfy", chapter: nil, verse: nil, verseEnd: nil))
        XCTAssertEqual(QueryParser.parse("约翰一书"), ParsedQuery(name: "约翰一书", chapter: nil, verse: nil, verseEnd: nil))
    }

    func testChapterVerseForms() {
        let expected = ParsedQuery(name: "yhfy", chapter: 4, verse: 24, verseEnd: nil)
        for q in ["yhfy 4:24", "yhfy 4 24", "yhfy4:24", "yhfy 4：24", "yhfy 4.24", "YHFY 4,24"] {
            XCTAssertEqual(QueryParser.parse(q), expected, q)
        }
        XCTAssertEqual(QueryParser.parse("yhfy 4"), ParsedQuery(name: "yhfy", chapter: 4, verse: nil, verseEnd: nil))
        XCTAssertEqual(QueryParser.parse("林前 13:4-8"), ParsedQuery(name: "林前", chapter: 13, verse: 4, verseEnd: 8))
        XCTAssertEqual(QueryParser.parse("约一 4 7~8"), ParsedQuery(name: "约一", chapter: 4, verse: 7, verseEnd: 8))
    }

    func testMalformedNumbersReturnNil() {
        XCTAssertNil(QueryParser.parse("yhfy 4:24:"))
        XCTAssertNil(QueryParser.parse("yhfy 4:24:1"))
        XCTAssertNil(QueryParser.parse("yhfy 4 24 26 1"))
    }
}
