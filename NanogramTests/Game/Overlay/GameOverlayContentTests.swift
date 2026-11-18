import Testing
@testable import Nanogram

struct GameOverlayContentTests {
    private let game = Game(id: "g", title: "Nano Hole", html: "<html></html>", creatorUsername: "arnaud", plays: 0, likes: 0)

    private func overlay(_ content: FeedPositionContent, _ gameState: GameLoadState = .idle) -> GameOverlayContent? {
        GameOverlayContent(content: content, gameState: gameState)
    }

    @Test func readyGameShowsTheGameItself() {
        #expect(overlay(.game(game), .ready) == nil)
    }

    @Test func gameThatIsNotReadyShowsItsNameOrASpinner() {
        let expectedWhileIdle = GameOverlayContent(title: "Nano Hole", detail: "by arnaud", background: .driftingGlows)
        let expectedWhileLoading = GameOverlayContent(title: "Nano Hole", showsSpinner: true, background: .driftingGlows)

        #expect(overlay(.game(game), .idle) == expectedWhileIdle)
        #expect(overlay(.game(game), .loading) == expectedWhileLoading)
    }

    @Test func gameWithoutATitleIsCalledUntitled() {
        let untitledGame = Game(id: "g", title: nil, html: "<html></html>", creatorUsername: nil, plays: nil, likes: nil)
        #expect(overlay(.game(untitledGame), .idle)?.title == "Untitled game")
    }

    @Test func gameWithUnknownCreatorShowsOnlyItsName() {
        let gameWithoutCreator = Game(id: "g", title: "Nano Hole", html: "<html></html>", creatorUsername: nil, plays: 0, likes: 0)
        let shown = overlay(.game(gameWithoutCreator), .idle)

        #expect(shown?.title == "Nano Hole")
        #expect(shown?.detail == nil)
    }

    @Test func failedGameShowsItsErrorWithRetry() {
        let error = GameLoadError.processTerminated
        let expected = GameOverlayContent(title: error.title, detail: error.message, showsRetry: true)
        #expect(overlay(.game(game), .failed(error)) == expected)
    }

    @Test func feedErrorsShowTheirMessageWithRetry() {
        let error = FeedError.offline
        let expectedForGame = GameOverlayContent(title: error.title, detail: error.message, showsRetry: true)
        let expectedForLoadMore = GameOverlayContent(
            title: error.title,
            detail: error.message,
            showsRetry: true,
            background: .driftingGlows
        )

        #expect(overlay(.reloadFailed(error)) == expectedForGame)
        #expect(overlay(.loadMoreFailed(error)) == expectedForLoadMore)
    }

    @Test func missingGameSaysSo() {
        let error = GameLoadError.unavailable
        let expected = GameOverlayContent(title: error.title, detail: error.message, showsRetry: true)
        #expect(overlay(.gameMissing) == expected)
    }

    @Test func loadingPositionsShowASpinner() {
        let expectedForReloading = GameOverlayContent(showsSpinner: true, background: .driftingGlows)
        let expectedForLoadMore = GameOverlayContent(
            title: "Loading more games…",
            showsSpinner: true,
            background: .driftingGlows
        )

        #expect(overlay(.reloadingGame) == expectedForReloading)
        #expect(overlay(.loadingMore) == expectedForLoadMore)
    }

    @Test func loadingShowsDriftingGlowsAndGameErrorsShowTheBlueGradient() {
        #expect(overlay(.game(game), .idle)?.background == .driftingGlows)
        #expect(overlay(.game(game), .loading)?.background == .driftingGlows)
        #expect(overlay(.reloadingGame)?.background == .driftingGlows)
        #expect(overlay(.loadingMore)?.background == .driftingGlows)
        #expect(overlay(.loadMoreFailed(.offline))?.background == .driftingGlows)

        #expect(overlay(.game(game), .failed(.timedOut))?.background == .blueGradient)
        #expect(overlay(.reloadFailed(.offline))?.background == .blueGradient)
        #expect(overlay(.gameMissing)?.background == .blueGradient)
    }

    /// A game view is never blank: everything except a ready game has an overlay.
    @Test(arguments: [GameLoadState.idle, .loading, .ready, .failed(.timedOut)])
    func positionsWithoutAGameAlwaysHaveAnOverlay(gameState: GameLoadState) {
        let contents: [FeedPositionContent] = [
            .reloadingGame, .loadingMore, .gameMissing, .reloadFailed(.offline), .loadMoreFailed(.timedOut),
        ]
        for content in contents {
            #expect(overlay(content, gameState) != nil)
        }
    }

    @Test(arguments: [GameLoadError.unavailable, .loadFailed, .timedOut, .processTerminated])
    func everyErrorHasUserFacingText(error: GameLoadError) {
        #expect(!error.title.isEmpty)
        #expect(!error.message.isEmpty)
    }
}
