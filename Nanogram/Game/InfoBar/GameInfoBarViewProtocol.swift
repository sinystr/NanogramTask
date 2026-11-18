import UIKit

/// What a game view needs from the info bar at its bottom.
@MainActor
protocol GameInfoBarViewProtocol: UIView {
    /// Called when the user taps the like button.
    var onLikeTapped: (() -> Void)? { get set }

    /// Shows the game's title, creator, plays, likes and like state.
    func show(_ content: GameInfoBarContent)
}
