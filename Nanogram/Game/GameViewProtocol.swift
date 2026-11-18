import UIKit

/// What the game scroll screen needs from each of its reusable game views.
@MainActor
protocol GameViewProtocol: UIView {
    /// The feed position this view shows right now.
    var position: Int? { get }

    /// Called when Retry is tapped for a download problem.
    var onRetryDownload: (() -> Void)? { get set }

    /// Called when the user taps a game that is ready to play.
    var onPlayRequested: (() -> Void)? { get set }

    /// Called when the user taps the like button.
    var onLikeTapped: (() -> Void)? { get set }

    /// Gives the view its position, content and like state.
    func configure(position: Int, content: FeedPositionContent, isLiked: Bool)

    /// Makes the view's game run, wait paused, or unload.
    func applyLifecycle(_ lifecycle: GameLifecycleState)

    /// Play mode: the game gets every touch.
    func setPlaying(_ playing: Bool)

    /// Empties the view and stops its game.
    func unload()
}
