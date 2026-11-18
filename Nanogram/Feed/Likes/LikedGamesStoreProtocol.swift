/// Keeps the ids of the games the user liked, so likes survive relaunching the app.
@MainActor
protocol LikedGamesStoreProtocol: AnyObject {
    /// The ids of every game the user has liked.
    func loadLikedGameIDs() -> Set<String>

    /// Replaces the saved likes with `likedGameIDs`.
    func saveLikedGameIDs(_ likedGameIDs: Set<String>)
}
