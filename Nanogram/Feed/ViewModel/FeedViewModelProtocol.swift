import Observation

/// What the feed's views need from the feed's view model.
///
/// It is `Observable`, so SwiftUI updates the views whenever a value they read changes.
@MainActor
protocol FeedViewModelProtocol: AnyObject, Observable {
    /// Loading the first page, failed, or showing the feed.
    var state: FeedViewModel.State { get }

    /// How many positions the user can scroll through right now.
    var scrollablePositionCount: Int { get }

    /// The position the user is on.
    var currentPosition: Int { get }

    /// True while the user plays the current game.
    var isPlaying: Bool { get }

    /// False while the app is in the background or covered. Then no game runs.
    var isAppActive: Bool { get }

    /// What the given position shows, or `nil` if it is outside the feed.
    func content(at position: Int) -> FeedPositionContent?

    /// True if the user liked the game at `position`.
    func isLiked(at position: Int) -> Bool

    /// Loads the first page. Safe to call more than once.
    func start()

    /// Tries the failed first or next page again.
    func retry()

    /// Retry from the error shown at `position`.
    func retry(at position: Int)

    /// Called once scrolling stops on a position.
    func didSettle(at position: Int)

    /// Starts playing the game at `position`, if it's the current one.
    func enterPlay(at position: Int)

    /// Leaves play mode.
    func exitPlay()

    /// The app is on screen and in use again: the current game runs again.
    func appBecameActive()

    /// The app went to the background or got covered: the current game is paused.
    func appBecameInactive()

    /// Likes the game at `position`, or removes the like. The change is saved on the device.
    func toggleLike(at position: Int)
}
