import XCTest
@testable import ChaJing

@MainActor
final class SearchWindowTests: XCTestCase {
    /// esc backs out one step at a time: clear the input first, hide only when it is empty.
    func testEscapeClearsTheQueryBeforeHiding() {
        let search = SearchWindowController.shared
        search.model.query = "约翰福音 1"
        XCTAssertFalse(search.model.results.isEmpty)

        search.escape()
        XCTAssertEqual(search.model.query, "")
        XCTAssertTrue(search.model.results.isEmpty)

        search.escape()                       // second press: hides, nothing left to clear
        XCTAssertEqual(search.model.query, "")
        XCTAssertFalse(search.window?.isVisible ?? true)
    }

    /// A plain hide (the ⌥Space toggle) keeps the query; finishing a task clears it.
    func testPlainHideKeepsTheQueryAndFinishingClearsIt() {
        let search = SearchWindowController.shared
        search.model.query = "lq 13"
        search.hide()
        XCTAssertEqual(search.model.query, "lq 13")
        search.hide(clearQuery: true)
        XCTAssertEqual(search.model.query, "")
    }
}
