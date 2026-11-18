import XCTest

/// Long session: memory and scrolling must stay steady however far the user goes.
///
/// `XCTMemoryMetric` measures the app process only; the WebContent processes, where the games
/// run, are measured separately (see "Performance" in Architecture.md).
final class FeedLongSessionTests: XCTestCase {
    private let swipeCount = 500

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The mock feed: small static games and a fast local network. Shows that the app's own
    /// machinery (view recycling, memory window, page downloads) doesn't grow.
    @MainActor
    func testFiveHundredSwipesKeepMemoryAndScrollingSteady() {
        let app = XCUIApplication.feed(["-mockDelayMs", "50"])
        swipeFiveHundredTimesMeasuring(app)
    }

    /// The real API with real games: real scripts, canvases and audio, and real network timing.
    /// Needs a network connection.
    @MainActor
    func testFiveHundredSwipesOnTheRealFeedKeepMemoryAndScrollingSteady() {
        let app = XCUIApplication.realFeed()
        swipeFiveHundredTimesMeasuring(app)
    }

    // MARK: - Helpers

    /// Launches the app, swipes up fast `swipeCount` times while measuring memory and scrolling,
    /// and checks the app is still running far down the feed.
    @MainActor
    private func swipeFiveHundredTimesMeasuring(_ app: XCUIApplication) {
        app.launch()
        waitUntilCurrent(0, in: app)

        let options = XCTMeasureOptions()
        // One pass is already 500 swipes; the default 5 passes would take far too long.
        options.iterationCount = 1

        measure(
            metrics: [XCTMemoryMetric(application: app), XCTOSSignpostMetric.scrollingAndDecelerationMetric],
            options: options
        ) {
            for _ in 0..<swipeCount {
                app.swipeUp(velocity: .fast)
            }
        }

        XCTAssertEqual(app.state, .runningForeground)

        let positionOnScreen = currentPosition(in: app)
        XCTAssertGreaterThan(positionOnScreen, swipeCount / 2, "Swipes should have moved far down the feed")
    }

    /// The position that fills the screen, or 0 if none is found.
    @MainActor
    private func currentPosition(in app: XCUIApplication) -> Int {
        let positionPrefix = "feed.position."
        let positions = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", positionPrefix))
            .allElementsBoundByIndex

        for position in positions {
            let isOnScreen = abs(position.frame.minY - app.frame.minY) < 1
            guard isOnScreen else {
                continue
            }

            let number = position.identifier.replacingOccurrences(of: positionPrefix, with: "")
            if let index = Int(number) {
                return index
            }
        }

        return 0
    }
}
