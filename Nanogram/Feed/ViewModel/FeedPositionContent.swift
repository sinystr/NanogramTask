/// What one feed position should show.
enum FeedPositionContent: Equatable {
    /// A game that is in memory.
    case game(Game)
    /// A game that was removed from memory and is being downloaded again.
    case reloadingGame
    /// Downloading the game again failed.
    case reloadFailed(FeedError)
    /// The game's page was downloaded again, but the game was no longer in it.
    case gameMissing
    /// The extra last position, shown while more games are loading.
    case loadingMore
    /// The extra last position, shown when loading more games failed.
    case loadMoreFailed(FeedError)
}
