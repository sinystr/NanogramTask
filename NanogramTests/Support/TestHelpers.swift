import Testing
@testable import Nanogram

/// Polls until `condition` holds, so async tests don't depend on fixed sleeps.
@MainActor
func waitUntil(
    timeout: Duration = .seconds(2),
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: () -> Bool
) async {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while !condition() {
        guard clock.now < deadline else {
            Issue.record("Condition not met within \(timeout)", sourceLocation: sourceLocation)
            return
        }
        try? await Task.sleep(for: .milliseconds(5))
    }
}

/// A feed view model wired the way the app wires it, on top of `service`.
@MainActor
func makeFeedViewModel(
    service: any GameFeedServiceProtocol,
    likedGamesStore: any LikedGamesStoreProtocol = InMemoryLikedGamesStore(),
    configuration: FeedViewModel.Configuration = FeedViewModel.Configuration()
) -> FeedViewModel {
    FeedViewModel(
        nextPageDownloader: PageDownloader(service: service),
        removedPageDownloader: PageDownloader(service: service),
        likedGamesStore: likedGamesStore,
        configuration: configuration
    )
}

/// Settles on each index in turn, waiting for any pagination it triggers to finish.
@MainActor
func settle(_ viewModel: FeedViewModel, through indices: some Sequence<Int>) async {
    for index in indices {
        viewModel.didSettle(at: index)
        await waitUntil { viewModel.state != .loaded(loadMore: .loading) }
    }
}

func makeGames(_ range: Range<Int>) -> [Game] {
    range.map { Game(id: "game-\($0)", title: "Game \($0)", html: "<html></html>", creatorUsername: "c", plays: 0, likes: 0) }
}
