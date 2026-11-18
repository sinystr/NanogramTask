import XCTest

final class FeedUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - First load

    @MainActor
    func testShowsLoadingThenTheFirstGame() {
        // Long enough that the loading screen is still up when `launch()` returns.
        let app = XCUIApplication.feed(["-mockDelayMs", "5000"])
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["feedLoading"].waitForExistence(timeout: 3))
        waitUntilCurrent(0, in: app)
        waitUntilReady(0, in: app)
        XCTAssertFalse(app.descendants(matching: .any)["feedLoading"].exists)
    }

    @MainActor
    func testInitialErrorRetryShowsTheFeed() {
        let app = XCUIApplication.feed(["-mockFailInitialLoad"])
        app.launch()

        let retry = app.buttons["feedError.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["feedError.message"].exists)

        retry.tap()

        waitUntilCurrent(0, in: app)
        XCTAssertFalse(retry.exists)
    }

    // MARK: - Swiping

    @MainActor
    func testSwipingMovesOnePositionAtATime() {
        let app = XCUIApplication.feed()
        app.launch()
        waitUntilCurrent(0, in: app)

        app.swipeUp()
        waitUntilCurrent(1, in: app)
        app.swipeUp()
        waitUntilCurrent(2, in: app)
        app.swipeDown()
        waitUntilCurrent(1, in: app)
    }

    @MainActor
    func testSwipingPastTheLastGameStartsOverFromTheFirst() {
        // One API page of 10 games, so the feed ends right away and loops.
        let app = XCUIApplication.feed(["-mockTotalPages", "1"])
        app.launch()
        waitUntilCurrent(0, in: app)

        for index in 1...11 {
            app.swipeUp()
            waitUntilCurrent(index, in: app)
        }
        waitUntilReady(11, in: app)
    }

    // MARK: - Play mode

    @MainActor
    func testPlayModeLocksTheFeedAndCloseReturnsToTheSamePosition() {
        let app = XCUIApplication.feed()
        app.launch()
        app.swipeUp()
        waitUntilCurrent(1, in: app)
        waitUntilReady(1, in: app)

        app.position(1).tap()
        XCTAssertTrue(app.closeGameButton.waitForExistence(timeout: 5))

        // The game gets the swipes; the feed must not move.
        app.swipeUp()
        app.swipeUp()
        app.swipeDown()
        XCTAssertTrue(app.closeGameButton.exists)

        app.closeGameButton.tap()
        waitUntil("close button hides") { !app.closeGameButton.exists }
        waitUntilCurrent(1, in: app)
        waitUntilReady(1, in: app)

        // Scrolling works again after closing.
        app.swipeUp()
        waitUntilCurrent(2, in: app)
    }
}
