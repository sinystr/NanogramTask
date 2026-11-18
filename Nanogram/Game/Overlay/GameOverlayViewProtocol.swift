import UIKit

/// What a game view needs from the overlay it shows while its game isn't playable.
@MainActor
protocol GameOverlayViewProtocol: UIView {
    /// Called when the user taps Retry.
    var onRetry: (() -> Void)? { get set }

    /// Shows the game's name, a spinner, or an error with Retry.
    func show(_ content: GameOverlayContent)
}
