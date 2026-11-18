import Foundation
import Testing
@testable import Nanogram

@MainActor
struct FeedViewModelTests {
    private func makeSUT(
        _ configuration: MockGameFeedService.Configuration = .test(),
        gamesKeptBehind: Int = 10
    ) -> (FeedViewModel, MockGameFeedService) {
        let service = MockGameFeedService(configuration: configuration)
        let feedConfiguration = FeedViewModel.Configuration(gamesKeptBehind: gamesKeptBehind)
        let viewModel = makeFeedViewModel(service: service, configuration: feedConfiguration)
        return (viewModel, service)
    }

    /// Starts and waits for the first page to land.
    private func makeLoadedSUT(
        _ configuration: MockGameFeedService.Configuration = .test()
    ) async -> (FeedViewModel, MockGameFeedService) {
        let (viewModel, service) = makeSUT(configuration)
        viewModel.start()
        await waitUntil { viewModel.state == .loaded(loadMore: .idle) }
        return (viewModel, service)
    }

    // MARK: - Initial load

    @Test func startsInLoadingFirstPageState() {
        let (viewModel, _) = makeSUT()
        #expect(viewModel.state == .loadingFirstPage)
        #expect(viewModel.scrollablePositionCount == 0)
    }

    @Test func initialLoadSuccessShowsGames() async {
        let (viewModel, service) = await makeLoadedSUT()

        #expect(viewModel.loadedGameCount == 10)
        #expect(viewModel.scrollablePositionCount == 10)
        #expect(viewModel.currentPosition == 0)
        #expect(viewModel.game(at: 0)?.id == "mock-0")
        #expect(await service.requestedPages == [1])
    }

    @Test func initialLoadFailureShowsError() async {
        let (viewModel, _) = makeSUT(.test(failure: .always(.server(statusCode: 500))))
        viewModel.start()
        await waitUntil { viewModel.state != .loadingFirstPage }

        #expect(viewModel.state == .failedInitial(.server(statusCode: 500)))
        #expect(viewModel.scrollablePositionCount == 0)
    }

    @Test func invalidDataSurfacesAsInvalidData() async {
        let (viewModel, _) = makeSUT(.test(failure: .always(.invalidData)))
        viewModel.start()
        await waitUntil { viewModel.state != .loadingFirstPage }

        #expect(viewModel.state == .failedInitial(.invalidData))
    }

    @Test func retryAfterInitialFailureLoadsGames() async {
        let (viewModel, service) = makeSUT(.test(failure: .firstRequests(count: 1, error: .timedOut)))
        viewModel.start()
        await waitUntil { viewModel.state == .failedInitial(.timedOut) }

        viewModel.retry()
        #expect(viewModel.state == .loadingFirstPage)
        await waitUntil { viewModel.state == .loaded(loadMore: .idle) }

        #expect(viewModel.loadedGameCount == 10)
        #expect(await service.requestedPages == [1, 1])
    }

    @Test func startTwiceDoesNotDuplicateTheInitialRequest() async {
        let (viewModel, service) = makeSUT(.test(delay: .milliseconds(50)))
        viewModel.start()
        viewModel.start()
        await waitUntil { viewModel.state == .loaded(loadMore: .idle) }

        #expect(await service.requestedPages == [1])
    }

    // MARK: - Pagination

    @Test func doesNotLoadMoreWhileFarFromTheEnd() async {
        let (viewModel, service) = await makeLoadedSUT()

        viewModel.didSettle(at: 5) // 4 games left after this one

        #expect(viewModel.state == .loaded(loadMore: .idle))
        #expect(await service.requestedPages == [1])
    }

    @Test func loadsNextPageWithinThreeOfTheEnd() async {
        let (viewModel, service) = await makeLoadedSUT()

        viewModel.didSettle(at: 6) // 3 games left after this one

        #expect(viewModel.state == .loaded(loadMore: .loading))
        #expect(viewModel.scrollablePositionCount == 11)
        await waitUntil { viewModel.state == .loaded(loadMore: .idle) }
        #expect(viewModel.loadedGameCount == 20)
        #expect(await service.requestedPages == [1, 2])
    }

    @Test func doesNotDuplicateRequestsWhileOneIsInFlight() async {
        let (viewModel, service) = await makeLoadedSUT(.test(delay: .milliseconds(100)))

        viewModel.didSettle(at: 6)
        viewModel.didSettle(at: 7)
        viewModel.didSettle(at: 8)
        viewModel.didSettle(at: 9)
        await waitUntil { viewModel.state == .loaded(loadMore: .idle) }

        #expect(await service.requestedPages == [1, 2])
    }

    @Test func stopsPaginatingAtTheEndOfTheFeed() async {
        let (viewModel, service) = await makeLoadedSUT(.test(totalPages: 1))

        viewModel.didSettle(at: 9)

        #expect(viewModel.state == .loaded(loadMore: .idle))
        #expect(viewModel.content(at: 10) != .loadingMore) // no load-more position: the feed loops instead
        #expect(await service.requestedPages == [1])
    }

    @Test func paginationFailureAndRetryKeepTheCurrentIndex() async {
        let (viewModel, service) = await makeLoadedSUT(.test(failure: .pages([2], error: .server(statusCode: 503))))

        viewModel.didSettle(at: 7)
        await waitUntil { viewModel.state == .loaded(loadMore: .failed(.server(statusCode: 503))) }
        #expect(viewModel.currentPosition == 7)
        #expect(viewModel.scrollablePositionCount == 11) // the load-more position shows the error

        // A failed page isn't retried automatically just because the user keeps swiping.
        viewModel.didSettle(at: 8)
        #expect(await service.requestedPages == [1, 2])

        await service.setFailure(.none)
        viewModel.retry()
        await waitUntil { viewModel.state == .loaded(loadMore: .idle) }

        #expect(viewModel.currentPosition == 8)
        #expect(viewModel.loadedGameCount == 20)
        #expect(await service.requestedPages == [1, 2, 2])
    }

    @Test func settlingOnTheLoadMorePositionIsAllowedAndKeptAfterItLoads() async {
        let (viewModel, _) = await makeLoadedSUT(.test(delay: .milliseconds(50)))
        viewModel.didSettle(at: 9)
        viewModel.didSettle(at: 10) // the load-more position

        #expect(viewModel.currentPosition == 10)
        await waitUntil { viewModel.state == .loaded(loadMore: .idle) }
        // The load-more position now shows the first game of the new page.
        #expect(viewModel.currentPosition == 10)
        #expect(viewModel.game(at: 10)?.id == "mock-10")
    }

    @Test func settledIndexIsClampedToTheFeed() async {
        let (viewModel, _) = await makeLoadedSUT(.test(totalPages: 1))

        viewModel.didSettle(at: 50)
        #expect(viewModel.currentPosition == 9)
        viewModel.didSettle(at: -3)
        #expect(viewModel.currentPosition == 0)
    }

    // MARK: - Windowing

    @Test func releasesGamesMoreThanTheRetainedCountBehind() async {
        let (viewModel, _) = await makeLoadedSUT()
        for index in 1...15 {
            viewModel.didSettle(at: index)
            await waitUntil { viewModel.state == .loaded(loadMore: .idle) }
        }

        #expect(viewModel.currentPosition == 15)
        #expect(viewModel.game(at: 4) == nil)
        #expect(viewModel.game(at: 5)?.id == "mock-5")
        #expect(viewModel.game(at: 15)?.id == "mock-15")
        // Logical positions don't shift when old games are released.
        #expect(viewModel.loadedGameCount == 20)
    }

    // MARK: - Play mode

    @Test func entersPlayModeOnlyForTheCurrentGame() async {
        let (viewModel, _) = await makeLoadedSUT()
        viewModel.didSettle(at: 2)

        viewModel.enterPlay(at: 3)
        #expect(!viewModel.isPlaying)

        viewModel.enterPlay(at: 2)
        #expect(viewModel.isPlaying)

        viewModel.exitPlay()
        #expect(!viewModel.isPlaying)
        #expect(viewModel.currentPosition == 2)
    }
}
