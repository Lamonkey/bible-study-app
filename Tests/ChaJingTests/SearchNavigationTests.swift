import XCTest
@testable import ChaJing

/// ← / → chapter paging and mouse verse picking in the search preview (real bundled text).
final class SearchNavigationTests: XCTestCase {
    func testPreviousChapterLandsOnItsLastVerseAtTheBottom() {
        let model = SearchViewModel()
        model.query = "约翰福音 2:3"
        model.stepChapter(-1)
        XCTAssertEqual(model.query, "约翰福音 1:51")          // John 1 has 51 verses
        XCTAssertEqual(model.selected?.title, "约翰福音 1:51")
        XCTAssertEqual(model.previewScroll, .bottom)
    }

    func testNextChapterLandsOnVerseOneAtTheTop() {
        let model = SearchViewModel()
        model.query = "约翰福音 2:3"
        model.stepChapter(1)
        XCTAssertEqual(model.query, "约翰福音 3:1")
        XCTAssertEqual(model.previewScroll, .top)
    }

    func testSteppingStopsAtTheEndsOfTheBook() {
        let model = SearchViewModel()
        model.query = "yhfy 1:1"
        XCTAssertFalse(model.canStepChapter(-1))
        model.stepChapter(-1)
        XCTAssertEqual(model.query, "yhfy 1:1")               // untouched
        model.query = "yhfy 21"
        XCTAssertFalse(model.canStepChapter(1))
        XCTAssertTrue(model.canStepChapter(-1))
    }

    func testSteppingAnAmbiguousQueryStaysInTheSelectedBook() {
        let model = SearchViewModel()
        model.query = "yh 3:16"                                // 约翰福音 and 约翰一书
        model.selectedIndex = 1
        XCTAssertEqual(model.selected?.book.name, "约翰一书")
        model.stepChapter(1)
        XCTAssertEqual(model.query, "约翰一书 4:1")
        XCTAssertEqual(model.results.map(\.book.name), ["约翰一书"])
    }

    func testBookOnlyQueryStepsFromChapterOne() {
        let model = SearchViewModel()
        model.query = "约翰福音"
        model.stepChapter(1)
        XCTAssertEqual(model.query, "约翰福音 2:1")
    }

    func testPickingVersesRewritesTheQueryAndKeepsTheScrollPosition() {
        let model = SearchViewModel()
        model.query = "yhfy 1:1"
        model.selectVerses(1...2)
        XCTAssertEqual(model.query, "约翰福音 1:1-2")
        XCTAssertEqual(model.selected?.passage.verseRange, 1...2)
        XCTAssertEqual(model.previewScroll, .stay)
        model.selectVerses(5...5)
        XCTAssertEqual(model.query, "约翰福音 1:5")
        model.selectVerses(40...99)                            // clamped to the chapter
        XCTAssertEqual(model.query, "约翰福音 1:40-51")
    }

    func testTypingAfterANavigationScrollsToTheTopAgain() {
        let model = SearchViewModel()
        model.query = "约翰福音 2:3"
        model.stepChapter(-1)
        model.query = "约翰福音 1:5"
        XCTAssertEqual(model.previewScroll, .top)
    }
}
