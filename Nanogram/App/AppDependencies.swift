import Foundation

/// Builds the parts of the app and connects them.
/// This is the only place that decides whether the real or the fake feed is used.
@MainActor
struct AppDependencies {
    let feedViewModel: any FeedViewModelProtocol
    let gameViewSettings: GameViewSettings

    init(launch: LaunchConfiguration) {
        let service = Self.makeFeedService(launch: launch)
        feedViewModel = FeedViewModel(
            nextPageDownloader: PageDownloader(service: service),
            removedPageDownloader: PageDownloader(service: service),
            likedGamesStore: LikedGamesStore()
        )

        let lifecyclePolicy = GameLifecyclePolicy(preloadsAdjacentGames: launch.preloadsAdjacentGames)
        gameViewSettings = GameViewSettings(lifecyclePolicy: lifecyclePolicy)
    }

    /// The real server. In debug builds, the fake feed instead when the app was launched
    /// with `-useMockFeed`, as the UI tests do. Release builds don't contain the fake feed.
    private static func makeFeedService(launch: LaunchConfiguration) -> any GameFeedServiceProtocol {
        #if DEBUG
        if let mockFeed = launch.mockFeed {
            return makeMockFeedService(settings: mockFeed)
        }
        #endif

        return RemoteGameFeedService()
    }

    #if DEBUG
    private static func makeMockFeedService(settings: MockFeedSettings) -> any GameFeedServiceProtocol {
        var failure: MockGameFeedService.FailurePolicy = .none
        if settings.failsInitialLoad {
            failure = .firstRequests(count: 1, error: .offline)
        }

        let configuration = MockGameFeedService.Configuration(
            totalPages: settings.totalPages,
            delay: settings.delay,
            failure: failure
        )

        return MockGameFeedService(configuration: configuration)
    }
    #endif
}
