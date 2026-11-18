extension FeedViewModel {
    /// Settings for how far ahead the feed loads and how many games it keeps in memory.
    struct Configuration {
        /// How many games away the app starts getting games ready, so they're there before
        /// the user swipes to them. With 3:
        /// - the next page starts loading when only 3 games are left
        /// - a game that was removed from memory loads again when the user is 3 games away
        let prefetchDistance: Int

        /// How many games before the current one stay in memory.
        let gamesKeptBehind: Int

        /// How many games after the current one stay in memory, at least.
        /// The rest of that API page is kept too, so a page isn't split in half.
        /// With the defaults, 21 to 30 games are kept in memory at once.
        let minimumGamesKeptAhead: Int

        init(prefetchDistance: Int = 3, gamesKeptBehind: Int = 10, minimumGamesKeptAhead: Int = 10) {
            self.prefetchDistance = prefetchDistance
            self.gamesKeptBehind = gamesKeptBehind
            self.minimumGamesKeptAhead = minimumGamesKeptAhead
        }
    }
}
