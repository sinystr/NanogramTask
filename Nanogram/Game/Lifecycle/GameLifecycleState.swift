/// What the game at a feed position should be doing.
enum GameLifecycleState: Equatable {
    /// On screen and running.
    case running
    /// Loaded early so the next swipe is instant, but paused: no sound, no game logic.
    case preloadedSuspended
    /// Nothing is loaded, so the view uses no memory or CPU for a game.
    case unloaded
}
