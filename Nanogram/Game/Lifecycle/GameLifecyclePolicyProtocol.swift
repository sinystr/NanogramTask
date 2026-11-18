/// Decides what the game at a feed position should be doing.
protocol GameLifecyclePolicyProtocol: Sendable {
    /// - Parameters:
    ///   - position: the position whose game is asked about.
    ///   - currentPosition: the position the user is on.
    ///   - isPlaying: true while the user plays the current game.
    ///   - isAppActive: false while the app is in the background or covered, for example by
    ///     Control Center. Then no game runs.
    func state(at position: Int, currentPosition: Int, isPlaying: Bool, isAppActive: Bool) -> GameLifecycleState
}
