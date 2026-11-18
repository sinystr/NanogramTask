import Testing
@testable import Nanogram

/// In these tests page 2 covered game indices 10..<20 the first time it was downloaded.
struct GamesInMemoryTests {
    private let pageTwoGameIndices = 10..<20

    @Test func storesOnlyTheGamesThatAreKept() {
        let games = GamesInMemory().storing(makeGames(0..<10), gameIndices: 0..<10, keeping: [2, 3])

        #expect(games.game(at: 2)?.id == "game-2")
        #expect(games.game(at: 3)?.id == "game-3")
        #expect(games.game(at: 4) == nil)
    }

    @Test func reloadedPageNeverTakesMoreGamesThanItHadTheFirstTime() {
        // Page 2 now comes back with 12 games.
        let games = GamesInMemory().storingReloadedPage(
            makeGames(100..<112),
            gameIndices: pageTwoGameIndices,
            keeping: Set(0..<30)
        )

        #expect(games.game(at: 19) != nil)
        #expect(games.game(at: 20) == nil)
    }

    @Test func gamesAPageNoLongerHasAreMarkedMissing() {
        // Page 2 now comes back with only 3 games.
        let games = GamesInMemory().storingReloadedPage(
            makeGames(100..<103),
            gameIndices: pageTwoGameIndices,
            keeping: Set(0..<30)
        )

        #expect(games.game(at: 12) != nil)
        #expect(!games.isMissing(12))
        #expect(games.isMissing(13))
        #expect(games.isMissing(19))
    }

    @Test func reloadErrorIsRecordedOnlyForKeptGamesThatAreNotLoaded() {
        let games = GamesInMemory()
            .storing(makeGames(10..<12), gameIndices: 10..<12, keeping: Set(0..<30))
            .recordingReloadError(.offline, gameIndices: pageTwoGameIndices, keeping: Set(0..<15))

        #expect(games.game(at: 10) != nil)
        #expect(games.reloadError(at: 10) == nil)
        #expect(games.reloadError(at: 14) == .offline)
        #expect(games.reloadError(at: 15) == nil) // not kept
    }

    @Test func retryClearsThePagesMissingGamesButKeepsItsLoadedOnes() {
        let games = GamesInMemory()
            .storingReloadedPage(makeGames(100..<103), gameIndices: pageTwoGameIndices, keeping: Set(0..<30))
        #expect(games.isMissing(15))

        let afterRetry = games.clearingReloadProblems(gameIndices: pageTwoGameIndices)

        #expect(afterRetry.game(at: 12) != nil)
        #expect(!afterRetry.isMissing(15))
    }

    @Test func retryClearsThePagesErrors() {
        let games = GamesInMemory()
            .recordingReloadError(.offline, gameIndices: pageTwoGameIndices, keeping: Set(0..<30))
        #expect(games.reloadError(at: 15) == .offline)

        let afterRetry = games.clearingReloadProblems(gameIndices: pageTwoGameIndices)

        #expect(afterRetry.reloadError(at: 15) == nil)
    }

    @Test func movingAwayForgetsGamesMarksAndErrorsThatAreNoLongerKept() {
        let games = GamesInMemory()
            .storing(makeGames(0..<10), gameIndices: 0..<10, keeping: Set(0..<20))
            .storingReloadedPage(makeGames(100..<103), gameIndices: pageTwoGameIndices, keeping: Set(0..<20))

        // The user moved on: only game indices 12..<20, all on page 2, are kept now.
        let kept = games.keepingOnly(Set(12..<20))

        #expect(kept.game(at: 5) == nil)
        #expect(kept.game(at: 12) != nil)
        #expect(kept.isMissing(15))
    }
}
