import Testing
@testable import Nanogram

/// Likes are saved on the device by game id, so they survive relaunching the app and stay
/// on a game when the endless feed comes round to it again.
@MainActor
struct FeedViewModelLikeTests {
    private func makeLoadedViewModel(
        store: InMemoryLikedGamesStore,
        totalPages: Int? = nil
    ) async -> FeedViewModel {
        let service = MockGameFeedService(configuration: .test(totalPages: totalPages))
        let viewModel = makeFeedViewModel(service: service, likedGamesStore: store)
        viewModel.start()
        await waitUntil { viewModel.state == .loaded(loadMore: .idle) }
        return viewModel
    }

    @Test func likingAGameSavesItOnTheDevice() async {
        let store = InMemoryLikedGamesStore()
        let viewModel = await makeLoadedViewModel(store: store)

        viewModel.toggleLike(at: 2)

        #expect(viewModel.isLiked(at: 2))
        #expect(!viewModel.isLiked(at: 3))
        #expect(store.savedLikedGameIDs == ["mock-2"])
    }

    @Test func likingAgainRemovesTheLike() async {
        let store = InMemoryLikedGamesStore()
        let viewModel = await makeLoadedViewModel(store: store)

        viewModel.toggleLike(at: 2)
        viewModel.toggleLike(at: 2)

        #expect(!viewModel.isLiked(at: 2))
        #expect(store.savedLikedGameIDs.isEmpty)
    }

    @Test func likesFromAnEarlierLaunchAreShown() async {
        let store = InMemoryLikedGamesStore(likedGameIDs: ["mock-1"])
        let viewModel = await makeLoadedViewModel(store: store)

        #expect(viewModel.isLiked(at: 1))
        #expect(!viewModel.isLiked(at: 0))
    }

    @Test func aGameKeepsItsLikeWhenTheFeedComesRoundAgain() async {
        // One API page of 10 games, so position 13 shows game 3 again.
        let store = InMemoryLikedGamesStore()
        let viewModel = await makeLoadedViewModel(store: store, totalPages: 1)

        viewModel.toggleLike(at: 3)
        await settle(viewModel, through: 1...13)

        #expect(viewModel.isLiked(at: 13))
    }
}
