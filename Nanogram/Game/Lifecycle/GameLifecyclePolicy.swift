/// Decides which games run, which wait paused, and which are unloaded.
///
/// Only the game at the current position runs. The games right before and after it are loaded
/// early but paused, so swiping to either one shows a ready game. While the user plays a game,
/// nothing else stays loaded. While the app isn't active, the current game is paused too, so no
/// game runs or makes a sound in the background.
struct GameLifecyclePolicy: GameLifecyclePolicyProtocol, Equatable {
    /// Whether the games at the previous and next positions are loaded early.
    let preloadsAdjacentGames: Bool

    init(preloadsAdjacentGames: Bool = true) {
        self.preloadsAdjacentGames = preloadsAdjacentGames
    }

    func state(at position: Int, currentPosition: Int, isPlaying: Bool, isAppActive: Bool) -> GameLifecycleState {
        if position == currentPosition {
            return currentGameState(isAppActive: isAppActive)
        }

        let isPrevious = position == currentPosition - 1
        let isNext = position == currentPosition + 1
        let isAdjacent = isPrevious || isNext
        if isAdjacent, preloadsAdjacentGames, !isPlaying {
            return .preloadedSuspended
        }

        return .unloaded
    }

    /// The current game runs while the app is active. Otherwise it is paused, not unloaded,
    /// so the user comes back to the game exactly where they left it.
    private func currentGameState(isAppActive: Bool) -> GameLifecycleState {
        if isAppActive {
            return .running
        }

        return .preloadedSuspended
    }
}
