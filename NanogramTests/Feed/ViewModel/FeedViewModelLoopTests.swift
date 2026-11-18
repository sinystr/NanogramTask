import Testing
@testable import Nanogram

/// Once the server has no more pages, the feed starts over from the first game, forever.
@MainActor
struct FeedViewModelLoopTests {
    private func makeLoadedSUT(totalPages: Int) async -> (FeedViewModel, MockGameFeedService) {
        let service = MockGameFeedService(configuration: .test(totalPages: totalPages))
        let viewModel = makeFeedViewModel(service: service)
        viewModel.start()
        await waitUntil { viewModel.state == .loaded(loadMore: .idle) }
        return (viewModel, service)
    }

    @Test func thePositionAfterTheLastGameIsTheFirstGame() async {
        let (viewModel, service) = await makeLoadedSUT(totalPages: 1)

        viewModel.didSettle(at: 9)

        #expect(viewModel.scrollablePositionCount == 11)
        #expect(viewModel.game(at: 10)?.id == "mock-0")
        #expect(await service.requestedPages == [1])
    }

    @Test func thereIsAlwaysANextPosition() async {
        let (viewModel, _) = await makeLoadedSUT(totalPages: 1)

        await settle(viewModel, through: 1...25)

        #expect(viewModel.currentPosition == 25)
        #expect(viewModel.scrollablePositionCount == 27)
        #expect(viewModel.game(at: 26)?.id == "mock-6")
    }

    @Test func loopingAroundKeepsMemoryBoundedAndReloadsRemovedGames() async {
        let (viewModel, service) = await makeLoadedSUT(totalPages: 3)
        await settle(viewModel, through: 1...29)

        // Around the loop: position 35 is game 5, loaded again after being removed.
        await settle(viewModel, through: 30...35)
        await waitUntil { viewModel.game(at: 35)?.id == "mock-5" }

        // Only games near game 5, counting around the loop, are in memory.
        #expect(viewModel.game(at: 27) != nil)
        #expect(viewModel.game(at: 8) != nil)
        #expect(viewModel.game(at: 20) == nil)
        #expect(viewModel.game(at: 24) == nil)
        // Only the removed page was loaded again; the feed never asked for page 4.
        #expect(await service.requestedPages == [1, 2, 3, 1])
    }

    @Test func aGameCanBePlayedAfterLooping() async {
        let (viewModel, _) = await makeLoadedSUT(totalPages: 1)
        await settle(viewModel, through: 1...12)

        viewModel.enterPlay(at: 12)

        #expect(viewModel.isPlaying)
    }
}
