import XCTest

extension XCUIApplication {
    /// The app on the mock feed. Arguments are the app's `LaunchConfiguration` flags.
    @MainActor
    static func feed(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-useMockFeed", "-mockDelayMs", "200"] + arguments
        return app
    }

    /// The app on the real API with real games, exactly as a user gets it. Needs a network
    /// connection.
    @MainActor
    static func realFeed() -> XCUIApplication {
        XCUIApplication()
    }

    @MainActor
    func position(_ index: Int) -> XCUIElement {
        descendants(matching: .any)["feed.position.\(index)"]
    }

    @MainActor
    var closeGameButton: XCUIElement { buttons["game.close"] }
}
