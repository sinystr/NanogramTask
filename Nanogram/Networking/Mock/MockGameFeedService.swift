import Foundation

// The fake feed exists only in debug builds, for development and tests. Release builds
// always use the real server.
#if DEBUG

/// A fake feed that makes up its own games. Used for development, previews and tests.
actor MockGameFeedService: GameFeedServiceProtocol {
    private let pageSize: Int
    private let totalPages: Int?
    /// Tests can change the delay and the failures while the feed is running.
    private var delay: Duration
    private var failure: FailurePolicy
    /// Every page that was asked for, in order. Failed and cancelled requests count too.
    private(set) var requestedPages: [Int] = []

    init(configuration: Configuration = Configuration()) {
        pageSize = configuration.pageSize
        totalPages = configuration.totalPages
        delay = configuration.delay
        failure = configuration.failure
    }

    func setFailure(_ failure: FailurePolicy) {
        self.failure = failure
    }

    func setDelay(_ delay: Duration) {
        self.delay = delay
    }

    func fetchPage(_ page: Int) async throws -> FeedPage {
        requestedPages.append(page)
        let requestNumber = requestedPages.count
        try await Task.sleep(for: delay)

        switch failure {
        case .always(let error):
            throw error
        case .firstRequests(let count, let error) where requestNumber <= count:
            throw error
        case .pages(let failingPages, let error) where failingPages.contains(page):
            throw error
        case .none, .firstRequests, .pages:
            break
        }

        // Pages are numbered from 1. A page after the last one is empty.
        let lastPage = totalPages ?? Int.max
        guard page <= lastPage else {
            return FeedPage(games: [], nextPage: nil)
        }
        let firstIndex = (page - 1) * pageSize
        let games = (firstIndex..<(firstIndex + pageSize)).map(Self.makeGame)
        let nextPage: Int? = page < lastPage ? page + 1 : nil
        return FeedPage(games: games, nextPage: nextPage)
    }

    /// Makes up a game: a web page with a colored background and the game's name on it.
    private static func makeGame(at index: Int) -> Game {
        let title = "Game \(index + 1)"
        // Each game's background is a bit further around the color wheel than the one before.
        let hue = (index * 47) % 360
        let html = """
            <!DOCTYPE html><html lang="en"><head><meta charset="utf-8">
            <meta name="viewport" content="width=device-width,initial-scale=1">
            <title>\(title)</title></head>
            <body style="margin:0;height:100vh;display:flex;align-items:center;justify-content:center;\
            background:hsl(\(hue),50%,30%);color:#fff;font:700 32px -apple-system,sans-serif">\(title)</body></html>
            """
        // The id comes from the position, so it is the same every time the app runs.
        return Game(
            id: "mock-\(index)",
            title: title,
            html: html,
            creatorUsername: "creator\(index % 7)",
            plays: 1_000 + index * 37,
            likes: 50 + index * 3
        )
    }
}

#endif
