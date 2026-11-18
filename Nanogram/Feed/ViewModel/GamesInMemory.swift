/// What the feed knows about each kept game, by game index.
///
/// A kept game is in one of four states:
/// - loaded: the game is here
/// - missing: its page was downloaded again and no longer had it
/// - reload failed: downloading its page again failed
/// - nothing recorded: it was forgotten and waits to be downloaded again
///
/// Only kept games are recorded. It never changes: every method returns a new value, and the
/// owner reassigns it.
struct GamesInMemory: Equatable {
    /// What is known about one kept game.
    private enum KeptGame: Equatable {
        case loaded(Game)
        case missing
        case reloadFailed(FeedError)
    }

    private let keptGames: [Int: KeptGame]

    /// Nothing in memory yet.
    init() {
        self.init(keptGames: [:])
    }

    private init(keptGames: [Int: KeptGame]) {
        self.keptGames = keptGames
    }

    // MARK: - Reading

    /// The game at `gameIndex`, if it is loaded.
    func game(at gameIndex: Int) -> Game? {
        guard case .loaded(let game) = keptGames[gameIndex] else {
            return nil
        }

        return game
    }

    /// True if the game's page was downloaded again and no longer had it.
    func isMissing(_ gameIndex: Int) -> Bool {
        keptGames[gameIndex] == .missing
    }

    /// Why downloading the game's page again failed, or `nil` if it didn't.
    func reloadError(at gameIndex: Int) -> FeedError? {
        guard case .reloadFailed(let error) = keptGames[gameIndex] else {
            return nil
        }

        return error
    }

    // MARK: - New values

    /// Adds the games of a downloaded page, but only the ones that are kept.
    func storing(
        _ pageGames: [Game],
        gameIndices pageGameIndices: Range<Int>,
        keeping gameIndicesToKeep: Set<Int>
    ) -> GamesInMemory {
        var updatedGames = keptGames

        // `zip` pairs each game with its game index. If the page has more games than it had the
        // first time, the extra ones are left out, because later game indices belong to other pages.
        for (index, game) in zip(pageGameIndices, pageGames) where gameIndicesToKeep.contains(index) {
            updatedGames[index] = .loaded(game)
        }

        return GamesInMemory(keptGames: updatedGames)
    }

    /// Adds the games of a page that was downloaded again.
    ///
    /// Kept games the page no longer has are marked missing, so they show "Couldn't load this
    /// game" instead of a spinner that never ends.
    func storingReloadedPage(
        _ pageGames: [Game],
        gameIndices pageGameIndices: Range<Int>,
        keeping gameIndicesToKeep: Set<Int>
    ) -> GamesInMemory {
        // First every kept game of the page that isn't loaded is marked missing. Then the games
        // the page still has replace those marks.
        let withMissingMarks = marking(pageGameIndices, as: .missing, keeping: gameIndicesToKeep)
        return withMissingMarks.storing(pageGames, gameIndices: pageGameIndices, keeping: gameIndicesToKeep)
    }

    /// Remembers that downloading a page again failed, for its kept games that aren't loaded.
    func recordingReloadError(
        _ error: FeedError,
        gameIndices pageGameIndices: Range<Int>,
        keeping gameIndicesToKeep: Set<Int>
    ) -> GamesInMemory {
        marking(pageGameIndices, as: .reloadFailed(error), keeping: gameIndicesToKeep)
    }

    /// Forgets a page's errors and missing marks, so the page is downloaded again (Retry).
    func clearingReloadProblems(gameIndices pageGameIndices: Range<Int>) -> GamesInMemory {
        var updatedGames = keptGames
        for index in pageGameIndices where game(at: index) == nil {
            updatedGames[index] = nil
        }

        return GamesInMemory(keptGames: updatedGames)
    }

    /// Forgets everything about games that are no longer kept.
    func keepingOnly(_ gameIndicesToKeep: Set<Int>) -> GamesInMemory {
        var updatedGames: [Int: KeptGame] = [:]
        for (index, keptGame) in keptGames where gameIndicesToKeep.contains(index) {
            updatedGames[index] = keptGame
        }

        return GamesInMemory(keptGames: updatedGames)
    }

    // MARK: - Private

    /// Puts `mark` on every kept game of the page that isn't loaded. Loaded games stay as they are.
    private func marking(
        _ pageGameIndices: Range<Int>,
        as mark: KeptGame,
        keeping gameIndicesToKeep: Set<Int>
    ) -> GamesInMemory {
        var updatedGames = keptGames
        for index in pageGameIndices where gameIndicesToKeep.contains(index) {
            if game(at: index) == nil {
                updatedGames[index] = mark
            }
        }

        return GamesInMemory(keptGames: updatedGames)
    }
}
