#if DEBUG

/// How the fake feed behaves, read from the `-mock…` launch arguments.
/// It exists only when the app was launched with `-useMockFeed`.
///
/// Supported arguments:
/// - `-mockDelayMs <n>`: how long the fake feed takes to answer, in milliseconds.
/// - `-mockTotalPages <n>`: how many pages the fake feed has. Without it the feed never ends.
/// - `-mockFailInitialLoad`: the first request fails as "offline". Later ones work.
struct MockFeedSettings {
    private enum Argument {
        static let delayInMilliseconds = "-mockDelayMs"
        static let totalPages = "-mockTotalPages"
        static let failsInitialLoad = "-mockFailInitialLoad"
    }

    /// How long the fake feed takes to answer when `-mockDelayMs` isn't given.
    static let defaultDelay: Duration = .milliseconds(600)

    /// How long the fake feed takes to answer.
    let delay: Duration

    /// How many pages the fake feed has. `nil` means the feed never ends.
    let totalPages: Int?

    /// True if the first request fails as "offline".
    let failsInitialLoad: Bool

    init(arguments: [String]) {
        delay = Self.delay(in: arguments)
        totalPages = Self.number(after: Argument.totalPages, in: arguments)
        failsInitialLoad = arguments.contains(Argument.failsInitialLoad)
    }

    /// The delay given with `-mockDelayMs`, or the default one.
    private static func delay(in arguments: [String]) -> Duration {
        guard let milliseconds = number(after: Argument.delayInMilliseconds, in: arguments) else {
            return defaultDelay
        }

        return .milliseconds(milliseconds)
    }

    /// The number written right after `name`. If `name` appears more than once, the last
    /// one counts, so a later argument can replace an earlier one.
    private static func number(after name: String, in arguments: [String]) -> Int? {
        guard let nameIndex = arguments.lastIndex(of: name) else {
            return nil
        }

        let valueIndex = nameIndex + 1
        guard arguments.indices.contains(valueIndex) else {
            return nil
        }

        return Int(arguments[valueIndex])
    }
}

#endif
