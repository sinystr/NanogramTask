import XCTest

extension XCTestCase {
    /// Waits for a condition on the UI, re-evaluated as the app updates.
    @MainActor
    func waitUntil(
        _ description: String,
        timeout: TimeInterval = 20,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @escaping @MainActor () -> Bool
    ) {
        let predicate = NSPredicate { _, _ in MainActor.assumeIsolated { condition() } }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        expectation.expectationDescription = description
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "Timed out waiting for: \(description)", file: file, line: line)
    }

    /// Waits until the position fills the screen, i.e. it's the settled current position.
    @MainActor
    func waitUntilCurrent(_ index: Int, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let position = app.position(index)
        waitUntil("position \(index) is current", file: file, line: line) {
            position.exists && abs(position.frame.minY - app.frame.minY) < 1 && position.frame.height > 0
        }
    }

    /// Waits until the position's overlay is gone, i.e. its game is showing and can be played.
    @MainActor
    func waitUntilReady(_ index: Int, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let position = app.position(index)
        let overlay = position.descendants(matching: .any)["game.overlay"]
        waitUntil("position \(index) is ready to play", file: file, line: line) {
            position.exists && !overlay.exists
        }
    }
}
