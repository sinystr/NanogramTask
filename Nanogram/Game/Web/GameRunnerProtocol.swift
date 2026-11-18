import WebKit

/// What a game view needs from the thing that runs its game.
@MainActor
protocol GameRunnerProtocol: AnyObject {
    /// The web view the game runs in. The game view shows it.
    var webView: WKWebView { get }

    /// How far the current game has got with loading.
    var state: GameLoadState { get }

    /// The game loaded right now, if any.
    var game: Game? { get }

    /// Called every time `state` changes.
    var onStateChange: ((GameLoadState) -> Void)? { get set }

    /// Makes `game` run, wait paused, or unload.
    func apply(_ lifecycle: GameLifecycleState, for game: Game)

    /// Tries to load a failed game again.
    func retry()

    /// Stops the game and frees its memory.
    func unload()
}
