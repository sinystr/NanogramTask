import Testing
@testable import Nanogram

/// Going back (or forward again) past the retained window fetches released games again.
@MainActor
struct FeedViewModelRefetchTests {
    /// Loads pages 1–3 (games 0–29) and settles on game 25, which releases games 0–14.
    private func makeScrolledSUT(
        _ configuration: MockGameFeedService.Configuration = .test()
    ) async -> (FeedViewModel, MockGameFeedService) {
        let service = MockGameFeedService(configuration: configuration)
        let viewModel = makeFeedViewModel(service: service)
        viewModel.start()
        await waitUntil { viewModel.state == .loaded(loadMore: .idle) }
        await settle(viewModel, through: 1...25)
        return (viewModel, service)
    }

    @Test func scrollingFarAheadReleasesOldGames() async {
        let (viewModel, service) = await makeScrolledSUT()

        #expect(viewModel.game(at: 14) == nil)
        #expect(viewModel.game(at: 15) != nil)
        #expect(await service.requestedPages == [1, 2, 3])
    }

    @Test func goingBackRefetchesTheReleasedPage() async {
        let (viewModel, service) = await makeScrolledSUT()

        await settle(viewModel, through: (18...24).reversed())
        #expect(await service.requestedPages == [1, 2, 3]) // nothing released is near yet

        viewModel.didSettle(at: 17) // game 14 is now within 3 pages
        await waitUntil { viewModel.game(at: 14) != nil }

        #expect(viewModel.game(at: 14)?.id == "mock-14")
        #expect(viewModel.game(at: 10)?.id == "mock-10")
        #expect(await service.requestedPages == [1, 2, 3, 2])
    }

    @Test func releasedGameShowsLoadingAndIsFetchedOnlyOnce() async {
        let (viewModel, service) = await makeScrolledSUT()
        await settle(viewModel, through: (18...24).reversed())
        await service.setDelay(.milliseconds(100))

        viewModel.didSettle(at: 17)
        #expect(viewModel.content(at: 14) == .reloadingGame)
        viewModel.didSettle(at: 16)
        viewModel.didSettle(at: 15)
        await waitUntil { viewModel.game(at: 12) != nil }

        #expect(await service.requestedPages == [1, 2, 3, 2])
    }

    @Test func refetchFailureShowsAnErrorAndRetryRecovers() async {
        let (viewModel, service) = await makeScrolledSUT()
        await settle(viewModel, through: (18...24).reversed())
        await service.setFailure(.pages([2], error: .server(statusCode: 500)))

        viewModel.didSettle(at: 17)
        await waitUntil { viewModel.content(at: 14) == .reloadFailed(.server(statusCode: 500)) }

        // Not retried automatically while the user keeps moving.
        viewModel.didSettle(at: 16)
        #expect(await service.requestedPages == [1, 2, 3, 2])

        await service.setFailure(.none)
        viewModel.retry(at: 14)
        await waitUntil { viewModel.game(at: 14) != nil }

        #expect(viewModel.currentPosition == 16)
        #expect(await service.requestedPages == [1, 2, 3, 2, 2])
    }

    @Test func goingBackReleasesGamesFarAheadAndGoingForwardFetchesThemAgain() async {
        let (viewModel, service) = await makeScrolledSUT()

        await settle(viewModel, through: (5...24).reversed())
        await waitUntil { viewModel.game(at: 5) != nil }
        // 10 ahead of game 5 is game 15, so its whole page (10–19) stays; page 3 is released.
        #expect(viewModel.game(at: 19) != nil)
        #expect(viewModel.game(at: 20) == nil)
        #expect(await service.requestedPages == [1, 2, 3, 2, 1])

        await settle(viewModel, through: 6...25)
        await waitUntil { viewModel.game(at: 25) != nil }
        #expect(await service.requestedPages == [1, 2, 3, 2, 1, 3])
        #expect(viewModel.game(at: 14) == nil)
    }

    @Test func gamesMissingFromAShrunkPageAreShownAsUnavailable() async {
        let service = ScriptedFeedService(pages: [
            1: FeedPage(games: makeGames(0..<10), nextPage: 2),
            2: FeedPage(games: makeGames(10..<20), nextPage: 3),
            3: FeedPage(games: makeGames(20..<30), nextPage: nil),
        ])
        let viewModel = makeFeedViewModel(service: service)
        viewModel.start()
        await waitUntil { viewModel.state == .loaded(loadMore: .idle) }
        await settle(viewModel, through: 1...25)
        await service.replace(page: 2, with: FeedPage(games: makeGames(10..<13), nextPage: 3))

        await settle(viewModel, through: (17...24).reversed())
        await waitUntil { viewModel.game(at: 12) != nil }

        #expect(viewModel.content(at: 13) == .gameMissing)
        #expect(viewModel.content(at: 14) == .gameMissing)
        #expect(viewModel.content(at: 15) == .game(makeGames(15..<16)[0]))
    }

    @Test func emptyLastPageTurnsTheLoadMorePositionIntoTheFirstGame() async {
        let service = ScriptedFeedService(
            pages: [
                1: FeedPage(games: makeGames(0..<10), nextPage: 2),
                2: FeedPage(games: [], nextPage: nil),
            ],
            delay: .milliseconds(50)
        )
        let viewModel = makeFeedViewModel(service: service)
        viewModel.start()
        await waitUntil { viewModel.state == .loaded(loadMore: .idle) }

        viewModel.didSettle(at: 9)
        viewModel.didSettle(at: 10) // the load-more position
        #expect(viewModel.currentPosition == 10)
        await waitUntil { viewModel.state == .loaded(loadMore: .idle) }

        // The feed has ended, so it loops: that position now shows the first game.
        #expect(viewModel.currentPosition == 10)
        #expect(viewModel.content(at: 10) == .game(makeGames(0..<1)[0]))
    }
}
