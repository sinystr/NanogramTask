import Testing
@testable import Nanogram

/// The view model remembers whether the app is in use, so the game scroll screen can pause the
/// current game while the app is in the background.
@MainActor
struct FeedViewModelAppActivityTests {
    private func makeViewModel() -> FeedViewModel {
        let service = MockGameFeedService(configuration: .test())
        return makeFeedViewModel(service: service)
    }

    @Test func appStartsActive() {
        #expect(makeViewModel().isAppActive)
    }

    @Test func goingToTheBackgroundAndBackIsRemembered() {
        let viewModel = makeViewModel()

        viewModel.appBecameInactive()
        #expect(!viewModel.isAppActive)

        viewModel.appBecameActive()
        #expect(viewModel.isAppActive)
    }

    @Test func playModeSurvivesTheBackground() async {
        let viewModel = makeViewModel()
        viewModel.start()
        await waitUntil { viewModel.state == .loaded(loadMore: .idle) }
        viewModel.enterPlay(at: 0)

        viewModel.appBecameInactive()
        viewModel.appBecameActive()

        // The player comes back to the game they were playing, not to the feed.
        #expect(viewModel.isPlaying)
    }
}
