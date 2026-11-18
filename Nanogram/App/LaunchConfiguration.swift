/// Settings read from the launch arguments, on every launch. UI tests use them to control the app.
///
/// Supported arguments:
/// - `-disableGamePreload`: don't load the previous and next games early.
/// - `-useMockFeed` (debug builds only): use the fake feed instead of the real server.
///   `MockFeedSettings` lists the `-mock…` arguments that go with it.
struct LaunchConfiguration {
    private enum Argument {
        static let disableGamePreload = "-disableGamePreload"
        static let useMockFeed = "-useMockFeed"
    }

    /// True if the previous and next games are loaded early and wait paused.
    let preloadsAdjacentGames: Bool

    #if DEBUG
    /// How the fake feed behaves. `nil` means the app uses the real server.
    let mockFeed: MockFeedSettings?
    #endif

    init(arguments: [String]) {
        preloadsAdjacentGames = !arguments.contains(Argument.disableGamePreload)

        #if DEBUG
        mockFeed = Self.mockFeedSettings(in: arguments)
        #endif
    }

    #if DEBUG
    /// The fake feed's settings, or `nil` if the app wasn't launched with `-useMockFeed`.
    private static func mockFeedSettings(in arguments: [String]) -> MockFeedSettings? {
        guard arguments.contains(Argument.useMockFeed) else {
            return nil
        }

        return MockFeedSettings(arguments: arguments)
    }
    #endif
}
